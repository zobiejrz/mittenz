//
//  SearchController.swift
//  mittenz
//
//  Created by Ben Zobrist on 10/23/25.
//

import Foundation
import zChessKit
import zBitboard

final class SearchController {
    private var board: BoardState
    private let evaluator: Evaluator
    private var startTime: Date?
    private var stop: Bool = false
    private let zobrist: Zobrist
    private let transpositionTable: TranspositionTable
    private var maxDepth: Int = 0
    
    init(board: BoardState, evaluator: Evaluator) {
        self.board = board
        self.evaluator = evaluator
        
        self.zobrist = Zobrist()
        self.zobrist.initialize()
        
        self.transpositionTable = TranspositionTable()
    }
    
    func setBoard(_ board: BoardState) {
        self.board = board
    }
    
    func bestMove(timeLimit: TimeLimit) -> Move {
        startTime = Date()
        stop = false
        
        var bestMoveSoFar: Move? = nil
        
        switch timeLimit {
        case .byDepth(let d):
            maxDepth = d
        default:
            maxDepth = 10 // heuristic low default for debugging
        }
        
        var repetitionHistory: Set<UInt64> = []
        let rootKey = zobrist.hash(board)
        repetitionHistory.insert(rootKey)
        
        // Iterative deepening
        for depth in 1...maxDepth {
            if stop { break }
            
            var currentBestMove: Move? = nil
            var alpha = Int.min
            var beta = Int.max
            var bestScore = Int.min
            
            let moves = orderMoves(board.generateAllLegalMoves(), position: board)

            for move in moves {
                if stop { break }
                
                let childPosition = move.resultingBoardState
                let score = safeNegate(
                    alphaBeta(
                        position: childPosition,
                        depth: depth - 1,
                        alpha: safeNegate(beta),
                        beta: safeNegate(alpha),
                        repetitionHistory: &repetitionHistory
                    )
                )

                
                if score > bestScore {
                    bestScore = score
                    currentBestMove = move
                }
                
                if score > alpha {
                    alpha = score
                }
                
                // Stop if time expired
                if timeExpired(timeLimit: timeLimit) {
                    stop = true
                    break
                }
            }
            
            if let move = currentBestMove {
                bestMoveSoFar = move
            }
            
            // Stop if time expired
            if timeExpired(timeLimit: timeLimit) {
                stop = true
                break
            }
        }
        
        // Fallback if no move found (should not happen in normal positions)
        return bestMoveSoFar ?? board.generateAllLegalMoves().first!
    }

    
    private func alphaBeta(
        position: BoardState,
        depth: Int,
        alpha: Int,
        beta: Int,
        repetitionHistory: inout Set<UInt64>
    ) -> Int {
        // detect/prevent repetition
        let key = zobrist.hash(position)
        if repetitionHistory.contains(key) {
            // Threefold repetition draw or repetition avoidance
            let sign = position.playerToMove == .white ? -1 : 1
            return sign * 15
        }
        
        repetitionHistory.insert(key)
        defer { repetitionHistory.remove(key) }
        
        // 1. Time + checkmate check
        if stop { return 0 }
        
        // Checkmate or stalemate detection
        let moves = position.generateAllLegalMoves()
        if moves.isEmpty {
            if position.isKingInCheck() {
                // Checkmate: losing side has no legal moves and is in check
                // Sign is from White’s perspective, so if it’s White to move and mated → huge negative
                let mateScore = evaluator.pieceValues[.king]! - (maxDepth - depth)
                let sign = position.playerToMove == .white ? -1 : 1
                return sign * mateScore
            } else {
                // Stalemate = draw
                return 0
            }
        }
        
        // 2. Transposition table lookup
        if let ttEntry = transpositionTable.probe(key), ttEntry.depth >= depth {
            switch ttEntry.flag {
            case .exact:
                return ttEntry.value
            case .upperBound:
                return min(beta, ttEntry.value)
            case .lowerBound:
                return max(alpha, ttEntry.value)
            }
        }
        
        // 3. Leaf node: evaluate statically if depth == 0
        if depth == 0 {
            if position.isKingInCheck() {
                // Check extension, force one more ply to resolve checks
                var history = repetitionHistory
                return -alphaBeta(position: position, depth: 2, alpha: -beta, beta: -alpha, repetitionHistory: &history)
            }
            return quiescence(position: position, alpha: alpha, beta: beta)
        }
        
        var alphaVar = alpha
        var bestValue = Int.min
        var bestMove: Move? = nil
        
        // 4. Generate all legal moves
        if moves.isEmpty {
            // Checkmate or stalemate
            // Evaluate accordingly: typically +MATE/-MATE or 0 for stalemate
            var eval = evaluator.evaluate(position: position)
            if abs(eval) >= 60000 {
                // Distance-to-mate correction so deeper mates appear slightly worse
                let sign = eval > 0 ? 1 : -1
                eval = (60000 - (maxDepth - depth)) * sign
            }
            return eval
        }
        
        let orderedMoves = moves.sorted { m1, m2 in
            if m1.capturedPiece != m2.capturedPiece {
                return m1.capturedPiece != nil && m2.capturedPiece == nil
            } else if m1.resultingBoardState.isKingInCheck() != m2.resultingBoardState.isKingInCheck() {
                return m1.resultingBoardState.isKingInCheck() && !m2.resultingBoardState.isKingInCheck()
            } else {
                return false
            }
        }
        
        // 5. Iterate through moves
        for move in orderedMoves {
            let childPosition = move.resultingBoardState
            var history = repetitionHistory
            let score = -alphaBeta(position: childPosition, depth: depth - 1, alpha: -beta, beta: -alphaVar, repetitionHistory: &history)
            
            if score > bestValue {
                bestValue = score
                bestMove = move
            }
            
            if bestValue > alphaVar {
                alphaVar = bestValue
            }
            
            // Beta cutoff
            if alphaVar >= beta {
                break
            }
            
            // Optional: stop flag checked periodically for long move lists
            if stop { break }
        }
        
        // 6. Store in transposition table
        let flag: TTFlag
        if bestValue <= alpha {
            flag = .upperBound
        } else if bestValue >= beta {
            flag = .lowerBound
        } else {
            flag = .exact
        }
        
        transpositionTable.store(key, value: bestValue, depth: depth, flag: flag, bestMove: bestMove)
        
        let valueRet: Int
        if abs(bestValue) >= 60000 {
            // Distance-to-mate correction so deeper mates appear slightly worse
            let sign = bestValue > 0 ? 1 : -1
            valueRet = (60000 - (maxDepth - depth)) * sign
        } else {
            valueRet = bestValue
        }
        return bestValue
    }
    
    private func timeExpired(timeLimit: TimeLimit) -> Bool {
        guard let start = startTime else { return false }
        switch timeLimit {
        case .byMillis(let ms):
            return Date().timeIntervalSince(start) * 1000 > Double(ms)
        case .byDepth:
            return false
        case .infinite:
            return false
        }
    }
    
    private func quiescence(position: BoardState, alpha: Int, beta: Int) -> Int {
        if stop { return 0 }
        
        let allmoves = position.generateAllLegalMoves()
        if allmoves.isEmpty {
            if position.isKingInCheck() {
                // Checkmate: losing side has no legal moves and is in check
                // Sign is from White’s perspective, so if it’s White to move and mated → huge negative
                let mateScore = evaluator.pieceValues[.king]!
                let sign = position.playerToMove == .white ? -1 : 1
                return sign * mateScore
            } else {
                // Stalemate = draw
                return 0
            }
        }
        
        var alphaVar = alpha
        
        // 1. Stand-pat evaluation: static evaluation of the current position
        let standPat = evaluator.evaluate(position: position)
        if standPat >= beta {
            return beta
        }
        if alphaVar < standPat {
            alphaVar = standPat
        }
        
        // 2. Generate captures only
        let moves = allmoves.filter {
            $0.capturedPiece != nil || $0.promotion != nil || $0.resultingBoardState.isKingInCheck()
        }

        
        // 3. Iterate over captures
        for move in moves {
            // Optional: use SEE to skip bad captures
            if let targetPiece = move.capturedPiece {
                let targetColor = move.resultingBoardState.whitePieces.hasPiece(on: move.to) ? PlayerColor.black : .white
                let see = evaluator.staticExchangeEval(square: move.to, position: position, targetPiece: targetPiece, targetColor: targetColor)
                if see < 0 { // MARK: This is a place I may need to adjust the sign for each player, I'm not sure
                    continue // Skip obviously losing captures
                }
            }
            
            let childPosition = move.resultingBoardState
            let score = -quiescence(position: childPosition, alpha: -beta, beta: -alphaVar)
            
            if score >= beta {
                return beta // Beta cutoff
            }
            
            if score > alphaVar {
                alphaVar = score
            }
            
            if stop { break } // Stop search if flagged
        }
        
        return alphaVar
    }

    private func safeNegate(_ x: Int) -> Int {
        return x == Int.min ? Int.max : -x
    }
    
    private func orderMoves(_ moves: [Move], position: BoardState) -> [Move] {
        let key = zobrist.hash(position)
        let ttBestMove = transpositionTable.probe(key)?.bestMove
        
        return moves.sorted { m1, m2 in
            // 1. TT move first
            if m1 == ttBestMove { return true }
            if m2 == ttBestMove { return false }
            
            // 2. Captures using MVV/LVA (SEE optional)
            let m1Score: Int
            let m2Score: Int
            
            if let captured = m1.capturedPiece {
                let attacker = m1.piece
                m1Score = (evaluator.pieceValues[captured]! * 10) - (evaluator.pieceValues[attacker]!)
            } else if m1.promotion != nil {
                m1Score = evaluator.pieceValues[m1.promotion!]!
            } else {
                m1Score = 0
            }
            
            if let captured = m2.capturedPiece {
                let attacker = m2.piece
                m2Score = (evaluator.pieceValues[captured]! * 10) - (evaluator.pieceValues[attacker]!)
            } else if m2.promotion != nil {
                m2Score = evaluator.pieceValues[m2.promotion!]!
            } else {
                m2Score = 0
            }
            
            return m1Score > m2Score
        }
    }
}

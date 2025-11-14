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
            maxDepth = 60
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
            
            let moves = orderMoves(board.generateAllLegalMoves(), position: board, pvMove: currentBestMove)
            
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
            return -15
        }
        
        repetitionHistory.insert(key)
        defer { repetitionHistory.remove(key) }
        
        // 1. Time + checkmate check
        if stop { return 0 }
        
        // Hard Limit Check
        let currentRecursionDepth = maxDepth - depth
        if currentRecursionDepth >= 60 {
//            print("hit a depth limit")
//            print(position.boardString())
            // If we hit the absolute safety limit, treat this node as a leaf
            // and return the quiescence search result (or static evaluation).
            return quiescence(position: position, alpha: alpha, beta: beta)
        }
        
        // 2. Transposition table lookup
        let ttMove: Move?
        if let ttEntry = transpositionTable.probe(key), ttEntry.depth >= depth {
            ttMove = ttEntry.bestMove
            switch ttEntry.flag {
            case .exact:
                return ttEntry.value
            case .upperBound:
                return min(beta, ttEntry.value)
            case .lowerBound:
                return max(alpha, ttEntry.value)
            }
        } else {
            ttMove = nil
        }
        
        // 3. Leaf node: evaluate statically if depth == 0
        if depth == 0 {
            if !position.isKingInCheck() {
                // Check extension, force one more ply to resolve checks
                return quiescence(position: position, alpha: alpha, beta: beta)
            }
        }
        
        var alphaVar = alpha
        var bestValue = Int.min
        var bestMove: Move? = nil
        
        // 4. Generate all legal moves
        // Also Checkmate or stalemate detection
        let moves = position.generateAllLegalMoves()
        if moves.isEmpty {
            // Checkmate or stalemate
            if position.isKingInCheck() {
                // Distance-to-mate correction so deeper mates appear slightly worse
                let mateScore = evaluator.pieceValues[.king]!
                let adjustedScore = mateScore - (maxDepth - depth)
                return -adjustedScore
            } else {
                return 0
            }
        }
        
        let orderedMoves = moves.sorted { m1, m2 in
            if m1 == ttMove {
                return true
            } else if m2 == ttMove {
                return false
            } else if m1.capturedPiece != m2.capturedPiece { // Pick the move that captures
                return m1.capturedPiece != nil && m2.capturedPiece == nil
            } else if m1.capturedPiece != nil && m2.capturedPiece != nil { // MVV-LVA
                return (evaluator.pieceValues[m1.capturedPiece!]! * 10) - (evaluator.pieceValues[m1.piece]!) > (evaluator.pieceValues[m2.capturedPiece!]! * 10) - (evaluator.pieceValues[m2.piece]!)
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
        
//        let valueRet: Int
//        if abs(bestValue) >= 60000 {
//            // Distance-to-mate correction so deeper mates appear slightly worse
//            let sign = bestValue > 0 ? 1 : -1
//            valueRet = (60000 - (maxDepth - depth)) * sign
//        } else {
//            valueRet = bestValue
//        }
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
    
    private func quiescence(position: BoardState, alpha: Int, beta: Int, qdepth: Int = 8) -> Int {
        if stop { return 0 }
        if qdepth <= 0 {
            // Return static evaluation when depth limit is reached
            return evaluator.evaluate(position: position)
        }
        
        let allmoves = position.generateAllLegalMoves()
        if allmoves.isEmpty {
            // Checkmate or stalemate
            if position.isKingInCheck() {
                // Distance-to-mate correction so deeper mates appear slightly worse
                let mateScore = evaluator.pieceValues[.king]!
                let adjustedScore = mateScore //- (maxDepth - depth)
                return -adjustedScore
            } else {
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
            $0.capturedPiece != nil || $0.promotion != nil || position.isKingInCheck()
        }.sorted { m1, m2 in
            let score1 = getQuiescenceMoveScore(m1, position: position)
            let score2 = getQuiescenceMoveScore(m2, position: position)
            return score1 > score2
        }

        
        // 3. Iterate over captures
        for move in moves {
            if stop { break } // Stop search if flagged
            
            let childPosition = move.resultingBoardState
            let score = -quiescence(position: childPosition, alpha: -beta, beta: -alphaVar, qdepth: qdepth-1)
            
            if score >= beta {
                return beta // Beta cutoff
            }
            
            if score > alphaVar {
                alphaVar = score
            }
            
        }
        
        return alphaVar
    }

    private func safeNegate(_ x: Int) -> Int {
        return x == Int.min ? Int.max : -x
    }
    
    private func orderMoves(_ moves: [Move], position: BoardState, pvMove: Move? = nil) -> [Move] {
        let key = zobrist.hash(position)
        let ttBestMove: Move?
        if pvMove != nil {
            ttBestMove = pvMove
        } else {
            ttBestMove = transpositionTable.probe(key)?.bestMove
        }
        
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
    
    // Helper function to score moves for QSearch ordering
    private func getQuiescenceMoveScore(_ move: Move, position: BoardState) -> Int {
        if let targetPiece = move.capturedPiece {
            // 1. CAPTURE SCORE (Prioritize by SEE)
            let targetColor: PlayerColor = position.whitePieces.hasPiece(on: move.to) ? .black : .white
            let see = evaluator.staticExchangeEval(square: move.to, position: position, targetPiece: targetPiece, targetColor: targetColor)
            
            let perspective = position.playerToMove == .white ? 1 : -1
            let seeFromCurrentPlayer = see * perspective
            
            if seeFromCurrentPlayer > 0 {
                // Winning Captures: Highest Priority (Score > 10000)
                return 10000 + seeFromCurrentPlayer
            } else {
                // Even or Losing Captures: Low Priority (Score < 0)
                // Use SEE to order blunders among themselves, but keep them below quiet moves.
                return -10000 + seeFromCurrentPlayer
            }
        }
        
        if let promotedPiece = move.promotion {
            // 2. PROMOTION SCORE (Score 1000 to 9999)
            // Highly prioritize promotion, especially to Queen.
            return evaluator.pieceValues[promotedPiece]! * 10
        }
        
        // 3. QUIET CHECK RESOLUTION MOVES (Score 0)
        // These include any non-capture move required to get out of check.
        if position.isKingInCheck() {
            return 0 // Neutral priority
        }
        
        // This should generally not be reached in the filtered list unless it's a quiet move
        // filtered in only because of the 'isKingInCheck()' condition.
        return -20000 // Lowest priority
    }
}

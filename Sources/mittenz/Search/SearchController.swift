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
        var maxDepth: Int
        
        switch timeLimit {
        case .byDepth(let d):
            maxDepth = d
        default:
            maxDepth = 10 // heuristic low default for debugging
        }
        
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
                        beta: safeNegate(alpha)
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

    
    private func alphaBeta(position: BoardState, depth: Int, alpha: Int, beta: Int) -> Int {
        // 1. Time check
        if stop { return 0 }
        
        // 2. Transposition table lookup
        let key = zobrist.hash(position)
        if let ttEntry = transpositionTable.probe(key), ttEntry.depth >= depth {
            switch ttEntry.flag {
            case .exact:
                return ttEntry.value
            case .upperBound:
                if ttEntry.value <= alpha { return alpha }
            case .lowerBound:
                if ttEntry.value >= beta { return beta }
            }
        }
        
        // 3. Leaf node: evaluate statically if depth == 0
        if depth == 0 {
            return quiescence(position: position, alpha: alpha, beta: beta)
        }
        
        var alphaVar = alpha
        var bestValue = Int.min
        var bestMove: Move? = nil
        
        // 4. Generate all legal moves
        let moves = position.generateAllLegalMoves()
        
        if moves.isEmpty {
            // Checkmate or stalemate
            // Evaluate accordingly: typically +MATE/-MATE or 0 for stalemate
            return evaluator.evaluate(position: position)  // simple fallback
        }
        
        // 5. Iterate through moves
        for move in moves {
            let childPosition = move.resultingBoardState
            let score = -alphaBeta(position: childPosition, depth: depth - 1, alpha: -beta, beta: -alphaVar)
            
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
            flag = .lowerBound
        } else if bestValue >= beta {
            flag = .upperBound
        } else {
            flag = .exact
        }
        
        transpositionTable.store(key, value: bestValue, depth: depth, flag: flag, bestMove: bestMove)
        
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
        let moves = position.generateAllLegalMoves().filter { $0.capturedPiece != nil }
        
        // 3. Iterate over captures
        for move in moves {
            // Optional: use SEE to skip bad captures
            let targetPiece = move.capturedPiece!
            let targetColor = move.resultingBoardState.whitePieces.hasPiece(on: move.to) ? PlayerColor.white : .black
            let see = evaluator.staticExchangeEval(square: move.to, position: position, targetPiece: targetPiece, targetColor: targetColor)
            if see < 0 { // MARK: This is a place I may need to adjust the sign for each player
                continue // Skip obviously losing captures
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
            
            if m1.isCapture, let captured = m1.capturedPieceType, let attacker = m1.pieceType {
                m1Score = (position.evaluator?.pieceValues[captured] ?? 0) * 10 - (position.evaluator?.pieceValues[attacker] ?? 0)
            } else if m1.isPromotion {
                m1Score = 900 // high value for promotions
            } else {
                m1Score = 0
            }
            
            if m2.isCapture, let captured = m2.capturedPieceType, let attacker = m2.pieceType {
                m2Score = (position.evaluator?.pieceValues[captured] ?? 0) * 10 - (position.evaluator?.pieceValues[attacker] ?? 0)
            } else if m2.isPromotion {
                m2Score = 900
            } else {
                m2Score = 0
            }
            
            return m1Score > m2Score
        }
    }
}

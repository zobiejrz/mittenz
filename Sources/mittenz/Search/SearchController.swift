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
        var bestScore = Int.min
        var currentBestMove: Move? = nil
        var bestMoveSoFar: Move? = nil

        for depth in 1...maxDepth {
            if stop { break }
            
            // Aspiration Window Setup
            var searchAgain = true
            var currentAlpha = Int.min
            var currentBeta = Int.max
            let window = 50
            
            if bestScore != Int.min {
                // Use results from previous, successfully completed depth
                currentAlpha = bestScore - window
                currentBeta = bestScore + window
            }
            
            while searchAgain {
                searchAgain = false // assume success on current attempt
                
                let moves = orderMoves(board.generateAllLegalMoves(), position: board, pvMove: currentBestMove)
                
                var depthBestScore = Int.min
                var depthCurrentBestMove: Move? = nil
                
                for move in moves {
                    if stop { break }
                    
                    let childPosition = move.resultingBoardState
                    let score = safeNegate(
                        alphaBeta(
                            position: childPosition,
                            depth: depth - 1,
                            alpha: safeNegate(currentBeta),
                            beta: safeNegate(currentAlpha),
                            repetitionHistory: &repetitionHistory
                        )
                    )
                    
                    
                    if score > depthBestScore {
                        depthBestScore = score
                        depthCurrentBestMove = move
                    }
                    
                    if score > currentAlpha {
                        currentAlpha = score
                    }
                    
                    if score >= currentBeta {
                        // Fail-High: Score is above the upper bound. Window was too small.
                        // This is a valuable move but we need to check if we must research.
                        break // Beta Cutoff (Move ordering has been effective)
                    }
                    
                    if timeExpired(timeLimit: timeLimit) {
                        stop = true
                        break
                    }
                }
                
                if !stop {
                    if depthBestScore <= currentAlpha {
                        // Fail Low: The true score is less than the expected lower bound.
                        // We must re-search with the full minimum alpha.
                        if currentAlpha > Int.min {
                            currentBeta = Int.max
                            currentAlpha = Int.min
                            searchAgain = true
                        }
                    } else if depthBestScore >= currentBeta && currentBeta < Int.max {
                        // Fail High: The true score is higher than the expected upper bound.
                        // We must re-search with the full maximum beta.
                        currentAlpha = Int.min
                        currentBeta = Int.max
                        searchAgain = true
                    }
                }
                
                // Only update persistent results if the search was NOT a window failure
                if !searchAgain {
                    // Update persistent variables with results from this successful depth
                    bestScore = depthBestScore
                    currentBestMove = depthCurrentBestMove
                    bestMoveSoFar = depthCurrentBestMove
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
        // Time + checkmate check
        if stop { return 0 }
        
        // Hard Limit Check
        let currentRecursionDepth = maxDepth - depth
        if currentRecursionDepth >= 60 {
//            print("hit a depth limit")
//            print(position.boardString())
            // If we hit the absolute safety limit, treat this node as a leaf
            // and return the quiescence search result (or static evaluation).
            return quiescence(position: position, alpha: alpha, beta: beta, repetitionHistory: &repetitionHistory)
        }
        
        // Generate all legal moves
        // Also Checkmate or stalemate detection
        let moves = position.generateAllLegalMoves()
        if moves.isEmpty {
            // Checkmate or stalemate
            print ("EMPTY CHECK")
            if position.isKingInCheck() {
                // Distance-to-mate correction so deeper mates appear slightly worse
                let mateScore = evaluator.pieceValues[.king]!
                let adjustedScore = mateScore - (maxDepth - depth)
                return -adjustedScore
            } else {
                return -15
            }
        }
        
        // detect/prevent repetition
        let key = zobrist.hash(position)
        if repetitionHistory.contains(key) {
            // Threefold repetition draw or repetition avoidance
            return -15
        }
        
        repetitionHistory.insert(key)
        defer { repetitionHistory.remove(key) }
        
        // Transposition table lookup
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
        
        // Leaf node: evaluate statically if depth == 0
        if depth == 0 {
            return quiescence(position: position, alpha: alpha, beta: beta, repetitionHistory: &repetitionHistory)
        }
        
        var alphaVar = alpha
        var bestValue = Int.min
        var bestMove: Move? = nil
        
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
        
        // Iterate through moves
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
        
        // Store in transposition table
        let flag: TTFlag
        if bestValue <= alpha {
            flag = .upperBound
        } else if bestValue >= beta {
            flag = .lowerBound
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
    
    private func quiescence(
        position: BoardState,
        alpha: Int,
        beta: Int,
        repetitionHistory: inout Set<UInt64>,
        qdepth: Int = 16,
    ) -> Int {
        if stop { return 0 }
        
        // repetition prevention
        let currentKey = zobrist.hash(position)
        if repetitionHistory.contains(currentKey) {
            return -15
        }
        repetitionHistory.insert(currentKey)
        
        // depth limit enforcement
        if qdepth <= 0 {
            // Return static evaluation when depth limit is reached
            repetitionHistory.remove(currentKey)
            return evaluator.evaluate(position: position)
        }
        
        var alphaVar = alpha
        
        // static evaluation of the current position
        let standPat = evaluator.evaluate(position: position, nosee: true)
        
        // stand-pat beta cutoff
        if standPat >= beta {
            return beta
        }
        
        // delta pruning
        let delta = evaluator.pieceValues[.queen]!
        if !position.isKingInCheck() && standPat + delta < alphaVar {
            repetitionHistory.remove(currentKey)
            return standPat
        }
        
        // updata alpha with stand-pat if it is bssf
        if alphaVar < standPat {
            alphaVar = standPat
        }
        
        // checkmate/draw evaluation
        let allmoves = position.generateAllLegalMoves()
        if allmoves.isEmpty {
            repetitionHistory.remove(currentKey)
            // Checkmate or stalemate
            if position.isKingInCheck() {
                // Distance-to-mate correction so deeper mates appear slightly worse
                let mateScore = evaluator.pieceValues[.king]!
                return -(mateScore - qdepth)
            } else {
                return -15
            }
        }
        
        
        // Filter for only 'noisy' moves + move ordering
        let moves = allmoves.filter {
            $0.capturedPiece != nil || $0.promotion != nil || position.isKingInCheck()
        }.sorted { m1, m2 in
            let score1 = getQuiescenceMoveScore(m1, position: position)
            let score2 = getQuiescenceMoveScore(m2, position: position)
            return score1 > score2
        }

        
        // Iterate over noisy moves
        for move in moves {
            if stop { break } // Stop search if flagged
            
            let childPosition = move.resultingBoardState
            var history = repetitionHistory
            let score = -quiescence(position: childPosition, alpha: -beta, beta: -alphaVar, repetitionHistory: &history, qdepth: qdepth-1)
            
            if score >= beta {
                repetitionHistory.remove(currentKey)
                return beta // Beta cutoff
            }
            
            if score > alphaVar {
                alphaVar = score
            }
            
        }
        repetitionHistory.remove(currentKey)
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
            // TT move first
            if m1 == ttBestMove { return true }
            if m2 == ttBestMove { return false }
            
            if m1.resultingBoardState.isKingInCheck() != m2.resultingBoardState.isKingInCheck() {
                return m1.resultingBoardState.isKingInCheck() && !m2.resultingBoardState.isKingInCheck()
            }
            
            // Captures using MVV/LVA (SEE optional)
            let m1Score: Int
            let m2Score: Int
            
            if let captured = m1.capturedPiece {
                let attacker = m1.piece
                m1Score = (evaluator.pieceValues[captured]! * 10) - (evaluator.pieceValues[attacker]!)
            } /*else if m1.promotion != nil {
                m1Score = evaluator.pieceValues[m1.promotion!]!
            }*/ else {
                m1Score = 0
            }
            
            if let captured = m2.capturedPiece {
                let attacker = m2.piece
                m2Score = (evaluator.pieceValues[captured]! * 10) - (evaluator.pieceValues[attacker]!)
            } /*else if m2.promotion != nil {
                m2Score = evaluator.pieceValues[m2.promotion!]!
            }*/ else {
                m2Score = 0
            }
            
            return m1Score > m2Score
        }
    }
    
    // Helper function to score moves for QSearch ordering
    private func getQuiescenceMoveScore(_ move: Move, position: BoardState) -> Int {
        
        if let promotedPiece = move.promotion {
            // 1. PROMOTION SCORE (Score 1000 to 9999)
            // Highly prioritize promotion, especially to Queen.
            return evaluator.pieceValues[promotedPiece]! + 20000
        }
        
        if let targetPiece = move.capturedPiece {
            // 2. CAPTURE SCORE (Prioritize by SEE)
            let targetColor: PlayerColor = position.whitePieces.hasPiece(on: move.to) ? .black : .white
            let see = evaluator.staticExchangeEval(square: move.to, position: position, targetPiece: targetPiece, targetColor: targetColor)
                        
            if see > 0 {
                // Winning Captures: Highest Priority (Score > 10000)
                return 10000 + see
            } else {
                // Even or Losing Captures: Low Priority (Score < 0)
                // Use SEE to order blunders among themselves, but keep them below quiet moves.
                return -10000 + see
            }
        }
        
        // 3. QUIET CHECK RESOLUTION MOVES (Score 0)
        // These include any non-capture move required to get out of check.
        if position.isKingInCheck() {
            return 1 // Neutral priority
        }
        
        // This should generally not be reached in the filtered list unless it's a quiet move
        // filtered in only because of the 'isKingInCheck()' condition.
        return 0 // Lowest priority
    }
}

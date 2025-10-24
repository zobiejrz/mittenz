//
//  SearchController.swift
//  mittenz
//
//  Created by Ben Zobrist on 10/23/25.
//

import Foundation
import zChessKit

final class SearchController {
    private var board: BoardState
    private let evaluator: Evaluator
    private var startTime: Date?
    private var stop: Bool = false
    
    init(board: BoardState, evaluator: Evaluator) {
        self.board = board
        self.evaluator = evaluator
    }
    
    func bestMove(timeLimit: TimeLimit, skill: SkillSetting?) -> Move? {
        startTime = Date()
        stop = false
        
        // Default skill: full strength
        let skillSetting = skill ?? SkillSetting(maxCentipawnLoss: 0)
        
        var bestMoveSoFar: Move? = nil
        var bestScoreSoFar = -Int.max
        
        var depth = 1
        while !stop {
            var bestScoreThisDepth = -Int.max
            var bestMoveThisDepth: Move? = nil
            
            let legalMoves = board.generateAllLegalMoves()
            
            for move in legalMoves {
                let nextBoard = move.resultingBoardState
                let score = -alphaBeta(position: nextBoard, depth: depth - 1, alpha: -Int.max, beta: Int.max)
                
                if score > bestScoreThisDepth {
                    bestScoreThisDepth = score
                    bestMoveThisDepth = move
                }
                
                if timeExpired(timeLimit: timeLimit) {
                    stop = true
                    break
                }
            }
            
            // Update global best move
            if let moveThisDepth = bestMoveThisDepth {
                bestMoveSoFar = moveThisDepth
                bestScoreSoFar = bestScoreThisDepth
            }
            
//            Logger.log("Depth \(depth) completed. Best move so far: \(bestMoveSoFar?.notation ?? "none") score: \(bestScoreSoFar)")
            
            // Increment depth for iterative deepening
            depth += 1
        }
        
        guard let fullStrengthMove = bestMoveSoFar else {
            return board.generateAllLegalMoves().first // fallback
        }
        
        // --- Apply skill adjustment ---
        // Pick among legal moves whose evaluation is close to the best
        let legalMoves = board.generateAllLegalMoves()
        let weightedMoves = legalMoves.filter { move in
            let score = evaluator.evaluate(position: move.resultingBoardState, depth: 0) // quick eval
            let centipawnLoss = bestScoreSoFar - score
            return centipawnLoss <= skillSetting.maxCentipawnLoss
        }
        
        // Pick randomly from candidates if any; otherwise fallback to best move
        let finalMove = weightedMoves.randomElement() ?? fullStrengthMove
        return finalMove
    }



    
    private func alphaBeta(position: BoardState, depth: Int, alpha: Int, beta: Int) -> Int {
        if depth == 0 || stop {
            return evaluator.evaluate(position: position, depth: depth)
        }
        
        var alphaVar = alpha
        var bestScore = -Int.max
        let moves = position.generateAllLegalMoves()
        
        if moves.isEmpty {
            return evaluator.evaluate(position: position, depth: depth) // handle mate/stalemate later
        }
        
        for move in moves {
            let score = -alphaBeta(position: move.resultingBoardState, depth: depth - 1, alpha: -beta, beta: -alphaVar)
            
            if score >= beta {
                return beta
            }
            if score > bestScore {
                bestScore = score
            }
            if score > alphaVar {
                alphaVar = score
            }
            
            if timeExpired(timeLimit: .infinite) { // or pass timeLimit down if needed
                stop = true
                break
            }
        }
        
        return bestScore
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
}

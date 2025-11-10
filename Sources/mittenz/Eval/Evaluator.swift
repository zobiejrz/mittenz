//
//  Evaluator.swift
//  mittenz
//
//  Created by Ben Zobrist on 10/23/25.
//

import zChessKit
import zBitboard

final class Evaluator {
    let pieceValues: [PieceType: Int] = [
        .pawn: 100,
        .knight: 280,
        .bishop: 320,
        .rook: 479,
        .queen: 929,
        .king: 60000
    ]
    
    // MARK: - Init

    init() {
        // ...
    }
    
    // MARK: - Evaluate
    public func evaluate(position: BoardState) -> Int {
        return evaluateStatic(position: position)
    }
    
    // MARK: - Static evaluation
    private func evaluateStatic(position: BoardState) -> Int {
        // Material + piece-square evaluation, from White's perspective
        let material = materialBalance(position: position)
        let pieceSquareScore = evaluatePieceSquares(position: position)
        
        return material + pieceSquareScore
    }
    
    // MARK: - Static Exchange Evaluation
    func staticExchangeEval(square: Square, position: BoardState, targetPiece: PieceType, targetColor: PlayerColor) -> Int {
        var occ = position.allPieces  // Assume this exists; otherwise derive from BoardState
        
        // Initialize gain array
        var gains: [Int] = []
        
        // Start with the target piece being captured
        gains.append(pieceValues[targetPiece] ?? 0)
        
        // Side to move for the simulation (the attacker)
        var side: PlayerColor = targetColor == .white ? .black : .white  // The initial attacker is opposite the target
        
        while true {
            // Get all attackers to the square for the current side
            let attackers = position.attackersTo(square, color: side, occupancy: occ)
            
            // Find the least valuable attacker
            guard let (attackerPiece, attackerSquare) = position.leastValuedAttacker(from: attackers, color: side) else {
                break  // No more attackers; end of sequence
            }
            
            // Compute gain for this capture
            let gain = (pieceValues[attackerPiece] ?? 0) - (gains.last ?? 0)
            gains.append(gain)
            
            // Remove the attacker from the occupancy bitboard
            occ &= ~Bitboard.squareMask(attackerSquare)
            
            // Swap sides
            side = side == .white ? .black : .white
        }
        
        // Now propagate the minimum gains backwards to account for optimal defense
        for i in (1..<gains.count).reversed() {
            gains[i - 1] = -max(-gains[i - 1], gains[i])
        }
        
        // Return net gain for initial attacker
        return gains.first ?? 0
    }
    
    // MARK: - Piece-square table evaluation
    private func evaluatePieceSquares(position: BoardState) -> Int {
        var score = 0
        
        // Determine phase ratio (0 = opening, 1 = endgame)
        let phase = phaseFactor(position: position)
        
        // Iterate over all pieces in the position
        for sq in Square.allCases {
            guard let piece = position.whatPieceIsOn(sq) else { continue }
            let color = position.whitePieces.hasPiece(on: sq) ? PlayerColor.white : .black
            let multiplier = colorMultiplier(for: color)
            
            let value = PieceSquareTable.read(piece: piece, square: sq, isWhite: color == .white, ratio: phase)
            score += multiplier * value

            
        }
        
        return score
    }
    
    // MARK: - Material Balance Evaluation
    private func materialBalance(position: BoardState) -> Int {
        var score = 0
        
        for sq in Square.allCases {
            guard let piece = position.whatPieceIsOn(sq) else { continue }
            let color = position.whitePieces.hasPiece(on: sq) ? PlayerColor.white : .black
            let multiplier = colorMultiplier(for: color)
            
            let value = pieceValues[piece]!
            score += multiplier * value
        }
        
        return score
    }
    
    // MARK: - Phase Factor (ratio of opening/end game)
    private func phaseFactor(position: BoardState) -> Double {
        let maxPhase = pieceValues[.knight]! + pieceValues[.bishop]! + pieceValues[.rook]! + pieceValues[.queen]! // Total max non-pawn
        let currentPhase = 0
        var totalCurrent = 0
        
        totalCurrent += pieceValues[.knight]! * (position.blackKnights | position.whiteKnights).nonzeroBitCount
        totalCurrent += pieceValues[.bishop]! * (position.blackBishops | position.whiteBishops).nonzeroBitCount
        totalCurrent += pieceValues[.rook]! * (position.blackRooks | position.whiteRooks).nonzeroBitCount
        totalCurrent += pieceValues[.queen]! * (position.blackQueens | position.whiteQueens).nonzeroBitCount
        
        // Clamp ratio to [0,1]
        let ratio = 1.0 - min(Double(totalCurrent) / Double(maxPhase), 1.0)
        return ratio
    }
    
    // MARK: - Color Multiplier (+/- 1)
    private func colorMultiplier(for color: PlayerColor) -> Int {
        color == .white ? 1 : -1
    }
}

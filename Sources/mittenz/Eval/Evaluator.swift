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
        // Terminal conditions
        let moves = position.generateAllLegalMoves()
        
        if moves.isEmpty {
            if position.isKingInCheck() {
                // Checkmate: losing side has no legal moves and is in check
                // Sign is from White’s perspective, so if it’s White to move and mated → huge negative
                let mateScore = pieceValues[.king]!  // same order as King value
                let sign = -1 * colorMultiplier(for: position.playerToMove)
                return sign * mateScore
            } else {
                // Stalemate = draw
                return 0
            }
        }
        
        // Material + piece-square evaluation, from White's perspective
        let material = materialBalance(position: position)
        let pieceSquareScore = evaluatePieceSquares(position: position)
        
        var seePenalty = 0
        
        // Iterate over all squares to check if any pieces are attacked
        for sq in Square.allCases {
            guard let piece = position.whatPieceIsOn(sq) else { continue }
            let color = position.whitePieces.hasPiece(on: sq) ? PlayerColor.white : .black
            
            let oppositeColor = color == .white ? PlayerColor.black : .white
            let attackers = position.attackersTo(sq, color: oppositeColor, occupancy: position.allPieces)
            if attackers == .empty { continue }
            
            // Compute SEE: net gain/loss for the piece if captured
            let see = staticExchangeEval(square: sq, position: position, targetPiece: piece, targetColor: color)
            
            // Penalize negative SEE (losing material) only
            if colorMultiplier(for: color) * see < 0 {
                seePenalty += colorMultiplier(for: color) * see
            }
        }
        
        return material + pieceSquareScore + seePenalty
    }
    
    // MARK: - Static Exchange Evaluation
    func staticExchangeEval(square: Square, position: BoardState, targetPiece: PieceType, targetColor: PlayerColor) -> Int {
        var occ = position.allPieces  // Assume this exists; otherwise derive from BoardState
        
        // Initialize gain array
        var gains: [Int] = []
        
        // Start with the target piece being captured
        gains.append(pieceValues[targetPiece]!)
        
        // Side to move for the simulation (the attacker)
        var attackerSide: PlayerColor = targetColor == .white ? .black : .white  // The initial attacker is opposite the target
        
        while true {
            // Pre-check: are there attackers for the next side?
            let nextAttackers = position.attackersTo(square, color: attackerSide == .white ? .black : .white, occupancy: occ)
            guard let (_, _) = position.leastValuedAttacker(from: nextAttackers, color: attackerSide) else {
                break  // No more attackers; end of sequence
            }
            
            // Get all attackers to the square for the current side
            let attackers = position.attackersTo(square, color: attackerSide, occupancy: occ)
            
            // Find the least valuable attacker
            guard let (attackerPiece, attackerSquare) = position.leastValuedAttacker(from: attackers, color: attackerSide) else {
                break  // No more attackers; end of sequence
            }
            
            // Compute gain for this capture
            let gain = pieceValues[attackerPiece]! - gains.last!
            gains.append(gain)
            
            // Remove the attacker from the occupancy bitboard
            occ &= ~Bitboard.squareMask(attackerSquare)
            
            // Swap sides
            attackerSide = attackerSide == .white ? .black : .white
        }
        
        // Now propagate the minimum gains backwards to account for optimal defense
//        print("\(gains)")
        for i in (1..<gains.count).reversed() {
//            print("-max(-\(gains[i-1]), \(gains[i])) = \(-max(-gains[i-1], gains[i]))")
            gains[i - 1] = -max(-gains[i-1], gains[i])
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
        
        var totalCurrent = 0
        totalCurrent += pieceValues[.knight]! * (position.blackKnights | position.whiteKnights).nonzeroBitCount
        totalCurrent += pieceValues[.bishop]! * (position.blackBishops | position.whiteBishops).nonzeroBitCount
        totalCurrent += pieceValues[.rook]! * (position.blackRooks | position.whiteRooks).nonzeroBitCount
        totalCurrent += pieceValues[.queen]! * (position.blackQueens | position.whiteQueens).nonzeroBitCount
        
        // Compute ratio: 0 = opening, 1 = endgame
        let ratio = 1.0 - min(Double(totalCurrent) / Double(maxPhase), 1.0)
        return ratio
    }
    
    // MARK: - Color Multiplier (+/- 1)
    private func colorMultiplier(for color: PlayerColor) -> Int {
        color == .white ? 1 : -1
    }
}

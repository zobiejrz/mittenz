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
    public func evaluate(position: BoardState, nosee: Bool = false) -> Int {
        return evaluateStatic(position: position, nosee: nosee)
    }
    
    // MARK: - Static evaluation
    private func evaluateStatic(position: BoardState, nosee: Bool = false) -> Int {
        
        // Material + piece-square evaluation
        let material = materialBalance(position: position)
        let pieceSquareScore = evaluatePieceSquares(position: position)
        
        var seePenalty = 0
        if nosee {
            // Iterate over all squares to check if any pieces are attacked
            for sq in Square.allCases {
                guard let piece = position.whatPieceIsOn(sq) else { continue }
                let color = position.whitePieces.hasPiece(on: sq) ? PlayerColor.white : .black
                
                let oppositeColor = color == .white ? PlayerColor.black : .white
                let attackers = position.attackersTo(sq, color: oppositeColor, occupancy: position.allPieces)
                if attackers == .empty { continue }
                
                // Compute SEE: net gain/loss for the piece if captured
                let multiplier = position.playerToMove == oppositeColor ? 1 : -1
                let see = staticExchangeEval(square: sq, position: position, targetPiece: piece, targetColor: color)
                
                seePenalty += multiplier * see
            }
        }
        
        let total = material + pieceSquareScore + seePenalty
//        if position.plyNumber == 7 {
//            print(position.boardString())
//            print("\teval is \(material) + \(pieceSquareScore) + \(seePenalty) = \(total)")
//        }
        
        return total
    }
    
    // MARK: - Static Exchange Evaluation
    func staticExchangeEval(square: Square, position: BoardState, targetPiece: PieceType, targetColor: PlayerColor) -> Int {
//        guard targetPiece != .king else { return 0 }
        
        var occ = position.allPieces & ~Bitboard.squareMask(square)
        
        // Initialize gain array
        var gains: [Int] = []
        
        // Start with the target piece being captured
        var currentCapturedPieceValue = pieceValues[targetPiece]!
        
        // Side to move for the simulation (the attacker)
        var attackerSide: PlayerColor = targetColor == .white ? .black : .white  // The initial attacker is opposite the target
        
        while true {
            // Get all attackers to the square for the current side
            let attackers = position.attackersTo(square, color: attackerSide, occupancy: occ)
            
            // Find the least valuable attacker
            guard let (attackerPiece, attackerSquare) = position.leastValuedAttacker(from: attackers, color: attackerSide) else {
                break  // No more attackers; end of sequence
            }
            
//            if currentCapturedPieceValue != pieceValues[.king]! {
                gains.append(currentCapturedPieceValue)
//                break
//            }
            
            // The next piece to be caputered is the current attacker
            currentCapturedPieceValue = pieceValues[attackerPiece]!
            
            // Remove the attacker from the occupancy bitboard
            occ &= ~Bitboard.squareMask(attackerSquare)
            
            // Swap sides
            attackerSide = attackerSide == .white ? .black : .white
        }
        
        if gains.isEmpty {
            return 0
        }
        
        var score = 0
        
        // Now propagate the minimum gains backwards to account for optimal defense and opt-out propagation
        for i in (0..<gains.count).reversed() {
            score = max(0, gains[i] - score)
        }
        
        // Return net gain for initial attacker
         return score
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
            let multiplier = position.playerToMove == color ? 1 : -1

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
            let multiplier = position.playerToMove == color ? 1 : -1
            
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

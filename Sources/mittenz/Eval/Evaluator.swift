//
//  Evaluator.swift
//  mittenz
//
//  Created by Ben Zobrist on 10/23/25.
//

import zChessKit
import zBitboard

final class Evaluator {
    private let useNNUE: Bool
    
    private let pieceValues: [PieceType: Int] = [
        .pawn: 100,
        .knight: 320,
        .bishop: 330,
        .rook: 500,
        .queen: 900,
        .king: 20000
    ]
    
    // MARK: - Piece-square tables (midgame)
    private let pawnTable: [Int] = [
        0,  0,  0,  0,  0,  0,  0,  0,
        50, 50, 50, 50, 50, 50, 50, 50,
        10, 10, 20, 30, 30, 20, 10, 10,
        5,  5, 10, 25, 25, 10,  5,  5,
        0,  0,  0, 20, 20,  0,  0,  0,
        5, -5,-10,  0,  0,-10, -5,  5,
        5, 10, 10,-20,-20, 10, 10,  5,
        0,  0,  0,  0,  0,  0,  0,  0
    ]
    
    private let knightTable: [Int] = [
        -50,-40,-30,-30,-30,-30,-40,-50,
         -40,-20,  0,  0,  0,  0,-20,-40,
         -30,  0, 10, 15, 15, 10,  0,-30,
         -30,  5, 15, 20, 20, 15,  5,-30,
         -30,  0, 15, 20, 20, 15,  0,-30,
         -30,  5, 10, 15, 15, 10,  5,-30,
         -40,-20,  0,  5,  5,  0,-20,-40,
         -50,-40,-30,-30,-30,-30,-40,-50
    ]
    
    private let bishopTable: [Int] = [
        -20,-10,-10,-10,-10,-10,-10,-20,
         -10,  0,  0,  0,  0,  0,  0,-10,
         -10,  0,  5, 10, 10,  5,  0,-10,
         -10,  5,  5, 10, 10,  5,  5,-10,
         -10,  0, 10, 10, 10, 10,  0,-10,
         -10, 10, 10, 10, 10, 10, 10,-10,
         -10,  5,  0,  0,  0,  0,  5,-10,
         -20,-10,-10,-10,-10,-10,-10,-20
    ]
    
    private let rookTable: [Int] = [
        0,  0,  0,  0,  0,  0,  0,  0,
        5, 10, 10, 10, 10, 10, 10,  5,
        -5,  0,  0,  0,  0,  0,  0, -5,
        -5,  0,  0,  0,  0,  0,  0, -5,
        -5,  0,  0,  0,  0,  0,  0, -5,
        -5,  0,  0,  0,  0,  0,  0, -5,
        -5,  0,  0,  0,  0,  0,  0, -5,
        0,  0,  0,  5,  5,  0,  0,  0
    ]
    
    private let queenTable: [Int] = [
        -20,-10,-10, -5, -5,-10,-10,-20,
         -10,  0,  0,  0,  0,  0,  0,-10,
         -10,  0,  5,  5,  5,  5,  0,-10,
         -5,  0,  5,  5,  5,  5,  0, -5,
         0,  0,  5,  5,  5,  5,  0, -5,
         -10,  5,  5,  5,  5,  5,  0,-10,
         -10,  0,  5,  0,  0,  0,  0,-10,
         -20,-10,-10, -5, -5,-10,-10,-20
    ]

    
    private let kingTable: [Int] = [
        -30,-40,-40,-50,-50,-40,-40,-30,
         -30,-40,-40,-50,-50,-40,-40,-30,
         -30,-40,-40,-50,-50,-40,-40,-30,
         -30,-40,-40,-50,-50,-40,-40,-30,
         -20,-30,-30,-40,-40,-30,-30,-20,
         -10,-20,-20,-20,-20,-20,-20,-10,
         20, 20,  0,  0,  0,  0, 20, 20,
         20, 30, 10,  0,  0, 10, 30, 20
    ]
    
    // MARK: - Init

    init(useNNUE: Bool = false) {
        self.useNNUE = useNNUE
        if useNNUE {
            loadNNUE()
        }
    }
    
    // MARK: - Evaluate
    func evaluate(position: BoardState, depth: Int = 0) -> Int {
        if useNNUE {
            return evaluateNNUE(position: position)
        } else {
            return evaluateStatic(position: position)
        }
    }
    
    // MARK: - Static evaluation
    private func evaluateStatic(position: BoardState) -> Int {
        var score = 0
        
        // Material
        score += pieceValues[.pawn]! * position.whitePawns.nonzeroBitCount
        score += pieceValues[.knight]! * position.whiteKnights.nonzeroBitCount
        score += pieceValues[.bishop]! * position.whiteBishops.nonzeroBitCount
        score += pieceValues[.rook]! * position.whiteRooks.nonzeroBitCount
        score += pieceValues[.queen]! * position.whiteQueens.nonzeroBitCount
        score += pieceValues[.king]! * position.whiteKing.nonzeroBitCount
        
        score -= pieceValues[.pawn]! * position.blackPawns.nonzeroBitCount
        score -= pieceValues[.knight]! * position.blackKnights.nonzeroBitCount
        score -= pieceValues[.bishop]! * position.blackBishops.nonzeroBitCount
        score -= pieceValues[.rook]! * position.blackRooks.nonzeroBitCount
        score -= pieceValues[.queen]! * position.blackQueens.nonzeroBitCount
        score -= pieceValues[.king]! * position.blackKing.nonzeroBitCount
        
        // Mobility (simple)
        score += 10 * position.generateAllLegalMoves(.white).count
        score -= 10 * position.generateAllLegalMoves(.black).count
        
        // Piece-square tables
        score += evaluatePieceSquares(position: position)
        
        // King safety (basic)
        score += evaluateKingSafety(position: position)
        
        // Pawn structure
        score += evaluatePawnStructure(position: position)
        
        return position.playerToMove == .white ? score : -score
    }
    
    // MARK: - Piece-square table evaluation
    private func evaluatePieceSquares(position: BoardState) -> Int {
        var score = 0
        
        for s in Square.allCases {
            if let piece = position.whatPieceIsOn(s) {
                let pieceColor: PlayerColor = Bitboard.squareMask(s) & position.whitePieces > 1 ? .white : .black
                let idx = pieceColor == .white ? s.rawValue : 63 - s.rawValue
                
                let delta: Int
                switch piece {
                case .pawn:
                    delta = pawnTable[idx]
                case .knight:
                    delta = knightTable[idx]
                case .bishop:
                    delta = bishopTable[idx]
                case .rook:
                    delta = rookTable[idx]
                case .queen:
                    delta = queenTable[idx]
                case .king:
                    delta = kingTable[idx]
                }
                
                if pieceColor == .white {
                    score += delta
                } else {
                    score -= delta
                }
            }
        }
        
        return score
    }
    
    // MARK: - Basic king safety evaluation
    private func evaluateKingSafety(position: BoardState) -> Int {
        var score = 0
        
        // Penalize open files near king
        let (whiteIdx, _) = position.whiteKing.popLSB()!
        score += position.whitePawns & Bitboard.file((whiteIdx % 8) + 1)! == .empty ? -20 : 0

        let (blackIdx, _) = position.blackKing.popLSB()!
        score += position.blackPawns & Bitboard.file((blackIdx % 8) + 1)! == .empty ? 20 : 0
        
        return score
    }
    
    // MARK: - Pawn structure evaluation
    private func evaluatePawnStructure(position: BoardState) -> Int {
        var score = 0
        
        // Doubled pawns penalty
        for i in 1...8 {
            let file = Bitboard.file(i)!
            let whitePawnMask = position.whitePawns & file
            let blackPawnMask = position.blackPawns & file
            if whitePawnMask.nonzeroBitCount > 1 {
                score -= 20
            }
            if blackPawnMask.nonzeroBitCount > 1 {
                score += 20
            }
        }
        
        // TODO: Isolated pawns penalty
//        score -= 15 * position.whitePawns.countIsolatedPawns()
//        score += 15 * position.blackPawns.countIsolatedPawns()
        
        // Passed pawns bonus
        for i in 1...8 {
            let file = Bitboard.file(i)!
            let whitePawnMask = position.whitePawns & file
            let blackPawnMask = position.blackPawns & file
            if whitePawnMask > 0 && whitePawnMask & position.blackPawns == whitePawnMask {
                score += 30

            }
            if blackPawnMask > 0 && blackPawnMask & position.whitePawns == blackPawnMask {
                score -= 30
            }
        }
        
        return score
    }
    
    // MARK: - Placeholder NNUE evaluation
    private func evaluateNNUE(position: BoardState) -> Int {
        return evaluateStatic(position: position)
    }
    
    private func loadNNUE() {
        // Load NNUE weights if useNNUE = true
    }
}

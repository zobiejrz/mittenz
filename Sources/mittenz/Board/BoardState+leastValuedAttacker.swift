//
//  Game+leastValuedAttacker.swift
//  mittenz
//
//  Created by Ben Zobrist on 10/25/25.
//

import zChessKit
import zBitboard

extension BoardState {
    // Helper: return least-value attacker bitboard and its piece type (Pawn < Knight < Bishop < Rook < Queen < King)
    func leastValuedAttacker(from attackersBB: Bitboard, color: PlayerColor) -> (PieceType, Square)? {
        if attackersBB == .empty { return nil }
        
        let piece: PieceType?
        let square: Square?
        
        // check pieces by increasing value
        if color == .white {
            if let (idx, _) = (attackersBB & self.whitePawns).popLSB() {
                piece = .pawn
                square = Square(rawValue: idx)!
            } else if let (idx, _) = (attackersBB & self.whiteKnights).popLSB() {
                piece = .knight
                square = Square(rawValue: idx)!
            } else if let (idx, _) = (attackersBB & self.whiteBishops).popLSB() {
                piece = .bishop
                square = Square(rawValue: idx)!
            } else if let (idx, _) = (attackersBB & self.whiteRooks).popLSB() {
                piece = .rook
                square = Square(rawValue: idx)!
            } else if let (idx, _) = (attackersBB & self.whiteQueens).popLSB() {
                piece = .queen
                square = Square(rawValue: idx)!
            } else if let (idx, _) = (attackersBB & self.whiteKing).popLSB() {
                if attackersBB & ~self.whiteKing == .empty { // verify that capturing with the king is legal
                    piece = .king
                    square = Square(rawValue: idx)!
                } else {
                    piece = nil
                    square = nil
                }
            } else {
                piece = nil
                square = nil
            }
        } else {
            if let (idx, _) = (attackersBB & self.blackPawns).popLSB() {
                piece = .pawn
                square = Square(rawValue: idx)!
            } else if let (idx, _) = (attackersBB & self.blackKnights).popLSB() {
                piece = .knight
                square = Square(rawValue: idx)!
            } else if let (idx, _) = (attackersBB & self.blackBishops).popLSB() {
                piece = .bishop
                square = Square(rawValue: idx)!
            } else if let (idx, _) = (attackersBB & self.blackRooks).popLSB() {
                piece = .rook
                square = Square(rawValue: idx)!
            } else if let (idx, _) = (attackersBB & self.blackQueens).popLSB() {
                piece = .queen
                square = Square(rawValue: idx)!
            } else if let (idx, _) = (attackersBB & self.blackKing).popLSB() {
                if attackersBB & ~self.blackKing == .empty { // verify that capturing with the king is legal
                    piece = .king
                    square = Square(rawValue: idx)!
                } else {
                    piece = nil
                    square = nil
                }
            } else {
                piece = nil
                square = nil
            }
        }
        
        if let p = piece, let s = square {
            return (p, s)
        }
        
        return nil
    }
}

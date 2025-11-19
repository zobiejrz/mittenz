//
//  BoardState+attackersTo.swift
//  mittenz
//
//  Created by Ben Zobrist on 10/25/25.
//

import zChessKit
import zBitboard

extension BoardState {
    func attackersTo(_ sq: Square, color: PlayerColor, occupancy: Bitboard) -> Bitboard {
        // For pawns, knights, kings, they are independent of blockers (pawns depend on direction)
        // For sliders (bishop/rook/queen) you must compute sliding attacks using occupancy.
        var res: Bitboard = .empty
        
        // Pawns: pawn-attacks depend on color
        if color == .white {
            res |= (Bitboard.squareMask(sq).neShift() | Bitboard.squareMask(sq).nwShift()) & self.whitePawns
        } else {
            res |= (Bitboard.squareMask(sq).seShift() | Bitboard.squareMask(sq).swShift()) & self.blackPawns
        }
        
        // Knights
        res |= Square.generateKnightMoves(sq) & (color == .white ? self.whiteKnights : self.blackKnights)
        
        // Kings
        res |= (
            Bitboard.squareMask(sq).nShift() | Bitboard.squareMask(sq).neShift() |
            Bitboard.squareMask(sq).eShift() | Bitboard.squareMask(sq).seShift() |
            Bitboard.squareMask(sq).sShift() | Bitboard.squareMask(sq).swShift() |
            Bitboard.squareMask(sq).wShift() | Bitboard.squareMask(sq).nwShift()
        ) & (color == .white ? whiteKing : blackKing)
        
        // Bishops
        let bishopAttackers = Square.slidingBishopAttacks(at: sq, blockers: occupancy) & (color == .white ? self.whiteBishops : self.blackBishops)
        res |= bishopAttackers
        
        // Rooks
        let rookAttackers = Square.slidingRookAttacks(at: sq, blockers: occupancy) & (color == .white ? self.whiteRooks : self.blackRooks)
        res |= rookAttackers
        
        // Queens
        let queenAttackers = Square.slidingQueenAttacks(at: sq, blockers: occupancy) & (color == .white ? self.whiteQueens : self.blackQueens)
        res |= queenAttackers
        
        return res & occupancy
    }
}

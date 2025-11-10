//
//  Zobrist.swift
//  mittenz
//
//  Created by Ben Zobrist on 10/25/25.
//

import Foundation
import zChessKit
import zBitboard

final class Zobrist {
    private var pieceKeys: [[UInt64]] = Array(
        repeating: Array(repeating: 0, count: 64),
        count: 12
    )
    private var castlingKeys: [UInt64] = Array(repeating: 0, count: 4)
    private var enPassantKeys: [UInt64] = Array(repeating: 0, count: 8)
    private var sideToMoveKey: UInt64 = 0
    
    // Optional: deterministic RNG seed for reproducible hashing
    private let seed: UInt64
    
    init(seed: UInt64 = 0xABCDEF) {
        self.seed = seed
    }
    
    // MARK: - Initialization
    
    func initialize() {
        var rng = DeterministicRNG(seed: seed)
        
        for piece in 0..<12 {
            for sq in 0..<64 {
                pieceKeys[piece][sq] = rng.next()
            }
        }
        for i in 0..<4 { castlingKeys[i] = rng.next() }
        for i in 0..<8 { enPassantKeys[i] = rng.next() }
        sideToMoveKey = rng.next()
    }
    
    // MARK: - Hashing
    
    func hash(_ board: BoardState) -> UInt64 {
        var h: UInt64 = 0
        
        // 1. Pieces
        for square in Square.allCases {
            if let piece = board.whatPieceIsOn(square) {
                let color: PlayerColor = board.whitePieces & Bitboard.squareMask(square) != .empty ? .white : .black
                let index = zobristIndex(for: piece, color: color)
                h ^= pieceKeys[index][square.rawValue]
            }
        }
        
        // 2. Castling rights
        if board.castlingRights.contains(.K) { h ^= castlingKeys[0] }
        if board.castlingRights.contains(.Q) { h ^= castlingKeys[1] }
        if board.castlingRights.contains(.k) { h ^= castlingKeys[2] }
        if board.castlingRights.contains(.q) { h ^= castlingKeys[3] }
        
        // 3. En passant
        if let (epIdx, _) = board.enpassantTargetSquare.popLSB() {
            let f = epIdx % 8
            h ^= enPassantKeys[f]
        }
        
        // 4. Side to move
        if board.playerToMove == .black {
            h ^= sideToMoveKey
        }
        
        return h
    }
    
    // MARK: - Helpers
    
    private func zobristIndex(for piece: PieceType, color: PlayerColor) -> Int {
        let base: Int
        switch piece {
        case .pawn: base = 0
        case .knight: base = 1
        case .bishop: base = 2
        case .rook: base = 3
        case .queen: base = 4
        case .king: base = 5
        }
        return color == .white ? base : base + 6
    }
}

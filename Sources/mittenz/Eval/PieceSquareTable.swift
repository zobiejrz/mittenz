//
//  PieceSquareTable.swift
//  mittenz
//
//  Created by Ben Zobrist on 11/10/25.
//

import zBitboard
import zChessKit

struct PieceSquareTable {
    private static let pawnTable: [Int] = [
        0,   0,   0,   0,   0,   0,   0,   0,
        50,  50,  50,  50,  50,  50,  50,  50,
        10,  10,  20,  30,  30,  20,  10,  10,
        5,   5,  10,  25,  25,  10,   5,   5,
        0,   0,   0,  20,  20,   0,   0,   0,
        5,  -5, -10,   0,   0, -10,  -5,   5,
        5,  10,  10, -20, -20,  10,  10,   5,
        0,   0,   0,   0,   0,   0,   0,   0
    ]
    private static let pawnEndTable: [Int] = [
        0,   0,   0,   0,   0,   0,   0,   0,
        80,  80,  80,  80,  80,  80,  80,  80,
        50,  50,  50,  50,  50,  50,  50,  50,
        30,  30,  30,  30,  30,  30,  30,  30,
        20,  20,  20,  20,  20,  20,  20,  20,
        10,  10,  10,  10,  10,  10,  10,  10,
        10,  10,  10,  10,  10,  10,  10,  10,
        0,   0,   0,   0,   0,   0,   0,   0
    ]

    private static let knightTable: [Int] = [
        -50,-40,-30,-30,-30,-30,-40,-50,
         -40,-20,  0,  0,  0,  0,-20,-40,
         -30,  0, 10, 15, 15, 10,  0,-30,
         -30,  5, 15, 20, 20, 15,  5,-30,
         -30,  0, 15, 20, 20, 15,  0,-30,
         -30,  5, 10, 15, 15, 10,  5,-30,
         -40,-20,  0,  5,  5,  0,-20,-40,
         -50,-40,-30,-30,-30,-30,-40,-50
    ]
//    private static let knightEndTable: [Int] = []

    private static let bishopTable: [Int] = [
        -20,-10,-10,-10,-10,-10,-10,-20,
         -10,  0,  0,  0,  0,  0,  0,-10,
         -10,  0,  5, 10, 10,  5,  0,-10,
         -10,  5,  5, 10, 10,  5,  5,-10,
         -10,  0, 10, 10, 10, 10,  0,-10,
         -10, 10, 10, 10, 10, 10, 10,-10,
         -10,  5,  0,  0,  0,  0,  5,-10,
         -20,-10,-10,-10,-10,-10,-10,-20
    ]
//    private static let bishopEndTable: [Int] = [...]

    private static let rookTable: [Int] = [
        0,  0,  0,  0,  0,  0,  0,  0,
        5, 10, 10, 10, 10, 10, 10,  5,
        -5,  0,  0,  0,  0,  0,  0, -5,
        -5,  0,  0,  0,  0,  0,  0, -5,
        -5,  0,  0,  0,  0,  0,  0, -5,
        -5,  0,  0,  0,  0,  0,  0, -5,
        -5,  0,  0,  0,  0,  0,  0, -5,
        0,  0,  0,  5,  5,  0,  0,  0
    ]
//    private static let rookEndTable: [Int] = [...]

    private static let queenTable: [Int] = [
        -20,-10,-10, -5, -5,-10,-10,-20,
         -10,  0,  0,  0,  0,  0,  0,-10,
         -10,  0,  5,  5,  5,  5,  0,-10,
         -5,   0,  5,  5,  5,  5,  0, -5,
         0,    0,  5,  5,  5,  5,  0, -5,
         -10,  5,  5,  5,  5,  5,  0,-10,
         -10,  0,  5,  0,  0,  0,  0,-10,
         -20,-10,-10, -5, -5,-10,-10,-20
    ]
//    private static let queenEndTable: [Int] = [...]

    private static let kingTable: [Int] = [
        -80, -70, -70, -70, -70, -70, -70, -80,
         -60, -60, -60, -60, -60, -60, -60, -60,
         -40, -50, -50, -60, -60, -50, -50, -40,
         -30, -40, -40, -50, -50, -40, -40, -30,
         -20, -30, -30, -40, -40, -30, -30, -20,
         -10, -20, -20, -20, -20, -20, -20, -10,
         20,  20,  -5,  -5,  -5,  -5,  20,  20,
         20,  30,  10,   0,   0,  10,  30,  20
    ]
    private static let kingEndTable: [Int] = [
        -20, -10, -10, -10, -10, -10, -10, -20,
         -5,   0,   5,   5,   5,   5,   0,  -5,
         -10, -5,   20,  30,  30,  20,  -5, -10,
         -15, -10,  35,  45,  45,  35, -10, -15,
         -20, -15,  30,  40,  40,  30, -15, -20,
         -25, -20,  20,  25,  25,  20, -20, -25,
         -30, -25,   0,   0,   0,   0, -25, -30,
         -50, -30, -30, -30, -30, -30, -30, -50
    ]
    
    
    public static func read(piece: PieceType, square: Square, isWhite: Bool, ratio: Double) -> Int {
        precondition((0...1).contains(ratio), "The ratio must be between 0 (pure opening table) and 1 (pure endgame table)")
        
        // Compute index (flip for black since tables are from white’s perspective)
        let idx: Int
        if isWhite {
            idx = square.rawValue
        } else {
            let r = Int(square.rawValue / 8)
            let f = square.rawValue % 8
            idx = (7 - r) + f
        }
        
        // Pick correct piece-square tables
        let (openTable, endTable): ([Int], [Int])
        switch piece {
        case .pawn:
            (openTable, endTable) = (pawnTable, pawnEndTable)
        case .knight:
            (openTable, endTable) = (knightTable, knightTable) // These are the same until I make separate tables
        case .bishop:
            (openTable, endTable) = (bishopTable, bishopTable) // These are the same until I make separate tables
        case .rook:
            (openTable, endTable) = (rookTable, rookTable) // These are the same until I make separate tables
        case .queen:
            (openTable, endTable) = (queenTable, queenTable) // These are the same until I make separate tables
        case .king:
            (openTable, endTable) = (kingTable, kingEndTable)
        }
        
        // Linear blend between opening and endgame scores
        let openVal = openTable[idx]
        let endVal = endTable[idx]
        let blended = (Double(openVal) * (1.0 - ratio)) + (Double(endVal) * (ratio))
        
        return Int(blended.rounded())
    }
    
}

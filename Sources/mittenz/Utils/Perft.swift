//
//  Perft.swift
//  mittenz
//
//  Created by Ben Zobrist on 10/23/25.
//

import zChessKit

enum Perft {
    static func run(board: BoardState, depth: Int) -> UInt64 {
        if depth == 0 { return 1 }
        var total: UInt64 = 0
        for move in board.generateAllLegalMoves() {
            total += run(board: move.resultingBoardState, depth: depth - 1)
        }
        return total
    }
}

//
//  TTEntry.swift
//  mittenz
//
//  Created by Ben Zobrist on 10/25/25.
//

import zChessKit

enum TTFlag {
    case exact, lowerBound, upperBound
}

struct TTEntry {
    let key: UInt64
    let value: Int
    let depth: Int
    let flag: TTFlag
    let bestMove: Move?
}

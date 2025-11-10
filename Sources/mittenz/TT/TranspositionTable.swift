//
//  TranspositionTable.swift
//  mittenz
//
//  Created by Ben Zobrist on 10/25/25.
//

import zChessKit

final class TranspositionTable {
    private let size: Int
    private var table: [TTEntry?]
    
    init(sizeMB: Int = 64) {
        // Each entry ≈ 32 bytes; 1MB ≈ 32k entries
        self.size = (sizeMB * 1024 * 1024) / MemoryLayout<TTEntry>.stride
        self.table = Array(repeating: nil, count: size)
    }
    
    func probe(_ key: UInt64) -> TTEntry? {
        let index = Int(key % UInt64(size))
        if let entry = table[index], entry.key == key {
            return entry
        }
        return nil
    }
    
    func store(_ key: UInt64, value: Int, depth: Int, flag: TTFlag, bestMove: Move?) {
        let index = Int(key % UInt64(size))
        if let existing = table[index] {
            // Replace only if deeper or new key
            if existing.key == key && existing.depth > depth {
                return
            }
        }
        table[index] = TTEntry(key: key, value: value, depth: depth, flag: flag, bestMove: bestMove)
    }
}

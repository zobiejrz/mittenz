//
//  SkillSetting.swift
//  mittenz
//
//  Created by Ben Zobrist on 10/23/25.
//

public struct SkillSetting {
    /// Approximate maximum centipawn loss allowed relative to best move
    public let maxCentipawnLoss: Int
    
    /// Initialize with level and optional max centipawn loss
    public init(maxCentipawnLoss: Int = 0) {
        self.maxCentipawnLoss = maxCentipawnLoss
    }
}

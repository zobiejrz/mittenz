//
//  TimeLimit.swift
//  mittenz
//
//  Created by Ben Zobrist on 10/23/25.
//

public enum TimeLimit: Equatable {
    case infinite, byDepth(Int), byMillis(Int)
        
    /// Helper: returns `true` if this is a fixed-depth search
    public var isDepthLimited: Bool {
        if case .byDepth = self { return true }
        return false
    }
    
    /// Helper: returns `true` if this is a time-limited search
    public var isTimeLimited: Bool {
        if case .byMillis = self { return true }
        return false
    }
    
    /// Helper: get associated value if available
    public var value: Int? {
        switch self {
        case .byDepth(let d), .byMillis(let d): return d
        default: return nil
        }
    }
}

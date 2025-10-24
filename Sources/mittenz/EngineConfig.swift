//
//  EngineConfig.swift
//  mittenz
//
//  Created by Ben Zobrist on 10/23/25.
//

public struct EngineConfig: Sendable, Codable, Hashable {
    public var threads: Int
    
    /// Hash table size in megabytes
    public var hashSizeMB: Int
    
    /// Initial position FEN (defaults to standard start position)
    public var startFEN: String
    
    /// Optional opening book path or resource
    public var openingBookPath: String?
    
    /// Whether to enable NNUE or other advanced eval features
    public var useNNUE: Bool
    
    /// Optional logging control
    public var enableLogging: Bool
    
    public init(
        threads: Int = 1,
        hashSizeMB: Int = 64,
        startFEN: String = "startpos", // TODO: UPDATE THIS
        openingBookPath: String? = nil,
        useNNUE: Bool = false,
        enableLogging: Bool = false
    ) {
        self.threads = max(1, threads)
        self.hashSizeMB = hashSizeMB
        self.startFEN = startFEN
        self.openingBookPath = openingBookPath
        self.useNNUE = useNNUE
        self.enableLogging = enableLogging
    }
    
    /// Convenience default config
    public static let `default` = EngineConfig()
}

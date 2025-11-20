//
//  UCILoop.swift
//  mittenz
//
//  Created by Ben Zobrist on 10/23/25.
//

import zChessKit

@available(iOS 13.0.0, *)
@available(macOS 10.15.0, *)
public final class UCILoop {
    private var engine: Engine
    
    public init(engine: Engine) {
        self.engine = engine
    }
    
    public func run() async {
        print("Mittenz engine ready. (UCI loop)")
        
        while let line = readLine() {
            let tokens = line.split(separator: " ")
            guard let command = tokens.first else { continue }
            
            switch command {
            case "uci":
                print("id name Mittenz")
                print("id author zobiejrz")
                print("uciok")
                
            case "isready":
                print("readyok")
                
            case "ucinewgame":
                engine.setFEN("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1") // reset board
                
            case "position":
                parsePosition(tokens: Array(tokens.dropFirst()))
                
            case "go":
                await parseGo(tokens: Array(tokens.dropFirst()))
                
            case "stop":
                engine.stopSearch() // implement stop flag in engine
                
            case "d":
                print(engine.currentState().boardString())
                print("\nFEN: \(engine.currentState().getFEN())")
                
            case "quit":
                return
                
            default:
                continue
            }
        }
    }
    
    // MARK: - Position Parsing
    private func parsePosition(tokens: [Substring]) {
        var idx = 0
        var fen: String = "startpos"
        var moves: [String] = []
        
        if idx < tokens.count {
            if tokens[idx] == "startpos" {
                fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
                idx += 1
            } else if tokens[idx] == "fen" {
                idx += 1
                var fenParts: [String] = []
                while idx < tokens.count && tokens[idx] != "moves" {
                    fenParts.append(String(tokens[idx]))
                    idx += 1
                }
                fen = fenParts.joined(separator: " ")
            }
        }
        
        if idx < tokens.count && tokens[idx] == "moves" {
            idx += 1
            while idx < tokens.count {
                moves.append(String(tokens[idx]))
                idx += 1
            }
        }
        
        engine.setFEN(fen)
        for move in moves {
            engine.makeMoveFromUCI(move)
        }
    }
    
    // MARK: - Go Parsing
    private func parseGo(tokens: [Substring]) async {
        var timeLimit: TimeLimit = .infinite
        let skill: SkillSetting = SkillSetting(maxCentipawnLoss: 0)
        
        var idx = 0
        while idx < tokens.count {
            let token = tokens[idx]
            switch token {
            case "depth":
                if idx + 1 < tokens.count, let d = Int(tokens[idx + 1]) {
                    timeLimit = .byDepth(d)
                    idx += 1
                }
            case "movetime":
                if idx + 1 < tokens.count, let ms = Int(tokens[idx + 1]) {
                    timeLimit = .byMillis(ms)
                    idx += 1
                }
            case "wtime", "btime", "winc", "binc":
                // Ignore for now
                idx += 1
                if idx < tokens.count { idx += 1 }
            default:
                break
            }
            idx += 1
        }
        
        // Run search
        if let bestMove = await engine.searchBestMove(timeLimit: timeLimit, skill: skill) {
            print("bestmove \(bestMove.uci)")
        }
    }
    
    public func playMove(_ move: Move) {
        engine.makeMoveFromUCI(move.uci)
    }
    
    /// Apply a move from a UCI string (e.g., "e2e4")
    public func playMove(_ uci: String) {
        engine.makeMoveFromUCI(uci)
    }
}

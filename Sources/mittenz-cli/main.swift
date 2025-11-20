//
//  main.swift
//  mittenz
//
//  Created by Ben Zobrist on 10/23/25.
//

import Foundation
import mittenz
import zChessKit

@available(iOS 13.0.0, *)
@available(macOS 10.15.0, *)
func selfPlayDemo(engine: Engine, moveLimit: Int = 100, timePerMove: Int = 500) async {
    let uciLoop = UCILoop(engine: engine)
    engine.setFEN("startpos") // start from initial position
    
    let game = Game()
    var movesPlayed = 0
    
    print("Starting self-play...")
    
    while movesPlayed < moveLimit {
        // Check for terminal state
        if game.getGameResult() != .ongoing {
            print("Game ended: \([.whiteWon, .blackWon].contains(game.getGameResult()) ? "Checkmate" : "Stalemate")")
            break
        }
        
        // Engine searches best move
        let bestMove = await engine.searchBestMove(
            timeLimit: .byMillis(timePerMove),
            skill: SkillSetting(maxCentipawnLoss: 0) // you could vary skill for weaker/stronger players
        )!
        
        // Apply move
        game.makeUCIMove(bestMove.uci)
        movesPlayed += 1
        
        let sign = engine.currentState().playerToMove == .white ? 1 : -1
        print("Ply \(movesPlayed) (\(engine.currentState().playerToMove == .white ? "White" : "Black"), \(sign * engine.evaluate(position: bestMove.resultingBoardState, depth: 5))): \(bestMove.uci)")
    }
    
    // Final FEN after self-play
    print("\nFinal position:\n\(engine.currentState().boardString())")
    
    // Optional: print the full game in UCI format
    let fullGameUCI = game.getPGN()//  moveHistory.map { $0.uci }.joined(separator: " ")
    print("\nMoves played (PGN):\n\(fullGameUCI)")
}

// Create engine config
let config = EngineConfig() // fill in defaults if needed
if #available(iOS 13.0, macOS 10.15, *) {
    let engine = Engine(config: config)
    
    await selfPlayDemo(engine: engine, moveLimit: 120, timePerMove: 2000)
    
    //    UCILoop(engine: engine).run()
} else {
    // Fallback on earlier versions
}

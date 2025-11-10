//
//  main.swift
//  mittenz
//
//  Created by Ben Zobrist on 10/23/25.
//

import Foundation
import mittenz
import zChessKit

func selfPlayDemo(engine: Engine, moveLimit: Int = 100, timePerMove: Int = 500) {
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
        let bestMove = engine.searchBestMove(
            timeLimit: .byMillis(timePerMove),
            skill: SkillSetting(maxCentipawnLoss: 0) // you could vary skill for weaker/stronger players
        )!
        
        // Apply move
        uciLoop.playMove(bestMove)
        game.makeUCIMove(bestMove.uci)
        movesPlayed += 1
        
        print("Move \(movesPlayed) (\(engine.currentState().playerToMove == .white ? "White" : "Black"), \(engine.evaluate(position: bestMove.resultingBoardState, depth: 1))): \(bestMove.uci)")
    }
    
    // Final FEN after self-play
    print("\nFinal position:\n\(engine.currentState().boardString())")
    
    // Optional: print the full game in UCI format
    let fullGameUCI = game.getPGN()//  moveHistory.map { $0.uci }.joined(separator: " ")
    print("\nMoves played (PGN):\n\(fullGameUCI)")
}

// Create engine config
let config = EngineConfig() // fill in defaults if needed
let engine = Engine(config: config)
selfPlayDemo(engine: engine, moveLimit: 100, timePerMove: 2000)

//UCILoop(engine: engine).run()

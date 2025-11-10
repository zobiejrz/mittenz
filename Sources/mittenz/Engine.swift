//
//  Engine.swift
//  mittenz
//
//  Created by Ben Zobrist on 10/23/25.
//

import Foundation
import zChessKit

public final class Engine {
    
    // MARK: - Internal State
    
    private var board: BoardState
    private var config: EngineConfig
    private var threads: Int
    private let evaluator: Evaluator
    private let search: SearchController
    private(set) var stopSearchFlag = false
    
    // MARK: - Init
    
    public init(config: EngineConfig = .default) {
        self.config = config
        self.threads = config.threads
        let board = BoardState.fromFEN(config.startFEN) ?? BoardState.startingPosition()
        self.board = board
        self.evaluator = Evaluator()
        self.search = SearchController(
            board: board,
            evaluator: evaluator
        )
//        if config.enableLogging {
//            Logger.shared.enable()
//        }
    }
    
    // MARK: - Position Control
    
    public func setFEN(_ fen: String) {
        if let newBoard = BoardState.fromFEN(fen) {
            self.board = newBoard
        } else {
            print("Engine: Invalid FEN string, keeping previous position.")
        }
    }
    
    public func currentState() -> BoardState {
        return board
    }
    
    // MARK: - Search
    
    public func searchBestMove(timeLimit: TimeLimit, skill: SkillSetting? = nil) -> Move? {
        resetStopFlag()
        let skillSetting = skill ?? SkillSetting(maxCentipawnLoss: 0)
        let move = self.search.bestMove(
            timeLimit: timeLimit
        )
        
        // Apply move to internal board state
        board = move.resultingBoardState
        self.search.setBoard(move.resultingBoardState)
        return move
    }
    
    // MARK: - Evaluation
    
    public func evaluate(position: BoardState, depth: Int = 0) -> Int {
        return evaluator.evaluate(position: position)
    }
    
    // MARK: - Perft (Movegen Accuracy Test)
    
    public func perft(depth: Int) -> UInt64 {
        return Perft.run(board: board, depth: depth)
    }
    
    // MARK: - Settings
    
//    public func setThreads(_ n: Int) {
//        threads = max(1, n)
//        search.setThreads(threads)
//    }
    
    // MARK: - UCI Protocol (optional)
    
    public func uciLoop() {
        let uci = UCILoop(engine: self)
        uci.run()
    }
    
    func makeMoveFromUCI(_ uci: String) {
        let legalMoves = board.generateAllLegalMoves() // each move has resultingBoardState
        
        if let move = legalMoves.first(where: { $0.uci == uci }) {
            // Apply the move
            board = move.resultingBoardState
        } else {
//            Logger.log("Warning: invalid UCI move '\(uci)' for current position")
        }
    }
    
    var stop: Bool {
        return stopSearchFlag // TODO: Don't use this value yet
    }
    
    public func stopSearch() {
        stopSearchFlag = true
    }
    
    private func resetStopFlag() {
        stopSearchFlag = false
    }
}

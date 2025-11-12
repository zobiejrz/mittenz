import Testing
import zChessKit
import zBitboard
@testable import mittenz

@Test func example() async throws {
    // Write your test here and use APIs like `#expect(...)` to check expected conditions.
}

@Test func SEETest() async throws {
    let fen = "7r/8/6pq/4N3/7k/8/6QK/7R w - - 0 1"
//    let fen = "1k1r4/1pp4p/p7/4p3/8/P5P1/1PP4P/2K1R3 w - - 0 1"
    
    let lexer = Lexer.getFENLexer()
    let tokens = try! lexer.run(input: fen)
    let state = try! Parser.parseFEN(from: tokens).first!
    
    let evaluator = Evaluator()
    
    print(evaluator.staticExchangeEval(square: .g6, position: state, targetPiece: .pawn, targetColor: .black))
//    print(evaluator.staticExchangeEval(square: .e5, position: state, targetPiece: .pawn, targetColor: .black))

}

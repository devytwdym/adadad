local ChessEngine = {}

-- Simple move generator for demonstration (returns common opening moves)
function ChessEngine.GetBestMove(fen, maxNodes)
    local moves = { "e2e4", "d2d4", "g1f3", "c2c4" }
    return moves[math.random(1, #moves)]
end

return ChessEngine

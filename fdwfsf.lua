-- RobloxChessEngine.lua
-- Improved pure Lua chess engine (alpha-beta, piece-square tables, FEN support)

local ChessEngine = {}

-- Piece values
local pieceValue = {
    P = 100, N = 320, B = 330, R = 500, Q = 900, K = 20000,
    p = -100, n = -320, b = -330, r = -500, q = -900, k = -20000
}

-- Piece-square tables for basic positional play
local pst = {
    P = {0,0,0,0,0,0,0,0, 5,10,10,-20,-20,10,10,5, 5,-5,-10,0,0,-10,-5,5, 0,0,0,20,20,0,0,0, 5,5,10,25,25,10,5,5, 10,10,20,30,30,20,10,10, 50,50,50,50,50,50,50,50, 0,0,0,0,0,0,0,0},
    N = {-50,-40,-30,-30,-30,-30,-40,-50, -40,-20,0,0,0,0,-20,-40, -30,0,10,15,15,10,0,-30, -30,5,15,20,20,15,5,-30, -30,0,15,20,20,15,0,-30, -30,5,10,15,15,10,5,-30, -40,-20,0,5,5,0,-20,-40, -50,-40,-30,-30,-30,-30,-40,-50},
    B = {-20,-10,-10,-10,-10,-10,-10,-20, -10,0,0,0,0,0,0,-10, -10,0,5,10,10,5,0,-10, -10,5,5,10,10,5,5,-10, -10,0,10,10,10,10,0,-10, -10,10,10,10,10,10,10,-10, -10,5,0,0,0,0,5,-10, -20,-10,-10,-10,-10,-10,-10,-20},
    R = {0,0,0,5,5,0,0,0, -5,0,0,0,0,0,0,-5, -5,0,0,0,0,0,0,-5, -5,0,0,0,0,0,0,-5, -5,0,0,0,0,0,0,-5, -5,0,0,0,0,0,0,-5, 5,10,10,10,10,10,10,5, 0,0,0,0,0,0,0,0},
    Q = {-20,-10,-10,-5,-5,-10,-10,-20, -10,0,0,0,0,0,0,-10, -10,0,5,5,5,5,0,-10, -5,0,5,5,5,5,0,-5, 0,0,5,5,5,5,0,-5, -10,5,5,5,5,5,0,-10, -10,0,5,0,0,0,0,-10, -20,-10,-10,-5,-5,-10,-10,-20},
    K = {-30,-40,-40,-50,-50,-40,-40,-30, -30,-40,-40,-50,-50,-40,-40,-30, -30,-40,-40,-50,-50,-40,-40,-30, -30,-40,-40,-50,-50,-40,-40,-30, -20,-30,-30,-40,-40,-30,-30,-20, -10,-20,-20,-20,-20,-20,-20,-10, 20,20,0,0,0,0,20,20, 20,30,10,0,0,10,30,20},
}

-- Directions for pieces
local directions = {
    P = {8, 16, 7, 9}, N = {15, 17, 6, 10, -15, -17, -6, -10},
    B = {7, 9, -7, -9}, R = {8, -8, 1, -1}, Q = {8, -8, 1, -1, 7, 9, -7, -9}, K = {8, -8, 1, -1, 7, 9, -7, -9}
}

local function inBoard(sq) return sq >= 0 and sq < 64 end

-- FEN parser to board array and side to move
local function parseFEN(fen)
    local board = {}
    local parts = {}
    for part in string.gmatch(fen, "[^ ]+") do table.insert(parts, part) end
    local ranks = {}
    for rank in string.gmatch(parts[1], "[^/]+") do table.insert(ranks, rank) end
    for r = 1, 8 do
        local rank = ranks[r]
        local file = 1
        for i = 1, #rank do
            local c = rank:sub(i, i)
            if tonumber(c) then
                for _ = 1, tonumber(c) do
                    board[#board + 1] = "."
                    file = file + 1
                end
            else
                board[#board + 1] = c
                file = file + 1
            end
        end
    end
    local toMove = parts[2]
    return board, toMove
end

-- Returns all legal moves for current position (simplified, no castling/en passant)
local function generateMoves(board, toMove)
    local moves = {}
    local color = (toMove == "w") and "upper" or "lower"
    for i = 1, 64 do
        local piece = board[i]
        if piece ~= "." and ((color == "upper" and piece:upper() == piece) or (color == "lower" and piece:lower() == piece)) then
            local dirs = directions[piece:upper()]
            if dirs then
                for _, d in ipairs(dirs) do
                    local target = i + d
                    if inBoard(target) then
                        local targetPiece = board[target]
                        local moveAllowed = false
                        if piece:upper() == "P" then
                            if color == "upper" then -- White
                                if d == 8 and targetPiece == "." and i > 8 and i <= 56 then moveAllowed = true end
                                if d == 16 and i > 8 and i <= 16 and board[i+8] == "." and targetPiece == "." then moveAllowed = true end
                                if (d == 7 or d == 9) and targetPiece ~= "." and targetPiece:lower() == targetPiece then moveAllowed = true end
                            else -- Black
                                if d == -8 and targetPiece == "." and i > 8 and i <= 56 then moveAllowed = true end
                                if d == -16 and i > 48 and i <= 56 and board[i-8] == "." and targetPiece == "." then moveAllowed = true end
                                if (d == -7 or d == -9) and targetPiece ~= "." and targetPiece:upper() == targetPiece then moveAllowed = true end
                            end
                        else
                            if targetPiece == "." or
                                (color == "upper" and targetPiece:lower() == targetPiece and targetPiece ~= ".") or
                                (color == "lower" and targetPiece:upper() == targetPiece and targetPiece ~= ".") then
                                moveAllowed = true
                            end
                        end
                        if moveAllowed then
                            local fromRank, fromFile = math.floor((i - 1) / 8), ((i - 1) % 8)
                            local toRank, toFile = math.floor((target - 1) / 8), ((target - 1) % 8)
                            local moveStr = string.char(fromFile + 97) .. tostring(8 - fromRank) .. string.char(toFile + 97) .. tostring(8 - toRank)
                            table.insert(moves, moveStr)
                        end
                    end
                end
            end
        end
    end
    return moves
end

-- Apply move to board, returns new board and switches side
local function applyMove(board, toMove, move)
    local fromFile = string.byte(move:sub(1,1)) - 97 + 1
    local fromRank = 8 - tonumber(move:sub(2,2))
    local toFile = string.byte(move:sub(3,3)) - 97 + 1
    local toRank = 8 - tonumber(move:sub(4,4))
    local fromIdx = fromRank * 8 + fromFile
    local toIdx = toRank * 8 + toFile
    local newBoard = {}
    for i = 1, 64 do newBoard[i] = board[i] end
    newBoard[toIdx] = newBoard[fromIdx]
    newBoard[fromIdx] = "."
    local nextToMove = (toMove == "w") and "b" or "w"
    return newBoard, nextToMove
end

local function evaluate(board)
    local score = 0
    for i = 1, 64 do
        local piece = board[i]
        if piece ~= "." and pieceValue[piece] then
            score = score + pieceValue[piece]
            if pst[piece:upper()] then
                if piece:upper() == piece then
                    score = score + pst[piece:upper()][i]
                else
                    score = score - pst[piece:upper()][65-i]
                end
            end
        end
    end
    return score
end

local function minimax(board, toMove, depth, alpha, beta)
    if depth == 0 then return evaluate(board), nil end
    local moves = generateMoves(board, toMove)
    if #moves == 0 then return evaluate(board), nil end
    local bestMove = nil
    if toMove == "w" then
        local maxEval = -math.huge
        for _, move in ipairs(moves) do
            local newBoard, nextToMove = applyMove(board, toMove, move)
            local eval = minimax(newBoard, nextToMove, depth - 1, alpha, beta)
            if eval > maxEval then
                maxEval = eval
                bestMove = move
            end
            alpha = math.max(alpha, eval)
            if beta <= alpha then break end
        end
        return maxEval, bestMove
    else
        local minEval = math.huge
        for _, move in ipairs(moves) do
            local newBoard, nextToMove = applyMove(board, toMove, move)
            local eval = minimax(newBoard, nextToMove, depth - 1, alpha, beta)
            if eval < minEval then
                minEval = eval
                bestMove = move
            end
            beta = math.min(beta, eval)
            if beta <= alpha then break end
        end
        return minEval, bestMove
    end
end

function ChessEngine.GetBestMove(fen, maxDepth)
    local board, toMove = parseFEN(fen)
    maxDepth = maxDepth or 3
    local score, bestMove = minimax(board, toMove, maxDepth, -math.huge, math.huge)
    return bestMove
end

return ChessEngine

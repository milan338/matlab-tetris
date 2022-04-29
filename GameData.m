classdef GameData < handle
    properties
        ROWS = 20
        COLS = 10
        level = 0
        playfield = []
        xPos = 0
        yPos = 0
        currentPiece = []
        lastPiecePos = []
        lastTime = 0
        canInput = false
    end
end


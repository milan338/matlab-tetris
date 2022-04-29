% Clear workspace, command window, and existing figures
clear all; %#ok<CLALL>
close all;
clc;

pause('on');

gd = GameData;

CENTRE_COLUMN = 5;
FPS = 120;
PLOT_UPDATE_DELAY = 0.00000000001;
ANIM_DELAY = 0.01;
LEVEL_DURATION = 120;

while gd.level < 1 || gd.level > 15
    gd.level = input('What level do you want to start at? [1 - 15] : ');
end
initLevel = gd.level;

SHAPE_I = [
    0, 0, 0, 0;
    1, 1, 1, 1;
    0, 0, 0, 0;
    0, 0, 0, 0];
SHAPE_J = [
    2, 0, 0;
    2, 2, 2;
    0, 0, 0];
SHAPE_L = [
    0, 0, 3;
    3, 3, 3;
    0, 0, 0];
SHAPE_O = [
    4, 4;
    4, 4];
SHAPE_S = [
    0, 5, 5;
    5, 5, 0;
    0, 0, 0];
SHAPE_T = [
    0, 6, 0;
    6, 6, 6;
    0, 0, 0];
SHAPE_Z = [
    7, 7, 0;
    0, 7, 7;
    0, 0, 0];

pieces = {SHAPE_I, SHAPE_J, SHAPE_L, SHAPE_O, SHAPE_S, SHAPE_T, SHAPE_Z};

% Add additional row and column as pcolor removes the last row and column
gd.playfield = zeros(gd.ROWS + 1, gd.COLS + 1);

% Set the hidden row of playfield to show contain all colours, otherwise
% Colours do not display properly
gd.playfield(end, :) = [1, 2, 3, 4, 5, 6, 7, 8, 1, 1, 1];

figure;

subplot(1, 2, 1);
playfieldPlot = pcolor(gd.playfield);
levelTitle = title('Level 0');
scoreTitle = subtitle('Score: 0');
axis off;
axis equal;

nextPieceSubplot = subplot(1, 2, 2);
% 2D array for next-piece plot - extra numbers to enable all colours
% pcolor will ignore the bottommost row and rightmost column
nextPieceArr = [
    0, 0, 0, 0, 1; ...
    0, 0, 0, 0, 8; ...
    0, 0, 0, 0, 7; ...
    0, 0, 0, 0, 6; ...
    1, 2, 3, 4, 5];
nextPiecePlot = pcolor(nextPieceArr);
npspPos = get(nextPieceSubplot, 'position');
set(nextPieceSubplot, 'position', [
    npspPos(1) + npspPos(3) / 5, ...
    npspPos(2) + npspPos(4) / 4, ...
    npspPos(3) / 2, ...
    npspPos(4) / 2]);
title('Next Piece...');
axis off;
axis equal;

% Colours for plot and pieces
colormap([ ...
    1, 1, 1; ...
    0, 0.5, 1;...
    1, 0.5, 0; ...
    1, 0.8, 0; ...
    0.25, 0, 1; ...
    0.5, 1, 0; ...
    1, 0, 1; ...
    1, 0, 0; ...
    0, 0, 0]);

set(gcf, 'Name', 'Tetris', 'NumberTitle', 'off');
set(gcf, 'WindowKeyPressFcn', {@onKeyPress, gd});

startTime = now();
lastFrameTime = now();
fallDelay = 1;
score = 0;
nextPiece = pieces{randi(length(pieces))};

% Game loop
while true
    % Allow input for this frame
    gd.canInput = true;

    % Last piece finished falling
    if gd.yPos <= 1
        gd.currentPiece = nextPiece;
        nextPiece = pieces{randi(length(pieces))};
        % Clear next-piece plot
        nextPiecePlot.CData = nextPieceArr;
        % Update next-piece plot with new next piece
        [rows, cols] = size(nextPiece);
        nextPiecePlot.CData(1:rows, 1:cols) = flip(nextPiece, 1);
        % Reset piece positions
        gd.yPos = gd.ROWS;
        gd.xPos = CENTRE_COLUMN - ceil(size(gd.currentPiece, 2) / 2) + 1;
        % Set last piece buffer to offscreen element for intersection check
        gd.lastPiecePos = [gd.ROWS + 1, gd.COLS + 1];
        % Check if piece will intersect
        [validIntersection] = getValidIntersection( ...
            gd, gd.currentPiece, gd.xPos, gd.yPos, '', 0, true);
        % Lose if the new piece collides
        if ~validIntersection
            close gcf;
            error('\n\nYou lose. Score: %.0f', score);
        end
        % Clear the last piece buffer
        gd.lastPiecePos = [];
    end

    % Restrict game updates to once per frame
    if (now() - lastFrameTime) * 10 ^ 5 > 1 / FPS
        % Prevent user input in this critical section
        gd.canInput = false;
        lastFrameTime = now();
        % Clear the previous piece only if piece moved or rotated
        if ~isempty(gd.lastPiecePos)
            % Loop over all cells to wipe - each column represents a cell
            for i = 1:size(gd.lastPiecePos, 1)
                xToWipe = gd.lastPiecePos(i, 1);
                yToWipe = gd.lastPiecePos(i, 2);
                gd.playfield(xToWipe, yToWipe) = 0;
            end
            % Clear the last piece buffer
            gd.lastPiecePos = [];
        end

        % Draw the piece in its new position
        [pieceRows, pieceCols] = size(gd.currentPiece);
        for row = 1:pieceRows
            for col = 1:pieceCols
                cellToPlace = gd.currentPiece(row, col);
                % Only place non-empty matrix cells, ignore empty space
                if cellToPlace
                    % Place the individual piece cell into the playfield
                    fieldRow = gd.yPos - row + 1;
                    fieldCol = gd.xPos + col - 1;
                    gd.playfield(fieldRow, fieldCol) = cellToPlace;
                    % Add cell to the last cell buffer for removal next frame
                    lastCell = [fieldRow, fieldCol];
                    gd.lastPiecePos = [gd.lastPiecePos; lastCell];
                end
            end
        end
        
        % Update vertical position
        if (now() - gd.lastTime) * 10 ^ 5 > fallDelay
            gd.lastTime = now();
            % Calculate current level from game duration
            gd.level = floor( ...
                ((gd.lastTime - startTime) * 10 ^ 5 + ...
                (initLevel * LEVEL_DURATION)) / LEVEL_DURATION);
            % Update current level and score titles
            levelTitle.String = sprintf('Level %d', gd.level);
            scoreTitle.String = sprintf('Score: %.0f', score);
            % Calculate new fall delay using delay = e^-0.25(x-1)
            fallDelay = exp(-0.25 * (gd.level - 1));
            % Colliding from bottom
            if isBoundCollision(gd, 'down')
                % Set not falling flag
                gd.yPos = 0;
                % Scan for filled rows
                filledRows = [];
                for row = 1:gd.ROWS
                    % If row not filled, any zero entries will make prod 0
                    if prod(gd.playfield(row, 1:gd.COLS))
                        filledRows = [filledRows, row]; %#ok<AGROW>
                    end
                end
                % Clear rows
                if filledRows
                    % Animate clearing 1 column at a time from left
                    for col = 1:gd.COLS
                        for i = 1:length(filledRows)
                            % Remove cell from playfield and update plot
                            gd.playfield(filledRows(i), col) = 0;
                            playfieldPlot.CData = gd.playfield;
                            % Pause gameloop to animate and redraw figure
                            pause(ANIM_DELAY);
                        end
                    end
                    % Shift rows down, from top down
                    for i = length(filledRows):-1:1
                        row = filledRows(i);
                        % Move everything above the filled row down 1
                        gd.playfield(row:gd.ROWS - 1, 1:gd.COLS) = ...
                            gd.playfield(row + 1:gd.ROWS, 1:gd.COLS);
                    end
                    n = length(filledRows);
                    scores = [100, 300, 500, 800];
                    % Add new score to running total
                    score = score + (scores(n) * gd.level);
                end
            end
            % Move the vertical position of the piece down 1
            gd.yPos = gd.yPos - 1;
        end

        % Update the plot with the new playfield
        playfieldPlot.CData = gd.playfield;
        % Pause the gameloop for a short time so the figure can redraw
        pause(PLOT_UPDATE_DELAY);
    end

    % Enable input just before delay
    gd.canInput = true;
    % Pause the gameloop for a short time so the figure can redraw
    pause(PLOT_UPDATE_DELAY);
end

% User input callback
function onKeyPress(~, event, gd)
    if ~gd.canInput
        return;
    end
    % Time in seconds to speed up falling of the piece on down arrow
    downArrowBoost = 2 * gd.level;
    % Handle input
    switch event.Key
        case 'leftarrow'
            if isBoundCollision(gd, 'left')
                return;
            end
            gd.xPos = gd.xPos - 1;
        case 'rightarrow'
            if isBoundCollision(gd, 'right')
                return;
            end
            gd.xPos = gd.xPos + 1;
        case 'uparrow'
            % Rotate piece 90 degrees anticlockwise, i.e. 3 times clockwise
            currentPieceRot = rot90(gd.currentPiece, 3);
            % Check if rotation is valid (will not result in collisions)
            [validIntersection, pDir, pDist] = getValidIntersection( ...
                gd, currentPieceRot, gd.xPos, gd.yPos, '', 0, false);
            % Piece intersects and cannot be pushed into valid position
            if ~validIntersection
                return;
            % Push piece into valid position
            else
                switch pDir
                    case 'left'
                        gd.xPos = gd.xPos - pDist;
                    case 'right'
                        gd.xPos = gd.xPos + pDist;
                    case 'up'
                        gd.yPos = gd.yPos + pDist;
                end
            end
            % Rotate actual piece on playfield
            gd.currentPiece = currentPieceRot;
        case 'downarrow'
            % Move piece down faster by subtracting from the lastTime
            % Variable such that the non-blocking delay finishes early
            gd.lastTime = gd.lastTime - downArrowBoost;
    end
end

% Check for intersections during rotation, returns direction to push piece
% Such that the rotation is valid (if any)
function [validIntersection, pushDir, pushDist] = ...
    getValidIntersection(gd, piece, xPos, yPos, dir, i, noRecursion)
    [pieceRows, pieceCols] = size(piece);
    validIntersection = false;
    pushDir = dir;
    pushDist = i;
    % Iterate though all piece elements for collisions
    collisions = 0;
    for row = 1:pieceRows
        for col = 1:pieceCols
            % Check for cell in piece
            if piece(row, col)
                fieldRow = yPos - row + 1;
                fieldCol = xPos + col - 1;
                % Check if cell already exists in playfield and is
                % Not part of the non rotated piece, or if intersects
                % With playfield edges
                if fieldCol < 1 || fieldCol > gd.COLS ...
                    || fieldRow < 1 || fieldRow > gd.ROWS ...
                    || (gd.playfield(fieldRow, fieldCol) && ...
                     ~ismember([fieldRow, fieldCol], gd.lastPiecePos, 'rows'))
                    collisions = collisions + 1;
                    % Don't push piece more than it's width - 3
                    if i > pieceRows - 3 || noRecursion
                        return;
                    end
                    % Check for intersections in alternate positions, if
                    % Already checking one direction, keep checking only
                    % In that direction
                    vInt = false;
                    % Intersection from bottom, push up 1
                    if i == 0 || strcmp(dir, 'up')
                        [vInt, pDir, pDst] = getValidIntersection( ...
                            gd, piece, xPos, yPos + 1, 'up', i + 1, false);
                    end
                    % Cannot be pushed up, push to right
                    if (~vInt && i == 0) || strcmp(dir, 'right')
                        [vInt, pDir, pDst] = getValidIntersection( ...
                            gd, piece, xPos + 1, yPos, 'right', i + 1, false);
                    end
                    % Cannot be pushed right, push to left
                    if (~vInt && i == 0) || strcmp(dir, 'left')
                        [vInt, pDir, pDst] = getValidIntersection( ...
                            gd, piece, xPos - 1, yPos, 'left', i + 1, false);
                    end
                    % Piece can be pushed into valid position
                    if vInt
                        pushDir = pDir;
                        pushDist = pDst;
                        validIntersection = true;
                        return;
                    end
                end
            end
        end
    end
    % If looped over all cells without collision, then intersection valid
    validIntersection = ~collisions;
end

% Check for collisions around the piece
function collides = isBoundCollision(gd, direction)
    xDelta = 0;
    yDelta = 0;
    switch direction
        case 'left'
            xDelta = -1;
        case 'right'
            xDelta = 1;
        case 'down'
            yDelta = -1;
    end
    % Check if the piece will intersect if moved
    [validIntersection] = getValidIntersection( ...
        gd, gd.currentPiece, gd.xPos + xDelta, gd.yPos + yDelta, '', 0, true);
    % If there is no valid intersection, the piece collides
    collides = ~validIntersection;
end

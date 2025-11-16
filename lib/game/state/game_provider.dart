import 'package:flutter/foundation.dart';
import 'package:chess_5d/game/logic/game.dart';
import 'package:chess_5d/game/logic/game_options.dart';
import 'package:chess_5d/game/logic/board.dart';
import 'package:chess_5d/game/logic/piece.dart';
import 'package:chess_5d/game/logic/position.dart';
import 'package:chess_5d/game/logic/check_detector.dart';
import 'package:chess_5d/game/logic/move.dart';

/// Game state provider that bridges game logic to UI
///
/// This class manages the game state and provides methods for UI interaction.
/// It uses ChangeNotifier to notify listeners when the game state changes.
class GameProvider extends ChangeNotifier {
  GameProvider({required GameOptions options, required List<bool> localPlayer})
    : _game = Game(options: options, localPlayer: localPlayer),
      _selectedPiece = null,
      _legalMoves = [],
      _hoveredPiece = null,
      _ghostPiece = null {
    _updateLegalMoves();
  }

  /// The game instance
  Game get game => _game;
  Game _game;

  /// Currently selected piece
  Piece? get selectedPiece => _selectedPiece;
  Piece? _selectedPiece;

  /// Legal moves for the selected piece
  List<Vec4> get legalMoves => _legalMoves;
  List<Vec4> _legalMoves;

  /// Currently hovered piece (for drag preview)
  Piece? get hoveredPiece => _hoveredPiece;
  Piece? _hoveredPiece;

  /// Ghost piece (drag preview)
  Piece? get ghostPiece => _ghostPiece;
  Piece? _ghostPiece;

  /// Whether the game is finished
  bool get isFinished => _game.finished;

  /// Current turn (0 = black, 1 = white)
  int get turn => _game.turn;

  /// Whether moves can be submitted
  bool get canSubmit => _game.canSubmit;

  /// Current turn moves
  List<Move> get currentTurnMoves => _game.currentTurnMoves;

  /// Select a piece
  ///
  /// [piece] - The piece to select, or null to deselect
  void selectPiece(Piece? piece) {
    _selectedPiece = piece;
    _updateLegalMoves();
    notifyListeners();
  }

  /// Deselect the currently selected piece
  void deselectPiece() {
    _selectedPiece = null;
    _legalMoves = [];
    notifyListeners();
  }

  /// Set the hovered piece (for drag preview)
  ///
  /// [piece] - The piece being hovered, or null to clear
  void setHoveredPiece(Piece? piece) {
    _hoveredPiece = piece;
    notifyListeners();
  }

  /// Set the ghost piece (drag preview)
  ///
  /// [piece] - The ghost piece, or null to clear
  void setGhostPiece(Piece? piece) {
    _ghostPiece = piece;
    notifyListeners();
  }

  /// Make a move
  ///
  /// [piece] - The piece to move
  /// [targetPos] - Target position
  /// [promotion] - Promotion piece type (1=Queen, 2=Knight, 3=Rook, 4=Bishop, null=no promotion)
  ///
  /// Returns true if the move was successful
  bool makeMove(Piece piece, Vec4 targetPos, int? promotion) {
    if (_game.finished) {
      return false;
    }

    // Allow only one move per turn
    if (_game.currentTurnMoves.isNotEmpty) {
      return false; // A move has already been made this turn
    }

    // Check if target is valid (within board bounds)
    if (targetPos.x < 0 ||
        targetPos.x >= 8 ||
        targetPos.y < 0 ||
        targetPos.y >= 8) {
      return false;
    }

    // Validate pawn moves according to chess rules
    if (piece.type == PieceType.pawn && piece.board != null) {
      if (!_isValidPawnMove(piece, targetPos, piece.board as Board)) {
        return false;
      }
    }

    // Validate bishop moves according to chess rules
    if (piece.type == PieceType.bishop && piece.board != null) {
      if (!_isValidBishopMove(piece, targetPos, piece.board as Board)) {
        return false;
      }
    }

    // Validate rook moves according to chess rules
    if (piece.type == PieceType.rook && piece.board != null) {
      if (!_isValidRookMove(piece, targetPos, piece.board as Board)) {
        return false;
      }
    }

    // Validate queen moves according to chess rules
    if (piece.type == PieceType.queen && piece.board != null) {
      if (!_isValidQueenMove(piece, targetPos, piece.board as Board)) {
        return false;
      }
    }

    // Validate knight moves according to chess rules
    if (piece.type == PieceType.knight && piece.board != null) {
      if (!_isValidKnightMove(piece, targetPos, piece.board as Board)) {
        return false;
      }
    }

    // Validate king moves according to chess rules
    if (piece.type == PieceType.king && piece.board != null) {
      if (!_isValidKingMove(piece, targetPos, piece.board as Board)) {
        return false;
      }
    }

    // Turn validation - only allow moves for pieces of the current player's side
    if (piece.side != _game.turn) {
      return false; // Not this player's turn
    }

    // Check if this move would leave the king in check (cross-timeline)
    if (piece.board != null) {
      final wouldLeaveInCheck =
          CheckDetector.wouldMoveLeaveKingInCheckCrossTimeline(
            _game,
            piece.board as Board,
            piece,
            targetPos,
          );

      if (wouldLeaveInCheck) {
        // Move would leave king in check - illegal move
        return false;
      }
    }

    // Bypass game.move() which has turn validation - use applyMove directly
    print(
      'DEBUG GameProvider.makeMove: Making move with piece at l=${piece.board?.l}, t=${piece.board?.t}, targetPos: l=${targetPos.l}, t=${targetPos.t}',
    );
    try {
      final move = _game.instantiateMove(
        piece,
        targetPos,
        promotion,
        false,
        false,
      );
      print('DEBUG GameProvider.makeMove: Move created, applying...');
      _game.applyMove(move, false);
      print(
        'DEBUG GameProvider.makeMove: Move applied, timeline end is now ${_game.getTimeline(0).end}',
      );
      _game.findChecks(); // Ensure checks are found after move
      _game.checkSubmitAvailable();

      // Deselect piece after move
      _selectedPiece = null;
      _updateLegalMoves();
      notifyListeners();
      return true;
    } catch (e) {
      // Move creation failed
      return false;
    }
  }

  /// Validate if a pawn move is legal according to chess rules
  ///
  /// [piece] - The pawn piece
  /// [targetPos] - Target position
  /// [board] - The board the pawn is on
  ///
  /// Returns true if the pawn move is valid
  bool _isValidPawnMove(Piece piece, Vec4 targetPos, Board board) {
    // Determine direction based on side
    // Black (side 0) moves down (positive y), White (side 1) moves up (negative y)
    final direction = piece.side == 0 ? 1 : -1;
    final startRank = piece.side == 0
        ? 1
        : 6; // Black starts on rank 1, White on rank 6

    final dx = targetPos.x - piece.x;
    final dy = targetPos.y - piece.y;

    // Must move forward (in the direction of the piece's side)
    if (dy == 0 || (direction > 0 && dy <= 0) || (direction < 0 && dy >= 0)) {
      return false;
    }

    // Forward move (one square)
    if (dx == 0) {
      // Must move exactly one square forward, or two if on starting rank and hasn't moved
      if (dy == direction) {
        // One square forward - target must be empty
        final targetPiece = board.getPiece(targetPos.x, targetPos.y);
        if (targetPiece != null) {
          return false; // Can't move forward onto a piece
        }
        return true;
      } else if (dy == 2 * direction &&
          piece.y == startRank &&
          !piece.hasMoved) {
        // Two squares forward from starting position - both squares must be empty
        final oneSquareY = piece.y + direction;
        final targetPiece = board.getPiece(targetPos.x, targetPos.y);
        final blockingPiece = board.getPiece(targetPos.x, oneSquareY);
        if (targetPiece != null || blockingPiece != null) {
          return false; // Can't jump over or land on a piece
        }
        return true;
      }
      return false; // Invalid forward move
    }

    // Diagonal capture (must capture an enemy piece or en passant)
    if (dx.abs() == 1 && dy == direction) {
      final targetPiece = board.getPiece(targetPos.x, targetPos.y);
      if (targetPiece != null && targetPiece.side != piece.side) {
        // Valid capture - enemy piece on diagonal
        return true;
      }

      return false; // Diagonal move requires capture
    }

    // Invalid pawn move
    return false;
  }

  /// Validate if a bishop move is legal according to chess rules
  ///
  /// [piece] - The bishop piece
  /// [targetPos] - Target position
  /// [board] - The board the bishop is on
  ///
  /// Returns true if the bishop move is valid
  bool _isValidBishopMove(Piece piece, Vec4 targetPos, Board board) {
    final dx = targetPos.x - piece.x;
    final dy = targetPos.y - piece.y;

    // Bishops move diagonally - dx and dy must be equal in absolute value
    if (dx.abs() != dy.abs()) {
      return false;
    }

    // Must actually move (not stay in place)
    if (dx == 0 && dy == 0) {
      return false;
    }

    // Determine diagonal direction
    final stepX = dx > 0 ? 1 : -1;
    final stepY = dy > 0 ? 1 : -1;
    final distance = dx.abs();

    // Check all squares along the diagonal path
    for (int step = 1; step <= distance; step++) {
      final checkX = piece.x + stepX * step;
      final checkY = piece.y + stepY * step;
      final checkPiece = board.getPiece(checkX, checkY);

      if (step == distance) {
        // Target square - can have enemy piece (capture) or be empty
        if (checkPiece != null && checkPiece.side == piece.side) {
          return false; // Can't capture friendly piece
        }
        // Valid move (empty or enemy piece)
      } else {
        // Intermediate squares - must be empty
        if (checkPiece != null) {
          return false; // Blocked by a piece
        }
      }
    }

    return true;
  }

  /// Validate if a rook move is legal according to chess rules
  ///
  /// [piece] - The rook piece
  /// [targetPos] - Target position
  /// [board] - The board the rook is on
  ///
  /// Returns true if the rook move is valid
  bool _isValidRookMove(Piece piece, Vec4 targetPos, Board board) {
    final dx = targetPos.x - piece.x;
    final dy = targetPos.y - piece.y;

    // Rooks move horizontally or vertically - one of dx or dy must be 0
    if (dx != 0 && dy != 0) {
      return false; // Not horizontal or vertical
    }

    // Must actually move (not stay in place)
    if (dx == 0 && dy == 0) {
      return false;
    }

    // Determine direction and distance
    int stepX = 0;
    int stepY = 0;
    int distance = 0;

    if (dx != 0) {
      // Horizontal move
      stepX = dx > 0 ? 1 : -1;
      distance = dx.abs();
    } else {
      // Vertical move
      stepY = dy > 0 ? 1 : -1;
      distance = dy.abs();
    }

    // Check all squares along the path
    for (int step = 1; step <= distance; step++) {
      final checkX = piece.x + stepX * step;
      final checkY = piece.y + stepY * step;
      final checkPiece = board.getPiece(checkX, checkY);

      if (step == distance) {
        // Target square - can have enemy piece (capture) or be empty
        if (checkPiece != null && checkPiece.side == piece.side) {
          return false; // Can't capture friendly piece
        }
        // Valid move (empty or enemy piece)
      } else {
        // Intermediate squares - must be empty
        if (checkPiece != null) {
          return false; // Blocked by a piece
        }
      }
    }

    return true;
  }

  /// Validate if a queen move is legal according to chess rules
  ///
  /// [piece] - The queen piece
  /// [targetPos] - Target position
  /// [board] - The board the queen is on
  ///
  /// Returns true if the queen move is valid
  bool _isValidQueenMove(Piece piece, Vec4 targetPos, Board board) {
    final dx = targetPos.x - piece.x;
    final dy = targetPos.y - piece.y;

    // Must actually move (not stay in place)
    if (dx == 0 && dy == 0) {
      return false;
    }

    // Queen moves like rook (horizontal/vertical) or bishop (diagonal)
    final isHorizontal = dy == 0 && dx != 0;
    final isVertical = dx == 0 && dy != 0;
    final isDiagonal = dx.abs() == dy.abs() && dx != 0;

    if (!isHorizontal && !isVertical && !isDiagonal) {
      return false; // Not a valid queen move direction
    }

    // Determine direction and distance
    int stepX = 0;
    int stepY = 0;
    int distance = 0;

    if (isHorizontal) {
      stepX = dx > 0 ? 1 : -1;
      distance = dx.abs();
    } else if (isVertical) {
      stepY = dy > 0 ? 1 : -1;
      distance = dy.abs();
    } else {
      // Diagonal
      stepX = dx > 0 ? 1 : -1;
      stepY = dy > 0 ? 1 : -1;
      distance = dx.abs();
    }

    // Check all squares along the path
    for (int step = 1; step <= distance; step++) {
      final checkX = piece.x + stepX * step;
      final checkY = piece.y + stepY * step;
      final checkPiece = board.getPiece(checkX, checkY);

      if (step == distance) {
        // Target square - can have enemy piece (capture) or be empty
        if (checkPiece != null && checkPiece.side == piece.side) {
          return false; // Can't capture friendly piece
        }
        // Valid move (empty or enemy piece)
      } else {
        // Intermediate squares - must be empty
        if (checkPiece != null) {
          return false; // Blocked by a piece
        }
      }
    }

    return true;
  }

  /// Validate if a knight move is legal according to chess rules
  ///
  /// [piece] - The knight piece
  /// [targetPos] - Target position
  /// [board] - The board the knight is on
  ///
  /// Returns true if the knight move is valid
  bool _isValidKnightMove(Piece piece, Vec4 targetPos, Board board) {
    final dx = targetPos.x - piece.x;
    final dy = targetPos.y - piece.y;

    // Knights move in L-shape: 2 squares in one direction, then 1 perpendicular
    // Valid patterns: (±2, ±1) or (±1, ±2)
    final absDx = dx.abs();
    final absDy = dy.abs();

    if (!((absDx == 2 && absDy == 1) || (absDx == 1 && absDy == 2))) {
      return false; // Not a valid L-shape move
    }

    // Knights can jump over pieces, so no path checking needed
    // Just check if target square is valid
    final targetPiece = board.getPiece(targetPos.x, targetPos.y);
    if (targetPiece != null && targetPiece.side == piece.side) {
      return false; // Can't capture friendly piece
    }

    // Valid knight move (can jump over pieces)
    return true;
  }

  /// Validate if a king move is legal according to chess rules
  ///
  /// [piece] - The king piece
  /// [targetPos] - Target position
  /// [board] - The board the king is on
  ///
  /// Returns true if the king move is valid
  bool _isValidKingMove(Piece piece, Vec4 targetPos, Board board) {
    final dx = targetPos.x - piece.x;
    final dy = targetPos.y - piece.y;

    // Kings move one square in any direction (including diagonals)
    // dx and dy must both be -1, 0, or 1
    if (dx.abs() > 1 || dy.abs() > 1) {
      return false; // Too far
    }

    // Must actually move (not stay in place)
    if (dx == 0 && dy == 0) {
      return false;
    }

    // Check if target square is valid
    final targetPiece = board.getPiece(targetPos.x, targetPos.y);
    if (targetPiece != null && targetPiece.side == piece.side) {
      return false; // Can't capture friendly piece
    }

    // King can only move one square in any direction (castling removed)
    // Valid king move (one square in any direction)
    return true;
  }

  /// Undo the last move
  ///
  /// Returns true if a move was undone
  bool undoMove() {
    if (_game.currentTurnMoves.isEmpty) {
      return false;
    }

    // Remove the last move and reverse it
    final lastMove = _game.currentTurnMoves.removeLast();

    // Store move info before undo (undo may remove boards)
    final isRegularMove = !lastMove.nullMove;
    final sourcePiece = lastMove.sourcePiece;
    final sourcePos = lastMove.from;
    final sourceBoard = lastMove.sourceBoard;

    // Store used boards before undo (need to restore them in timeline)
    final usedBoards = List<Board>.from(lastMove.usedBoards);

    // Undo the move (removes created boards, reactivates used boards)
    lastMove.undo();

    // Restore used boards in timeline (undo removes created boards but doesn't restore used boards in timeline)
    for (final usedBoard in usedBoards) {
      final timeline = _game.getTimeline(usedBoard.l);
      timeline.setBoard(usedBoard.t, usedBoard);
    }

    // Restore piece position if this is a regular move (not null move)
    if (isRegularMove &&
        sourcePiece != null &&
        sourcePos != null &&
        sourceBoard != null) {
      // Find the actual board to restore to (the used board that was reactivated)
      final restoredBoard = usedBoards.firstWhere(
        (board) => board.l == sourcePos.l && board.t == sourcePos.t,
        orElse: () => sourceBoard,
      );

      // Move piece back to original position on the restored board
      if (sourcePiece.board != restoredBoard ||
          sourcePiece.x != sourcePos.x ||
          sourcePiece.y != sourcePos.y) {
        sourcePiece.changePosition(restoredBoard, sourcePos.x, sourcePos.y);
      }
    }

    // Update game state after undo (similar to Game.undo())
    if (_game.currentTurnMoves.isEmpty) {
      _game.movePresent(false);
    }

    _game.findChecks();
    _game.checkSubmitAvailable();

    // Clear selection and update legal moves
    _selectedPiece = null;
    _legalMoves = [];
    notifyListeners();
    return true;
  }

  /// Submit all moves for the current turn
  ///
  /// Returns true if moves were submitted successfully
  bool submitMoves() {
    // Check if there are any moves to submit
    if (_game.currentTurnMoves.isEmpty) {
      return false;
    }

    // Update submit availability
    _game.checkSubmitAvailable();

    // Submit moves - use remote: true to bypass canSubmit check for manual submission
    // This allows manual submission even if canSubmit is false
    final result = _game.submit(remote: true, fastForward: false);
    if (result['submitted'] == true) {
      _selectedPiece = null;
      _legalMoves = [];

      // Force UI update - notify listeners so the board view rebuilds
      notifyListeners();

      return true;
    }
    return false;
  }

  /// Start a new game
  ///
  /// [options] - Game options
  /// [localPlayer] - Local player flags
  void newGame(GameOptions options, List<bool> localPlayer) {
    _game = Game(options: options, localPlayer: localPlayer);
    _selectedPiece = null;
    _legalMoves = [];
    _hoveredPiece = null;
    _ghostPiece = null;
    _updateLegalMoves();
    notifyListeners();
  }

  /// Get legal moves for a piece
  ///
  /// [piece] - The piece to get moves for
  ///
  /// Returns a list of legal move positions
  List<Vec4> getLegalMovesForPiece(Piece piece) {
    if (piece.board == null) {
      return [];
    }

    // Get all possible moves for this piece
    final allMoves = piece.enumerateMoves();

    // Filter out illegal moves (moves that would leave king in check)
    final legalMoves = <Vec4>[];
    for (final move in allMoves) {
      try {
        // Use CheckDetector to check if move would leave king in check
        final wouldLeaveInCheck =
            CheckDetector.wouldMoveLeaveKingInCheckCrossTimeline(
              _game,
              piece.board!,
              piece,
              move,
            );

        if (!wouldLeaveInCheck) {
          legalMoves.add(move);
        }
      } catch (e) {
        // Invalid move, skip it
        continue;
      }
    }

    return legalMoves;
  }

  /// Update legal moves for the selected piece
  void _updateLegalMoves() {
    if (_selectedPiece == null) {
      _legalMoves = [];
      return;
    }

    // Show legal moves for pawns and bishops
    if (_selectedPiece!.type == PieceType.pawn ||
        _selectedPiece!.type == PieceType.bishop ||
        _selectedPiece!.type == PieceType.rook ||
        _selectedPiece!.type == PieceType.queen ||
        _selectedPiece!.type == PieceType.king ||
        _selectedPiece!.type == PieceType.knight) {
      _legalMoves = getLegalMovesForPiece(_selectedPiece!);
    } else {
      _legalMoves = [];
    }
  }

  /// Handle square tap
  ///
  /// [position] - The position that was tapped
  void handleSquareTap(Vec4 position) {
    print(
      'DEBUG GameProvider.handleSquareTap: Tapped position l=${position.l}, t=${position.t}, x=${position.x}, y=${position.y}',
    );
    if (_selectedPiece != null) {
      print(
        'DEBUG GameProvider.handleSquareTap: Selected piece at l=${_selectedPiece!.board?.l}, t=${_selectedPiece!.board?.t}, x=${_selectedPiece!.x}, y=${_selectedPiece!.y}',
      );
    }

    // If a piece is selected, try to make a move
    if (_selectedPiece != null) {
      // Check if tapping the same square (deselect)
      if (_selectedPiece!.x == position.x &&
          _selectedPiece!.y == position.y &&
          _selectedPiece!.board!.l == position.l &&
          _selectedPiece!.board!.t == position.t) {
        deselectPiece();
        return;
      }

      // Check if there's a piece on the target square
      final targetPiece = _game.getPiece(position);

      // If it's a friendly piece, select that instead
      if (targetPiece != null && targetPiece.side == _selectedPiece!.side) {
        selectPiece(targetPiece);
        return;
      }

      // Otherwise, try to move the selected piece to this square
      // No chess rules validation - just move it
      print(
        'DEBUG GameProvider.handleSquareTap: Calling makeMove with targetPos l=${position.l}, t=${position.t}',
      );
      makeMove(_selectedPiece!, position, null);
    } else {
      // No piece selected, check if there's a piece on this square
      final piece = _game.getPiece(position);
      if (piece != null && piece.side == _game.turn) {
        // Select the piece (only current player's pieces)
        selectPiece(piece);
      }
    }
  }

  /// Handle piece selection
  ///
  /// [piece] - The piece to select, or null to deselect
  void handlePieceSelection(Piece? piece) {
    selectPiece(piece);
  }

  /// Check if a move requires promotion
  ///
  /// [piece] - The piece making the move
  /// [targetPos] - Target position
  ///
  /// Returns true if this is a pawn moving to the promotion rank
  bool requiresPromotion(Piece piece, Vec4 targetPos) {
    if (piece.type != PieceType.pawn) {
      return false;
    }

    // White pawns promote on rank 0 (y == 0)
    // Black pawns promote on rank 7 (y == 7)
    if (piece.side == PieceSide.white && targetPos.y == 0) {
      return true;
    }
    if (piece.side == PieceSide.black && targetPos.y == 7) {
      return true;
    }

    return false;
  }

  /// Dispose resources
  @override
  void dispose() {
    _game.destroy();
    super.dispose();
  }
}

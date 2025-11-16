import 'package:chess_5d/game/logic/board.dart';
import 'package:chess_5d/game/logic/piece.dart';
import 'package:chess_5d/game/logic/position.dart';

/// Detects check and checkmate conditions
///
/// This class provides methods to check if squares are attacked,
/// if kings are in check, and to find all checks on the board.
/// Supports both single-board and cross-timeline check detection.
class CheckDetector {
  /// Check if a square is attacked by any piece of the attacking side on a single board
  ///
  /// [board] - The board to check on
  /// [x] - X coordinate of the square
  /// [y] - Y coordinate of the square
  /// [attackingSide] - Side of the attacking pieces (0 = black, 1 = white)
  /// [targetL] - Optional target timeline (for time travel moves)
  ///
  /// Returns true if the square is attacked by any enemy piece on this board.
  static bool isSquareAttacked(
    Board board,
    int x,
    int y,
    int attackingSide, [
    int? targetL,
  ]) {
    // Check all pieces on the board
    for (int px = 0; px < 8; px++) {
      for (int py = 0; py < 8; py++) {
        final piece = board.getPiece(px, py);
        if (piece == null || piece.side != attackingSide) {
          continue; // Skip empty squares and friendly pieces
        }

        // Get all possible moves for this piece
        final moves = piece.enumerateMoves(targetL);

        // Check if any move targets the square (matching x, y, and optionally l, t)
        if (moves.any((move) {
          if (move.x != x || move.y != y) return false;
          // If targetL is specified, also check timeline match
          if (targetL != null && move.l != targetL) return false;
          return true;
        })) {
          return true;
        }
      }
    }

    return false;
  }

  /// Check if a square is attacked by pieces from ALL timelines (cross-timeline check)
  ///
  /// [game] - The game instance (to access all timelines)
  /// [targetPos] - The target position to check (Vec4 with x, y, l, t)
  /// [attackingSide] - Side of the attacking pieces (0 = black, 1 = white)
  /// [targetBoard] - The board containing the target position
  ///
  /// Returns true if the square is attacked by any enemy piece from any timeline.
  ///
  /// Implementation matches reference: checks pieces from boards where
  /// board.turn != targetBoard.turn OR board == targetBoard (same board check).
  static bool isSquareAttackedCrossTimeline(
    dynamic game,
    Vec4 targetPos,
    int attackingSide,
    Board targetBoard,
  ) {
    // Check pieces from all timelines
    for (final timelineDirection in game.timelines) {
      for (final timeline in timelineDirection) {
        if (!timeline.isActive) continue;

        final currentBoard = timeline.getCurrentBoard();
        if (currentBoard == null) continue;

        // Check pieces from boards where:
        // 1. board.turn != targetBoard.turn (opponent's turn boards)
        // 2. OR board == targetBoard (same board - already handled by single-board check, but included for completeness)
        // This matches the reference implementation logic
        if (currentBoard.turn != targetBoard.turn ||
            (currentBoard.l == targetBoard.l &&
                currentBoard.t == targetBoard.t)) {
          // Check if any enemy piece on this board can attack the target position
          for (int px = 0; px < 8; px++) {
            for (int py = 0; py < 8; py++) {
              final piece = currentBoard.getPiece(px, py);
              if (piece == null || piece.side != attackingSide) {
                continue; // Skip empty squares and friendly pieces
              }

              // Get all possible moves for this piece, targeting the target timeline
              final moves = piece.enumerateMoves(targetPos.l);

              // Check if any move targets the exact position (x, y, l, t)
              if (moves.any(
                (move) =>
                    move.x == targetPos.x &&
                    move.y == targetPos.y &&
                    move.l == targetPos.l &&
                    move.t == targetPos.t,
              )) {
                return true;
              }
            }
          }
        }
      }
    }

    return false;
  }

  /// Check if the king of the specified side is in check (single board)
  ///
  /// [board] - The board to check on
  /// [side] - Side of the king to check (0 = black, 1 = white)
  /// [targetL] - Optional target timeline (for time travel moves)
  ///
  /// Returns true if the king is in check on this board only.
  static bool isKingInCheck(Board board, int side, [int? targetL]) {
    // Find the king
    Piece? king;
    for (int x = 0; x < 8; x++) {
      for (int y = 0; y < 8; y++) {
        final piece = board.getPiece(x, y);
        if (piece != null &&
            piece.type == PieceType.king &&
            piece.side == side) {
          king = piece;
          break;
        }
      }
      if (king != null) break;
    }

    if (king == null) {
      // No king found - this shouldn't happen in a valid game
      return false;
    }

    // Check if the king's square is attacked by the enemy on this board
    final enemySide = side == 0 ? 1 : 0;
    return isSquareAttacked(board, king.x, king.y, enemySide, targetL);
  }

  /// Check if the king of the specified side is in check across ALL timelines
  ///
  /// [game] - The game instance (to access all timelines)
  /// [board] - The board containing the king to check
  /// [side] - Side of the king to check (0 = black, 1 = white)
  ///
  /// Returns true if the king is in check by pieces from any timeline.
  static bool isKingInCheckCrossTimeline(dynamic game, Board board, int side) {
    // Find the king
    Piece? king;
    for (int x = 0; x < 8; x++) {
      for (int y = 0; y < 8; y++) {
        final piece = board.getPiece(x, y);
        if (piece != null &&
            piece.type == PieceType.king &&
            piece.side == side) {
          king = piece;
          break;
        }
      }
      if (king != null) break;
    }

    if (king == null) {
      // No king found - this shouldn't happen in a valid game
      return false;
    }

    // Check if the king's position is attacked by pieces from all timelines
    // Also check pieces on the same board (using single-board method first for efficiency)
    final enemySide = side == 0 ? 1 : 0;
    if (isSquareAttacked(board, king.x, king.y, enemySide)) {
      return true;
    }

    // Check cross-timeline attacks
    // The cross-timeline method handles both same-board and cross-timeline checks
    final kingPos = Vec4(king.x, king.y, board.l, board.t);
    return isSquareAttackedCrossTimeline(game, kingPos, enemySide, board);
  }

  /// Find all checks on the board
  ///
  /// This is a placeholder that will be expanded in Phase 3 when we have
  /// the Game class to check across timelines.
  ///
  /// [board] - The board to check
  /// [side] - Side to check for (0 = black, 1 = white)
  ///
  /// Returns true if the king of the specified side is in check.
  static bool findChecks(Board board, int side) {
    return isKingInCheck(board, side);
  }

  /// Check if a move would leave the king in check (single board)
  ///
  /// This is used by MoveGenerator to filter out illegal moves.
  ///
  /// [board] - The board before the move
  /// [piece] - The piece making the move
  /// [targetX] - Target X coordinate
  /// [targetY] - Target Y coordinate
  /// [targetL] - Optional target timeline
  ///
  /// Returns true if the move would leave the king in check on this board.
  ///
  /// Implementation: Creates a temporary board with the move applied,
  /// then checks if the king is in check on that board.
  static bool wouldMoveLeaveKingInCheck(
    Board board,
    Piece piece,
    int targetX,
    int targetY, [
    int? targetL,
  ]) {
    // Create a temporary board by cloning the current board
    final tempBoard = Board.fromBoard(board);

    // Find the piece on the temporary board (it will be a clone)
    final tempPiece = tempBoard.getPiece(piece.x, piece.y);
    if (tempPiece == null ||
        tempPiece.type != piece.type ||
        tempPiece.side != piece.side) {
      // Piece not found or doesn't match - this shouldn't happen
      return false;
    }

    // Capture any piece at the target square
    final targetPiece = tempBoard.getPiece(targetX, targetY);
    if (targetPiece != null) {
      // Remove the captured piece
      tempBoard.setPiece(targetX, targetY, null);
    }

    // Move the piece on the temporary board using setPiece (which updates board reference)
    tempBoard.setPiece(piece.x, piece.y, null);
    tempBoard.setPiece(targetX, targetY, tempPiece);
    // Note: setPiece already updates tempPiece.x, tempPiece.y, and tempPiece.board

    // Check if the king of the moving piece's side is in check
    return isKingInCheck(tempBoard, piece.side, targetL);
  }

  /// Check if a move would leave the king in check across ALL timelines
  ///
  /// This is used by MoveGenerator to filter out illegal moves in 5D chess.
  ///
  /// [game] - The game instance (to access all timelines)
  /// [board] - The board before the move
  /// [piece] - The piece making the move
  /// [targetPos] - Target position (Vec4 with x, y, l, t)
  ///
  /// Returns true if the move would leave the king in check by pieces from any timeline.
  ///
  /// Implementation: Creates a temporary board with the move applied,
  /// then checks if the king is in check across all timelines.
  static bool wouldMoveLeaveKingInCheckCrossTimeline(
    dynamic game,
    Board board,
    Piece piece,
    Vec4 targetPos,
  ) {
    // Create a temporary board by cloning the current board
    final tempBoard = Board.fromBoard(board);

    // Find the piece on the temporary board (it will be a clone)
    final tempPiece = tempBoard.getPiece(piece.x, piece.y);
    if (tempPiece == null ||
        tempPiece.type != piece.type ||
        tempPiece.side != piece.side) {
      // Piece not found or doesn't match - this shouldn't happen
      return false;
    }

    // Capture any piece at the target square
    final targetPiece = tempBoard.getPiece(targetPos.x, targetPos.y);
    if (targetPiece != null) {
      // Remove the captured piece
      tempBoard.setPiece(targetPos.x, targetPos.y, null);
    }

    // Move the piece on the temporary board
    tempBoard.setPiece(piece.x, piece.y, null);
    tempBoard.setPiece(targetPos.x, targetPos.y, tempPiece);

    // Check if the king of the moving piece's side is in check across all timelines
    // Note: We always check the tempBoard (with the move applied) regardless of whether
    // we're moving to a new board or staying on the same board. This correctly handles:
    // - Same board moves: Check if king is in check after move
    // - Moves to next turn (targetBoard == null): Check if king is in check after move on tempBoard
    // - Inter-dimensional moves (targetBoard exists): Check if king is in check after move on tempBoard
    //
    // When moving to next turn, the target board doesn't exist yet, but we still need to
    // check if the king would be in check after the move. The tempBoard represents the state
    // after the move is applied, so we check that.
    return CheckDetector.isKingInCheckCrossTimeline(
      game,
      tempBoard,
      piece.side,
    );
  }
}

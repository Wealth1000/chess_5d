import 'package:chess_5d/game/logic/piece.dart';
import 'package:chess_5d/game/logic/board.dart';
import 'package:chess_5d/game/logic/position.dart';

/// Helper class for piece movement patterns
///
/// This class provides static methods for generating moves for each piece type.
/// Moves are generated based on standard chess rules, considering:
/// - Board bounds
/// - Piece blocking (friendly pieces block, enemy pieces can be captured)
/// - Special rules (castling, en-passant, promotion)
class MovementPatterns {
  /// Generate moves for a rook
  ///
  /// Rooks move horizontally and vertically any number of squares.
  static List<Vec4> getRookMoves(Piece piece, Board board, int? targetL) {
    final moves = <Vec4>[];
    final l = targetL ?? board.l;
    final t = board.t + 1; // Next turn

    // Horizontal moves (left and right)
    for (int dx = -1; dx <= 1; dx += 2) {
      for (int x = piece.x + dx; x >= 0 && x < 8; x += dx) {
        final targetPos = Vec4(x, piece.y, l, t);
        if (!targetPos.isValid()) break;

        final targetPiece = board.getPiece(x, piece.y);
        if (targetPiece == null) {
          // Empty square - can move here
          moves.add(targetPos);
        } else if (targetPiece.side != piece.side) {
          // Enemy piece - can capture, but stop here
          moves.add(targetPos);
          break;
        } else {
          // Friendly piece - block, stop here
          break;
        }
      }
    }

    // Vertical moves (up and down)
    for (int dy = -1; dy <= 1; dy += 2) {
      for (int y = piece.y + dy; y >= 0 && y < 8; y += dy) {
        final targetPos = Vec4(piece.x, y, l, t);
        if (!targetPos.isValid()) break;

        final targetPiece = board.getPiece(piece.x, y);
        if (targetPiece == null) {
          // Empty square - can move here
          moves.add(targetPos);
        } else if (targetPiece.side != piece.side) {
          // Enemy piece - can capture, but stop here
          moves.add(targetPos);
          break;
        } else {
          // Friendly piece - block, stop here
          break;
        }
      }
    }

    return moves;
  }

  /// Generate moves for a knight
  ///
  /// Knights move in an L-shape: 2 squares in one direction, then 1 square perpendicular.
  static List<Vec4> getKnightMoves(Piece piece, Board board, int? targetL) {
    final moves = <Vec4>[];
    final l = targetL ?? board.l;
    final t = board.t + 1; // Next turn

    // All possible knight moves (L-shape)
    final offsets = [
      [-2, -1],
      [-2, 1],
      [-1, -2],
      [-1, 2],
      [1, -2],
      [1, 2],
      [2, -1],
      [2, 1],
    ];

    for (final offset in offsets) {
      final x = piece.x + offset[0];
      final y = piece.y + offset[1];

      if (x < 0 || x >= 8 || y < 0 || y >= 8) continue;

      final targetPos = Vec4(x, y, l, t);
      if (!targetPos.isValid()) continue;

      final targetPiece = board.getPiece(x, y);
      if (targetPiece == null || targetPiece.side != piece.side) {
        // Empty square or enemy piece - can move/capture
        moves.add(targetPos);
      }
      // Friendly piece - cannot move here (no need to add)
    }

    return moves;
  }

  /// Generate moves for a bishop
  ///
  /// Bishops move diagonally any number of squares.
  static List<Vec4> getBishopMoves(Piece piece, Board board, int? targetL) {
    final moves = <Vec4>[];
    final l = targetL ?? board.l;
    final t = board.t + 1; // Next turn

    // Diagonal moves (4 directions)
    final directions = [
      [-1, -1], // Up-left
      [-1, 1], // Up-right
      [1, -1], // Down-left
      [1, 1], // Down-right
    ];

    for (final dir in directions) {
      final dx = dir[0];
      final dy = dir[1];

      for (int step = 1; step < 8; step++) {
        final x = piece.x + dx * step;
        final y = piece.y + dy * step;

        if (x < 0 || x >= 8 || y < 0 || y >= 8) break;

        final targetPos = Vec4(x, y, l, t);
        if (!targetPos.isValid()) break;

        final targetPiece = board.getPiece(x, y);
        if (targetPiece == null) {
          // Empty square - can move here
          moves.add(targetPos);
        } else if (targetPiece.side != piece.side) {
          // Enemy piece - can capture, but stop here
          moves.add(targetPos);
          break;
        } else {
          // Friendly piece - block, stop here
          break;
        }
      }
    }

    return moves;
  }

  /// Generate moves for a queen
  ///
  /// Queens move in all directions (horizontal, vertical, diagonal) any number of squares.
  static List<Vec4> getQueenMoves(Piece piece, Board board, int? targetL) {
    // Queen moves are a combination of rook and bishop moves
    final moves = <Vec4>[];
    moves.addAll(getRookMoves(piece, board, targetL));
    moves.addAll(getBishopMoves(piece, board, targetL));
    return moves;
  }

  /// Generate moves for a king
  ///
  /// Kings move one square in any direction. Also includes castling moves.
  static List<Vec4> getKingMoves(Piece piece, Board board, int? targetL) {
    final moves = <Vec4>[];
    final l = targetL ?? board.l;
    final t = board.t + 1; // Next turn

    // Regular king moves (one square in any direction)
    for (int dx = -1; dx <= 1; dx++) {
      for (int dy = -1; dy <= 1; dy++) {
        if (dx == 0 && dy == 0) continue; // Skip current position

        final x = piece.x + dx;
        final y = piece.y + dy;

        if (x < 0 || x >= 8 || y < 0 || y >= 8) continue;

        final targetPos = Vec4(x, y, l, t);
        if (!targetPos.isValid()) continue;

        final targetPiece = board.getPiece(x, y);
        if (targetPiece == null || targetPiece.side != piece.side) {
          // Empty square or enemy piece - can move/capture
          moves.add(targetPos);
        }
      }
    }

    // Castling removed - king can only move one square

    return moves;
  }

  /// Check if kingside castling is possible
  static bool _canCastleKingside(Piece king, Board board) {
    if (king.hasMoved) return false;
    if (king.x != 4) return false; // King must be on e-file
    if (king.side == 0 && king.y != 0) return false; // Black king on rank 0
    if (king.side == 1 && king.y != 7) return false; // White king on rank 7

    // Check if castling rights exist
    final rights = board.castleAvailable;
    if (king.side == 0 && !CastlingRights.canBlackCastleKingside(rights)) {
      return false;
    }
    if (king.side == 1 && !CastlingRights.canWhiteCastleKingside(rights)) {
      return false;
    }

    // Check if squares between king and rook are empty
    if (board.getPiece(5, king.y) != null ||
        board.getPiece(6, king.y) != null) {
      return false;
    }

    // Check if rook exists and hasn't moved
    final rook = board.getPiece(7, king.y);
    if (rook == null || rook.type != PieceType.rook || rook.hasMoved) {
      return false;
    }

    // TODO: Check if king is in check or would pass through check (needs check detection)
    return true;
  }

  /// Check if queenside castling is possible
  static bool _canCastleQueenside(Piece king, Board board) {
    if (king.hasMoved) return false;
    if (king.x != 4) return false; // King must be on e-file
    if (king.side == 0 && king.y != 0) return false; // Black king on rank 0
    if (king.side == 1 && king.y != 7) return false; // White king on rank 7

    // Check if castling rights exist
    final rights = board.castleAvailable;
    if (king.side == 0 && !CastlingRights.canBlackCastleQueenside(rights)) {
      return false;
    }
    if (king.side == 1 && !CastlingRights.canWhiteCastleQueenside(rights)) {
      return false;
    }

    // Check if squares between king and rook are empty
    if (board.getPiece(1, king.y) != null ||
        board.getPiece(2, king.y) != null ||
        board.getPiece(3, king.y) != null) {
      return false;
    }

    // Check if rook exists and hasn't moved
    final rook = board.getPiece(0, king.y);
    if (rook == null || rook.type != PieceType.rook || rook.hasMoved) {
      return false;
    }

    // TODO: Check if king is in check or would pass through check (needs check detection)
    return true;
  }

  /// Generate moves for a pawn
  ///
  /// Pawns move forward one square (or two on first move), capture diagonally,
  /// can capture en-passant, and promote on the 8th rank.
  static List<Vec4> getPawnMoves(Piece piece, Board board, int? targetL) {
    final moves = <Vec4>[];
    final l = targetL ?? board.l;
    final t = board.t + 1; // Next turn

    // Determine direction based on side
    // Black (side 0) moves down (positive y), White (side 1) moves up (negative y)
    final direction = piece.side == 0 ? 1 : -1;
    final startRank = piece.side == 0
        ? 1
        : 6; // Black starts on rank 1, White on rank 6

    // Forward move (one square)
    final oneSquareY = piece.y + direction;
    if (oneSquareY >= 0 && oneSquareY < 8) {
      final targetPos = Vec4(piece.x, oneSquareY, l, t);
      if (targetPos.isValid() && board.getPiece(piece.x, oneSquareY) == null) {
        moves.add(targetPos);

        // Double move from starting position
        if (piece.y == startRank && !piece.hasMoved) {
          final twoSquareY = piece.y + 2 * direction;
          if (twoSquareY >= 0 &&
              twoSquareY < 8 &&
              board.getPiece(piece.x, twoSquareY) == null) {
            moves.add(Vec4(piece.x, twoSquareY, l, t));
          }
        }
      }
    }

    // Capture moves (diagonal)
    for (int dx = -1; dx <= 1; dx += 2) {
      final captureX = piece.x + dx;
      final captureY = piece.y + direction;

      if (captureX >= 0 && captureX < 8 && captureY >= 0 && captureY < 8) {
        final targetPos = Vec4(captureX, captureY, l, t);
        if (!targetPos.isValid()) continue;

        final targetPiece = board.getPiece(captureX, captureY);
        if (targetPiece != null && targetPiece.side != piece.side) {
          // Enemy piece - can capture
          moves.add(targetPos);
        }
      }
    }

    // Note: Promotion will be handled when the move is executed
    // For now, we just generate the move positions

    return moves;
  }
}

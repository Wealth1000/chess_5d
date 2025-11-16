import 'package:chess_5d/game/logic/piece.dart';
import 'package:chess_5d/game/logic/board.dart';
import 'package:chess_5d/game/logic/position.dart';
import 'package:chess_5d/game/logic/check_detector.dart';

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

    // Castling moves (only on same board, not when targetL is specified)
    // IMPORTANT: Only check castling if it's this piece's turn (when checking moves for current player)
    // Skip castling checks during check detection (when validating moves for other players)
    if (targetL == null && piece.game != null && board.turn == piece.side) {
      // print(
      //   'DEBUG Castling: Checking castling for king at (${piece.x}, ${piece.y}), side=${piece.side}, board.turn=${board.turn}, hasMoved=${piece.hasMoved}',
      // );
      // print(
      //   'DEBUG Castling: Board castling rights: ${board.castleAvailable.toRadixString(2)}',
      // );

      // Kingside castling: king moves to g-file (x=6)
      final canKingside = _canCastleKingside(piece, board, piece.game);
      // print('DEBUG Castling: Kingside castling possible: $canKingside');
      if (canKingside) {
        final castlingPos = Vec4(6, piece.y, l, t);
        if (castlingPos.isValid()) {
          // print(
          //   'DEBUG Castling: Adding kingside castling move to (${castlingPos.x}, ${castlingPos.y}) at l=${castlingPos.l}, t=${castlingPos.t}',
          // );
          moves.add(castlingPos);
        }
      }

      // Queenside castling: king moves to c-file (x=2)
      final canQueenside = _canCastleQueenside(piece, board, piece.game);
      // print('DEBUG Castling: Queenside castling possible: $canQueenside');
      if (canQueenside) {
        final castlingPos = Vec4(2, piece.y, l, t);
        if (castlingPos.isValid()) {
          // print(
          //   'DEBUG Castling: Adding queenside castling move to (${castlingPos.x}, ${castlingPos.y}) at l=${castlingPos.l}, t=${castlingPos.t}',
          // );
          moves.add(castlingPos);
        }
      }
    }
    // else {
    //   if (targetL != null) {
    //     print(
    //       'DEBUG Castling: Skipping castling - targetL is not null (inter-dimensional move)',
    //     );
    //   } else if (piece.game == null) {
    //     print('DEBUG Castling: Skipping castling - piece.game is null');
    //   } else if (board.turn != piece.side) {
    //     print(
    //       'DEBUG Castling: Skipping castling - not this player\'s turn (board.turn=${board.turn}, piece.side=${piece.side})',
    //     );
    //   }
    // }

    return moves;
  }

  /// Check if kingside castling is possible
  ///
  /// [king] - The king piece
  /// [board] - The board to check on
  /// [game] - The game instance (for check detection)
  static bool _canCastleKingside(Piece king, Board board, dynamic game) {
    // print('DEBUG Castling._canCastleKingside: Checking kingside castling');

    if (king.hasMoved) {
      // print('DEBUG Castling._canCastleKingside: Failed - king has moved');
      return false;
    }
    if (king.x != 4) {
      // print(
      //   'DEBUG Castling._canCastleKingside: Failed - king not on e-file (x=${king.x})',
      // );
      return false; // King must be on e-file
    }
    if (king.side == 0 && king.y != 0) {
      // print(
      //   'DEBUG Castling._canCastleKingside: Failed - black king not on rank 0 (y=${king.y})',
      // );
      return false; // Black king on rank 0
    }
    if (king.side == 1 && king.y != 7) {
      // print(
      //   'DEBUG Castling._canCastleKingside: Failed - white king not on rank 7 (y=${king.y})',
      // );
      return false; // White king on rank 7
    }

    // Check if castling rights exist
    final rights = board.castleAvailable;
    if (king.side == 0 && !CastlingRights.canBlackCastleKingside(rights)) {
      // print(
      //   'DEBUG Castling._canCastleKingside: Failed - black kingside castling rights not available',
      // );
      return false;
    }
    if (king.side == 1 && !CastlingRights.canWhiteCastleKingside(rights)) {
      // print(
      //   'DEBUG Castling._canCastleKingside: Failed - white kingside castling rights not available',
      // );
      return false;
    }

    // Check if squares between king and rook are empty
    if (board.getPiece(5, king.y) != null ||
        board.getPiece(6, king.y) != null) {
      // print(
      //   'DEBUG Castling._canCastleKingside: Failed - squares between king and rook are not empty',
      // );
      return false;
    }

    // Check if rook exists and hasn't moved
    final rook = board.getPiece(7, king.y);
    if (rook == null || rook.type != PieceType.rook || rook.hasMoved) {
      // print(
      //   'DEBUG Castling._canCastleKingside: Failed - rook at (7, ${king.y}) is ${rook == null ? "null" : "type=${rook.type}, hasMoved=${rook.hasMoved}"}',
      // );
      return false;
    }

    // Check if king is in check
    final inCheck = CheckDetector.isKingInCheckCrossTimeline(
      game,
      board,
      king.side,
    );
    if (inCheck) {
      // print('DEBUG Castling._canCastleKingside: Failed - king is in check');
      return false;
    }

    // Check if king would pass through check (f1/f8 and g1/g8)
    // Create temporary board to test if squares are attacked
    final tempBoard = Board.fromBoard(board);
    final tempKing = tempBoard.getPiece(king.x, king.y);
    if (tempKing == null) {
      // print('DEBUG Castling._canCastleKingside: Failed - tempKing is null');
      return false;
    }

    // Check square f (5) - king passes through here
    tempBoard.setPiece(king.x, king.y, null);
    tempBoard.setPiece(5, king.y, tempKing);
    final checkOnF = CheckDetector.isKingInCheckCrossTimeline(
      game,
      tempBoard,
      king.side,
    );
    if (checkOnF) {
      // print(
      //   'DEBUG Castling._canCastleKingside: Failed - king would pass through check at f (5, ${king.y})',
      // );
      return false;
    }

    // Check square g (6) - king ends here
    tempBoard.setPiece(5, king.y, null);
    tempBoard.setPiece(6, king.y, tempKing);
    final checkOnG = CheckDetector.isKingInCheckCrossTimeline(
      game,
      tempBoard,
      king.side,
    );
    if (checkOnG) {
      // print(
      //   'DEBUG Castling._canCastleKingside: Failed - king would end in check at g (6, ${king.y})',
      // );
      return false;
    }

    // print(
    //   'DEBUG Castling._canCastleKingside: SUCCESS - kingside castling is legal',
    // );
    return true;
  }

  /// Check if queenside castling is possible
  ///
  /// [king] - The king piece
  /// [board] - The board to check on
  /// [game] - The game instance (for check detection)
  static bool _canCastleQueenside(Piece king, Board board, dynamic game) {
    // print('DEBUG Castling._canCastleQueenside: Checking queenside castling');

    if (king.hasMoved) {
      // print('DEBUG Castling._canCastleQueenside: Failed - king has moved');
      return false;
    }
    if (king.x != 4) {
      // print(
      //   'DEBUG Castling._canCastleQueenside: Failed - king not on e-file (x=${king.x})',
      // );
      return false; // King must be on e-file
    }
    if (king.side == 0 && king.y != 0) {
      // print(
      //   'DEBUG Castling._canCastleQueenside: Failed - black king not on rank 0 (y=${king.y})',
      // );
      return false; // Black king on rank 0
    }
    if (king.side == 1 && king.y != 7) {
      // print(
      //   'DEBUG Castling._canCastleQueenside: Failed - white king not on rank 7 (y=${king.y})',
      // );
      return false; // White king on rank 7
    }

    // Check if castling rights exist
    final rights = board.castleAvailable;
    if (king.side == 0 && !CastlingRights.canBlackCastleQueenside(rights)) {
      // print(
      //   'DEBUG Castling._canCastleQueenside: Failed - black queenside castling rights not available',
      // );
      return false;
    }
    if (king.side == 1 && !CastlingRights.canWhiteCastleQueenside(rights)) {
      // print(
      //   'DEBUG Castling._canCastleQueenside: Failed - white queenside castling rights not available',
      // );
      return false;
    }

    // Check if squares between king and rook are empty
    if (board.getPiece(1, king.y) != null ||
        board.getPiece(2, king.y) != null ||
        board.getPiece(3, king.y) != null) {
      // print(
      //   'DEBUG Castling._canCastleQueenside: Failed - squares between king and rook are not empty',
      // );
      return false;
    }

    // Check if rook exists and hasn't moved
    final rook = board.getPiece(0, king.y);
    if (rook == null || rook.type != PieceType.rook || rook.hasMoved) {
      // print(
      //   'DEBUG Castling._canCastleQueenside: Failed - rook at (0, ${king.y}) is ${rook == null ? "null" : "type=${rook.type}, hasMoved=${rook.hasMoved}"}',
      // );
      return false;
    }

    // Check if king is in check
    final inCheck = CheckDetector.isKingInCheckCrossTimeline(
      game,
      board,
      king.side,
    );
    if (inCheck) {
      // print('DEBUG Castling._canCastleQueenside: Failed - king is in check');
      return false;
    }

    // Check if king would pass through check (b1/b8, c1/c8, d1/d8)
    // Create temporary board to test if squares are attacked
    final tempBoard = Board.fromBoard(board);
    final tempKing = tempBoard.getPiece(king.x, king.y);
    if (tempKing == null) {
      // print('DEBUG Castling._canCastleQueenside: Failed - tempKing is null');
      return false;
    }

    // Check square d (3) - king passes through here
    tempBoard.setPiece(king.x, king.y, null);
    tempBoard.setPiece(3, king.y, tempKing);
    final checkOnD = CheckDetector.isKingInCheckCrossTimeline(
      game,
      tempBoard,
      king.side,
    );
    if (checkOnD) {
      // print(
      //   'DEBUG Castling._canCastleQueenside: Failed - king would pass through check at d (3, ${king.y})',
      // );
      return false;
    }

    // Check square c (2) - king ends here
    tempBoard.setPiece(3, king.y, null);
    tempBoard.setPiece(2, king.y, tempKing);
    final checkOnC = CheckDetector.isKingInCheckCrossTimeline(
      game,
      tempBoard,
      king.side,
    );
    if (checkOnC) {
      // print(
      //   'DEBUG Castling._canCastleQueenside: Failed - king would end in check at c (2, ${king.y})',
      // );
      return false;
    }

    // print(
    //   'DEBUG Castling._canCastleQueenside: SUCCESS - queenside castling is legal',
    // );
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
          // print(
          //   'DEBUG EnPassant: Regular capture found at (${captureX}, ${captureY})',
          // );
          moves.add(targetPos);
        }
      }
    }

    // En passant capture
    if (board.enPassantTargetSquare != null) {
      // print(
      //   'DEBUG EnPassant: Checking en passant - target square: (${board.enPassantTargetSquare!.x}, ${board.enPassantTargetSquare!.y}) at l=${board.enPassantTargetSquare!.l}, t=${board.enPassantTargetSquare!.t}',
      // );
      // print(
      //   'DEBUG EnPassant: Pawn at (${piece.x}, ${piece.y}), direction=$direction, piece side=${piece.side}',
      // );

      // En passant is only available if:
      // 1. The en passant target square is adjacent horizontally (same rank)
      // 2. The pawn can capture diagonally to the square behind the target
      final epTarget = board.enPassantTargetSquare!;
      if (epTarget.l == board.l && epTarget.t == board.t) {
        // Same board - check if pawn is on the same rank and adjacent file
        final dx = epTarget.x - piece.x;
        final isAdjacent = dx.abs() == 1 && epTarget.y == piece.y;

        if (isAdjacent) {
          // The pawn is adjacent to the en passant target square
          // The capture square is one square forward (in the direction of movement)
          final captureY = piece.y + direction;
          final capturePos = Vec4(epTarget.x, captureY, l, t);

          // print(
          //   'DEBUG EnPassant: Pawn is adjacent to en passant target - capture square: (${capturePos.x}, ${capturePos.y}) at l=${capturePos.l}, t=${capturePos.t}',
          // );

          if (capturePos.isValid() &&
              captureY >= 0 &&
              captureY < 8 &&
              capturePos.x >= 0 &&
              capturePos.x < 8) {
            // Check if the capture square is empty (it should be for en passant)
            final captureSquarePiece = board.getPiece(
              capturePos.x,
              capturePos.y,
            );
            if (captureSquarePiece == null) {
              // print(
              //   'DEBUG EnPassant: Adding en passant capture move to (${capturePos.x}, ${capturePos.y}) at l=${capturePos.l}, t=${capturePos.t}',
              // );
              moves.add(capturePos);
            }
            // else {
            //   print(
            //     'DEBUG EnPassant: Capture square (${capturePos.x}, ${capturePos.y}) is not empty - cannot en passant',
            //   );
            // }
          }
          // else {
          //   print(
          //     'DEBUG EnPassant: Capture square (${capturePos.x}, ${capturePos.y}) is invalid or out of bounds',
          //   );
          // }
        }
        // else {
        //   print(
        //     'DEBUG EnPassant: Pawn not adjacent to en passant target (dx=$dx, pawn y=${piece.y}, epTarget y=${epTarget.y})',
        //   );
        // }
      }
      // else {
      //   print(
      //     'DEBUG EnPassant: En passant target is on different board (target l=${epTarget.l}, t=${epTarget.t}, board l=${board.l}, t=${board.t})',
      //   );
      // }
    }
    // else {
    //   print('DEBUG EnPassant: No en passant target square available');
    // }

    // Note: Promotion will be handled when the move is executed
    // For now, we just generate the move positions

    return moves;
  }
}

import 'package:chess_5d/game/logic/board.dart';
import 'package:chess_5d/game/logic/piece.dart';
import 'package:chess_5d/game/logic/position.dart';

/// Represents a move in 5D Chess
///
/// A move can be:
/// - Physical move: Moves on the same board (same l and t)
/// - Inter-dimensional move: Moves across timelines (different l or t)
/// - Null move: Internal mechanism to create a new board without moving a piece
///   (used for turn advancement when no moves were made on a timeline)
class Move {
  /// Create a regular move (requires both sourcePiece and targetPos)
  ///
  /// [game] - The game this move belongs to
  /// [sourcePiece] - The piece making the move (required)
  /// [targetPos] - Target position (required)
  /// [promotionTo] - Promotion type (1-4, or null)
  /// [remoteMove] - Whether this is a remote move
  /// [fastForward] - Whether to skip animations
  Move({
    required this.game,
    required Piece sourcePiece,
    required Vec4 targetPos,
    int? promotionTo,
    this.remoteMove = false,
    bool fastForward = false,
  }) : promote = promotionTo,
       to = targetPos,
       sourcePiece = sourcePiece,
       usedBoards = [],
       createdBoards = [],
       nullMove = false,
       isInterDimensionalMove = true,
       sourceBoard = null,
       targetBoard = null {
    // Set from position
    try {
      from = sourcePiece.pos();
    } catch (e) {
      // Piece not on a board yet - this should not happen for valid moves
      throw StateError('Cannot create move: piece is not on a board');
    }

    final sourceBoardOriginal = sourcePiece.board;
    if (sourceBoardOriginal == null) {
      throw StateError('Cannot create move: source piece is not on a board');
    }

    print(
      'DEBUG Move.constructor: === START === Creating move for ${sourcePiece.type} from (${from?.x}, ${from?.y}) to (${targetPos.x}, ${targetPos.y}) at l=${targetPos.l}, t=${targetPos.t}',
    );
    print(
      'DEBUG Move.constructor: Source board: l=${sourceBoardOriginal.l}, t=${sourceBoardOriginal.t}, turn=${sourceBoardOriginal.turn}',
    );

    // Get the target board from the timeline
    final targetTimeline = game.getTimeline(targetPos.l);
    var targetOriginBoard = targetTimeline.getBoard(targetPos.t);

    // Check if this is a capture move
    // IMPORTANT: For captures moving to next turn, the enemy piece is on the SOURCE board
    // (not the target board, which doesn't exist yet)
    final enemyPieceOnSourceBoard = sourceBoardOriginal.getPiece(
      targetPos.x,
      targetPos.y,
    );
    final isCapture =
        enemyPieceOnSourceBoard != null &&
        enemyPieceOnSourceBoard.side != sourcePiece.side;

    print(
      'DEBUG Move.constructor: Target board at l=${targetPos.l}, t=${targetPos.t}: ${targetOriginBoard != null ? "exists" : "null"}',
    );
    if (isCapture) {
      print(
        'DEBUG Move.constructor: This is a CAPTURE move - capturing ${enemyPieceOnSourceBoard.type} at (${targetPos.x}, ${targetPos.y}) on source board',
      );
    }

    // Get source timeline
    // Debug prints commented out
    // print('DEBUG Move.constructor: Creating move');
    // print(
    //   'DEBUG Move.constructor: sourcePiece: ${sourcePiece.type}, side=${sourcePiece.side}',
    // );
    // final fromStr = from != null
    //     ? "x=${from!.x}, y=${from!.y}, l=${from!.l}, t=${from!.t}"
    //     : "null";
    // print('DEBUG Move.constructor: from: $fromStr');
    // print(
    //   'DEBUG Move.constructor: to: x=${targetPos.x}, y=${targetPos.y}, l=${targetPos.l}, t=${targetPos.t}',
    // );
    // print(
    //   'DEBUG Move.constructor: sourceBoardOriginal: l=${sourceBoardOriginal.l}, t=${sourceBoardOriginal.t}',
    // );

    final sourceTimeline = game.getTimeline(sourceBoardOriginal.l);

    // If target board doesn't exist, we need to create it
    // This happens when moving to the next turn on the same timeline
    if (targetOriginBoard == null) {
      print(
        'DEBUG Move.constructor: Target board is null - checking if we should create it',
      );
      // Check if we're moving to the next turn on the same timeline
      if (targetPos.l == sourceBoardOriginal.l &&
          targetPos.t == sourceBoardOriginal.t + 1) {
        // This is a normal move to the next turn - we'll create the board below
        // For now, we'll use the source board as the "target origin" to clone from
        print(
          'DEBUG Move.constructor: Target board is null, but moving to next turn - will create new board',
        );
        targetOriginBoard = sourceBoardOriginal;
      } else {
        // Cannot move to a non-existent board on a different timeline or turn
        print(
          'DEBUG Move.constructor: ERROR - Cannot create move: target board does not exist at timeline ${targetPos.l}, turn ${targetPos.t} (source: l=${sourceBoardOriginal.l}, t=${sourceBoardOriginal.t})',
        );
        throw StateError(
          'Cannot create move: target board does not exist at timeline ${targetPos.l}, turn ${targetPos.t}',
        );
      }
    } else {
      print(
        'DEBUG Move.constructor: Target board exists at t=${targetOriginBoard.t}',
      );
    }

    // Track used boards (boards that will become inactive)
    usedBoards.add(sourceBoardOriginal);

    // Determine move type and create boards accordingly
    if (!targetOriginBoard.active) {
      // Case 1: Moving to inactive board (past) - create timeline branch
      // Create a copy of the source board
      sourceBoard = game.instantiateBoard(
        sourceBoardOriginal.l,
        sourceBoardOriginal.t,
        sourceBoardOriginal.turn,
        sourceBoardOriginal,
        fastForward,
      );

      // Update source board in its timeline
      sourceTimeline.setBoard(sourceBoardOriginal.t, sourceBoard!);

      // Calculate new timeline index
      // newL = ++timelineCount[targetOriginBoard.turn] * (targetOriginBoard.turn ? 1 : -1)
      final targetSide = targetOriginBoard.turn;
      game.timelineCount[targetSide] = game.timelineCount[targetSide] + 1;
      final newL = game.timelineCount[targetSide] * (targetSide == 1 ? 1 : -1);

      // Create new timeline starting at targetBoard.t + 1
      game.instantiateTimeline(
        newL,
        targetOriginBoard.t + 1,
        sourceBoardOriginal.l,
        fastForward,
      );

      // Create target board on new timeline (branching from the past board)
      targetBoard = game.instantiateBoard(
        newL,
        targetOriginBoard.t + 1,
        targetOriginBoard.turn,
        targetOriginBoard,
        fastForward,
      );

      // Set the board in the new timeline
      game.getTimeline(newL).setBoard(targetOriginBoard.t + 1, targetBoard!);

      isInterDimensionalMove = true;
    } else if (sourceBoardOriginal != targetOriginBoard) {
      // Case 2: Moving to active board on different timeline
      // Create copies of both boards
      sourceBoard = game.instantiateBoard(
        sourceBoardOriginal.l,
        sourceBoardOriginal.t,
        sourceBoardOriginal.turn,
        sourceBoardOriginal,
        fastForward,
      );

      // Update source board in its timeline
      sourceTimeline.setBoard(sourceBoardOriginal.t, sourceBoard!);

      targetBoard = game.instantiateBoard(
        targetOriginBoard.l,
        targetOriginBoard.t,
        targetOriginBoard.turn,
        targetOriginBoard,
        fastForward,
      );

      // Update the target board in its timeline
      targetTimeline.setBoard(targetOriginBoard.t, targetBoard!);

      usedBoards.add(targetOriginBoard);
      isInterDimensionalMove = true;
    } else {
      // Case 3: Moving on the same board (normal move)
      // Check if we're moving to the next turn (board needs to be created)
      print(
        'DEBUG Move.constructor: Checking move type - targetOriginBoard==sourceBoardOriginal: ${targetOriginBoard == sourceBoardOriginal}, targetPos.l==source.l: ${targetPos.l == sourceBoardOriginal.l}, targetPos.t==source.t+1: ${targetPos.t == sourceBoardOriginal.t + 1}',
      );

      // For captures: targetOriginBoard might exist (if capturing on same turn board)
      // but we still want to create a new board at t+1 for the capture
      // So we need to check: if it's a capture and targetOriginBoard exists at t+1,
      // we should still create a new board (the targetOriginBoard is the one we're capturing on)

      final shouldCreateNewBoard =
          targetOriginBoard == sourceBoardOriginal &&
          targetPos.l == sourceBoardOriginal.l &&
          targetPos.t == sourceBoardOriginal.t + 1;

      print(
        'DEBUG Move.constructor: shouldCreateNewBoard=$shouldCreateNewBoard',
      );
      print(
        'DEBUG Move.constructor:   - targetOriginBoard==sourceBoardOriginal: ${targetOriginBoard == sourceBoardOriginal}',
      );
      print(
        'DEBUG Move.constructor:   - targetPos.l==source.l: ${targetPos.l == sourceBoardOriginal.l} (targetPos.l=${targetPos.l}, source.l=${sourceBoardOriginal.l})',
      );
      print(
        'DEBUG Move.constructor:   - targetPos.t==source.t+1: ${targetPos.t == sourceBoardOriginal.t + 1} (targetPos.t=${targetPos.t}, source.t=${sourceBoardOriginal.t}, source.t+1=${sourceBoardOriginal.t + 1})',
      );
      if (isCapture) {
        print(
          'DEBUG Move.constructor: This is a CAPTURE - will create new board if shouldCreateNewBoard is true',
        );
        if (!shouldCreateNewBoard) {
          print(
            'DEBUG Move.constructor: ERROR - Capture detected but shouldCreateNewBoard is FALSE! This is wrong!',
          );
        }
      }

      // If targetOriginBoard exists but is NOT the source board, and we're moving to next turn,
      // we might be capturing on an existing board at next turn - this shouldn't happen normally,
      // but if it does, we need to handle it
      final isCaptureOnNextTurn =
          targetOriginBoard != null &&
          targetOriginBoard != sourceBoardOriginal &&
          targetPos.l == sourceBoardOriginal.l &&
          targetPos.t == sourceBoardOriginal.t + 1 &&
          isCapture;

      if (shouldCreateNewBoard || isCaptureOnNextTurn) {
        print(
          'DEBUG Move.constructor: Moving to next turn - creating new board at t=${targetPos.t}${isCapture ? " (CAPTURE MOVE)" : ""}',
        );
        // Moving to next turn on same timeline - create new board at next turn
        sourceBoard = game.instantiateBoard(
          sourceBoardOriginal.l,
          sourceBoardOriginal.t,
          sourceBoardOriginal.turn,
          sourceBoardOriginal,
          fastForward,
        );

        // Update source board in timeline
        sourceTimeline.setBoard(sourceBoardOriginal.t, sourceBoard!);
        print(
          'DEBUG Move.constructor: Source board set at t=${sourceBoardOriginal.t}',
        );

        // Create target board at next turn
        print(
          'DEBUG Move.constructor: Creating target board at l=${targetPos.l}, t=${targetPos.t}, turn=${1 - sourceBoardOriginal.turn}',
        );
        targetBoard = game.instantiateBoard(
          targetPos.l,
          targetPos.t,
          1 - sourceBoardOriginal.turn, // Next turn alternates
          sourceBoardOriginal,
          fastForward,
        );

        // Set target board in timeline
        print(
          'DEBUG Move.constructor: Setting target board in timeline at t=${targetPos.t}',
        );
        sourceTimeline.setBoard(targetPos.t, targetBoard!);
        print(
          'DEBUG Move.constructor: Target board set! Timeline end is now ${sourceTimeline.end}',
        );
      } else {
        // Moving on the same board (same turn)
        print(
          'DEBUG Move.constructor: Moving on same board (same turn) - NOT creating new board at t=${targetPos.t}',
        );
        if (isCapture) {
          print(
            'DEBUG Move.constructor: WARNING - This is a capture but falling into "same board" branch! This might be wrong!',
          );
        }
        sourceBoard = game.instantiateBoard(
          sourceBoardOriginal.l,
          sourceBoardOriginal.t,
          sourceBoardOriginal.turn,
          sourceBoardOriginal,
          fastForward,
        );
        targetBoard = sourceBoard;

        // Update the board in its timeline
        sourceTimeline.setBoard(sourceBoardOriginal.t, sourceBoard!);
        print(
          'DEBUG Move.constructor: Same board updated at t=${sourceBoardOriginal.t}, timeline end remains ${sourceTimeline.end}',
        );
      }

      isInterDimensionalMove = false;
    }

    // Track created boards (sourceBoard is guaranteed to be non-null here)
    createdBoards.add(sourceBoard!);
    // Always add targetBoard if it exists and is different from sourceBoard
    // This includes normal moves to next turn (not just inter-dimensional moves)
    if (targetBoard != null &&
        targetBoard != sourceBoard &&
        !createdBoards.contains(targetBoard)) {
      createdBoards.add(targetBoard!);
      print(
        'DEBUG Move.constructor: Added targetBoard to createdBoards: l=${targetBoard!.l}, t=${targetBoard!.t}',
      );
    }

    // Algorithm: En Passant Handling
    // A. On Every Move Made:
    // 1. If the moved piece is NOT a pawn: Clear enPassantTargetSquare
    // 2. If the moved piece IS a pawn:
    //    - If pawn moved 2 squares forward: Set enPassantTargetSquare to the square behind the pawn
    //    - Otherwise: Clear enPassantTargetSquare

    final finalTargetBoard = targetBoard;
    if (finalTargetBoard == null) {
      throw StateError('Target board is null');
    }

    // Remove piece at target position if it exists (on target board)
    final targetPiece = finalTargetBoard.getPiece(targetPos.x, targetPos.y);
    if (targetPiece != null) {
      targetPiece.remove();
    }

    // IMPORTANT: Get the piece from the TARGET board (not source board)
    // The source board should remain unchanged (it represents the previous state)
    // The target board is a clone and has its own cloned pieces
    final pieceOnTargetBoard = finalTargetBoard.getPiece(from!.x, from!.y);
    if (pieceOnTargetBoard == null) {
      throw StateError('Source piece not found on target board');
    }

    final finalSourcePiece = sourcePiece;
    if (promote != null) {
      // Handle promotion: remove the pawn and create the promoted piece
      // Remove the pawn from the target board
      pieceOnTargetBoard.remove();

      // Determine the promoted piece type
      String promotedType;
      switch (promote) {
        case 1:
          promotedType = PieceType.queen;
          break;
        case 2:
          promotedType = PieceType.knight;
          break;
        case 3:
          promotedType = PieceType.rook;
          break;
        case 4:
          promotedType = PieceType.bishop;
          break;
        default:
          promotedType = PieceType.queen; // Default to queen
      }

      // Create the promoted piece on the target board
      final promotedPiece = Piece(
        game: game,
        board: finalTargetBoard,
        side: finalSourcePiece.side,
        x: targetPos.x,
        y: targetPos.y,
        type: promotedType,
      );
      promotedPiece.hasMoved = true; // Promoted piece has moved
      _promotedPiece = promotedPiece;

      // Place the promoted piece on the target board
      finalTargetBoard.setPiece(targetPos.x, targetPos.y, promotedPiece);
    } else {
      // Normal move

      // Check for promotion: if pawn reaches the end of the board, promote to queen
      final isPawnPromotion =
          finalSourcePiece.type == PieceType.pawn &&
          ((finalSourcePiece.side == 0 && targetPos.y == 7) ||
              (finalSourcePiece.side == 1 && targetPos.y == 0));

      if (isPawnPromotion) {
        // Remove the pawn from the target board
        pieceOnTargetBoard.remove();

        // Create a queen on the target board
        final promotedQueen = Piece(
          game: game,
          board: finalTargetBoard,
          side: finalSourcePiece.side,
          x: targetPos.x,
          y: targetPos.y,
          type: PieceType.queen,
        );
        promotedQueen.hasMoved = true; // Promoted piece has moved
        _promotedPiece = promotedQueen;

        // Place the promoted queen on the target board
        finalTargetBoard.setPiece(targetPos.x, targetPos.y, promotedQueen);
      } else {
        // Normal move - move the piece on the target board
        // The source board remains unchanged (previous state)
        pieceOnTargetBoard.changePosition(
          finalTargetBoard,
          targetPos.x,
          targetPos.y,
          sourceBoard: sourceBoardOriginal,
          sourcePiece: finalSourcePiece,
        );
      }

      // Update castling rights when king or rook moves
      if (finalSourcePiece.type == PieceType.king) {
        // Remove all castling rights for this side
        finalTargetBoard.castleAvailable = CastlingRights.removeCastlingRights(
          finalTargetBoard.castleAvailable,
          finalSourcePiece.side,
        );
      } else if (finalSourcePiece.type == PieceType.rook) {
        // Remove castling right for this specific rook
        final fromX = from!.x;
        final targetRank = from!.y;

        // Check if this is a corner rook
        if (fromX == 0) {
          // Queenside rook
          if (finalSourcePiece.side == 0) {
            finalTargetBoard.castleAvailable &= ~CastlingRights.blackQueenside;
          } else {
            finalTargetBoard.castleAvailable &= ~CastlingRights.whiteQueenside;
          }
        } else if (fromX == 7) {
          // Kingside rook
          if (finalSourcePiece.side == 0) {
            finalTargetBoard.castleAvailable &= ~CastlingRights.blackKingside;
          } else {
            finalTargetBoard.castleAvailable &= ~CastlingRights.whiteKingside;
          }
        }
      }

      // Also update castling rights if a rook is captured
      if (targetPiece != null && targetPiece.type == PieceType.rook) {
        final fromX = targetPos.x;
        final targetRank = targetPos.y;

        if (fromX == 0) {
          // Queenside rook captured
          if (targetPiece.side == 0) {
            finalTargetBoard.castleAvailable &= ~CastlingRights.blackQueenside;
          } else {
            finalTargetBoard.castleAvailable &= ~CastlingRights.whiteQueenside;
          }
        } else if (fromX == 7) {
          // Kingside rook captured
          if (targetPiece.side == 0) {
            finalTargetBoard.castleAvailable &= ~CastlingRights.blackKingside;
          } else {
            finalTargetBoard.castleAvailable &= ~CastlingRights.whiteKingside;
          }
        }
      }
    }

    // Make used boards inactive
    print(
      'DEBUG Move.execute: Making ${usedBoards.length} used boards inactive',
    );
    for (final board in usedBoards) {
      print(
        'DEBUG Move.execute: Making board inactive: l=${board.l}, t=${board.t}',
      );
      board.makeInactive();
    }

    print('DEBUG Move.execute: === MOVE EXECUTE END ===');
  }

  /// Private constructor for null moves (internal use only)
  ///
  /// Null moves are used internally by the game engine to advance timelines
  /// when no piece moves were made on that timeline during a turn.
  Move._nullMove({
    required this.game,
    required int timelineIndex,
    this.remoteMove = false,
  }) : sourcePiece = null,
       from = null,
       to = null,
       promote = null,
       usedBoards = [],
       createdBoards = [],
       nullMove = true,
       isInterDimensionalMove = false,
       sourceBoard = null,
       targetBoard = null,
       l = timelineIndex;

  /// Create a null move (creates a new board without moving a piece)
  ///
  /// Null moves are internal game mechanics used during submit() to advance
  /// timelines when no piece moves were made on that timeline.
  ///
  /// [game] - The game
  /// [board] - The board/timeline to create the null move for
  /// [fastForward] - Whether to skip animations
  factory Move.nullMove(dynamic game, Board board, {bool fastForward = false}) {
    final move = Move._nullMove(game: game, timelineIndex: board.l);

    // Create a new board for the next turn on this timeline
    final timeline = game.getTimeline(board.l);
    final nextTurn = board.t + 1;
    final nextTurnBoard = game.instantiateBoard(
      board.l,
      nextTurn,
      board.turn,
      board,
      fastForward,
    );

    timeline.setBoard(nextTurn, nextTurnBoard);
    move.createdBoards.add(nextTurnBoard);
    move.usedBoards.add(board);
    board.makeInactive();

    return move;
  }

  /// Create a move from serialized data
  ///
  /// Note: This is a simplified version. Full deserialization will require
  /// access to the game state to reconstruct pieces and boards.
  ///
  /// For null moves, this will create a null move. For regular moves,
  /// sourcePiece will need to be reconstructed from the game state in Phase 2.
  factory Move.fromSerialized(dynamic game, Map<String, dynamic> data) {
    final isNullMove = data['nullMove'] ?? false;

    if (isNullMove) {
      // Create null move
      final timelineIndex = data['l'] as int?;
      if (timelineIndex == null) {
        throw ArgumentError('Null move must have timeline index (l)');
      }
      return Move._nullMove(
        game: game,
        timelineIndex: timelineIndex,
        remoteMove: data['remoteMove'] ?? false,
      );
    } else {
      // Create regular move (sourcePiece will need to be set later)
      // This is a temporary object that will be fully reconstructed in Phase 2
      final targetPos = data['to'] != null ? Vec4.fromJson(data['to']) : null;
      if (targetPos == null) {
        throw ArgumentError('Regular move must have target position');
      }

      // We need a sourcePiece, but we can't reconstruct it yet without game state
      // For now, throw an error - this will be properly implemented in Phase 2
      throw UnimplementedError(
        'Deserialization of regular moves requires game state access. '
        'This will be implemented in Phase 2 when Game class is available.',
      );
    }
  }

  /// The game this move belongs to
  dynamic game; // Game class (forward reference)

  /// Board the move starts from
  Board? sourceBoard;

  /// Board the move ends on
  Board? targetBoard;

  /// Source position (Vec4)
  Vec4? from;

  /// Destination position (Vec4)
  Vec4? to;

  /// Source piece (null only for null moves)
  Piece? sourcePiece;

  /// Whether this is an inter-dimensional move (across timelines)
  bool isInterDimensionalMove;

  /// Whether this is a null move (no piece movement, internal game mechanic)
  bool nullMove;

  /// Whether this move is from a remote player
  bool remoteMove;

  /// Pawn promotion: 1=Queen, 2=Knight, 3=Rook, 4=Bishop
  int? promote;

  /// Boards that become inactive due to this move
  List<Board> usedBoards;

  /// Boards created by this move
  List<Board> createdBoards;

  /// Promoted piece (if this move involved promotion)
  Piece? _promotedPiece;

  /// Timeline index (for null moves, specifies which timeline to advance)
  int? l;

  /// Whether this move has been executed
  bool _executed = false;

  /// Execute this move
  ///
  /// This is a placeholder - full implementation will come in Phase 2
  void execute({bool fastForward = false}) {
    if (_executed) {
      return;
    }

    // TODO: Implement move execution in Phase 2
    // For now, just mark as executed
    _executed = true;
  }

  /// Undo this move
  ///
  /// Reverses the move by removing created boards and reactivating used boards
  void undo() {
    // Remove created boards and reactivate used boards
    for (int i = 0; i < createdBoards.length; i++) {
      final createdBoard = createdBoards[i];

      // Remove the board from its timeline
      final timeline = game.getTimeline(createdBoard.l);
      timeline.boards[createdBoard.t - timeline.start] = null;

      // Remove the board (this will clean up pieces)
      createdBoard.remove();

      // Reactivate the corresponding used board if it exists
      if (i < usedBoards.length) {
        final usedBoard = usedBoards[i];
        usedBoard.makeActive();
      }
    }

    // If this was a timeline branch, we may need to remove the timeline
    if (isInterDimensionalMove &&
        targetBoard != sourceBoard &&
        targetBoard != null) {
      final targetTimeline = game.getTimeline(targetBoard!.l);
      // Check if timeline is now empty
      if (targetTimeline.boardCount == 0) {
        // Remove the timeline (this is handled by the timeline itself)
        targetTimeline.remove();

        // Update timeline count
        final side = targetBoard!.l < 0 ? 0 : 1;
        if (game.timelineCount[side] > 0) {
          game.timelineCount[side] = game.timelineCount[side] - 1;
        }
      }
    }

    _executed = false;
  }

  /// Serialize this move to JSON
  ///
  /// Used for network transmission and undo/redo
  Map<String, dynamic> serialize() {
    return {
      'from': from?.toJson(),
      'to': to?.toJson(),
      'sourcePiece': sourcePiece != null
          ? {
              'type': sourcePiece!.type,
              'side': sourcePiece!.side,
              'x': sourcePiece!.x,
              'y': sourcePiece!.y,
            }
          : null,
      'sourceBoard': sourceBoard != null
          ? {'l': sourceBoard!.l, 't': sourceBoard!.t}
          : null,
      'targetBoard': targetBoard != null
          ? {'l': targetBoard!.l, 't': targetBoard!.t}
          : null,
      'isInterDimensionalMove': isInterDimensionalMove,
      'nullMove': nullMove,
      'remoteMove': remoteMove,
      'promote': promote,
      'l': l,
    };
  }

  /// Check if this move is valid
  ///
  /// This is a placeholder - full validation will come in Phase 2
  bool isValid() {
    // TODO: Implement move validation in Phase 2
    return true;
  }

  /// Get promotion piece type name
  String? getPromotionTypeName() {
    switch (promote) {
      case 1:
        return 'queen';
      case 2:
        return 'knight';
      case 3:
        return 'rook';
      case 4:
        return 'bishop';
      default:
        return null;
    }
  }

  @override
  String toString() {
    if (nullMove) {
      return 'Move(null, l:$l)';
    }
    return 'Move($from -> $to, piece:${sourcePiece?.type}, interDim:$isInterDimensionalMove)';
  }
}

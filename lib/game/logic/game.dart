import 'dart:math' as math;
import 'package:chess_5d/game/logic/board.dart';
import 'package:chess_5d/game/logic/check_detector.dart';
import 'package:chess_5d/game/logic/checkmate/simple_checkmate_detector.dart';
import 'package:chess_5d/game/logic/game_options.dart';
import 'package:chess_5d/game/logic/move.dart';
import 'package:chess_5d/game/logic/piece.dart';
import 'package:chess_5d/game/logic/player.dart';
import 'package:chess_5d/game/logic/position.dart';
import 'package:chess_5d/game/logic/timeline.dart';
import 'package:chess_5d/game/logic/variants/variant_factory.dart';

/// Main game state manager
///
/// Manages the entire game state including timelines, turns, moves, and game logic.
class Game {
  /// Create a new game
  ///
  /// [options] - Game configuration options
  /// [localPlayer] - Which players are local: [black, white]
  Game({required GameOptions options, required List<bool> localPlayer})
    : _options = options,
      _localPlayer = localPlayer,
      turn = 1,
      present = 0,
      finished = false,
      canSubmit = false,
      timelines = [[], []],
      timelineCount = [0, 0],
      lastTimelineCount = [0, 0],
      currentTurnMoves = [],
      timeRemaining = [options.time.start[0], options.time.start[1]],
      displayedChecks = [],
      players = [] {
    // Initialize piece types (placeholder for now)
    instantiatePieceTypes();

    // Initialize players
    players.add(instantiatePlayer(0));
    players.add(instantiatePlayer(1));

    // Create main timeline (l=0) starting at t=-1
    instantiateTimeline(0, -1, null, true);

    // Create turn 0 board (inactive, for variant setup)
    final turnZeroBoard = instantiateBoard(0, -1, 1 - turn, null, true);
    turnZeroBoard.makeInactive();
    getTimeline(0).setBoard(-1, turnZeroBoard);

    // Create initial board at t=0 using variant system
    final variant = VariantFactory.createVariant(options.variant);
    final initialBoard = variant.createInitialBoard(this, 0, 0, turn);
    getTimeline(0).setBoard(0, initialBoard);

    // Load moves from options if provided (for replay)
    // Note: Move deserialization will be implemented in a later phase
    // For now, we skip loading moves from options.moves
    // if (options.moves != null) {
    //   // Move deserialization requires game state access
    //   // This will be implemented when Move.fromSerialized is complete
    // }

    // Initialize present
    movePresent(true);

    // Find initial checks
    findChecks();

    // Start clocks if running
    if (options.runningClocks) {
      players[turn].startTime(
        skipGraceAmount: options.runningClockGraceTime,
        skipAmount: options.runningClockTime,
      );
    }

    // Check if game is finished
    if (options.finished) {
      end(options.winner, options.winCause, options.winReason, true);
    }
  }

  /// Game options
  final GameOptions _options;

  /// Which players are local: [black, white]
  final List<bool> _localPlayer;

  /// Current turn: 0 = black, 1 = white
  int turn;

  /// Present turn (minimum end turn across all active timelines)
  int present;

  /// Timelines: [[negative timelines], [positive timelines]]
  /// Negative timelines are for black (l < 0)
  /// Positive timelines are for white (l >= 0)
  /// Timeline 0 is stored in positive timelines[0]
  List<List<Timeline>> timelines;

  /// Count of timelines for each side: [black, white]
  List<int> timelineCount;

  /// Previous timeline count (for animation)
  List<int> lastTimelineCount;

  /// Current turn moves (not yet submitted)
  List<Move> currentTurnMoves;

  /// Whether moves can be submitted
  bool canSubmit;

  /// Whether the game is finished
  bool finished;

  /// Time remaining for each player in milliseconds: [black, white]
  List<int> timeRemaining;

  /// Displayed checks (for UI): List of check positions
  List<List<Vec4>> displayedChecks;

  /// Player objects: [black, white]
  List<Player> players;

  /// Piece type classes (placeholder for now)
  Map<String, Type> pieceTypes = {};

  /// Whether the game is loading (for async operations)
  bool loading = false;

  /// Get timeline by index
  ///
  /// [l] - Timeline index (negative for black, positive for white, 0 for main)
  Timeline getTimeline(int l) {
    if (l >= 0) {
      // Positive timelines (including 0)
      while (timelines[1].length <= l) {
        timelines[1].add(Timeline(game: this, l: timelines[1].length, t: 0));
      }
      return timelines[1][l];
    } else {
      // Negative timelines
      final index = -1 - l;
      while (timelines[0].length <= index) {
        timelines[0].add(
          Timeline(game: this, l: -(timelines[0].length + 1), t: 0),
        );
      }
      return timelines[0][index];
    }
  }

  /// Get piece at a specific position
  ///
  /// [pos] - Position (Vec4)
  /// [incrBoardNum] - Optional timeline index for board increment
  Piece? getPiece(Vec4 pos, [int? incrBoardNum]) {
    if (pos.x < 0 || pos.x >= 8 || pos.y < 0 || pos.y >= 8) {
      return null;
    }

    final timeline = getTimeline(pos.l);

    // Determine which turn to get the board from
    final boardTurn =
        (incrBoardNum != null &&
            timeline.l == incrBoardNum &&
            timeline.end < pos.t)
        ? pos.t - 1
        : pos.t;

    final board = timeline.getBoard(boardTurn);
    if (board == null) {
      return null;
    }

    return board.getPiece(pos.x, pos.y);
  }

  /// Factory method to create a move
  Move instantiateMove(
    Piece sourcePiece,
    Vec4 targetPos,
    int? promotionTo,
    bool remoteMove,
    bool fastForward,
  ) {
    return Move(
      game: this,
      sourcePiece: sourcePiece,
      targetPos: targetPos,
      promotionTo: promotionTo,
      remoteMove: remoteMove,
      fastForward: fastForward,
    );
  }

  /// Factory method to create a timeline
  Timeline instantiateTimeline(int l, int t, int? sourceL, bool fastForward) {
    final timeline = Timeline(
      game: this,
      l: l,
      t: t,
      sourceL: sourceL,
      fastForward: fastForward,
    );

    // Add to appropriate timeline list
    if (l >= 0) {
      // Update timeline count for white
      if (l > 0) {
        timelineCount[1] = math.max(timelineCount[1], l);
      }
      // Ensure list is large enough
      while (timelines[1].length <= l) {
        timelines[1].add(Timeline(game: this, l: timelines[1].length, t: 0));
      }
      timelines[1][l] = timeline;
    } else {
      // Update timeline count for black
      final index = -1 - l;
      timelineCount[0] = math.max(timelineCount[0], index - 1);
      // Ensure list is large enough
      while (timelines[0].length <= index) {
        timelines[0].add(
          Timeline(game: this, l: -(timelines[0].length + 1), t: 0),
        );
      }
      timelines[0][index] = timeline;
    }

    return timeline;
  }

  /// Factory method to create a board
  Board instantiateBoard(
    int l,
    int t,
    int turn,
    Board? initialBoard,
    bool fastForward,
  ) {
    print('DEBUG Board Creation: Creating board at l=$l, t=$t, turn=$turn');
    final board = Board(
      game: this,
      l: l,
      t: t,
      turn: turn,
      initialBoard: initialBoard,
      fastForward: fastForward,
    );
    print('DEBUG Board Creation: Board created successfully at l=$l, t=$t');
    return board;
  }

  /// Factory method to create a player
  Player instantiatePlayer(int side) {
    return Player(
      game: this,
      side: side,
      timeRemaining: _options.time.start[side],
    );
  }

  /// Initialize piece types (placeholder for now)
  ///
  /// This will be implemented in a later phase when we add variant support.
  void instantiatePieceTypes() {
    // Placeholder - will be implemented with variant system
    pieceTypes = {};
  }

  /// Update present to minimum end turn across all active timelines
  ///
  /// [fastForward] - Whether to skip animations
  void movePresent(bool fastForward) {
    present = 999999; // Large number (infinity equivalent)

    // Calculate active timeline range
    final minL = -math.min(timelineCount[0], timelineCount[1] + 1);
    final maxL = math.min(timelineCount[0] + 1, timelineCount[1]);

    // Find minimum end turn across active timelines
    for (int l = minL; l <= maxL; l++) {
      final timeline = getTimeline(l);
      if (timeline.isActive) {
        final t = math.max(timeline.end, timeline.start);
        if (t < present) {
          present = t;
        }
      }
    }

    // Fallback: if no active timelines found, set present to 0
    if (present == 999999) {
      present = 0;
    } else {
      present = math.max(0, present);
    }

    // Update lastTimelineCount for animation tracking
    lastTimelineCount = [timelineCount[0], timelineCount[1]];
  }

  /// Find all checks on the board (cross-timeline check detection)
  ///
  /// Returns true if any king is in check by pieces from any timeline.
  bool findChecks() {
    bool hasChecks = false;
    displayedChecks = [];

    // Check all timelines for boards where the current player's king might be
    // In 5D chess, we need to find the king on any board, not just boards with matching turn
    for (final timelineDirection in timelines) {
      for (final timeline in timelineDirection) {
        if (!timeline.isActive) continue;

        // Check all boards in this timeline, not just the current board
        // We need to find the king wherever it is
        final activeBoards = timeline.getActiveBoards();
        for (final board in activeBoards) {
          // Find the king of the current player's side on this board
          Piece? king;
          int? kingX, kingY;
          for (int x = 0; x < 8; x++) {
            for (int y = 0; y < 8; y++) {
              final piece = board.getPiece(x, y);
              if (piece != null &&
                  piece.type == PieceType.king &&
                  piece.side == turn) {
                king = piece;
                kingX = x;
                kingY = y;
                break;
              }
            }
            if (king != null) break;
          }

          // If we found a king on this board, check if it's in check
          if (king != null) {
            // Check if king is in check (cross-timeline: checks pieces from ALL timelines)
            final inCheck = CheckDetector.isKingInCheckCrossTimeline(
              this,
              board,
              turn,
            );

            if (inCheck) {
              hasChecks = true;
              board.imminentCheck = true;

              // Store king position for display
              final kingPos = Vec4(kingX!, kingY!, board.l, board.t);
              displayedChecks.add([kingPos]);
            } else {
              board.imminentCheck = false;
            }
          }
        }
      }
    }

    return hasChecks;
  }

  /// Check if moves can be submitted
  ///
  /// Returns true if submit is available
  bool checkSubmitAvailable() {
    if (!_localPlayer[turn] || finished) {
      canSubmit = false;
      return false;
    }

    // Present must match player's turn
    canSubmit = present % 2 == turn;

    if (canSubmit) {
      // All active timelines must be ready for submit
      final minL = -math.min(timelineCount[0], timelineCount[1] + 1);
      final maxL = math.min(timelineCount[0] + 1, timelineCount[1]);

      for (int l = minL; l <= maxL; l++) {
        final timeline = getTimeline(l);
        if (!timeline.isSubmitReady(present)) {
          canSubmit = false;
          break;
        }
      }
    }

    return canSubmit;
  }

  /// Submit moves and advance turn
  ///
  /// [remote] - Whether this is a remote submit
  /// [fastForward] - Whether to skip animations
  /// [skipTime] - Whether to skip time management
  ///
  /// Returns a map with submit status and timing information
  Map<String, dynamic> submit({
    bool remote = false,
    bool fastForward = false,
    bool skipTime = false,
  }) {
    int? elapsedTime;
    int? timeGainedCap;

    if (!fastForward) {
      if (finished) {
        return {'submitted': false};
      }
      if ((!canSubmit || loading) && !remote) {
        return {'submitted': false};
      }
    }

    // Stop clock for current player
    if (!skipTime) {
      elapsedTime = players[turn].stopTime();
      timeGainedCap = players[turn].lastIncr;
    }

    // Create null moves for timelines that didn't have moves made
    // This ensures all active timelines advance to the next turn
    final timelinesWithMoves = <int>{};
    for (final move in currentTurnMoves) {
      if (!move.nullMove && move.sourceBoard != null) {
        timelinesWithMoves.add(move.sourceBoard!.l);
      } else if (move.nullMove && move.l != null) {
        timelinesWithMoves.add(move.l!);
      }
    }

    // Find active timelines that need null moves
    final minL = -math.min(timelineCount[0], timelineCount[1] + 1);
    final maxL = math.min(timelineCount[0] + 1, timelineCount[1]);

    for (int l = minL; l <= maxL; l++) {
      try {
        final timeline = getTimeline(l);
        if (!timeline.isActive) continue;

        final currentBoard = timeline.getCurrentBoard();
        if (currentBoard == null) continue;

        // If this timeline didn't have a move and its turn matches current turn,
        // create a null move to advance it
        if (!timelinesWithMoves.contains(l) && currentBoard.turn == turn) {
          final nullMove = Move.nullMove(
            this,
            currentBoard,
            fastForward: fastForward,
          );
          currentTurnMoves.add(nullMove);
        }
      } catch (e) {
        // Timeline doesn't exist, skip
        continue;
      }
    }

    // Clear current turn moves (they're now part of game history)
    currentTurnMoves.clear();

    // Update present (this will recalculate based on all timeline ends)
    movePresent(fastForward);

    // Advance turn
    turn = 1 - turn;

    // Find checks for new turn
    if (!fastForward) {
      findChecks();
    }

    // Start clock for new player
    if (!skipTime && getTimeline(0).end > 1) {
      players[turn].startTime();
    }

    canSubmit = false;

    return {
      'submitted': true,
      'elapsedTime': elapsedTime,
      'timeGainedCap': timeGainedCap,
    };
  }

  /// Make a move
  ///
  /// [sourcePiece] - Piece to move
  /// [targetPos] - Target position
  /// [promotionTo] - Promotion type (1-4, or null)
  ///
  /// Returns true if move was successful
  bool move(Piece sourcePiece, Vec4 targetPos, [int? promotionTo]) {
    // Verify target board's turn matches piece's side
    final targetBoard = getTimeline(targetPos.l).getBoard(targetPos.t);
    if (targetBoard == null || targetBoard.turn != sourcePiece.side) {
      return false;
    }

    // Verify it's the player's turn and they are local
    if (sourcePiece.side == turn && _localPlayer[turn]) {
      applyMove(
        instantiateMove(sourcePiece, targetPos, promotionTo, false, false),
        false,
      );
      checkSubmitAvailable();
      return true;
    }

    return false;
  }

  /// Apply a move to the game state
  ///
  /// [move] - Move to apply
  /// [fastForward] - Whether to skip animations
  void applyMove(Move move, bool fastForward) {
    currentTurnMoves.add(move);
    movePresent(fastForward);
    if (!fastForward) {
      findChecks();
    }
  }

  /// Execute moves (for replay and remote moves)
  ///
  /// [action] - Action type: 'move' or 'submit'
  /// [newCurrentMoves] - List of moves to execute
  /// [timeTaken] - Time taken for the move
  /// [fastForward] - Whether to skip animations
  ///
  /// Returns list of deleted moves
  List<Move> executeMove(
    String action,
    List<Move> newCurrentMoves,
    int timeTaken,
    bool fastForward,
  ) {
    // Map moves to ensure they have proper structure
    final mappedMoves = newCurrentMoves.map((m) {
      if (m.nullMove) {
        return m;
      } else {
        // Ensure move has from and to positions
        return m;
      }
    }).toList();

    final existingMoves = List<Move?>.filled(mappedMoves.length, null);
    final deletedMoves = <Move>[];

    // Find existing moves that match
    nextExistingMove:
    for (final move in currentTurnMoves) {
      for (int i = 0; i < mappedMoves.length; i++) {
        final newMove = mappedMoves[i];
        if (move.nullMove && newMove.nullMove) {
          if (move.l == newMove.l) {
            existingMoves[i] = move;
            continue nextExistingMove;
          }
        } else if (!move.nullMove && !newMove.nullMove) {
          if (move.from != null &&
              newMove.from != null &&
              move.to != null &&
              newMove.to != null &&
              move.from!.equals(newMove.from!) &&
              move.to!.equals(newMove.to!)) {
            existingMoves[i] = move;
            continue nextExistingMove;
          }
        }
      }
      deletedMoves.add(move);
    }

    // Create new moves that don't exist
    for (int i = 0; i < mappedMoves.length; i++) {
      if (existingMoves[i] == null) {
        final moveData = mappedMoves[i];
        Move newMove;

        if (moveData.nullMove) {
          // Create null move
          final timeline = getTimeline(moveData.l!);
          final lastBoard = timeline.getCurrentBoard();
          if (lastBoard != null) {
            newMove = Move.nullMove(this, lastBoard);
          } else {
            continue; // Skip invalid null move
          }
        } else {
          // Create regular move
          final sourcePiece = getPiece(moveData.from!);
          if (sourcePiece == null) {
            continue; // Skip invalid move
          }
          newMove = instantiateMove(
            sourcePiece,
            moveData.to!,
            moveData.promote,
            true,
            fastForward,
          );
        }

        applyMove(newMove, fastForward);
        existingMoves[i] = newMove;
      }
    }

    // Undo deleted moves
    for (final move in deletedMoves) {
      move.undo();
    }

    // Update present
    movePresent(fastForward);

    // Update current turn moves
    currentTurnMoves = existingMoves.whereType<Move>().toList();

    // Handle submit action
    if (action == 'submit') {
      final player = turn;
      submit(remote: true, fastForward: fastForward, skipTime: fastForward);
      if (!fastForward) {
        timeRemaining[player] += players[player].lastTurnTime - timeTaken;
        players[player].updateTime(timeRemaining[player]);
      }
    }

    return deletedMoves;
  }

  /// Undo last move
  void undo() {
    if (currentTurnMoves.isEmpty) {
      return;
    }

    Move? lastMove;
    if (_localPlayer[turn]) {
      // Local player: pop last move
      lastMove = currentTurnMoves.removeLast();
    } else {
      // Remote player: find last non-remote null move
      for (int i = currentTurnMoves.length - 1; i >= 0; i--) {
        final move = currentTurnMoves[i];
        if (move.nullMove && !move.remoteMove) {
          lastMove = currentTurnMoves.removeAt(i);
          break;
        }
      }
      if (lastMove == null) {
        return;
      }
    }

    lastMove.undo();

    if (currentTurnMoves.isEmpty) {
      movePresent(false);
    }

    findChecks();
    checkSubmitAvailable();
  }

  /// Check if the current player is in checkmate
  ///
  /// Uses SimpleCheckmateDetector for reliable checkmate detection.
  ///
  /// Returns true if the current player is in checkmate.
  bool isCheckmate() {
    return SimpleCheckmateDetector.isCheckmate(this);
  }

  /// Check if the current player is in stalemate
  ///
  /// Uses SimpleCheckmateDetector for reliable stalemate detection.
  ///
  /// Returns true if the current player is in stalemate.
  bool isStalemate() {
    return SimpleCheckmateDetector.isStalemate(this);
  }

  /// Check if the current player has any legal moves
  ///
  /// Uses SimpleCheckmateDetector for reliable move detection.
  ///
  /// Returns true if the current player has at least one legal move.
  bool hasLegalMoves() {
    return SimpleCheckmateDetector.hasLegalMoves(this);
  }

  /// End the game
  ///
  /// [winner] - Winner side: 0 = black, 1 = white, -1 = draw
  /// [cause] - Cause side: 0 = black, 1 = white, null = no cause
  /// [reason] - Reason: 'checkmate', 'stalemate', 'resign', 'timeout', 'draw'
  /// [inPast] - Whether this is ending in the past
  void end(int? winner, int? cause, String? reason, bool inPast) {
    players[0].stopTime();
    players[1].stopTime();
    finished = true;

    if (winner != null && winner >= 0) {
      // Set winner (placeholder - Player class doesn't have setWinner yet)
      // This will be implemented when we add game end logic
    }

    checkSubmitAvailable();
  }

  /// Destroy the game and cleanup
  void destroy() {
    players[0].stopTime();
    players[1].stopTime();
  }

  /// Get game options
  GameOptions get options => _options;

  /// Get local player flags
  List<bool> get localPlayer => _localPlayer;
}

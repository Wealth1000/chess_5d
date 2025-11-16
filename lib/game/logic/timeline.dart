import 'package:chess_5d/game/logic/board.dart';

/// Manages a sequence of boards in a timeline
///
/// Each timeline represents a branch of the game state.
/// Timelines are indexed by l (timeline number):
/// - Negative l = black player's timelines
/// - Positive l = white player's timelines
/// - l = 0 is the main timeline
class Timeline {
  Timeline({
    required this.game,
    required this.l,
    required int t,
    int? sourceL,
    bool fastForward = false,
  }) : start = t,
       end = t,
       boards = [] {
    // Initialize with empty board list
    // Boards will be added via setBoard()
  }

  /// The game this timeline belongs to
  dynamic game; // Game class (forward reference)

  /// Timeline index (negative for black, positive for white, 0 for main)
  final int l;

  /// First turn number in this timeline
  int start;

  /// Last turn number in this timeline
  int end;

  /// Side: 0 = black (if l < 0), 1 = white (if l >= 0)
  int get side => l < 0 ? 0 : 1;

  /// Boards in this timeline, indexed by turn number
  /// Access as boards[t - start] for turn t
  List<Board?> boards;

  /// Whether this timeline is active
  bool _active = true;

  /// Get a board at a specific turn number
  ///
  /// Returns null if turn is out of range
  Board? getBoard(int t) {
    if (t < start || t > end) {
      return null;
    }
    final index = t - start;
    if (index < 0 || index >= boards.length) {
      return null;
    }
    return boards[index];
  }

  /// Set a board at a specific turn number
  ///
  /// Expands the boards list if necessary
  void setBoard(int t, Board board) {
    print(
      'DEBUG Timeline.setBoard: Setting board at timeline l=$l, turn t=$t (current end=$end)',
    );

    // Ensure boards list is large enough
    final requiredLength = t - start + 1;
    while (boards.length < requiredLength) {
      boards.add(null);
    }

    final index = t - start;
    if (index >= 0 && index < boards.length) {
      boards[index] = board;
      board.timeline = this;

      // Update end if this is a new latest board
      if (t > end) {
        final oldEnd = end;
        end = t;
        print(
          'DEBUG Timeline.setBoard: Updated timeline end from $oldEnd to $end (new board added!)',
        );
      } else {
        print(
          'DEBUG Timeline.setBoard: Board set at turn $t (end remains $end)',
        );
      }
    }
  }

  /// Get the current board (board at the end turn)
  Board? getCurrentBoard() {
    return getBoard(end);
  }

  /// Remove the last board (pop)
  ///
  /// Returns the removed board, or null if timeline is empty
  Board? pop() {
    if (boards.isEmpty || end < start) {
      return null;
    }

    final board = boards[end - start];
    boards[end - start] = null;

    // Find the new end (last non-null board)
    int newEnd = end;
    while (newEnd >= start &&
        (newEnd - start >= boards.length || boards[newEnd - start] == null)) {
      newEnd--;
    }

    end = newEnd;
    return board;
  }

  /// Remove this timeline from the game
  void remove() {
    _active = false;
    // Remove all boards
    for (final board in boards) {
      board?.remove();
    }
    boards.clear();
  }

  /// Activate this timeline
  void activate() {
    _active = true;
  }

  /// Deactivate this timeline
  void deactivate() {
    _active = false;
  }

  /// Check if this timeline is active
  bool get isActive => _active;

  /// Check if this timeline is ready for submit
  ///
  /// A timeline is ready if its end turn is at least the present turn
  bool isSubmitReady(int present) {
    return _active && end >= present;
  }

  /// Get all active boards in this timeline
  List<Board> getActiveBoards() {
    return boards
        .whereType<Board>()
        .where((board) => board.active && !board.deleted)
        .toList();
  }

  /// Get the number of boards in this timeline
  int get boardCount => boards.whereType<Board>().length;

  @override
  String toString() =>
      'Timeline(l:$l, start:$start, end:$end, side:$side, active:$_active)';
}

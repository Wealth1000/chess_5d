import 'package:chess_5d/game/logic/piece.dart';
import 'package:chess_5d/game/logic/position.dart';

/// Represents a single 8x8 chess board at a specific timeline and turn
///
/// Each board is part of a timeline and contains pieces at specific positions.
class Board {
  /// Create a new board
  ///
  /// [game] - The game this board belongs to
  /// [l] - Timeline index
  /// [t] - Turn number
  /// [turn] - Current turn side (0=black, 1=white)
  /// [initialBoard] - Optional board to clone from
  /// [fastForward] - Whether to fast-forward setup (skip animations)
  Board({
    required this.game,
    required this.l,
    required this.t,
    required this.turn,
    Board? initialBoard,
    bool fastForward = false,
  }) : pieces = List.generate(8, (_) => List.filled(8, null)),
       active = true,
       deleted = false,
       castleAvailable = 0,
       imminentCheck = false {
    // If cloning from another board, copy pieces
    if (initialBoard != null) {
      for (int x = 0; x < 8; x++) {
        for (int y = 0; y < 8; y++) {
          final piece = initialBoard.pieces[x][y];
          if (piece != null) {
            piece.cloneToBoard(this);
          }
        }
      }
      castleAvailable = initialBoard.castleAvailable;
    }
  }

  /// Create a board by cloning another board
  ///
  /// [source] - Board to clone from
  /// [isBranch] - Whether this is a timeline branch
  /// [newL] - New timeline index (if branching)
  factory Board.fromBoard(Board source, {bool isBranch = false, int? newL}) {
    return Board(
      game: source.game,
      l: newL ?? source.l,
      t: source.t,
      turn: source.turn,
      initialBoard: source,
      fastForward: true,
    );
  }

  /// The game this board belongs to
  dynamic game; // Game class (forward reference)

  /// Timeline index (negative for black, positive for white, 0 for main)
  final int l;

  /// Turn number in this timeline
  final int t;

  /// Current turn side: 0 = black, 1 = white
  final int turn;

  /// 8x8 array of pieces, indexed as pieces[x][y]
  /// null means empty square
  List<List<Piece?>> pieces;

  /// Whether this board is currently active (being played on)
  bool active;

  /// Whether this board has been deleted
  bool deleted;

  /// The parent timeline this board belongs to
  dynamic timeline; // Timeline class (forward reference)

  /// Castling availability bitmask
  /// Bit 0: Black kingside, Bit 1: Black queenside
  /// Bit 2: White kingside, Bit 3: White queenside
  int castleAvailable;

  /// Whether this board has imminent checks
  bool imminentCheck;

  /// Get a piece at a specific position
  Piece? getPiece(int x, int y) {
    if (x < 0 || x >= 8 || y < 0 || y >= 8) {
      return null;
    }
    return pieces[x][y];
  }

  /// Get a piece at a Vec4 position (checks if position matches this board)
  Piece? getPieceAt(Vec4 pos) {
    if (pos.l != l || pos.t != t) {
      return null;
    }
    return getPiece(pos.x, pos.y);
  }

  /// Set a piece at a specific position
  void setPiece(int x, int y, Piece? piece) {
    if (x < 0 || x >= 8 || y < 0 || y >= 8) {
      return;
    }
    pieces[x][y] = piece;
    if (piece != null) {
      piece.x = x;
      piece.y = y;
      piece.board = this;
    }
  }

  /// Check if this board has imminent checks
  ///
  /// This is a placeholder - full implementation will come in Phase 2
  bool hasImminentChecks() {
    // TODO: Implement check detection in Phase 2
    return imminentCheck;
  }

  /// Make this board inactive
  void makeInactive() {
    active = false;
  }

  /// Make this board active
  void makeActive() {
    active = true;
  }

  /// Remove this board
  ///
  /// Returns a callback function for animation (if needed)
  /// Using dynamic for now since we don't want Flutter dependencies in logic layer
  dynamic remove() {
    deleted = true;
    active = false;
    // Remove all pieces
    for (int x = 0; x < 8; x++) {
      for (int y = 0; y < 8; y++) {
        final piece = pieces[x][y];
        if (piece != null) {
          piece.remove();
        }
        pieces[x][y] = null;
      }
    }
    // Return null for now (animation callback can be added later)
    return null;
  }

  /// Check if a square is empty
  bool isEmpty(int x, int y) {
    return getPiece(x, y) == null;
  }

  /// Check if a square contains an enemy piece
  bool hasEnemyPiece(int x, int y, int side) {
    final piece = getPiece(x, y);
    return piece != null && piece.side != side;
  }

  /// Check if a square contains a friendly piece
  bool hasFriendlyPiece(int x, int y, int side) {
    final piece = getPiece(x, y);
    return piece != null && piece.side == side;
  }

  /// Check if coordinates are within board bounds
  static bool isValidCoordinate(int x, int y) {
    return x >= 0 && x < 8 && y >= 0 && y < 8;
  }

  @override
  String toString() => 'Board(l:$l, t:$t, turn:$turn, active:$active)';
}

/// Castling rights constants
class CastlingRights {
  static const int blackKingside = 1 << 0; // 1
  static const int blackQueenside = 1 << 1; // 2
  static const int whiteKingside = 1 << 2; // 4
  static const int whiteQueenside = 1 << 3; // 8

  /// Check if black can castle kingside
  static bool canBlackCastleKingside(int rights) {
    return (rights & blackKingside) != 0;
  }

  /// Check if black can castle queenside
  static bool canBlackCastleQueenside(int rights) {
    return (rights & blackQueenside) != 0;
  }

  /// Check if white can castle kingside
  static bool canWhiteCastleKingside(int rights) {
    return (rights & whiteKingside) != 0;
  }

  /// Check if white can castle queenside
  static bool canWhiteCastleQueenside(int rights) {
    return (rights & whiteQueenside) != 0;
  }

  /// Remove castling rights for a side
  static int removeCastlingRights(
    int rights,
    int side, {
    bool kingside = true,
    bool queenside = true,
  }) {
    if (side == 0) {
      // Black
      if (kingside) rights &= ~blackKingside;
      if (queenside) rights &= ~blackQueenside;
    } else {
      // White
      if (kingside) rights &= ~whiteKingside;
      if (queenside) rights &= ~whiteQueenside;
    }
    return rights;
  }
}

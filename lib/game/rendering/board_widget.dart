import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:chess_5d/game/logic/board.dart';
import 'package:chess_5d/game/logic/position.dart';
import 'package:chess_5d/game/rendering/board_painter.dart';
import 'package:chess_5d/game/rendering/highlight.dart';
import 'package:chess_5d/game/rendering/arrow.dart';
import 'package:chess_5d/game/rendering/piece_renderer.dart';

/// Widget for displaying a chess board
///
/// This widget wraps the BoardPainter and provides interaction capabilities.
class BoardWidget extends StatelessWidget {
  const BoardWidget({
    super.key,
    required this.board,
    this.selectedSquare,
    this.legalMoves = const [],
    this.highlights = const [],
    this.arrows = const [],
    this.onSquareTapped,
    this.onSquareLongPressed,
    this.lightSquareColor,
    this.darkSquareColor,
    this.coordinatesVisible = true,
    this.flipBoard = false,
    this.size,
  });

  /// The board to display
  final Board board;

  /// Selected square (if any)
  final Vec4? selectedSquare;

  /// List of legal move destinations
  final List<Vec4> legalMoves;

  /// List of highlights to draw
  final List<Highlight> highlights;

  /// List of arrows to draw
  final List<Arrow> arrows;

  /// Callback when a square is tapped
  /// Can be async to handle promotion dialogs
  final Future<void> Function(Vec4)? onSquareTapped;

  /// Callback when a square is long-pressed
  final Future<void> Function(Vec4)? onSquareLongPressed;

  /// Color for light squares
  final Color? lightSquareColor;

  /// Color for dark squares
  final Color? darkSquareColor;

  /// Whether to show coordinates
  final bool coordinatesVisible;

  /// Whether to flip the board
  final bool flipBoard;

  /// Fixed size for the board (if null, uses available space)
  final double? size;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boardSize = size ?? constraints.maxWidth;
        final squareSize = boardSize / 8;

        return GestureDetector(
          onTapDown: (details) async {
            // Only handle taps on empty squares (pieces handle their own taps)
            if (onSquareTapped != null) {
              final square = _getSquareFromPosition(
                details.localPosition,
                boardSize,
              );
              if (square != null) {
                // Check if there's a piece on this square
                final piece = board.getPiece(square.x, square.y);
                // Only handle if no piece (pieces have their own tap handlers)
                if (piece == null) {
                  await onSquareTapped!(square);
                }
              }
            }
          },
          onLongPressStart: (details) async {
            if (onSquareLongPressed != null) {
              final square = _getSquareFromPosition(
                details.localPosition,
                boardSize,
              );
              if (square != null) {
                await onSquareLongPressed!(square);
              }
            }
          },
          child: SizedBox(
            width: boardSize,
            height: boardSize,
            child: Stack(
              children: [
                // Board background (squares, highlights, arrows, coordinates)
                CustomPaint(
                  size: Size(boardSize, boardSize),
                  painter: BoardPainter(
                    board: board,
                    selectedSquare: selectedSquare,
                    legalMoves: legalMoves,
                    highlights: highlights,
                    arrows: arrows,
                    lightSquareColor:
                        lightSquareColor ?? const Color(0xFFF0D9B5),
                    darkSquareColor: darkSquareColor ?? const Color(0xFFB58863),
                    coordinatesVisible: coordinatesVisible,
                    flipBoard: flipBoard,
                  ),
                ),
                // Pieces rendered as SVG widgets (each with its own tap handler)
                ..._buildPieces(boardSize, squareSize),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Build widgets for all pieces on the board
  List<Widget> _buildPieces(double boardSize, double squareSize) {
    final pieces = <Widget>[];

    for (int x = 0; x < 8; x++) {
      for (int y = 0; y < 8; y++) {
        final piece = board.getPiece(x, y);
        if (piece == null) {
          continue;
        }

        final displayX = flipBoard ? 7 - x : x;
        final displayY = flipBoard ? 7 - y : y;

        final left = displayX * squareSize;
        final top = displayY * squareSize;

        pieces.add(
          Positioned(
            left: left,
            top: top,
            width: squareSize,
            height: squareSize,
            child: GestureDetector(
              onTap: () async {
                if (onSquareTapped != null) {
                  // Check if this square matches a legal move - if so, use the legal move's position
                  // (which has the correct t value for next turn)
                  // This is important for captures, which should target the next turn
                  Vec4? square;
                  for (final move in legalMoves) {
                    if (move.x == x && move.y == y) {
                      // Found matching legal move - use its position (has correct l and t)
                      square = move;
                      break;
                    }
                  }
                  // If no matching legal move, use current board's position (for piece selection)
                  square ??= Vec4(x, y, board.l, board.t);
                  await onSquareTapped!(square);
                }
              },
              behavior: HitTestBehavior.opaque,
              child: Center(
                child: SvgPicture.asset(
                  PieceRenderer.getPrimaryAssetPath(piece),
                  fit: BoxFit.contain,
                  width: squareSize * 0.85,
                  height: squareSize * 0.85,
                ),
              ),
            ),
          ),
        );
      }
    }

    return pieces;
  }

  /// Get the square coordinates from a tap position
  /// If the tapped square matches a legal move, use the legal move's position (which has correct t value)
  Vec4? _getSquareFromPosition(Offset position, double boardSize) {
    final squareSize = boardSize / 8;
    final x = (position.dx / squareSize).floor();
    final y = (position.dy / squareSize).floor();

    if (x < 0 || x >= 8 || y < 0 || y >= 8) {
      return null;
    }

    final displayX = flipBoard ? 7 - x : x;
    final displayY = flipBoard ? 7 - y : y;

    // Check if this square matches a legal move - if so, use the legal move's position
    // (which has the correct t value for next turn)
    for (final move in legalMoves) {
      if (move.x == displayX && move.y == displayY) {
        // Found matching legal move - use its position (has correct l and t)
        return move;
      }
    }

    // No matching legal move - use current board's position (for piece selection)
    return Vec4(displayX, displayY, board.l, board.t);
  }
}

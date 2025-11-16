import 'package:flutter/material.dart';
import 'package:chess_5d/game/state/game_provider.dart';
import 'package:chess_5d/core/theme_provider.dart';
import 'package:chess_5d/game/logic/board.dart';
import 'package:chess_5d/game/logic/board_setup.dart';
import 'package:chess_5d/game/logic/position.dart';
import 'package:chess_5d/game/rendering/board_widget.dart';
import 'package:chess_5d/game/rendering/highlight.dart';

/// Mobile-friendly game screen matching the parallel view layout.
class GameScreen extends StatelessWidget {
  const GameScreen({super.key, required this.gameProvider, this.themeProvider});

  final GameProvider gameProvider;
  final ThemeProvider? themeProvider;

  /// Show the pause menu dialog
  void _showPauseMenu(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Container(
            padding: const EdgeInsets.all(24.0),
            constraints: const BoxConstraints(maxWidth: 300),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                Text(
                  'Game Menu',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24.0),
                // Resume button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    child: const Text('Resume'),
                  ),
                ),
                const SizedBox(height: 12.0),
                // Forfeit game button - resets board and goes back to previous page
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      // Close the dialog
                      Navigator.of(dialogContext).pop();
                      // Reset the game to the beginning
                      final options = gameProvider.game.options;
                      final localPlayer = gameProvider.game.localPlayer;
                      gameProvider.newGame(options, localPlayer);
                      // Navigate back to the previous page
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Forfeit Game'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      appBar: AppBar(
        title: const Text('5D Chess'),
        leading: IconButton(
          icon: const Icon(Icons.menu, size: 18),
          onPressed: () {
            _showPauseMenu(context);
          },
          style: IconButton.styleFrom(
            backgroundColor: Colors.black.withValues(alpha: 0.35),
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(6.0),
            minimumSize: const Size(40, 40),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        actions: [
          // Info button
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: const Icon(Icons.info, size: 18, color: Color(0xFF2196F3)),
              onPressed: () {},
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: 0.35),
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(6.0),
                minimumSize: const Size(40, 40),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Checkered background
            Positioned.fill(
              child: CustomPaint(
                painter: const _CheckeredBackgroundPainter(squareSize: 40.0),
              ),
            ),
            // Scrollable content area with boards
            _BlankBoardsView(gameProvider: gameProvider),

            // Fixed view mode buttons at the top
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: _ViewModeButtons(),
              ),
            ),

            // Fixed bottom action buttons at the bottom
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: _BottomActions(gameProvider: gameProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// View mode buttons (History View, Parallel View, Flip Persp.)
class _ViewModeButtons extends StatefulWidget {
  @override
  State<_ViewModeButtons> createState() => _ViewModeButtonsState();
}

class _ViewModeButtonsState extends State<_ViewModeButtons> {
  String _activeView = 'Parallel View';

  void _handleViewChange(String view) {
    setState(() {
      _activeView = view;
    });
    // TODO: Implement view change logic
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ViewButton(
            label: 'History View',
            isActive: _activeView == 'History View',
            onTap: () => _handleViewChange('History View'),
          ),
          const SizedBox(width: 8),
          _ViewButton(
            label: 'Parallel View',
            isActive: _activeView == 'Parallel View',
            onTap: () => _handleViewChange('Parallel View'),
          ),
          const SizedBox(width: 8),
          _ViewButton(
            label: 'Flip Persp.',
            isActive: _activeView == 'Flip Persp.',
            onTap: () => _handleViewChange('Flip Persp.'),
          ),
        ],
      ),
    );
  }
}

/// View mode button (History View, Parallel View, etc.)
class _ViewButton extends StatelessWidget {
  const _ViewButton({required this.label, this.isActive = false, this.onTap});

  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // All buttons use the same color
    const backgroundColor = Colors.black;

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(20),
      elevation: 2,
      child: InkWell(
        onTap: onTap ?? () {},
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          child: Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom action buttons
class _BottomActions extends StatelessWidget {
  const _BottomActions({required this.gameProvider});

  final GameProvider gameProvider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: _ActionButton(
              label: 'Undo Move',
              color: Colors.grey[800]!,
              onTap: () {
                gameProvider.undoMove();
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _ActionButton(
              label: 'Submit Moves',
              color: Colors.grey[800]!,
              onTap: () {
                gameProvider.submitMoves();
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// View for displaying blank boards with scrollable and zoomable background
class _BlankBoardsView extends StatefulWidget {
  const _BlankBoardsView({required this.gameProvider});

  final GameProvider gameProvider;

  @override
  State<_BlankBoardsView> createState() => _BlankBoardsViewState();
}

class _BlankBoardsViewState extends State<_BlankBoardsView> {
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  int _previousTurnCount = 0;

  @override
  void initState() {
    super.initState();
    // Listen to game provider changes
    widget.gameProvider.addListener(_onGameStateChanged);
    // Track initial turn count (use end, not end + 1)
    final timeline = widget.gameProvider.game.getTimeline(0);
    _previousTurnCount = timeline.end;
  }

  @override
  void dispose() {
    widget.gameProvider.removeListener(_onGameStateChanged);
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  void _onGameStateChanged() {
    // Always rebuild when game state changes
    setState(() {
      final timeline = widget.gameProvider.game.getTimeline(0);
      final currentTurnCount = timeline.end;

      print(
        'DEBUG GameScreen._onGameStateChanged: currentTurnCount=$currentTurnCount, _previousTurnCount=$_previousTurnCount',
      );

      // Check if a new board was added OR if the turn count changed (could be undo)
      if (currentTurnCount != _previousTurnCount) {
        print(
          'DEBUG GameScreen._onGameStateChanged: Turn count changed from $_previousTurnCount to $currentTurnCount',
        );
        if (currentTurnCount > _previousTurnCount) {
          // A new board was added - scroll to it after the frame is built
          print(
            'DEBUG GameScreen._onGameStateChanged: New board added - will scroll to it',
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToNewBoard();
          });
        } else {
          // Turn count decreased (undo happened) - update tracking but don't scroll
          print(
            'DEBUG GameScreen._onGameStateChanged: Turn count decreased (undo) - updating _previousTurnCount',
          );
        }
        _previousTurnCount = currentTurnCount;
      } else {
        print(
          'DEBUG GameScreen._onGameStateChanged: Turn count unchanged - no scroll needed',
        );
      }

      // Check for checkmate and show dialog
      if (widget.gameProvider.checkmateDetected) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showCheckmateDialog();
          widget.gameProvider.clearCheckmateFlag();
        });
      }
    });
  }

  void _scrollToNewBoard() {
    print(
      'DEBUG GameScreen._scrollToNewBoard: Attempting to scroll to new board',
    );
    if (_horizontalScrollController.hasClients &&
        _horizontalScrollController.position.maxScrollExtent > 0) {
      // Scroll to the rightmost board
      final maxScroll = _horizontalScrollController.position.maxScrollExtent;
      print(
        'DEBUG GameScreen._scrollToNewBoard: Scrolling to maxScroll=$maxScroll',
      );
      _horizontalScrollController.animateTo(
        maxScroll,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      print(
        'DEBUG GameScreen._scrollToNewBoard: Cannot scroll - hasClients=${_horizontalScrollController.hasClients}, maxScrollExtent=${_horizontalScrollController.hasClients ? _horizontalScrollController.position.maxScrollExtent : "N/A"}',
      );
    }
  }

  /// Show the checkmate dialog
  void _showCheckmateDialog() {
    final context = this.context;
    final gameProvider = widget.gameProvider;

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Container(
            padding: const EdgeInsets.all(24.0),
            constraints: const BoxConstraints(maxWidth: 300),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                Text(
                  'Checkmate!',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8.0),
                // Message
                Text(
                  'The game is over. Checkmate has been reached.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24.0),
                // Return to previous screen button - resets board and goes back
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      // Close the dialog
                      Navigator.of(dialogContext).pop();
                      // Reset the game to the beginning
                      final options = gameProvider.game.options;
                      final localPlayer = gameProvider.game.localPlayer;
                      gameProvider.newGame(options, localPlayer);
                      // Navigate back to the previous page
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Return to Previous Screen'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get all boards from the timeline (main timeline, all turns)
    final timeline = widget.gameProvider.game.getTimeline(0);
    final boards = <Board>[];

    // Debug prints commented out
    // print('DEBUG GameScreen.build: === START BUILD ===');
    // print(
    //   'DEBUG GameScreen.build: Timeline l=0, start=${timeline.start}, end=${timeline.end}',
    // );

    // Get all active boards from the timeline
    final activeBoards = timeline.getActiveBoards();
    // print('DEBUG GameScreen.build: Found ${activeBoards.length} active boards');
    for (final board in activeBoards) {
      // print(
      //   'DEBUG GameScreen.build: Active board at l=${board.l}, t=${board.t}, active=${board.active}, deleted=${board.deleted}',
      // );
      if (board.l == 0 && !board.deleted) {
        // print('DEBUG GameScreen.build: Adding active board at t=${board.t}');
        boards.add(board);
      }
    }

    // Also check boards by turn number directly (in case some aren't in activeBoards)
    final maxTurn = timeline.end;
    print(
      'DEBUG GameScreen.build: Checking boards from t=-1 to t=${maxTurn + 1}',
    );
    for (int t = -1; t <= maxTurn + 1; t++) {
      final board = timeline.getBoard(t);
      if (board != null) {
        print(
          'DEBUG GameScreen.build: Found board at t=$t: l=${board.l}, active=${board.active}, deleted=${board.deleted}',
        );
        if (!board.deleted && !boards.contains(board)) {
          print(
            'DEBUG GameScreen.build: Adding board at t=$t (not in activeBoards or already collected)',
          );
          boards.add(board);
        }
      }
    }

    // Also check if there are any unsubmitted moves that create boards at the next turn
    final currentTurnMoves = widget.gameProvider.game.currentTurnMoves;
    print(
      'DEBUG GameScreen.build: Checking ${currentTurnMoves.length} unsubmitted moves',
    );
    for (final move in currentTurnMoves) {
      if (!move.nullMove && move.to != null) {
        final targetPos = move.to!;
        print(
          'DEBUG GameScreen.build: Move targets l=${targetPos.l}, t=${targetPos.t}, maxTurn=$maxTurn',
        );
        if (targetPos.l == 0) {
          // Check if board exists at target position (even if t > maxTurn)
          final futureBoard = timeline.getBoard(targetPos.t);
          if (futureBoard != null) {
            print(
              'DEBUG GameScreen.build: Found board from move at t=${targetPos.t}, deleted=${futureBoard.deleted}',
            );
            if (!futureBoard.deleted && !boards.contains(futureBoard)) {
              print(
                'DEBUG GameScreen.build: Adding future board at t=${targetPos.t}',
              );
              boards.add(futureBoard);
            }
          } else {
            print(
              'DEBUG GameScreen.build: Board at t=${targetPos.t} does not exist yet',
            );
          }
        }
      }
    }

    // print('DEBUG GameScreen.build: Total boards collected: ${boards.length}');

    // If no boards found, create initial board
    if (boards.isEmpty) {
      // print('DEBUG GameScreen.build: No boards found, creating initial board');
      final initialBoard = BoardSetup.createInitialBoard(
        widget.gameProvider.game,
        0,
        0,
        1,
      );
      return _buildBoardsRow([initialBoard]);
    }

    // Sort boards by turn number to ensure correct order
    boards.sort((a, b) => a.t.compareTo(b.t));
    print(
      'DEBUG GameScreen.build: Final board count before build: ${boards.length}',
    );
    for (final board in boards) {
      print(
        'DEBUG GameScreen.build: Final board list - l=${board.l}, t=${board.t}, turn=${board.turn}, active=${board.active}, deleted=${board.deleted}',
      );
    }
    print('DEBUG GameScreen.build: === END BUILD ===');

    return _buildBoardsRow(boards);
  }

  Widget _buildBoardsRow(List<Board> boards) {
    // print('DEBUG GameScreen: Building ${boards.length} boards');
    // for (final board in boards) {
    //   print(
    //     'DEBUG GameScreen: Board at l=${board.l}, t=${board.t}, turn=${board.turn}',
    //   );
    // }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate available height (screen height minus safe area and button areas)
        final availableHeight = constraints.maxHeight;
        final availableWidth = constraints.maxWidth;

        // Use nested scroll views for both horizontal and vertical scrolling
        return SizedBox(
          width: availableWidth,
          height: availableHeight,
          child: SingleChildScrollView(
            controller: _verticalScrollController,
            scrollDirection: Axis.vertical,
            child: SizedBox(
              height: availableHeight, // Minimum height for vertical scrolling
              child: SingleChildScrollView(
                controller: _horizontalScrollController,
                scrollDirection: Axis.horizontal,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: boards.map((board) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: _buildBoardView(board),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBoardView(Board board) {
    // Get selected piece and legal moves from game provider
    final selectedPiece = widget.gameProvider.selectedPiece;
    final legalMoves = widget.gameProvider.legalMoves;
    final currentTurn = widget.gameProvider.turn; // 0 = black, 1 = white

    // Convert selected piece to Vec4 position if it exists
    Vec4? selectedSquare;
    if (selectedPiece != null && selectedPiece.board == board) {
      selectedSquare = Vec4(selectedPiece.x, selectedPiece.y, board.l, board.t);
    }

    // Filter legal moves to only show moves on this board (or next turn on same timeline)
    // In 5D chess, moves are to the next turn, so we show moves that will happen on this timeline
    final boardLegalMoves = legalMoves.where((move) {
      return move.l == board.l && (move.t == board.t || move.t == board.t + 1);
    }).toList();

    // Get check highlights from game state
    final checkHighlights = <Highlight>[];
    final game = widget.gameProvider.game;

    for (final checkList in game.displayedChecks) {
      if (checkList.isNotEmpty) {
        final kingPos = checkList[0];
        // Only show check highlight if it's on this board
        if (kingPos.l == board.l && kingPos.t == board.t) {
          checkHighlights.add(
            Highlight(position: kingPos, type: HighlightType.check),
          );
        }
      }
    }

    // Determine outline color based on current turn
    // White's turn (1) = white outline, Black's turn (0) = black outline
    final outlineColor = currentTurn == 1 ? Colors.white : Colors.black;

    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: outlineColor, width: 3.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SizedBox(
        width: 300,
        height: 300,
        child: BoardWidget(
          board: board,
          selectedSquare: selectedSquare,
          legalMoves: boardLegalMoves,
          highlights: checkHighlights,
          onSquareTapped: _handleSquareTap,
          coordinatesVisible: true,
        ),
      ),
    );
  }

  Future<void> _handleSquareTap(Vec4 position) async {
    widget.gameProvider.handleSquareTap(position);
  }
}

/// Infinite checkered background painter
///
/// Draws an endless checkered pattern by painting squares far beyond
/// the visible area, making it appear infinite even when zooming out.
class _CheckeredBackgroundPainter extends CustomPainter {
  const _CheckeredBackgroundPainter({this.squareSize = 40.0});

  final double squareSize;

  @override
  void paint(Canvas canvas, Size size) {
    // Very large padding so zoom out never shows the end
    const double padding = 5000.0;

    const lightGrey = Color(0xFFE0E0E0);
    const lighterGrey = Color(0xFFF0F0F0);

    final lightPaint = Paint()..color = lightGrey;
    final darkPaint = Paint()..color = lighterGrey;

    // Draw an extremely large region around the visible canvas
    final double left = -padding;
    final double top = -padding;
    final double right = size.width + padding;
    final double bottom = size.height + padding;

    for (double y = top; y < bottom; y += squareSize) {
      for (double x = left; x < right; x += squareSize) {
        final isDark =
            ((x / squareSize).floor() + (y / squareSize).floor()) % 2 == 0;
        canvas.drawRect(
          Rect.fromLTWH(x, y, squareSize, squareSize),
          isDark ? darkPaint : lightPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Action button (Undo, Submit)
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: color,
      borderRadius: BorderRadius.circular(20),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

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
            // Present indicator bar (vertical bar through the most recent board)
            // Placed BEFORE boards in Stack so it renders behind them
            Builder(
              builder: (context) {
                final containerKey =
                    GlobalKey<_PresentIndicatorBarContainerState>();
                return Stack(
                  children: [
                    _PresentIndicatorBarContainer(
                      key: containerKey,
                      gameProvider: gameProvider,
                    ),
                    // Scrollable content area with boards
                    _BlankBoardsView(
                      gameProvider: gameProvider,
                      onScrollControllerReady: (controller) {
                        containerKey.currentState?._onScrollControllerReady(
                          controller,
                        );
                      },
                    ),
                  ],
                );
              },
            ),

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
  const _BlankBoardsView({
    required this.gameProvider,
    this.onScrollControllerReady,
  });

  final GameProvider gameProvider;
  final void Function(ScrollController)? onScrollControllerReady;

  @override
  State<_BlankBoardsView> createState() => _BlankBoardsViewState();
}

class _BlankBoardsViewState extends State<_BlankBoardsView>
    with TickerProviderStateMixin {
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  int _previousTurnCount = 0;

  // Track boards and their animation states
  final Map<int, AnimationController> _boardAnimationControllers = {};
  final Set<int> _boardsBeingDeleted = {};
  final Set<int> _boardsBeingCreated = {};
  List<Board> _previousBoards = [];

  @override
  void initState() {
    super.initState();
    // Listen to game provider changes
    widget.gameProvider.addListener(_onGameStateChanged);
    // Track initial turn count (use end, not end + 1)
    final timeline = widget.gameProvider.game.getTimeline(0);
    _previousTurnCount = timeline.end;
    // Initialize previous boards list
    _previousBoards = _getCurrentBoards();
    // Initialize animation controllers for existing boards
    for (final board in _previousBoards) {
      final controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      );
      controller.value = 1.0; // Existing boards are fully visible
      _boardAnimationControllers[board.t] = controller;
    }
    // Notify parent about scroll controller
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onScrollControllerReady?.call(_horizontalScrollController);
    });
  }

  @override
  void dispose() {
    widget.gameProvider.removeListener(_onGameStateChanged);
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    // Dispose all animation controllers
    for (final controller in _boardAnimationControllers.values) {
      controller.dispose();
    }
    _boardAnimationControllers.clear();
    super.dispose();
  }

  void _onGameStateChanged() {
    // Always rebuild when game state changes
    setState(() {
      final timeline = widget.gameProvider.game.getTimeline(0);
      final currentTurnCount = timeline.end;

      // Get current boards to detect changes
      final currentBoards = _getCurrentBoards();
      final currentBoardTurns = currentBoards.map((b) => b.t).toSet();
      final previousBoardTurns = _previousBoards.map((b) => b.t).toSet();

      // Detect newly created boards
      final newBoards = currentBoardTurns.difference(previousBoardTurns);
      for (final turn in newBoards) {
        if (!_boardAnimationControllers.containsKey(turn)) {
          // Create animation controller for new board
          final controller = AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 300),
          );
          _boardAnimationControllers[turn] = controller;
          _boardsBeingCreated.add(turn);
          // Start fade-in animation
          controller.forward(from: 0.0);
          // Remove from being created after animation
          controller.addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              setState(() {
                _boardsBeingCreated.remove(turn);
              });
            }
          });
        }
      }

      // Detect boards being deleted (present in previous but not in current)
      final deletedBoards = previousBoardTurns.difference(currentBoardTurns);
      for (final turn in deletedBoards) {
        if (_boardAnimationControllers.containsKey(turn) &&
            !_boardsBeingDeleted.contains(turn)) {
          _boardsBeingDeleted.add(turn);
          final controller = _boardAnimationControllers[turn]!;
          // Start fade-out animation
          controller.reverse().then((_) {
            // Clean up after animation completes
            if (mounted) {
              setState(() {
                _boardsBeingDeleted.remove(turn);
                controller.dispose();
                _boardAnimationControllers.remove(turn);
                // Remove from previous boards as well
                _previousBoards.removeWhere((b) => b.t == turn);
              });
            }
          });
        } else if (!_boardAnimationControllers.containsKey(turn)) {
          // Board is being deleted but doesn't have an animation controller yet
          // This can happen if the board was just created and immediately deleted
          // Create a controller and animate it out
          final controller = AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 300),
          );
          controller.value = 1.0; // Start at full opacity
          _boardAnimationControllers[turn] = controller;
          _boardsBeingDeleted.add(turn);
          // Start fade-out animation
          controller.reverse().then((_) {
            // Clean up after animation completes
            if (mounted) {
              setState(() {
                _boardsBeingDeleted.remove(turn);
                controller.dispose();
                _boardAnimationControllers.remove(turn);
                // Remove from previous boards as well
                _previousBoards.removeWhere((b) => b.t == turn);
              });
            }
          });
        }
      }

      // Update previous boards AFTER detecting changes
      // This ensures we have the boards stored before they're deleted
      _previousBoards = List.from(currentBoards);

      // Check if a new board was added OR if the turn count changed (could be undo)
      if (currentTurnCount != _previousTurnCount) {
        if (currentTurnCount > _previousTurnCount) {
          // A new board was added - scroll to it after the frame is built
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToNewBoard();
          });
        }
        _previousTurnCount = currentTurnCount;
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

  List<Board> _getCurrentBoards() {
    final timeline = widget.gameProvider.game.getTimeline(0);
    final boards = <Board>[];

    // Get all active boards from the timeline
    final activeBoards = timeline.getActiveBoards();
    for (final board in activeBoards) {
      if (board.l == 0 && !board.deleted) {
        boards.add(board);
      }
    }

    // Also check boards by turn number directly
    final maxTurn = timeline.end;
    for (int t = -1; t <= maxTurn + 1; t++) {
      final board = timeline.getBoard(t);
      if (board != null && !board.deleted && !boards.contains(board)) {
        boards.add(board);
      }
    }

    // Also check if there are any unsubmitted moves that create boards at the next turn
    final currentTurnMoves = widget.gameProvider.game.currentTurnMoves;
    for (final move in currentTurnMoves) {
      if (!move.nullMove && move.to != null) {
        final targetPos = move.to!;
        if (targetPos.l == 0) {
          final futureBoard = timeline.getBoard(targetPos.t);
          if (futureBoard != null &&
              !futureBoard.deleted &&
              !boards.contains(futureBoard)) {
            boards.add(futureBoard);
          }
        }
      }
    }

    // Include boards that are being deleted (for animation purposes)
    for (final turn in _boardsBeingDeleted) {
      // Find the board from previous boards list or timeline
      Board? deletedBoard;
      try {
        deletedBoard = _previousBoards.firstWhere((b) => b.t == turn);
      } catch (e) {
        deletedBoard = timeline.getBoard(turn);
      }
      if (deletedBoard != null && !boards.contains(deletedBoard)) {
        boards.add(deletedBoard);
      }
    }

    boards.sort((a, b) => a.t.compareTo(b.t));
    return boards;
  }

  void _scrollToNewBoard() {
    // print(
    //   'DEBUG GameScreen._scrollToNewBoard: Attempting to scroll to new board',
    // );
    if (_horizontalScrollController.hasClients &&
        _horizontalScrollController.position.maxScrollExtent > 0) {
      // Scroll to the rightmost board
      final maxScroll = _horizontalScrollController.position.maxScrollExtent;
      // print(
      //   'DEBUG GameScreen._scrollToNewBoard: Scrolling to maxScroll=$maxScroll',
      // );
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
    // Get current boards
    final boards = _getCurrentBoards();

    // If no boards found, create initial board
    if (boards.isEmpty) {
      final initialBoard = BoardSetup.createInitialBoard(
        widget.gameProvider.game,
        0,
        0,
        1,
      );
      return _buildBoardsRow([initialBoard]);
    }

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
                        // Get animation controller for this board
                        final controller = _boardAnimationControllers[board.t];
                        if (controller != null) {
                          // Board has animation - use animated view
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                            ),
                            child: _buildAnimatedBoardView(board, controller),
                          );
                        }
                        // Fallback: board without animation (shouldn't happen after init)
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

  Widget _buildAnimatedBoardView(Board board, AnimationController controller) {
    // Create fade and scale animations
    final fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));
    final scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOut));

    return FadeTransition(
      opacity: fadeAnimation,
      child: ScaleTransition(
        scale: scaleAnimation,
        child: _buildBoardView(board),
      ),
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

/// Container for present indicator bar that manages scroll controller
class _PresentIndicatorBarContainer extends StatefulWidget {
  const _PresentIndicatorBarContainer({super.key, required this.gameProvider});

  final GameProvider gameProvider;

  @override
  State<_PresentIndicatorBarContainer> createState() =>
      _PresentIndicatorBarContainerState();
}

class _PresentIndicatorBarContainerState
    extends State<_PresentIndicatorBarContainer> {
  ScrollController? _scrollController;

  void _onScrollControllerReady(ScrollController controller) {
    setState(() {
      _scrollController = controller;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_scrollController == null) {
      return const SizedBox.shrink();
    }
    return _PresentIndicatorBar(
      gameProvider: widget.gameProvider,
      scrollController: _scrollController!,
    );
  }
}

/// Present indicator bar widget
///
/// Displays a vertical bar that passes through the most recent board (the present).
/// The bar changes color based on whose turn it is.
class _PresentIndicatorBar extends StatefulWidget {
  const _PresentIndicatorBar({
    required this.gameProvider,
    required this.scrollController,
  });

  final GameProvider gameProvider;
  final ScrollController scrollController;

  @override
  State<_PresentIndicatorBar> createState() => _PresentIndicatorBarState();
}

class _PresentIndicatorBarState extends State<_PresentIndicatorBar>
    with TickerProviderStateMixin {
  AnimationController? _positionAnimationController;
  Animation<double>? _positionAnimation;
  double _targetBarPosition = 0.0;
  double _lastKnownPosition =
      0.0; // Keep last known position to prevent disappearing
  int? _previousMostRecentBoardT;

  @override
  void initState() {
    super.initState();
    widget.gameProvider.addListener(_onGameStateChanged);
    widget.scrollController.addListener(_onScroll);
    _positionAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _positionAnimation = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _positionAnimationController!,
        curve: Curves.easeInOut,
      ),
    );
    _positionAnimation!.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    widget.gameProvider.removeListener(_onGameStateChanged);
    widget.scrollController.removeListener(_onScroll);
    _positionAnimationController?.dispose();
    super.dispose();
  }

  bool _isScrolling = false;

  void _onScroll() {
    // Mark that we're scrolling - build will handle updating position immediately
    _isScrolling = true;
    setState(() {});
  }

  void _onGameStateChanged() {
    // Just trigger rebuild - build will handle animation logic
    setState(() {});
  }

  bool _updateTargetPosition(BuildContext context) {
    final timeline = widget.gameProvider.game.getTimeline(0);
    final mostRecentBoard = timeline.getBoard(timeline.end);

    if (mostRecentBoard == null) {
      return false; // Indicate failure
    }

    // Board layout measurements
    const boardCoreWidth = 300.0;
    const boardContainerPadding = 8.0;
    const boardBorderWidth = 3.0;
    const boardOuterPadding = 16.0;
    const boardContainerWidth =
        boardCoreWidth + (boardContainerPadding * 2) + (boardBorderWidth * 2);
    const totalBoardWidth = boardContainerWidth + (boardOuterPadding * 2);

    // Get all boards
    final boards = <Board>[];
    final activeBoards = timeline.getActiveBoards();
    for (final board in activeBoards) {
      if (board.l == 0 && !board.deleted) {
        boards.add(board);
      }
    }

    final maxTurn = timeline.end;
    for (int t = -1; t <= maxTurn + 1; t++) {
      final board = timeline.getBoard(t);
      if (board != null && !board.deleted && !boards.contains(board)) {
        boards.add(board);
      }
    }

    boards.sort((a, b) => a.t.compareTo(b.t));

    if (boards.isEmpty) {
      return false; // Indicate failure
    }

    final mostRecentIndex = boards.length - 1;
    final screenWidth = MediaQuery.of(context).size.width;
    final totalBoardsWidth = boards.length * totalBoardWidth;
    final contentStartX = (totalBoardsWidth > screenWidth)
        ? 0.0
        : (screenWidth - totalBoardsWidth) / 2;
    final boardCenterXInContent =
        contentStartX +
        (mostRecentIndex * totalBoardWidth) +
        (boardOuterPadding + (boardContainerWidth / 2));
    final scrollOffset = widget.scrollController.hasClients
        ? widget.scrollController.offset
        : 0.0;
    final boardCenterXOnScreen = boardCenterXInContent - scrollOffset;
    const barWidth = boardCoreWidth * 0.8;
    _targetBarPosition = boardCenterXOnScreen - (barWidth / 2);
    return true; // Indicate success
  }

  @override
  Widget build(BuildContext context) {
    // Get the most recent board (the present)
    final timeline = widget.gameProvider.game.getTimeline(0);
    final mostRecentBoard = timeline.getBoard(timeline.end);

    // Get current turn (0 = black, 1 = white)
    final currentTurn = widget.gameProvider.turn;
    final barColor = currentTurn == 1 ? Colors.white : Colors.black;

    // If board is null, use last known position to prevent disappearing
    if (mostRecentBoard == null) {
      final barWidth = 300.0 * 0.8;
      final barPosition = _positionAnimation?.value ?? _lastKnownPosition;

      // If we have no position at all, don't show the bar
      if (barPosition == 0.0 && _lastKnownPosition == 0.0) {
        return const SizedBox.shrink();
      }

      return Positioned(
        left: barPosition,
        top: 0,
        bottom: 0,
        child: IgnorePointer(
          child: Container(
            width: barWidth,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  _lightenColor(barColor, 0.1).withValues(alpha: 0.85),
                  barColor.withValues(alpha: 0.9),
                  barColor.withValues(alpha: 0.9),
                  _lightenColor(barColor, 0.1).withValues(alpha: 0.85),
                ],
                stops: const [0.0, 0.2, 0.8, 1.0],
              ),
              border: Border.symmetric(
                horizontal: BorderSide(color: barColor, width: 2.0),
              ),
            ),
          ),
        ),
      );
    }

    // Update target position - only proceed if successful
    final positionUpdateSuccess = _updateTargetPosition(context);

    // Get current position - prefer animation value, fall back to last known or target
    final currentPosition =
        _positionAnimation?.value ??
        (_lastKnownPosition != 0.0 ? _lastKnownPosition : _targetBarPosition);

    // If position update failed, use last known position and don't animate
    if (!positionUpdateSuccess) {
      final barWidth = 300.0 * 0.8;
      final barPosition = currentPosition;
      if (barPosition != 0.0) {
        _lastKnownPosition = barPosition;
      }
      return Positioned(
        left: barPosition,
        top: 0,
        bottom: 0,
        child: IgnorePointer(
          child: Container(
            width: barWidth,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  _lightenColor(barColor, 0.1).withValues(alpha: 0.85),
                  barColor.withValues(alpha: 0.9),
                  barColor.withValues(alpha: 0.9),
                  _lightenColor(barColor, 0.1).withValues(alpha: 0.85),
                ],
                stops: const [0.0, 0.2, 0.8, 1.0],
              ),
              border: Border.symmetric(
                horizontal: BorderSide(color: barColor, width: 2.0),
              ),
            ),
          ),
        ),
      );
    }

    final currentBoardT = mostRecentBoard.t;

    // Handle initialization
    if (_previousMostRecentBoardT == null) {
      _previousMostRecentBoardT = currentBoardT;
      _lastKnownPosition = _targetBarPosition;
      if (_positionAnimationController != null) {
        _positionAnimation =
            Tween<double>(
              begin: _targetBarPosition,
              end: _targetBarPosition,
            ).animate(
              CurvedAnimation(
                parent: _positionAnimationController!,
                curve: Curves.easeInOut,
              ),
            );
        _positionAnimation!.addListener(() {
          setState(() {});
        });
        _positionAnimationController!.value = 1.0;
      }
    }
    // Handle scrolling - update position immediately without animation
    else if (_isScrolling) {
      _isScrolling = false;
      if (_positionAnimationController != null) {
        _positionAnimation =
            Tween<double>(
              begin: currentPosition,
              end: _targetBarPosition,
            ).animate(
              CurvedAnimation(
                parent: _positionAnimationController!,
                curve: Curves.easeInOut,
              ),
            );
        _positionAnimation!.addListener(() {
          setState(() {});
        });
        // Set to end immediately when scrolling
        _positionAnimationController!.value = 1.0;
        _lastKnownPosition = _targetBarPosition;
      }
    }
    // Handle new board created - animate from current position to new target
    else if (_previousMostRecentBoardT != currentBoardT) {
      // Only animate if we have a valid current position and target position
      if (currentPosition != 0.0 &&
          _targetBarPosition != 0.0 &&
          _positionAnimationController != null) {
        _positionAnimation =
            Tween<double>(
              begin: currentPosition,
              end: _targetBarPosition,
            ).animate(
              CurvedAnimation(
                parent: _positionAnimationController!,
                curve: Curves.easeInOut,
              ),
            );
        _positionAnimation!.addListener(() {
          setState(() {});
        });
        _positionAnimationController!.forward(from: 0.0);
      }
      _previousMostRecentBoardT = currentBoardT;
      _lastKnownPosition = _targetBarPosition;
    } else {
      // No change - just update last known position
      _lastKnownPosition = _targetBarPosition;
    }

    // Use the animated position value, with fallbacks
    final barWidth = 300.0 * 0.8; // Leave 10% margin on each side
    final barPosition =
        _positionAnimation?.value ??
        (_lastKnownPosition != 0.0 ? _lastKnownPosition : _targetBarPosition);

    // Update last known position for next frame
    if (barPosition != 0.0) {
      _lastKnownPosition = barPosition;
    }

    return Positioned(
      left: barPosition,
      top: 0,
      bottom: 0,
      child: IgnorePointer(
        child: Container(
          width: barWidth,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                _lightenColor(barColor, 0.1).withValues(alpha: 0.85),
                barColor.withValues(alpha: 0.9),
                barColor.withValues(alpha: 0.9),
                _lightenColor(barColor, 0.1).withValues(alpha: 0.85),
              ],
              stops: const [0.0, 0.2, 0.8, 1.0],
            ),
            border: Border.symmetric(
              horizontal: BorderSide(color: barColor, width: 2.0),
            ),
          ),
        ),
      ),
    );
  }

  Color _lightenColor(Color color, double amount) {
    final hslColor = HSLColor.fromColor(color);
    final lightness = (hslColor.lightness + amount).clamp(0.0, 1.0);
    return hslColor.withLightness(lightness.toDouble()).toColor();
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

import 'package:chess_5d/core/utils.dart';
import 'package:chess_5d/core/constants.dart';
import 'package:chess_5d/game/state/game_provider.dart';
import 'package:chess_5d/game/logic/game_options.dart';
import 'package:chess_5d/ui/screens/game_screen.dart';
import 'package:chess_5d/ui/utils/game_options_helper.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NewGameScreen extends StatefulWidget {
  const NewGameScreen({super.key});

  @override
  State<NewGameScreen> createState() => _NewGameScreenState();
}

class _NewGameScreenState extends State<NewGameScreen> {
  String _selectedMode = 'Local';
  String _selectedTimeControl = 'No Clock (recommended)';
  String _selectedVariant = 'Standard';

  final List<String> _gameModes = [
    'Local',
    'CPU',
    'Public',
    'Custom',
    'Private',
  ];

  final List<String> _timeControls = [
    'No Clock (recommended)',
    'Short Clock',
    'Medium Clock',
    'Long Clock',
  ];

  final List<String> _variants = [
    'Standard',
    'Random',
    'Simple - No Bishops',
    'Simple - No Knights',
    'Simple - No Rooks',
    'Simple - No Queens',
    'Simple - Knights vs. Bishops',
    'Simple - Simple Set',
  ];

  String get _modeDisplayText {
    switch (_selectedMode) {
      case 'Local':
        return 'Local Match';
      case 'CPU':
        return 'CPU Match';
      case 'Public':
        return 'Public Match';
      case 'Custom':
        return 'Custom Match';
      case 'Private':
        return 'Private Match';
      default:
        return 'Local Match';
    }
  }

  void _showTimeControlDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return _TimeControlDialog(
          timeControls: _timeControls,
          selected: _selectedTimeControl,
          onSelect: (value) {
            setState(() {
              _selectedTimeControl = value;
            });
            Navigator.pop(context);
          },
        );
      },
    );
  }

  void _showVariantDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return _VariantDialog(
          variants: _variants,
          selected: _selectedVariant,
          onSelect: (value) {
            setState(() {
              _selectedVariant = value;
            });
            Navigator.pop(context);
          },
        );
      },
    );
  }

  /// Start a new game with the selected options
  void _startGame(BuildContext context) {
    try {
      // Validate variant
      if (!GameOptionsHelper.isValidVariant(_selectedVariant)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Invalid variant: $_selectedVariant',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Create game options
      final gameOptions = GameOptionsHelper.createGameOptions(
        variantString: _selectedVariant,
        timeControlString: _selectedTimeControl,
        gameMode: _selectedMode,
      );

      // Create game provider
      final localPlayer = GameOptionsHelper.getLocalPlayerFlags(_selectedMode);
      final gameProvider = GameProvider(
        options: gameOptions,
        localPlayer: localPlayer,
      );

      // Navigate to game screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GameScreen(gameProvider: gameProvider),
        ),
      );
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error starting game: $e', style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = Responsive.getScreenWidth(context);
    final spacing = Responsive.getSpacing(context);
    final padding = Responsive.getScreenPadding(context);
    final titleSize = ResponsiveFontSize.getTitleSize(screenWidth);
    final bodySize = ResponsiveFontSize.getBodySize(screenWidth);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'New Game',
          style: GoogleFonts.orbitron(
            color: Theme.of(context).colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
            fontSize: titleSize * 0.7,
            letterSpacing: 1.0,
          ),
        ),
        toolbarHeight: screenWidth < Breakpoints.mobileMedium ? 60 : 70,
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: Responsive.getMaxContentWidth(context),
            ),
            padding: padding,
            child: Column(
              children: [
                SizedBox(height: spacing * 2),
                Text(
                  'Versus - $_modeDisplayText',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.orbitron(
                    fontSize: titleSize * 0.6,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                    letterSpacing: 1.0,
                  ),
                ),
                SizedBox(height: spacing * 3),
                // Game Mode Selection Buttons
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: spacing * 0.8,
                  runSpacing: spacing * 0.8,
                  children: _gameModes.map((mode) {
                    final isSelected = _selectedMode == mode;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedMode = mode;
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: spacing * 1.5,
                          vertical: spacing,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(context).colorScheme.secondary
                              : Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.secondary
                                .withValues(alpha: isSelected ? 1.0 : 0.3),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: isSelected ? 0.2 : 0.1,
                              ),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          mode,
                          style: GoogleFonts.inter(
                            fontSize: bodySize - 1,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Theme.of(context).colorScheme.onSecondary
                                : Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                SizedBox(height: spacing * 3),
                // Game Options Card
                Container(
                  width: double.infinity,
                  constraints: BoxConstraints(
                    maxWidth: Responsive.getMaxContentWidth(context) * 0.9,
                  ),
                  padding: EdgeInsets.all(spacing * 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.secondary.withValues(alpha: 0.1),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Time Control Selection
                      Text(
                        'Select time control:',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: bodySize,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      SizedBox(height: spacing),
                      Center(
                        child: _buildOptionButton(
                          _selectedTimeControl,
                          _showTimeControlDialog,
                          context,
                          bodySize,
                          spacing,
                        ),
                      ),
                      SizedBox(height: spacing * 2),
                      // Variant Selection
                      Text(
                        'Select variant:',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: bodySize,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      SizedBox(height: spacing),
                      Center(
                        child: _buildOptionButton(
                          _selectedVariant,
                          _showVariantDialog,
                          context,
                          bodySize,
                          spacing,
                        ),
                      ),
                      SizedBox(height: spacing * 2),
                      // Play Button (disabled for Public, CPU, Custom, Private)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _selectedMode == 'Local'
                              ? () => _startGame(context)
                              : null,
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              vertical: spacing * 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Play',
                            style: GoogleFonts.inter(
                              fontSize: bodySize + 2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionButton(
    String label,
    VoidCallback onTap,
    BuildContext context,
    double bodySize,
    double spacing,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: spacing * 1.5,
          vertical: spacing * 1.2,
        ),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.secondary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.secondary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: bodySize,
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(width: spacing * 0.5),
            Icon(
              Icons.arrow_drop_down,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeControlDialog extends StatelessWidget {
  const _TimeControlDialog({
    required this.timeControls,
    required this.selected,
    required this.onSelect,
  });
  final List<String> timeControls;
  final String selected;
  final Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    final spacing = Responsive.getSpacing(context);
    final bodySize = ResponsiveFontSize.getBodySize(
      Responsive.getScreenWidth(context),
    );
    final maxWidth = Responsive.getMaxContentWidth(context) * 0.85;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: EdgeInsets.all(spacing * 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select Time Control',
              style: GoogleFonts.inter(
                fontSize: bodySize + 4,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
            SizedBox(height: spacing * 2),
            Divider(
              height: 1,
              color: Theme.of(
                context,
              ).colorScheme.secondary.withValues(alpha: 0.2),
            ),
            SizedBox(height: spacing),
            ...timeControls.map((timeControl) {
              final isSelected = selected == timeControl;
              return RadioListTile<String>(
                title: Text(
                  timeControl,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: bodySize,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
                value: timeControl,
                groupValue: selected,
                onChanged: (value) {
                  if (value != null) {
                    onSelect(value);
                  }
                },
                activeColor: Theme.of(context).colorScheme.secondary,
                contentPadding: EdgeInsets.symmetric(horizontal: spacing),
              );
            }),
            SizedBox(height: spacing),
          ],
        ),
      ),
    );
  }
}

class _VariantDialog extends StatelessWidget {
  const _VariantDialog({
    required this.variants,
    required this.selected,
    required this.onSelect,
  });
  final List<String> variants;
  final String selected;
  final Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    final spacing = Responsive.getSpacing(context);
    final bodySize = ResponsiveFontSize.getBodySize(
      Responsive.getScreenWidth(context),
    );
    final screenHeight = Responsive.getScreenHeight(context);
    final maxWidth = Responsive.getMaxContentWidth(context) * 0.85;
    final maxHeight = screenHeight * 0.6;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        padding: EdgeInsets.all(spacing * 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select Variant',
              style: GoogleFonts.inter(
                fontSize: bodySize + 4,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
            SizedBox(height: spacing * 2),
            Divider(
              height: 1,
              color: Theme.of(
                context,
              ).colorScheme.secondary.withValues(alpha: 0.2),
            ),
            SizedBox(height: spacing),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: variants.length,
                itemBuilder: (context, index) {
                  final variant = variants[index];
                  final isSelected = selected == variant;
                  return ListTile(
                    title: Text(
                      variant,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: bodySize,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: isSelected
                            ? Theme.of(context).colorScheme.secondary
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(
                            Icons.check,
                            color: Theme.of(context).colorScheme.secondary,
                          )
                        : null,
                    onTap: () {
                      onSelect(variant);
                    },
                    selected: isSelected,
                    selectedTileColor: Theme.of(
                      context,
                    ).colorScheme.secondary.withValues(alpha: 0.1),
                  );
                },
              ),
            ),
            SizedBox(height: spacing),
          ],
        ),
      ),
    );
  }
}

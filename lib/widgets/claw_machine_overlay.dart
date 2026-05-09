import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/claw_machine_game.dart';

/// Result handed back when the overlay closes. The screen-side flow uses
/// this to credit any sphere reward and refund unspent coins (currently
/// always 0 — a single attempt).
class ClawResult {
  final bool won;
  final int spheresWon;
  final int coinsSpent;

  const ClawResult({
    required this.won,
    required this.spheresWon,
    required this.coinsSpent,
  });
}

/// Thin host: wraps a [ClawMachineGame] in a [GameWidget] backed by the
/// dim modal scrim, and shows the result splash once the game says the
/// attempt has resolved. All gameplay (claw motion, joystick, button,
/// sprite layering) lives inside the Flame game.
class ClawMachineOverlay extends StatefulWidget {
  final int coinsSpent;
  final ValueChanged<ClawResult> onClose;

  const ClawMachineOverlay({
    super.key,
    required this.coinsSpent,
    required this.onClose,
  });

  @override
  State<ClawMachineOverlay> createState() => _ClawMachineOverlayState();
}

class _ClawMachineOverlayState extends State<ClawMachineOverlay> {
  late final ClawMachineGame _game;
  bool _resultDialogShown = false;
  bool _won = false;
  int _spheresWon = 0;

  @override
  void initState() {
    super.initState();
    _game = ClawMachineGame(onResultReady: _onResultReady);
  }

  void _onResultReady({required bool won, required int spheresWon}) {
    _won = won;
    _spheresWon = spheresWon;
    if (_resultDialogShown) return;
    _resultDialogShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _ResultDialog(
          won: _won,
          onContinue: () {
            Navigator.of(ctx).pop();
            widget.onClose(ClawResult(
              won: _won,
              spheresWon: _spheresWon,
              coinsSpent: widget.coinsSpent,
            ));
          },
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.78),
      child: SafeArea(child: GameWidget(game: _game)),
    );
  }
}

class _ResultDialog extends StatelessWidget {
  final bool won;
  final VoidCallback onContinue;

  const _ResultDialog({required this.won, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFFFFE0AC),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFC2185B), width: 3),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              won ? 'You got a sphere!' : 'So close!',
              style: const TextStyle(
                fontFamily: 'Pixelify Sans',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFFC2185B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              won ? '+1 sphere' : 'Try the next one.',
              style: const TextStyle(
                fontFamily: 'Pixelify Sans',
                fontSize: 16,
                color: Color(0xFF3E2723),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF4081),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(
                  fontFamily: 'Pixelify Sans',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

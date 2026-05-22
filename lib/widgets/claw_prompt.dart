import 'package:flutter/material.dart';

class ClawPrompt extends StatelessWidget {
  final int coinCost;
  final int currentCoins;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const ClawPrompt({
    super.key,
    required this.coinCost,
    required this.currentCoins,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final canAfford = currentCoins >= coinCost;
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE0AC),
                  border: Border.all(color: const Color(0xFFC2185B), width: 3),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'A claw machine!',
                      style: TextStyle(
                        fontFamily: 'Pixelify Sans',
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFC2185B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Try a grab for $coinCost coin${coinCost == 1 ? '' : 's'}?',
                      style: const TextStyle(
                        fontFamily: 'Pixelify Sans',
                        fontSize: 16,
                        color: Color(0xFF3E2723),
                      ),
                    ),
                    if (!canAfford) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Not enough coins (you have $currentCoins).',
                        style: const TextStyle(
                          fontFamily: 'Pixelify Sans',
                          fontSize: 13,
                          color: Color(0xFFB00020),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _PromptButton(
                          label: 'Walk past',
                          onPressed: onDecline,
                          color: const Color(0xFFE0E0E0),
                          textColor: const Color(0xFF3E2723),
                        ),
                        _PromptButton(
                          label: canAfford ? 'Play!' : 'Need coins',
                          onPressed: canAfford ? onAccept : null,
                          color: canAfford
                              ? const Color(0xFFFF4081)
                              : const Color(0xFFBDBDBD),
                          textColor: Colors.white,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _PromptButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final Color textColor;

  const _PromptButton({
    required this.label,
    required this.onPressed,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: textColor,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Pixelify Sans',
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

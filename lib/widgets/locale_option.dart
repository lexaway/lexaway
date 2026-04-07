import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class LocaleOption extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  const LocaleOption({
    super.key,
    required this.label,
    this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        label,
        style: TextStyle(
          color: selected ? AppColors.textPrimary : AppColors.textSecondary,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: subtitle != null
          ? Text(subtitle!, style: const TextStyle(color: AppColors.textFaint))
          : null,
      trailing: selected
          ? const Icon(Icons.check, color: AppColors.success, size: 20)
          : null,
      onTap: onTap,
    );
  }
}

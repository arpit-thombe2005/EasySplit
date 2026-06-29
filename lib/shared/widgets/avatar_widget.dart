import 'package:flutter/material.dart';
import 'package:easy_split/core/constants/app_constants.dart';

/// Avatar widget rendered cleanly from built-in avatar ID or initials.
class AppAvatar extends StatelessWidget {
  final String? avatarId;
  final String name;
  final double radius;
  final bool showBorder;

  const AppAvatar({
    super.key,
    this.avatarId,
    required this.name,
    this.radius = 20,
    this.showBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final preset = _findPreset(avatarId);

    Widget avatar;
    if (preset != null) {
      final color = Color(int.parse('FF${preset['bgHex']}', radix: 16));
      final iconData = preset['icon'] as IconData;
      avatar = CircleAvatar(
        radius: radius,
        backgroundColor: color,
        child: Icon(
          iconData,
          size: radius * 1.1,
          color: Colors.white,
        ),
      );
    } else {
      avatar = _InitialsAvatar(
        initials: _initials(name),
        radius: radius,
        cs: cs,
      );
    }

    if (showBorder) {
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: cs.surface,
            width: 2,
          ),
        ),
        child: avatar,
      );
    }
    return avatar;
  }

  Map<String, dynamic>? _findPreset(String? id) {
    if (id == null || id.isEmpty) return null;
    return AppConstants.avatarPresets.firstWhere(
      (p) => p['id'] == id,
      orElse: () => AppConstants.avatarPresets.first,
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    if (name.isNotEmpty) return name[0].toUpperCase();
    return '?';
  }
}

class _InitialsAvatar extends StatelessWidget {
  final String initials;
  final double radius;
  final ColorScheme cs;

  const _InitialsAvatar({
    required this.initials,
    required this.radius,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: cs.primary,
      child: Text(
        initials,
        style: TextStyle(
          color: cs.onPrimary,
          fontSize: radius * 0.7,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Stacked avatars for showing group members.
class StackedAvatars extends StatelessWidget {
  final List<String> names;
  final List<String?> avatarIds;
  final int maxVisible;
  final double radius;

  const StackedAvatars({
    super.key,
    required this.names,
    required this.avatarIds,
    this.maxVisible = 4,
    this.radius = 16,
  });

  @override
  Widget build(BuildContext context) {
    final visible = names.take(maxVisible).toList();
    final overflow = names.length - maxVisible;

    return SizedBox(
      height: radius * 2,
      width: (visible.length * (radius * 1.4)) + (overflow > 0 ? radius * 1.6 : 0),
      child: Stack(
        children: [
          for (int i = 0; i < visible.length; i++)
            Positioned(
              left: i * radius * 1.4,
              child: AppAvatar(
                name: visible[i],
                avatarId: i < avatarIds.length ? avatarIds[i] : null,
                radius: radius,
                showBorder: true,
              ),
            ),
          if (overflow > 0)
            Positioned(
              left: visible.length * radius * 1.4,
              child: CircleAvatar(
                radius: radius,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Text(
                  '+$overflow',
                  style: TextStyle(
                    fontSize: radius * 0.6,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

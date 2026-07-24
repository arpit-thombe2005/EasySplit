import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_split/core/services/connectivity_service.dart';

/// Persistent top banner displayed when device is in Offline Mode.
class OfflineBanner extends ConsumerWidget {
  final Widget child;

  const OfflineBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOffline = ref.watch(isOfflineProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        if (isOffline)
          Material(
            elevation: 2,
            color: isDark ? const Color(0xFF7A4300) : const Color(0xFFFFF3E0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? Colors.amber[700]! : Colors.amber[300]!,
                    width: 1,
                  ),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.wifi_off_rounded,
                      size: 22,
                      color: isDark ? Colors.amber[300] : Colors.amber[900],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Offline Mode',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.amber[200] : Colors.amber[900],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Only expense addition is available. Changes will sync automatically when you're back online.",
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.2,
                              color: isDark ? Colors.amber[100] : Colors.amber[950],
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
        Expanded(child: child),
      ],
    );
  }
}

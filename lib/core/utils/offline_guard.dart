import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_split/core/services/connectivity_service.dart';

/// Helper utility to guard features that require internet connection.
class OfflineGuard {
  /// Checks if the device is online. If offline, shows a SnackBar with user feedback and returns false.
  static bool checkOnlineOrNotify(
    BuildContext context,
    WidgetRef ref, {
    String message = 'Internet connection required for this feature.',
  }) {
    final isOffline = ref.read(isOfflineProvider);
    if (isOffline) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.grey[850],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 3),
        ),
      );
      return false;
    }
    return true;
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:easy_split/features/auth/presentation/providers/auth_provider.dart';

class VersionCheckState {
  final bool needsUpdate;
  final String latestVersion;
  final String updateUrl;
  final bool hasError;

  const VersionCheckState({
    required this.needsUpdate,
    required this.latestVersion,
    required this.updateUrl,
    this.hasError = false,
  });

  const VersionCheckState.initial()
      : needsUpdate = false,
        latestVersion = '',
        updateUrl = '',
        hasError = false;
}

final versionCheckProvider = AsyncNotifierProvider<VersionCheckNotifier, VersionCheckState>(
  VersionCheckNotifier.new,
);

class VersionCheckNotifier extends AsyncNotifier<VersionCheckState> {
  @override
  Future<VersionCheckState> build() async {
    return _performCheck();
  }

  Future<void> retryCheck() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _performCheck());
  }

  Future<VersionCheckState> _performCheck() async {
    try {
      final api = ref.read(apiServiceProvider);
      
      // Fetch version config from backend
      final response = await api.get('config/version');
      final minVersion = response['minimumVersion'] as String? ?? '1.0.0';
      final latestVersion = response['latestVersion'] as String? ?? '1.0.0';
      final updateUrl = response['updateUrl'] as String? ?? 'https://easysplit-p6z9.onrender.com';

      // Get local version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final needsUpdate = _isVersionOlder(currentVersion, minVersion);

      return VersionCheckState(
        needsUpdate: needsUpdate,
        latestVersion: latestVersion,
        updateUrl: updateUrl,
      );
    } catch (e) {
      // If version check fails due to network/server, we do not block the user.
      // We gracefully allow them to proceed, but flag the error.
      return const VersionCheckState(
        needsUpdate: false,
        latestVersion: '1.0.0',
        updateUrl: 'https://easysplit-p6z9.onrender.com',
        hasError: true,
      );
    }
  }

  bool _isVersionOlder(String current, String minimum) {
    // Try to compare as pure integers (in case build numbers/codes are sent)
    final currentInt = int.tryParse(current);
    final minInt = int.tryParse(minimum);
    if (currentInt != null && minInt != null) {
      return currentInt < minInt;
    }

    // Split semver by dot and remove any + suffixes (e.g. 1.0.0+1 -> 1.0.0)
    final currentClean = current.split('+').first;
    final minClean = minimum.split('+').first;

    final currentParts = currentClean.split('.');
    final minParts = minClean.split('.');

    for (int i = 0; i < minParts.length; i++) {
      final minPart = int.tryParse(minParts[i]) ?? 0;
      final currentPart = i < currentParts.length ? (int.tryParse(currentParts[i]) ?? 0) : 0;

      if (currentPart < minPart) {
        return true; // Local is older
      }
      if (currentPart > minPart) {
        return false; // Local is newer
      }
    }

    // If version names are identical, check build number if present
    final currentBuild = _getBuildNumber(current);
    final minBuild = _getBuildNumber(minimum);
    if (currentBuild != null && minBuild != null) {
      return currentBuild < minBuild;
    }

    return false;
  }

  int? _getBuildNumber(String fullVersion) {
    final parts = fullVersion.split('+');
    if (parts.length > 1) {
      return int.tryParse(parts[1]);
    }
    return null;
  }
}

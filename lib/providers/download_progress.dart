import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ephemeral progress of one download slot, keyed by pack/lang id.
/// `null` = idle; `0.0..1.0` = downloading; [extracting] = archive unpacking
/// (rendered as an indeterminate spinner — consumers check `progress < 0`).
///
/// The pack, voice, and music progress families all share this notifier;
/// downloads drive it via [track] so the lifecycle (spinner before first
/// byte, reset on completion *and* on failure) is encoded in one place.
class DownloadProgress extends FamilyNotifier<double?, String> {
  /// Sentinel state: download finished, extraction in progress.
  static const extracting = -1.0;

  @override
  double? build(String arg) => null;

  /// Run [body], mirroring its progress into this slot: `0.0` immediately
  /// (so the spinner shows before the first byte arrives), live fractions
  /// while it reports progress, [extracting] once unpacking starts, and
  /// back to idle when it completes or throws.
  Future<void> track(
    Future<void> Function(
      void Function(double) onProgress,
      void Function() onExtracting,
    ) body,
  ) async {
    state = 0.0;
    try {
      await body((p) => state = p, () => state = extracting);
    } finally {
      state = null;
    }
  }
}

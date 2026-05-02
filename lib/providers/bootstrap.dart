import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive_ce.dart';

import '../data/world_state_repository.dart';

/// Pre-resolved in main(), overridden in ProviderScope.
final hiveBoxProvider = Provider<Box>((ref) {
  throw UnimplementedError('hiveBoxProvider must be overridden');
});

/// The persistence gateway for world state, keyed by target language so each
/// pack gets its own dino world. Other code should depend on this rather than
/// reaching into the Hive box directly.
///
/// `autoDispose` because each lang the user has ever loaded would otherwise
/// pin a `WorldStateRepository` in the family forever — call sites just
/// `ref.read` the repo into the game instance, so once that read returns
/// no listener keeps the family entry alive.
final worldStateRepositoryProvider =
    Provider.autoDispose.family<WorldStateRepository, String>((ref, lang) {
  return WorldStateRepository(ref.watch(hiveBoxProvider), lang);
});

/// Pre-resolved directory paths, overridden in ProviderScope.
final packsDirProvider = Provider<String>((ref) {
  throw UnimplementedError('packsDirProvider must be overridden');
});
final modelsDirProvider = Provider<String>((ref) {
  throw UnimplementedError('modelsDirProvider must be overridden');
});
final musicDirProvider = Provider<String>((ref) {
  throw UnimplementedError('musicDirProvider must be overridden');
});
final tmpDirProvider = Provider<String>((ref) {
  throw UnimplementedError('tmpDirProvider must be overridden');
});

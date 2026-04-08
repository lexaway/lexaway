import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lexaway/data/pack_manager.dart';
import 'package:lexaway/models/question.dart';
import 'package:lexaway/providers.dart';
import 'screenshot_data.dart';

class FakeActivePackNotifier extends ActivePackNotifier {
  bool _hasQuestions = false;

  @override
  Future<List<Question>> build() async =>
      _hasQuestions ? screenshotQuestions : [];

  @override
  String? get activePackId => _hasQuestions ? 'eng-fra' : null;

  @override
  String? get activeLang => _hasQuestions ? 'fra' : null;

  /// Activate the fake pack so the router sees questions + a language.
  void activate() {
    _hasQuestions = true;
    state = AsyncData(screenshotQuestions);
  }

  /// Put the provider into loading state so the router stays on /loading.
  void setLoading() {
    _hasQuestions = false;
    state = const AsyncLoading();
  }
}

class FakeLocalPacksNotifier extends LocalPacksNotifier {
  @override
  Future<Map<String, LocalPack>> build() async => screenshotLocalPacks;
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lexaway/data/pack_manager.dart';
import 'package:lexaway/models/question.dart';
import 'package:lexaway/providers.dart';
import 'screenshot_data.dart';

class FakeActivePackNotifier extends ActivePackNotifier {
  bool _hasQuestions = false;
  ScreenshotLocaleData? _data;

  void setLocaleData(ScreenshotLocaleData data) {
    _data = data;
  }

  @override
  Future<List<Question>> build() async =>
      _hasQuestions ? (_data?.questions ?? []) : [];

  @override
  String? get activePackId => _hasQuestions ? _data?.packId : null;

  @override
  String? get activeLang => _hasQuestions ? _data?.activeLang : null;

  /// Activate the fake pack so the router sees questions + a language.
  void activate() {
    _hasQuestions = true;
    state = AsyncData(_data?.questions ?? []);
  }

  /// Put the provider into loading state so the router stays on /loading.
  void setLoading() {
    _hasQuestions = false;
    state = const AsyncLoading();
  }
}

class FakeLocalPacksNotifier extends LocalPacksNotifier {
  Map<String, LocalPack> _packs = {};

  void setPacks(Map<String, LocalPack> packs) {
    _packs = packs;
    state = AsyncData(packs);
  }

  @override
  Future<Map<String, LocalPack>> build() async => _packs;
}

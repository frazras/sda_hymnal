import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../models/hymnal_pack.dart';
import 'language_pack_download.dart';
import 'language_pack_store.dart';

LanguagePackStore? _store;

/// Application support storage survives temporary-cache eviction. Initializing
/// this service never downloads a pack or changes bundled English content.
Future<LanguagePackStore> get languagePackStore async {
  final existing = _store;
  if (existing != null) return existing;
  final support = await getApplicationSupportDirectory();
  return _store ??= LanguagePackStore(
      Directory('${support.path}/language_text_packs'),
      download: downloadLanguagePack);
}

/// Preserve the bundled book order and replace only exact-edition text.
/// Missing/corrupt downloaded content retains that edition's bundled fallback.
Future<List<HymnalPack>> loadInstalledLanguagePacks(AssetBundle bundle,
    {LanguagePackStore? store}) async {
  final bundled = await loadHymnalPacks(bundle);
  LanguagePackStore installed;
  try {
    installed = store ?? await languagePackStore;
  } catch (_) {
    return bundled;
  }
  final result = <HymnalPack>[];
  for (final fallback in bundled) {
    final updated = await installed.load(fallback.edition.id);
    result
        .add(updated?.edition.id == fallback.edition.id ? updated! : fallback);
  }
  return List.unmodifiable(result);
}

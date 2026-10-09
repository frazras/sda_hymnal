import 'dart:io';
import 'dart:convert';
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

/// Trusted bundled metadata pins every remote object to a reviewed commit.
Future<List<LanguagePackDownload>> loadLanguagePackDownloads(
    AssetBundle bundle) async {
  final catalog =
      jsonDecode(await bundle.loadString('assets/hymnals/downloads.json'))
          as Map<String, dynamic>;
  final source = catalog['source'] as Map<String, dynamic>;
  final repository = source['repository'] as String;
  final revision = source['revision'] as String;
  if (catalog['schemaVersion'] != 1 ||
      !RegExp(r'^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$').hasMatch(repository) ||
      !RegExp(r'^[0-9a-f]{40}$').hasMatch(revision)) {
    throw const FormatException('Unpinned language download catalog');
  }
  final downloads = <LanguagePackDownload>[];
  final seen = <String>{};
  for (final value in catalog['books'] as List<dynamic>) {
    final descriptor =
        LanguagePackDownload.fromJson(value as Map<String, dynamic>);
    final expected = Uri.https('raw.githubusercontent.com',
        '/$repository/$revision/assets/hymnals/${descriptor.bookId}.json');
    if (!seen.add(descriptor.bookId) || descriptor.url != expected) {
      throw const FormatException('Invalid language download destination');
    }
    downloads.add(descriptor);
  }
  if (downloads.isEmpty) throw const FormatException('Empty download catalog');
  return List.unmodifiable(downloads);
}

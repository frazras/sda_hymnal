import 'package:sdahymnal/l10n/app_localizations.dart';

// Published release content is mapped by version and position, never by translated text.
List<String>? translatedReleaseFeatures(
        AppLocalizations text, String version) =>
    switch (version) {
      '4.5.0' => [
          text.release450Feature0,
          text.release450Feature1,
          text.release450Feature2,
          text.release450Feature3,
          text.release450Feature4,
          text.release450Feature5,
          text.release450Feature6,
          text.release450Feature7,
          text.release450Feature8,
          text.release450Feature9,
        ],
      '4.4.0' => [
          text.release440Feature0,
          text.release440Feature1,
          text.release440Feature2,
          text.release440Feature3,
          text.release440Feature4,
        ],
      '4.3.0' => [
          text.release430Feature0,
          text.release430Feature1,
          text.release430Feature2,
          text.release430Feature3,
          text.release430Feature4,
          text.release430Feature5,
        ],
      '4.2.0' => [
          text.release420Feature0,
          text.release420Feature1,
          text.release420Feature2,
          text.release420Feature3,
          text.release420Feature4,
          text.release420Feature5,
          text.release420Feature6,
          text.release420Feature7,
          text.release420Feature8,
        ],
      '4.1.1' => [
          text.release411Feature0,
          text.release411Feature1,
          text.release411Feature2,
        ],
      '4.1.0' => [
          text.release410Feature0,
          text.release410Feature1,
          text.release410Feature2,
        ],
      '4.0.1' => [
          text.release401Feature0,
        ],
      '4.0.0' => [
          text.release400Feature0,
          text.release400Feature1,
          text.release400Feature2,
        ],
      _ => null,
    };

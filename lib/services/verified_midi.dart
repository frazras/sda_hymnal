/// Explicit instrumental assets keyed by the displayed book and item.
/// Never infer a cross-language association from hymn number or title.
///
/// Spanish 2009 #303: NEW BRITAIN, F major, introduction plus three verses.
/// Generated from the reviewed English New #108 asset; see
/// docs/cross-language-tune-matching.md and tool/build_verified_tune.py.
String? hymnMidiAsset(String book, int number) {
  if (book == 'new' && number >= 1 && number <= 695) {
    return 'midi/${number.toString().padLeft(3, '0')}.mid';
  }
  if (book == 'old' && number >= 1 && number <= 703) {
    return 'midi/C${number.toString().padLeft(3, '0')}.mid';
  }
  if (book == 'sda-es-2009' && number == 303) {
    return 'midi/es-2009-303.mid';
  }
  return null;
}

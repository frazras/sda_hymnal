import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/models/additional_reading.dart';

part 'topical_index.g.dart';

/// Seed ordering from the public SDA Hymnal top-hymns page and the communion
/// selections reviewed for this app. Live community trends replace these
/// scores as soon as they are available.
const researchedPopularity = <String, int>{
  'new:524': 13043,
  'new:1': 11594,
  'new:100': 11090,
  'new:499': 8311,
  'new:12': 7877,
  'new:86': 6158,
  'new:309': 5910,
  'new:213': 5902,
  'new:388': 5735,
  'new:290': 5383,
  'new:409': 10013,
  'new:403': 10012,
  'new:397': 10010,
  'new:317': 10011,
  'new:302': 10010,
  'new:281': 10009,
  'new:294': 10008,
  'new:523': 10007,
  'new:330': 10006,
  'new:336': 10005,
  'new:312': 10004,
  'new:308': 10003,
  'new:318': 10002,
  'new:337': 10001,
  'new:190': 10020,
  'new:218': 10019,
  'new:580': 10018,
  'new:543': 10017,
  'new:468': 10016,
  'new:101': 10015,
  'new:626': 10014,
  'new:379': 10013,
};

/// Printed topical index merged additively with the existing curated occasions.
/// References are edition-specific; titles and lyrics come from the hymn catalog.
class HymnOccasion {
  final String id;
  final String title;
  final String description;
  final List<int> newNumbers;
  final List<int> oldNumbers;
  final List<int> newReadingNumbers;

  const HymnOccasion(
      {required this.id,
      required this.title,
      required this.description,
      required this.newNumbers,
      required this.oldNumbers,
      this.newReadingNumbers = const []});

  List<AdditionalReading> readingsFor(
      AdditionalReadingCatalog catalog, String version) {
    if (version != 'new') return const [];
    final byNumber = {
      for (final reading in catalog.readings)
        if (reading.edition == version) reading.number: reading
    };
    return [
      for (final number in newReadingNumbers)
        if (byNumber[number] != null) byNumber[number]!
    ];
  }

  List<Hymn> hymnsFor(List<Hymn> hymns, String version,
      {Map<String, int> popularity = const {}}) {
    final numbers = version == 'old' ? oldNumbers : newNumbers;
    final byNumber = {
      for (final hymn in hymns)
        if (hymn.version == version) hymn.number: hymn
    };
    final result = [
      for (final number in numbers)
        if (byNumber[number] != null) byNumber[number]!
    ];
    if (popularity.isEmpty) return result;
    final order = {for (var i = 0; i < result.length; i++) result[i].number: i};
    result.sort((a, b) {
      final score = (popularity['${a.version}:${a.number}'] ?? 0)
          .compareTo(popularity['${b.version}:${b.number}'] ?? 0);
      return score == 0 ? order[a.number]!.compareTo(order[b.number]!) : -score;
    });
    return result;
  }
}

const curatedHymnOccasions = <HymnOccasion>[
  HymnOccasion(
      id: "communion",
      title: "Communion",
      description: "Remembering Christ’s sacrifice and serving one another.",
      newNumbers: [
        409,
        403,
        317,
        302,
        281,
        294,
        523,
        330,
        336,
        312,
        308,
        318,
        337,
        397,
        398,
        399,
        400,
        401,
        402,
        405,
        406,
        408,
        410,
        396,
        404,
        407
      ],
      oldNumbers: [
        476,
        475,
        472,
        471,
        477,
        478,
        30,
        31,
        412,
        413
      ]),
  HymnOccasion(
      id: "funerals",
      title: "Funerals",
      description: "Comfort in grief and hope in the resurrection.",
      newNumbers: [
        50,
        99,
        101,
        102,
        103,
        104,
        181,
        206,
        428,
        432,
        440,
        441,
        442,
        443,
        444,
        445,
        499,
        530,
        545,
        547
      ],
      oldNumbers: [
        50,
        99,
        102,
        103,
        104,
        134,
        135,
        387,
        488,
        530,
        545,
        551,
        555,
        557,
        577
      ]),
  HymnOccasion(
      id: "morning",
      title: "Morning worship",
      description: "Begin the day with praise and dedication.",
      newNumbers: [39, 40, 41, 42, 43, 44, 45, 1, 3, 18, 31, 34, 35, 37, 38],
      oldNumbers: [39, 40, 41, 42, 43, 44, 45, 46, 47, 454, 621]),
  HymnOccasion(
      id: "evening",
      title: "Evening worship",
      description: "Close the day with gratitude, peace, and prayer.",
      newNumbers: [
        46,
        47,
        48,
        49,
        50,
        51,
        52,
        53,
        54,
        55,
        56,
        57,
        58,
        64,
        65
      ],
      oldNumbers: [
        28,
        32,
        33,
        34,
        35,
        37,
        39,
        48,
        49,
        50,
        51,
        52,
        53,
        54,
        55,
        56,
        57
      ]),
  HymnOccasion(
      id: "sabbath",
      title: "Sabbath",
      description: "Welcome the Sabbath and celebrate God’s gift of rest.",
      newNumbers: [
        380,
        381,
        382,
        383,
        384,
        385,
        388,
        389,
        390,
        391,
        392,
        393,
        394,
        40,
        59,
        60
      ],
      oldNumbers: [
        39,
        40,
        42,
        43,
        46,
        47,
        468,
        469,
        470,
        471,
        472,
        653,
        654
      ]),
  HymnOccasion(
      id: "opening",
      title: "Opening worship",
      description: "Gather the congregation in praise and reverence.",
      newNumbers: [
        1,
        3,
        4,
        6,
        8,
        10,
        12,
        15,
        20,
        27,
        29,
        30,
        59,
        60,
        61,
        62,
        63
      ],
      oldNumbers: [
        8,
        12,
        27,
        29,
        30,
        31,
        34,
        36,
        40,
        59
      ]),
  HymnOccasion(
      id: "closing",
      title: "Closing worship",
      description: "Go with God’s blessing and a renewed purpose.",
      newNumbers: [64, 65, 66, 67, 68, 69, 70, 71, 72, 407, 408, 411],
      oldNumbers: [32, 33, 34, 35, 36, 37, 38, 55, 64, 65, 66, 67, 68, 69]),
  HymnOccasion(
      id: "prayer",
      title: "Prayer meetings",
      description: "Draw near to God in trust and intercession.",
      newNumbers: [
        181,
        250,
        291,
        306,
        309,
        318,
        330,
        469,
        478,
        483,
        499,
        501,
        522,
        523,
        524,
        526,
        547,
        577
      ],
      oldNumbers: [
        252,
        258,
        268,
        291,
        316,
        320,
        324,
        474,
        483,
        499,
        501,
        532,
        573,
        578
      ]),
  HymnOccasion(
      id: "thanksgiving",
      title: "Thanksgiving",
      description: "Give thanks for God’s care and daily blessings.",
      newNumbers: [
        1,
        2,
        8,
        9,
        10,
        12,
        20,
        22,
        25,
        26,
        27,
        29,
        31,
        32,
        33,
        34,
        35,
        90,
        92,
        93,
        99,
        100,
        101,
        559,
        560,
        561,
        565
      ],
      oldNumbers: [
        8,
        12,
        15,
        16,
        20,
        22,
        23,
        25,
        90,
        91,
        92,
        93,
        99,
        100,
        101
      ]),
  HymnOccasion(
      id: "baptism",
      title: "Baptisms & dedication",
      description:
          "Celebrate new life in Christ and a commitment to follow Him.",
      newNumbers: [
        108,
        181,
        214,
        309,
        318,
        330,
        338,
        343,
        359,
        373,
        377,
        378,
        590
      ],
      oldNumbers: [
        121,
        134,
        135,
        252,
        273,
        295,
        309,
        412,
        418,
        474,
        573,
        635
      ]),
  HymnOccasion(
      id: "weddings",
      title: "Weddings & family",
      description: "Pray for love, unity, and God’s blessing on the home.",
      newNumbers: [
        396,
        400,
        401,
        402,
        405,
        406,
        407,
        650,
        651,
        652,
        653,
        654,
        655,
        656,
        657,
        658,
        659
      ],
      oldNumbers: [
        410,
        412,
        413,
        414,
        415,
        416,
        417,
        419,
        650,
        651
      ]),
  HymnOccasion(
      id: "children",
      title: "Children & youth",
      description:
          "Beloved songs for Sabbath School, children’s worship, and youth gatherings.",
      newNumbers: [
        190,
        218,
        580,
        543,
        468,
        101,
        626,
        379,
        146,
        133,
        135,
        141,
        151,
        153,
        181,
        188,
        189,
        191,
        192,
        193
      ],
      oldNumbers: [
        418,
        531,
        532,
        539,
        540,
        542,
        543,
        544,
        545,
        552,
        553,
        554,
        555,
        572,
        579,
        621,
        635
      ]),
  HymnOccasion(
      id: "christmas",
      title: "Christmas",
      description: "Celebrate the birth of Jesus.",
      newNumbers: [
        115,
        116,
        117,
        118,
        119,
        120,
        121,
        122,
        124,
        125,
        126,
        127,
        128,
        132,
        135,
        141,
        142,
        143
      ],
      oldNumbers: [
        102,
        103,
        104,
        105,
        106,
        107,
        108,
        109,
        110,
        111,
        112,
        113,
        114,
        115,
        116,
        117,
        118,
        119,
        120
      ]),
  HymnOccasion(
      id: "resurrection",
      title: "Resurrection",
      description: "Rejoice in Christ’s victory and the promise of life.",
      newNumbers: [
        154,
        155,
        156,
        157,
        158,
        159,
        163,
        165,
        166,
        167,
        169,
        171,
        172,
        173,
        175,
        176,
        526
      ],
      oldNumbers: [
        130,
        131,
        132,
        134,
        135,
        136,
        137,
        138,
        139,
        140,
        141,
        142
      ]),
  HymnOccasion(
      id: "missions",
      title: "Missions & service",
      description: "Answer the call to share the gospel and serve others.",
      newNumbers: [
        213,
        214,
        215,
        216,
        359,
        360,
        361,
        362,
        363,
        364,
        365,
        369,
        370,
        371,
        373,
        374,
        375,
        377,
        378
      ],
      oldNumbers: [
        354,
        356,
        359,
        360,
        361,
        362,
        363,
        364,
        365,
        366,
        367,
        368,
        440,
        447,
        454,
        543,
        576
      ]),
  HymnOccasion(
      id: "advent",
      title: "Second Coming",
      description: "Sing of Christ’s return and our eternal home.",
      newNumbers: [
        177,
        178,
        179,
        180,
        182,
        183,
        184,
        185,
        186,
        187,
        188,
        189,
        190,
        191,
        212,
        213,
        214,
        216,
        420,
        421,
        426,
        427,
        428,
        433,
        442
      ],
      oldNumbers: [
        131,
        132,
        135,
        136,
        137,
        138,
        139,
        140,
        141,
        142,
        182,
        306,
        420,
        421,
        426,
        427,
        428,
        433,
        536,
        540,
        541,
        545,
        546,
        547,
        548,
        549
      ]),
];

/// Stable occasion IDs and original memberships survive title changes.
final hymnOccasions = _mergeTopicalIndex();

List<HymnOccasion> _mergeTopicalIndex() {
  const matches = <String, List<String>>{
    'communion': ['Communion'],
    'funerals': [
      'Hope and Comfort',
      'Eternal Life',
      'Jesus Christ: Resurrection and Ascension'
    ],
    'morning': ['Morning Worship'],
    'evening': ['Evening Worship'],
    'sabbath': ['Sabbath'],
    'opening': ['Opening of Worship'],
    'closing': ['Close of Worship'],
    'prayer': ['Meditation and Prayer'],
    'thanksgiving': ['Thankfulness'],
    'baptism': ['Baptism'],
    'weddings': ['Marriage'],
    'children': ['Love in the Home'],
    'christmas': ['Jesus Christ: Birth', 'Jesus Christ: First Advent'],
    'resurrection': ['Jesus Christ: Resurrection and Ascension'],
    'missions': ['Mission of the Church'],
    'advent': ['Jesus Christ: Second Advent'],
  };
  const keepNames = {'funerals', 'children', 'christmas'};
  final index = {for (final topic in printedTopicalIndex) topic.title: topic};
  final mergedTitles = <String>{};
  final result = <HymnOccasion>[];
  for (final original in curatedHymnOccasions) {
    final topics = [
      for (final title in matches[original.id] ?? <String>[]) index[title]!
    ];
    final rename = !keepNames.contains(original.id) && topics.isNotEmpty;
    if (rename) mergedTitles.add(topics.first.title);
    result.add(HymnOccasion(
      id: original.id,
      title: rename ? topics.first.title : original.title,
      description: original.description,
      newNumbers: List.unmodifiable(
          {...original.newNumbers, ...topics.expand((t) => t.newNumbers)}),
      oldNumbers: List.unmodifiable(
          {...original.oldNumbers, ...topics.expand((t) => t.oldNumbers)}),
      newReadingNumbers: List.unmodifiable({
        ...original.newReadingNumbers,
        ...topics.expand((t) => t.newReadingNumbers)
      }),
    ));
  }
  result.addAll(
      printedTopicalIndex.where((t) => !mergedTitles.contains(t.title)));
  return List.unmodifiable(result);
}

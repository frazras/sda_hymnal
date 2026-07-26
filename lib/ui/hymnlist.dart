import 'package:sdahymnal/models/hymn.dart';
import 'package:flutter/material.dart';
import 'package:sdahymnal/ui/hymnPage.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/cupertino.dart';

class HymnList extends StatefulWidget {
  final List<Hymn> hymns;
  final List<Hymn> hymnsNew;
  final List<Hymn> hymnsOld;

  const HymnList(
      {super.key,
      required this.hymns,
      required this.hymnsOld,
      required this.hymnsNew});

  @override
  State<HymnList> createState() => _HymnListState();
}

class _HymnListState extends State<HymnList> {
  late List<Hymn> _filteredHymns;
  String filter = "ALL";
  String _query = "";

  @override
  void initState() {
    super.initState();
    _filteredHymns = widget.hymns;
  }

  @override
  void didUpdateWidget(HymnList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hymns != widget.hymns) {
      _applyFilter();
    }
  }

  List<Hymn> get _currentHymns => (filter == "OLD")
      ? widget.hymnsOld
      : (filter == "NEW")
          ? widget.hymnsNew
          : widget.hymns;

  void _applyFilter() {
    final query = _query;
    if (query.isEmpty) {
      _filteredHymns = _currentHymns;
      return;
    }
    _filteredHymns = _currentHymns
        .where((h) =>
            h.title.toLowerCase().contains(query.toLowerCase()) ||
            h.body
                .toLowerCase()
                .replaceAll(RegExp(r'[^\w\s]+'), '')
                .contains(query.toLowerCase()) ||
            h.number.toString().contains(query))
        .toList();
  }

  Widget _buildHymnItem(BuildContext context, int index) {
    Hymn hymn = _filteredHymns[index];

    return Container(
      child: Card(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              decoration: BoxDecoration(
                color: hymn.version == 'new' ? Colors.white : Colors.grey[300],
                border: Border.all(color: Colors.black, width: 2.0),
              ),
              padding: const EdgeInsets.all(0.0),
              child: ListTile(
                title: Text(
                  '${hymn.number}. ${hymn.title}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                    fontSize: 16.0,
                  ),
                ),
                leading: SvgPicture.asset(
                  hymn.version == 'new'
                      ? "assets/lettern.svg"
                      : "assets/lettero.svg",
                  semanticsLabel: 'Letter N/O',
                  width: 32,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 1.0, vertical: 0.0),
                dense: true, // Less Cramped Tile
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HymnPage(
                          hymn: _filteredHymns[index],
                          hymns: _filteredHymns[index].version == 'new'
                              ? widget.hymnsNew
                              : widget.hymnsOld),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getAppTitleWidget() {
    return CupertinoTextField(
      style: const TextStyle(color: Colors.white, fontSize: 20.0),
      // Dark background so the white input text stays visible (the 2020 app
      // got this from its global dark theme).
      decoration: BoxDecoration(
        color: const Color(0xdd222222),
        borderRadius: BorderRadius.circular(8.0),
      ),
      placeholder: "Search Hymns",
      placeholderStyle:
          const TextStyle(fontSize: 20.0, color: Color(0xff00FF00)),
      prefix: Container(
        padding: const EdgeInsets.only(left: 10.0),
        child: const Icon(
          Icons.search,
          color: Color(0xff00FF00),
          size: 40,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 10.0),
      onChanged: (query) {
        setState(() {
          _query = query;
          _applyFilter();
        });
      },
    );
  }

  Widget _buildBody() {
    return Container(
      margin: const EdgeInsets.fromLTRB(
          8.0, // A left margin of 8.0
          8.0, // A top margin of 8.0
          8.0, // A right margin of 8.0
          0.0 // A bottom margin of 0.0
          ),
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              Expanded(
                child: _getAppTitleWidget(),
              ),
              Container(
                width: 50.0,
                margin: const EdgeInsets.only(left: 5.0),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(4),
                  ),
                  onPressed: () {
                    setState(() {
                      switch (filter) {
                        case "ALL":
                          filter = "OLD";
                          break;
                        case "OLD":
                          filter = "NEW";
                          break;
                        case "NEW":
                          filter = "ALL";
                          break;
                      }
                      _applyFilter();
                    });
                  },
                  child: FittedBox(
                    fit: BoxFit.fitWidth,
                    child: Column(
                      children: <Widget>[
                        Text(filter, style: const TextStyle(fontSize: 16)),
                        const Text('Hymns', style: TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          _getListViewWidget()
        ],
      ),
    );
  }

  Future<void> refresh() {
    return Future<void>.value();
  }

  Widget _getListViewWidget() {
    return Flexible(
        child: RefreshIndicator(
            onRefresh: refresh,
            child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _filteredHymns.length,
                itemBuilder: _buildHymnItem)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
    );
  }
}

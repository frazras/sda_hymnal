import 'package:flutter/material.dart';
import 'package:sdahymnal/ui/tabs.dart';

void main() {
  runApp(const Hymnal());
}

class Hymnal extends StatelessWidget {
  const Hymnal({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return const Tabs();
  }
}

import 'package:flutter/material.dart';
import 'xpad.g.dart';

void main() {
  runApp(MaterialApp(
    title: 'XPad',
    theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.deepPurple)),
    home: HomePage(),
  ));
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
    );
  }
}

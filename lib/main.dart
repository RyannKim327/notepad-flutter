import 'package:flutter/material.dart';

import 'screens/home_page.dart';

void main() {
  runApp(const Notepad());
}

class Notepad extends StatelessWidget {
  const Notepad({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notepad',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber),
        scaffoldBackgroundColor: const Color(0xFFFFFBF2),
        useMaterial3: true,
      ),
      home: const NotepadHomepage(),
    );
  }
}

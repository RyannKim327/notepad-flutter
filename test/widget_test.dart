import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:notepad/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Finder noteTextField() {
    return find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'Type something...',
    );
  }

  testWidgets('creates a typed note', (WidgetTester tester) async {
    await tester.pumpWidget(const Notepad());
    await tester.pumpAndSettle();

    expect(find.text('My Notes'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('New Note'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('note-title')),
      'Shopping',
    );
    await tester.enterText(
      noteTextField().first,
      'Milk and eggs',
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Shopping'), findsOneWidget);
    expect(find.text('Milk and eggs'), findsOneWidget);
  });

  testWidgets('mixes typed text and a sketch in one note', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const Notepad());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('note-title')),
      'Ideas',
    );
    await tester.enterText(
      noteTextField().first,
      'Sketch below',
    );

    await tester.ensureVisible(find.text('Add sketch'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add sketch'));
    await tester.pumpAndSettle();

    final canvas = find.byKey(
      const ValueKey('drawing-canvas'),
    );
    expect(canvas, findsOneWidget);

    await tester.ensureVisible(canvas);
    await tester.pumpAndSettle();

    await tester.drag(canvas, const Offset(60, 40));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Ideas'), findsOneWidget);
    expect(find.text('Sketch below'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    final saved =
        jsonDecode(prefs.getString('notes')!) as List<dynamic>;
    final note = saved.first as Map<String, dynamic>;
    final blocks =
        jsonDecode(note['blocks'] as String) as List<dynamic>;
    final types = blocks
        .map(
          (block) => (block as Map<String, dynamic>)['type'],
        )
        .toList();

    expect(types, containsAll(<String>['text', 'drawing']));
  });
}

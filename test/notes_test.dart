import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aoj_sitekit/models/note.dart';
import 'package:aoj_sitekit/screens/notes/notes_page.dart';
import 'package:aoj_sitekit/services/notes_repository.dart';
import 'package:aoj_sitekit/services/notifications.dart';
import 'package:aoj_sitekit/utils/date_format.dart';

Note note({
  String id = 'n1',
  String title = 'Check rebar spacing',
  List<String> photos = const [],
  DateTime? reminderAt,
}) {
  final now = DateTime(2026, 10, 20, 9);
  return Note(
    id: id,
    title: title,
    project: 'Block 2',
    body: 'Level 3 slab, grid C-D',
    photos: photos,
    createdAt: now,
    updatedAt: now,
    reminderAt: reminderAt,
  );
}

void main() {
  late Directory root;
  final repo = NotesRepository.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    root = Directory.systemTemp.createTempSync('sitekit_notes_');
    await repo.init(root: root);
  });

  tearDown(() {
    // Windows can briefly hold a handle after the last write.
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // Left in the system temp folder; harmless.
    }
  });

  group('NotesRepository', () {
    test('saves and reloads notes', () async {
      await repo.save(note());
      await repo.init(root: root);
      expect(repo.notes.value.single.title, 'Check rebar spacing');
      expect(repo.notes.value.single.project, 'Block 2');
    });

    test('imports photos privately and deletes removed ones', () async {
      final source = File('${root.path}/camera.jpg')..writeAsBytesSync([1, 2]);
      final name = await repo.importPhoto(source.path);
      expect(repo.photoFile(name).existsSync(), isTrue);

      await repo.save(note(photos: [name]));
      await repo.save(note(photos: []));
      expect(repo.photoFile(name).existsSync(), isFalse);
    });

    test('deleting a note removes its photos', () async {
      final source = File('${root.path}/c.png')..writeAsBytesSync([1]);
      final name = await repo.importPhoto(source.path);
      final n = note(photos: [name]);
      await repo.save(n);
      await repo.delete(n);
      expect(repo.notes.value, isEmpty);
      expect(repo.photoFile(name).existsSync(), isFalse);
    });

    test('a corrupt file is set aside, not lost', () async {
      File('${root.path}/notes.json').writeAsStringSync('{not json');
      await repo.init(root: root);
      expect(repo.notes.value, isEmpty);
      expect(File('${root.path}/notes.corrupt.json').existsSync(), isTrue);
    });

    test('photo names that could escape the folder are dropped', () {
      final json = note().toJson()
        ..['photos'] = ['ok_1.jpg', '../../secret', r'..\x.jpg', '/etc/x'];
      expect(Note.fromJson(json).photos, ['ok_1.jpg']);
    });

    test('due reminders are logged once as in-app notifications', () async {
      await Notifications.load();
      final before = Notifications.items.value.length;
      await repo.save(
        note(reminderAt: DateTime.now().subtract(const Duration(minutes: 1))),
      );
      await repo.logDueReminders();
      await repo.logDueReminders();
      expect(Notifications.items.value.length, before + 1);
      expect(
        Notifications.items.value.first.title,
        'Reminder: Check rebar spacing',
      );
      expect(repo.notes.value.single.reminderLogged, isTrue);
    });

    test('notification ids are stable and positive', () {
      final id = note(id: 'abc').notificationId;
      expect(id, note(id: 'abc').notificationId);
      expect(id, greaterThanOrEqualTo(0));
      expect(id, isNot(note(id: 'abd').notificationId));
    });

    test('stored JSON round-trips', () {
      final n = note(reminderAt: DateTime(2026, 11, 1, 8));
      final back = Note.fromJson(
        jsonDecode(jsonEncode(n.toJson())) as Map<String, dynamic>,
      );
      expect(back.reminderAt, n.reminderAt);
      expect(back.body, n.body);
    });
  });

  test('date formatting', () {
    final now = DateTime(2026, 10, 20, 12);
    expect(formatDay(DateTime(2026, 10, 20, 8), now: now), 'Today');
    expect(formatDay(DateTime(2026, 10, 21), now: now), 'Tomorrow');
    expect(formatDay(DateTime(2026, 10, 25), now: now), 'Sun 25 Oct');
    expect(formatDay(DateTime(2027, 1, 4), now: now), 'Mon 4 Jan 2027');
    expect(
      formatDateTime(DateTime(2026, 10, 20, 7, 5), now: now),
      'Today, 07:05',
    );
  });

  testWidgets('creates a note from the notes page', (tester) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: NotesPage()));
    expect(find.text('No notes yet'), findsOneWidget);

    await tester.tap(find.text('New note'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Snag: cracked tile');
    await tester.enterText(find.byType(TextField).at(1), 'Block 2');
    await tester.tap(find.text('Save'));
    // Let the real file write finish.
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Snag: cracked tile'), findsOneWidget);
    expect(find.text('Block 2'), findsWidgets);
    expect(repo.notes.value.single.project, 'Block 2');
  });
}

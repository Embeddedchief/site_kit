import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/note.dart';
import '../../services/notes_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_format.dart';
import '../../widgets/common.dart';
import '../../widgets/fade_route.dart';
import 'note_editor_page.dart';

void openNote(BuildContext context, [Note? note]) =>
    Navigator.of(context).push(fadeRoute(NoteEditorPage(note: note)));

/// Site notes list with search and a project filter.
class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final _search = TextEditingController();
  String? _project;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Note> _filter(List<Note> notes) {
    final q = _search.text.trim().toLowerCase();
    return [
      for (final n in notes)
        if ((_project == null || n.project == _project) &&
            (q.isEmpty ||
                n.title.toLowerCase().contains(q) ||
                n.project.toLowerCase().contains(q) ||
                n.body.toLowerCase().contains(q)))
          n,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => openNote(context),
          backgroundColor: AppColors.red,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text('New note'),
        ),
        body: ValueListenableBuilder<List<Note>>(
          valueListenable: NotesRepository.instance.notes,
          builder: (context, notes, _) {
            final projects = {
              for (final n in notes)
                if (n.project.isNotEmpty) n.project,
            }.toList()..sort();
            if (_project != null && !projects.contains(_project)) {
              _project = null;
            }
            final visible = _filter(notes);

            return Column(
              children: [
                PageHeader(
                  title: 'Site Notes',
                  subtitle:
                      '${notes.length} note${notes.length == 1 ? '' : 's'}',
                ),
                if (notes.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Search notes',
                        prefixIcon: const Icon(Icons.search_rounded),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.red),
                        ),
                      ),
                    ),
                  ),
                  if (projects.isNotEmpty)
                    SizedBox(
                      height: 48,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                        children: [
                          _ProjectChip(
                            label: 'All',
                            selected: _project == null,
                            onTap: () => setState(() => _project = null),
                          ),
                          for (final p in projects)
                            _ProjectChip(
                              label: p,
                              selected: _project == p,
                              onTap: () => setState(() => _project = p),
                            ),
                        ],
                      ),
                    ),
                ],
                Expanded(
                  child: notes.isEmpty
                      ? const _EmptyState()
                      : visible.isEmpty
                      ? const Center(
                          child: Text(
                            'No notes match',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        )
                      : ListView.separated(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                          itemCount: visible.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) => _NoteCard(note: visible[i]),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProjectChip extends StatelessWidget {
  const _ProjectChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.ink,
        backgroundColor: Colors.white,
        side: BorderSide(color: selected ? AppColors.ink : AppColors.border),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: selected ? Colors.white : AppColors.ink,
        ),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note});

  final Note note;

  @override
  Widget build(BuildContext context) {
    final repo = NotesRepository.instance;
    final reminder = note.reminderAt;
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: () => openNote(context, note),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      note.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatDay(note.updatedAt),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.faint,
                    ),
                  ),
                ],
              ),
              if (note.project.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.folder_outlined,
                      size: 14,
                      color: AppColors.red,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        note.project,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (note.body.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  note.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.muted,
                  ),
                ),
              ],
              if (note.photos.isNotEmpty || reminder != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (final p in note.photos.take(3))
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            repo.photoFile(p),
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            cacheWidth: 120,
                            errorBuilder: (_, _, _) => Container(
                              width: 40,
                              height: 40,
                              color: AppColors.border,
                            ),
                          ),
                        ),
                      ),
                    if (note.photos.length > 3)
                      Text(
                        '+${note.photos.length - 3}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    const Spacer(),
                    if (reminder != null) _ReminderBadge(note: note),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ReminderBadge extends StatelessWidget {
  const _ReminderBadge({required this.note});

  final Note note;

  @override
  Widget build(BuildContext context) {
    final upcoming = note.hasUpcomingReminder;
    final color = upcoming ? AppColors.red : AppColors.faint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: upcoming ? AppColors.redTint : AppColors.bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            upcoming
                ? Icons.notifications_active_outlined
                : Icons.notifications_off_outlined,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            upcoming ? formatDateTime(note.reminderAt!) : 'Reminded',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconTile(Icons.sticky_note_2_outlined, size: 56),
            SizedBox(height: 14),
            Text(
              'No notes yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Record site observations with photos, tag them to a project, '
              'and set reminders for follow-ups.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

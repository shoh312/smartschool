import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/student.dart';
import '../providers/teacher_provider.dart';
import '../widgets/app_shell.dart';
import '../widgets/empty_state.dart';

class ClassRosterScreen extends StatefulWidget {
  const ClassRosterScreen({
    super.key,
    required this.classId,
    required this.className,
    this.subject = '',
  });

  final int classId;
  final String className;
  final String subject;

  @override
  State<ClassRosterScreen> createState() => _ClassRosterScreenState();
}

class _ClassRosterScreenState extends State<ClassRosterScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TeacherProvider>().loadRoster(widget.classId);
    });
  }

  Future<void> _openGradeDialog(Student student) async {
    final subjectController = TextEditingController(text: widget.subject);
    final commentController = TextEditingController();
    int value = 5;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${student.fullName} uchun baho'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: subjectController,
                decoration: const InputDecoration(labelText: 'Fan'),
              ),
              const SizedBox(height: 16),
              const Text('Baho'),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 2, label: Text('2')),
                  ButtonSegment(value: 3, label: Text('3')),
                  ButtonSegment(value: 4, label: Text('4')),
                  ButtonSegment(value: 5, label: Text('5')),
                ],
                selected: {value},
                onSelectionChanged: (selection) =>
                    setDialogState(() => value = selection.first),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commentController,
                decoration: const InputDecoration(labelText: 'Izoh (ixtiyoriy)'),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Bekor qilish'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Saqlash'),
            ),
          ],
        ),
      ),
    );

    if (result != true || !mounted) return;

    final success = await context.read<TeacherProvider>().submitGrade(
      studentId: student.id,
      classId: widget.classId,
      subject: subjectController.text.trim(),
      value: value,
      comment: commentController.text.trim().isEmpty
          ? null
          : commentController.text.trim(),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Baho saqlandi' : 'Xatolik: ${context.read<TeacherProvider>().error}',
        ),
      ),
    );
  }

  Future<void> _openHomeworkDialog() async {
    final subjectController = TextEditingController(text: widget.subject);
    final descriptionController = TextEditingController();
    DateTime? dueDate;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${widget.className} uchun uy vazifasi'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: subjectController,
                decoration: const InputDecoration(labelText: 'Fan'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Topshiriq'),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Text(
                  dueDate == null
                      ? 'Muddatni tanlash (ixtiyoriy)'
                      : '${dueDate!.year}-${dueDate!.month.toString().padLeft(2, '0')}-${dueDate!.day.toString().padLeft(2, '0')}',
                ),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setDialogState(() => dueDate = picked);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Bekor qilish'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Saqlash'),
            ),
          ],
        ),
      ),
    );

    if (result != true || !mounted) return;

    final success = await context.read<TeacherProvider>().submitHomework(
      classId: widget.classId,
      subject: subjectController.text.trim(),
      description: descriptionController.text.trim(),
      dueDate: dueDate,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Uy vazifasi saqlandi'
              : 'Xatolik: ${context.read<TeacherProvider>().error}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final teacherProvider = context.watch<TeacherProvider>();
    final roster = teacherProvider.roster;

    return AppShell(
      title: widget.className,
      actions: [
        IconButton(
          tooltip: 'Uy vazifasi qo\'shish',
          icon: const Icon(Icons.assignment_outlined),
          onPressed: _openHomeworkDialog,
        ),
      ],
      child: RefreshIndicator(
        onRefresh: () => context.read<TeacherProvider>().loadRoster(widget.classId),
        child: teacherProvider.isRosterLoading
            ? const Center(child: CircularProgressIndicator())
            : roster.isEmpty
            ? const EmptyState(
                icon: Icons.groups_outlined,
                title: 'Bu sinfda o\'quvchi topilmadi',
                message: 'Direktor o\'quvchilarni bu sinfga biriktirgach, bu yerda ko\'rinadi.',
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: roster.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final student = roster[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          student.firstName.isEmpty ? '?' : student.firstName[0],
                        ),
                      ),
                      title: Text(student.fullName),
                      trailing: FilledButton.tonalIcon(
                        onPressed: () => _openGradeDialog(student),
                        icon: const Icon(Icons.grade_outlined, size: 18),
                        label: const Text('Baho qo\'yish'),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

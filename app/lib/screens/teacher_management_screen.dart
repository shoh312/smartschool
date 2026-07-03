import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/school_class.dart';
import '../models/teacher.dart';
import '../providers/school_provider.dart';
import '../providers/teacher_admin_provider.dart';
import '../widgets/app_shell.dart';
import '../widgets/empty_state.dart';

class TeacherManagementScreen extends StatefulWidget {
  const TeacherManagementScreen({super.key, this.isIntegrated = false});

  final bool isIntegrated;

  @override
  State<TeacherManagementScreen> createState() => _TeacherManagementScreenState();
}

class _TeacherManagementScreenState extends State<TeacherManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TeacherAdminProvider>().loadTeachers();
      context.read<SchoolProvider>().loadSchoolData();
    });
  }

  Future<void> _openCreateTeacherDialog() async {
    final fullNameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yangi o\'qituvchi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: fullNameController,
              decoration: const InputDecoration(labelText: 'F.I.Sh.'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Parol'),
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
            child: const Text('Yaratish'),
          ),
        ],
      ),
    );

    if (result != true || !mounted) return;

    final success = await context.read<TeacherAdminProvider>().createTeacher(
      fullName: fullNameController.text.trim(),
      email: emailController.text.trim(),
      password: passwordController.text,
    );

    if (!mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Xatolik: ${context.read<TeacherAdminProvider>().error}',
          ),
        ),
      );
    }
  }

  Future<void> _openAssignClassDialog(Teacher teacher) async {
    final classes = context.read<SchoolProvider>().classes;
    SchoolClass? selectedClass = classes.isNotEmpty ? classes.first : null;
    final subjectController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${teacher.fullName} ga sinf biriktirish'),
          content: classes.isEmpty
              ? const Text('Avval sinf yarating.')
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<SchoolClass>(
                      value: selectedClass,
                      decoration: const InputDecoration(labelText: 'Sinf'),
                      items: classes
                          .map(
                            (schoolClass) => DropdownMenuItem(
                              value: schoolClass,
                              child: Text(schoolClass.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => selectedClass = value),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: subjectController,
                      decoration: const InputDecoration(labelText: 'Fan'),
                    ),
                  ],
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Bekor qilish'),
            ),
            FilledButton(
              onPressed: classes.isEmpty
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('Biriktirish'),
            ),
          ],
        ),
      ),
    );

    if (result != true || selectedClass == null || !mounted) return;

    final success = await context.read<TeacherAdminProvider>().assignClass(
      teacherId: teacher.id,
      classId: selectedClass!.id,
      subject: subjectController.text.trim(),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Sinf biriktirildi'
              : 'Xatolik: ${context.read<TeacherAdminProvider>().error}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TeacherAdminProvider>();

    return AppShell(
      title: 'O\'qituvchilar',
      showAppBar: !widget.isIntegrated,
      actions: [
        IconButton(
          tooltip: 'Yangi o\'qituvchi',
          icon: const Icon(Icons.person_add_alt_1_outlined),
          onPressed: _openCreateTeacherDialog,
        ),
      ],
      child: RefreshIndicator(
        onRefresh: () => context.read<TeacherAdminProvider>().loadTeachers(),
        child: provider.isLoading && provider.teachers.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : provider.teachers.isEmpty
            ? EmptyState(
                icon: Icons.school_outlined,
                title: 'Hali o\'qituvchi yo\'q',
                message: 'Yangi o\'qituvchi qo\'shish uchun yuqoridagi tugmani bosing.',
                onAction: _openCreateTeacherDialog,
                actionLabel: 'O\'qituvchi qo\'shish',
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: provider.teachers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final teacher = provider.teachers[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          teacher.fullName.isEmpty ? '?' : teacher.fullName[0],
                        ),
                      ),
                      title: Text(teacher.fullName),
                      subtitle: Text(teacher.email),
                      trailing: IconButton(
                        tooltip: 'Sinf biriktirish',
                        icon: const Icon(Icons.class_outlined),
                        onPressed: () => _openAssignClassDialog(teacher),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

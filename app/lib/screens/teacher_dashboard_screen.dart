import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/teacher_provider.dart';
import '../widgets/app_shell.dart';
import '../widgets/empty_state.dart';
import 'class_roster_screen.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TeacherProvider>().loadMyClasses();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TeacherProvider>();
    final theme = Theme.of(context);

    return AppShell(
      title: 'Mening sinflarim',
      child: RefreshIndicator(
        onRefresh: () => context.read<TeacherProvider>().loadMyClasses(),
        child: provider.isLoading && provider.myClasses.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : provider.myClasses.isEmpty
            ? EmptyState(
                icon: Icons.school_outlined,
                title: 'Sizga hali sinf biriktirilmagan',
                message: 'Direktor sizni biror sinfga biriktirgach, bu yerda ko\'rinadi.',
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: provider.myClasses.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final assignment = provider.myClasses[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                        child: Icon(Icons.class_outlined, color: theme.colorScheme.primary),
                      ),
                      title: Text(assignment.className ?? 'Sinf #${assignment.classId}'),
                      subtitle: Text(assignment.subject ?? '-'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ClassRosterScreen(
                            classId: assignment.classId,
                            className: assignment.className ?? 'Sinf #${assignment.classId}',
                            subject: assignment.subject ?? '',
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

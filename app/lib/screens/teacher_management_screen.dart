import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../core/constants.dart';
import '../core/design_tokens.dart';
import '../models/teacher.dart';
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
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _newTeacherSubject = AppConstants.schoolSubjects.first;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TeacherAdminProvider>().loadTeachers();
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _createTeacher() async {
    final l10n = AppLocalizations.of(context)!;
    final success = await context.read<TeacherAdminProvider>().createTeacher(
      fullName: _fullNameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      subject: _newTeacherSubject,
    );

    if (!mounted) return;
    if (success) {
      _fullNameController.clear();
      _emailController.clear();
      _passwordController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.errorPrefix(context.read<TeacherAdminProvider>().error ?? ''),
          ),
        ),
      );
    }
  }

  Future<void> _delete(Teacher teacher) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteTeacherTitle),
        content: Text(l10n.deleteTeacherConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete, style: const TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final success = await context.read<TeacherAdminProvider>().deleteTeacher(
      teacher.id,
    );

    if (!mounted || success) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.errorPrefix(context.read<TeacherAdminProvider>().error ?? ''),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TeacherAdminProvider>();
    final l10n = AppLocalizations.of(context)!;

    return AppShell(
      title: l10n.teachers,
      showAppBar: !widget.isIntegrated,
      child: RefreshIndicator(
        onRefresh: () => context.read<TeacherAdminProvider>().loadTeachers(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.addNewTeacher,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _fullNameController,
                      decoration: InputDecoration(labelText: l10n.fullName),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(labelText: l10n.email),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(labelText: l10n.password),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _newTeacherSubject,
                      decoration: InputDecoration(labelText: l10n.subjectLabel),
                      items: AppConstants.schoolSubjects
                          .map(
                            (subject) => DropdownMenuItem(
                              value: subject,
                              child: Text(subject),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(
                        () => _newTeacherSubject =
                            value ?? _newTeacherSubject,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: provider.isLoading ? null : _createTeacher,
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                      label: Text(l10n.create),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              l10n.existingTeachers,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (provider.isLoading && provider.teachers.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (provider.teachers.isEmpty)
              SizedBox(
                height: 200,
                child: EmptyState(
                  icon: Icons.school_outlined,
                  title: l10n.noTeachers,
                  message: l10n.noTeachersMessage,
                ),
              )
            else
              ...provider.teachers.map(
                (teacher) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.lgRadius,
                    border: Border.all(color: AppColors.border),
                    boxShadow: AppShadows.card,
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.lgRadius),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: AppGradients.primary,
                        borderRadius: AppRadius.mdRadius,
                        boxShadow: AppShadows.colored(AppColors.primary),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        teacher.fullName.isEmpty ? '?' : teacher.fullName[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                    ),
                    title: Text(teacher.fullName, style: Theme.of(context).textTheme.titleMedium),
                    subtitle: Text(
                      teacher.subject == null
                          ? teacher.email
                          : '${teacher.email} • ${teacher.subject}',
                    ),
                    trailing: IconButton(
                      tooltip: l10n.delete,
                      icon: const Icon(
                        Icons.delete_outline,
                        color: AppColors.danger,
                      ),
                      onPressed: () => _delete(teacher),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

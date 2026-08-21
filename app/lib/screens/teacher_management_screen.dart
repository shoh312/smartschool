import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../core/constants.dart';
import '../core/design_tokens.dart';
import '../models/teacher.dart';
import '../providers/teacher_admin_provider.dart';
import '../utils/error_formatter.dart';
import '../widgets/analytics/analytics_widgets.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/app_list_card.dart';
import '../widgets/app_loading_indicator.dart';
import '../widgets/app_shell.dart';
import '../widgets/bottom_nav_inset.dart';
import '../widgets/collapsible_form_card.dart';
import '../widgets/dashboard/dashboard_widgets.dart';
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
  bool _formOpen = false;

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
      // Fold the form away again so the list of teachers -- including the
      // one just added -- is what's on screen.
      setState(() => _formOpen = false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.errorPrefix(humanReadableError(context.read<TeacherAdminProvider>().error, l10n)),
          ),
        ),
      );
    }
  }

  Future<void> _delete(Teacher teacher) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showAppConfirmDialog(
      context,
      icon: Icons.delete_outline_rounded,
      title: l10n.deleteTeacherTitle,
      message: l10n.deleteTeacherConfirm,
      isDestructive: true,
    );

    if (!confirm || !mounted) return;

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
          padding: (const EdgeInsets.fromLTRB(16, 16, 16, 24)).add(bottomNavPadding(context)),
          children: [
            CollapsibleFormCard(
              title: l10n.addNewTeacher,
              expanded: _formOpen,
              onToggle: () => setState(() => _formOpen = !_formOpen),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
            const SizedBox(height: 26),
            DashboardSectionHeader(title: l10n.existingTeachers),
            if (provider.isLoading && provider.teachers.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: AppLoadingIndicator(),
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
              ...provider.teachers.asMap().entries.map((entry) {
                final index = entry.key;
                final teacher = entry.value;
                return FadeSlideIn(
                  delay: index < 12 ? Duration(milliseconds: 40 * index) : Duration.zero,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppListCard(
                      leading: AppListBadge(
                        text: teacher.fullName.isEmpty
                            ? '?'
                            : teacher.fullName[0].toUpperCase(),
                      ),
                      title: teacher.fullName,
                      subtitle: teacher.subject == null
                          ? teacher.email
                          : '${teacher.email} • ${teacher.subject}',
                      trailing: IconButton(
                        tooltip: l10n.delete,
                        icon: Icon(Icons.delete_outline, color: context.colors.danger),
                        onPressed: () => _delete(teacher),
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

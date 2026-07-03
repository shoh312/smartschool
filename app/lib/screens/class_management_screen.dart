import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../models/school_class.dart';
import '../providers/school_provider.dart';
import '../widgets/app_shell.dart';
import '../widgets/empty_state.dart';

class ClassManagementScreen extends StatefulWidget {
  const ClassManagementScreen({super.key, this.isIntegrated = false});

  final bool isIntegrated;

  @override
  State<ClassManagementScreen> createState() => _ClassManagementScreenState();
}

class _ClassManagementScreenState extends State<ClassManagementScreen> {
  final _nameController = TextEditingController();
  final _gradeController = TextEditingController();
  SchoolClass? _editingClass;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SchoolProvider>().loadSchoolData();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _gradeController.dispose();
    super.dispose();
  }

  void _prepareEdit(SchoolClass schoolClass) {
    setState(() {
      _editingClass = schoolClass;
      _nameController.text = schoolClass.name;
      _gradeController.text = schoolClass.grade.toString();
    });
  }

  void _clear() {
    setState(() {
      _editingClass = null;
      _nameController.clear();
      _gradeController.clear();
    });
  }

  Future<void> _save() async {
    final grade = int.tryParse(_gradeController.text.trim()) ??
        int.tryParse(
          _nameController.text.trim().replaceAll(RegExp(r'[^0-9]'), ''),
        ) ??
        0;

    final schoolClass = SchoolClass(
      id: _editingClass?.id ?? 0,
      name: _nameController.text.trim().toUpperCase(),
      grade: grade,
    );

    if (_editingClass == null) {
      await context.read<SchoolProvider>().createClass(schoolClass);
    } else {
      await context.read<SchoolProvider>().updateClass(schoolClass);
    }
    _clear();
  }

  Future<void> _delete(int id) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteClassTitle),
        content: Text(l10n.deleteClassConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await context.read<SchoolProvider>().deleteClass(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SchoolProvider>();
    final l10n = AppLocalizations.of(context)!;

    return AppShell(
      title: l10n.classManagement,
      showAppBar: !widget.isIntegrated,
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
                    _editingClass == null ? l10n.createNewClass : l10n.editClass,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: l10n.classNameLabel,
                      hintText: l10n.classNameHint,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _gradeController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.gradeOptional,
                      hintText: l10n.gradeHint,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (_editingClass != null)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _clear,
                            child: Text(l10n.cancel),
                          ),
                        ),
                      if (_editingClass != null) const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _save,
                          icon: Icon(_editingClass == null ? Icons.add : Icons.save),
                          label: Text(_editingClass == null ? l10n.createClass : l10n.saveChanges),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.existingClasses,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          if (provider.classes.isEmpty)
            SizedBox(
              height: 200,
              child: EmptyState(
                icon: Icons.class_outlined,
                title: l10n.noClasses,
                message: l10n.createClassesMessage,
              ),
            )
          else
            ...provider.classes.map(
              (schoolClass) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
                    child: Text(
                      schoolClass.grade.toString(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(schoolClass.name),
                  subtitle: Text(l10n.gradeLabel(schoolClass.grade.toString())),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: () => _prepareEdit(schoolClass),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                        onPressed: () => _delete(schoolClass.id),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

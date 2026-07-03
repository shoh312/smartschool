import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../models/school_class.dart';
import '../models/student.dart';
import '../providers/school_provider.dart';
import '../providers/student_provider.dart';
import '../widgets/app_shell.dart';
import '../widgets/empty_state.dart';
import '../widgets/student_tile.dart';

class StudentManagementScreen extends StatefulWidget {
  const StudentManagementScreen({super.key, this.isIntegrated = false});

  final bool isIntegrated;

  @override
  State<StudentManagementScreen> createState() =>
      _StudentManagementScreenState();
}

class _StudentManagementScreenState extends State<StudentManagementScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _parentPhoneController = TextEditingController();
  final _picker = ImagePicker();
  SchoolClass? _selectedClass;
  XFile? _selectedImage;
  Student? _editingStudent;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StudentProvider>().loadStudents();
      context.read<SchoolProvider>().loadSchoolData();
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _parentPhoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final image = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (image != null) {
      setState(() => _selectedImage = image);
    }
  }

  void _prepareEdit(Student student, List<SchoolClass> classes) {
    setState(() {
      _editingStudent = student;
      _firstNameController.text = student.firstName;
      _lastNameController.text = student.lastName;
      _parentPhoneController.text = student.parentPhone ?? '';
      _isActive = student.isActive;
      _selectedClass = classes.cast<SchoolClass?>().firstWhere(
            (c) => c?.id == student.classId,
            orElse: () => null,
          );
      _selectedImage = null;
    });
  }

  void _clear() {
    setState(() {
      _editingStudent = null;
      _firstNameController.clear();
      _lastNameController.clear();
      _parentPhoneController.clear();
      _selectedClass = null;
      _selectedImage = null;
      _isActive = true;
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    if (_selectedClass == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.selectClass)),
      );
      return;
    }

    final studentProvider = context.read<StudentProvider>();
    if (_editingStudent == null) {
      if (_selectedImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.studentPhotoRequired)),
        );
        return;
      }
      await studentProvider.createStudentWithFace(
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            classId: _selectedClass!.id,
            parentPhone: _parentPhoneController.text.trim(),
            imagePath: _selectedImage!.path,
          );
    } else {
      await studentProvider.updateStudent(
            id: _editingStudent!.id,
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            classId: _selectedClass!.id,
            parentPhone: _parentPhoneController.text.trim(),
            isActive: _isActive,
            imagePath: _selectedImage?.path,
          );
    }

    if (!mounted) return;
    if (studentProvider.error == null) {
      _clear();
    }
  }

  Future<void> _delete(int id) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteStudentTitle),
        content: Text(l10n.deleteStudentConfirm),
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
      await context.read<StudentProvider>().deleteStudent(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StudentProvider>();
    final school = context.watch<SchoolProvider>();
    final l10n = AppLocalizations.of(context)!;

    return AppShell(
      title: l10n.studentManagement,
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
                    _editingStudent == null ? l10n.addNewStudent : l10n.editStudent,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _firstNameController,
                          decoration: InputDecoration(labelText: l10n.firstName),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _lastNameController,
                          decoration: InputDecoration(labelText: l10n.lastName),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<SchoolClass>(
                    value: _selectedClass,
                    decoration: InputDecoration(labelText: l10n.classSingle),
                    items: school.classes
                        .map(
                          (schoolClass) => DropdownMenuItem(
                            value: schoolClass,
                            child: Text(schoolClass.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _selectedClass = value),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _parentPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: l10n.parentPhoneNumber,
                      prefixIcon: const Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_editingStudent != null)
                    SwitchListTile(
                      title: Text(l10n.isActive),
                      value: _isActive,
                      onChanged: (val) => setState(() => _isActive = val),
                    ),
                  const SizedBox(height: 12),
                  Card(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: ListTile(
                      leading: const Icon(Icons.face_retouching_natural),
                      title: Text(
                        _selectedImage == null
                            ? (_editingStudent == null ? l10n.studentFacePhoto : l10n.updatePhotoOptional)
                            : _selectedImage!.name,
                      ),
                      subtitle: Text(l10n.requiredForFaceRecognition),
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          IconButton(
                            tooltip: 'Camera',
                            icon: const Icon(Icons.photo_camera_outlined),
                            onPressed: () => _pickImage(ImageSource.camera),
                          ),
                          IconButton(
                            tooltip: 'Gallery',
                            icon: const Icon(Icons.photo_library_outlined),
                            onPressed: () => _pickImage(ImageSource.gallery),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (provider.error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      provider.error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (_editingStudent != null)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _clear,
                            child: Text(l10n.cancel),
                          ),
                        ),
                      if (_editingStudent != null) const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: provider.isLoading ? null : _save,
                          icon: provider.isLoading
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Icon(_editingStudent == null ? Icons.person_add_alt_1 : Icons.save),
                          label: Text(_editingStudent == null ? l10n.addStudent : l10n.saveChanges),
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
            l10n.studentsList,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          if (provider.students.isEmpty && !provider.isLoading)
            SizedBox(
              height: 200,
              child: EmptyState(
                icon: Icons.groups_outlined,
                title: l10n.noStudents,
                message: l10n.studentsAssignedWillAppear,
              ),
            )
          else
            ...provider.students.map(
              (student) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: StudentTile(
                  student: student,
                  onEdit: () => _prepareEdit(student, school.classes),
                  onDelete: () => _delete(student.id),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

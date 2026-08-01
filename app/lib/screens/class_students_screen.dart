import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../core/design_tokens.dart';
import '../models/school_class.dart';
import '../models/student.dart';
import '../providers/school_provider.dart';
import '../providers/student_provider.dart';
import '../utils/error_formatter.dart';
import '../widgets/app_shell.dart';
import '../widgets/empty_state.dart';
import '../widgets/student_tile.dart';

/// Roster + add/edit form for a single class -- entered from the class list
/// in StudentManagementScreen so a director works with one classroom's
/// students at a time instead of the whole school mixed together.
class ClassStudentsScreen extends StatefulWidget {
  const ClassStudentsScreen({
    super.key,
    required this.classId,
    required this.className,
  });

  final int classId;
  final String className;

  @override
  State<ClassStudentsScreen> createState() => _ClassStudentsScreenState();
}

class _ClassStudentsScreenState extends State<ClassStudentsScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _parentPhoneController = TextEditingController();
  final _picker = ImagePicker();
  SchoolClass? _selectedClass;
  bool _classInitialized = false;
  XFile? _selectedImage;
  Student? _editingStudent;
  bool _isActive = true;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _parentPhoneController.dispose();
    super.dispose();
  }

  // image_picker's Windows/Linux desktop backends have no built-in camera
  // capture -- ImageSource.camera throws a StateError there unless the app
  // wires up its own CameraDelegate, which this app doesn't. Hide the
  // camera option on those platforms rather than let the button silently
  // do nothing.
  bool get _cameraCaptureSupported =>
      kIsWeb ||
      (defaultTargetPlatform != TargetPlatform.windows &&
          defaultTargetPlatform != TargetPlatform.linux);

  Future<void> _pickImage(ImageSource source) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (image != null) {
        setState(() => _selectedImage = image);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.cameraNotAvailable)),
        );
      }
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

  void _clear(SchoolClass? defaultClass) {
    setState(() {
      _editingStudent = null;
      _firstNameController.clear();
      _lastNameController.clear();
      _parentPhoneController.clear();
      _selectedClass = defaultClass;
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
      _clear(_selectedClass);
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
            child: Text(l10n.delete, style: TextStyle(color: context.colors.danger)),
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

    if (!_classInitialized && school.classes.isNotEmpty) {
      _classInitialized = true;
      _selectedClass = school.classes.cast<SchoolClass?>().firstWhere(
            (c) => c?.id == widget.classId,
            orElse: () => null,
          );
    }

    final roster = provider.students
        .where((student) => student.classId == widget.classId)
        .toList()
      ..sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));

    return AppShell(
      title: widget.className,
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
                    style: Theme.of(context).textTheme.titleLarge,
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
                  Container(
                    decoration: BoxDecoration(
                      gradient: AppGradients.tint(context.colors.primary),
                      borderRadius: AppRadius.mdRadius,
                      border: Border.all(color: context.colors.primary.withOpacity(0.14)),
                    ),
                    child: ListTile(
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: context.colors.surface,
                          borderRadius: AppRadius.smRadius,
                        ),
                        child: Icon(Icons.face_retouching_natural, color: context.colors.primary),
                      ),
                      title: Text(
                        _selectedImage == null
                            ? (_editingStudent == null ? l10n.studentFacePhoto : l10n.updatePhotoOptional)
                            : _selectedImage!.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(l10n.requiredForFaceRecognition),
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          if (_cameraCaptureSupported)
                            IconButton(
                              tooltip: l10n.cameraOptionTooltip,
                              icon: Icon(Icons.photo_camera_outlined, color: context.colors.primary),
                              onPressed: () => _pickImage(ImageSource.camera),
                            ),
                          IconButton(
                            tooltip: l10n.galleryOptionTooltip,
                            icon: Icon(Icons.photo_library_outlined, color: context.colors.primary),
                            onPressed: () => _pickImage(ImageSource.gallery),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (provider.error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.colors.danger.withOpacity(0.06),
                        borderRadius: AppRadius.mdRadius,
                        border: Border.all(color: context.colors.danger.withOpacity(0.16)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline_rounded, color: context.colors.danger, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              humanReadableError(provider.error, l10n),
                              style: TextStyle(color: context.colors.danger, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (_editingStudent != null)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _clear(_selectedClass),
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
          const SizedBox(height: 28),
          Text(
            l10n.studentsList,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (roster.isEmpty && !provider.isLoading)
            SizedBox(
              height: 200,
              child: EmptyState(
                icon: Icons.groups_outlined,
                title: l10n.noStudents,
                message: l10n.studentsAssignedWillAppear,
              ),
            )
          else
            ...roster.map(
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

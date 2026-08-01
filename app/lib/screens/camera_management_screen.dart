import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../core/design_tokens.dart';
import '../models/camera_config.dart';
import '../models/school_class.dart';
import '../providers/school_provider.dart';
import '../widgets/app_shell.dart';
import '../widgets/empty_state.dart';

class CameraManagementScreen extends StatefulWidget {
  const CameraManagementScreen({super.key, this.isIntegrated = false});

  final bool isIntegrated;

  @override
  State<CameraManagementScreen> createState() => _CameraManagementScreenState();
}

class _CameraManagementScreenState extends State<CameraManagementScreen> {
  final _nameController = TextEditingController();
  final _rtspController = TextEditingController();
  SchoolClass? _selectedClass;
  CameraConfig? _editingCamera;

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
    _rtspController.dispose();
    super.dispose();
  }

  void _prepareEdit(CameraConfig camera, List<SchoolClass> classes) {
    setState(() {
      _editingCamera = camera;
      _nameController.text = camera.name;
      _rtspController.text = camera.rtspUrl ?? '';
      _selectedClass = classes.cast<SchoolClass?>().firstWhere(
            (c) => c?.id == camera.classId,
            orElse: () => null,
          );
    });
  }

  void _clear() {
    setState(() {
      _editingCamera = null;
      _nameController.clear();
      _rtspController.clear();
      _selectedClass = null;
    });
  }

  Future<void> _save() async {
    final camera = CameraConfig(
      id: _editingCamera?.id ?? 0,
      name: _nameController.text.trim(),
      classId: _selectedClass?.id,
      rtspUrl: _rtspController.text.trim(),
      isActive: _editingCamera?.isActive ?? true,
    );

    if (_editingCamera == null) {
      await context.read<SchoolProvider>().createCamera(camera);
    } else {
      await context.read<SchoolProvider>().updateCamera(camera);
    }
    _clear();
  }

  Future<void> _delete(int id) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteCameraTitle),
        content: Text(l10n.deleteCameraConfirm),
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
      await context.read<SchoolProvider>().deleteCamera(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SchoolProvider>();
    final l10n = AppLocalizations.of(context)!;

    return AppShell(
      title: l10n.cameraManagement,
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
                    _editingCamera == null ? l10n.addNewCamera : l10n.editCamera,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(labelText: l10n.cameraNameLabel),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<SchoolClass>(
                    value: _selectedClass,
                    decoration: InputDecoration(labelText: l10n.assignToClass),
                    items: provider.classes
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(c.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _selectedClass = value),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _rtspController,
                    decoration: InputDecoration(labelText: l10n.rtspUrl),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (_editingCamera != null)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _clear,
                            child: Text(l10n.cancel),
                          ),
                        ),
                      if (_editingCamera != null) const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _save,
                          icon: Icon(_editingCamera == null ? Icons.add : Icons.save),
                          label: Text(_editingCamera == null ? l10n.addCamera : l10n.saveChanges),
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
            l10n.registeredCameras,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (provider.cameras.isEmpty)
            SizedBox(
              height: 200,
              child: EmptyState(
                icon: Icons.videocam_outlined,
                title: l10n.noCameras,
                message: l10n.classroomCamerasWillAppear,
              ),
            )
          else
            ...provider.cameras.map(
              (camera) {
                final className = provider.classes
                    .cast<SchoolClass?>()
                    .firstWhere((c) => c?.id == camera.classId, orElse: () => null)
                    ?.name;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: AppRadius.lgRadius,
                    border: Border.all(color: context.colors.border),
                    boxShadow: AppShadows.card,
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.lgRadius),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: camera.isActive
                            ? AppGradients.success
                            : null,
                        color: camera.isActive ? null : context.colors.surfaceAlt,
                        borderRadius: AppRadius.mdRadius,
                        boxShadow: camera.isActive ? AppShadows.colored(context.colors.success) : null,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.videocam_outlined,
                        color: camera.isActive ? Colors.white : context.colors.textMuted,
                      ),
                    ),
                    title: Text(camera.name, style: Theme.of(context).textTheme.titleMedium),
                    subtitle: Text(className ?? l10n.unassigned),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit_outlined, size: 20, color: context.colors.textMuted),
                          onPressed: () => _prepareEdit(camera, provider.classes),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, size: 20, color: context.colors.danger),
                          onPressed: () => _delete(camera.id),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

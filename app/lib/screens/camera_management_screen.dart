import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../core/design_tokens.dart';
import '../models/camera_config.dart';
import '../models/school_class.dart';
import '../providers/school_provider.dart';
import '../services/school_service.dart';
import 'camera_groups_screen.dart';
import '../widgets/analytics/analytics_widgets.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/app_list_card.dart';
import '../widgets/app_shell.dart';
import '../widgets/bottom_nav_inset.dart';
import '../widgets/collapsible_form_card.dart';
import '../widgets/dashboard/dashboard_widgets.dart';
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
  bool _formOpen = false;

  /// Whether this school runs several groups through one room. Off by
  /// default, which is every ordinary school: one class, one room, and
  /// nothing to schedule.
  bool _groupMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SchoolProvider>().loadSchoolData();
      _loadGroupMode();
    });
  }

  Future<void> _loadGroupMode() async {
    try {
      final settings = await context.read<SchoolService>().fetchSettings();
      if (mounted) setState(() => _groupMode = settings.groupMode);
    } catch (_) {
      // Left off: the camera list is the point of this screen and it
      // works without knowing.
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rtspController.dispose();
    super.dispose();
  }

  void _prepareEdit(CameraConfig camera, List<SchoolClass> classes) {
    setState(() {
      // Editing has to open the form itself -- the user tapped a pencil on a
      // row, not the "+" header.
      _formOpen = true;
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
      _formOpen = false;
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
    final confirm = await showAppConfirmDialog(
      context,
      icon: Icons.delete_outline_rounded,
      title: l10n.deleteCameraTitle,
      message: l10n.deleteCameraConfirm,
      isDestructive: true,
    );

    if (confirm && mounted) {
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
        padding: (const EdgeInsets.fromLTRB(16, 16, 16, 24)).add(bottomNavPadding(context)),
        children: [
          CollapsibleFormCard(
            title: _editingCamera == null ? l10n.addNewCamera : l10n.editCamera,
            expanded: _formOpen,
            onToggle: () {
              if (_formOpen) {
                _clear();
              } else {
                setState(() => _formOpen = true);
              }
            },
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
          const SizedBox(height: 26),
          DashboardSectionHeader(title: l10n.registeredCameras),
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
            ...provider.cameras.asMap().entries.map(
              (entry) {
                final index = entry.key;
                final camera = entry.value;
                final className = provider.classes
                    .cast<SchoolClass?>()
                    .firstWhere((c) => c?.id == camera.classId, orElse: () => null)
                    ?.name;

                return FadeSlideIn(
                  delay: index < 12 ? Duration(milliseconds: 40 * index) : Duration.zero,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppListCard(
                      leading: AppListBadge(
                        icon: Icons.videocam_outlined,
                        // An inactive camera reads as muted rather than
                        // green, so a glance down the list shows which
                        // rooms are actually being watched.
                        color: camera.isActive
                            ? context.colors.success
                            : context.colors.textMuted,
                      ),
                      title: camera.name,
                      subtitle: className ?? l10n.unassigned,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Only in group mode: with one class per
                          // room there is no schedule to keep, and a
                          // button leading to an empty screen is
                          // worse than no button.
                          if (_groupMode)
                            IconButton(
                              tooltip: l10n.cameraGroups,
                              icon: Icon(Icons.schedule_outlined, size: 20, color: context.colors.primary),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CameraGroupsScreen(camera: camera),
                                ),
                              ),
                            ),
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
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../models/notification_event.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../utils/date_formatters.dart';
import '../widgets/app_shell.dart';
import '../widgets/empty_state.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key, this.isIntegrated = false});

  final bool isIntegrated;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final notificationProvider = context.watch<NotificationProvider>();
    final parentId = auth.parentId;
    final l10n = AppLocalizations.of(context)!;

    return AppShell(
      title: l10n.notifications,
      showAppBar: !isIntegrated,
      child: parentId == null
          ? EmptyState(
              icon: Icons.notifications_outlined,
              title: l10n.directorNotifications,
              message: l10n.schoolWideNotificationView,
            )
          : notificationProvider.isLoading && notificationProvider.notifications.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () => notificationProvider.loadNotifications(parentId),
                  child: notificationProvider.notifications.isEmpty
                      ? EmptyState(
                          icon: Icons.notifications_outlined,
                          title: l10n.noNotifications,
                          message: l10n.attendanceAlertsWillAppear,
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: notificationProvider.notifications.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = notificationProvider.notifications[index];
                            return Card(
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.notifications_active_outlined,
                                    color: Theme.of(context).colorScheme.primary,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  item.title,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(item.body),
                                trailing: Text(
                                  item.createdAt != null
                                      ? DateFormatters.time(item.createdAt!)
                                      : '',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}


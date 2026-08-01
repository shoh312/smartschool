import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../core/design_tokens.dart';
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
              imageAsset: 'assets/icons/not_notifications.png',
              title: l10n.directorNotifications,
              message: l10n.schoolWideNotificationView,
            )
          : notificationProvider.isLoading && notificationProvider.notifications.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () => notificationProvider.loadNotifications(parentId),
                  child: notificationProvider.notifications.isEmpty
                      ? EmptyState(
                          imageAsset: 'assets/icons/not_notifications.png',
                          title: l10n.noNotifications,
                          message: l10n.attendanceAlertsWillAppear,
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: notificationProvider.notifications.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = notificationProvider.notifications[index];
                            return Container(
                              decoration: BoxDecoration(
                                color: context.colors.surface,
                                borderRadius: AppRadius.lgRadius,
                                border: Border.all(color: context.colors.border),
                                boxShadow: AppShadows.card,
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                leading: Image.asset(
                                  'assets/icons/alerts.png',
                                  width: 44,
                                  height: 44,
                                ),
                                title: Text(
                                  item.title,
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text(
                                    item.body,
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                                trailing: Text(
                                  item.createdAt != null
                                      ? DateFormatters.time(item.createdAt!)
                                      : '',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: context.colors.textMuted,
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


import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../core/design_tokens.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../utils/date_formatters.dart';
import '../widgets/analytics/analytics_widgets.dart';
import '../widgets/app_list_card.dart';
import '../widgets/app_loading_indicator.dart';
import '../widgets/app_shell.dart';
import '../widgets/bottom_nav_inset.dart';
import '../widgets/dashboard/dashboard_widgets.dart';
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
              icon: Icons.notifications_none_rounded,
              title: l10n.directorNotifications,
              message: l10n.schoolWideNotificationView,
            )
          : notificationProvider.isLoading && notificationProvider.notifications.isEmpty
              ? const AppLoadingIndicator()
              : RefreshIndicator(
                  onRefresh: () => notificationProvider.loadNotifications(parentId),
                  child: notificationProvider.notifications.isEmpty
                      ? EmptyState(
                          icon: Icons.notifications_none_rounded,
                          title: l10n.noNotifications,
                          message: l10n.attendanceAlertsWillAppear,
                        )
                      : ListView(
                          padding: (const EdgeInsets.fromLTRB(16, 8, 16, 24)).add(bottomNavPadding(context)),
                          children: [
                            DashboardSectionHeader(title: l10n.notifications),
                            for (var i = 0; i < notificationProvider.notifications.length; i++)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: FadeSlideIn(
                                  delay: i < 12 ? Duration(milliseconds: 40 * i) : Duration.zero,
                                  child: AppListCard(
                                    leading: const AppListBadge(
                                      icon: Icons.notifications_active_outlined,
                                    ),
                                    title: notificationProvider.notifications[i].title,
                                    subtitle: notificationProvider.notifications[i].body,
                                    subtitleMaxLines: 2,
                                    showChevron: false,
                                    trailing: Text(
                                      notificationProvider.notifications[i].createdAt != null
                                          ? DateFormatters.time(
                                              notificationProvider.notifications[i].createdAt!)
                                          : '',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: context.colors.textMuted,
                                      ),
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


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../widgets/grade_detail_sheet.dart';

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
                                    // Two lines is right for a list and wrong
                                    // for the one message that matters most:
                                    // a pupil's login and password sit on
                                    // lines three and four, where nobody
                                    // could read them.
                                    onTap: () => _showFull(
                                      context,
                                      notificationProvider.notifications[i].title,
                                      notificationProvider.notifications[i].body,
                                    ),
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


/// The whole message, plus a way to get the password out of it.
///
/// Copying matters more than it looks: the alternative is a parent reading
/// eight random characters off one screen while typing them into another.
void _showFull(BuildContext context, String title, String body) {
  showDetailBottomSheet(
    context,
    contentBuilder: (context) {
      final l10n = AppLocalizations.of(context)!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          SelectableText(
            body,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.5,
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: body));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.copiedToClipboard)),
                );
              }
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: Text(l10n.copyAction),
          ),
        ],
      );
    },
  );
}

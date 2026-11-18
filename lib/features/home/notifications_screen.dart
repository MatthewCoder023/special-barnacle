import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/overlays.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final List<AppNotification> _items;
  late final Set<AppNotification> _unread;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _items = state.myNotifications;
    _unread = _items.where((n) => !n.read).toSet();
    // Opening the list marks everything as read.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => state.markNotificationsRead());
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Notifications',
      children: [
        if (_items.isEmpty)
          const EmptyState(
            icon: 'notifications',
            title: 'Nothing new',
            message: 'Announcements, approvals and event updates appear here.',
          ),
        for (final (i, n) in _items.indexed)
          FadeIn(
            index: i,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                color: _unread.contains(n) ? AppColors.skyMist : AppColors.white,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: AppIcon('notifications',
                          size: 18,
                          color: _unread.contains(n)
                              ? AppColors.pinkDeep
                              : AppColors.inkFaint),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(n.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall),
                              ),
                              if (_unread.contains(n))
                                const Tag('New', tone: Tone.pink),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(n.body),
                          const SizedBox(height: 4),
                          Text(timeAgo(n.at),
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

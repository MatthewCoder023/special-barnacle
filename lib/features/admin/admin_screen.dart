import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/overlays.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../shared/shared_widgets.dart';

/// M5: platform administrator console. Approves communities and providers,
/// verifies owners, makes final moderation decisions, and shows the
/// reference data and the audit log.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int _tab = 0;

  static const _tabs = [
    'Approvals',
    'Verification',
    'Moderation',
    'Reference data',
    'Audit log',
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final approvals =
        state.pendingCommunities.length + state.pendingProviders.length;
    return TabPage(
      title: 'Admin',
      subtitle: 'Platform administration',
      children: [
        Row(
          children: [
            Expanded(
              child: StatTile(
                icon: 'check',
                value: '$approvals',
                label: 'Approvals',
                onTap: () => setState(() => _tab = 0),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatTile(
                icon: 'verified',
                value: '${state.pendingVerifications.length}',
                label: 'Verifications',
                pink: true,
                onTap: () => setState(() => _tab = 1),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatTile(
                icon: 'flag',
                value: '${state.reportsForAdmin.length}',
                label: 'Reports',
                onTap: () => setState(() => _tab = 2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        PillRow(
          padding: EdgeInsets.zero,
          labels: _tabs,
          index: _tab,
          onChanged: (i) => setState(() => _tab = i),
        ),
        const SizedBox(height: 16),
        Swap(
          id: _tab,
          child: switch (_tab) {
            0 => const _Approvals(),
            1 => const _Verifications(),
            2 => const _Moderation(),
            3 => const _Reference(),
            _ => const _Audit(),
          },
        ),
      ],
    );
  }
}

/// Approve and decline buttons shared by the admin queues.
class _Decision extends StatelessWidget {
  const _Decision({
    required this.onApprove,
    required this.onDecline,
    this.approveLabel = 'Approve',
    this.declineLabel = 'Decline',
  });

  final VoidCallback onApprove;
  final VoidCallback onDecline;
  final String approveLabel;
  final String declineLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Expanded(
            child: AppButton(
              label: declineLabel,
              kind: AppButtonKind.soft,
              small: true,
              onTap: onDecline,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AppButton(label: approveLabel, small: true, onTap: onApprove),
          ),
        ],
      ),
    );
  }
}

class _Approvals extends StatelessWidget {
  const _Approvals();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final communities = state.pendingCommunities;
    final providers = state.pendingProviders;
    final text = Theme.of(context).textTheme;
    if (communities.isEmpty && providers.isEmpty) {
      return const EmptyState(
        icon: 'check',
        title: 'Nothing waiting for approval',
        message: 'New communities and provider listings appear here.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (communities.isNotEmpty) ...[
          Text('New communities', style: text.titleMedium),
          const SizedBox(height: 10),
        ],
        for (final c in communities)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.name, style: text.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    '${c.type.label} · created by ${state.userName(c.members.keys.first)} · ${timeAgo(c.createdAt)}',
                    style: text.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(c.description,
                      style: const TextStyle(color: AppColors.inkSoft)),
                  const SizedBox(height: 8),
                  const NoticeBox(
                    'Check that the name does not impersonate an existing club before approving.',
                    icon: 'shield',
                  ),
                  _Decision(
                    onApprove: () {
                      state.decideCommunity(c, approve: true);
                      showToast(context, '${c.name} approved.');
                    },
                    onDecline: () {
                      state.decideCommunity(c, approve: false);
                      showToast(context, '${c.name} declined.',
                          success: false);
                    },
                  ),
                ],
              ),
            ),
          ),
        if (providers.isNotEmpty) ...[
          Text('Provider listings', style: text.titleMedium),
          const SizedBox(height: 10),
        ],
        for (final p in providers)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, style: text.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    '${p.category.label} · ${p.address} · listed by ${state.userName(p.ownerId)}',
                    style: text.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Text('Services: ${p.services.join(', ')}',
                      style: const TextStyle(color: AppColors.inkSoft)),
                  _Decision(
                    approveLabel: 'Verify',
                    onApprove: () {
                      state.decideProvider(p, approve: true);
                      showToast(context, '${p.name} verified.');
                    },
                    onDecline: () {
                      state.decideProvider(p, approve: false);
                      showToast(context, '${p.name} declined.',
                          success: false);
                    },
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Verifications extends StatelessWidget {
  const _Verifications();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final list = state.pendingVerifications;
    if (list.isEmpty) {
      return const EmptyState(
        icon: 'verified',
        title: 'No owner verifications waiting',
      );
    }
    return Column(
      children: [
        const NoticeBox(
          'Owners submit minimal proof of ownership. The document is deleted once you decide.',
          icon: 'lock',
        ),
        const SizedBox(height: 12),
        for (final u in list)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Avatar(u.initials, imageUrl: u.avatarUrl, imageBytes: u.avatarBytes),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(u.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            Text(
                              '${u.vehicle?.name ?? 'No vehicle'} · ${u.region}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const InfoRow('document',
                      'Proof of ownership submitted (held in private storage)'),
                  _Decision(
                    approveLabel: 'Verify owner',
                    onApprove: () {
                      state.decideVerification(u, approve: true);
                      showToast(context, '${u.name} verified.');
                    },
                    onDecline: () {
                      state.decideVerification(u, approve: false);
                      showToast(context, 'Verification declined.',
                          success: false);
                    },
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Moderation extends StatelessWidget {
  const _Moderation();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final list = state.reportsForAdmin;
    final decided = state.reports
        .where((r) =>
            r.status == ReportStatus.removed ||
            r.status == ReportStatus.dismissed)
        .toList();
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (list.isEmpty)
          const EmptyState(
            icon: 'flag',
            title: 'Moderation queue is clear',
            message:
                'Reports on reviews, and reports that community officers escalate, come here for a final decision.',
          ),
        for (final r in list)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tag(r.contentType, tone: Tone.neutral),
                  const SizedBox(height: 8),
                  Text(r.contentTitle, style: text.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    'Reason: ${r.reason} · reported by ${state.userName(r.reporterId)} · ${timeAgo(r.createdAt)}',
                    style: text.bodySmall,
                  ),
                  _Decision(
                    approveLabel: 'Remove content',
                    declineLabel: 'Dismiss report',
                    onApprove: () {
                      state.decideReport(r, ReportStatus.removed);
                      showToast(context, 'Content removed.');
                    },
                    onDecline: () {
                      state.decideReport(r, ReportStatus.dismissed);
                      showToast(context, 'Report dismissed.', success: false);
                    },
                  ),
                ],
              ),
            ),
          ),
        if (decided.isNotEmpty) ...[
          const SectionHeader('Decided'),
          for (final r in decided)
            InfoRow('check', '${r.status.label}: ${r.contentTitle}'),
        ],
      ],
    );
  }
}

class _Reference extends StatelessWidget {
  const _Reference();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        const NoticeBox(
          'Every reference dataset is stored with its source and collection date. The values below are sample placeholders.',
          icon: 'database',
        ),
        const SizedBox(height: 12),
        for (final (i, d) in state.referenceData.indexed)
          FadeIn(
            index: i,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(d.name, style: text.titleSmall)),
                        Text(d.value,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('Source: ${d.source}', style: text.bodySmall),
                    Text('Collected ${fmtDate(d.collected)}',
                        style: text.bodySmall),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Audit extends StatelessWidget {
  const _Audit();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final entries = [...state.audit]..sort((a, b) => b.at.compareTo(a.at));
    return Column(
      children: [
        for (final (i, e) in entries.indexed)
          FadeIn(
            index: i,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child:
                        AppIcon('list', size: 16, color: AppColors.inkFaint),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.action, style: const TextStyle(fontSize: 13.5)),
                        Text(
                          '${state.userName(e.actorId)} · ${fmtDateTime(e.at)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

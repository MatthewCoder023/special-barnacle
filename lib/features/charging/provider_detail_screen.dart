import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/overlays.dart';
import '../../data/models.dart';
import '../../data/seed_data.dart';
import '../../domain/charging_rules.dart';
import '../../state/app_state.dart';
import '../shared/shared_widgets.dart';
import 'station_detail_screen.dart';

/// M4: a listing in the cross-brand service and parts directory.
class ProviderDetailScreen extends StatelessWidget {
  const ProviderDetailScreen({super.key, required this.providerId});

  final String providerId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = state.providerById(providerId);
    if (p == null) {
      return const DetailScaffold(
        title: 'Provider',
        children: [
          EmptyState(icon: 'wrench', title: 'This listing is not available'),
        ],
      );
    }
    final here = state.location;
    final road = Geo.roadKm(here.lat, here.lng, p.lat, p.lng);
    final tribes = state.myManagedTribes;
    final endorsers = [
      for (final id in p.recommendedBy) ?state.communityById(id)?.name,
    ];
    final text = Theme.of(context).textTheme;

    return DetailScaffold(
      title: 'Provider',
      bottom: AppButton(
        label: 'Open navigation in Google Maps',
        icon: 'route',
        expand: true,
        onTap: () => openDirections(context, p.lat, p.lng),
      ),
      children: [
        Text(p.name, style: text.headlineMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            Tag(p.category.label),
            if (p.status == ApprovalStatus.approved)
              const Tag('Verified provider', tone: Tone.success, icon: 'check')
            else
              const Tag('Waiting for verification', tone: Tone.warning),
          ],
        ),
        const SizedBox(height: 12),
        Text(p.description, style: const TextStyle(color: AppColors.inkSoft)),
        const SizedBox(height: 14),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InfoRow(
                'pin',
                '${p.address} · about ${km(road)} away',
                color: AppColors.ink,
              ),
              InfoRow('phone', p.contact, color: AppColors.ink),
              InfoRow(
                'car',
                'Brands served: ${p.brands.join(', ')}',
                color: AppColors.ink,
              ),
            ],
          ),
        ),
        const SectionHeader('Services and products'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [for (final s in p.services) Tag(s, tone: Tone.neutral)],
        ),
        const SizedBox(height: 8),
        Text(
          'Compatibility and warranty details are declared by the provider. EVYAHE does not certify service quality.',
          style: text.bodySmall,
        ),
        if (endorsers.isNotEmpty || tribes.isNotEmpty) ...[
          const SectionHeader('Tribe recommendations'),
          if (endorsers.isEmpty)
            Text(
              'No tribe has recommended this provider yet.',
              style: text.bodySmall,
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final name in endorsers)
                  Tag('Recommended by $name', tone: Tone.pink, icon: 'flag'),
              ],
            ),
          for (final t in tribes)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: ToggleRow(
                title: 'Recommended by ${t.name}',
                subtitle: 'You manage this tribe.',
                value: p.recommendedBy.contains(t.id),
                onChanged: (_) => state.toggleRecommendation(p, t),
              ),
            ),
        ],
        ReviewSection(
          target: ReviewTarget.provider,
          targetId: p.id,
          tags: SeedData.providerTags,
        ),
      ],
    );
  }
}

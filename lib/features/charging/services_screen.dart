import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/basics.dart';
import '../../data/models.dart';
import '../../domain/charging_rules.dart';
import '../../state/app_state.dart';
import '../shared/shared_widgets.dart';
import 'provider_detail_screen.dart';
import 'tools_screens.dart';

/// M4 service directory: verified cross-brand service providers and parts
/// sellers, plus the cost comparison tool. It is a directory only; EVYAHE
/// does not process bookings, payments or warranty claims.
class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  int _category = 0;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final here = state.location;
    final category = _category == 0
        ? null
        : ProviderCategory.values[_category - 1];
    // Providers have no status reports, so they are ranked by travel time.
    final list =
        state.directory
            .where((p) => category == null || p.category == category)
            .toList()
          ..sort(
            (a, b) => Geo.roadKm(
              here.lat,
              here.lng,
              a.lat,
              a.lng,
            ).compareTo(Geo.roadKm(here.lat, here.lng, b.lat, b.lng)),
          );
    final text = Theme.of(context).textTheme;

    return TabPage(
      title: 'Services',
      subtitle: 'Service and parts directory',
      children: [
        AppCard(
          color: AppColors.sky,
          onTap: () => pushScreen(context, const CostComparisonScreen()),
          child: Row(
            children: [
              const AppIcon('wallet', size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cost comparison', style: text.titleSmall),
                    const Text(
                      'Home charging, public charging and fuel, per month',
                      style: TextStyle(fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              const AppIcon('chevron', size: 16),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PillRow(
          padding: EdgeInsets.zero,
          labels: ['All', for (final c in ProviderCategory.values) c.label],
          index: _category,
          onChanged: (i) => setState(() => _category = i),
        ),
        const SizedBox(height: 14),
        Swap(
          id: _category,
          child: Column(
            children: [
              if (list.isEmpty)
                const EmptyState(
                  icon: 'wrench',
                  title: 'No providers in this category',
                ),
              for (final (i, p) in list.indexed)
                FadeIn(
                  key: ValueKey(p.id),
                  index: i,
                  child: ProviderCard(provider: p),
                ),
            ],
          ),
        ),
        Text(
          'A cross-brand directory. EVYAHE does not process bookings, payments or warranty claims.',
          style: text.bodySmall,
        ),
      ],
    );
  }
}

class ProviderCard extends StatelessWidget {
  const ProviderCard({super.key, required this.provider});

  final ServiceProvider provider;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = provider;
    final here = state.location;
    final road = Geo.roadKm(here.lat, here.lng, p.lat, p.lng);
    final rating = state.ratingFor(ReviewTarget.provider, p.id);
    final count = state.reviewsFor(ReviewTarget.provider, p.id).length;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        onTap: () =>
            pushScreen(context, ProviderDetailScreen(providerId: p.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(p.name, style: text.titleSmall)),
                const AppIcon('chevron', size: 16, color: AppColors.inkFaint),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${p.category.label} · ${p.city} · ${km(road)} · ${minutes(Geo.travelMinutes(road))}',
              style: text.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Serves ${p.brands.join(', ')}',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (p.status == ApprovalStatus.approved)
                  const Tag(
                    'Verified provider',
                    tone: Tone.success,
                    icon: 'check',
                  ),
                if (p.recommendedBy.isNotEmpty)
                  Tag(
                    'Recommended by ${plural(p.recommendedBy.length, 'tribe')}',
                    tone: Tone.pink,
                    icon: 'flag',
                  ),
                if (count > 0)
                  Tag(
                    '${rating.toStringAsFixed(1)} · ${plural(count, 'review')}',
                    tone: Tone.neutral,
                    icon: 'star',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

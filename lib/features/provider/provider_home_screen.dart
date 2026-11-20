import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/overlays.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../charging/provider_detail_screen.dart';
import '../home/notifications_screen.dart';
import '../shared/shared_widgets.dart';

/// Home for service providers and dealerships: manage their own listings
/// and read the feedback on them. Providers do not administer communities.
class ProviderHomeScreen extends StatelessWidget {
  const ProviderHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final listings = state.myListings;
    final reviews = [
      for (final p in listings)
        ...state.reviewsFor(ReviewTarget.provider, p.id),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final average = reviews.isEmpty
        ? 0.0
        : reviews.fold<int>(0, (s, r) => s + r.rating) / reviews.length;
    final text = Theme.of(context).textTheme;

    return TabPage(
      title: 'My listings',
      subtitle: 'Service and parts directory',
      actions: [
        IconSquare(
          icon: 'notifications',
          label: 'Notifications',
          dot: state.unreadCount > 0,
          onTap: () => pushScreen(context, const NotificationsScreen()),
        ),
        IconSquare(
          icon: 'add',
          label: 'Add a listing',
          filled: true,
          onTap: () => _edit(context, null),
        ),
      ],
      children: [
        Row(
          children: [
            Expanded(
              child: StatTile(
                icon: 'store',
                value: '${listings.length}',
                label: 'Listings',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatTile(
                icon: 'star',
                value: reviews.isEmpty ? '–' : average.toStringAsFixed(1),
                label: 'Average rating',
                pink: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatTile(
                icon: 'chat',
                value: '${reviews.length}',
                label: 'Reviews',
              ),
            ),
          ],
        ),
        const SectionHeader('Listings'),
        if (listings.isEmpty)
          const EmptyState(
            icon: 'store',
            title: 'No listings yet',
            message: 'Add your shop or service so EV owners can find it.',
          ),
        for (final (i, p) in listings.indexed)
          FadeIn(
            key: ValueKey(p.id),
            index: i,
            child: Padding(
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
                        Builder(
                          builder: (anchor) => Pressable(
                            label: 'Edit listing',
                            onTap: () => _edit(context, p),
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: AppIcon(
                                'edit',
                                size: 17,
                                color: AppColors.skyDeep,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${p.category.label} · ${p.address}',
                      style: text.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        switch (p.status) {
                          ApprovalStatus.approved => const Tag(
                            'Verified and listed',
                            tone: Tone.success,
                            icon: 'check',
                          ),
                          ApprovalStatus.pending => const Tag(
                            'Waiting for admin verification',
                            tone: Tone.warning,
                          ),
                          ApprovalStatus.rejected => const Tag(
                            'Not approved',
                            tone: Tone.danger,
                          ),
                        },
                        if (p.recommendedBy.isNotEmpty)
                          Tag(
                            'Recommended by ${plural(p.recommendedBy.length, 'tribe')}',
                            tone: Tone.pink,
                            icon: 'flag',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SectionHeader('Recent feedback'),
        if (reviews.isEmpty)
          const EmptyState(
            icon: 'chat',
            title: 'No feedback yet',
            message: 'Reviews from members on your listings appear here.',
          ),
        for (final r in reviews.take(5))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Stars(r.rating.toDouble()),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${state.userName(r.authorId)} · ${timeAgo(r.createdAt)}',
                          style: text.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(r.body),
                  const SizedBox(height: 6),
                  Text(
                    'On ${state.providerById(r.targetId)?.name ?? 'listing'}',
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _edit(BuildContext context, ServiceProvider? listing) {
    showAppSheet<void>(
      context,
      title: listing == null ? 'New listing' : 'Edit listing',
      builder: (_) => _ListingForm(
        listing: listing,
        onDone: (message) => showToast(context, message),
      ),
    );
  }
}

class _ListingForm extends StatefulWidget {
  const _ListingForm({required this.listing, required this.onDone});

  final ServiceProvider? listing;
  final ValueChanged<String> onDone;

  @override
  State<_ListingForm> createState() => _ListingFormState();
}

class _ListingFormState extends State<_ListingForm> {
  late final _name = TextEditingController(text: widget.listing?.name);
  late final _description = TextEditingController(
    text: widget.listing?.description,
  );
  late final _brands = TextEditingController(
    text: widget.listing?.brands.join(', '),
  );
  late final _services = TextEditingController(
    text: widget.listing?.services.join(', '),
  );
  late final _address = TextEditingController(text: widget.listing?.address);
  late final _city = TextEditingController(text: widget.listing?.city);
  late final _contact = TextEditingController(text: widget.listing?.contact);
  late ProviderCategory _category =
      widget.listing?.category ?? ProviderCategory.service;

  @override
  void dispose() {
    for (final c in [
      _name,
      _description,
      _brands,
      _services,
      _address,
      _city,
      _contact,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> _split(TextEditingController c) => c.text
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  @override
  Widget build(BuildContext context) {
    final ready =
        _name.text.trim().isNotEmpty &&
        _address.text.trim().isNotEmpty &&
        _split(_services).isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppField(
          controller: _name,
          label: 'Business name',
          onChanged: (_) => setState(() {}),
        ),
        const FieldLabel('Category'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in ProviderCategory.values)
              ChoicePill(
                label: c.label,
                selected: c == _category,
                onTap: () => setState(() => _category = c),
              ),
          ],
        ),
        const SizedBox(height: 14),
        AppField(controller: _description, label: 'Description', maxLines: 3),
        AppField(
          controller: _services,
          label: 'Services or products',
          hint: 'Separate with commas',
          onChanged: (_) => setState(() {}),
        ),
        AppField(
          controller: _brands,
          label: 'Vehicle brands served',
          hint: 'Separate with commas',
        ),
        AppField(
          controller: _address,
          label: 'Address',
          onChanged: (_) => setState(() {}),
        ),
        AppField(controller: _city, label: 'City'),
        AppField(
          controller: _contact,
          label: 'Contact number',
          keyboardType: TextInputType.phone,
        ),
        AnimatedSwitcher(
          duration: AppMotion.of(context, AppMotion.fast),
          child: widget.listing == null
              ? const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: NoticeBox(
                    'New listings are checked by the platform administrator before they appear in the directory.',
                  ),
                )
              : const SizedBox.shrink(),
        ),
        AppButton(
          label: widget.listing == null ? 'Submit listing' : 'Save changes',
          expand: true,
          onTap: !ready
              ? null
              : () {
                  context.read<AppState>().saveListing(
                    existing: widget.listing,
                    name: _name.text.trim(),
                    category: _category,
                    description: _description.text.trim(),
                    brands: _split(_brands).isEmpty
                        ? ['All brands']
                        : _split(_brands),
                    services: _split(_services),
                    address: _address.text.trim(),
                    city: _city.text.trim(),
                    contact: _contact.text.trim(),
                  );
                  Navigator.of(context).pop();
                  widget.onDone(
                    widget.listing == null
                        ? 'Listing submitted for verification.'
                        : 'Listing saved.',
                  );
                },
        ),
      ],
    );
  }
}

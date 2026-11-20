import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/overlays.dart';
import '../../data/models.dart';
import '../../data/seed_data.dart';
import '../../state/app_state.dart';
import 'event_detail_screen.dart';

/// M3: leaders and officers create an event for a group they manage.
class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key, this.community});

  /// Preselected host group, when opened from a community.
  final Community? community;

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  late Community? _host = widget.community;
  EventType _type = EventType.meetup;
  EventVisibility _visibility = EventVisibility.community;
  DateTime? _date;
  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 0);
  Place? _venue;
  Place? _origin;
  double _capacity = 20;
  bool _announce = true;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  bool get _ready =>
      _host != null &&
      _title.text.trim().isNotEmpty &&
      _date != null &&
      _venue != null &&
      (!_type.hasRoute || (_origin != null && _origin != _venue));

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  void _submit() {
    final state = context.read<AppState>();
    final d = _date!;
    final event = state.createEvent(
      community: _host!,
      title: _title.text.trim(),
      type: _type,
      description: _description.text.trim().isEmpty
          ? 'Details to follow.'
          : _description.text.trim(),
      start: DateTime(d.year, d.month, d.day, _time.hour, _time.minute),
      venue: _venue!,
      origin: _type.hasRoute ? _origin : null,
      capacity: _capacity.round(),
      visibility: _visibility,
      announce: _announce,
    );
    Navigator.of(context).pop();
    showToast(context, 'Event created. Members were notified.');
    pushScreen(context, EventDetailScreen(eventId: event.id));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final hosts = state.managedGroups;
    final start = _date == null
        ? null
        : DateTime(
            _date!.year,
            _date!.month,
            _date!.day,
            _time.hour,
            _time.minute,
          );
    return DetailScaffold(
      title: 'New event',
      bottom: AppButton(
        label: 'Create event',
        expand: true,
        onTap: _ready ? _submit : null,
      ),
      children: [
        const FieldLabel('Host group'),
        Builder(
          builder: (anchor) => _PickerField(
            value: _host?.name,
            hint: 'Choose a community or tribe you manage',
            onTap: () async {
              final picked = await pickOption<Community>(
                anchor,
                title: 'Host group',
                options: hosts,
                label: (c) => c.name,
                subtitle: (c) => c.isTribe ? 'Tribe' : 'Community',
                selected: _host,
              );
              if (picked != null) {
                setState(() {
                  _host = picked;
                  if (!picked.isTribe && _visibility == EventVisibility.tribe) {
                    _visibility = EventVisibility.community;
                  }
                });
              }
            },
          ),
        ),
        AppField(
          controller: _title,
          label: 'Title',
          hint: 'e.g. Tagaytay Weekend Run',
          onChanged: (_) => setState(() {}),
        ),
        const FieldLabel('Type'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in EventType.values)
              ChoicePill(
                label: t.label,
                selected: t == _type,
                onTap: () => setState(() => _type = t),
              ),
          ],
        ),
        const SizedBox(height: 16),
        AppField(controller: _description, label: 'Description', maxLines: 3),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FieldLabel('Date'),
                  _PickerField(
                    value: _date == null ? null : fmtDate(_date!),
                    hint: 'Choose',
                    onTap: _pickDate,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FieldLabel('Start time'),
                  _PickerField(
                    value: start == null
                        ? _time.format(context)
                        : fmtTime(start),
                    hint: 'Choose',
                    onTap: _pickTime,
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_type.hasRoute) ...[
          const FieldLabel('Starting point'),
          Builder(
            builder: (anchor) => _PickerField(
              value: _origin?.name,
              hint: 'Where the convoy starts',
              onTap: () async {
                final picked = await _pickPlace(
                  anchor,
                  'Starting point',
                  _origin,
                );
                if (picked != null) setState(() => _origin = picked);
              },
            ),
          ),
        ],
        FieldLabel(_type.hasRoute ? 'Destination' : 'Venue'),
        Builder(
          builder: (anchor) => _PickerField(
            value: _venue?.name,
            hint: 'Choose a place',
            onTap: () async {
              final picked = await _pickPlace(
                anchor,
                _type.hasRoute ? 'Destination' : 'Venue',
                _venue,
              );
              if (picked != null) setState(() => _venue = picked);
            },
          ),
        ),
        if (_type.hasRoute)
          const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: NoticeBox(
              'After creating the event you can plan one charging stop and run the route check on attendees\' vehicles.',
              icon: 'route',
            ),
          ),
        FieldLabel('Capacity: ${plural(_capacity.round(), 'attendee')}'),
        Slider(
          value: _capacity,
          min: 5,
          max: 100,
          divisions: 19,
          onChanged: (v) => setState(() => _capacity = v),
        ),
        ToggleRow(
          title: 'Announce to members',
          subtitle: 'Posts an announcement in the group and notifies members.',
          value: _announce,
          onChanged: (v) => setState(() => _announce = v),
        ),
        const FieldLabel('Who can see it'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final v in EventVisibility.values)
              if (v != EventVisibility.tribe || (_host?.isTribe ?? false))
                ChoicePill(
                  label: v.label,
                  selected: v == _visibility,
                  onTap: () => setState(() => _visibility = v),
                ),
          ],
        ),
      ],
    );
  }

  Future<Place?> _pickPlace(BuildContext anchor, String title, Place? current) {
    return pickOption<Place>(
      anchor,
      title: title,
      options: SeedData.places,
      label: (p) => p.name,
      selected: current,
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.value,
    required this.hint,
    required this.onTap,
  });

  final String? value;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.skyMist,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value ?? hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: value == null ? AppColors.inkFaint : AppColors.ink,
                ),
              ),
            ),
            const AppIcon('chevron', size: 16, color: AppColors.inkFaint),
          ],
        ),
      ),
    );
  }
}

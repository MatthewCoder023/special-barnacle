import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/basics.dart';
import '../../core/widgets/overlays.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';

/// M1: create a community, or a tribe when [parent] is given.
class CreateCommunityScreen extends StatefulWidget {
  const CreateCommunityScreen({super.key, this.parent});

  final Community? parent;

  @override
  State<CreateCommunityScreen> createState() => _CreateCommunityScreenState();
}

class _CreateCommunityScreenState extends State<CreateCommunityScreen> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _rules = TextEditingController();
  final _model = TextEditingController();
  final _region = TextEditingController();
  CommunityType _type = CommunityType.model;
  bool _approval = false;
  bool _verified = false;

  @override
  void dispose() {
    for (final c in [_name, _description, _rules, _model, _region]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _ready =>
      _name.text.trim().length >= 3 && _description.text.trim().isNotEmpty;

  void _submit() {
    final state = context.read<AppState>();
    String? orNull(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    final created = state.createCommunity(
      name: _name.text.trim(),
      type: _type,
      description: _description.text.trim(),
      rules: orNull(_rules) ?? 'No rules written yet.',
      joinPolicy: _approval ? JoinPolicy.approval : JoinPolicy.open,
      requiresVerification: _verified,
      criteriaModel: orNull(_model),
      criteriaRegion: orNull(_region),
      parent: widget.parent,
    );
    Navigator.of(context).pop();
    showToast(
      context,
      created.isTribe
          ? 'Tribe created. You are its leader.'
          : 'Community submitted. The platform administrator will review it.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final tribe = widget.parent != null;
    return DetailScaffold(
      title: tribe ? 'New tribe' : 'New community',
      bottom: AppButton(
        label: tribe ? 'Create tribe' : 'Submit for approval',
        expand: true,
        onTap: _ready ? _submit : null,
      ),
      children: [
        NoticeBox(
          tribe
              ? 'A tribe is a smaller group inside ${widget.parent!.name}. Only its members can join.'
              : 'New communities are reviewed by the platform administrator before they appear, to prevent impersonation of real clubs.',
        ),
        const SizedBox(height: 16),
        AppField(
          controller: _name,
          label: 'Name',
          hint: tribe ? 'e.g. Cavite Tribe' : 'e.g. Dolphin Owners PH',
          onChanged: (_) => setState(() {}),
        ),
        const FieldLabel('Type'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in CommunityType.values)
              ChoicePill(
                label: t.label,
                selected: t == _type,
                onTap: () => setState(() => _type = t),
              ),
          ],
        ),
        const SizedBox(height: 16),
        AppField(
          controller: _description,
          label: 'Description',
          hint: 'Who is it for and what do members do?',
          maxLines: 3,
          onChanged: (_) => setState(() {}),
        ),
        AppField(
          controller: _rules,
          label: 'Rules',
          hint: 'Posting, selling, behavior, charging etiquette',
          maxLines: 4,
        ),
        ToggleRow(
          title: 'Approve each join request',
          subtitle: 'Off means anyone eligible joins right away.',
          value: _approval,
          onChanged: (v) => setState(() => _approval = v),
        ),
        ToggleRow(
          title: 'Require verified ownership',
          subtitle: 'Only members with the verified-owner label can join.',
          value: _verified,
          onChanged: (v) => setState(() => _verified = v),
        ),
        const SizedBox(height: 8),
        Text('Membership criteria (optional)',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 10),
        AppField(
            controller: _model,
            label: 'Vehicle model',
            hint: 'e.g. BYD Dolphin'),
        AppField(
            controller: _region, label: 'Region', hint: 'e.g. Laguna'),
      ],
    );
  }
}

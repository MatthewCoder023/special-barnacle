import '../models.dart';
import 'remote_store.dart';

/// Table names, in the order they are loaded.
const remoteTables = [
  'vehicles',
  'profiles',
  'communities',
  'community_members',
  'join_requests',
  'announcements',
  'discussions',
  'replies',
  'helpful_votes',
  'reviews',
  'proposals',
  'votes',
  'concerns',
  'concern_supporters',
  'position_summaries',
  'content_reports',
  'events',
  'rsvps',
  'stations',
  'status_reports',
  'check_ins',
  'providers',
  'provider_recommendations',
  'audit_log',
  'reference_data',
  'notifications',
  'news_articles',
];

/// Backend functions loaded with the tables. Membership lists, votes and
/// RSVPs are private, so these return counts and anonymous ballots for what
/// the user cannot read directly.
const remoteFunctions = ['member_counts', 'poll_ballots', 'event_attendance'];

typedef Row = Map<String, dynamic>;

DateTime _time(dynamic v) => DateTime.parse(v as String).toLocal();
DateTime _date(dynamic v) => DateTime.parse(v as String);
double _num(dynamic v) => (v as num).toDouble();
List<String> _strings(dynamic v) => [
  for (final x in (v as List? ?? const [])) x as String,
];

/// How many of [total] records the user cannot see, given [visible] of
/// them. Without a total (sample data, older backends) nothing is hidden.
int _hidden(int? total, int visible) =>
    total == null || total <= visible ? 0 : total - visible;

/// Groups [rows] by the string value of [key].
Map<String, List<Row>> _groupBy(List<Row> rows, String key) {
  final out = <String, List<Row>>{};
  for (final r in rows) {
    (out[r[key] as String] ??= []).add(r);
  }
  return out;
}

/// Builds the app's models from database rows.
///
/// [tables] maps each name in [remoteTables] and [remoteFunctions] to its
/// rows. Child rows
/// (members, replies, votes, RSVPs, reports and so on) are folded into their
/// parent models, matching how the screens read them.
RemoteSnapshot buildSnapshot(Map<String, List<Row>> tables) {
  List<Row> rows(String name) => tables[name] ?? const [];

  final vehicles = {
    for (final r in rows('vehicles'))
      r['id'] as String: Vehicle(
        id: r['id'] as String,
        brand: r['brand'] as String,
        model: r['model'] as String,
        type: VehicleType.values.byName(r['type'] as String),
        connectors: [
          for (final c in _strings(r['connectors']))
            ConnectorType.values.byName(c),
        ],
        batteryKwh: _num(r['battery_kwh']),
        kwhPerKm: _num(r['kwh_per_km']),
      ),
  };

  final users = [
    for (final r in rows('profiles'))
      AppUser(
        id: r['id'] as String,
        name: r['name'] as String,
        role: PlatformRole.values.byName(r['role'] as String),
        region: r['region'] as String? ?? '',
        vehicle: vehicles[r['vehicle_id']],
        verification: VerificationStatus.values.byName(
          r['verification'] as String,
        ),
        username: r['username'] as String?,
        avatarUrl: r['avatar_url'] as String?,
        chargeToPct: (r['charge_to_pct'] as num?)?.toInt() ?? 80,
        reservePct: (r['reserve_pct'] as num?)?.toInt() ?? 10,
        notifyCommunity: r['notify_community'] as bool? ?? true,
        notifyEvents: r['notify_events'] as bool? ?? true,
        notifyPolls: r['notify_polls'] as bool? ?? true,
        showVehicle: r['show_vehicle'] as bool? ?? true,
        showNameOnStations: r['show_name_on_stations'] as bool? ?? true,
      ),
  ];

  final membersOf = _groupBy(rows('community_members'), 'community_id');
  final memberTotals = {
    for (final r in rows('member_counts'))
      r['community_id'] as String: (r['members'] as num).toInt(),
  };
  final requestsOf = _groupBy(rows('join_requests'), 'community_id');
  final communities = [
    for (final r in rows('communities'))
      () {
        final members = membersOf[r['id']] ?? const <Row>[];
        final c = Community(
          id: r['id'] as String,
          parentId: r['parent_id'] as String?,
          name: r['name'] as String,
          type: CommunityType.values.byName(r['type'] as String),
          description: r['description'] as String? ?? '',
          rules: r['rules'] as String? ?? '',
          joinPolicy: JoinPolicy.values.byName(r['join_policy'] as String),
          requiresVerification: r['requires_verification'] as bool? ?? false,
          criteriaModel: r['criteria_model'] as String?,
          criteriaRegion: r['criteria_region'] as String?,
          membersCanPropose: r['members_can_propose'] as bool? ?? true,
          status: ApprovalStatus.values.byName(r['status'] as String),
          createdAt: _time(r['created_at']),
          members: {
            for (final m in members)
              m['user_id'] as String: GroupRole.values.byName(
                m['role'] as String,
              ),
          },
          joinRequests: [
            for (final q in requestsOf[r['id']] ?? const <Row>[])
              q['user_id'] as String,
          ],
          hiddenMembers: _hidden(memberTotals[r['id']], members.length),
        );
        for (final m in members) {
          c.joinedAt[m['user_id'] as String] = _time(m['joined_at']);
        }
        return c;
      }(),
  ];

  // Helpfulness votes, keyed by "type:id".
  final helpful = <String, Set<String>>{};
  for (final r in rows('helpful_votes')) {
    (helpful['${r['target_type']}:${r['target_id']}'] ??= {}).add(
      r['user_id'] as String,
    );
  }
  Set<String> helpfulFor(String type, String id) => helpful['$type:$id'] ?? {};

  final announcements = [
    for (final r in rows('announcements'))
      Announcement(
        id: r['id'] as String,
        communityId: r['community_id'] as String,
        authorId: r['author_id'] as String,
        title: r['title'] as String,
        body: r['body'] as String,
        pinned: r['pinned'] as bool? ?? false,
        createdAt: _time(r['created_at']),
      ),
  ];

  final repliesOf = _groupBy(rows('replies'), 'discussion_id');
  final discussions = [
    for (final r in rows('discussions'))
      Discussion(
        id: r['id'] as String,
        communityId: r['community_id'] as String,
        authorId: r['author_id'] as String,
        title: r['title'] as String,
        body: r['body'] as String,
        topic: r['topic'] as String,
        vehicleModel: r['vehicle_model'] as String?,
        isQuestion: r['is_question'] as bool? ?? false,
        createdAt: _time(r['created_at']),
        helpful: helpfulFor('discussion', r['id'] as String),
        replies: [
          for (final p in repliesOf[r['id']] ?? const <Row>[])
            Reply(
              id: p['id'] as String,
              authorId: p['author_id'] as String,
              body: p['body'] as String,
              createdAt: _time(p['created_at']),
              helpful: helpfulFor('reply', p['id'] as String),
            ),
        ],
      ),
  ];

  final reviews = [
    for (final r in rows('reviews'))
      Review(
        id: r['id'] as String,
        target: ReviewTarget.values.byName(r['target_type'] as String),
        targetId: r['target_id'] as String,
        authorId: r['author_id'] as String,
        rating: (r['rating'] as num).toInt(),
        tags: _strings(r['tags']),
        body: r['body'] as String,
        createdAt: _time(r['created_at']),
        helpful: helpfulFor('review', r['id'] as String),
      ),
  ];

  final votesOf = _groupBy(rows('votes'), 'proposal_id');
  final ballotsOf = _groupBy(rows('poll_ballots'), 'proposal_id');
  final proposals = [
    for (final r in rows('proposals'))
      Proposal(
        id: r['id'] as String,
        communityId: r['community_id'] as String,
        authorId: r['author_id'] as String,
        title: r['title'] as String,
        description: r['description'] as String? ?? '',
        options: _strings(r['options']),
        ranked: r['ranked'] as bool? ?? false,
        deadline: _time(r['deadline']),
        quorum: (r['quorum'] as num).toInt(),
        closed: r['closed'] as bool? ?? false,
        outcome: r['outcome'] as String?,
        createdAt: _time(r['created_at']),
        votes: {
          for (final v in votesOf[r['id']] ?? const <Row>[])
            v['user_id'] as String: [
              for (final i in v['choice'] as List) (i as num).toInt(),
            ],
        },
        hiddenBallots: [
          for (final b in ballotsOf[r['id']] ?? const <Row>[])
            [for (final i in b['choice'] as List) (i as num).toInt()],
        ],
      ),
  ];

  final supportersOf = _groupBy(rows('concern_supporters'), 'concern_id');
  final concerns = [
    for (final r in rows('concerns'))
      Concern(
        id: r['id'] as String,
        communityId: r['community_id'] as String,
        authorId: r['author_id'] as String,
        category: r['category'] as String,
        title: r['title'] as String,
        details: r['details'] as String,
        location: r['location'] as String,
        stationId: r['station_id'] as String?,
        hasPhoto: r['has_photo'] as bool? ?? false,
        createdAt: _time(r['created_at']),
        supporters: {
          for (final s in supportersOf[r['id']] ?? const <Row>[])
            s['user_id'] as String,
        },
      ),
  ];

  final summaries = [
    for (final r in rows('position_summaries'))
      PositionSummary(
        id: r['id'] as String,
        communityId: r['community_id'] as String,
        authorId: r['author_id'] as String,
        title: r['title'] as String,
        category: r['category'] as String,
        text: r['body'] as String,
        concernCount: (r['concern_count'] as num).toInt(),
        supportCount: (r['support_count'] as num).toInt(),
        createdAt: _time(r['created_at']),
      ),
  ];

  final reports = [
    for (final r in rows('content_reports'))
      ContentReport(
        id: r['id'] as String,
        reporterId: r['reporter_id'] as String,
        contentType: r['content_type'] as String,
        contentId: r['content_id'] as String,
        contentTitle: r['content_title'] as String,
        reason: r['reason'] as String,
        communityId: r['community_id'] as String?,
        status: ReportStatus.values.byName(r['status'] as String),
        createdAt: _time(r['created_at']),
      ),
  ];

  final rsvpsOf = _groupBy(rows('rsvps'), 'event_id');
  final attendeeTotals = {
    for (final r in rows('event_attendance'))
      r['event_id'] as String: (r['attendees'] as num).toInt(),
  };
  final events = [
    for (final r in rows('events'))
      CommunityEvent(
        id: r['id'] as String,
        communityId: r['community_id'] as String,
        creatorId: r['creator_id'] as String,
        title: r['title'] as String,
        type: EventType.values.byName(r['type'] as String),
        description: r['description'] as String? ?? '',
        start: _time(r['starts_at']),
        venue: Place(
          r['venue_name'] as String,
          _num(r['venue_lat']),
          _num(r['venue_lng']),
        ),
        origin: r['origin_name'] == null
            ? null
            : Place(
                r['origin_name'] as String,
                _num(r['origin_lat']),
                _num(r['origin_lng']),
              ),
        capacity: (r['capacity'] as num).toInt(),
        visibility: EventVisibility.values.byName(r['visibility'] as String),
        stopStationId: r['stop_station_id'] as String?,
        cancelled: r['cancelled'] as bool? ?? false,
        rsvps: [
          for (final v in rsvpsOf[r['id']] ?? const <Row>[])
            Rsvp(
              userId: v['user_id'] as String,
              vehicle: vehicles[v['vehicle_id']],
              startBatteryPct: _num(v['start_battery_pct']),
            ),
        ],
        hiddenAttendees: _hidden(
          attendeeTotals[r['id']],
          (rsvpsOf[r['id']] ?? const <Row>[]).length,
        ),
      ),
  ];

  final reportsOf = _groupBy(rows('status_reports'), 'station_id');
  final checkInsOf = _groupBy(rows('check_ins'), 'station_id');
  final stations = [
    for (final r in rows('stations'))
      Station(
        id: r['id'] as String,
        name: r['name'] as String,
        operator: r['operator'] as String? ?? '',
        address: r['address'] as String? ?? '',
        city: r['city'] as String? ?? '',
        lat: _num(r['lat']),
        lng: _num(r['lng']),
        connectors: [
          for (final c in r['connectors'] as List? ?? const [])
            StationConnector(
              ConnectorType.values.byName((c as Map)['type'] as String),
              _num(c['power_kw']),
            ),
        ],
        fee: r['fee'] as String? ?? '',
        feeDate: _date(r['fee_date']),
        hours: r['hours'] as String? ?? '',
        parking: r['parking'] as String? ?? '',
        source: r['source'] as String,
        sourceDate: _date(r['source_date']),
        reports: [
          for (final s in reportsOf[r['id']] ?? const <Row>[])
            StatusReport(
              userId: s['user_id'] as String,
              working: s['working'] as bool,
              note: s['note'] as String? ?? '',
              createdAt: _time(s['created_at']),
            ),
        ],
        checkIns: [
          for (final c in checkInsOf[r['id']] ?? const <Row>[])
            CheckIn(
              userId: c['user_id'] as String,
              charging: c['charging'] as bool,
              createdAt: _time(c['created_at']),
            ),
        ],
      ),
  ];

  final recommendedBy = _groupBy(
    rows('provider_recommendations'),
    'provider_id',
  );
  final providers = [
    for (final r in rows('providers'))
      ServiceProvider(
        id: r['id'] as String,
        ownerId: r['owner_id'] as String? ?? '',
        name: r['name'] as String,
        category: ProviderCategory.values.byName(r['category'] as String),
        description: r['description'] as String? ?? '',
        brands: _strings(r['brands']),
        services: _strings(r['services']),
        address: r['address'] as String? ?? '',
        city: r['city'] as String? ?? '',
        lat: _num(r['lat']),
        lng: _num(r['lng']),
        contact: r['contact'] as String? ?? '',
        status: ApprovalStatus.values.byName(r['status'] as String),
        recommendedBy: {
          for (final t in recommendedBy[r['id']] ?? const <Row>[])
            t['tribe_id'] as String,
        },
      ),
  ];

  return RemoteSnapshot(
    users: users,
    vehicles: vehicles.values.toList(),
    communities: communities,
    announcements: announcements,
    discussions: discussions,
    reviews: reviews,
    proposals: proposals,
    concerns: concerns,
    summaries: summaries,
    reports: reports,
    events: events,
    stations: stations,
    providers: providers,
    audit: [
      for (final r in rows('audit_log'))
        AuditEntry(
          r['actor_id'] as String,
          r['action'] as String,
          _time(r['created_at']),
        ),
    ],
    referenceData: [
      for (final r in rows('reference_data'))
        ReferenceData(
          name: r['name'] as String,
          value: r['value'] as String,
          source: r['source'] as String,
          collected: _date(r['collected_on']),
        ),
    ],
    news: [
      for (final r in rows('news_articles'))
        NewsArticle(
          id: r['id'] as String,
          title: r['title'] as String,
          summary: r['summary'] as String? ?? '',
          source: r['source'] as String,
          publishedAt: _time(r['published_at']),
          url: r['url'] as String?,
          imageUrl: r['image_url'] as String?,
          philippines: r['philippines'] as bool? ?? true,
        ),
    ]..sort((a, b) => b.publishedAt.compareTo(a.publishedAt)),
    notifications: [
      for (final r in rows('notifications'))
        AppNotification(
          userId: r['user_id'] as String?,
          title: r['title'] as String,
          body: r['body'] as String,
          read: r['read'] as bool? ?? false,
          at: _time(r['created_at']),
        ),
    ],
  );
}

/// Database rows for the records the app writes. Timestamps such as
/// `created_at` are left to the database defaults.
class Rows {
  Rows._();

  static Row community(Community c) => {
    'id': c.id,
    'parent_id': c.parentId,
    ...communitySettings(c),
    'name': c.name,
    'type': c.type.name,
    'description': c.description,
  };

  /// The fields leaders and officers may change.
  static Row communitySettings(Community c) => {
    'rules': c.rules,
    'join_policy': c.joinPolicy.name,
    'requires_verification': c.requiresVerification,
    'criteria_model': c.criteriaModel,
    'criteria_region': c.criteriaRegion,
    'members_can_propose': c.membersCanPropose,
  };

  static Row announcement(Announcement a) => {
    'id': a.id,
    'community_id': a.communityId,
    'author_id': a.authorId,
    'title': a.title,
    'body': a.body,
    'pinned': a.pinned,
  };

  static Row discussion(Discussion d) => {
    'id': d.id,
    'community_id': d.communityId,
    'author_id': d.authorId,
    'title': d.title,
    'body': d.body,
    'topic': d.topic,
    'vehicle_model': d.vehicleModel,
    'is_question': d.isQuestion,
  };

  static Row reply(Reply r, String discussionId) => {
    'id': r.id,
    'discussion_id': discussionId,
    'author_id': r.authorId,
    'body': r.body,
  };

  static Row review(Review r) => {
    'id': r.id,
    'target_type': r.target.name,
    'target_id': r.targetId,
    'author_id': r.authorId,
    'rating': r.rating,
    'tags': r.tags,
    'body': r.body,
  };

  static Row proposal(Proposal p) => {
    'id': p.id,
    'community_id': p.communityId,
    'author_id': p.authorId,
    'title': p.title,
    'description': p.description,
    'options': p.options,
    'ranked': p.ranked,
    'deadline': p.deadline.toUtc().toIso8601String(),
    'quorum': p.quorum,
  };

  static Row concern(Concern k) => {
    'id': k.id,
    'community_id': k.communityId,
    'author_id': k.authorId,
    'category': k.category,
    'title': k.title,
    'details': k.details,
    'location': k.location,
    'station_id': k.stationId,
    'has_photo': k.hasPhoto,
  };

  static Row summary(PositionSummary s) => {
    'id': s.id,
    'community_id': s.communityId,
    'author_id': s.authorId,
    'title': s.title,
    'category': s.category,
    'body': s.text,
    'concern_count': s.concernCount,
    'support_count': s.supportCount,
  };

  static Row report(ContentReport r) => {
    'id': r.id,
    'reporter_id': r.reporterId,
    'content_type': r.contentType,
    'content_id': r.contentId,
    'content_title': r.contentTitle,
    'reason': r.reason,
    'community_id': r.communityId,
    'status': r.status.name,
  };

  static Row event(CommunityEvent e) => {
    'id': e.id,
    'community_id': e.communityId,
    'creator_id': e.creatorId,
    'title': e.title,
    'type': e.type.name,
    'description': e.description,
    'starts_at': e.start.toUtc().toIso8601String(),
    'venue_name': e.venue.name,
    'venue_lat': e.venue.lat,
    'venue_lng': e.venue.lng,
    'origin_name': e.origin?.name,
    'origin_lat': e.origin?.lat,
    'origin_lng': e.origin?.lng,
    'capacity': e.capacity,
    'visibility': e.visibility.name,
    'stop_station_id': e.stopStationId,
  };

  static Row provider(ServiceProvider p) => {
    'id': p.id,
    'owner_id': p.ownerId,
    ...providerDetails(p),
    'lat': p.lat,
    'lng': p.lng,
  };

  /// The fields a provider may edit on their own listing.
  static Row providerDetails(ServiceProvider p) => {
    'name': p.name,
    'category': p.category.name,
    'description': p.description,
    'brands': p.brands,
    'services': p.services,
    'address': p.address,
    'city': p.city,
    'contact': p.contact,
  };
}

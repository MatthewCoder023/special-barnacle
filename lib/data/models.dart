/// Data models for EVYAHE, grouped by the module that owns them.
///
/// These mirror the tables planned for Supabase (PostgreSQL). They are plain
/// Dart classes so the in-memory repository can be replaced by Supabase calls
/// without touching the screens.
library;

import 'dart:typed_data';

// ───────────────────────── Users and vehicles (RBAC) ─────────────────────────

/// Platform-level role. Leader and officer are per-community roles
/// ([GroupRole]) held by members.
enum PlatformRole {
  admin('Platform administrator'),
  member('Member'),
  guest('Guest'),
  provider('Service provider');

  const PlatformRole(this.label);
  final String label;
}

enum VehicleType {
  bev('BEV'),
  phev('PHEV'),
  reev('REEV');

  const VehicleType(this.label);
  final String label;
}

enum ConnectorType {
  ccs2('CCS2'),
  type2('Type 2'),
  chademo('CHAdeMO'),
  gbt('GB/T');

  const ConnectorType(this.label);
  final String label;
}

enum VerificationStatus {
  none('Not verified'),
  pending('Verification pending'),
  verified('Verified owner'),
  rejected('Verification declined');

  const VerificationStatus(this.label);
  final String label;
}

class Vehicle {
  const Vehicle({
    this.id,
    required this.brand,
    required this.model,
    required this.type,
    required this.connectors,
    required this.batteryKwh,
    required this.kwhPerKm,
  });

  /// Database id; null for the bundled sample vehicles.
  final String? id;
  final String brand;
  final String model;
  final VehicleType type;
  final List<ConnectorType> connectors;
  final double batteryKwh;

  /// Rated energy use. For PHEV and REEV this is the electric-only figure.
  final double kwhPerKm;

  String get name => '$brand $model';
  double get fullRangeKm => batteryKwh / kwhPerKm;

  /// PHEV and REEV have an engine that can extend the driving range.
  bool get hasEngine => type != VehicleType.bev;
}

class AppUser {
  AppUser({
    required this.id,
    required this.name,
    required this.role,
    required this.region,
    this.vehicle,
    this.verification = VerificationStatus.none,
    this.username,
    this.avatarUrl,
    this.chargeToPct = 80,
    this.reservePct = 10,
    this.notifyCommunity = true,
    this.notifyEvents = true,
    this.notifyPolls = true,
    this.showVehicle = true,
    this.showNameOnStations = true,
  });

  final String id;
  String name;
  final PlatformRole role;
  String region;
  Vehicle? vehicle;
  VerificationStatus verification;

  /// Optional handle, 3 to 20 lowercase letters, digits or underscores.
  String? username;

  /// Profile photo: a link when stored on the backend, or bytes held in
  /// memory when running on sample data.
  String? avatarUrl;
  Uint8List? avatarBytes;

  /// Charging preferences used by route planning: the level to charge to
  /// at a stop, and the battery level to keep in hand on arrival.
  int chargeToPct;
  int reservePct;

  /// Notification preferences, by kind.
  bool notifyCommunity;
  bool notifyEvents;
  bool notifyPolls;

  /// Privacy preferences: whether other members see this user's vehicle on
  /// member lists, and their name on station check-ins and status reports.
  bool showVehicle;
  bool showNameOnStations;

  bool get isVerified => verification == VerificationStatus.verified;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

/// What a notification is about, so users can switch kinds off.
enum NotifyKind { community, events, polls, account }

// ─────────────────── M1 Community & Tribe Management ───────────────────

enum CommunityType {
  brand('Brand'),
  model('Model'),
  region('Region'),
  interest('Interest');

  const CommunityType(this.label);
  final String label;
}

enum JoinPolicy {
  open('Open to join'),
  approval('Approval needed');

  const JoinPolicy(this.label);
  final String label;
}

enum GroupRole {
  leader('Leader'),
  officer('Officer'),
  member('Member');

  const GroupRole(this.label);
  final String label;
}

enum ApprovalStatus { pending, approved, rejected }

/// A community, or a tribe when [parentId] is set.
class Community {
  Community({
    required this.id,
    required this.name,
    required this.type,
    required this.description,
    required this.rules,
    required this.joinPolicy,
    required this.createdAt,
    this.parentId,
    this.requiresVerification = false,
    this.criteriaModel,
    this.criteriaRegion,
    this.membersCanPropose = true,
    this.status = ApprovalStatus.approved,
    Map<String, GroupRole>? members,
    List<String>? joinRequests,
  })  : members = members ?? {},
        joinRequests = joinRequests ?? [] {
    // Initial members get join dates spread from the creation date to now,
    // so the membership-growth chart has something to show. The backend
    // stores the real date each member joined.
    final ids = this.members.keys.toList();
    final age = DateTime.now().difference(createdAt);
    for (var i = 0; i < ids.length; i++) {
      joinedAt[ids[i]] = createdAt.add(age * (i / ids.length));
    }
  }

  final String id;
  String name;
  CommunityType type;
  String description;
  String rules;
  JoinPolicy joinPolicy;
  final DateTime createdAt;
  final String? parentId;
  bool requiresVerification;

  /// Optional membership criteria set by the leader.
  String? criteriaModel;
  String? criteriaRegion;

  /// Voting rule: whether ordinary members may open proposals.
  bool membersCanPropose;
  ApprovalStatus status;

  /// User id to role in this group.
  final Map<String, GroupRole> members;
  final List<String> joinRequests;

  /// User id to the date they joined.
  final Map<String, DateTime> joinedAt = {};

  bool get isTribe => parentId != null;
  String get kind => isTribe ? 'tribe' : 'community';
}

// ─────────────── M2 Community Engagement & Governance ───────────────

class Announcement {
  Announcement({
    required this.id,
    required this.communityId,
    required this.authorId,
    required this.title,
    required this.body,
    required this.createdAt,
    this.pinned = false,
  });

  final String id;
  final String communityId;
  final String authorId;
  final String title;
  final String body;
  final DateTime createdAt;
  bool pinned;
}

class Reply {
  Reply({
    required this.id,
    required this.authorId,
    required this.body,
    required this.createdAt,
    Set<String>? helpful,
  }) : helpful = helpful ?? {};

  final String id;
  final String authorId;
  final String body;
  final DateTime createdAt;
  final Set<String> helpful;
}

class Discussion {
  Discussion({
    required this.id,
    required this.communityId,
    required this.authorId,
    required this.title,
    required this.body,
    required this.topic,
    required this.createdAt,
    this.vehicleModel,
    this.isQuestion = false,
    List<Reply>? replies,
    Set<String>? helpful,
  })  : replies = replies ?? [],
        helpful = helpful ?? {};

  final String id;
  final String communityId;
  final String authorId;
  final String title;
  final String body;
  final String topic;
  final DateTime createdAt;
  final String? vehicleModel;
  final bool isQuestion;
  final List<Reply> replies;
  final Set<String> helpful;
}

enum ReviewTarget { station, provider }

class Review {
  Review({
    required this.id,
    required this.target,
    required this.targetId,
    required this.authorId,
    required this.rating,
    required this.tags,
    required this.body,
    required this.createdAt,
    Set<String>? helpful,
  }) : helpful = helpful ?? {};

  final String id;
  final ReviewTarget target;
  final String targetId;
  final String authorId;
  final int rating;
  final List<String> tags;
  final String body;
  final DateTime createdAt;
  final Set<String> helpful;
}

/// A proposal or poll. Each voter stores the option indexes they chose: one
/// for single choice, or all of them in preference order for ranked choice.
class Proposal {
  Proposal({
    required this.id,
    required this.communityId,
    required this.authorId,
    required this.title,
    required this.description,
    required this.options,
    required this.ranked,
    required this.deadline,
    required this.quorum,
    required this.createdAt,
    Map<String, List<int>>? votes,
    this.closed = false,
    this.outcome,
  }) : votes = votes ?? {};

  final String id;
  final String communityId;
  final String authorId;
  final String title;
  final String description;
  final List<String> options;
  final bool ranked;
  final DateTime deadline;

  /// Minimum number of votes for the result to stand, set by the community.
  final int quorum;
  final DateTime createdAt;
  final Map<String, List<int>> votes;
  bool closed;

  /// Outcome text published by the leader when the poll is closed.
  String? outcome;
}

/// A member's concern on the Community Voice board.
class Concern {
  Concern({
    required this.id,
    required this.communityId,
    required this.authorId,
    required this.category,
    required this.title,
    required this.details,
    required this.location,
    required this.createdAt,
    this.stationId,
    this.hasPhoto = false,
    Set<String>? supporters,
  }) : supporters = supporters ?? {};

  final String id;
  final String communityId;
  final String authorId;
  final String category;
  final String title;
  final String details;
  final String location;
  final DateTime createdAt;
  final String? stationId;
  final bool hasPhoto;
  final Set<String> supporters;
}

/// Dated position summary a leader compiles from concerns.
class PositionSummary {
  PositionSummary({
    required this.id,
    required this.communityId,
    required this.authorId,
    required this.title,
    required this.category,
    required this.text,
    required this.concernCount,
    required this.supportCount,
    required this.createdAt,
  });

  final String id;
  final String communityId;
  final String authorId;
  final String title;
  final String category;
  final String text;
  final int concernCount;
  final int supportCount;
  final DateTime createdAt;
}

enum ReportStatus {
  open('Open'),
  escalated('Sent to platform admin'),
  removed('Content removed'),
  dismissed('Dismissed');

  const ReportStatus(this.label);
  final String label;
}

/// A report filed against a piece of content.
class ContentReport {
  ContentReport({
    required this.id,
    required this.reporterId,
    required this.contentType,
    required this.contentId,
    required this.contentTitle,
    required this.reason,
    required this.createdAt,
    this.communityId,
    this.status = ReportStatus.open,
  });

  final String id;
  final String reporterId;

  /// 'discussion', 'reply', 'review' or 'concern'.
  final String contentType;
  final String contentId;
  final String contentTitle;
  final String reason;
  final DateTime createdAt;
  final String? communityId;
  ReportStatus status;
}

// ───────────────────── M3 Events & Group Trips ─────────────────────

enum EventType {
  meetup('Meetup'),
  convoy('Convoy'),
  drive('Drive'),
  outreach('Outreach');

  const EventType(this.label);
  final String label;

  /// Convoys and drives travel a route, so the route check applies.
  bool get hasRoute => this == convoy || this == drive;
}

enum EventVisibility {
  tribe('Tribe only'),
  community('Community'),
  public('Public');

  const EventVisibility(this.label);
  final String label;
}

/// A named point used for venues, starting points and trip destinations.
class Place {
  const Place(this.name, this.lat, this.lng);

  final String name;
  final double lat;
  final double lng;
}

class Rsvp {
  Rsvp({
    required this.userId,
    required this.vehicle,
    required this.startBatteryPct,
  });

  final String userId;

  /// Attending vehicle, taken from the member's profile. Null for members
  /// without a vehicle attending a meetup or outreach.
  final Vehicle? vehicle;
  double startBatteryPct;
}

class CommunityEvent {
  CommunityEvent({
    required this.id,
    required this.communityId,
    required this.creatorId,
    required this.title,
    required this.type,
    required this.description,
    required this.start,
    required this.venue,
    required this.capacity,
    required this.visibility,
    this.origin,
    this.stopStationId,
    this.cancelled = false,
    List<Rsvp>? rsvps,
  }) : rsvps = rsvps ?? [];

  final String id;
  final String communityId;
  final String creatorId;
  String title;
  final EventType type;
  String description;
  DateTime start;

  /// Venue, or the destination of a convoy or drive.
  Place venue;

  /// Starting point of a convoy or drive.
  Place? origin;
  int capacity;
  EventVisibility visibility;

  /// The one planned charging stop, chosen by the leader.
  String? stopStationId;
  bool cancelled;
  final List<Rsvp> rsvps;
}

// ───────────────────── M4 EV Charging & Services ─────────────────────

class StationConnector {
  const StationConnector(this.type, this.powerKw);

  final ConnectorType type;
  final double powerKw;
}

class StatusReport {
  StatusReport({
    required this.userId,
    required this.working,
    required this.createdAt,
    this.note = '',
  });

  final String userId;
  final bool working;
  final DateTime createdAt;
  final String note;
}

class CheckIn {
  CheckIn({
    required this.userId,
    required this.charging,
    required this.createdAt,
  });

  final String userId;

  /// True when charging, false when waiting in the queue.
  final bool charging;
  final DateTime createdAt;
}

class Station {
  Station({
    required this.id,
    required this.name,
    required this.operator,
    required this.address,
    required this.city,
    required this.lat,
    required this.lng,
    required this.connectors,
    required this.fee,
    required this.feeDate,
    required this.hours,
    required this.parking,
    required this.source,
    required this.sourceDate,
    List<StatusReport>? reports,
    List<CheckIn>? checkIns,
  })  : reports = reports ?? [],
        checkIns = checkIns ?? [];

  final String id;
  final String name;
  final String operator;
  final String address;
  final String city;
  final double lat;
  final double lng;
  final List<StationConnector> connectors;

  /// Published fee and the date it was collected.
  final String fee;
  final DateTime feeDate;
  final String hours;
  final String parking;

  /// Reference data source and collection date.
  final String source;
  final DateTime sourceDate;
  final List<StatusReport> reports;
  final List<CheckIn> checkIns;

  double get maxPowerKw =>
      connectors.fold<double>(0, (m, c) => c.powerKw > m ? c.powerKw : m);
}

enum ProviderCategory {
  service('Service center'),
  parts('Parts and accessories'),
  tires('Tires and alignment'),
  dealership('Dealership service');

  const ProviderCategory(this.label);
  final String label;
}

/// A listing in the cross-brand service and parts directory.
class ServiceProvider {
  ServiceProvider({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.category,
    required this.description,
    required this.brands,
    required this.services,
    required this.address,
    required this.city,
    required this.lat,
    required this.lng,
    required this.contact,
    this.status = ApprovalStatus.approved,
    Set<String>? recommendedBy,
  }) : recommendedBy = recommendedBy ?? {};

  final String id;
  final String ownerId;
  String name;
  ProviderCategory category;
  String description;
  List<String> brands;
  List<String> services;
  String address;
  String city;
  final double lat;
  final double lng;
  String contact;

  /// Approved listings are shown as verified providers.
  ApprovalStatus status;

  /// Ids of tribes that marked this provider "recommended by our tribe".
  final Set<String> recommendedBy;
}

// ───────────────────── M5 Admin & Community Insights ─────────────────────

class AuditEntry {
  AuditEntry(this.actorId, this.action, this.at);

  final String actorId;
  final String action;
  final DateTime at;
}

/// A reference dataset with its source and collection date.
class ReferenceData {
  const ReferenceData({
    required this.name,
    required this.value,
    required this.source,
    required this.collected,
  });

  final String name;
  final String value;
  final String source;
  final DateTime collected;
}

class AppNotification {
  AppNotification({
    required this.userId,
    required this.title,
    required this.body,
    required this.at,
    this.read = false,
  });

  /// Recipient, or null for everyone.
  final String? userId;
  final String title;
  final String body;
  final DateTime at;
  bool read;
}

// ───────────────────────────── EV news (Home) ─────────────────────────────

/// An EV news item collected from a publisher's RSS feed.
///
/// Only what the feed itself provides is kept: headline, summary, image link
/// and the link to the original. The full article stays on the publisher's
/// site and opens there.
class NewsArticle {
  const NewsArticle({
    required this.id,
    required this.title,
    required this.summary,
    required this.source,
    required this.publishedAt,
    this.url,
    this.imageUrl,
    this.philippines = true,
    this.isSample = false,
  });

  final String id;
  final String title;
  final String summary;
  final String source;
  final DateTime publishedAt;

  /// Link to the original article. Null for bundled sample items.
  final String? url;
  final String? imageUrl;

  /// True for Philippine coverage, false for world EV news.
  final bool philippines;

  /// True for the placeholder items shown when no backend is connected.
  final bool isSample;
}

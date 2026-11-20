import 'models.dart';

/// Sample data for development and demonstrations.
///
/// Everything here is a placeholder. Station, provider and vehicle records
/// stand in for the reference data the proposal sources from the DOE EVCS
/// Locator, Open Charge Map, brand service networks and published vehicle
/// specifications. Names and figures are illustrative, not collected data.
class SeedData {
  SeedData(this.now) {
    _build();
  }

  final DateTime now;

  static const topics = [
    'Charging',
    'Maintenance',
    'Vehicle use',
    'Ownership',
    'Events',
  ];

  static const concernCategories = [
    'Charging stations',
    'Service centers',
    'Parts and pricing',
    'Roads and parking',
    'Other',
  ];

  static const stationTags = [
    'Fast charging',
    'Short wait',
    'Long wait',
    'Safe parking',
    'Charger offline',
    'Good amenities',
  ];

  static const providerTags = [
    'Knowledgeable',
    'Fair price',
    'Fast turnaround',
    'Parts available',
    'Long wait',
  ];

  /// Demo driver location: Poblacion, Makati.
  static const userPlace = Place('Poblacion, Makati', 14.5650, 121.0300);

  static const _dc = [ConnectorType.ccs2, ConnectorType.type2];

  static const vehicles = [
    Vehicle(
      brand: 'BYD',
      model: 'Atto 3',
      type: VehicleType.bev,
      connectors: _dc,
      batteryKwh: 60.5,
      kwhPerKm: 0.156,
    ),
    Vehicle(
      brand: 'BYD',
      model: 'Dolphin',
      type: VehicleType.bev,
      connectors: _dc,
      batteryKwh: 44.9,
      kwhPerKm: 0.140,
    ),
    Vehicle(
      brand: 'BYD',
      model: 'Sealion 6 DM-i',
      type: VehicleType.phev,
      connectors: [ConnectorType.type2],
      batteryKwh: 18.3,
      kwhPerKm: 0.190,
    ),
    Vehicle(
      brand: 'Tesla',
      model: 'Model 3',
      type: VehicleType.bev,
      connectors: _dc,
      batteryKwh: 60,
      kwhPerKm: 0.140,
    ),
    Vehicle(
      brand: 'Nissan',
      model: 'Leaf',
      type: VehicleType.bev,
      connectors: [ConnectorType.chademo, ConnectorType.type2],
      batteryKwh: 40,
      kwhPerKm: 0.160,
    ),
    Vehicle(
      brand: 'VinFast',
      model: 'VF 5',
      type: VehicleType.bev,
      connectors: _dc,
      batteryKwh: 37.2,
      kwhPerKm: 0.135,
    ),
    Vehicle(
      brand: 'Kia',
      model: 'EV6',
      type: VehicleType.bev,
      connectors: _dc,
      batteryKwh: 77.4,
      kwhPerKm: 0.170,
    ),
  ];

  static const places = [
    Place('Makati CBD', 14.5547, 121.0244),
    Place('Bonifacio Global City, Taguig', 14.5507, 121.0509),
    Place('Quezon Memorial Circle', 14.6515, 121.0493),
    Place('Bay Area, Pasay', 14.5352, 120.9822),
    Place('Alabang, Muntinlupa', 14.4237, 121.0297),
    Place('Antipolo, Rizal', 14.5860, 121.1761),
    Place('Sta. Rosa, Laguna', 14.2370, 121.0580),
    Place('Calamba, Laguna', 14.2117, 121.1653),
    Place('Tagaytay, Cavite', 14.1153, 120.9621),
    Place('Lipa, Batangas', 13.9411, 121.1631),
    Place('Batangas City', 13.7565, 121.0583),
    Place('Lucena, Quezon', 13.9373, 121.6170),
  ];

  late final List<AppUser> users;
  late final List<Community> communities;
  late final List<Announcement> announcements;
  late final List<Discussion> discussions;
  late final List<Review> reviews;
  late final List<Proposal> proposals;
  late final List<Concern> concerns;
  late final List<PositionSummary> summaries;
  late final List<ContentReport> reports;
  late final List<CommunityEvent> events;
  late final List<Station> stations;
  late final List<ServiceProvider> providers;
  late final List<AuditEntry> audit;
  late final List<ReferenceData> referenceData;
  late final List<AppNotification> notifications;
  late final List<NewsArticle> news;

  /// Accounts offered on the demo sign-in screen, one per role.
  static const demoAccountIds = ['u1', 'u2', 'u6', 'u7', 'u8'];

  DateTime _ago({int d = 0, int h = 0, int m = 0}) =>
      now.subtract(Duration(days: d, hours: h, minutes: m));

  DateTime _in({int d = 0, int h = 0}) {
    final t = now.add(Duration(days: d));
    return DateTime(t.year, t.month, t.day, h);
  }

  void _build() {
    const v = vehicles;
    users = [
      AppUser(
        id: 'u1',
        name: 'Mika Santos',
        role: PlatformRole.member,
        region: 'Makati, Metro Manila',
        vehicle: v[0],
        verification: VerificationStatus.verified,
      ),
      AppUser(
        id: 'u2',
        name: 'Rafael Cruz',
        role: PlatformRole.member,
        region: 'Taguig, Metro Manila',
        vehicle: v[3],
        verification: VerificationStatus.verified,
      ),
      AppUser(
        id: 'u3',
        name: 'Liza Reyes',
        role: PlatformRole.member,
        region: 'Imus, Cavite',
        vehicle: v[0],
        verification: VerificationStatus.verified,
      ),
      AppUser(
        id: 'u4',
        name: 'Jun Dela Cruz',
        role: PlatformRole.member,
        region: 'Pasig, Metro Manila',
        vehicle: v[2],
        verification: VerificationStatus.verified,
      ),
      AppUser(
        id: 'u5',
        name: 'Carla Lim',
        role: PlatformRole.member,
        region: 'Quezon City, Metro Manila',
        vehicle: v[4],
        verification: VerificationStatus.pending,
      ),
      AppUser(
        id: 'u6',
        name: 'Paolo Garcia',
        role: PlatformRole.guest,
        region: 'Sta. Rosa, Laguna',
      ),
      AppUser(
        id: 'u7',
        name: 'Ana Mendoza',
        role: PlatformRole.provider,
        region: 'Makati, Metro Manila',
      ),
      AppUser(
        id: 'u8',
        name: 'EVYAHE Admin',
        role: PlatformRole.admin,
        region: 'Research team',
      ),
      AppUser(
        id: 'u9',
        name: 'Ben Tan',
        role: PlatformRole.member,
        region: 'Manila, Metro Manila',
        vehicle: v[1],
      ),
      AppUser(
        id: 'u10',
        name: 'Trish Uy',
        role: PlatformRole.member,
        region: 'Calamba, Laguna',
        vehicle: v[6],
        verification: VerificationStatus.verified,
      ),
      AppUser(
        id: 'u11',
        name: 'Marco Villanueva',
        role: PlatformRole.member,
        region: 'Sta. Rosa, Laguna',
        vehicle: v[1],
        verification: VerificationStatus.pending,
      ),
      AppUser(
        id: 'u12',
        name: 'Ella Ramos',
        role: PlatformRole.member,
        region: 'Bacoor, Cavite',
        vehicle: v[5],
      ),
    ];

    communities = [
      Community(
        id: 'c1',
        name: 'Metro EV Owners Circle',
        type: CommunityType.region,
        description: 'A cross-brand community for EV owners around Metro Manila. Share charging tips, join weekend runs and raise concerns together.',
        rules: '1. Be respectful.\n2. No selling outside the service directory.\n3. Share station reports with the date and time.\n4. Follow charging etiquette: move your car when charging is done.',
        joinPolicy: JoinPolicy.open,
        criteriaRegion: 'Metro Manila',
        createdAt: _ago(d: 240),
        members: {
          'u2': GroupRole.leader,
          'u4': GroupRole.officer,
          'u1': GroupRole.member,
          'u5': GroupRole.member,
          'u9': GroupRole.member,
          'u10': GroupRole.member,
          'u11': GroupRole.member,
        },
      ),
      Community(
        id: 'c2',
        name: 'Atto 3 Drivers PH',
        type: CommunityType.model,
        description: 'For BYD Atto 3 owners. Model-specific questions, accessories and owner meetups.',
        rules: '1. Atto 3 owners only; ownership is verified.\n2. Keep discussions about the model.\n3. Officers moderate posts.',
        joinPolicy: JoinPolicy.approval,
        requiresVerification: true,
        criteriaModel: 'BYD Atto 3',
        membersCanPropose: false,
        createdAt: _ago(d: 180),
        members: {'u3': GroupRole.leader, 'u1': GroupRole.member},
        joinRequests: ['u9'],
      ),
      Community(
        id: 'c3',
        name: 'South Luzon EV Riders',
        type: CommunityType.region,
        description: 'EV owners in Laguna, Cavite and Batangas. Long drives, charging stops and service tips in the south.',
        rules: '1. Open to all EV owners in CALABARZON.\n2. Post trip plans at least three days ahead.\n3. Report charger problems on the concern board.',
        joinPolicy: JoinPolicy.open,
        criteriaRegion: 'CALABARZON',
        createdAt: _ago(d: 120),
        members: {
          'u10': GroupRole.leader,
          'u11': GroupRole.member,
          'u12': GroupRole.member,
          'u4': GroupRole.member,
        },
      ),
      Community(
        id: 'c4',
        name: 'Dolphin Club Laguna',
        type: CommunityType.model,
        description: 'A new club for BYD Dolphin owners in Laguna.',
        rules: 'Rules to follow once the club is approved.',
        joinPolicy: JoinPolicy.approval,
        criteriaModel: 'BYD Dolphin',
        criteriaRegion: 'Laguna',
        status: ApprovalStatus.pending,
        createdAt: _ago(d: 1),
        members: {'u11': GroupRole.leader},
      ),
      // Tribes
      Community(
        id: 't1',
        parentId: 'c1',
        name: 'Weekend Convoy Tribe',
        type: CommunityType.interest,
        description:
            'Members of the Circle who join weekend runs out of the metro.',
        rules: 'RSVP with your vehicle and battery level so routes can be checked.',
        joinPolicy: JoinPolicy.open,
        createdAt: _ago(d: 90),
        members: {
          'u2': GroupRole.leader,
          'u1': GroupRole.member,
          'u4': GroupRole.member,
          'u9': GroupRole.member,
        },
      ),
      Community(
        id: 't2',
        parentId: 'c1',
        name: 'PHEV Owners Tribe',
        type: CommunityType.interest,
        description:
            'Plug-in hybrid owners sharing electric-share and fuel tips.',
        rules: 'Share real-world figures with dates.',
        joinPolicy: JoinPolicy.open,
        createdAt: _ago(d: 60),
        members: {'u4': GroupRole.leader},
      ),
      Community(
        id: 't3',
        parentId: 'c2',
        name: 'Atto 3 Cavite Tribe',
        type: CommunityType.region,
        description: 'Atto 3 owners based in Cavite.',
        rules: 'Same rules as Atto 3 Drivers PH.',
        joinPolicy: JoinPolicy.approval,
        requiresVerification: true,
        criteriaRegion: 'Cavite',
        createdAt: _ago(d: 45),
        members: {'u3': GroupRole.leader},
      ),
    ];

    announcements = [
      Announcement(
        id: 'a1',
        communityId: 'c1',
        authorId: 'u2',
        title: 'Tagaytay run: RSVP with your battery level',
        body: 'Our next weekend run is to Tagaytay. Please RSVP with the vehicle you will bring and your expected starting battery level so the officers can check the route and the charging stop.',
        createdAt: _ago(h: 5),
        pinned: true,
      ),
      Announcement(
        id: 'a2',
        communityId: 'c1',
        authorId: 'u4',
        title: 'Vote on the charging etiquette rule',
        body: 'The proposal on a 15-minute grace period after charging is open for voting until the deadline shown in Polls.',
        createdAt: _ago(d: 1, h: 2),
      ),
      Announcement(
        id: 'a3',
        communityId: 'c2',
        authorId: 'u3',
        title: 'Welcome new members',
        body: 'Please read the rules in the About tab and introduce yourself in the discussions.',
        createdAt: _ago(d: 3),
        pinned: true,
      ),
      Announcement(
        id: 'a4',
        communityId: 'c3',
        authorId: 'u10',
        title: 'Batangas coastal drive next month',
        body: 'Details are in Events. The route has one planned charging stop in Lipa.',
        createdAt: _ago(d: 2),
        pinned: true,
      ),
    ];

    discussions = [
      Discussion(
        id: 'd1',
        communityId: 'c1',
        authorId: 'u1',
        title: 'Which chargers along SLEX are reliable on weekends?',
        body: 'Planning to go south on Saturday morning. Which stations have you used recently that were working, and how long was the wait?',
        topic: 'Charging',
        isQuestion: true,
        createdAt: _ago(h: 8),
        helpful: {'u2', 'u4', 'u9'},
        replies: [
          Reply(
            id: 'r1',
            authorId: 'u10',
            body: 'The Calamba stop was working last Sunday, two cars waiting around 10 AM. Check the station page for the latest report before you leave.',
            createdAt: _ago(h: 6),
            helpful: {'u1', 'u2'},
          ),
          Reply(
            id: 'r2',
            authorId: 'u4',
            body: 'Sta. Rosa has the faster charger. I check in on the app when I arrive so others can see the queue.',
            createdAt: _ago(h: 3),
            helpful: {'u1'},
          ),
        ],
      ),
      Discussion(
        id: 'd2',
        communityId: 'c1',
        authorId: 'u9',
        title: 'Home charging on a 40 A breaker',
        body: 'Sharing my setup after three months: a 7 kW wall charger on a dedicated line. Happy to answer questions on installation cost and permits.',
        topic: 'Ownership',
        vehicleModel: 'BYD Dolphin',
        createdAt: _ago(d: 2),
        helpful: {'u1', 'u5'},
        replies: [
          Reply(
            id: 'r3',
            authorId: 'u5',
            body: 'Did your electrician need to upgrade the service entrance?',
            createdAt: _ago(d: 1, h: 20),
          ),
        ],
      ),
      Discussion(
        id: 'd3',
        communityId: 'c2',
        authorId: 'u3',
        title: 'Tire pressure after the first PMS',
        body: 'What pressure are you running after your first service? Mine came back higher than the door sticker.',
        topic: 'Maintenance',
        vehicleModel: 'BYD Atto 3',
        isQuestion: true,
        createdAt: _ago(d: 4),
        helpful: {'u1'},
      ),
      Discussion(
        id: 'd4',
        communityId: 'c3',
        authorId: 'u12',
        title: 'Lipa charger was offline on Friday',
        body: 'Went there at 6 PM and the unit showed an error. I filed a status report and a concern on the board.',
        topic: 'Charging',
        createdAt: _ago(d: 2, h: 4),
        helpful: {'u10', 'u11'},
      ),
      Discussion(
        id: 'd5',
        communityId: 't1',
        authorId: 'u2',
        title: 'Convoy spacing and radio channel',
        body: 'For the Tagaytay run we will keep to the right lane and use channel 5. Lead car leaves at exactly the start time.',
        topic: 'Events',
        createdAt: _ago(d: 1),
      ),
    ];

    stations = [
      _station(
        's1',
        'Makati CBD Charging Hub',
        'Metro Charge',
        'Ayala Avenue, Makati',
        'Makati',
        14.5547,
        121.0244,
        const [
          StationConnector(ConnectorType.ccs2, 60),
          StationConnector(ConnectorType.type2, 22),
        ],
        '₱28 per kWh',
        '24 hours',
        'Paid mall parking; four EV-only bays',
        reports: [
          StatusReport(
            userId: 'u2',
            working: true,
            createdAt: _ago(h: 2),
            note: 'Both units working.',
          ),
        ],
        checkIns: [
          CheckIn(userId: 'u9', charging: true, createdAt: _ago(m: 35)),
        ],
      ),
      _station(
        's2',
        'BGC High Street Chargers',
        'Volt Avenue',
        '9th Avenue, Bonifacio Global City',
        'Taguig',
        14.5507,
        121.0509,
        const [
          StationConnector(ConnectorType.ccs2, 120),
          StationConnector(ConnectorType.type2, 7),
        ],
        '₱32 per kWh',
        '6 AM to 12 MN',
        'Basement parking; two EV-only bays',
        reports: [
          StatusReport(userId: 'u4', working: true, createdAt: _ago(h: 5)),
        ],
        checkIns: [
          CheckIn(userId: 'u4', charging: true, createdAt: _ago(m: 50)),
          CheckIn(userId: 'u5', charging: false, createdAt: _ago(m: 20)),
          CheckIn(userId: 'u11', charging: false, createdAt: _ago(m: 10)),
        ],
      ),
      _station(
        's3',
        'Bay Area Fast Charge',
        'Metro Charge',
        'Seaside Boulevard, Pasay',
        'Pasay',
        14.5352,
        120.9822,
        const [
          StationConnector(ConnectorType.ccs2, 60),
          StationConnector(ConnectorType.chademo, 50),
        ],
        '₱30 per kWh',
        '10 AM to 10 PM',
        'Open parking; fees apply after three hours',
        reports: [
          StatusReport(
            userId: 'u9',
            working: false,
            createdAt: _ago(h: 3),
            note: 'CCS2 unit shows a fault. CHAdeMO still works.',
          ),
        ],
      ),
      _station(
        's4',
        'Quezon City Triangle Chargers',
        'North Grid EV',
        'Triangle Park, Quezon City',
        'Quezon City',
        14.6445,
        121.0370,
        const [
          StationConnector(ConnectorType.type2, 22),
          StationConnector(ConnectorType.gbt, 60),
        ],
        '₱25 per kWh',
        '8 AM to 10 PM',
        'Free parking for the first two hours',
        reports: [
          StatusReport(userId: 'u5', working: true, createdAt: _ago(d: 2)),
        ],
      ),
      _station(
        's5',
        'Ortigas Center Charging Point',
        'Volt Avenue',
        'Emerald Avenue, Pasig',
        'Pasig',
        14.5873,
        121.0615,
        const [
          StationConnector(ConnectorType.ccs2, 50),
          StationConnector(ConnectorType.type2, 11),
        ],
        '₱29 per kWh',
        '24 hours',
        'Building parking; rates not published',
        reports: [
          StatusReport(userId: 'u4', working: true, createdAt: _ago(h: 20)),
        ],
      ),
      _station(
        's6',
        'Alabang Town Charging Point',
        'South Grid EV',
        'Commerce Avenue, Alabang',
        'Muntinlupa',
        14.4237,
        121.0297,
        const [
          StationConnector(ConnectorType.ccs2, 60),
          StationConnector(ConnectorType.type2, 22),
        ],
        '₱27 per kWh',
        '10 AM to 9 PM',
        'Mall parking; three EV-only bays',
        reports: [
          StatusReport(userId: 'u10', working: true, createdAt: _ago(h: 9)),
        ],
      ),
      _station(
        's7',
        'Sta. Rosa Greenfield Chargers',
        'South Grid EV',
        'Greenfield Parkway, Sta. Rosa',
        'Sta. Rosa',
        14.2443,
        121.0570,
        const [StationConnector(ConnectorType.ccs2, 120)],
        '₱33 per kWh',
        '24 hours',
        'Open parking, no fee',
        reports: [
          StatusReport(userId: 'u11', working: true, createdAt: _ago(h: 4)),
        ],
        checkIns: [
          CheckIn(userId: 'u11', charging: false, createdAt: _ago(m: 15)),
        ],
      ),
      _station(
        's8',
        'Calamba Expressway Stop Charger',
        'Expressway Charge',
        'SLEX southbound service area, Calamba',
        'Calamba',
        14.2117,
        121.1340,
        const [
          StationConnector(ConnectorType.ccs2, 60),
          StationConnector(ConnectorType.chademo, 50),
        ],
        '₱35 per kWh',
        '24 hours',
        'Service area parking, no fee',
        reports: [
          StatusReport(
            userId: 'u10',
            working: true,
            createdAt: _ago(d: 1, h: 6),
          ),
        ],
      ),
      _station(
        's9',
        'Tagaytay Ridge Charging Stop',
        'Ridge Power',
        'Aguinaldo Highway, Tagaytay',
        'Tagaytay',
        14.1153,
        120.9621,
        const [
          StationConnector(ConnectorType.ccs2, 50),
          StationConnector(ConnectorType.type2, 22),
        ],
        '₱30 per kWh',
        '7 AM to 9 PM',
        'Restaurant parking for customers',
      ),
      _station(
        's10',
        'Lipa City Charging Point',
        'South Grid EV',
        'JP Laurel Highway, Lipa',
        'Lipa',
        13.9411,
        121.1631,
        const [StationConnector(ConnectorType.ccs2, 60)],
        '₱31 per kWh',
        '8 AM to 8 PM',
        'Open parking, no fee',
        reports: [
          StatusReport(
            userId: 'u12',
            working: false,
            createdAt: _ago(d: 2, h: 4),
            note: 'Unit showed an error at 6 PM.',
          ),
        ],
      ),
      _station(
        's11',
        'Batangas City Charging Hub',
        'South Grid EV',
        'P. Burgos Street, Batangas City',
        'Batangas City',
        13.7565,
        121.0583,
        const [
          StationConnector(ConnectorType.ccs2, 60),
          StationConnector(ConnectorType.type2, 22),
        ],
        '₱31 per kWh',
        '8 AM to 9 PM',
        'Paid parking',
      ),
      _station(
        's12',
        'Antipolo Hilltop Charger',
        'North Grid EV',
        'Sumulong Highway, Antipolo',
        'Antipolo',
        14.5860,
        121.1761,
        const [StationConnector(ConnectorType.type2, 7)],
        'Free for customers',
        '9 AM to 9 PM',
        'Customer parking only',
      ),
      _station(
        's13',
        'Imus Fast Charge',
        'Expressway Charge',
        'Aguinaldo Highway, Imus',
        'Imus',
        14.4297,
        120.9367,
        const [
          StationConnector(ConnectorType.ccs2, 60),
          StationConnector(ConnectorType.gbt, 60),
        ],
        '₱30 per kWh',
        '24 hours',
        'Open parking, no fee',
        reports: [
          StatusReport(userId: 'u3', working: true, createdAt: _ago(h: 11)),
        ],
      ),
    ];

    providers = [
      ServiceProvider(
        id: 'p1',
        ownerId: 'u7',
        name: 'Voltworks EV Service Center',
        category: ProviderCategory.service,
        description: 'Independent EV service center for preventive maintenance and diagnostics.',
        brands: ['BYD', 'Tesla', 'Nissan', 'Kia'],
        services: [
          'Preventive maintenance',
          'Battery health diagnostics',
          'Sensor calibration',
          'Brake service',
        ],
        address: 'Chino Roces Avenue, Makati',
        city: 'Makati',
        lat: 14.5440,
        lng: 121.0160,
        contact: '(02) 8555 0142',
        recommendedBy: {'t1'},
      ),
      ServiceProvider(
        id: 'p2',
        ownerId: 'u7',
        name: 'Voltworks Mobile Service',
        category: ProviderCategory.service,
        description:
            'On-site inspection and minor repairs within Metro Manila.',
        brands: ['BYD', 'Tesla'],
        services: ['On-site inspection', '12 V battery replacement'],
        address: 'Chino Roces Avenue, Makati',
        city: 'Makati',
        lat: 14.5440,
        lng: 121.0160,
        contact: '(02) 8555 0143',
        status: ApprovalStatus.pending,
      ),
      ServiceProvider(
        id: 'p3',
        ownerId: 'x1',
        name: 'GreenTorque Tires and Alignment',
        category: ProviderCategory.tires,
        description: 'EV-rated tires, alignment and balancing.',
        brands: ['All brands'],
        services: ['EV-rated tires', 'Wheel alignment', 'Balancing'],
        address: 'Quezon Avenue, Quezon City',
        city: 'Quezon City',
        lat: 14.6360,
        lng: 121.0200,
        contact: '(02) 8555 0178',
      ),
      ServiceProvider(
        id: 'p4',
        ownerId: 'x2',
        name: 'South Charge Parts and Accessories',
        category: ProviderCategory.parts,
        description:
            'Portable chargers, adapters, cabin filters and accessories.',
        brands: ['BYD', 'VinFast', 'Nissan'],
        services: [
          'Portable chargers',
          'Adapters',
          'Cabin filters',
          'Floor mats',
        ],
        address: 'Balibago Road, Sta. Rosa',
        city: 'Sta. Rosa',
        lat: 14.2900,
        lng: 121.1050,
        contact: '(049) 555 0120',
        recommendedBy: {'t3'},
      ),
      ServiceProvider(
        id: 'p5',
        ownerId: 'x3',
        name: 'Alabang Authorized EV Service',
        category: ProviderCategory.dealership,
        description: 'Dealership service department for authorized maintenance and warranty work.',
        brands: ['BYD'],
        services: [
          'Authorized maintenance',
          'Warranty repairs',
          'Software checks',
        ],
        address: 'Alabang–Zapote Road, Muntinlupa',
        city: 'Muntinlupa',
        lat: 14.4300,
        lng: 121.0200,
        contact: '(02) 8555 0190',
      ),
    ];

    reviews = [
      Review(
        id: 'v1',
        target: ReviewTarget.station,
        targetId: 's1',
        authorId: 'u2',
        rating: 5,
        tags: ['Fast charging', 'Safe parking'],
        body: 'Reliable and well lit. Charged from 30% to 80% in about 35 minutes.',
        createdAt: _ago(d: 3),
        helpful: {'u1', 'u4'},
      ),
      Review(
        id: 'v2',
        target: ReviewTarget.station,
        targetId: 's2',
        authorId: 'u4',
        rating: 3,
        tags: ['Long wait'],
        body: 'Fast charger but there is usually a queue after office hours.',
        createdAt: _ago(d: 5),
        helpful: {'u9'},
      ),
      Review(
        id: 'v3',
        target: ReviewTarget.station,
        targetId: 's3',
        authorId: 'u9',
        rating: 2,
        tags: ['Charger offline'],
        body: 'The CCS2 unit has been down twice this month.',
        createdAt: _ago(d: 1),
        helpful: {'u1', 'u2', 'u5'},
      ),
      Review(
        id: 'v4',
        target: ReviewTarget.provider,
        targetId: 'p1',
        authorId: 'u1',
        rating: 5,
        tags: ['Knowledgeable', 'Fair price'],
        body: 'Explained the battery health report clearly and did not push extra work.',
        createdAt: _ago(d: 6),
        helpful: {'u2'},
      ),
      Review(
        id: 'v5',
        target: ReviewTarget.provider,
        targetId: 'p1',
        authorId: 'u4',
        rating: 4,
        tags: ['Fast turnaround'],
        body: 'PMS done in half a day. Booking by phone only.',
        createdAt: _ago(d: 12),
      ),
      Review(
        id: 'v6',
        target: ReviewTarget.provider,
        targetId: 'p4',
        authorId: 'u12',
        rating: 4,
        tags: ['Parts available'],
        body: 'Had the adapter in stock when others did not.',
        createdAt: _ago(d: 9),
      ),
    ];

    proposals = [
      Proposal(
        id: 'pr1',
        communityId: 'c1',
        authorId: 'u4',
        title: 'Grace period before a charging-etiquette warning',
        description: 'How long should a member be allowed to stay plugged in after charging ends before officers issue a reminder?',
        options: ['No grace period', '15 minutes', '30 minutes'],
        ranked: false,
        deadline: _in(d: 4, h: 20),
        quorum: 5,
        createdAt: _ago(d: 2),
        votes: {
          'u2': [1],
          'u4': [1],
          'u9': [2],
          'u10': [1],
        },
      ),
      Proposal(
        id: 'pr2',
        communityId: 'c1',
        authorId: 'u2',
        title: 'Destination for the December run',
        description: 'Rank the destinations in order of preference. The result is counted by instant runoff.',
        options: ['Tagaytay', 'Batangas City', 'Antipolo'],
        ranked: true,
        deadline: _in(d: 9, h: 18),
        quorum: 4,
        createdAt: _ago(d: 1),
        votes: {
          'u2': [0, 2, 1],
          'u9': [1, 0, 2],
          'u5': [2, 0, 1],
        },
      ),
      Proposal(
        id: 'pr3',
        communityId: 'c1',
        authorId: 'u2',
        title: 'Allow service providers to be endorsed by tribes',
        description: 'Should tribes be able to mark providers in the directory as recommended?',
        options: ['Yes', 'No'],
        ranked: false,
        deadline: _ago(d: 10),
        quorum: 4,
        createdAt: _ago(d: 20),
        votes: {
          'u2': [0],
          'u4': [0],
          'u1': [0],
          'u9': [1],
          'u10': [0],
        },
        closed: true,
        outcome: 'Approved, 4 to 1. Tribe leaders may now mark providers as recommended.',
      ),
      Proposal(
        id: 'pr4',
        communityId: 'c3',
        authorId: 'u10',
        title: 'Monthly drive schedule',
        description: 'Which weekend works best for the monthly drive?',
        options: ['First Saturday', 'Second Sunday', 'Last Saturday'],
        ranked: false,
        deadline: _in(d: 6, h: 20),
        quorum: 3,
        createdAt: _ago(d: 1),
        votes: {
          'u10': [0],
          'u12': [2],
        },
      ),
    ];

    concerns = [
      Concern(
        id: 'k1',
        communityId: 'c1',
        authorId: 'u9',
        category: 'Charging stations',
        title: 'CCS2 unit at Bay Area keeps going offline',
        details: 'The unit has shown a fault on three visits this month. No notice is posted and the operator hotline does not answer.',
        location: 'Pasay',
        stationId: 's3',
        hasPhoto: true,
        createdAt: _ago(d: 6),
        supporters: {'u1', 'u2', 'u4', 'u5'},
      ),
      Concern(
        id: 'k2',
        communityId: 'c1',
        authorId: 'u5',
        category: 'Charging stations',
        title: 'Non-charging cars parked in EV bays',
        details: 'EV-only bays at BGC are often taken by cars that are not charging, especially after 6 PM.',
        location: 'Taguig',
        stationId: 's2',
        hasPhoto: true,
        createdAt: _ago(d: 4),
        supporters: {'u2', 'u4', 'u9'},
      ),
      Concern(
        id: 'k3',
        communityId: 'c1',
        authorId: 'u1',
        category: 'Service centers',
        title: 'Long wait for PMS slots',
        details: 'Earliest dealership slot offered was five weeks away.',
        location: 'Makati',
        createdAt: _ago(d: 8),
        supporters: {'u9'},
      ),
      Concern(
        id: 'k4',
        communityId: 'c1',
        authorId: 'u4',
        category: 'Charging stations',
        title: 'Published fee differs from the amount charged',
        details: 'The posted rate was lower than what the app billed.',
        location: 'Pasig',
        stationId: 's5',
        createdAt: _ago(d: 2),
        supporters: {'u1', 'u2'},
      ),
      Concern(
        id: 'k5',
        communityId: 'c3',
        authorId: 'u12',
        category: 'Charging stations',
        title: 'Lipa charger offline with no notice',
        details: 'Unit showed an error on Friday evening. It is the only fast charger on the route.',
        location: 'Lipa',
        stationId: 's10',
        hasPhoto: true,
        createdAt: _ago(d: 2),
        supporters: {'u10', 'u11'},
      ),
    ];

    summaries = [
      PositionSummary(
        id: 'ps1',
        communityId: 'c1',
        authorId: 'u2',
        title: 'Charger reliability in Metro Manila, October',
        category: 'Charging stations',
        text: 'Position of Metro EV Owners Circle on charger reliability.\n\nMembers filed 2 concerns supported by 9 members. Affected locations: Pasay (1), Taguig (1). We ask operators to post outage notices at the unit and in their apps, and to enforce EV-only bays.',
        concernCount: 2,
        supportCount: 9,
        createdAt: _ago(d: 25),
      ),
    ];

    reports = [
      ContentReport(
        id: 'rp1',
        reporterId: 'u1',
        contentType: 'reply',
        contentId: 'r3',
        contentTitle: 'Reply by Carla Lim in "Home charging on a 40 A breaker"',
        reason: 'Off-topic',
        communityId: 'c1',
        createdAt: _ago(h: 10),
      ),
      ContentReport(
        id: 'rp2',
        reporterId: 'u9',
        contentType: 'review',
        contentId: 'v2',
        contentTitle: 'Review of BGC High Street Chargers by Jun Dela Cruz',
        reason: 'Inaccurate information',
        createdAt: _ago(d: 1),
        status: ReportStatus.escalated,
      ),
    ];

    events = [
      CommunityEvent(
        id: 'e1',
        communityId: 't1',
        creatorId: 'u2',
        title: 'Tagaytay Weekend Run',
        type: EventType.convoy,
        description: 'Easy-paced convoy to Tagaytay with a breakfast stop. Bring your charging cable.',
        start: _in(d: 5, h: 6),
        origin: places[1],
        venue: places[8],
        capacity: 15,
        visibility: EventVisibility.community,
        stopStationId: 's7',
        rsvps: [
          Rsvp(userId: 'u2', vehicle: v[3], startBatteryPct: 90),
          Rsvp(userId: 'u4', vehicle: v[2], startBatteryPct: 100),
          Rsvp(userId: 'u9', vehicle: v[1], startBatteryPct: 12),
        ],
      ),
      CommunityEvent(
        id: 'e2',
        communityId: 'c1',
        creatorId: 'u4',
        title: 'Charging Etiquette Meetup',
        type: EventType.meetup,
        description: 'Coffee and a short talk on sharing chargers. Open to anyone curious about EVs.',
        start: _in(d: 2, h: 16),
        venue: places[0],
        capacity: 40,
        visibility: EventVisibility.public,
        rsvps: [
          Rsvp(userId: 'u4', vehicle: v[2], startBatteryPct: 80),
          Rsvp(userId: 'u5', vehicle: v[4], startBatteryPct: 70),
        ],
      ),
      CommunityEvent(
        id: 'e3',
        communityId: 'c3',
        creatorId: 'u10',
        title: 'Batangas Coastal Drive',
        type: EventType.drive,
        description: 'A longer drive from Sta. Rosa to Batangas City. One planned charging stop.',
        start: _in(d: 19, h: 7),
        origin: places[6],
        venue: places[10],
        capacity: 12,
        visibility: EventVisibility.community,
        stopStationId: 's10',
        rsvps: [
          Rsvp(userId: 'u10', vehicle: v[6], startBatteryPct: 95),
          Rsvp(userId: 'u12', vehicle: v[5], startBatteryPct: 60),
        ],
      ),
      CommunityEvent(
        id: 'e4',
        communityId: 'c2',
        creatorId: 'u3',
        title: 'Atto 3 Owners Outreach',
        type: EventType.outreach,
        description:
            'School supplies drive with a short display of members\' cars.',
        start: _in(d: 12, h: 9),
        venue: places[4],
        capacity: 25,
        visibility: EventVisibility.community,
        rsvps: [Rsvp(userId: 'u3', vehicle: v[0], startBatteryPct: 85)],
      ),
    ];

    audit = [
      AuditEntry(
        'u8',
        'Approved community "South Luzon EV Riders"',
        _ago(d: 120),
      ),
      AuditEntry(
        'u8',
        'Verified provider "Voltworks EV Service Center"',
        _ago(d: 40),
      ),
      AuditEntry(
        'u8',
        'Verified owner Trish Uy and deleted the submitted document',
        _ago(d: 14),
      ),
      AuditEntry(
        'u8',
        'Updated reference data "Household electricity rate"',
        _ago(d: 7),
      ),
    ];

    referenceData = [
      ReferenceData(
        name: 'Charging station list',
        value: '${stations.length} sample stations',
        source: 'Sample data (to be replaced by DOE EVCS Locator and Open Charge Map)',
        collected: _ago(d: 20),
      ),
      ReferenceData(
        name: 'Household electricity rate',
        value: '₱15.55 per kWh',
        source: 'Sample default (Meralco published rate; users can enter their own)',
        collected: _ago(d: 7),
      ),
      ReferenceData(
        name: 'Public charging rate',
        value: '₱35.00 per kWh',
        source: 'Sample default (operators\' published rates)',
        collected: _ago(d: 20),
      ),
      ReferenceData(
        name: 'Gasoline pump price',
        value: '₱60.00 per liter',
        source: 'Sample default (DOE retail pump prices; users can enter their own)',
        collected: _ago(d: 7),
      ),
      ReferenceData(
        name: 'Vehicle specifications',
        value: '${vehicles.length} sample models',
        source: 'Sample data (manufacturers\' published specifications)',
        collected: _ago(d: 30),
      ),
      ReferenceData(
        name: 'Service provider seed list',
        value: '${providers.length} sample listings',
        source: 'Sample data (brand service networks, NCR and CALABARZON)',
        collected: _ago(d: 30),
      ),
    ];

    // Placeholders for the news feed. Real items come from the daily RSS
    // collection in Supabase; these only show the layout without a backend.
    news = [
      NewsArticle(
        id: 'n1',
        isSample: true,
        source: 'Sample source',
        publishedAt: _ago(h: 3),
        title:
            'Sample headline: new fast chargers open along a major expressway',
        summary: 'This is a placeholder article. With the backend connected, this feed shows real electric vehicle news from Philippine publishers, refreshed every day.',
      ),
      NewsArticle(
        id: 'n2',
        isSample: true,
        source: 'Sample source',
        publishedAt: _ago(h: 9),
        title: 'Sample headline: government updates incentives for electric vehicle buyers',
        summary: 'Placeholder summary. Each real item carries the publisher\'s own headline, summary, image and a link to read the full story on their site.',
      ),
      NewsArticle(
        id: 'n3',
        isSample: true,
        source: 'Sample source',
        publishedAt: _ago(d: 1, h: 2),
        title: 'Sample headline: owner clubs hold a weekend convoy to promote EV travel',
        summary: 'Placeholder summary for a community story.',
      ),
      NewsArticle(
        id: 'n4',
        isSample: true,
        source: 'Sample source',
        publishedAt: _ago(d: 1, h: 8),
        title: 'Sample headline: a new electric crossover arrives in local showrooms',
        summary: 'Placeholder summary for a product story.',
      ),
      NewsArticle(
        id: 'n5',
        isSample: true,
        philippines: false,
        source: 'Sample source',
        publishedAt: _ago(d: 2),
        title: 'Sample headline: battery makers announce faster-charging cells',
        summary: 'Placeholder summary for a world EV story.',
      ),
    ];

    notifications = [
      AppNotification(
        userId: 'u1',
        title: 'New announcement',
        body: 'Metro EV Owners Circle: Tagaytay run: RSVP with your battery level',
        at: _ago(h: 5),
      ),
      AppNotification(
        userId: 'u1',
        title: 'Poll closing soon',
        body: 'Grace period before a charging-etiquette warning',
        at: _ago(d: 1),
        read: true,
      ),
      AppNotification(
        userId: 'u2',
        title: 'Route check',
        body: 'One attendee of Tagaytay Weekend Run is flagged.',
        at: _ago(h: 2),
      ),
      AppNotification(
        userId: 'u7',
        title: 'New review',
        body: 'Mika Santos reviewed Voltworks EV Service Center.',
        at: _ago(d: 6),
      ),
      AppNotification(
        userId: 'u8',
        title: 'Pending approvals',
        body: 'A community and a provider listing are waiting for review.',
        at: _ago(h: 20),
      ),
    ];
  }

  Station _station(
    String id,
    String name,
    String operator,
    String address,
    String city,
    double lat,
    double lng,
    List<StationConnector> connectors,
    String fee,
    String hours,
    String parking, {
    List<StatusReport>? reports,
    List<CheckIn>? checkIns,
  }) => Station(
    id: id,
    name: name,
    operator: operator,
    address: address,
    city: city,
    lat: lat,
    lng: lng,
    connectors: connectors,
    fee: fee,
    feeDate: _ago(d: 20),
    hours: hours,
    parking: parking,
    source: 'Sample data',
    sourceDate: _ago(d: 20),
    reports: reports,
    checkIns: checkIns,
  );
}

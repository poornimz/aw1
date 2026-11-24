DateTime? _parseNullableDate(dynamic raw) {
  if (raw == null) return null;
  final text = raw.toString().trim();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text)?.toUtc();
}

class PaginationMeta {
  final int total;
  final int limit;
  final int offset;
  final bool hasMore;

  const PaginationMeta({
    required this.total,
    required this.limit,
    required this.offset,
    required this.hasMore,
  });

  factory PaginationMeta.fromJson(Map<String, dynamic> json) {
    return PaginationMeta(
      total: (json['total'] as num?)?.toInt() ?? 0,
      limit: (json['limit'] as num?)?.toInt() ?? 20,
      offset: (json['offset'] as num?)?.toInt() ?? 0,
      hasMore: json['has_more'] == true,
    );
  }
}

class PaginatedResponse<T> {
  final List<T> items;
  final PaginationMeta pagination;
  final DateTime? lastSyncedAt;
  final bool cacheHit;

  const PaginatedResponse({
    required this.items,
    required this.pagination,
    this.lastSyncedAt,
    this.cacheHit = false,
  });
}

class PayloadModel {
  final int id;
  final String name;
  final String payloadType;
  final double? massKg;
  final String? orbit;
  final String? customer;
  final String? description;

  const PayloadModel({
    required this.id,
    required this.name,
    required this.payloadType,
    this.massKg,
    this.orbit,
    this.customer,
    this.description,
  });

  factory PayloadModel.fromJson(Map<String, dynamic> json) {
    return PayloadModel(
      id: (json['id'] as num).toInt(),
      name: json['name']?.toString() ?? 'Unknown Payload',
      payloadType: json['payload_type']?.toString() ?? 'Satellite',
      massKg: (json['mass_kg'] as num?)?.toDouble(),
      orbit: json['orbit']?.toString(),
      customer: json['customer']?.toString(),
      description: json['description']?.toString(),
    );
  }
}

class MissionModel {
  final int id;
  final String missionCode;
  final String name;
  final String program;
  final String status;
  final int organizationId;
  final String? organizationName;
  final int? vehicleId;
  final String? vehicleName;
  final String? launchSite;
  final String? launchPad;
  final String? orbitType;
  final DateTime? launchDateUtc;
  final bool isCrewed;
  final String? summary;
  final String sourceName;
  final DateTime? lastSyncedAt;
  final List<PayloadModel> payloads;

  const MissionModel({
    required this.id,
    required this.missionCode,
    required this.name,
    required this.program,
    required this.status,
    required this.organizationId,
    this.organizationName,
    this.vehicleId,
    this.vehicleName,
    this.launchSite,
    this.launchPad,
    this.orbitType,
    this.launchDateUtc,
    required this.isCrewed,
    this.summary,
    required this.sourceName,
    this.lastSyncedAt,
    required this.payloads,
  });

  factory MissionModel.fromJson(Map<String, dynamic> json) {
    final rawPayloads = json['payloads'] as List<dynamic>? ?? const [];
    return MissionModel(
      id: (json['id'] as num).toInt(),
      missionCode: json['mission_code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      program: json['program']?.toString() ?? 'General',
      status: json['status']?.toString() ?? 'Upcoming',
      organizationId: (json['organization_id'] as num?)?.toInt() ?? 0,
      organizationName: json['organization_name']?.toString(),
      vehicleId: (json['vehicle_id'] as num?)?.toInt(),
      vehicleName: json['vehicle_name']?.toString(),
      launchSite: json['launch_site']?.toString(),
      launchPad: json['launch_pad']?.toString(),
      orbitType: json['orbit_type']?.toString(),
      launchDateUtc: _parseNullableDate(json['launch_date_utc']),
      isCrewed: json['is_crewed'] == true,
      summary: json['summary']?.toString(),
      sourceName: json['source_name']?.toString() ?? 'seed',
      lastSyncedAt: _parseNullableDate(json['last_synced_at']),
      payloads: rawPayloads
          .whereType<Map<String, dynamic>>()
          .map(PayloadModel.fromJson)
          .toList(),
    );
  }
}

class NextMissionData {
  final MissionModel? mission;
  final DateTime serverTimeUtc;
  final DateTime? lastSyncedAt;

  const NextMissionData({
    required this.mission,
    required this.serverTimeUtc,
    this.lastSyncedAt,
  });

  factory NextMissionData.fromJson(Map<String, dynamic> json) {
    final missionJson = json['mission'] as Map<String, dynamic>?;
    return NextMissionData(
      mission: missionJson != null ? MissionModel.fromJson(missionJson) : null,
      serverTimeUtc:
          _parseNullableDate(json['server_time_utc']) ?? DateTime.now().toUtc(),
      lastSyncedAt: _parseNullableDate(json['last_synced_at']),
    );
  }
}

class LaunchVehicleModel {
  final int id;
  final String name;
  final String slug;
  final int organizationId;
  final String? organizationName;
  final String status;
  final int? stages;
  final double? heightM;
  final double? liftoffMassTonnes;
  final int? leoPayloadKg;
  final int? gtoPayloadKg;
  final int? ssoPayloadKg;
  final int totalLaunches;
  final int successfulLaunches;
  final String? description;
  final DateTime? lastSyncedAt;

  const LaunchVehicleModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.organizationId,
    this.organizationName,
    required this.status,
    this.stages,
    this.heightM,
    this.liftoffMassTonnes,
    this.leoPayloadKg,
    this.gtoPayloadKg,
    this.ssoPayloadKg,
    required this.totalLaunches,
    required this.successfulLaunches,
    this.description,
    this.lastSyncedAt,
  });

  factory LaunchVehicleModel.fromJson(Map<String, dynamic> json) {
    return LaunchVehicleModel(
      id: (json['id'] as num).toInt(),
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      organizationId: (json['organization_id'] as num?)?.toInt() ?? 0,
      organizationName: json['organization_name']?.toString(),
      status: json['status']?.toString() ?? 'Operational',
      stages: (json['stages'] as num?)?.toInt(),
      heightM: (json['height_m'] as num?)?.toDouble(),
      liftoffMassTonnes: (json['liftoff_mass_tonnes'] as num?)?.toDouble(),
      leoPayloadKg: (json['leo_payload_kg'] as num?)?.toInt(),
      gtoPayloadKg: (json['gto_payload_kg'] as num?)?.toInt(),
      ssoPayloadKg: (json['sso_payload_kg'] as num?)?.toInt(),
      totalLaunches: (json['total_launches'] as num?)?.toInt() ?? 0,
      successfulLaunches: (json['successful_launches'] as num?)?.toInt() ?? 0,
      description: json['description']?.toString(),
      lastSyncedAt: _parseNullableDate(json['last_synced_at']),
    );
  }
}

class StartupModel {
  final int id;
  final String name;
  final String slug;
  final String focusArea;
  final int? foundedYear;
  final String? headquarters;
  final String? city;
  final String? state;
  final String? fundingStage;
  final String? website;
  final String? description;
  final DateTime? lastSyncedAt;

  const StartupModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.focusArea,
    this.foundedYear,
    this.headquarters,
    this.city,
    this.state,
    this.fundingStage,
    this.website,
    this.description,
    this.lastSyncedAt,
  });

  factory StartupModel.fromJson(Map<String, dynamic> json) {
    return StartupModel(
      id: (json['id'] as num).toInt(),
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      focusArea: json['focus_area']?.toString() ?? 'Space Systems',
      foundedYear: (json['founded_year'] as num?)?.toInt(),
      headquarters: json['headquarters']?.toString(),
      city: json['city']?.toString(),
      state: json['state']?.toString(),
      fundingStage: json['funding_stage']?.toString(),
      website: json['website']?.toString(),
      description: json['description']?.toString(),
      lastSyncedAt: _parseNullableDate(json['last_synced_at']),
    );
  }
}

class ISROCentreModel {
  final int id;
  final String code;
  final String name;
  final String city;
  final String state;
  final double latitude;
  final double longitude;
  final String specialization;
  final int? establishedYear;
  final String? website;
  final String? description;
  final DateTime? lastSyncedAt;

  const ISROCentreModel({
    required this.id,
    required this.code,
    required this.name,
    required this.city,
    required this.state,
    required this.latitude,
    required this.longitude,
    required this.specialization,
    this.establishedYear,
    this.website,
    this.description,
    this.lastSyncedAt,
  });

  factory ISROCentreModel.fromJson(Map<String, dynamic> json) {
    return ISROCentreModel(
      id: (json['id'] as num).toInt(),
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      specialization: json['specialization']?.toString() ?? '',
      establishedYear: (json['established_year'] as num?)?.toInt(),
      website: json['website']?.toString(),
      description: json['description']?.toString(),
      lastSyncedAt: _parseNullableDate(json['last_synced_at']),
    );
  }
}
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../models/space_models.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

class MissionFilterState {
  final String? program;
  final String? status;
  final String search;

  const MissionFilterState({
    this.program,
    this.status,
    this.search = '',
  });

  MissionFilterState copyWith({
    String? program,
    bool clearProgram = false,
    String? status,
    bool clearStatus = false,
    String? search,
  }) {
    return MissionFilterState(
      program: clearProgram ? null : (program ?? this.program),
      status: clearStatus ? null : (status ?? this.status),
      search: search ?? this.search,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is MissionFilterState &&
            other.program == program &&
            other.status == status &&
            other.search == search);
  }

  @override
  int get hashCode => Object.hash(program, status, search);
}

class MissionFilterNotifier extends StateNotifier<MissionFilterState> {
  MissionFilterNotifier() : super(const MissionFilterState());

  void setProgram(String? program) {
    if (program == null || program == 'All') {
      state = state.copyWith(clearProgram: true);
    } else {
      state = state.copyWith(program: program);
    }
  }

  void setStatus(String? status) {
    if (status == null || status == 'All') {
      state = state.copyWith(clearStatus: true);
    } else {
      state = state.copyWith(status: status);
    }
  }

  void setSearch(String search) {
    state = state.copyWith(search: search);
  }

  void reset() {
    state = const MissionFilterState();
  }
}

final missionFilterProvider =
    StateNotifierProvider<MissionFilterNotifier, MissionFilterState>(
  (ref) => MissionFilterNotifier(),
);

final launchControlChipProvider = StateProvider<String>((ref) => 'All');

final startupFocusProvider = StateProvider<String?>((ref) => null);

final centreSearchProvider = StateProvider<String>((ref) => '');

final nextMissionProvider = FutureProvider<NextMissionData>((ref) async {
  final api = ref.watch(apiClientProvider);
  final resp = await api.get<Map<String, dynamic>>('/missions/next');
  return NextMissionData.fromJson(resp.data ?? const {});
});

final launchControlMissionsProvider =
    FutureProvider<PaginatedResponse<MissionModel>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final chip = ref.watch(launchControlChipProvider);

  final params = <String, dynamic>{'limit': 25};
  if (chip != 'All') {
    params['program'] = chip;
  }

  final resp = await api.get<Map<String, dynamic>>(
    '/missions',
    queryParameters: params,
  );
  return _parseMissionPage(resp.data ?? const {});
});

final filteredMissionsProvider =
    FutureProvider<PaginatedResponse<MissionModel>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final filter = ref.watch(missionFilterProvider);

  final params = <String, dynamic>{'limit': 50};
  if (filter.program != null && filter.program!.isNotEmpty) {
    params['program'] = filter.program;
  }
  if (filter.status != null && filter.status!.isNotEmpty) {
    params['status'] = filter.status;
  }
  if (filter.search.trim().isNotEmpty) {
    params['search'] = filter.search.trim();
  }

  final resp = await api.get<Map<String, dynamic>>(
    '/missions',
    queryParameters: params,
  );
  return _parseMissionPage(resp.data ?? const {});
});

final vehiclesProvider =
    FutureProvider<PaginatedResponse<LaunchVehicleModel>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final resp = await api.get<Map<String, dynamic>>('/vehicles');
  final data = resp.data ?? const {};
  final rawItems = data['items'] as List<dynamic>? ?? const [];

  return PaginatedResponse<LaunchVehicleModel>(
    items: rawItems
        .whereType<Map<String, dynamic>>()
        .map(LaunchVehicleModel.fromJson)
        .toList(),
    pagination: PaginationMeta.fromJson(
      data['pagination'] as Map<String, dynamic>? ?? const {},
    ),
    lastSyncedAt: DateTime.tryParse(data['last_synced_at']?.toString() ?? ''),
    cacheHit: data['cache_hit'] == true,
  );
});

final startupsProvider =
    FutureProvider<PaginatedResponse<StartupModel>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final focusArea = ref.watch(startupFocusProvider);

  final params = <String, dynamic>{};
  if (focusArea != null && focusArea != 'All') {
    params['focus_area'] = focusArea;
  }

  final resp = await api.get<Map<String, dynamic>>(
    '/startups',
    queryParameters: params,
  );
  final data = resp.data ?? const {};
  final rawItems = data['items'] as List<dynamic>? ?? const [];

  return PaginatedResponse<StartupModel>(
    items: rawItems
        .whereType<Map<String, dynamic>>()
        .map(StartupModel.fromJson)
        .toList(),
    pagination: PaginationMeta.fromJson(
      data['pagination'] as Map<String, dynamic>? ?? const {},
    ),
    lastSyncedAt: DateTime.tryParse(data['last_synced_at']?.toString() ?? ''),
    cacheHit: data['cache_hit'] == true,
  );
});

final centresProvider =
    FutureProvider<PaginatedResponse<ISROCentreModel>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final search = ref.watch(centreSearchProvider).trim();

  final params = <String, dynamic>{};
  if (search.isNotEmpty) {
    params['search'] = search;
  }

  final resp = await api.get<Map<String, dynamic>>(
    '/centres',
    queryParameters: params,
  );
  final data = resp.data ?? const {};
  final rawItems = data['items'] as List<dynamic>? ?? const [];

  return PaginatedResponse<ISROCentreModel>(
    items: rawItems
        .whereType<Map<String, dynamic>>()
        .map(ISROCentreModel.fromJson)
        .toList(),
    pagination: PaginationMeta.fromJson(
      data['pagination'] as Map<String, dynamic>? ?? const {},
    ),
    lastSyncedAt: DateTime.tryParse(data['last_synced_at']?.toString() ?? ''),
    cacheHit: data['cache_hit'] == true,
  );
});

class SyncNotifier extends StateNotifier<AsyncValue<String?>> {
  final Ref _ref;

  SyncNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> triggerSync() async {
    state = const AsyncValue.loading();
    try {
      final api = _ref.read(apiClientProvider);
      await api.post<Map<String, dynamic>>('/admin/sync');
      _ref.invalidate(nextMissionProvider);
      _ref.invalidate(launchControlMissionsProvider);
      _ref.invalidate(filteredMissionsProvider);
      _ref.invalidate(vehiclesProvider);
      _ref.invalidate(startupsProvider);
      _ref.invalidate(centresProvider);
      state = const AsyncValue.data('Space data synchronized');
    } catch (err, st) {
      state = AsyncValue.error(err, st);
    }
  }
}

final syncNotifierProvider =
    StateNotifierProvider<SyncNotifier, AsyncValue<String?>>(
  (ref) => SyncNotifier(ref),
);

PaginatedResponse<MissionModel> _parseMissionPage(Map<String, dynamic> data) {
  final rawItems = data['items'] as List<dynamic>? ?? const [];
  return PaginatedResponse<MissionModel>(
    items: rawItems
        .whereType<Map<String, dynamic>>()
        .map(MissionModel.fromJson)
        .toList(),
    pagination: PaginationMeta.fromJson(
      data['pagination'] as Map<String, dynamic>? ?? const {},
    ),
    lastSyncedAt: DateTime.tryParse(data['last_synced_at']?.toString() ?? ''),
    cacheHit: data['cache_hit'] == true,
  );
}
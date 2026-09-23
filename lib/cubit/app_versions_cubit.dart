import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/app_versions_repository.dart';
import '../models/app_version.dart';

enum AppVersionsStatus { loading, loaded, error }

class AppVersionsState {
  const AppVersionsState({
    required this.status,
    this.versions = const [],
    this.errorMessage,
    this.searchQuery = '',
  });

  final AppVersionsStatus status;
  final List<AppVersion> versions;
  final String? errorMessage;
  final String searchQuery;

  const AppVersionsState.initial() : this(status: AppVersionsStatus.loading);

  List<AppVersion> get filteredVersions {
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return versions;
    return versions
        .where((v) => v.packageName.toLowerCase().contains(query))
        .toList(growable: false);
  }

  AppVersionsState copyWith({
    AppVersionsStatus? status,
    List<AppVersion>? versions,
    String? errorMessage,
    String? searchQuery,
  }) {
    return AppVersionsState(
      status: status ?? this.status,
      versions: versions ?? this.versions,
      errorMessage: errorMessage,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

/// يدير تدفّق قائمة إصدارات التطبيقات اللحظي (مرتبط مباشرة بـ Firestore
/// snapshots) بالإضافة لفلترة البحث المحلية.
class AppVersionsCubit extends Cubit<AppVersionsState> {
  AppVersionsCubit({required AppVersionsRepository repository})
      : _repository = repository,
        super(const AppVersionsState.initial()) {
    _subscription = _repository.watchAll().listen(
      (versions) {
        emit(state.copyWith(
          status: AppVersionsStatus.loaded,
          versions: versions,
        ));
      },
      onError: (Object error) {
        emit(state.copyWith(
          status: AppVersionsStatus.error,
          errorMessage: 'تعذّر تحميل قائمة الإصدارات: $error',
        ));
      },
    );
  }

  final AppVersionsRepository _repository;
  late final StreamSubscription<List<AppVersion>> _subscription;

  void search(String query) {
    emit(state.copyWith(searchQuery: query));
  }

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}

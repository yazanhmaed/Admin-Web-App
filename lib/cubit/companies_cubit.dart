import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/companies_repository.dart';
import '../models/company.dart';

enum CompaniesStatus { loading, loaded, error }

class CompaniesState {
  const CompaniesState({
    required this.status,
    this.companies = const [],
    this.errorMessage,
    this.searchQuery = '',
  });

  final CompaniesStatus status;
  final List<Company> companies;
  final String? errorMessage;
  final String searchQuery;

  const CompaniesState.initial() : this(status: CompaniesStatus.loading);

  List<Company> get filteredCompanies {
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return companies;
    return companies
        .where((c) =>
            c.name.toLowerCase().contains(query) ||
            c.code.toLowerCase().contains(query))
        .toList(growable: false);
  }

  CompaniesState copyWith({
    CompaniesStatus? status,
    List<Company>? companies,
    String? errorMessage,
    String? searchQuery,
  }) {
    return CompaniesState(
      status: status ?? this.status,
      companies: companies ?? this.companies,
      errorMessage: errorMessage,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

/// يدير تدفّق قائمة الشركات اللحظي (مرتبط مباشرة بـ Firestore snapshots)
/// بالإضافة لفلترة البحث المحلية.
class CompaniesCubit extends Cubit<CompaniesState> {
  CompaniesCubit({required CompaniesRepository companiesRepository})
      : _repository = companiesRepository,
        super(const CompaniesState.initial()) {
    _subscription = _repository.watchAll().listen(
      (companies) {
        emit(state.copyWith(
          status: CompaniesStatus.loaded,
          companies: companies,
        ));
      },
      onError: (Object error) {
        emit(state.copyWith(
          status: CompaniesStatus.error,
          errorMessage: 'تعذّر تحميل قائمة الشركات: $error',
        ));
      },
    );
  }

  final CompaniesRepository _repository;
  late final StreamSubscription<List<Company>> _subscription;

  void search(String query) {
    emit(state.copyWith(searchQuery: query));
  }

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}

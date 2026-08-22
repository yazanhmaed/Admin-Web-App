import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/theme.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/companies_cubit.dart';
import '../data/companies_repository.dart';
import '../models/company.dart';
import 'widgets/company_details_dialog.dart';
import 'widgets/company_form_dialog.dart';
import 'widgets/company_row.dart';
import 'widgets/delete_confirm_dialog.dart';
import 'widgets/import_json_dialog.dart';
import 'widgets/renew_subscription_dialog.dart';

class CompaniesListScreen extends StatefulWidget {
  const CompaniesListScreen({super.key});

  @override
  State<CompaniesListScreen> createState() => _CompaniesListScreenState();
}

class _CompaniesListScreenState extends State<CompaniesListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _toggleActive(Company company, bool value) async {
    final repo = context.read<CompaniesRepository>();
    try {
      await repo.setActive(company.code, value);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر تحديث حالة التفعيل: $e')),
      );
    }
  }

  Future<void> _confirmDelete(Company company) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => DeleteConfirmDialog(company: company),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    final repo = context.read<CompaniesRepository>();
    try {
      await repo.deleteCompany(company.code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم حذف "${company.name}".')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر الحذف: $e')),
      );
    }
  }

  void _openAddDialog() {
    showDialog(
      context: context,
      builder: (_) => const CompanyFormDialog(),
    );
  }

  void _openEditDialog(Company company) {
    showDialog(
      context: context,
      builder: (_) => CompanyFormDialog(existingCompany: company),
    );
  }

  void _openRenewDialog(Company company) {
    showDialog(
      context: context,
      builder: (_) => RenewSubscriptionDialog(company: company),
    );
  }

  void _openDetailsDialog(Company company) {
    showDialog(
      context: context,
      builder: (_) => CompanyDetailsDialog(company: company),
    );
  }

  void _openImportDialog() {
    showDialog(
      context: context,
      builder: (_) => const ImportJsonDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الشركات'),
        actions: [
          IconButton(
            tooltip: 'استيراد من JSON',
            icon: const Icon(Icons.upload_file_outlined),
            onPressed: _openImportDialog,
          ),
          IconButton(
            tooltip: 'تسجيل الخروج',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => context.read<AuthCubit>().signOut(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('إضافة شركة جديدة'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 360,
              child: TextField(
                controller: _searchController,
                onChanged: (value) =>
                    context.read<CompaniesCubit>().search(value),
                decoration: const InputDecoration(
                  hintText: 'ابحث بالاسم أو الكود...',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: BlocBuilder<CompaniesCubit, CompaniesState>(
                builder: (context, state) {
                  if (state.status == CompaniesStatus.loading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state.status == CompaniesStatus.error) {
                    return Center(
                      child: Text(
                        state.errorMessage ?? 'حدث خطأ',
                        style: const TextStyle(color: AppTheme.danger),
                      ),
                    );
                  }
                  final companies = state.filteredCompanies;
                  if (companies.isEmpty) {
                    return const Center(
                      child: Text('لا توجد شركات مطابقة.'),
                    );
                  }
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: kCompanyRowTotalWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                border: Border(
                                  bottom: BorderSide(
                                      color: Colors.grey.shade200),
                                ),
                              ),
                              child: const CompanyRowHeader(),
                            ),
                            Expanded(
                              child: ListView.separated(
                                itemCount: companies.length,
                                separatorBuilder: (_, _) => Divider(
                                  height: 1,
                                  color: Colors.grey.shade200,
                                ),
                                itemBuilder: (context, index) {
                                  final company = companies[index];
                                  return CompanyRow(
                                    company: company,
                                    onToggleActive: (value) =>
                                        _toggleActive(company, value),
                                    onEdit: () => _openEditDialog(company),
                                    onRenew: () => _openRenewDialog(company),
                                    onDelete: () => _confirmDelete(company),
                                    onDetails: () =>
                                        _openDetailsDialog(company),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

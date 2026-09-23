import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/theme.dart';
import '../cubit/app_versions_cubit.dart';
import '../data/app_versions_repository.dart';
import '../models/app_version.dart';
import 'widgets/app_version_delete_confirm_dialog.dart';
import 'widgets/app_version_form_dialog.dart';
import 'widgets/app_version_row.dart';

class AppVersionsScreen extends StatefulWidget {
  const AppVersionsScreen({super.key});

  @override
  State<AppVersionsScreen> createState() => _AppVersionsScreenState();
}

class _AppVersionsScreenState extends State<AppVersionsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete(AppVersion version) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AppVersionDeleteConfirmDialog(version: version),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    final repo = context.read<AppVersionsRepository>();
    try {
      await repo.deleteVersion(version.packageName);
      await repo.deleteApkFile(
        packageName: version.packageName,
        versionCode: version.latestVersionCode,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم حذف إصدار "${version.packageName}".')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر الحذف: $e')),
      );
    }
  }

  void _openAddDialog(List<AppVersion> allVersions) {
    showDialog(
      context: context,
      builder: (_) => AppVersionFormDialog(allVersions: allVersions),
    );
  }

  void _openEditDialog(AppVersion version, List<AppVersion> allVersions) {
    showDialog(
      context: context,
      builder: (_) => AppVersionFormDialog(
        existingVersion: version,
        allVersions: allVersions,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إصدارات التطبيق'),
      ),
      floatingActionButton: BlocBuilder<AppVersionsCubit, AppVersionsState>(
        builder: (context, state) {
          return FloatingActionButton.extended(
            onPressed: () => _openAddDialog(state.versions),
            icon: const Icon(Icons.add_rounded),
            label: const Text('إضافة إصدار جديد'),
          );
        },
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
                    context.read<AppVersionsCubit>().search(value),
                decoration: const InputDecoration(
                  hintText: 'ابحث باسم الحزمة...',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: BlocBuilder<AppVersionsCubit, AppVersionsState>(
                builder: (context, state) {
                  if (state.status == AppVersionsStatus.loading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state.status == AppVersionsStatus.error) {
                    return Center(
                      child: Text(
                        state.errorMessage ?? 'حدث خطأ',
                        style: const TextStyle(color: AppTheme.danger),
                      ),
                    );
                  }
                  final versions = state.filteredVersions;
                  if (versions.isEmpty) {
                    return const Center(
                      child: Text('لا توجد إصدارات منشورة بعد.'),
                    );
                  }
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: kAppVersionRowTotalWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                border: Border(
                                  bottom:
                                      BorderSide(color: Colors.grey.shade200),
                                ),
                              ),
                              child: const AppVersionRowHeader(),
                            ),
                            Expanded(
                              child: ListView.separated(
                                itemCount: versions.length,
                                separatorBuilder: (_, i) => Divider(
                                  height: 1,
                                  color: Colors.grey.shade200,
                                ),
                                itemBuilder: (context, index) {
                                  final version = versions[index];
                                  return AppVersionRow(
                                    version: version,
                                    onEdit: () => _openEditDialog(
                                        version, state.versions),
                                    onDelete: () => _confirmDelete(version),
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

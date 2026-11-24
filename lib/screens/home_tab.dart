import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/app_theme.dart';
import '../data/models/content_model.dart';
import '../data/repositories/content_repository.dart';
import '../logic/content/content_cubit.dart';
import '../logic/content/content_state.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  static const List<({String value, String label})> _categories = [
    (value: 'All', label: 'Semua'),
    (value: 'Ihram', label: 'Ihram'),
    (value: 'Thawaf', label: 'Thawaf'),
    (value: "Sa'i", label: "Sa'i"),
    (value: 'Tahallul', label: 'Tahallul'),
  ];

  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          ContentCubit(context.read<ContentRepository>())..fetchContent(),
      child: Builder(
        builder: (context) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              title: const Text(
                'Panduan Doa',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: Column(
                    children: [
                      _buildSearchBar(context),
                      const SizedBox(height: AppSpacing.md),
                      _buildCategoryFilter(),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Expanded(
                  child: BlocBuilder<ContentCubit, ContentState>(
                    builder: (context, state) {
                      if (state is ContentLoading || state is ContentInitial) {
                        return const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: AppSpacing.md),
                              Text(
                                'Memuat panduan doa...',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      if (state is ContentError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.xxl),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.wifi_off_rounded,
                                  size: 48,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Text(
                                  state.message,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                ElevatedButton(
                                  onPressed: () => context
                                      .read<ContentCubit>()
                                      .fetchContent(),
                                  child: const Text('Coba Lagi'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      if (state is ContentLoaded) {
                        final isFiltered =
                            state.searchQuery.trim().isNotEmpty ||
                                state.activeCategory != 'All';

                        return Column(
                          children: [
                            if (state.isFromCache) _buildOfflineBanner(context),
                            Expanded(
                              child: state.displayList.isEmpty
                                  ? _buildEmptyState(context, isFiltered)
                                  : RefreshIndicator(
                                      color: AppColors.primary,
                                      onRefresh: () => context
                                          .read<ContentCubit>()
                                          .fetchContent(),
                                      child: ListView.builder(
                                        physics:
                                            const AlwaysScrollableScrollPhysics(),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppSpacing.lg,
                                          vertical: AppSpacing.sm,
                                        ),
                                        itemCount: state.displayList.length,
                                        itemBuilder: (context, index) {
                                          return _buildMenuItem(
                                            context,
                                            state.displayList[index],
                                          );
                                        },
                                      ),
                                    ),
                            ),
                          ],
                        );
                      }

                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _searchController,
      builder: (context, value, _) {
        return TextField(
          controller: _searchController,
          onChanged: (text) {
            context.read<ContentCubit>().filterContent(query: text);
          },
          decoration: InputDecoration(
            hintText: 'Cari doa atau bacaan manasik...',
            prefixIcon: const Icon(
              Icons.search,
              color: AppColors.textSecondary,
            ),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Hapus pencarian',
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      context.read<ContentCubit>().filterContent(query: '');
                    },
                  ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: 14,
            ),
          ),
        );
      },
    );
  }

  Widget _buildOfflineBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.infoSurface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 18,
            color: AppColors.infoText,
          ),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(
            child: Text(
              'Menampilkan panduan tersimpan (offline).',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.infoText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () => context.read<ContentCubit>().fetchContent(),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.infoText,
              minimumSize: const Size(44, 44),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Muat Ulang',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isFiltered) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.menu_book_outlined,
              size: 48,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              isFiltered
                  ? 'Tidak ada doa yang cocok dengan pencarian atau kategori ini.'
                  : 'Belum ada panduan doa yang tersedia.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: () {
                if (isFiltered) {
                  _searchController.clear();
                  context
                      .read<ContentCubit>()
                      .filterContent(category: 'All', query: '');
                } else {
                  context.read<ContentCubit>().fetchContent();
                }
              },
              child: Text(isFiltered ? 'Reset Filter' : 'Muat Ulang'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return BlocBuilder<ContentCubit, ContentState>(
      builder: (context, state) {
        final activeCategory =
            state is ContentLoaded ? state.activeCategory : 'All';

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _categories.map((cat) {
              final isActive = activeCategory == cat.value;
              return Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: Semantics(
                  button: true,
                  selected: isActive,
                  label: 'Kategori ${cat.label}',
                  child: Material(
                    color: isActive
                        ? AppColors.errorSurface
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      onTap: () {
                        context
                            .read<ContentCubit>()
                            .filterContent(category: cat.value);
                      },
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: 44,
                          minWidth: 44,
                        ),
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                              color: isActive
                                  ? AppColors.primary
                                  : AppColors.borderChip,
                              width: isActive ? 1.5 : 1,
                            ),
                          ),
                          child: Text(
                            cat.label,
                            style: TextStyle(
                              color: isActive
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                              fontWeight:
                                  isActive ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildMenuItem(BuildContext context, ContentModel item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Semantics(
        button: true,
        label: 'Buka detail ${item.name}',
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: () => _showDetailModal(context, item),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.md,
                  horizontal: AppSpacing.lg,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (item.category.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              item.category,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    const Icon(
                      Icons.chevron_right,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDetailModal(BuildContext context, ContentModel item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) => _DoaDetailSheet(item: item),
    );
  }
}

class _DoaDetailSheet extends StatefulWidget {
  final ContentModel item;

  const _DoaDetailSheet({required this.item});

  @override
  State<_DoaDetailSheet> createState() => _DoaDetailSheetState();
}

class _DoaDetailSheetState extends State<_DoaDetailSheet> {
  static const String _fontScaleKey = 'doa_font_scale';
  static const double _minScale = 0.85;
  static const double _maxScale = 1.50;
  static const double _step = 0.15;

  double _fontScale = 1.0;

  @override
  void initState() {
    super.initState();
    _loadFontScale();
  }

  Future<void> _loadFontScale() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble(_fontScaleKey);
    if (saved != null && mounted) {
      setState(() {
        _fontScale = saved.clamp(_minScale, _maxScale);
      });
    }
  }

  Future<void> _updateFontScale(double delta) async {
    final next =
        ((_fontScale + delta).clamp(_minScale, _maxScale) * 100).round() / 100;
    if (next == _fontScale) return;
    setState(() => _fontScale = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontScaleKey, next);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final canDecrease = _fontScale > _minScale + 0.001;
    final canIncrease = _fontScale < _maxScale - 0.001;
    final percent = (_fontScale * 100).round();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) {
        return SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
            ),
            child: ListView(
              controller: controller,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderChip,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    if (item.category.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundWarm,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Text(
                          item.category,
                          style: const TextStyle(
                            color: AppColors.accentGold,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildFontButton(
                          label: 'A-',
                          tooltip: 'Perkecil ukuran huruf',
                          onPressed: canDecrease
                              ? () => _updateFontScale(-_step)
                              : null,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                          ),
                          child: Text(
                            '$percent%',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        _buildFontButton(
                          label: 'A+',
                          tooltip: 'Perbesar ukuran huruf',
                          onPressed: canIncrease
                              ? () => _updateFontScale(_step)
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                if (item.arabic.isNotEmpty) ...[
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: Text(
                      item.arabic,
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 26 * _fontScale,
                        fontWeight: FontWeight.bold,
                        height: 1.9,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
                if (item.latin.isNotEmpty) ...[
                  Text(
                    item.latin,
                    style: TextStyle(
                      fontSize: 16 * _fontScale,
                      fontStyle: FontStyle.italic,
                      height: 1.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
                const Text(
                  'Terjemahan',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  item.translateId,
                  style: TextStyle(
                    fontSize: 15 * _fontScale,
                    height: 1.55,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                if (item.description.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Text(
                      item.description,
                      style: TextStyle(
                        fontSize: 13 * _fontScale,
                        height: 1.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFontButton({
    required String label,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          disabledForegroundColor: AppColors.borderChip,
          side: BorderSide(
            color:
                onPressed == null ? AppColors.borderSubtle : AppColors.primary,
          ),
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

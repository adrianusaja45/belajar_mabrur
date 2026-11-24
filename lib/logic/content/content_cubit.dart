import 'package:belajar_mabrur/data/repositories/content_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/api_exception.dart';
import '../../data/models/content_model.dart';
import 'content_state.dart';

class ContentCubit extends Cubit<ContentState> {
  final ContentRepository repository;

  // Keep unfiltered list in memory for local search and category filtering.
  List<ContentModel> _allContent = [];
  bool _isFromCache = false;

  ContentCubit(this.repository) : super(ContentInitial());

  Future<void> fetchContent() async {
    if (isClosed) return;

    final previous = state;
    final activeCategory =
        previous is ContentLoaded ? previous.activeCategory : "All";
    final searchQuery = previous is ContentLoaded ? previous.searchQuery : "";

    emit(ContentLoading());
    try {
      final result = await repository.getContents();
      _allContent = result.items;
      _isFromCache = result.fromCache;

      if (isClosed) return;
      filterContent(category: activeCategory, query: searchQuery);
    } catch (e) {
      debugPrint("Content Error: $e");
      final message = e is ApiException
          ? e.message
          : 'Gagal memuat panduan. Silakan coba lagi.';
      if (!isClosed) emit(ContentError(message));
    }
  }

  void filterContent({String? category, String? query}) {
    if (isClosed) return;

    final currentState = state;
    String currentCategory = "All";
    String currentQuery = "";

    if (currentState is ContentLoaded) {
      currentCategory = category ?? currentState.activeCategory;
      currentQuery = query ?? currentState.searchQuery;
    } else {
      currentCategory = category ?? "All";
      currentQuery = query ?? "";
    }

    final normalizedQuery = currentQuery.trim().toLowerCase();

    List<ContentModel> filtered = _allContent.where((item) {
      final matchCategory =
          currentCategory == "All" || item.category == currentCategory;
      final matchSearch = normalizedQuery.isEmpty ||
          item.name.toLowerCase().contains(normalizedQuery) ||
          item.latin.toLowerCase().contains(normalizedQuery) ||
          item.translateId.toLowerCase().contains(normalizedQuery);
      return matchCategory && matchSearch;
    }).toList();

    emit(
      ContentLoaded(
        filtered,
        activeCategory: currentCategory,
        searchQuery: currentQuery,
        isFromCache: _isFromCache,
      ),
    );
  }
}

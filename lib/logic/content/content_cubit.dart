import 'package:belajar_mabrur/data/repositories/content_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/content_model.dart';
import 'content_state.dart';

class ContentCubit extends Cubit<ContentState> {
  final ContentRepository repository;
  
  // Cache data asli agar tidak perlu hit API ulang saat filtering
  List<ContentModel> _allContent = [];

  ContentCubit(this.repository) : super(ContentInitial());

  /// Fungsi untuk mengambil data dari Server
  void fetchContent() async {
    // Safety check: Jangan emit jika widget sudah didispose
    if (isClosed) return; 
    
    emit(ContentLoading());
    try {
      _allContent = await repository.getContents().timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception("Server tidak merespons (Timeout)"),
      );
      
      if (isClosed) return; 
      emit(ContentLoaded(_allContent));
    } catch (e) {
      debugPrint("Content Error: $e");
      if (!isClosed) emit(ContentError(e.toString()));
    }
  }

  /// Fungsi lokal untuk memfilter data (Pencarian & Kategori)
  /// Tidak memanggil API, hanya memproses _allContent
  void filterContent({String? category, String? query}) {
    if (isClosed) return;

    final currentState = state;
    String currentCategory = "All";
    String currentQuery = "";

    // Pertahankan filter sebelumnya jika parameter null
    if (currentState is ContentLoaded) {
      currentCategory = category ?? currentState.activeCategory;
      currentQuery = query ?? currentState.searchQuery;
    } else {
      currentCategory = category ?? "All";
      currentQuery = query ?? "";
    }

    // Logika Filter
    List<ContentModel> filtered = _allContent.where((item) {
      final matchCategory = currentCategory == "All" || item.category == currentCategory;
      final matchSearch = item.name.toLowerCase().contains(currentQuery.toLowerCase());
      return matchCategory && matchSearch;
    }).toList();

    emit(ContentLoaded(
      filtered, 
      activeCategory: currentCategory, 
      searchQuery: currentQuery
    ));
  }
}
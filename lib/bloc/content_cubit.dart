import 'package:flutter/material.dart'; // Tambahkan untuk debugPrint
import 'package:flutter_bloc/flutter_bloc.dart';
import '../repositories/auth_repository.dart';
import '../models/content_model.dart';

// State (Tetap sama)
abstract class ContentState {}
class ContentInitial extends ContentState {}
class ContentLoading extends ContentState {}
class ContentLoaded extends ContentState {
  final List<ContentModel> displayList;
  final String activeCategory;
  final String searchQuery;
  ContentLoaded(this.displayList, {this.activeCategory = "All", this.searchQuery = ""});
}
class ContentError extends ContentState {
  final String message;
  ContentError(this.message);
}

// Cubit
class ContentCubit extends Cubit<ContentState> {
  final AuthRepository repository;
  List<ContentModel> _allContent = [];

  ContentCubit(this.repository) : super(ContentInitial());

  void fetchContent() async {
    // Pastikan tidak emit jika Cubit sudah ditutup
    if (isClosed) return; 
    
    emit(ContentLoading());
    try {
      // Tambahkan timeout agar tidak ANR (isn't responding)
      _allContent = await repository.getContents().timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception("Server tidak merespons (Timeout)"),
      );
      
      if (isClosed) return; // Cek kembali sebelum emit
      emit(ContentLoaded(_allContent));
    } catch (e) {
      debugPrint("Content Error: $e");
      if (!isClosed) emit(ContentError(e.toString()));
    }
  }

  void filterContent({String? category, String? query}) {
    if (isClosed) return; // Cek status

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
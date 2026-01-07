import '../../data/models/content_model.dart';

/// Base class state konten.
abstract class ContentState {}

class ContentInitial extends ContentState {}

/// Saat data sedang diambil dari API.
class ContentLoading extends ContentState {}

/// Saat data berhasil dimuat.
/// Menyimpan list data asli dan status filter pencarian/kategori.
class ContentLoaded extends ContentState {
  final List<ContentModel> displayList;
  final String activeCategory;
  final String searchQuery;
  
  ContentLoaded(this.displayList, {this.activeCategory = "All", this.searchQuery = ""});
}

/// Saat gagal memuat data.
class ContentError extends ContentState {
  final String message;
  ContentError(this.message);
}
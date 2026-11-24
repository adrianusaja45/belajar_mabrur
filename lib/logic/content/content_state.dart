import '../../data/models/content_model.dart';

abstract class ContentState {}

class ContentInitial extends ContentState {}

class ContentLoading extends ContentState {}

class ContentLoaded extends ContentState {
  final List<ContentModel> displayList;
  final String activeCategory;
  final String searchQuery;
  final bool isFromCache;

  ContentLoaded(
    this.displayList, {
    this.activeCategory = "All",
    this.searchQuery = "",
    this.isFromCache = false,
  });
}

class ContentError extends ContentState {
  final String message;
  ContentError(this.message);
}

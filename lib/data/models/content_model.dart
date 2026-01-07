class ContentModel {
  final int id;
  final String name;
  final String category;
  final String arabic;
  final String latin;
  final String translateId;
  final String description;

  ContentModel({
    required this.id,
    required this.name,
    required this.category,
    required this.arabic,
    required this.latin,
    required this.translateId,
    required this.description,
  });

  /// Factory method untuk mengubah JSON dari API menjadi Object Dart.
  factory ContentModel.fromJson(Map<String, dynamic> json) {
    return ContentModel(
      id: json['id'],
      name: json['name'] ?? '',
      category: json['category'] ?? 'General',
      arabic: json['arabic'] ?? '',
      latin: json['latin'] ?? '',
      translateId: json['translate_id'] ?? '',
      description: json['description'] ?? '',
    );
  }
}
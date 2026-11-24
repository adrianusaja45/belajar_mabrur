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

  factory ContentModel.fromJson(Map<String, dynamic> json) {
    return ContentModel(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Umum',
      arabic: json['arabic']?.toString() ?? '',
      latin: json['latin']?.toString() ?? '',
      translateId: json['translate_id']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'arabic': arabic,
        'latin': latin,
        'translate_id': translateId,
        'description': description,
      };
}

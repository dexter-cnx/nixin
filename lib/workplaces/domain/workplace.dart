class Workplace {
  const Workplace({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.isDefault = false,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDefault;

  Workplace copyWith({
    String? name,
    DateTime? updatedAt,
    bool? isDefault,
  }) {
    return Workplace(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'isDefault': isDefault,
      };

  factory Workplace.fromMap(Map<dynamic, dynamic> map) {
    return Workplace(
      id: map['id'] as String,
      name: map['name'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      isDefault: map['isDefault'] as bool? ?? false,
    );
  }
}

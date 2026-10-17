abstract class BaseEntity<TId> {
  final TId id;
  final String name;
  final String? description;

  const BaseEntity({
    required this.id,
    required this.name,
    this.description,
  });

  // Phương thức chung có thể override
  Map<String, dynamic> toJson();
}
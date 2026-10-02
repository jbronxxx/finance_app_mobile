import 'local_db_models.dart';

/// Модель пагинированного ответа API (`PaginatedResponse<T>`).
class PaginatedResponse<T> {
  final List<T> items;
  final int total;
  final int limit;
  final int offset;

  const PaginatedResponse({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  /// Вычисляет наличие следующей страницы на основе текущего смещения и общего числа элементов.
  bool get hasMore => offset + items.length < total;

  /// Разбирает структуру ответа с элементами `items` и метаданными пагинации `total`, `limit`, `offset`.
  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic item) fromJsonT,
  ) {
    final rawItems = json['items'];
    final itemsList = rawItems is List
        ? rawItems.map((item) => fromJsonT(item)).toList()
        : <T>[];

    return PaginatedResponse<T>(
      items: itemsList,
      total: parseInteger(json['total']),
      limit: parseInteger(json['limit'], 50),
      offset: parseInteger(json['offset']),
    );
  }

  /// Преобразует пагинированный список в JSON-представление.
  Map<String, dynamic> toJson(Map<String, dynamic> Function(T item) toJsonT) {
    return {
      'items': items.map((e) => toJsonT(e)).toList(),
      'total': total,
      'limit': limit,
      'offset': offset,
    };
  }
}

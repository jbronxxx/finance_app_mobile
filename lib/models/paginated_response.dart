import 'local_db_models.dart';

/// Модель пагинированного ответа API (`PaginatedResponse<T>`).
class PaginatedResponse<T> {
  final List<T> items;
  final bool hasMore;
  final String? nextCursor;
  final int limit;

  const PaginatedResponse({
    required this.items,
    required this.hasMore,
    this.nextCursor,
    required this.limit,
  });

  /// Разбирает структуру ответа с элементами `items` и метаданными пагинации `has_more`, `limit`, `next_cursor`.
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
      hasMore: json['has_more'] as bool? ?? false,
      nextCursor: json['next_cursor'] as String?,
      limit: parseInteger(json['limit'], 50),
    );
  }

  /// Преобразует пагинированный список в JSON-представление.
  Map<String, dynamic> toJson(Map<String, dynamic> Function(T item) toJsonT) {
    return {
      'items': items.map((e) => toJsonT(e)).toList(),
      'has_more': hasMore,
      'next_cursor': nextCursor,
      'limit': limit,
    };
  }
}

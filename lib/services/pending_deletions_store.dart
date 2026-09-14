import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Очередь удалений, которые ещё не доехали до сервера («надгробия»).
///
/// Нужна из-за асимметрии синхронизации. Создание и изменение записи видно
/// по самой записи, а вот удаление не оставляет в локальной базе никакого
/// следа: строки просто нет. Поэтому [ApiService.syncBackendDataToLocal],
/// забирая с сервера полный список, не может отличить «эту запись удалили на
/// устройстве» от «эту запись на устройстве ещё не видели» — и вернул бы
/// удалённую транзакцию назад при следующем входе.
///
/// Сюда попадают `serverId` транзакций, удалённых пока приложение было без
/// сети или без авторизации (гостевой режим после выхода из аккаунта).
/// [ApiService.syncAll] проигрывает очередь перед выгрузкой и загрузкой.
///
/// Хранится файлом в каталоге документов приложения, а не в локальной БД:
/// для новой ObjectBox-сущности потребовалась бы перегенерация
/// `objectbox.g.dart`. Файл переживает перезапуск приложения и выход из
/// аккаунта, но удаляется вместе с приложением — это правильно: после
/// переустановки сервер остаётся единственным источником данных, и
/// проигрывать старые удаления уже нечему.
class PendingDeletionsStore {
  static late final PendingDeletionsStore instance;

  final File _file;
  final Set<String> _transactionIds;

  PendingDeletionsStore._(this._file, this._transactionIds);

  /// Читает очередь с диска и инициализирует [instance]. Вызывается один раз
  /// при старте приложения. Повреждённый или нечитаемый файл не считается
  /// ошибкой: очередь просто начинается пустой, иначе приложение не
  /// запустилось бы из-за вспомогательных данных.
  static Future<void> init() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final file = File(p.join(docsDir.path, 'pending_deletions.json'));
    final ids = <String>{};

    try {
      if (await file.exists()) {
        final decoded = jsonDecode(await file.readAsString());

        if (decoded is List) {
          ids.addAll(decoded.whereType<String>());
        }
      }
    } catch (e) {
      debugPrint('Не удалось прочитать очередь удалений: $e');
    }

    instance = PendingDeletionsStore._(file, ids);
  }

  /// `serverId` транзакций, удаление которых ещё нужно повторить на сервере.
  Set<String> get transactionIds => Set.unmodifiable(_transactionIds);

  bool get isEmpty => _transactionIds.isEmpty;

  Future<void> addTransaction(String serverId) async {
    if (_transactionIds.add(serverId)) await _flush();
  }

  /// Убирает из очереди удаления, доехавшие до сервера.
  Future<void> removeTransactions(Iterable<String> serverIds) async {
    final sizeBefore = _transactionIds.length;
    _transactionIds.removeAll(serverIds.toSet());

    if (_transactionIds.length != sizeBefore) await _flush();
  }

  Future<void> _flush() async {
    try {
      await _file.writeAsString(jsonEncode(_transactionIds.toList()));
    } catch (e) {
      // Запись не удалась — очередь останется только в памяти и будет
      // потеряна при перезапуске. Это лучше, чем упасть в момент удаления
      // транзакции, но знать об этом в логах полезно.
      debugPrint('Не удалось сохранить очередь удалений: $e');
    }
  }
}

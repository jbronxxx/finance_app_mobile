import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Сервис для получения и кеширования информации о приложении.
class AppInfoService {
  AppInfoService._internal();

  static final AppInfoService instance = AppInfoService._internal();

  PackageInfo? _cachedPackageInfo;

  /// Возвращает кешированный экземпляр [PackageInfo] или запрашивает его у платформы.
  Future<PackageInfo> getPackageInfo() async {
    _cachedPackageInfo ??= await PackageInfo.fromPlatform();
    return _cachedPackageInfo!;
  }

  /// Возвращает форматированную строку версии и номера сборки (например, '1.0.0+1').
  Future<String> getVersionString() async {
    final info = await getPackageInfo();
    return '${info.version}+${info.buildNumber}';
  }

  /// Возвращает название приложения.
  Future<String> getAppName() async {
    final info = await getPackageInfo();
    return info.appName;
  }

  /// Возвращает идентификатор пакета приложения.
  Future<String> getPackageName() async {
    final info = await getPackageInfo();
    return info.packageName;
  }

  /// Выполняет предзагрузку информации о приложении в память.
  Future<void> init() async {
    await getPackageInfo();
  }

  /// Сбрасывает закешированные данные.
  @visibleForTesting
  void reset() {
    _cachedPackageInfo = null;
  }

  /// Задает мок-объект информации о приложении для тестирования.
  @visibleForTesting
  void setMockPackageInfo(PackageInfo info) {
    _cachedPackageInfo = info;
  }
}

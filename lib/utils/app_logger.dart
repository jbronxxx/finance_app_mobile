import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:talker_flutter/talker_flutter.dart';

final talker = TalkerFlutter.init(
  settings: TalkerSettings(
    enabled: kDebugMode, // Полностью отключаем в релизе
    useConsoleLogs: kDebugMode,
  ),
);

final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 5,
    lineLength: 80,
    colors: true,
    printEmojis: true,
  ),
  level: kReleaseMode ? Level.off : Level.trace,
);

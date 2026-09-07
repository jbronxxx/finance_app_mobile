# Family Budget (finance_app_mobile)

Flutter-приложение для учёта личных/семейных финансов: баланс, операции,
лимиты бюджета по категориям, AI-инсайты. Работает офлайн (ObjectBox),
опционально синхронизируется с бэкендом на FastAPI.

Архитектура и известные ограничения подробно описаны в
[ARCHITECTURE.md](ARCHITECTURE.md) — прочитайте перед тем, как вносить
изменения в `services/`, `models/` или связывать новые экраны.

## Требования

- [FVM](https://fvm.app/) — используется для фиксации версии Flutter
  (см. `.fvmrc` → Flutter `3.29.3`). Можно и без FVM (см. ниже), но версии
  Flutter/Dart тогда нужно совместить самостоятельно.
- Xcode (для iOS/macOS-сборок, только macOS) с установленными CocoaPods
  (`sudo gem install cocoapods`).
- Android Studio + Android SDK/NDK (для Android-сборок).
- Для запуска на устройствах — авторизованный доступ (Android: USB-debug,
  iOS: доверенный сертификат разработчика/Apple ID в Xcode).

## Установка

```bash
# Один раз: поставить FVM (если ещё не установлен)
brew tap leoafarias/fvm && brew install fvm

# Поставить/активировать версию Flutter, зафиксированную в .fvmrc
fvm install
fvm use

# Подтянуть зависимости
fvm flutter pub get
```

Если не используете FVM — замените `fvm flutter` на `flutter` во всех
командах ниже (нужен Flutter 3.29.3 или совместимый).

## Переменные окружения (`.env`)

Приложение не хранит адреса бэкенда, ключи и прочие настройки окружения в
коде — они читаются из `.env` через `flutter_dotenv`
(см. `lib/config/api_config.dart`). Файл `.env` **не коммитится**
(в `.gitignore`), в репозитории лежит только шаблон.

```bash
cp .env.example .env
# затем отредактируйте .env под своё окружение
```

Переменные:

| Переменная      | Назначение                              | Пример для Android-эмулятора |
|-----------------|-------------------------------------------|-------------------------------|
| `API_BASE_URL`  | Базовый URL FastAPI-бэкенда (`/api/v1`)   | `http://10.0.2.2:8000/api/v1` |

Если `.env` отсутствует, приложение не падает — используется дефолтный
адрес для Android-эмулятора (см. `ApiConfig`). Для iOS-симулятора и
реальных устройств адрес почти наверняка нужно поменять (см. комментарии
в `.env.example`).

**Никогда не коммитьте реальный `.env`, ключи, токены доступа и т.п.** Если
случайно закоммитили секрет — считайте его скомпрометированным: смените
значение/отзовите токен на стороне сервиса, а не просто удаляйте из
следующего коммита (история git его сохранит).

## Кодогенерация (ObjectBox)

Модели БД (`lib/models/models.dart`) генерируют `lib/objectbox.g.dart` и
обновляют `lib/objectbox-model.json`. Перегенерировать нужно после любого
изменения `@Entity()`-классов:

```bash
fvm flutter pub run build_runner build --delete-conflicting-outputs
```

Оба сгенерированных файла коммитятся в git — `objectbox-model.json` хранит
стабильные ID полей между миграциями схемы базы, его нельзя добавлять в
`.gitignore` и нельзя удалять вручную.

## Запуск в режиме разработки

```bash
fvm flutter devices          # посмотреть доступные устройства/эмуляторы
fvm flutter run              # запуск в debug на выбранном/единственном устройстве
fvm flutter run -d chrome     # запуск в браузере (web)
fvm flutter run -d macos      # запуск нативного macOS-приложения
```

## Сборки

### Android

```bash
# Debug APK (для разработки/тестирования)
fvm flutter build apk --debug

# Release APK
fvm flutter build apk --release

# Release App Bundle (для публикации в Google Play)
fvm flutter build appbundle --release
```

> Перед публикацией в Google Play замените `applicationId` в
> `android/app/build.gradle.kts` (сейчас `com.example.finance_app_mobile` —
> шаблонное значение) и настройте боевой ключ подписи вместо debug-ключа,
> которым сейчас подписывается release-сборка (см. `signingConfig` там же).
> Ключ подписи и его пароли храните вне репозитория — например,
> `android/key.properties` (уже в `.gitignore`) и переменные окружения CI.

### iOS

```bash
# Установить/обновить CocoaPods-зависимости (обычно делает flutter run/build сам)
cd ios && pod install && cd ..

# Debug-сборка для симулятора
fvm flutter build ios --debug --simulator

# Release-сборка (нужен подключённый Apple Developer аккаунт и провижининг в Xcode)
fvm flutter build ios --release

# IPA для распространения (TestFlight/App Store)
fvm flutter build ipa --release
```

Подпись/провижининг для iOS настраивается в Xcode
(`ios/Runner.xcworkspace` → Signing & Capabilities), а не в коде.

### macOS / Windows / Linux (desktop)

```bash
fvm flutter build macos --release
fvm flutter build windows --release
fvm flutter build linux --release
```

### Web

```bash
fvm flutter build web --release
```

## Обновление и очистка

```bash
# Обновить зависимости в рамках ограничений pubspec.yaml
fvm flutter pub upgrade

# Проверить, какие зависимости отстают от последних версий
fvm flutter pub outdated

# Полная очистка артефактов сборки и кешей (build/, .dart_tool/)
fvm flutter clean

# После clean зависимости и кодогенерацию нужно подтянуть заново
fvm flutter pub get
fvm flutter pub run build_runner build --delete-conflicting-outputs
```

Для полной пересборки iOS/Android с нуля (если проблемы со сборкой не
решаются `flutter clean`):

```bash
# iOS: пересобрать CocoaPods
cd ios && rm -rf Pods Podfile.lock && pod install && cd ..

# Android: сбросить Gradle-кэш проекта
cd android && ./gradlew clean && cd ..
```

## Тесты и статический анализ

```bash
fvm flutter analyze     # статический анализ (lints)
fvm flutter test        # unit/widget-тесты
```

`flutter test` запускает виджет-тесты на хостовой машине (не на
эмуляторе), а ObjectBox использует нативную библиотеку — для macOS/Linux/
Windows её нужно один раз установить отдельно (не через `pub get`):

```bash
bash <(curl -s https://raw.githubusercontent.com/objectbox/objectbox-dart/main/install.sh)
```

Без этого шага `fvm flutter test` упадёт с ошибкой загрузки
`libobjectbox` — это ожидаемо на чистой машине и не связано с багами в коде.

## Структура проекта

Подробности в [ARCHITECTURE.md](ARCHITECTURE.md): слои, правила импортов
(в частности — почему `screens/` и `services/` не должны импортировать
`main.dart`), список известных недоделок (заглушка авторизации, статичные
инсайты и т.д.).

## Безопасность / работа с репозиторием

- Секреты — только через `.env` (см. выше), никогда не в коде и не в
  коммитах.
- Если нужно поделиться доступом к бэкенду для локальной разработки,
  передавайте `.env` вне git (менеджер паролей, защищённый чат) — не
  добавляйте его в `.gitignore`-исключения и не коммитьте "временно".
- `objectbox-model.json` и `objectbox.g.dart` — коммитить всегда,
  остальные сгенерированные артефакты (`build/`, `.dart_tool/`, Pods,
  Gradle-кэш, `.idea/`) — никогда (см. `.gitignore`).

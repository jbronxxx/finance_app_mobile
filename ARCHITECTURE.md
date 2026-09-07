# Архитектура Family Budget (finance_app_mobile)

Кроссплатформенное Flutter-приложение для учёта личных/семейных финансов.
Работает офлайн-first: все данные сначала пишутся в локальную базу на
устройстве, синхронизация с бэкендом — отдельный, пока частично
реализованный слой.

## Технологический стек

| Слой              | Технология                              |
|-------------------|------------------------------------------|
| UI                | Flutter (Material 3)                      |
| Локальное хранилище | [ObjectBox](https://objectbox.io/) (NoSQL, встроенная БД) |
| Сетевой клиент     | [Dio](https://pub.dev/packages/dio)       |
| Конфигурация       | [flutter_dotenv](https://pub.dev/packages/flutter_dotenv) (`.env`) |
| Управление версией SDK | [FVM](https://fvm.app/) (см. `.fvmrc`, Flutter 3.29.3) |

Бэкенд (FastAPI) в этот репозиторий не входит — приложение общается с ним
только по REST API, описанному в `lib/config/api_config.dart`.

## Структура `lib/`

```
lib/
├── main.dart                    # Точка входа: .env -> локальная БД -> runApp
├── config/
│   └── api_config.dart          # Адрес бэкенда (.env) и пути эндпоинтов
├── models/
│   └── models.dart               # Transaction, Budget, enum Category/TransactionType
├── services/
│   ├── local_db_service.dart    # Доступ к ObjectBox (singleton LocalDbService.instance)
│   └── api_service.dart          # Синхронизация с FastAPI-бэкендом (Dio)
└── screens/
    ├── main_shell.dart            # Нижняя навигация + состояние авторизации
    ├── dashboard_screen.dart      # Баланс, список операций за период
    ├── add_transaction_sheet.dart # Форма добавления/редактирования операции
    ├── budgets_screen.dart        # Лимиты бюджета по категориям
    ├── insights_screen.dart       # AI-инсайты (пока статичные демо-данные)
    ├── profile_screen.dart        # Профиль пользователя, статус синхронизации
    ├── settings_screen.dart       # Настройки (тема/валюта/уведомления)
    └── auth_screen.dart           # Вход/регистрация (пока UI-заглушка)
```

## Правила зависимостей между слоями

```
screens/  --->  services/  --->  models/
screens/  --->  models/
services/ --->  config/
main.dart --->  services/, screens/
```

Экраны и сервисы **никогда** не импортируют `main.dart`. Раньше это было не
так: глобальный объект `dbService` жил прямо в `main.dart`, и экраны
(`dashboard_screen.dart`, `budgets_screen.dart`, `add_transaction_sheet.dart`)
импортировали его оттуда — получался цикл `main.dart -> screens/... ->
main.dart`. Это было исправлено переносом состояния БД в сам
`LocalDbService` (статическое поле `LocalDbService.instance`,
инициализируется в `main()` через `LocalDbService.init()`). Придерживайтесь
этого правила при добавлении новых сервисов/глобального состояния — не
кладите его в `main.dart`.

## Локальное хранилище и синхронизация

- `Transaction` и `Budget` — сущности ObjectBox (`@Entity()`), схема
  описана в `lib/objectbox-model.json` и генерируется в
  `lib/objectbox.g.dart` (см. раздел "Кодогенерация" в README). Оба файла
  коммитятся в git — `objectbox-model.json` хранит стабильные ID полей
  между миграциями схемы, терять его нельзя.
- Поле `serverId` в обеих моделях — `null`, пока запись не отправлена на
  бэкенд. `LocalDbService.getUnsyncedTransactions()` возвращает то, что
  ещё предстоит выгрузить.
- `ApiService.syncLocalDataToBackend()` — единственная точка выгрузки
  локальных данных на сервер (эндпоинт `/sync`), вызывается один раз после
  успешного входа/регистрации.

## Известные ограничения / точки роста (важно для дальнейшей разработки)

Эти моменты — не баги в смысле "что-то сломано", а осознанно
незакрытые части функциональности. Оставлены как есть, чтобы не
придумывать бизнес-логику за product-owner'а:

1. **Авторизация — заглушка.** `AuthScreen` ничего не отправляет на
   бэкенд: просто валидирует поля и возвращает введённые email/имя.
   Реальный вызов `/auth/login` и `/auth/register` (см. `ApiConfig`) ещё
   предстоит подключить, как и последующий вызов
   `ApiService.syncLocalDataToBackend`.
2. **Синхронизация в профиле — имитация.** `ProfileScreen._startSync()`
   делает `Future.delayed(2s)` вместо реального запроса.
3. **AI-инсайты — статичный текст.** `InsightsScreen` не обращается к
   `/insights`.
4. **Настройки не сохраняются.** Переключатели в `SettingsScreen` живут
   только в памяти виджета и сбрасываются при перезапуске.
5. **"Очистить локальный кэш" ничего не чистит** — кнопка в
   `SettingsScreen` только показывает уведомление. Перед реальной
   реализацией нужно диалоговое подтверждение — операция необратимая.
6. **Android release собирается debug-ключом подписи**
   (`android/app/build.gradle.kts`) и `applicationId`/bundle id всё ещё
   `com.example.finance_app_mobile` — стандартные TODO из шаблона
   `flutter create`, которые нужно заменить перед публикацией в сторы.
7. **`getSpentForCategory`** в `LocalDbService` сканирует все транзакции
   линейно — приемлемо для личного бюджета, но при росте данных стоит
   заменить на `Box.query` с фильтрами по индексируемым полям.

## Конфигурация и секреты

Секретов в коде нет и быть не должно. Адрес бэкенда читается из `.env`
(см. `README.md` → "Переменные окружения"). Раньше `ApiService` и
`ApiConfig` использовали два разных, рассинхронизированных URL — теперь
единственный источник правды — `ApiConfig.baseUrl`.

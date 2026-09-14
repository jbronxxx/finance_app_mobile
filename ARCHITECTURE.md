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
├── main.dart                    # Точка входа: .env -> локальная БД -> ApiService.init -> runApp
├── config/
│   └── api_config.dart          # Конфигурация бэкенда (эндпоинты и базовый URL)
├── models/
│   ├── auth_model.dart          # DTO для авторизации (Login, Register, Me)
│   ├── budget_model.dart        # DTO для бюджетов
│   ├── transaction_model.dart   # DTO для транзакций
│   ├── sync_model.dart          # Модель для пакетной синхронизации
│   └── local_db_models.dart     # Сущности ObjectBox (Transaction, Budget)
├── services/
│   ├── local_db_service.dart    # Доступ к ObjectBox (singleton)
│   ├── api_service.dart          # Клиент API (Dio, JWT, Refresh Token, Sync)
│   └── pending_deletions_store.dart # Очередь отложенных удалений
└── screens/
    ├── main_shell.dart            # Каркас с навигацией и слушателем сессии
    ├── dashboard_screen.dart      # Баланс и список операций
    ├── add_transaction_sheet.dart # Форма добавления транзакции
    ├── budgets_screen.dart        # Лимиты бюджета
    ├── insights_screen.dart       # AI-инсайты (заглушка)
    ├── profile_screen.dart        # Профиль и ручная синхронизация
    ├── settings_screen.dart       # Настройки
    └── auth_screen.dart           # Вход и регистрация (реализовано)
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

## Авторизация и безопасность

- **JWT-авторизация**: Используется пара `access_token` и `refresh_token`.
- **Хранение**: Токены сохраняются в `FlutterSecureStorage`.
- **Автообновление**: Реализован `InterceptorsWrapper` в Dio, который при получении `401` пытается обновить токены через `/auth/refresh`. При неудаче (рефреш протух) сессия сбрасывается.
- **Слушатель сессии**: `MainShell` подписывается на `ApiService.authStream` и автоматически перенаправляет на `/login` при потере авторизации.

## Локальное хранилище и синхронизация

- `Transaction` и `Budget` — сущности ObjectBox (`@Entity()`).
- **Синхронизация**: Двусторонняя (push/pull).
  - `syncLocalDataToBackend`: Отправляет локальные записи без `serverId`.
  - `syncBackendDataToLocal`: Загружает актуальные данные с сервера и сверяет с локальными.
  - `PendingDeletionsStore`: Хранит ID удаленных локально транзакций, чтобы повторить удаление на сервере при появлении сети.

## Известные ограничения

1. **AI-инсайты — статичный текст.** `InsightsScreen` пока не обращается к эндпоинту `/insights`.
2. **Настройки не сохраняются.** Выбор в `SettingsScreen` живет только в памяти виджета.
3. **Android release**: Используется стандартный debug-ключ.
4. **`getSpentForCategory`**: Линейное сканирование транзакций в `LocalDbService`.


## Конфигурация и секреты

Секретов в коде нет и быть не должно. Адрес бэкенда читается из `.env`
(см. `README.md` → "Переменные окружения"). Раньше `ApiService` и
`ApiConfig` использовали два разных, рассинхронизированных URL — теперь
единственный источник правды — `ApiConfig.baseUrl`.

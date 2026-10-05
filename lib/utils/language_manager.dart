import 'package:getbalanceai_mobile/services/services.dart';
import 'package:flutter/material.dart';

enum AppLanguage {
  ru('ru', 'Русский', '🇷🇺'),
  uz('uz', "O'zbekcha", '🇺🇿'),
  en('en', 'English', '🇬🇧');

  final String code;
  final String displayName;
  final String flag;

  const AppLanguage(this.code, this.displayName, this.flag);
}

class LanguageManager {
  static AppLanguage _currentLanguage = AppLanguage.ru;

  static final ValueNotifier<AppLanguage> languageNotifier =
      ValueNotifier(AppLanguage.ru);

  static void setLanguage(AppLanguage language) {
    _currentLanguage = language;
    languageNotifier.value = language;
    PreferencesService.instance.saveLanguage(language.code);
  }

  static Future<void> loadSavedLanguage() async {
    final code = await PreferencesService.instance.getLanguage();
    if (code != null) {
      try {
        final saved = AppLanguage.values.firstWhere((l) => l.code == code);
        _currentLanguage = saved;
        languageNotifier.value = saved;
      } catch (_) {}
    }
  }

  static AppLanguage get currentLanguage => _currentLanguage;
  static String get code => _currentLanguage.code;

  /// Все переводы для приложения на трех языках
  static final Map<String, Map<AppLanguage, String>> _localizedValues = {
    // Вкладки и общие элементы
    'balance': {
      AppLanguage.ru: 'Баланс',
      AppLanguage.uz: 'Balans',
      AppLanguage.en: 'Balance'
    },
    'limits': {
      AppLanguage.ru: 'Лимиты',
      AppLanguage.uz: 'Limitlar',
      AppLanguage.en: 'Budgets'
    },
    'insights': {
      AppLanguage.ru: 'Инсайты',
      AppLanguage.uz: 'Insaytlar',
      AppLanguage.en: 'Insights'
    },
    'profile': {
      AppLanguage.ru: 'Профиль',
      AppLanguage.uz: 'Profil',
      AppLanguage.en: 'Profile'
    },
    'interface': {
      AppLanguage.ru: 'Интерфейс',
      AppLanguage.uz: 'Interfeys',
      AppLanguage.en: 'Interface'
    },
    'currency': {
      AppLanguage.ru: 'Валюта',
      AppLanguage.uz: 'Valyuta',
      AppLanguage.en: 'Currency'
    },
    'language': {
      AppLanguage.ru: 'Язык приложения',
      AppLanguage.uz: 'Ilova tili',
      AppLanguage.en: 'App Language'
    },
    'select_language': {
      AppLanguage.ru: 'Выбор языка',
      AppLanguage.uz: 'Tilni tanlash',
      AppLanguage.en: 'Select Language'
    },
    'dark_mode': {
      AppLanguage.ru: 'Темная тема',
      AppLanguage.uz: 'Tungi rejim',
      AppLanguage.en: 'Dark Mode'
    },
    'soon': {
      AppLanguage.ru: 'Скоро появится',
      AppLanguage.uz: 'Yaqinda qo\'shiladi',
      AppLanguage.en: 'Coming soon'
    },
    'notifications': {
      AppLanguage.ru: 'Уведомления',
      AppLanguage.uz: 'Bildirishnomalar',
      AppLanguage.en: 'Notifications'
    },
    'limits_and_budgets': {
      AppLanguage.ru: 'Лимиты и бюджеты',
      AppLanguage.uz: 'Limit va budjetlar',
      AppLanguage.en: 'Limits and budgets'
    },
    'cloud': {
      AppLanguage.ru: 'Облако',
      AppLanguage.uz: 'Bulut',
      AppLanguage.en: 'Cloud'
    },
    'sync_status': {
      AppLanguage.ru: 'Статус синхронизации',
      AppLanguage.uz: 'Sinxronizatsiya holati',
      AppLanguage.en: 'Sync Status'
    },
    'cloud_not_connected': {
      AppLanguage.ru: 'Облако не подключено',
      AppLanguage.uz: 'Bulutga ulanmagan',
      AppLanguage.en: 'Cloud not connected'
    },
    'guest_mode': {
      AppLanguage.ru: 'Гостевой режим',
      AppLanguage.uz: 'Mehmon rejimi',
      AppLanguage.en: 'Guest Mode'
    },
    'login_cloud_hint': {
      AppLanguage.ru: 'Войдите, чтобы сохранять данные в облаке',
      AppLanguage.uz: 'Ma\'lumotlarni bulutda saqlash uchun kiring',
      AppLanguage.en: 'Log in to save data to the cloud'
    },
    'logout': {
      AppLanguage.ru: 'Выйти из аккаунта',
      AppLanguage.uz: 'Hisobdan chiqish',
      AppLanguage.en: 'Log Out'
    },
    'login_or_register': {
      AppLanguage.ru: 'Войти или создать аккаунт',
      AppLanguage.uz: 'Kirish yoki ro\'yxatdan o\'tish',
      AppLanguage.en: 'Log In or Register'
    },
    'user': {
      AppLanguage.ru: 'Пользователь',
      AppLanguage.uz: 'Foydalanuvchi',
      AppLanguage.en: 'User'
    },

    // Смена валют
    'select_currency': {
      AppLanguage.ru: 'Выбор валюты',
      AppLanguage.uz: 'Valyutani tanlash',
      AppLanguage.en: 'Select Currency'
    },
    'uzs_name': {
      AppLanguage.ru: 'Узбекский сум',
      AppLanguage.uz: "O'zbek so'mi",
      AppLanguage.en: 'Uzbek Som'
    },
    'kzt_name': {
      AppLanguage.ru: 'Казахстанский тенге',
      AppLanguage.uz: 'Qozog\'iston tengesi',
      AppLanguage.en: 'Kazakhstani Tenge'
    },
    'rub_name': {
      AppLanguage.ru: 'Российский рубль',
      AppLanguage.uz: 'Rossiya rubli',
      AppLanguage.en: 'Russian Ruble'
    },
    'eur_name': {
      AppLanguage.ru: 'Евро',
      AppLanguage.uz: 'Evro',
      AppLanguage.en: 'Euro'
    },
    'usd_name': {
      AppLanguage.ru: 'Доллар США',
      AppLanguage.uz: 'AQSh dollari',
      AppLanguage.en: 'US Dollar'
    },

    // Диалоги / Алерты / Кнопки действий
    'cancel': {
      AppLanguage.ru: 'Отмена',
      AppLanguage.uz: 'Bekor qilish',
      AppLanguage.en: 'Cancel'
    },
    'logout_confirm_title': {
      AppLanguage.ru: 'Выход',
      AppLanguage.uz: 'Chiqish',
      AppLanguage.en: 'Log Out'
    },
    'logout_confirm_desc': {
      AppLanguage.ru: 'Вы уверены, что хотите выйти из аккаунта?',
      AppLanguage.uz: 'Hisobingizdan chiqmoqchimisiz?',
      AppLanguage.en: 'Are you sure you want to log out?'
    },
    'syncing': {
      AppLanguage.ru: 'Синхронизация...',
      AppLanguage.uz: 'Sinxronizatsiya...',
      AppLanguage.en: 'Syncing...'
    },
    'sync_success': {
      AppLanguage.ru: 'Данные успешно синхронизированы',
      AppLanguage.uz: 'Ma\'lumotlar muvaffaqiyatli sinxronlandi',
      AppLanguage.en: 'Data synced successfully'
    },
    'sync_updated_just_now': {
      AppLanguage.ru: 'Обновлено только что',
      AppLanguage.uz: 'Hozirgina yangilandi',
      AppLanguage.en: 'Updated just now'
    },
    'sync_no_internet': {
      AppLanguage.ru: 'Нет сети',
      AppLanguage.uz: 'Tarmoq yo\'q',
      AppLanguage.en: 'No Network'
    },
    'no_internet_connection': {
      AppLanguage.ru:
          'Нет подключения к интернету. Проверьте сеть и повторите попытку.',
      AppLanguage.uz:
          'Internetga ulanish yo\'q. Tarmoqni tekshirib, qayta urinib ko\'ring.',
      AppLanguage.en:
          'No internet connection. Please check your network and try again.'
    },
    'sync_no_internet_alert': {
      AppLanguage.ru: 'Для синхронизации нужно подключение к сети',
      AppLanguage.uz: 'Sinxronizatsiya uchun tarmoqqa ulanish zarur',
      AppLanguage.en: 'Network connection is required for sync'
    },
    'sync_error': {
      AppLanguage.ru: 'Ошибка синхронизации',
      AppLanguage.uz: 'Sinxronizatsiya xatoligi',
      AppLanguage.en: 'Sync Error'
    },
    'logout_info': {
      AppLanguage.ru: 'Вы вышли из системы',
      AppLanguage.uz: 'Tizimdan chiqdingiz',
      AppLanguage.en: 'Logged out successfully'
    },
    'logout_error_title': {
      AppLanguage.ru: 'Ошибка при выходе',
      AppLanguage.uz: 'Chiqishda xatolik',
      AppLanguage.en: 'Error logging out'
    },
    'transaction_deleted': {
      AppLanguage.ru: 'Запись удалена',
      AppLanguage.uz: 'Yozuv o\'chirildi',
      AppLanguage.en: 'Transaction deleted'
    },

    // Приветственный экран первого запуска
    'welcome_lang_title': {
      AppLanguage.ru: 'Выберите язык / Tanlang',
      AppLanguage.uz: 'Tilni tanlang / Choose Language',
      AppLanguage.en: 'Select Language / Выберите язык'
    },
    'welcome_lang_subtitle': {
      AppLanguage.ru: 'Для комфортной работы с приложением',
      AppLanguage.uz: 'Ilovadan qulay foydalanish uchun',
      AppLanguage.en: 'For a comfortable experience with the app'
    },
    'continue_btn': {
      AppLanguage.ru: 'Продолжить',
      AppLanguage.uz: 'Davom etish',
      AppLanguage.en: 'Continue'
    },

    // Главный экран (Dashboard)
    'total_balance': {
      AppLanguage.ru: 'Общий баланс',
      AppLanguage.uz: 'Umumiy balans',
      AppLanguage.en: 'Total Balance'
    },
    'expense_title': {
      AppLanguage.ru: 'Расход',
      AppLanguage.uz: 'Xarajat',
      AppLanguage.en: 'Expense'
    },
    'income_title': {
      AppLanguage.ru: 'Доход',
      AppLanguage.uz: 'Daromad',
      AppLanguage.en: 'Income'
    },
    'no_transactions': {
      AppLanguage.ru: 'Нет записей за этот месяц',
      AppLanguage.uz: 'Bu oyda yozuvlar yo\'q',
      AppLanguage.en: 'No transactions for this month'
    },
    'all_months': {
      AppLanguage.ru: 'Все месяцы',
      AppLanguage.uz: 'Barcha oylar',
      AppLanguage.en: 'All Months'
    },
    'swipe_hint_text': {
      AppLanguage.ru: 'Смахните операцию влево, чтобы удалить её',
      AppLanguage.uz: 'O\'chirish uchun yozuvni chapga suring',
      AppLanguage.en: 'Swipe left to delete a transaction'
    },
    'delete_confirm_title': {
      AppLanguage.ru: 'Удаление',
      AppLanguage.uz: 'O\'chirish',
      AppLanguage.en: 'Delete'
    },
    'delete_confirm_desc': {
      AppLanguage.ru: 'Вы уверены, что хотите удалить эту запись?',
      AppLanguage.uz: 'Ushbu yozuvni o\'chirmoqchimisiz?',
      AppLanguage.en: 'Are you sure you want to delete this transaction?'
    },
    'delete_btn': {
      AppLanguage.ru: 'Удалить',
      AppLanguage.uz: 'O\'chirish',
      AppLanguage.en: 'Delete'
    },
    'today_prefix': {
      AppLanguage.ru: 'Сегодня',
      AppLanguage.uz: 'Bugun',
      AppLanguage.en: 'Today'
    },

    // Боттомшит Новая запись
    'new_transaction': {
      AppLanguage.ru: 'Новая запись',
      AppLanguage.uz: 'Yangi yozuv',
      AppLanguage.en: 'New Transaction'
    },
    'edit_transaction': {
      AppLanguage.ru: 'Редактировать запись',
      AppLanguage.uz: 'Yozuvni tahrirlash',
      AppLanguage.en: 'Edit Transaction'
    },
    'amount_label': {
      AppLanguage.ru: 'Сумма',
      AppLanguage.uz: 'Summa',
      AppLanguage.en: 'Amount'
    },
    'category_label': {
      AppLanguage.ru: 'Категория',
      AppLanguage.uz: 'Kategoriya',
      AppLanguage.en: 'Category'
    },
    'description_label': {
      AppLanguage.ru: 'Описание (необязательно)',
      AppLanguage.uz: 'Tavsif (ixtiyoriy)',
      AppLanguage.en: 'Description (optional)'
    },
    'add_btn': {
      AppLanguage.ru: 'Добавить запись',
      AppLanguage.uz: 'Yozuvni qo\'shish',
      AppLanguage.en: 'Add Transaction'
    },
    'save_changes_btn': {
      AppLanguage.ru: 'Сохранить изменения',
      AppLanguage.uz: 'O\'zgarishlarni saqlash',
      AppLanguage.en: 'Save Changes'
    },
    'alert_valid_amount': {
      AppLanguage.ru: 'Введите корректную сумму',
      AppLanguage.uz: 'To\'g\'ri summani kiriting',
      AppLanguage.en: 'Enter a valid amount'
    },
    'alert_amount_too_large': {
      AppLanguage.ru: 'Сумма слишком велика для',
      AppLanguage.uz: 'Summa juda katta, valyuta:',
      AppLanguage.en: 'Amount is too large for'
    },

    // Экран бюджетов и лимитов
    'budgets_title': {
      AppLanguage.ru: 'Лимиты расходов',
      AppLanguage.uz: 'Xarajatlar limitlari',
      AppLanguage.en: 'Expense Budgets'
    },
    'add_budget_title': {
      AppLanguage.ru: 'Лимит на бюджет',
      AppLanguage.uz: 'Budjet limiti',
      AppLanguage.en: 'Set Budget Limit'
    },
    'edit_budget_title': {
      AppLanguage.ru: 'Редактировать лимит',
      AppLanguage.uz: 'Limitni tahrirlash',
      AppLanguage.en: 'Edit Budget Limit'
    },
    'budget_amount_hint': {
      AppLanguage.ru: 'Сумма лимита',
      AppLanguage.uz: 'Limit summasi',
      AppLanguage.en: 'Limit Amount'
    },
    'save_btn': {
      AppLanguage.ru: 'Сохранить',
      AppLanguage.uz: 'Saqlash',
      AppLanguage.en: 'Save'
    },
    'budget_exceeded': {
      AppLanguage.ru: 'Превышен на',
      AppLanguage.uz: 'Ortiqcha xarajat:',
      AppLanguage.en: 'Exceeded by'
    },
    'budget_remaining': {
      AppLanguage.ru: 'Осталось',
      AppLanguage.uz: 'Qoldi',
      AppLanguage.en: 'Remaining'
    },
    'budget_spent': {
      AppLanguage.ru: 'Израсходовано',
      AppLanguage.uz: 'Sarflandi',
      AppLanguage.en: 'Spent'
    },
    'budget_out_of': {
      AppLanguage.ru: 'из',
      AppLanguage.uz: 'dan',
      AppLanguage.en: 'out of'
    },
    'no_budgets_title': {
      AppLanguage.ru: 'Бюджеты не установлены',
      AppLanguage.uz: 'Budjetlar belgilanmagan',
      AppLanguage.en: 'No Budgets Set'
    },
    'no_budgets_subtitle': {
      AppLanguage.ru:
          'Установите лимиты по категориям, чтобы контролировать перерасход средств.',
      AppLanguage.uz:
          'Mablag\'larni nazorat qilish uchun kategoriyalar bo\'yicha limitlar belgilang.',
      AppLanguage.en: 'Set limits by category to avoid overspending.'
    },
    'alert_enter_budget_amount': {
      AppLanguage.ru: 'Введите сумму лимита',
      AppLanguage.uz: 'Limit summasi kiriting',
      AppLanguage.en: 'Please enter a limit amount'
    },

    // Экран Инсайтов
    'insights_screen_title': {
      AppLanguage.ru: 'Аналитика и инсайты',
      AppLanguage.uz: 'Tahlil va insaytlar',
      AppLanguage.en: 'Analytics & Insights'
    },
    'insights_subtitle': {
      AppLanguage.ru: 'Умный анализ ваших финансов',
      AppLanguage.uz: 'Moliyangizning aqlli tahlili',
      AppLanguage.en: 'Smart analysis of your finances'
    },
    'insight_advice_title': {
      AppLanguage.ru: 'Финансовый совет',
      AppLanguage.uz: 'Moliyaviy maslahat',
      AppLanguage.en: 'Financial Advice'
    },
    'insight_advice_desc': {
      AppLanguage.ru:
          'Старайтесь откладывать не менее 10-15% от доходов сразу в день их получения, формируя подушку безопасности.',
      AppLanguage.uz:
          'Daromad olgan kuningiz darhol kamida 10-15% qismini xavfsizlik yostig\'i uchun olib qo\'yishga harakat qiling.',
      AppLanguage.en:
          'Try to save at least 10-15% of your income on the day you receive it to build an emergency fund.'
    },
    'insight_structure_title': {
      AppLanguage.ru: 'Структура расходов за месяц',
      AppLanguage.uz: 'Bir oylik xarajatlar tarkibi',
      AppLanguage.en: 'Monthly Expense Structure'
    },
    'insight_structure_empty': {
      AppLanguage.ru:
          'Недостаточно данных для анализа расходов. Добавьте транзакции.',
      AppLanguage.uz:
          'Xarajatlar tahlili uchun ma\'lumot yetarli emas. Yozuvlar qo\'shing.',
      AppLanguage.en:
          'Not enough data for expense analysis. Please add transactions.'
    },
    'insight_saving_title': {
      AppLanguage.ru: 'Уровень сбережений',
      AppLanguage.uz: 'Jamg\'arma darajasi',
      AppLanguage.en: 'Savings Rate'
    },
    'insight_saving_desc_positive': {
      AppLanguage.ru:
          'Отличный результат! Вы откладываете средства. Продолжайте в том же духе для достижения долгосрочных целей.',
      AppLanguage.uz:
          'Ajoyib natija! Siz pul jamg\'armoqdasiz. Uzoq muddatli maqsadlarga erishish uchun shu tarzda davom eting.',
      AppLanguage.en:
          'Great job! You are saving money. Keep it up to reach your long-term goals.'
    },
    'insight_saving_desc_negative': {
      AppLanguage.ru:
          'В этом месяце ваши расходы превысили доходы. Рекомендуем пересмотреть лимиты в необязательных категориях.',
      AppLanguage.uz:
          'Ushbu oyda xarajatlaringiz daromaddan oshib ketdi. Ixtiyoriy kategoriyalar limitlarini qayta ko\'rib chiqishni tavsiya etamiz.',
      AppLanguage.en:
          'This month your expenses exceeded your income. We recommend reviewing limits on non-essential categories.'
    },
    'insight_login_hint': {
      AppLanguage.ru:
          'Войдите в аккаунт, чтобы получить персональные рекомендации на основе ваших данных.',
      AppLanguage.uz:
          'Ma\'lumotlaringiz asosida shaxsiy tavsiyalarni olish uchun hisobga kiring.',
      AppLanguage.en:
          'Log in to get personalized recommendations based on your data.'
    },
    'insight_no_data': {
      AppLanguage.ru:
          'Пока недостаточно данных для анализа. Продолжайте записывать расходы!',
      AppLanguage.uz:
          'Tahlil uchun hozircha ma\'lumot yetarli emas. Xarajatlarni yozishda davom eting!',
      AppLanguage.en:
          'Not enough data for analysis yet. Keep recording expenses!'
    },
    'no_network_title': {
      AppLanguage.ru: 'Нет подключения к сети',
      AppLanguage.uz: 'Tarmoqqa ulanish yo\'q',
      AppLanguage.en: 'No internet connection'
    },
    'no_network_desc': {
      AppLanguage.ru:
          'Обновление инсайтов требует интернета. Проверьте соединение и потяните экран вниз для повтора.',
      AppLanguage.uz:
          'Insaytlarni yangilash uchun internet zarur. Ulanishni tekshiring vacancies ekranni pastga torting.',
      AppLanguage.en:
          'Updating insights requires internet. Check your connection and pull down to retry.'
    },
    'insights_header_title': {
      AppLanguage.ru: 'AI-Инсайты и Аналитика',
      AppLanguage.uz: 'AI-Insaytlar va Tahlil',
      AppLanguage.en: 'AI Insights & Analytics'
    },
    'insights_header_subtitle': {
      AppLanguage.ru: 'Умный анализ ваших финансов на базе ИИ',
      AppLanguage.uz: 'Moliyangizning aqlli tahlili (AI)',
      AppLanguage.en: 'Smart analysis of your finances powered by AI'
    },
    'personal_recs_title': {
      AppLanguage.ru: 'Персональные рекомендации',
      AppLanguage.uz: 'Shaxsiy tavsiyalar',
      AppLanguage.en: 'Personalized Recommendations'
    },
    'insights_updated_prefix': {
      AppLanguage.ru: 'Обновлено',
      AppLanguage.uz: 'Yangilangan',
      AppLanguage.en: 'Updated'
    },
    'insights_cache_hint': {
      AppLanguage.ru:
          'Советы обновляются автоматически при добавлении новых расходов',
      AppLanguage.uz:
          'Maslahatlar yangi xarajatlar qo\'shilganda avtomatik ravishda yangilanadi',
      AppLanguage.en:
          'Insights update automatically when new expenses are added'
    },

    // Месяцы и время
    'month_1': {
      AppLanguage.ru: 'Январь',
      AppLanguage.uz: 'Yanvar',
      AppLanguage.en: 'January'
    },
    'month_2': {
      AppLanguage.ru: 'Февраль',
      AppLanguage.uz: 'Fevral',
      AppLanguage.en: 'February'
    },
    'month_3': {
      AppLanguage.ru: 'Март',
      AppLanguage.uz: 'Mart',
      AppLanguage.en: 'March'
    },
    'month_4': {
      AppLanguage.ru: 'Апрель',
      AppLanguage.uz: 'Aprel',
      AppLanguage.en: 'April'
    },
    'month_5': {
      AppLanguage.ru: 'Май',
      AppLanguage.uz: 'May',
      AppLanguage.en: 'May'
    },
    'month_6': {
      AppLanguage.ru: 'Июнь',
      AppLanguage.uz: 'Iyun',
      AppLanguage.en: 'June'
    },
    'month_7': {
      AppLanguage.ru: 'Июль',
      AppLanguage.uz: 'Iyul',
      AppLanguage.en: 'July'
    },
    'month_8': {
      AppLanguage.ru: 'Август',
      AppLanguage.uz: 'Avgust',
      AppLanguage.en: 'August'
    },
    'month_9': {
      AppLanguage.ru: 'Сентябрь',
      AppLanguage.uz: 'Sentabr',
      AppLanguage.en: 'September'
    },
    'month_10': {
      AppLanguage.ru: 'Октябрь',
      AppLanguage.uz: 'Oktabr',
      AppLanguage.en: 'October'
    },
    'month_11': {
      AppLanguage.ru: 'Ноябрь',
      AppLanguage.uz: 'Noyabr',
      AppLanguage.en: 'November'
    },
    'month_12': {
      AppLanguage.ru: 'Декабрь',
      AppLanguage.uz: 'Dekabr',
      AppLanguage.en: 'December'
    },
    'select_period': {
      AppLanguage.ru: 'Выберите период',
      AppLanguage.uz: 'Davrni tanlang',
      AppLanguage.en: 'Select Period'
    },
    'month_label': {
      AppLanguage.ru: 'Месяц',
      AppLanguage.uz: 'Oy',
      AppLanguage.en: 'Month'
    },
    'year_label': {
      AppLanguage.ru: 'Год',
      AppLanguage.uz: 'Yil',
      AppLanguage.en: 'Year'
    },
    'no_description': {
      AppLanguage.ru: 'Без описания',
      AppLanguage.uz: 'Tavsifsiz',
      AppLanguage.en: 'No description'
    },
    'today': {
      AppLanguage.ru: 'Сегодня',
      AppLanguage.uz: 'Bugun',
      AppLanguage.en: 'Today'
    },

    // Экран авторизации (Логин и Регистрация)
    'welcome_back': {
      AppLanguage.ru: 'С возвращением!',
      AppLanguage.uz: 'Qaytganingiz bilan!',
      AppLanguage.en: 'Welcome back!'
    },
    'create_account': {
      AppLanguage.ru: 'Создать аккаунт',
      AppLanguage.uz: 'Hisob yaratish',
      AppLanguage.en: 'Create Account'
    },
    'login_subtitle': {
      AppLanguage.ru: 'Войдите, чтобы синхронизировать данные с сервером',
      AppLanguage.uz: 'Ma\'lumotlarni server bilan sinxronlash uchun kiring',
      AppLanguage.en: 'Log in to sync data with the server'
    },
    'register_subtitle': {
      AppLanguage.ru: 'Зарегистрируйтесь для доступа к облачному хранилищу',
      AppLanguage.uz: 'Bulutli xotiraga kirish uchun ro\'yxatdan o\'ting',
      AppLanguage.en: 'Register for access to cloud storage'
    },
    'name_label': {
      AppLanguage.ru: 'Имя',
      AppLanguage.uz: 'Ism',
      AppLanguage.en: 'Name'
    },
    'email_label': {
      AppLanguage.ru: 'Email',
      AppLanguage.uz: 'Email',
      AppLanguage.en: 'Email'
    },
    'password_label': {
      AppLanguage.ru: 'Пароль',
      AppLanguage.uz: 'Parol',
      AppLanguage.en: 'Password'
    },
    'login_btn': {
      AppLanguage.ru: 'Войти',
      AppLanguage.uz: 'Kirish',
      AppLanguage.en: 'Log In'
    },
    'register_btn': {
      AppLanguage.ru: 'Зарегистрироваться',
      AppLanguage.uz: 'Ro\'yxatdan o\'tish',
      AppLanguage.en: 'Register'
    },
    'no_account_prompt': {
      AppLanguage.ru: 'Нет аккаунта? Зарегистрируйтесь',
      AppLanguage.uz: 'Hisobingiz yo\'qmi? Ro\'yxatdan o\'ting',
      AppLanguage.en: 'Don\'t have an account? Register'
    },
    'have_account_prompt': {
      AppLanguage.ru: 'Уже есть аккаунт? Войдите',
      AppLanguage.uz: 'Sizda hisob bormi? Kiring',
      AppLanguage.en: 'Already have an account? Log In'
    },
    'fill_all_fields': {
      AppLanguage.ru: 'Заполните все поля',
      AppLanguage.uz: 'Barcha maydonlarni to\'ldiring',
      AppLanguage.en: 'Fill in all fields'
    },
    'enter_name_alert': {
      AppLanguage.ru: 'Введите имя',
      AppLanguage.uz: 'Ismingizni kiriting',
      AppLanguage.en: 'Please enter your name'
    },
    'auth_network_required': {
      AppLanguage.ru:
          'Для входа или регистрации необходимо интернет-соединение',
      AppLanguage.uz:
          'Kirish yoki ro\'yxatdan o\'tish uchun tarmoqqa ulanish zarur',
      AppLanguage.en: 'Internet connection is required to log in or register'
    },
    'login_error_title': {
      AppLanguage.ru: 'Ошибка входа',
      AppLanguage.uz: 'Kirishda xatolik',
      AppLanguage.en: 'Login Error'
    },
    'register_error_title': {
      AppLanguage.ru: 'Ошибка регистрации',
      AppLanguage.uz: 'Ro\'yxatdan o\'tishda xatolik',
      AppLanguage.en: 'Registration Error'
    },
    'password_validation_error': {
      AppLanguage.ru:
          'Пароль должен содержать минимум 6 символов, включая минимум одну букву и одну цифру',
      AppLanguage.uz:
          'Parol kamida bitta harf va bitta raqamdan iborat kamida 6 belgidan iborat bo\'lishi kerak',
      AppLanguage.en:
          'Password must be at least 6 characters, including at least one letter and one number'
    },
    'password_requirements_hint': {
      AppLanguage.ru: 'Минимум 6 символов (1 буква и 1 цифра)',
      AppLanguage.uz: 'Kamida 6 belgi (1 harf va 1 raqam)',
      AppLanguage.en: 'Min 6 characters (1 letter and 1 number)'
    },
    'password_too_long_bytes': {
      AppLanguage.ru: 'Пароль слишком длинный (макс. 72 байта)',
      AppLanguage.uz: 'Parol juda uzun (maks. 72 bayt)',
      AppLanguage.en: 'Password is too long (max 72 bytes)'
    },
    'sync_login_required': {
      AppLanguage.ru: 'Войдите в аккаунт для синхронизации',
      AppLanguage.uz: 'Sinxronizatsiya uchun hisobga kiring',
      AppLanguage.en: 'Log in to sync'
    },
    'uzs_symbol': {
      AppLanguage.ru: 'сум',
      AppLanguage.uz: "so'm",
      AppLanguage.en: 'UZS'
    },

    // Категории
    'category_food': {
      AppLanguage.ru: 'Питание',
      AppLanguage.uz: 'Oziq-ovqat',
      AppLanguage.en: 'Food'
    },
    'category_transport': {
      AppLanguage.ru: 'Транспорт',
      AppLanguage.uz: 'Transport',
      AppLanguage.en: 'Transport'
    },
    'category_entertainment': {
      AppLanguage.ru: 'Развлечения',
      AppLanguage.uz: "O'yin-kulgi",
      AppLanguage.en: 'Entertainment'
    },
    'category_health': {
      AppLanguage.ru: 'Здоровье',
      AppLanguage.uz: "Sog'liq",
      AppLanguage.en: 'Health'
    },
    'category_subscriptions': {
      AppLanguage.ru: 'Подписки',
      AppLanguage.uz: 'Obunalar',
      AppLanguage.en: 'Subscriptions'
    },
    'category_shopping': {
      AppLanguage.ru: 'Покупки',
      AppLanguage.uz: 'Xaridlar',
      AppLanguage.en: 'Shopping'
    },
    'category_salary': {
      AppLanguage.ru: 'Зарплата',
      AppLanguage.uz: 'Maosh',
      AppLanguage.en: 'Salary'
    },
    'category_other': {
      AppLanguage.ru: 'Другое',
      AppLanguage.uz: 'Boshqa',
      AppLanguage.en: 'Other'
    },

    // Типы операций
    'type_income': {
      AppLanguage.ru: 'Доход',
      AppLanguage.uz: 'Daromad',
      AppLanguage.en: 'Income'
    },
    'type_expense': {
      AppLanguage.ru: 'Расход',
      AppLanguage.uz: 'Xarajat',
      AppLanguage.en: 'Expense'
    },

    // Алерты, диалоги, кнопки
    'dialog_ok': {
      AppLanguage.ru: 'Понятно',
      AppLanguage.uz: 'Tushunarli',
      AppLanguage.en: 'Got it'
    },
    'session_expired_title': {
      AppLanguage.ru: 'Сессия истекла',
      AppLanguage.uz: 'Sessiya tugadi',
      AppLanguage.en: 'Session Expired'
    },
    'session_expired_desc': {
      AppLanguage.ru:
          'Пожалуйста, войдите в аккаунт снова для продолжения работы.',
      AppLanguage.uz: 'Davom etish uchun hisobingizga qayta kiring.',
      AppLanguage.en: 'Please log in to your account again to continue.'
    },

    // Ошибки сервера и сети (AppErrorHandler)
    'server_error_general': {
      AppLanguage.ru: 'Произошла ошибка при связи с сервером',
      AppLanguage.uz: "Server bilan bog'lanishda xatolik yuz berdi",
      AppLanguage.en: 'An error occurred while communicating with the server'
    },
    'http_400': {
      AppLanguage.ru: 'Некорректный запрос',
      AppLanguage.uz: "Noto'g'ri so'rov",
      AppLanguage.en: 'Bad request'
    },
    'http_401': {
      AppLanguage.ru: 'Необходима авторизация',
      AppLanguage.uz: 'Avtorizatsiya talab qilinadi',
      AppLanguage.en: 'Authorization required'
    },
    'http_403': {
      AppLanguage.ru: 'Доступ запрещен',
      AppLanguage.uz: 'Ruxsat berilmagan',
      AppLanguage.en: 'Access forbidden'
    },
    'http_404': {
      AppLanguage.ru: 'Ресурс не найден',
      AppLanguage.uz: 'Manba topilmadi',
      AppLanguage.en: 'Resource not found'
    },
    'http_429': {
      AppLanguage.ru:
          'Превышен лимит запросов. Пожалуйста, повторите попытку позже.',
      AppLanguage.uz:
          'So‘rovlar chegarasi oshib ketdi. Iltimos, keyinroq qayta urinib ko‘ring.',
      AppLanguage.en: 'Too many requests. Please try again later.'
    },
    'rate_limit_exceeded_title': {
      AppLanguage.ru: 'Превышен лимит запросов',
      AppLanguage.uz: 'So‘rovlar chegarasi oshib ketdi',
      AppLanguage.en: 'Rate Limit Exceeded'
    },
    'rate_limit_retry_after': {
      AppLanguage.ru:
          'Пожалуйста, подождите {seconds} сек. перед повторной попыткой.',
      AppLanguage.uz:
          'Iltimos, qayta urinishdan oldin {seconds} soniya kuting.',
      AppLanguage.en: 'Please wait {seconds} sec before retrying.'
    },
    'rate_limit_countdown_prefix': {
      AppLanguage.ru: 'Повторите попытку через:',
      AppLanguage.uz: 'Qayta urinish vaqti:',
      AppLanguage.en: 'Retry in:'
    },
    'rate_limit_ready': {
      AppLanguage.ru: 'Вы можете повторить попытку прямо сейчас',
      AppLanguage.uz: 'Endi qayta urinib ko‘rishingiz mumkin',
      AppLanguage.en: 'You can retry now'
    },
    'http_500': {
      AppLanguage.ru: 'Внутренняя ошибка сервера',
      AppLanguage.uz: 'Serverning ichki xatoligi',
      AppLanguage.en: 'Internal server error'
    },
    'http_503': {
      AppLanguage.ru: 'Сервис временно недоступен. Ведутся технические работы',
      AppLanguage.uz:
          'Xizmat vaqtincha ishlamayapti. Texnik ishlar olib borilmoqda',
      AppLanguage.en: 'Service temporarily unavailable. Maintenance in progress'
    },
    'service_unavailable_title': {
      AppLanguage.ru: 'Сервис временно недоступен',
      AppLanguage.uz: 'Xizmat vaqtincha ishlamayapti',
      AppLanguage.en: 'Service Unavailable'
    },
    'service_unavailable_desc': {
      AppLanguage.ru:
          'Ведутся технические работы. Пожалуйста, повторите попытку позже.',
      AppLanguage.uz:
          'Texnik ishlar olib borilmoqda. Iltimos, keyinroq qayta urinib ko‘ring.',
      AppLanguage.en:
          'Technical maintenance in progress. Please try again later.'
    },
    'service_unavailable_retry': {
      AppLanguage.ru: 'Повторить попытку',
      AppLanguage.uz: 'Qayta urinish',
      AppLanguage.en: 'Try Again'
    },
    'server_error_code': {
      AppLanguage.ru: 'Ошибка сервера',
      AppLanguage.uz: 'Server xatoligi',
      AppLanguage.en: 'Server error'
    },
    'err_connection_timeout': {
      AppLanguage.ru: 'Превышено время ожидания соединения',
      AppLanguage.uz: 'Ulanish vaqti tugadi',
      AppLanguage.en: 'Connection timeout'
    },
    'err_send_timeout': {
      AppLanguage.ru: 'Превышено время отправки данных',
      AppLanguage.uz: "Ma'lumot jo'natish vaqti tugadi",
      AppLanguage.en: 'Send timeout'
    },
    'err_receive_timeout': {
      AppLanguage.ru: 'Превышено время получения данных',
      AppLanguage.uz: "Ma'lumot qabul qilish vaqti tugadi",
      AppLanguage.en: 'Receive timeout'
    },
    'err_connection_error': {
      AppLanguage.ru: 'Отсутствует интернет-соединение или сервер недоступен',
      AppLanguage.uz: "Internet ulanishi yo'q yoki server band",
      AppLanguage.en: 'No internet connection or server unavailable'
    },
    'err_network_default': {
      AppLanguage.ru: 'Ошибка сети: проверьте подключение',
      AppLanguage.uz: 'Tarmoq xatoligi: ulanishni tekshiring',
      AppLanguage.en: 'Network error: check your connection'
    },

    // Pull-to-refresh
    'pull_to_refresh': {
      AppLanguage.ru: 'Потяните для обновления',
      AppLanguage.uz: 'Yangilash uchun torting',
      AppLanguage.en: 'Pull to refresh'
    },
    'release_to_refresh': {
      AppLanguage.ru: 'Отпустите для обновления',
      AppLanguage.uz: "Yangilash uchun qo'yib yuboring",
      AppLanguage.en: 'Release to refresh'
    },
    'refreshing_data': {
      AppLanguage.ru: 'Обновление данных...',
      AppLanguage.uz: "Ma'lumotlar yangilanmoqda...",
      AppLanguage.en: 'Updating data...'
    },

    // Бюджеты
    'budget_deleted': {
      AppLanguage.ru: 'Лимит удален',
      AppLanguage.uz: "Limit o'chirildi",
      AppLanguage.en: 'Budget limit deleted'
    },
    'sync_network_required': {
      AppLanguage.ru: 'Нет подключения к сети для синхронизации',
      AppLanguage.uz: 'Sinxronizatsiya uchun tarmoqqa ulanish zarur',
      AppLanguage.en: 'Network connection is required for sync'
    },

    // Синхронизация в профиле
    'sync_synced': {
      AppLanguage.ru: 'Данные синхронизированы',
      AppLanguage.uz: "Ma'lumotlar sinxronlangan",
      AppLanguage.en: 'Data synced'
    },

    // Валидация валюты
    'enter_amount': {
      AppLanguage.ru: 'Введите сумму',
      AppLanguage.uz: 'Summani kiriting',
      AppLanguage.en: 'Enter amount'
    },
    'invalid_amount': {
      AppLanguage.ru: 'Некорректная сумма',
      AppLanguage.uz: "Noto'g'ri summa",
      AppLanguage.en: 'Invalid amount'
    },
    'max_amount_prefix': {
      AppLanguage.ru: 'Макс. сумма',
      AppLanguage.uz: 'Maksimal summa',
      AppLanguage.en: 'Max amount'
    },

    // Месяцы в родительном падеже (для отображения дат на главном экране)
    'month_gen_1': {
      AppLanguage.ru: 'января',
      AppLanguage.uz: 'yanvar',
      AppLanguage.en: 'January'
    },
    'month_gen_2': {
      AppLanguage.ru: 'февраля',
      AppLanguage.uz: 'fevral',
      AppLanguage.en: 'February'
    },
    'month_gen_3': {
      AppLanguage.ru: 'марта',
      AppLanguage.uz: 'mart',
      AppLanguage.en: 'March'
    },
    'month_gen_4': {
      AppLanguage.ru: 'апреля',
      AppLanguage.uz: 'aprel',
      AppLanguage.en: 'April'
    },
    'month_gen_5': {
      AppLanguage.ru: 'мая',
      AppLanguage.uz: 'may',
      AppLanguage.en: 'May'
    },
    'month_gen_6': {
      AppLanguage.ru: 'июня',
      AppLanguage.uz: 'iyun',
      AppLanguage.en: 'June'
    },
    'month_gen_7': {
      AppLanguage.ru: 'июля',
      AppLanguage.uz: 'iyul',
      AppLanguage.en: 'July'
    },
    'month_gen_8': {
      AppLanguage.ru: 'августа',
      AppLanguage.uz: 'avgust',
      AppLanguage.en: 'August'
    },
    'month_gen_9': {
      AppLanguage.ru: 'сентября',
      AppLanguage.uz: 'sentabr',
      AppLanguage.en: 'September'
    },
    'month_gen_10': {
      AppLanguage.ru: 'октября',
      AppLanguage.uz: 'oktabr',
      AppLanguage.en: 'October'
    },
    'month_gen_11': {
      AppLanguage.ru: 'ноября',
      AppLanguage.uz: 'noyabr',
      AppLanguage.en: 'November'
    },
    'month_gen_12': {
      AppLanguage.ru: 'декабря',
      AppLanguage.uz: 'dekabr',
      AppLanguage.en: 'December'
    },
  };

  static List<String> get monthsNames =>
      List.generate(12, (i) => t('month_${i + 1}'));

  static String getMonthGenitive(int month) => t('month_gen_$month');

  static String formatDayMonth(DateTime date) {
    final day = date.day;
    final monthGen = getMonthGenitive(date.month);
    switch (_currentLanguage) {
      case AppLanguage.ru:
        return '$day $monthGen';
      case AppLanguage.uz:
        return '$day-$monthGen';
      case AppLanguage.en:
        return '$monthGen $day';
    }
  }

  static String formatDateTime(DateTime date) {
    final dayMonth = formatDayMonth(date);
    final hours = date.hour.toString().padLeft(2, '0');
    final minutes = date.minute.toString().padLeft(2, '0');
    final timeStr = '$hours:$minutes';

    final now = DateTime.now();
    if (date.year != now.year) {
      switch (_currentLanguage) {
        case AppLanguage.ru:
          return '$dayMonth ${date.year}, $timeStr';
        case AppLanguage.uz:
          return '${date.year}-yil $dayMonth, $timeStr';
        case AppLanguage.en:
          return '$dayMonth, ${date.year}, $timeStr';
      }
    }

    return '$dayMonth, $timeStr';
  }

  static String formatDate(DateTime date, {bool includeTime = true}) {
    if (includeTime) {
      return formatDateTime(date);
    }
    return formatDayMonth(date);
  }

  static String t(String key) {
    final map = _localizedValues[key];
    if (map == null) return key;
    return map[_currentLanguage] ?? map[AppLanguage.ru] ?? key;
  }
}

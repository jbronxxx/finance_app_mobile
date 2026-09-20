import 'package:family_budget/services/preferences_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Поддерживаемые валюты с их параметрами.
enum Currency {
  uzs('UZS', 'сум', 'Узбекский сум', false, 0, 100000000000), // Лимит 100 млрд
  kzt('KZT', '₸', 'Казахстанский тенге', false, 0, 10000000000),    // Лимит 10 млрд
  rub('RUB', '₽', 'Российский рубль', false, 2, 1000000000),     // Лимит 1 млрд
  eur('EUR', '€', 'Евро', true, 2, 100000000),       // Лимит 100 млн
  usd('USD', r'$', 'Доллар США', true, 2, 100000000);      // Лимит 100 млн

  final String code; // Код валюты (ISO)
  final String symbol; // Символ валюты
  final String readableName; // Читаемое название валюты (на русском)
  final bool symbolBefore; // Ставить ли символ перед числом ($100 vs 100 руб)
  final int defaultDecimalDigits; // Сколько знаков после запятой отображать
  final double maxAmount; // Максимально допустимая сумма для ввода

  const Currency(this.code, this.symbol, this.readableName, this.symbolBefore, this.defaultDecimalDigits, this.maxAmount);
}

/// Утилита для форматирования и валидации денежных сумм.
class CurrencyFormatter {
  static Currency _currentCurrency = Currency.rub;
  
  /// Уведомляет слушателей (UI) об изменении выбранной валюты.
  static final ValueNotifier<Currency> currencyNotifier = ValueNotifier(Currency.rub);

  /// Устанавливает текущую валюту и уведомляет UI.
  static void setCurrency(Currency currency) {
    _currentCurrency = currency;
    currencyNotifier.value = currency;
    // Сохраняем выбор в постоянное хранилище
    PreferencesService.instance.saveCurrency(currency.code);
  }

  /// Загружает сохраненную валюту из хранилища.
  static Future<void> loadSavedCurrency() async {
    final code = await PreferencesService.instance.getCurrency();
    if (code != null) {
      try {
        final saved = Currency.values.firstWhere((c) => c.code == code);
        _currentCurrency = saved;
        currencyNotifier.value = saved;
      } catch (_) {
        // Если сохраненный код не найден, оставляем дефолтную (RUB)
      }
    }
  }

  static Currency get currentCurrency => _currentCurrency;

  /// Превращает строку из поля ввода в число.
  /// Удаляет пробелы-разделители и заменяет запятые на точки.
  static double? parseInput(String input) {
    if (input.isEmpty) return null;
    final sanitized = input.replaceAll(' ', '').replaceAll(',', '.');
    return double.tryParse(sanitized);
  }

  /// Проверяет корректность введенной суммы и соблюдение лимитов.
  static String? validateAmount(String? value) {
    if (value == null || value.isEmpty) return 'Введите сумму';
    final amount = parseInput(value);
    if (amount == null || amount <= 0) return 'Некорректная сумма';
    if (amount > _currentCurrency.maxAmount) {
      return 'Макс. сумма: ${format(_currentCurrency.maxAmount)}';
    }
    return null;
  }

  /// Основной метод форматирования суммы в строку.
  /// Добавляет разделители тысяч (пробелы) и символ валюты.
  static String format(double amount, {bool showSymbol = true, int? decimalDigits, bool showSign = false}) {
    final digits = decimalDigits ?? _currentCurrency.defaultDecimalDigits;
    String sign = '';
    
    // Добавление знака + или - если требуется
    if (showSign) {
      if (amount > 0) sign = '+';
      if (amount < 0) sign = '-';
    }
    
    final absAmount = amount.abs();
    String formatted = absAmount.toStringAsFixed(digits);
    
    // Добавление пробелов как разделителей тысяч (регулярное выражение)
    final parts = formatted.split('.');
    final RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    parts[0] = parts[0].replaceAllMapped(reg, (Match m) => '${m[1]} ');
    formatted = parts.join(digits > 0 ? ',' : '');

    if (!showSymbol) return '$sign$formatted';

    // Позиционирование символа валюты
    if (_currentCurrency.symbolBefore) {
      return '$sign${_currentCurrency.symbol}$formatted';
    } else {
      return '$sign$formatted ${_currentCurrency.symbol}';
    }
  }

  /// Виджет для безопасного отображения текста суммы.
  /// Использует FittedBox или ellipsis, чтобы длинные числа (UZS/KZT) не ломали верстку.
  static Widget formatText(double amount, {
    TextStyle? style,
    bool showSymbol = true,
    int? decimalDigits,
    bool useFittedBox = false,
    TextAlign textAlign = TextAlign.start,
    bool showSign = false,
  }) {
    final text = Text(
      format(amount, showSymbol: showSymbol, decimalDigits: decimalDigits, showSign: showSign),
      style: style,
      textAlign: textAlign,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    if (useFittedBox) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: text,
      );
    }
    return text;
  }
}

/// Форматировщик для TextField. 
/// Автоматически расставляет пробелы при вводе и ограничивает ввод некорректных символов.
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;

    // Оставляем только цифры и один разделитель (точку или запятую)
    final text = newValue.text.replaceAll(' ', '').replaceAll(',', '.');
    
    // Если ввод не является числом (и не в процессе ввода точки), отменяем изменение
    if (text != '.' && double.tryParse(text) == null && !text.endsWith('.')) {
      return oldValue;
    }

    final parts = text.split('.');
    // Форматируем целую часть с пробелами
    final RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    String formattedInt = parts[0].replaceAllMapped(reg, (Match m) => '${m[1]} ');
    
    String finalString = formattedInt;
    // Добавляем дробную часть обратно, если она есть
    if (text.contains('.')) {
      finalString += ',${parts.length > 1 ? parts[1] : ''}';
    }

    return TextEditingValue(
      text: finalString,
      // Удерживаем курсор в конце для удобства ввода
      selection: TextSelection.collapsed(offset: finalString.length),
    );
  }
}

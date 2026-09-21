import 'package:flutter/material.dart';

enum AlertType { success, error, warning, info }

class AppAlerts {
  /// Отображает всплывающее уведомление (Toast) с кастомным дизайном.
  /// 
  /// Поддерживает различные типы [type] для визуальной дифференциации.
  static void showToast(
    BuildContext context, {
    required String message,
    String? title,
    AlertType type = AlertType.info,
    Duration duration = const Duration(seconds: 4),
  }) {
    // Настраиваем цвета и иконки в зависимости от типа
    Color bgColor;
    Color iconColor;
    IconData icon;

    switch (type) {
      case AlertType.success:
        bgColor = const Color(0xFFF0FDF4); // Light Green
        iconColor = const Color(0xFF16A34A); // Green
        icon = Icons.check_circle_rounded;
        break;
      case AlertType.error:
        bgColor = const Color(0xFFFEF2F2); // Light Red
        iconColor = const Color(0xFFEF4444); // Red
        icon = Icons.error_rounded;
        break;
      case AlertType.warning:
        bgColor = const Color(0xFFFFFBEB); // Light Amber
        iconColor = const Color(0xFFF59E0B); // Amber
        icon = Icons.warning_rounded;
        break;
      case AlertType.info:
        bgColor = const Color(0xFFF0F9FF); // Light Blue
        iconColor = const Color(0xFF3B82F6); // Blue
        icon = Icons.info_rounded;
        break;
    }

    final snackBar = SnackBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      duration: duration,
      padding: EdgeInsets.zero,
      content: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: iconColor.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: iconColor.withValues(alpha: 0.08),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (title != null) ...[
                    Text(
                      title,
                      style: TextStyle(
                        color: iconColor.darken(0.2),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    message,
                    style: TextStyle(
                      color: Colors.black87.withValues(alpha: 0.8),
                      fontSize: title != null ? 13 : 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, size: 16, color: iconColor.withValues(alpha: 0.5)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ],
        ),
      ),
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }

  static void success(BuildContext context, String message, {String? title}) {
    showToast(context, message: message, title: title, type: AlertType.success);
  }

  static void error(BuildContext context, String message, {String? title}) {
    showToast(context, message: message, title: title, type: AlertType.error);
  }

  static void warning(BuildContext context, String message, {String? title}) {
    showToast(context, message: message, title: title, type: AlertType.warning);
  }

  static void info(BuildContext context, String message, {String? title}) {
    showToast(context, message: message, title: title, type: AlertType.info);
  }

  /// Отображает критическое модальное окно, требующее действия пользователя.
  /// 
  /// Используется для критических ошибок или важных системных уведомлений.
  static void showErrorDialog(
    BuildContext context, {
    required String title,
    required String message,
    String buttonText = 'Понятно',
    VoidCallback? onPressed,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 0,
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEF2F2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_rounded,
                    color: Color(0xFFEF4444),
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      if (onPressed != null) onPressed();
                    },
                    child: Text(
                      buttonText,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

extension ColorExtension on Color {
  Color darken([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}

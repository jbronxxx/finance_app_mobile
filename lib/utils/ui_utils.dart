import 'package:flutter/material.dart';
import '../widgets/app_alerts.dart';

extension ShowSnackBar on BuildContext {
  void showMessage(String message, {bool isError = false}) {
    if (isError) {
      AppAlerts.error(this, message);
    } else {
      AppAlerts.success(this, message);
    }
  }
}

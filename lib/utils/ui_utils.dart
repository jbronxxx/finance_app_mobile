import 'package:getbalanceai_mobile/widgets/widgets.dart';
import 'package:flutter/material.dart';

extension ShowSnackBar on BuildContext {
  void showMessage(String message, {bool isError = false}) {
    if (isError) {
      AppAlerts.error(this, message);
    } else {
      AppAlerts.success(this, message);
    }
  }
}

import 'package:flutter/material.dart';

const appFeedbackDuration = Duration(seconds: 3);

SnackBar appSnackBar({required Widget content, SnackBarAction? action}) =>
    SnackBar(content: content, action: action, duration: appFeedbackDuration);

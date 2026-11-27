import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '/flutter_flow/nav/nav.dart';

/// Shown instead of a blank or fatal screen when a build throws.
const friendlyErrorText = 'Something went wrong. Go back and try again.';

/// Snackbar copy for errors that escape a button handler.
const friendlyErrorSnack = 'Something went wrong. Please try again.';

class FriendlyErrorView extends StatelessWidget {
  const FriendlyErrorView({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFF7F4EF),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            friendlyErrorText,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF1C1917),
              fontSize: 16,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}

/// Keeps framework, platform, and zone errors on screen instead of closing the app.
class AppErrorHandler {
  static DateTime? _lastShown;

  static void install() {
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.dumpErrorToConsole(details);
      report(details.exception, details.stack);
    };
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      report(error, stack);
      return true;
    };
    ErrorWidget.builder = (FlutterErrorDetails details) {
      debugPrint('Build error: ${details.exception}');
      return const FriendlyErrorView();
    };
  }

  static void report(Object error, StackTrace? stack) {
    debugPrint('Handled error: $error');
    if (stack != null) debugPrint(stack.toString());
    final now = DateTime.now();
    final last = _lastShown;
    if (last != null && now.difference(last) < const Duration(seconds: 2)) {
      return;
    }
    _lastShown = now;
    try {
      final context = appNavigatorKey.currentContext;
      if (context == null) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text(friendlyErrorSnack)),
      );
    } catch (e) {
      debugPrint('Could not show the error message: $e');
    }
  }

  static void resetForTests() {
    _lastShown = null;
  }
}

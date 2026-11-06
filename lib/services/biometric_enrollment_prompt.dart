import 'package:flutter/material.dart';

import '/app_state.dart';
import '/services/biometric_lock_service.dart';

class BiometricEnrollmentPrompt {
  static bool _isShowing = false;

  static Future<void> showAfterLogin(BuildContext context) async {
    if (_isShowing || !context.mounted) return;

    _isShowing = true;
    try {
      final appState = FFAppState();
      final biometricService = BiometricLockService();
      final canEnroll = !appState.biometricsEnabled &&
          await _canEnrollBiometrics(biometricService);
      if (!context.mounted) return;

      final enableBiometrics = await Navigator.of(
        context,
        rootNavigator: true,
      ).push<bool>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => _BiometricPromptScreen(
            canEnroll: canEnroll,
            isAlreadyEnabled: appState.biometricsEnabled,
          ),
        ),
      );

      if (!context.mounted) return;
      if (enableBiometrics == true && !appState.biometricsEnabled) {
        try {
          final enabled = await biometricService.enableBiometrics();
          if (enabled && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Biometrics enabled')),
            );
          }
        } catch (error, stackTrace) {
          debugPrint('Unable to enable biometrics after login: $error');
          debugPrint(stackTrace.toString());
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Biometrics were not enabled. You can try again in Profile settings.',
                ),
              ),
            );
          }
        }
      }

      if (!context.mounted) return;
      final enableDarkMode = await Navigator.of(
        context,
        rootNavigator: true,
      ).push<bool>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => _DarkModePromptScreen(
            isDarkModeEnabled: appState.themeMode == ThemeMode.dark,
          ),
        ),
      );

      if (context.mounted && enableDarkMode != null) {
        appState.themeMode = enableDarkMode ? ThemeMode.dark : ThemeMode.light;
      }
    } catch (error, stackTrace) {
      debugPrint('Unable to show login preferences: $error');
      debugPrint(stackTrace.toString());
    } finally {
      _isShowing = false;
    }
  }

  static Future<bool> _canEnrollBiometrics(
    BiometricLockService biometricService,
  ) async {
    try {
      return await biometricService.canUseBiometrics() &&
          (await biometricService.getAvailableBiometrics()).isNotEmpty;
    } catch (error, stackTrace) {
      debugPrint('Unable to check biometric enrollment: $error');
      debugPrint(stackTrace.toString());
      return false;
    }
  }
}

class _DarkModePromptScreen extends StatefulWidget {
  const _DarkModePromptScreen({required this.isDarkModeEnabled});

  final bool isDarkModeEnabled;

  @override
  State<_DarkModePromptScreen> createState() => _DarkModePromptScreenState();
}

class _DarkModePromptScreenState extends State<_DarkModePromptScreen> {
  late bool _darkModeEnabled = widget.isDarkModeEnabled;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Not now'),
                ),
              ),
              const Spacer(),
              Icon(Icons.dark_mode_outlined, size: 88, color: colors.primary),
              const SizedBox(height: 32),
              Text(
                'Make FARM easier on your eyes',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Choose your appearance. You can change this anytime in Profile settings.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 20),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: Colors.green,
                value: _darkModeEnabled,
                onChanged: (value) => setState(() => _darkModeEnabled = value),
                title: const Text('Dark Mode'),
                subtitle: Text(
                  _darkModeEnabled
                      ? 'Dark theme enabled'
                      : 'Light theme enabled',
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(_darkModeEnabled),
                child: const Text('Continue'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _BiometricPromptScreen extends StatefulWidget {
  const _BiometricPromptScreen({
    required this.canEnroll,
    required this.isAlreadyEnabled,
  });

  final bool canEnroll;
  final bool isAlreadyEnabled;

  @override
  State<_BiometricPromptScreen> createState() => _BiometricPromptScreenState();
}

class _BiometricPromptScreenState extends State<_BiometricPromptScreen> {
  late bool _biometricsEnabled = widget.isAlreadyEnabled;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Not now'),
                ),
              ),
              const Spacer(),
              Icon(Icons.fingerprint, size: 88, color: colors.primary),
              const SizedBox(height: 32),
              Text(
                'Secure your account with biometric sign-in',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.canEnroll || widget.isAlreadyEnabled
                    ? 'Next time, unlock with your fingerprint or face instead of an SMS code. You can change this in Profile settings.'
                    : 'Biometric authentication is not available on this device. You can enable it later in Profile settings when available.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 20),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: Colors.green,
                value: _biometricsEnabled,
                onChanged: widget.canEnroll || widget.isAlreadyEnabled
                    ? (value) => setState(() => _biometricsEnabled = value)
                    : null,
                title: const Text('Enable Biometrics'),
                subtitle: Text(
                  _biometricsEnabled
                      ? 'Face ID / Fingerprint active'
                      : 'Biometric authentication disabled',
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(_biometricsEnabled),
                child: const Text('Continue'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

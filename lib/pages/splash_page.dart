import 'package:flutter/material.dart';

import '../components/farm_mark.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/pages/onboarding/onboarding_widget.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  static String routeName = 'SplashPage';
  static String routePath = '/splash';

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(OnboardingWidget.routePath);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Scaffold(
      backgroundColor: theme.primaryBackground,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const FarmMark(size: 72),
            const SizedBox(height: 16),
            Text('FARM',
                style: theme.titleLarge.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('Loading your experience…', style: theme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

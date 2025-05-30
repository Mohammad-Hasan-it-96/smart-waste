import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:smart_waste/screens/login_screen.dart' as login;
import 'package:smart_waste/screens/home_screen.dart' as home;
import 'package:smart_waste/screens/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    await Future.delayed(const Duration(seconds: 1));
    String? onboardingDone = await _storage.read(key: 'onboarding_complete');
    if (!mounted) return;
    if (onboardingDone == 'true') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const home.HomeScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder:
              (context) => OnboardingScreen(
                onFinish: () async {
                  print('Onboarding finished');
                  await _storage.write(
                    key: 'onboarding_complete',
                    value: 'true',
                  );
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => const home.HomeScreen(),
                    ),
                    (route) => false,
                  );
                },
              ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.eco, size: 64, color: theme.colorScheme.primary),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'EcoPack',
              style: theme.textTheme.headlineLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Экологичное будущее',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.secondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

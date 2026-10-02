import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'theme/boho_theme.dart';
import 'services/auth_service.dart';
import 'services/app_config_service.dart';
import 'services/data_service.dart';
import 'services/quest_service.dart';
import 'services/billing_service.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  bool firebaseOk = true;
  String? firebaseInitError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Firebase config not added yet (see PUBLISHING.md). App still boots;
    // auth-backed features will prompt to finish setup.
    firebaseOk = false;
    firebaseInitError = e.toString();
  }
  final auth = AuthService()..initError = firebaseInitError;
  if (firebaseOk) {
    await auth.init();
    // Pull remote feature flags (Admin → Settings) with local fallbacks.
    await AppConfigService().refresh();
  }
  await DataService().load();
  // Quest pins for the gamified map (bundled JSON + inline fallback).
  try {
    await QuestService().load();
  } catch (_) {}
  // Store billing (real products in release; clearly-marked debug bypass
  // in test builds). Never throws at startup.
  try {
    await BillingService().init();
  } catch (_) {}
  runApp(GoTrvlApp(auth: auth, firebaseOk: firebaseOk));
}

class GoTrvlApp extends StatelessWidget {
  final AuthService auth;
  final bool firebaseOk;
  const GoTrvlApp({super.key, required this.auth, required this.firebaseOk});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider.value(value: auth)],
      child: MaterialApp(
        title: 'GoTRVL',
        debugShowCheckedModeBanner: false,
        theme: bohoTheme(),
        navigatorKey: BillingService.navigatorKey, // test-mode dialogs
        home: SplashScreen(firebaseOk: firebaseOk),
        routes: {
          '/login': (_) => const LoginScreen(),
          '/home': (_) => const HomeShell(),
        },
      ),
    );
  }
}

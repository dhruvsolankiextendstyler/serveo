import "package:flutter/material.dart";
import "package:firebase_core/firebase_core.dart";
import "package:firebase_messaging/firebase_messaging.dart";
import "package:frontend/pages/auth_gate.dart";
import "package:frontend/utils/menu_provider.dart";
import "package:frontend/utils/order_provider.dart";
import "package:frontend/utils/restaurant_provider.dart";
import "package:frontend/utils/theme_provider.dart";
import "package:provider/provider.dart";
import "firebase_options.dart";

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // background message handler
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  final themeProvider = ThemeProvider();
  await themeProvider.loadThemePreference();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ChangeNotifierProvider<RestaurantProvider>(create: (_) => RestaurantProvider()..fetchPublicInfo()),
        ChangeNotifierProvider<OrderProvider>(create: (_) => OrderProvider()),
        ChangeNotifierProvider<MenuProvider>(create: (_) => MenuProvider()..fetchMenu()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: "Serveo",
      themeMode: themeProvider.themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const AuthGate(),
    );
  }
}


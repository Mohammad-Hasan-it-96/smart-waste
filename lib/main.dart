import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'env.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Handle background message
  print('Handling a background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Local notifications setup
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  FirebaseMessaging messaging = FirebaseMessaging.instance;
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // Foreground
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Got a message whilst in the foreground!');
    String? title = message.notification?.title ?? message.data['title'];
    String? body = message.notification?.body ?? message.data['body'];
    if (title != null && body != null) {
      flutterLocalNotificationsPlugin.show(
        message.hashCode,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'default_channel_id',
            'Default',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
      );
    }
  });

  // When app is opened from a notification
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('Message clicked!');
    // TODO: Navigate or handle as needed
  });

  // Handle app launch from terminated state via notification
  RemoteMessage? initialMessage =
      await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    print('App launched from notification: ${initialMessage.messageId}');
    // TODO: Handle navigation or logic here
  }

  // Listen for token refresh
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
    print('FCM Token refreshed: $newToken');
    // TODO: Send newToken to your backend
  });

  String? token = await FirebaseMessaging.instance.getToken();
  print("FCM Token: $token");

  if (token != null) {
    await sendFcmTokenToBackend(token);
  }

  runApp(
    ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'EcoPack',
          theme: ThemeData(
            brightness: Brightness.light,
            primaryColor: const Color(0xFFFF9800), // Orange
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFFF9800),
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: const Color(0xFFF1F8E9),
            textTheme: const TextTheme(
              headlineLarge: TextStyle(
                color: Color(0xFFFF9800),
                fontWeight: FontWeight.bold,
                fontSize: 32,
              ),
            ),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: const Color(0xFFFF9800),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFFF9800),
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: const Color(0xFF263238),
            textTheme: const TextTheme(
              headlineLarge: TextStyle(
                color: Color(0xFFFF9800),
                fontWeight: FontWeight.bold,
                fontSize: 32,
              ),
            ),
          ),
          themeMode: mode,
          home: const SplashScreen(),
          debugShowCheckedModeBanner: false,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [
            Locale('en', ''), // English
            Locale('ru', ''), // Russian
            // Add other locales you need
          ],
        );
      },
    ),
  );
}

class SmartWasteApp extends StatelessWidget {
  const SmartWasteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EcoPack',
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFFFF9800), // Orange
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF9800),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF1F8E9),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            color: Color(0xFFFF9800),
            fontWeight: FontWeight.bold,
            fontSize: 32,
          ),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFFFF9800),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF9800),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF263238),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            color: Color(0xFFFF9800),
            fontWeight: FontWeight.bold,
            fontSize: 32,
          ),
        ),
      ),
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

Future<void> sendFcmTokenToBackend(String fcmToken) async {
  final storage = FlutterSecureStorage();
  final authToken = await storage.read(key: 'auth_token');
  if (authToken == null) return;

  final url = Uri.parse('${Env.apiBaseUrl}api/firebase_store');
  await http.post(
    url,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $authToken',
    },
    body: '{"fcm_token": "$fcmToken"}',
  );
}

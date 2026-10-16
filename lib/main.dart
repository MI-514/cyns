import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/category_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/location_provider.dart';
import 'providers/service_request_provider.dart';
import 'providers/worker_provider.dart';
import 'screens/splash/splash_screen.dart';
import 'dart:ui';
import 'core/widgets/call_listener_wrapper.dart';
import 'core/services/worker_background_service.dart';
import 'core/services/notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Prevent uncaught Flutter framework errors from crashing the app
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('CYN Flutter Error: ${details.exception}');
  };

  // Prevent uncaught async platform errors from terminating the app
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('CYN Platform Async Error: $error');
    return true; // Marked as handled so app stays running safely
  };

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    try {
      await Firebase.initializeApp();
    } catch (_) {}
  }

  // Register Background FCM Handler
  try {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (_) {}

  try {
    await WorkerBackgroundService.instance.initialize();
  } catch (_) {}

  runApp(const CynApp());
}

class CynApp extends StatelessWidget {
  const CynApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CategoryProvider()),
        ChangeNotifierProvider(create: (_) => WorkerProvider()),
        ChangeNotifierProvider(create: (_) => ServiceRequestProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
      ],
      child: MaterialApp(
        navigatorKey: AppConstants.navigatorKey,
        scaffoldMessengerKey: AppConstants.scaffoldMessengerKey,
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.navyWhiteTheme,
        builder: (context, child) {
          return CallListenerWrapper(
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const SplashScreen(),
      ),
    );
  }
}

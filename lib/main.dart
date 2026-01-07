import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

// --- IMPORT CONSTANTS (Untuk Warna) ---
import 'core/constants.dart'; // <-- Pastikan ini diimport

// --- IMPORT REPOSITORIES (MODEL) ---
import 'data/repositories/auth_repository.dart';
import 'data/repositories/content_repository.dart';

// --- IMPORT LOGIC (VIEW MODEL) ---
import 'logic/auth/auth_bloc.dart';
import 'logic/dashboard/dashboard_cubit.dart';

// --- IMPORT SCREENS (VIEW) ---
import 'screens/splash_screen.dart';
import 'screens/map_sos_tab.dart'; 

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel', 
  'High Importance Notifications',
  importance: Importance.max,
);

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    
    final mapsImplementation = GoogleMapsFlutterPlatform.instance;
    if (mapsImplementation is GoogleMapsFlutterAndroid) {
      mapsImplementation.useAndroidViewSurface = true;
    }

    await Firebase.initializeApp().timeout(const Duration(seconds: 15));
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
        
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true, 
      badge: true, 
      sound: true
    );
    
    runApp(const MyApp());
  } catch (e) {
    runApp(MaterialApp(home: Scaffold(body: Center(child: Text("Gagal Startup: $e")))));
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _setupFCM();
  }

  void _setupFCM() {
    _setupForegroundNotificationListener();
    _setupInteractedMessage();
  }

  Future<void> _setupInteractedMessage() async {
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) _handleMessage(initialMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
  }

  void _handleMessage(RemoteMessage message) {
    if (message.data['lat'] != null) {
      String senderName = message.data['sender_name']?.toString() ?? "Seseorang";
      _triggerSOSModal(
        double.parse(message.data['lat'].toString()),
        double.parse(message.data['lng'].toString()),
        senderName,
      );
    }
  }

  void _triggerSOSModal(double lat, double lng, String senderName) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      final String timeStamp = DateTime.now().toString().substring(11, 16);

      context.read<DashboardCubit>().addSosToHistory({
        'lat': lat, 
        'lng': lng, 
        'time': timeStamp,
        'name': senderName,
      });

      context.read<DashboardCubit>().changeTab(1); 

      Future.delayed(const Duration(milliseconds: 600), () {
        if (mapSosKey.currentState != null) {
          mapSosKey.currentState!.showSOSModal(lat, lng, senderName);
        }
      });
    }
  }

  void _setupForegroundNotificationListener() {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(android: androidInit),
      onDidReceiveNotificationResponse: (response) {
        if (response.payload != null) {
          final data = jsonDecode(response.payload!);
          _triggerSOSModal(
            double.parse(data['lat'].toString()), 
            double.parse(data['lng'].toString()),
            data['sender_name']?.toString() ?? "Seseorang",
          );
        }
      },
    );

    FirebaseMessaging.onMessage.listen((message) {
      RemoteNotification? notification = message.notification;
      String senderName = message.data['sender_name']?.toString() ?? "Seseorang";

      if (notification != null) {
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          "SOS DARI $senderName", 
          "$senderName butuh bantuan segera!", 
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id, 
              channel.name, 
              icon: '@mipmap/ic_launcher', 
              importance: Importance.max, 
              priority: Priority.high
            )
          ),
          payload: jsonEncode(message.data),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(create: (_) => AuthRepository()),
        RepositoryProvider(create: (_) => ContentRepository()), 
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => AuthBloc(
              authRepository: context.read<AuthRepository>()
            )..add(CheckAuthStatus()),
          ),
          BlocProvider(create: (_) => DashboardCubit()),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          
          // --- SETTING TEMA AGAR LOADING JADI MERAH ---
          theme: ThemeData(
            useMaterial3: true,
            // Gunakan ColorScheme.fromSeed untuk generate palet warna lengkap dari merah
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppConstants.primaryColor, 
              primary: AppConstants.primaryColor, // Paksa primary jadi merah
            ),
            // Opsional: Paksa loading indicator spesifik jadi merah
            progressIndicatorTheme: const ProgressIndicatorThemeData(
              color: AppConstants.primaryColor,
            ),
            // Konfigurasi AppBar default
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent, // Hilangkan tint ungu di AppBar saat scroll
            ),
          ),
          
          home: const SplashScreen(),
        ),
      ),
    );
  }
}
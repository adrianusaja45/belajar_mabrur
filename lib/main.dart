import 'dart:async';
import 'dart:convert';
import 'package:belajar_mabrur/screens/map_sos_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

import 'repositories/auth_repository.dart';
import 'bloc/auth_bloc.dart';
import 'bloc/dashboard_cubit.dart';
import 'screens/splash_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel', 'High Importance Notifications',
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
    await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);
    
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
      // Ambil nama dari data payload 'sender_name'
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

      // Simpan nama pengirim ke riwayat Cubit
      context.read<DashboardCubit>().addSosToHistory({
        'lat': lat, 
        'lng': lng, 
        'time': timeStamp,
        'name': senderName, // Field Nama disimpan di sini
      });

      context.read<DashboardCubit>().changeTab(1); 

      Future.delayed(const Duration(milliseconds: 600), () {
        if (mapSosKey.currentState != null) {
          // Kirim nama pengirim ke fungsi modal di Tab Map
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
      // Ambil nama untuk ditampilkan di judul/body notifikasi lokal
      String senderName = message.data['sender_name']?.toString() ?? "Seseorang";

      if (notification != null) {
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          "SOS DARI $senderName", // Judul Dinamis
          "$senderName butuh bantuan segera!", // Body Dinamis
          NotificationDetails(android: AndroidNotificationDetails(channel.id, channel.name, icon: '@mipmap/ic_launcher', importance: Importance.max, priority: Priority.high)),
          payload: jsonEncode(message.data),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [RepositoryProvider(create: (_) => AuthRepository())],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (context) => AuthBloc(authRepository: context.read<AuthRepository>())..add(CheckAuthStatus())),
          BlocProvider(create: (_) => DashboardCubit()),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          theme: ThemeData(primaryColor: const Color(0xFFA01C1C), useMaterial3: true),
          home: const SplashScreen(),
        ),
      ),
    );
  }
}
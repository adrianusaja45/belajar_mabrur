import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

// --- IMPORT CONSTANTS (Untuk Warna Hex) ---
import 'core/constants.dart'; 

// --- IMPORT REPOSITORIES (MODEL) ---
import 'data/repositories/auth_repository.dart';
import 'data/repositories/content_repository.dart';

// --- IMPORT LOGIC (VIEW MODEL) ---
import 'logic/auth/auth_bloc.dart';
import 'logic/dashboard/dashboard_cubit.dart';

// --- IMPORT SCREENS (VIEW) ---
import 'screens/splash_screen.dart';
import 'screens/map_sos_tab.dart'; 

// --- IMPORT AUDIO ROOM SCREEN (untuk route restore dari PIP) ---
import 'screens/audio_room/audio_room_screen.dart';

// Global Key untuk Navigasi (Agar bisa buka modal dari notifikasi background)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// --- HANDLER NOTIFIKASI BACKGROUND (Saat aplikasi mati/minimized) ---
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Notifikasi akan ditangani oleh sistem tray Android secara otomatis
}

// --- KONFIGURASI CHANNEL NOTIFIKASI ANDROID ---
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel', 
  'High Importance Notifications',
  importance: Importance.max,
);

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Fix untuk Google Maps di beberapa versi Android (mencegah crash/blank)
    final mapsImplementation = GoogleMapsFlutterPlatform.instance;
    if (mapsImplementation is GoogleMapsFlutterAndroid) {
      mapsImplementation.useAndroidViewSurface = true;
    }

    // Inisialisasi Firebase
    await Firebase.initializeApp().timeout(const Duration(seconds: 15));
    
    // Set Handler Background
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    // Inisialisasi Local Notifications (Agar muncul popup di atas layar)
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
        
    // Atur agar notifikasi muncul saat aplikasi dibuka (Foreground)
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true, 
      badge: true, 
      sound: true
    );
    
    runApp(const MyApp());
  } catch (e) {
    // Error Handling jika Firebase gagal init
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

  // --- HANDLER SAAT NOTIFIKASI DIKLIK ---
  Future<void> _setupInteractedMessage() async {
    // 1. Jika aplikasi dibuka dari kondisi mati (Terminated)
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) _handleMessage(initialMessage);
    
    // 2. Jika aplikasi dibuka dari kondisi background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
  }

  void _handleMessage(RemoteMessage message) {
    // Cek apakah ada data lokasi di notifikasi
    if (message.data['lat'] != null) {
      String senderName = message.data['sender_name']?.toString() ?? "Seseorang";
      
      _triggerSOSModal(
        double.parse(message.data['lat'].toString()),
        double.parse(message.data['lng'].toString()),
        senderName,
      );
    }
  }

  // --- LOGIKA MEMUNCULKAN MODAL SOS & SIMPAN RIWAYAT ---
  void _triggerSOSModal(double lat, double lng, String senderName) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      final String timeStamp = DateTime.now().toString().substring(11, 16);

      // 1. Simpan ke Riwayat (Cubit)
      context.read<DashboardCubit>().addSosToHistory({
        'lat': lat, 
        'lng': lng, 
        'time': timeStamp,
        'name': senderName,
      });

      // 2. Pindah ke Tab Map (Index 1)
      context.read<DashboardCubit>().changeTab(1); 

      // 3. Tampilkan Modal di MapSosTab (Tunggu sebentar agar tab berpindah dulu)
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mapSosKey.currentState != null) {
          mapSosKey.currentState!.showSOSModal(lat, lng, senderName);
        }
      });
    }
  }

  // --- HANDLER SAAT APLIKASI DIBUKA (FOREGROUND) ---
  void _setupForegroundNotificationListener() {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // Init Local Notification
    flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(android: androidInit),
      onDidReceiveNotificationResponse: (response) {
        // Jika notifikasi lokal diklik
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

    // Dengar pesan masuk dari Firebase saat aplikasi aktif
    FirebaseMessaging.onMessage.listen((message) {
      RemoteNotification? notification = message.notification;
      String senderName = message.data['sender_name']?.toString() ?? "Seseorang";

      if (notification != null) {
        // Tampilkan notifikasi lokal (Heads-up)
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          "SOS DARI $senderName", // Judul Custom
          "$senderName butuh bantuan segera!", // Body Custom
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
    // --- DEPENDENCY INJECTION (MVVM SETUP) ---
    return MultiRepositoryProvider(
      providers: [
        // 1. Auth Repository (Login/User)
        RepositoryProvider(create: (_) => AuthRepository()),
        
        // 2. Content Repository (Data Konten)
        RepositoryProvider(create: (_) => ContentRepository()), 
      ],
      child: MultiBlocProvider(
        providers: [
          // Bloc Authentication (Global)
          BlocProvider(
            create: (context) => AuthBloc(
              authRepository: context.read<AuthRepository>()
            )..add(CheckAuthStatus()),
          ),
          // Cubit Dashboard (Global state for Tabs & SOS History)
          BlocProvider(create: (_) => DashboardCubit()),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          
          // --- REGISTER ROUTES (PIP / Restore Audio Room) ---
          routes: {
            '/audioRoom': (ctx) {
              final args = ModalRoute.of(ctx)!.settings.arguments as Map<String, dynamic>;
              return AudioRoomScreen(
                roomID: args['roomID'],
                userID: args['userID'],
                displayName: args['displayName'],
                hostUserID: args['hostUserID'],
                isHost: args['isHost'] ?? false,
              );
            },
          },

          // --- GLOBAL THEME CONFIGURATION ---
          theme: ThemeData(
            useMaterial3: true,
            
            // Konfigurasi Warna Utama & Error dari Constants
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppConstants.primaryColor, 
              primary: AppConstants.primaryColor, // Warna Utama (Merah)
              error: AppConstants.errorColor,     // Warna Error (Merah Terang)
              surface: AppConstants.backgroundColor, // Paksa surface putih bersih
            ),
            
            // Background Scaffold Putih Bersih (Fix Red Tint Issue)
            scaffoldBackgroundColor: AppConstants.backgroundColor,

            // Loading Indicator Merah
            progressIndicatorTheme: const ProgressIndicatorThemeData(
              color: AppConstants.primaryColor,
            ),
            
            // AppBar Putih & Bersih
            appBarTheme: const AppBarTheme(
              backgroundColor: AppConstants.backgroundColor,
              surfaceTintColor: Colors.transparent, // Hilangkan tint ungu/merah saat scroll
            ),
          ),
          
          home: const SplashScreen(),
        ),
      ),
    );
  }
}
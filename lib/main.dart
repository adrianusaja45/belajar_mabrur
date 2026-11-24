import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:zego_uikit_prebuilt_live_audio_room/zego_uikit_prebuilt_live_audio_room.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/content_repository.dart';
import 'data/repositories/sos_repository.dart';
import 'logic/auth/auth_bloc.dart';
import 'logic/dashboard/dashboard_cubit.dart';
import 'screens/map_sos_tab.dart';
import 'screens/splash_screen.dart';

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

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    try {
      await dotenv.load(fileName: ".env");
    } catch (_) {}

    final mapsImplementation = GoogleMapsFlutterPlatform.instance;
    if (mapsImplementation is GoogleMapsFlutterAndroid) {
      // Texture layer avoids SurfaceView ghosting across IndexedStack tabs on Impeller.
      mapsImplementation.useAndroidViewSurface = false;
    }

    await Firebase.initializeApp().timeout(const Duration(seconds: 15));

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    runApp(const MyApp());
  } catch (e) {
    debugPrint('Gagal startup aplikasi: $e');
    runApp(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xxl),
                child: Text(
                  'Aplikasi gagal dimulai. Silakan tutup lalu buka kembali.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textPrimary),
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
    RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) _handleMessage(initialMessage);

    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
  }

  void _handleMessage(RemoteMessage message) {
    final lat = double.tryParse(message.data['lat']?.toString() ?? '');
    final lng = double.tryParse(message.data['lng']?.toString() ?? '');
    if (lat != null && lng != null) {
      final senderName = message.data['sender_name']?.toString() ?? "Seseorang";
      _triggerSOSModal(lat, lng, senderName);
    }
  }

  void _triggerSOSModal(double lat, double lng, String senderName) {
    final context = navigatorKey.currentContext;
    if (context != null && context.mounted) {
      final dashboardCubit = context.read<DashboardCubit>();
      final String timeStamp = DateTime.now().toString().substring(11, 16);

      dashboardCubit.addSosToHistory({
        'lat': lat,
        'lng': lng,
        'time': timeStamp,
        'name': senderName,
      });

      dashboardCubit.changeTab(1);

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
        if (response.payload == null) return;
        try {
          final data = jsonDecode(response.payload!);
          if (data is! Map) return;
          final lat = double.tryParse(data['lat']?.toString() ?? '');
          final lng = double.tryParse(data['lng']?.toString() ?? '');
          if (lat != null && lng != null) {
            _triggerSOSModal(
              lat,
              lng,
              data['sender_name']?.toString() ?? "Seseorang",
            );
          }
        } catch (e) {
          debugPrint('Gagal membaca payload notifikasi SOS: $e');
        }
      },
    );

    FirebaseMessaging.onMessage.listen((message) {
      final RemoteNotification? notification = message.notification;
      final String senderName =
          message.data['sender_name']?.toString() ?? "Seseorang";

      final lat = double.tryParse(message.data['lat']?.toString() ?? '');
      final lng = double.tryParse(message.data['lng']?.toString() ?? '');
      if (lat != null && lng != null) {
        final navContext = navigatorKey.currentContext;
        if (navContext != null && navContext.mounted) {
          final String timeStamp = DateTime.now().toString().substring(11, 16);
          navContext.read<DashboardCubit>().addSosToHistory({
            'lat': lat,
            'lng': lng,
            'time': timeStamp,
            'name': senderName,
          });
        }
      }

      if (notification != null) {
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          "Sinyal SOS dari $senderName",
          "$senderName membutuhkan bantuan segera.",
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              icon: '@mipmap/ic_launcher',
              importance: Importance.max,
              priority: Priority.high,
            ),
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
        RepositoryProvider(create: (_) => SosRepository()),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) =>
                AuthBloc(authRepository: context.read<AuthRepository>()),
          ),
          BlocProvider(
            create: (context) => DashboardCubit(
              sosRepository: context.read<SosRepository>(),
            ),
          ),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,

          // Mount Zego PiP overlay above Navigator routes.
          builder: (context, child) {
            return Stack(
              children: [
                child!,
                ZegoUIKitPrebuiltLiveAudioRoomMiniOverlayPage(
                  contextQuery: () {
                    return navigatorKey.currentState!.context;
                  },
                ),
              ],
            );
          },

          theme: AppTheme.lightTheme,

          home: const SplashScreen(),
        ),
      ),
    );
  }
}

import 'package:belajar_mabrur/core/api_exception.dart';
import 'package:belajar_mabrur/core/theme/app_theme.dart';
import 'package:belajar_mabrur/data/models/content_model.dart';
import 'package:belajar_mabrur/data/models/user_model.dart';
import 'package:belajar_mabrur/data/repositories/auth_repository.dart';
import 'package:belajar_mabrur/data/repositories/content_repository.dart';
import 'package:belajar_mabrur/logic/auth/auth_bloc.dart';
import 'package:belajar_mabrur/screens/account_tab.dart';
import 'package:belajar_mabrur/screens/home_tab.dart';
import 'package:belajar_mabrur/screens/join_tab.dart';
import 'package:belajar_mabrur/screens/login_screen.dart';
import 'package:belajar_mabrur/screens/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StubAuthRepository extends AuthRepository {
  @override
  Future<UserModel?> getCachedUser() async => null;
}

class _StubContentRepository extends ContentRepository {
  Future<({List<ContentModel> items, bool fromCache})> Function() handler;

  _StubContentRepository(this.handler);

  @override
  Future<({List<ContentModel> items, bool fromCache})> getContents() =>
      handler();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LoginScreen & RegisterScreen', () {
    testWidgets('LoginScreen validates empty inputs and shows Indonesian copy',
        (tester) async {
      final authRepo = _StubAuthRepository();
      final authBloc = AuthBloc(
        authRepository: authRepo,
        subscribeToTopic: (_) async {},
        unsubscribeFromTopic: (_) async {},
      );

      await tester.pumpWidget(
        RepositoryProvider<AuthRepository>.value(
          value: authRepo,
          child: BlocProvider<AuthBloc>(
            create: (_) => authBloc,
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const LoginScreen(),
            ),
          ),
        ),
      );

      expect(find.text('Masuk ke Belajar Mabrur'), findsOneWidget);
      expect(find.text('Masuk'), findsOneWidget);
      expect(find.text('Daftar Akun'), findsOneWidget);

      await tester.tap(find.text('Masuk'));
      await tester.pump();

      expect(find.text('Nama pengguna tidak boleh kosong'), findsOneWidget);
      expect(find.text('Kata sandi tidak boleh kosong'), findsOneWidget);
    });

    testWidgets('RegisterScreen validates spacing and password length',
        (tester) async {
      final authRepo = _StubAuthRepository();
      final authBloc = AuthBloc(
        authRepository: authRepo,
        subscribeToTopic: (_) async {},
        unsubscribeFromTopic: (_) async {},
      );

      await tester.pumpWidget(
        RepositoryProvider<AuthRepository>.value(
          value: authRepo,
          child: BlocProvider<AuthBloc>(
            create: (_) => authBloc,
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const RegisterScreen(),
            ),
          ),
        ),
      );

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Jamaah Satu');
      await tester.enterText(fields.at(1), 'ada spasi');
      await tester.enterText(fields.at(2), '123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Daftar Akun'));
      await tester.pump();

      expect(
        find.text('Nama pengguna tidak boleh mengandung spasi'),
        findsOneWidget,
      );
      expect(find.text('Kata sandi minimal 6 karakter'), findsOneWidget);
    });
  });

  group('HomeTab (R-27 states, offline cache, Arabic RTL, A-/A+)', () {
    final sampleDoa = ContentModel(
      id: 1,
      name: 'Niat Ihram Umrah',
      category: 'Ihram',
      arabic: 'لَبَّيْكَ اللَّهُمَّ عُمْرَةً',
      latin: 'Labbaikallahumma umratan',
      translateId: 'Aku penuhi panggilan-Mu untuk umrah.',
      description: 'Dibaca saat mengambil miqat.',
    );

    testWidgets(
        'shows error with retry, offline banner, filter reset, and A-/A+',
        (tester) async {
      var attempt = 0;
      final contentRepo = _StubContentRepository(() async {
        attempt++;
        if (attempt == 1) {
          throw const ApiException('Tidak ada koneksi internet.');
        }
        return (items: [sampleDoa], fromCache: true);
      });

      await tester.pumpWidget(
        RepositoryProvider<ContentRepository>.value(
          value: contentRepo,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const HomeTab(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Tidak ada koneksi internet.'), findsOneWidget);
      expect(find.text('Coba Lagi'), findsOneWidget);

      await tester.tap(find.text('Coba Lagi'));
      await tester.pumpAndSettle();

      expect(
        find.text('Menampilkan panduan tersimpan (offline).'),
        findsOneWidget,
      );
      expect(find.text('Niat Ihram Umrah'), findsOneWidget);

      await tester.tap(find.text('Thawaf'));
      await tester.pumpAndSettle();
      expect(find.text('Reset Filter'), findsOneWidget);

      await tester.tap(find.text('Reset Filter'));
      await tester.pumpAndSettle();
      expect(find.text('Niat Ihram Umrah'), findsOneWidget);

      await tester.tap(find.text('Niat Ihram Umrah'));
      await tester.pumpAndSettle();

      final arabicText = tester.widget<Text>(
        find.text('لَبَّيْكَ اللَّهُمَّ عُمْرَةً'),
      );
      expect(arabicText.textDirection, TextDirection.rtl);
      expect(arabicText.textAlign, TextAlign.right);
      expect(find.text('100%'), findsOneWidget);

      await tester.tap(find.text('A+'));
      await tester.pumpAndSettle();
      expect(find.text('115%'), findsOneWidget);

      await tester.tap(find.text('A-'));
      await tester.pumpAndSettle();
      expect(find.text('100%'), findsOneWidget);
    });
  });

  group('JoinTab & AccountTab', () {
    testWidgets('JoinTab has no emoji/Zego and toggles CTA for host',
        (tester) async {
      final authRepo = _StubAuthRepository();
      final authBloc = AuthBloc(
        authRepository: authRepo,
        subscribeToTopic: (_) async {},
        unsubscribeFromTopic: (_) async {},
      )..emit(
          const AuthSuccess(
            'Berhasil masuk.',
            user: UserModel(
              id: '10',
              name: 'Ust. Hasan',
              username: 'hasan',
              role: 'host',
              groupId: 'g1',
            ),
          ),
        );

      await tester.pumpWidget(
        RepositoryProvider<AuthRepository>.value(
          value: authRepo,
          child: BlocProvider<AuthBloc>(
            create: (_) => authBloc,
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const JoinTab(),
            ),
          ),
        ),
      );

      expect(find.textContaining('Zego'), findsNothing);
      expect(find.textContaining('🎙️'), findsNothing);
      expect(find.text('Bimbingan Suara Langsung'), findsOneWidget);
      expect(find.text('Pembimbing'), findsOneWidget);
      expect(find.text('Gabung Ruang Audio'), findsOneWidget);

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(find.text('Buka Ruang Audio'), findsOneWidget);

      await tester.tap(find.text('Buka Ruang Audio'));
      await tester.pump();
      expect(find.text('Masukkan ID Ruang terlebih dahulu.'), findsOneWidget);
    });

    testWidgets(
        'JoinTab blocks host and offers Settings when mic permanently denied',
        (tester) async {
      final authRepo = _StubAuthRepository();
      final authBloc = AuthBloc(
        authRepository: authRepo,
        subscribeToTopic: (_) async {},
        unsubscribeFromTopic: (_) async {},
      )..emit(
          const AuthSuccess(
            'Berhasil masuk.',
            user: UserModel(
              id: '10',
              name: 'Ust. Hasan',
              username: 'hasan',
              role: 'host',
              groupId: 'g1',
            ),
          ),
        );

      await tester.pumpWidget(
        RepositoryProvider<AuthRepository>.value(
          value: authRepo,
          child: BlocProvider<AuthBloc>(
            create: (_) => authBloc,
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: JoinTab(
                checkMicrophonePermission: () async =>
                    (granted: false, permanentlyDenied: true),
              ),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '2701');
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Buka Ruang Audio'));
      await tester.pumpAndSettle();

      expect(
        find.text('Izin mikrofon diperlukan untuk membuka ruang audio.'),
        findsOneWidget,
      );
      expect(find.text('Pengaturan'), findsOneWidget);
      expect(find.byType(JoinTab), findsOneWidget);
    });

    testWidgets('AccountTab separates host vs jamaah actions and error state',
        (tester) async {
      final authRepo = _StubAuthRepository();
      final authBloc = AuthBloc(
        authRepository: authRepo,
        subscribeToTopic: (_) async {},
        unsubscribeFromTopic: (_) async {},
      )..emit(
          const AuthSuccess(
            'Berhasil masuk.',
            user: UserModel(
              id: '20',
              name: 'Siti Aminah',
              username: 'siti',
              role: 'user',
              groupId: 'g1',
            ),
          ),
        );

      await tester.pumpWidget(
        RepositoryProvider<AuthRepository>.value(
          value: authRepo,
          child: BlocProvider<AuthBloc>(
            create: (_) => authBloc,
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const AccountTab(),
            ),
          ),
        ),
      );

      expect(find.text('Jamaah'), findsOneWidget);
      expect(find.text('Ubah Profil'), findsNothing);
      expect(find.text('Keluar Akun'), findsOneWidget);

      authBloc.emit(const AuthFailure('Koneksi terputus.'));
      await tester.pump();
      expect(find.text('Koneksi terputus.'), findsOneWidget);
      expect(find.text('Coba Lagi'), findsOneWidget);
    });
  });
}

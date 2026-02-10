import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hellchinza/auth/presentation/auth_view.dart';
import 'package:hellchinza/services/shared_prefs_service.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart' hide User;
import 'package:shared_preferences/shared_preferences.dart';

import 'auth/presentation/extra_info/extra_info_view.dart';
import 'constants/app_colors.dart';
import 'constants/app_text_style.dart';
import 'firebase_options.dart';
import 'home/home_view.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SharedPrefService().init();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await GoogleSignIn.instance.initialize();
   KakaoSdk.init(
    nativeAppKey:'f107d10aec4120e46508bdcbfc1ad0af'
  );
  // try {
  //   String keyHash = await KakaoSdk.origin;
  //   print('현재 앱의 Kakao Key Hash: $keyHash'); // Logger를 사용하여 출력
  // } catch (e) {
  //   print('Kakao Key Hash를 가져오는 중 오류 발생: $e'); // 오류 발생 시 로그 출력
  // }
  runApp(ProviderScope(child: MyApp()));
}

final authUserProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final userDocProvider =
StreamProvider.autoDispose.family<DocumentSnapshot<Map<String, dynamic>>, String>(
      (ref, uid) {
    return FirebaseFirestore.instance.collection('users').doc(uid).snapshots();
  },
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: MaterialApp(
        navigatorKey: rootNavigatorKey,
        supportedLocales: const [
          Locale('ko', 'KR'),
          Locale('en', 'US'),
        ],
        locale: const Locale('ko', 'KR'), // ✅ 강제로 한국어
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        title: 'Flutter Demo',
        theme: ThemeData(
          scaffoldBackgroundColor: Colors.white,
          appBarTheme: AppBarTheme(
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            backgroundColor: AppColors.bgWhite,
            elevation: 0,
            titleTextStyle: AppTextStyle.titleMediumBoldStyle.copyWith(
              color: AppColors.textDefault,
            ),
            centerTitle: true,
          ),
          bottomNavigationBarTheme: BottomNavigationBarThemeData(
            backgroundColor: Colors.white,
          ),

          colorScheme: .fromSeed(seedColor: Colors.deepPurple),
        ),
        home: AuthGate(),
      ),
    );
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authUserProvider);

    return authAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Auth error: $e'))),
      data: (user) {
        if (user == null) return const AuthView();

        final docAsync = ref.watch(userDocProvider(user.uid));

        return docAsync.when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, _) =>
              Scaffold(body: Center(child: Text('User doc error: $e'))),
          data: (doc) {
            // ✅ 문서가 없으면 "첫 유저"로 보고 ExtraInfoView로 보내고 싶다 했지?
            if (doc == null || !doc.exists) {
              return const AuthView();
            }

            final data = doc.data()!;
            final completed = data['profileCompleted'] as bool? ?? false;

            if (!completed) return const ExtraInfoView();
            return const HomeView();
          },
        );
      },
    );
  }
}

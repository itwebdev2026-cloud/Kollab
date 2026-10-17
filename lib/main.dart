import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'core/brand.dart';
import 'features/flow.dart';
import 'firebase_options.dart';

enum Role { creator, business }

final role = ValueNotifier<Role?>(null);
final appThemeMode = ValueNotifier<ThemeMode>(ThemeMode.light);

/// Flip to true after running `flutterfire configure`.
const useFirebase = true;

abstract class AuthService {
  Future<void> signIn(String email, String pass, {required bool create});
  Future<void> signInWithGoogle();
}

class DemoAuth implements AuthService {
  @override
  Future<void> signIn(String email, String pass, {required bool create}) =>
      Future.delayed(const Duration(milliseconds: 500));

  @override
  Future<void> signInWithGoogle() =>
      Future.delayed(const Duration(milliseconds: 500));
}

class FirebaseAuthService implements AuthService {
  @override
  Future<void> signIn(String email, String pass, {required bool create}) async {
    final a = FirebaseAuth.instance;
    final credential = create
        ? await a.createUserWithEmailAndPassword(email: email, password: pass)
        : await a.signInWithEmailAndPassword(email: email, password: pass);
    if (!create) return;

    final accountRole = role.value;
    if (accountRole == null) {
      throw StateError('Choose an account type before signing up.');
    }

    final uid = credential.user!.uid;
    final now = FieldValue.serverTimestamp();
    final db = FirebaseFirestore.instance;
    await db.collection('users').doc(uid).set({
      'email': email,
      'role': accountRole.name,
      'createdAt': now,
      'updatedAt': now,
    });

    final profile = accountRole == Role.creator
        ? <String, dynamic>{
            'name': '',
            'username': '',
            'city': '',
            'niches': <String>[],
            'types': <String>[],
            'bio': '',
            'socialLinks': <String, String>{
              'instagram': '',
              'youtube': '',
              'facebook': '',
              'website': '',
            },
            'skills': <String>[],
            'services': <Map<String, dynamic>>[],
            'photoData': '',
            'followers': 0,
            'price': 0,
            'availability': 'Available',
            'verified': false,
            'rating': 0.0,
          }
        : <String, dynamic>{
            'businessName': '',
            'ownerName': '',
            'industry': '',
            'city': '',
            'website': '',
          };
    profile['createdAt'] = now;
    profile['updatedAt'] = now;
    await db
        .collection(accountRole == Role.creator ? 'creators' : 'businesses')
        .doc(uid)
        .set(profile);
  }

  @override
  Future<void> signInWithGoogle() async {
    if (!kIsWeb) {
      throw UnsupportedError('Google sign-in is currently configured for web.');
    }

    final credential = await FirebaseAuth.instance.signInWithPopup(
      GoogleAuthProvider(),
    );
    final user = credential.user;
    if (user == null) throw StateError('Google sign-in did not return a user.');

    final db = FirebaseFirestore.instance;
    final userRef = db.collection('users').doc(user.uid);
    final existingUser = await userRef.get();
    Role? accountRole;
    final savedRole = existingUser.data()?['role'];
    if (savedRole is String) {
      for (final candidate in Role.values) {
        if (candidate.name == savedRole) accountRole = candidate;
      }
    }
    accountRole ??= role.value;
    if (accountRole == null) {
      throw StateError('Choose Creator or Business before continuing.');
    }
    role.value = accountRole;

    final now = FieldValue.serverTimestamp();
    if (!existingUser.exists) {
      await userRef.set({
        'email': user.email ?? '',
        'role': accountRole.name,
        'createdAt': now,
        'updatedAt': now,
      });
    }

    final collection = accountRole == Role.creator ? 'creators' : 'businesses';
    final profileRef = db.collection(collection).doc(user.uid);
    final profileSnapshot = await profileRef.get();
    if (!profileSnapshot.exists) {
      final profile = accountRole == Role.creator
          ? <String, dynamic>{
              'name': user.displayName ?? '',
              'username': '',
              'city': '',
              'niches': <String>[],
              'types': <String>[],
              'bio': '',
              'socialLinks': <String, String>{
                'instagram': '',
                'youtube': '',
                'facebook': '',
                'website': '',
              },
              'skills': <String>[],
              'services': <Map<String, dynamic>>[],
              'photoData': '',
              'followers': 0,
              'price': 0,
              'availability': 'Available',
              'verified': false,
              'rating': 0.0,
            }
          : <String, dynamic>{
              'businessName': '',
              'ownerName': user.displayName ?? '',
              'industry': '',
              'city': '',
              'website': '',
            };
      profile['createdAt'] = now;
      profile['updatedAt'] = now;
      await profileRef.set(profile);
    }
  }
}

late final AuthService auth;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (useFirebase) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  auth = useFirebase ? FirebaseAuthService() : DemoAuth();
  runApp(const CollavoApp());
}

class CollavoApp extends StatelessWidget {
  const CollavoApp({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
        valueListenable: appThemeMode,
        builder: (context, mode, child) => MaterialApp(
          title: Brand.name,
          debugShowCheckedModeBanner: false,
          theme: Brand.theme(),
          darkTheme: Brand.theme(dark: true),
          themeMode: mode,
          home: const SplashPage(),
        ),
      );
}

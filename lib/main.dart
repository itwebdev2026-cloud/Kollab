import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'core/brand.dart';
import 'features/flow.dart';

enum Role { creator, business }

final role = ValueNotifier<Role?>(null);

/// Flip to true after running `flutterfire configure`.
const useFirebase = false;

abstract class AuthService {
  Future<void> signIn(String email, String pass, {required bool create});
}

class DemoAuth implements AuthService {
  @override
  Future<void> signIn(String email, String pass, {required bool create}) =>
      Future.delayed(const Duration(milliseconds: 500));
}

class FirebaseAuthService implements AuthService {
  @override
  Future<void> signIn(String email, String pass, {required bool create}) async {
    final a = FirebaseAuth.instance;
    create
        ? await a.createUserWithEmailAndPassword(email: email, password: pass)
        : await a.signInWithEmailAndPassword(email: email, password: pass);
    // TODO: write users/{uid} {role: role.value!.name} to Firestore.
  }
}

late final AuthService auth;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (useFirebase) await Firebase.initializeApp();
  auth = useFirebase ? FirebaseAuthService() : DemoAuth();
  runApp(const CollavoApp());
}

class CollavoApp extends StatelessWidget {
  const CollavoApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
      title: Brand.name,
      debugShowCheckedModeBanner: false,
      theme: Brand.theme(),
      home: const SplashPage());
}

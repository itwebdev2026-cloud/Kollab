import 'package:flutter/material.dart';
import '../core/brand.dart';
import '../main.dart';
import 'shell.dart';

void _go(BuildContext c, Widget w) =>
    Navigator.pushReplacement(c, MaterialPageRoute(builder: (_) => w));

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});
  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) _go(context, const OnboardingPage());
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          CollavoLogo(size: 120),
          SizedBox(height: 12),
          Text(Brand.name,
              style: TextStyle(
                  fontSize: 30,
                  letterSpacing: 4,
                  fontWeight: FontWeight.w800,
                  color: Brand.navy)),
          SizedBox(height: 6),
          Text(Brand.tagline),
        ])),
      );
}

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final ctrl = PageController();
  int p = 0;
  static const slides = [
    ('Discover creators.',
        'Find talented creators based on your niche, location, audience and content style.',
        Icons.search),
    ('Find your perfect match.',
        'Discover creators who match your campaign goals.', Icons.auto_awesome),
    ('Collaborate with confidence.',
        'Connect, communicate and build successful campaigns.', Icons.handshake),
  ];
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              Expanded(
                  child: PageView(
                      controller: ctrl,
                      onPageChanged: (v) => setState(() => p = v),
                      children: [
                    for (final s in slides)
                      Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        ShaderMask(
                            shaderCallback: (r) => Brand.gradient.createShader(r),
                            child: Icon(s.$3, size: 120, color: Colors.white)),
                        const SizedBox(height: 24),
                        Text(s.$1,
                            style: const TextStyle(
                                fontSize: 28, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 12),
                        Text(s.$2, textAlign: TextAlign.center),
                      ])
                  ])),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var k = 0; k < 3; k++)
                  Container(
                      margin: const EdgeInsets.all(4),
                      width: k == p ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: k == p ? Brand.purple : Colors.black26,
                          borderRadius: BorderRadius.circular(4)))
              ]),
              const SizedBox(height: 16),
              FilledButton(
                  onPressed: () => p < 2
                      ? ctrl.nextPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut)
                      : _go(context, const RolePage()),
                  child: Text(p < 2 ? 'Next' : 'Get Started')),
            ]),
          ),
        ),
      );
}

class RolePage extends StatelessWidget {
  const RolePage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 24),
              const Text('What are you looking for?',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(height: 24),
              _card(context, Role.creator, "I'm a Creator",
                  'Showcase your work and get discovered.', Icons.camera_alt),
              _card(context, Role.business, "I'm a Business",
                  'Find creators for your next campaign.', Icons.storefront),
            ]),
          ),
        ),
      );
  Widget _card(BuildContext c, Role r, String t, String s, IconData ic) => Card(
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: Brand.purple, width: 1.2)),
        child: ListTile(
            contentPadding: const EdgeInsets.all(20),
            leading: Icon(ic, size: 36, color: Brand.purple),
            title: Text(t, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(s),
            onTap: () {
              role.value = r;
              _go(c, const AuthPage());
            }),
      );
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final email = TextEditingController(), pass = TextEditingController();
  final key = GlobalKey<FormState>();
  bool signup = true, busy = false;
  String? error;

  Future<void> submit() async {
    if (!key.currentState!.validate()) return;
    setState(() { busy = true; error = null; });
    try {
      await auth.signIn(email.text.trim(), pass.text, create: signup);
      if (mounted) _go(context, const Shell());
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Form(
            key: key,
            child: ListView(padding: const EdgeInsets.all(24), children: [
              const Center(child: CollavoLogo(size: 72)),
              const SizedBox(height: 16),
              Text(signup ? 'Create your account' : 'Welcome back',
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              TextFormField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (v) =>
                      (v ?? '').contains('@') ? null : 'Enter a valid email'),
              const SizedBox(height: 12),
              TextFormField(
                  controller: pass,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                  validator: (v) =>
                      (v ?? '').length >= 6 ? null : 'Use at least 6 characters'),
              if (error != null)
                Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(error!, style: const TextStyle(color: Colors.red))),
              const SizedBox(height: 16),
              FilledButton(
                  onPressed: busy ? null : submit,
                  child: busy
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(signup ? 'Sign up' : 'Log in')),
              TextButton(
                  onPressed: () => setState(() => signup = !signup),
                  child: Text(signup
                      ? 'Have an account? Log in'
                      : 'New here? Sign up')),
            ]),
          ),
        ),
      );
}

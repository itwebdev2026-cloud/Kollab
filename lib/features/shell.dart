import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/brand.dart';
import '../main.dart';
import 'creator.dart';
import 'discover.dart';
import 'flow.dart';
import 'messaging.dart';
import 'profile.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int i = 0;
  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(
        onSearch: () => setState(() => i = 1),
        onProfile: () => setState(() => i = 4),
      ),
      const DiscoverPage(),
      const _Soon('Campaigns', Icons.campaign_outlined),
      InboxPage(
        onSettings: () => _showSettingsDialog(context),
        onProfile: () => setState(() => i = 4),
      ),
      role.value == Role.creator
          ? const CreatorProfileEditorPage()
          : const _AccountPage(),
    ];
    return Scaffold(
      body: pages[i],
      bottomNavigationBar: NavigationBar(
        selectedIndex: i,
        onDestinationSelected: (v) => setState(() => i = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.explore_outlined), label: 'Discover'),
          NavigationDestination(
              icon: Icon(Icons.campaign_outlined), label: 'Campaigns'),
          NavigationDestination(
            icon: _UnreadMessageBadge(),
            selectedIcon: _UnreadMessageBadge(selected: true),
            label: 'Messages',
          ),
          NavigationDestination(
              icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}

class _UnreadMessageBadge extends StatelessWidget {
  const _UnreadMessageBadge({this.selected = false});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final user = useFirebase ? FirebaseAuth.instance.currentUser : null;
    final icon = Icon(
      selected ? Icons.chat_bubble : Icons.chat_bubble_outline,
    );
    if (user == null) return icon;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('conversations')
          .where('participantIds', arrayContains: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        var count = 0;
        for (final conversation in snapshot.data?.docs ?? const []) {
          final unread = conversation.data()['unreadCounts'];
          if (unread is Map) count += (unread[user.uid] as num?)?.toInt() ?? 0;
        }
        return Badge(
          isLabelVisible: count > 0,
          label: Text(count > 99 ? '99+' : '$count'),
          child: icon,
        );
      },
    );
  }
}

class HomePage extends StatelessWidget {
  final VoidCallback onSearch;
  final VoidCallback onProfile;
  const HomePage({super.key, required this.onSearch, required this.onProfile});
  @override
  Widget build(BuildContext context) {
    final isCreator = role.value == Role.creator;
    return SafeArea(
      child: ListView(padding: const EdgeInsets.all(20), children: [
        Row(
          children: [
            const CollavoLogo(size: 40),
            const Spacer(),
            PopupMenuButton<String>(
              tooltip: 'Open menu',
              icon: const Icon(Icons.menu),
              onSelected: (value) {
                if (value == 'profile') onProfile();
                if (value == 'settings') _showSettingsDialog(context);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'settings', child: Text('Settings')),
                PopupMenuItem(value: 'profile', child: Text('Profile')),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (isCreator) ...[
          const Text('Good morning 👋',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          const Text('80% Complete'),
          const LinearProgressIndicator(value: .8, minHeight: 8),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: onProfile,
            child: const Text('Complete Profile'),
          ),
        ] else ...[
          const Text('Find the right creator.',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          GestureDetector(
              onTap: onSearch,
              child: const AbsorbPointer(
                  child: TextField(
                      decoration: InputDecoration(
                          hintText: 'Search creators, niches or locations...',
                          prefixIcon: Icon(Icons.search))))),
          const SizedBox(height: 20),
          const Text('Recommended Creators',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final c in sampleCreators.take(3)) CreatorCard(c: c, score: 0),
          const SizedBox(height: 20),
          const Text('Previous Collabs',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          for (final collab in _previousCollabs)
            _PreviousCollabTile(collab: collab),
        ],
      ]),
    );
  }
}

void _showSettingsDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Settings'),
      content: ValueListenableBuilder<ThemeMode>(
        valueListenable: appThemeMode,
        builder: (context, mode, child) => SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Dark mode'),
          secondary: const Icon(Icons.dark_mode_outlined),
          value: mode == ThemeMode.dark,
          onChanged: (enabled) =>
              appThemeMode.value = enabled ? ThemeMode.dark : ThemeMode.light,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    ),
  );
}

class _AccountPage extends StatelessWidget {
  const _AccountPage();

  Future<void> _signOut(BuildContext context) async {
    if (useFirebase) await FirebaseAuth.instance.signOut();
    role.value = null;
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const OnboardingPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = useFirebase ? FirebaseAuth.instance.currentUser : null;
    final name = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!.trim()
        : user?.email?.split('@').first ?? 'Your account';
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          CircleAvatar(
            radius: 38,
            child: Text(name.isEmpty ? '?' : name[0].toUpperCase(),
                style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(height: 12),
          Center(
              child: Text(name, style: Theme.of(context).textTheme.titleLarge)),
          if (user?.email != null)
            Center(
                child: Text(user!.email!,
                    style: Theme.of(context).textTheme.bodyMedium)),
          const SizedBox(height: 28),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Settings'),
            subtitle: const Text('Theme and appearance'),
            onTap: () => _showSettingsDialog(context),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => _signOut(context),
            icon: const Icon(Icons.logout),
            label: const Text('Log out'),
          ),
        ],
      ),
    );
  }
}

class _PastCollab {
  const _PastCollab({
    required this.creator,
    required this.campaign,
    required this.period,
    required this.icon,
  });

  final String creator;
  final String campaign;
  final String period;
  final IconData icon;
}

const _previousCollabs = [
  _PastCollab(
    creator: 'Aola Jamir',
    campaign: 'Spring menu reel',
    period: 'Mar 2026',
    icon: Icons.local_cafe_outlined,
  ),
  _PastCollab(
    creator: 'Temsu Longkumer',
    campaign: 'Product photography',
    period: 'Jan 2026',
    icon: Icons.photo_camera_outlined,
  ),
  _PastCollab(
    creator: 'Rinchen Dorjee',
    campaign: 'Destination feature',
    period: 'Nov 2025',
    icon: Icons.landscape_outlined,
  ),
];

class _PreviousCollabTile extends StatelessWidget {
  const _PreviousCollabTile({required this.collab});

  final _PastCollab collab;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        elevation: 0,
        color: Brand.purple.withValues(alpha: .05),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          leading: CircleAvatar(
            backgroundColor: Brand.purple.withValues(alpha: .12),
            child: Icon(collab.icon, color: Brand.purple, size: 20),
          ),
          title: Text(
            collab.creator,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            '${collab.campaign} · ${collab.period}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Tooltip(
            message: 'Completed',
            child: Icon(Icons.check_circle, color: Colors.teal, size: 20),
          ),
        ),
      );
}

class _Soon extends StatelessWidget {
  final String t;
  final IconData ic;
  const _Soon(this.t, this.ic);
  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(ic, size: 48, color: Brand.purple),
        const SizedBox(height: 8),
        Text('$t is coming next'),
      ]));
}

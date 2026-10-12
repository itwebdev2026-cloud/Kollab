import 'package:flutter/material.dart';
import '../core/brand.dart';
import '../main.dart';
import 'creator.dart';
import 'discover.dart';

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
      HomePage(onSearch: () => setState(() => i = 1)),
      const DiscoverPage(),
      const _Soon('Campaigns', Icons.campaign_outlined),
      const _Soon('Messages', Icons.chat_bubble_outline),
      const _Soon('Profile', Icons.person_outline),
    ];
    return Scaffold(
      body: pages[i],
      bottomNavigationBar: NavigationBar(
        selectedIndex: i,
        onDestinationSelected: (v) => setState(() => i = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.explore_outlined), label: 'Discover'),
          NavigationDestination(icon: Icon(Icons.campaign_outlined), label: 'Campaigns'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'Messages'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  final VoidCallback onSearch;
  const HomePage({super.key, required this.onSearch});
  @override
  Widget build(BuildContext context) {
    final isCreator = role.value == Role.creator;
    return SafeArea(
      child: ListView(padding: const EdgeInsets.all(20), children: [
        const Align(alignment: Alignment.centerLeft, child: CollavoLogo(size: 40)),
        const SizedBox(height: 16),
        if (isCreator) ...[
          const Text('Good morning 👋',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          const Text('80% Complete'),
          const LinearProgressIndicator(value: .8, minHeight: 8),
          const SizedBox(height: 8),
          FilledButton(onPressed: () {}, child: const Text('Complete Profile')),
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

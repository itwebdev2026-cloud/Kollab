import 'package:flutter/material.dart';
import '../core/brand.dart';
import 'creator.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});
  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  final req = Requirement();
  String query = '';

  @override
  Widget build(BuildContext context) {
    final cities = sampleCreators.map((c) => c.city).toSet().toList();
    final list = sampleCreators
        .where((c) =>
            query.isEmpty ||
            '${c.name} ${c.city} ${c.niches.join(' ')}'
                .toLowerCase()
                .contains(query.toLowerCase()))
        .map((c) => (c, matchScore(c, req)))
        .toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));
    return SafeArea(
      child: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(
            onChanged: (v) => setState(() => query = v),
            decoration: const InputDecoration(
                hintText: 'Search creators, niches or locations...',
                prefixIcon: Icon(Icons.search))),
        const SizedBox(height: 12),
        Wrap(spacing: 12, runSpacing: 4, children: [
          _drop('City', req.city, cities, (v) => req.city = v),
          _drop('Niche', req.niche, allNiches, (v) => req.niche = v),
          _drop('Content', req.type, allTypes, (v) => req.type = v),
          TextButton(
              onPressed: () => setState(() {
                    req.city = req.niche = req.type = null;
                    req.minFollowers = 0;
                  }),
              child: const Text('Clear')),
        ]),
        Text('Min followers: ${req.minFollowers}'),
        Slider(
            value: req.minFollowers.toDouble(),
            max: 50000,
            divisions: 10,
            onChanged: (v) => setState(() => req.minFollowers = v.round())),
        if (list.isEmpty)
          const Padding(
              padding: EdgeInsets.all(32),
              child: Text('No creators found. Try removing a filter.')),
        for (final (c, s) in list) CreatorCard(c: c, score: s),
      ]),
    );
  }

  Widget _drop(String label, String? value, List<String> items,
          void Function(String?) set) =>
      DropdownButton<String>(
          hint: Text(label),
          value: value,
          items: [
            for (final i in items) DropdownMenuItem(value: i, child: Text(i))
          ],
          onChanged: (v) => setState(() => set(v)),
          underline: const SizedBox());
}

class CreatorCard extends StatelessWidget {
  final Creator c;
  final int score;
  const CreatorCard({super.key, required this.c, required this.score});
  @override
  Widget build(BuildContext context) => Card(
        elevation: 2,
        shadowColor: Brand.purple.withOpacity(.2),
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => CreatorProfilePage(c: c))),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              CircleAvatar(
                  radius: 28,
                  backgroundColor: Brand.purple,
                  child: Text(c.name[0],
                      style: const TextStyle(color: Colors.white, fontSize: 22))),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      Flexible(
                          child: Text(c.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 16))),
                      if (c.verified)
                        const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.verified,
                                size: 16, color: Brand.blue)),
                    ]),
                    Text('${c.niches.first} • ${c.city}',
                        style: const TextStyle(color: Colors.black54)),
                    Text('${c.followers} followers'),
                  ])),
              if (score > 0)
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                        gradient: Brand.gradient,
                        borderRadius: BorderRadius.circular(12)),
                    child: Text('$score%',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w800))),
            ]),
          ),
        ),
      );
}

class CreatorProfilePage extends StatelessWidget {
  final Creator c;
  const CreatorProfilePage({super.key, required this.c});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('@${c.username}')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Center(
              child: CircleAvatar(
                  radius: 44,
                  backgroundColor: Brand.purple,
                  child: Text(c.name[0],
                      style: const TextStyle(color: Colors.white, fontSize: 34)))),
          const SizedBox(height: 12),
          Center(
              child: Text(c.name,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800))),
          Center(child: Text('${c.city} • ${c.availability}')),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _stat('${c.followers}', 'Followers'),
            _stat('${c.rating}', 'Rating'),
            _stat('₹${c.price}+', 'Starting'),
          ]),
          const SizedBox(height: 20),
          const Text('Niches', style: TextStyle(fontWeight: FontWeight.w700)),
          Wrap(spacing: 8, children: [
            for (final n in c.niches) Chip(label: Text(n))
          ]),
          const Text('Content', style: TextStyle(fontWeight: FontWeight.w700)),
          Wrap(spacing: 8, children: [
            for (final t in c.types) Chip(label: Text(t))
          ]),
          const SizedBox(height: 24),
          FilledButton(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Request sent (demo)'))),
              child: const Text('Contact Creator')),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: () {}, child: const Text('Save')),
        ]),
      );
  Widget _stat(String v, String l) => Column(children: [
        Text(v, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        Text(l, style: const TextStyle(color: Colors.black54)),
      ]);
}

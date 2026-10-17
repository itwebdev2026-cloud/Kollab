import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/brand.dart';
import 'creator.dart';
import 'messaging.dart';

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
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('creators').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Could not load creators.'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final creators = snapshot.data!.docs.map((document) {
          final data = document.data();
          List<String> stringList(Object? value) => value is Iterable
              ? value.map((item) => item.toString()).toList()
              : <String>[];
          return Creator(
            document.id,
            data['name']?.toString().trim().isNotEmpty == true
                ? data['name'].toString()
                : 'Creator',
            data['username']?.toString() ?? '',
            data['city']?.toString() ?? '',
            stringList(data['niches']),
            stringList(data['types']),
            (data['followers'] as num?)?.toInt() ?? 0,
            (data['price'] as num?)?.toInt() ?? 0,
            data['verified'] == true,
            (data['rating'] as num?)?.toDouble() ?? 0,
            data['availability']?.toString() ?? 'Available',
            photoData: data['photoData']?.toString(),
            isSample: false,
          );
        }).toList();
        final cities = creators
            .map((creator) => creator.city)
            .where((city) => city.isNotEmpty)
            .toSet()
            .toList();
        final list = creators
            .where((c) =>
                query.isEmpty ||
                '${c.name} ${c.city} ${c.niches.join(' ')}'
                    .toLowerCase()
                    .contains(query.toLowerCase()))
            .where(
                (c) => req.minFollowers == 0 || c.followers >= req.minFollowers)
            .where((c) => req.city == null || c.city == req.city)
            .where((c) => req.niche == null || c.niches.contains(req.niche))
            .where((c) => req.type == null || c.types.contains(req.type))
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
                  child: Text('No creator profiles match these filters yet.')),
            for (final (c, s) in list) CreatorCard(c: c, score: s),
          ]),
        );
      },
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
        shadowColor: Brand.purple.withValues(alpha: .2),
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
                  backgroundImage: _photoProvider(c.photoData),
                  child: c.photoData == null || c.photoData!.isEmpty
                      ? Text(c.name.isEmpty ? '?' : c.name[0],
                          style: const TextStyle(
                              color: Colors.white, fontSize: 22))
                      : null),
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
                    Text(
                        '${c.niches.isEmpty ? 'Creator' : c.niches.first} • ${c.city}',
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

  Future<void> _messageCreator(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to message creators.')),
      );
      return;
    }
    try {
      final conversationId = await MessageService.startConversation(
        otherUid: c.id,
        otherName: c.name,
      );
      if (!context.mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ChatPage(
          conversationId: conversationId,
          otherName: c.name,
        ),
      ));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start conversation: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('@${c.username}')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Center(
              child: CircleAvatar(
                  radius: 44,
                  backgroundColor: Brand.purple,
                  backgroundImage: _photoProvider(c.photoData),
                  child: c.photoData == null || c.photoData!.isEmpty
                      ? Text(c.name.isEmpty ? '?' : c.name[0],
                          style: const TextStyle(
                              color: Colors.white, fontSize: 34))
                      : null)),
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
          Wrap(
              spacing: 8,
              children: [for (final n in c.niches) Chip(label: Text(n))]),
          const Text('Content', style: TextStyle(fontWeight: FontWeight.w700)),
          Wrap(
              spacing: 8,
              children: [for (final t in c.types) Chip(label: Text(t))]),
          const SizedBox(height: 24),
          FilledButton.icon(
              onPressed: c.isSample ? null : () => _messageCreator(context),
              icon: const Icon(Icons.chat_bubble_outline),
              label: Text(c.isSample ? 'Sample profile' : 'Message creator')),
          const SizedBox(height: 8),
          _FollowCreatorButton(creatorId: c.id, enabled: !c.isSample),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: () {}, child: const Text('Save')),
        ]),
      );
  Widget _stat(String v, String l) => Column(children: [
        Text(v,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        Text(l, style: const TextStyle(color: Colors.black54)),
      ]);
}

class _FollowCreatorButton extends StatelessWidget {
  const _FollowCreatorButton({
    required this.creatorId,
    required this.enabled,
  });

  final String creatorId;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (!enabled || user == null) {
      return OutlinedButton.icon(
        onPressed: enabled
            ? () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sign in to follow creators.')),
                )
            : null,
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Follow'),
      );
    }

    final followRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('following')
        .doc(creatorId);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: followRef.snapshots(),
      builder: (context, snapshot) {
        final isFollowing = snapshot.data?.exists == true;
        return OutlinedButton.icon(
          onPressed: snapshot.connectionState == ConnectionState.waiting
              ? null
              : () async {
                  try {
                    if (isFollowing) {
                      await followRef.delete();
                    } else {
                      await followRef.set({
                        'creatorId': creatorId,
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                    }
                  } catch (error) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Could not update follow: $error')),
                    );
                  }
                },
          icon: Icon(isFollowing
              ? Icons.person_remove_outlined
              : Icons.person_add_alt_1_outlined),
          label: Text(isFollowing ? 'Following' : 'Follow'),
        );
      },
    );
  }
}

ImageProvider<Object>? _photoProvider(String? photoData) {
  if (photoData == null || photoData.isEmpty) return null;
  try {
    return MemoryImage(base64Decode(photoData));
  } on FormatException {
    return null;
  }
}

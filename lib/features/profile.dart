import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../main.dart';
import 'creator.dart';
import 'flow.dart';

class CreatorProfileEditorPage extends StatefulWidget {
  const CreatorProfileEditorPage({super.key});

  @override
  State<CreatorProfileEditorPage> createState() =>
      _CreatorProfileEditorPageState();
}

class _CreatorProfileEditorPageState extends State<CreatorProfileEditorPage> {
  static const _ink = Color(0xFF182C29);
  static const _paper = Color(0xFFF3F5F0);
  static const _lime = Color(0xFFD9F078);
  static const _muted = Color(0xFF697771);

  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _city = TextEditingController();
  final _bio = TextEditingController();
  final _instagram = TextEditingController();
  final _youtube = TextEditingController();
  final _facebook = TextEditingController();
  final _website = TextEditingController();
  final List<_ServiceRate> _services = [];
  final Set<String> _selectedNiches = {};
  String? _photoData;
  String? _photoUrl;
  Uint8List? _pendingPhotoBytes;
  bool _loading = true;
  bool _saving = false;
  bool _selectingPhoto = false;
  bool _photoRemoved = false;
  bool _verified = false;
  double _rating = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _loading = false;
        _error = 'Sign in to edit your creator profile.';
      });
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('creators')
          .doc(user.uid)
          .get();
      final data = snapshot.data() ?? <String, dynamic>{};
      _name.text = data['name']?.toString() ?? '';
      _username.text = data['username']?.toString() ?? '';
      _city.text = data['city']?.toString() ?? '';
      _bio.text = data['bio']?.toString() ?? '';
      final savedNiches = data['niches'];
      if (savedNiches is Iterable) {
        _selectedNiches.addAll(
          savedNiches
              .map((niche) => niche.toString().trim())
              .where((niche) => niche.isNotEmpty),
        );
      }
      _photoData = data['photoData']?.toString();
      _photoUrl = data['photoUrl']?.toString();
      _verified = data['verified'] == true;
      _rating = (data['rating'] as num?)?.toDouble() ?? 0;

      final links = data['socialLinks'];
      if (links is Map) {
        _instagram.text = links['instagram']?.toString() ?? '';
        _youtube.text = links['youtube']?.toString() ?? '';
        _facebook.text = links['facebook']?.toString() ?? '';
        _website.text = links['website']?.toString() ?? '';
      }

      final savedServices = data['services'];
      if (savedServices is Iterable) {
        for (final value in savedServices) {
          if (value is Map) {
            final service = Map<String, dynamic>.from(value);
            _services.add(_ServiceRate(
              skill: service['skill']?.toString() ?? '',
              price: service['price']?.toString() ?? '',
            ));
          }
        }
      }
      if (_services.isEmpty) {
        final savedSkills = data['skills'];
        if (savedSkills is Iterable) {
          for (final skill in savedSkills) {
            _services.add(_ServiceRate(skill: skill.toString()));
          }
        }
      }
      if (_services.isEmpty) _services.add(_ServiceRate());
    } catch (error) {
      _error = 'Could not load your profile: $error';
      if (_services.isEmpty) _services.add(_ServiceRate());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _error = 'Sign in to save your creator profile.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final services = _services
        .where((service) => service.skill.text.trim().isNotEmpty)
        .map((service) => {
              'skill': service.skill.text.trim(),
              'price': int.parse(service.price.text.trim()),
            })
        .toList();
    final rates = services.map((service) => service['price'] as int).toList();
    final startingPrice = rates.isEmpty
        ? 0
        : rates.reduce((first, second) => first < second ? first : second);
    String? savedPhotoData = _photoData;
    String? savedPhotoUrl = _photoUrl;
    var savingStage = 'saving profile details';

    try {
      final photoBytes = _pendingPhotoBytes;
      if (photoBytes != null) {
        savingStage = 'preparing profile picture';
        if (photoBytes.lengthInBytes > 600 * 1024) {
          throw StateError('Choose an image smaller than 600 KiB.');
        }
        savedPhotoData = base64Encode(photoBytes);
        savedPhotoUrl = null;
      } else if (_photoRemoved) {
        savedPhotoData = null;
        savedPhotoUrl = null;
      }

      savingStage = 'saving profile details';
      await FirebaseFirestore.instance
          .collection('creators')
          .doc(user.uid)
          .set({
        'name': _name.text.trim(),
        'username': _username.text.trim().replaceFirst(RegExp(r'^@'), ''),
        'city': _city.text.trim(),
        'bio': _bio.text.trim(),
        'niches': _selectedNiches.toList(),
        'socialLinks': {
          'instagram': _instagram.text.trim(),
          'youtube': _youtube.text.trim(),
          'facebook': _facebook.text.trim(),
          'website': _website.text.trim(),
        },
        'skills': services.map((service) => service['skill']).toList(),
        'services': services,
        'photoData': savedPhotoData ?? FieldValue.delete(),
        'photoUrl': savedPhotoUrl ?? FieldValue.delete(),
        'verified': _verified,
        'rating': _rating,
        'price': startingPrice,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        setState(() {
          _photoData = savedPhotoData;
          _photoUrl = savedPhotoUrl;
          _pendingPhotoBytes = null;
          _photoRemoved = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved.')),
        );
      }
    } catch (error) {
      if (mounted) {
        final detail = error is FirebaseException
            ? '${error.code}: ${error.message ?? error}'
            : error.toString();
        setState(() => _error = 'Could not $savingStage: $detail');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addService() => setState(() => _services.add(_ServiceRate()));

  Future<void> _pickProfilePhoto() async {
    if (_selectingPhoto) return;
    setState(() {
      _selectingPhoto = true;
      _error = null;
    });
    try {
      final selected = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 70,
      );
      if (!mounted || selected == null) return;
      final bytes = await selected.readAsBytes();
      if (bytes.lengthInBytes > 600 * 1024) {
        setState(() => _error = 'Choose a smaller image (600 KiB maximum).');
        return;
      }
      setState(() {
        _pendingPhotoBytes = bytes;
        _photoRemoved = false;
      });
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not select a photo: $error');
      if (mounted) setState(() => _selectingPhoto = false);
    }
  }

  void _removeProfilePhoto() {
    setState(() {
      _photoData = null;
      _photoUrl = null;
      _pendingPhotoBytes = null;
      _photoRemoved = true;
    });
  }

  bool get _hasProfilePicture =>
      _pendingPhotoBytes != null ||
      (_photoData?.isNotEmpty ?? false) ||
      (_photoUrl?.isNotEmpty ?? false);

  void _removeService(_ServiceRate service) {
    if (_services.length == 1) {
      service.skill.clear();
      service.price.clear();
      setState(() {});
      return;
    }
    setState(() => _services.remove(service));
    service.dispose();
  }

  String? _validateUrl(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty) {
      return 'Enter a full link starting with https://';
    }
    return null;
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _city.dispose();
    _bio.dispose();
    _instagram.dispose();
    _youtube.dispose();
    _facebook.dispose();
    _website.dispose();
    for (final service in _services) {
      service.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _paper,
        appBar: AppBar(
          backgroundColor: _paper,
          title: const Text('Creator studio'),
          actions: [
            IconButton(
              tooltip: 'Log out',
              onPressed: () async {
                if (useFirebase && FirebaseAuth.instance.currentUser != null) {
                  await FirebaseAuth.instance.signOut();
                }
                role.value = null;
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute<void>(
                    builder: (_) => const OnboardingPage(),
                  ),
                  (_) => false,
                );
              },
              icon: const Icon(Icons.logout),
            ),
            IconButton(
              tooltip: 'Save profile',
              onPressed: _saving || _loading ? null : _saveProfile,
              icon: const Icon(Icons.save_outlined),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _profileHeader(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 26, 20, 36),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_error != null) ...[
                            _errorBanner(),
                            const SizedBox(height: 20),
                          ],
                          _sectionTitle('01', 'Identity'),
                          TextFormField(
                            controller: _name,
                            textCapitalization: TextCapitalization.words,
                            decoration:
                                const InputDecoration(labelText: 'Name'),
                            validator: (value) => (value ?? '').trim().isEmpty
                                ? 'Enter your name'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _username,
                            decoration: const InputDecoration(
                              labelText: 'Username',
                              prefixText: '@',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _city,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'City',
                              prefixIcon: Icon(Icons.location_on_outlined),
                            ),
                          ),
                          _sectionDivider(),
                          _sectionTitle('02', 'Your niches'),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final niche in {
                                ...allNiches,
                                ..._selectedNiches,
                              })
                                FilterChip(
                                  label: Text(niche),
                                  selected: _selectedNiches.contains(niche),
                                  showCheckmark: false,
                                  selectedColor: _lime,
                                  backgroundColor: Colors.white,
                                  side: BorderSide(
                                    color: _selectedNiches.contains(niche)
                                        ? _ink
                                        : const Color(0xFFDDE3DB),
                                  ),
                                  shape: const StadiumBorder(),
                                  onSelected: _saving
                                      ? null
                                      : (selected) => setState(() {
                                            if (selected) {
                                              _selectedNiches.add(niche);
                                            } else {
                                              _selectedNiches.remove(niche);
                                            }
                                          }),
                                ),
                            ],
                          ),
                          _sectionDivider(),
                          _sectionTitle('03', 'Your story'),
                          TextFormField(
                            controller: _bio,
                            maxLines: 4,
                            maxLength: 300,
                            decoration: const InputDecoration(
                              labelText: 'About you',
                              alignLabelWithHint: true,
                            ),
                          ),
                          _sectionDivider(),
                          _sectionTitle('04', 'Around the web'),
                          TextFormField(
                            controller: _instagram,
                            keyboardType: TextInputType.url,
                            validator: _validateUrl,
                            decoration: const InputDecoration(
                              labelText: 'Instagram',
                              hintText: 'https://instagram.com/username',
                              prefixIcon: Icon(Icons.camera_alt_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _youtube,
                            keyboardType: TextInputType.url,
                            validator: _validateUrl,
                            decoration: const InputDecoration(
                              labelText: 'YouTube',
                              hintText: 'https://youtube.com/@channel',
                              prefixIcon: Icon(Icons.play_circle_outline),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _facebook,
                            keyboardType: TextInputType.url,
                            validator: _validateUrl,
                            decoration: const InputDecoration(
                              labelText: 'Facebook',
                              hintText: 'https://facebook.com/page',
                              prefixIcon: Icon(Icons.people_outline),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _website,
                            keyboardType: TextInputType.url,
                            validator: _validateUrl,
                            decoration: const InputDecoration(
                              labelText: 'Website or other link',
                              hintText: 'https://example.com',
                              prefixIcon: Icon(Icons.link),
                            ),
                          ),
                          _sectionDivider(),
                          Row(
                            children: [
                              Expanded(child: _sectionTitle('05', 'Services')),
                              IconButton.filledTonal(
                                tooltip: 'Add service',
                                onPressed: _saving ? null : _addService,
                                icon: const Icon(Icons.add),
                              ),
                            ],
                          ),
                          for (final entry in _services.asMap().entries) ...[
                            _serviceFields(entry.value, entry.key + 1),
                            const SizedBox(height: 10),
                          ],
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: _ink,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _saving ? null : _saveProfile,
                            icon: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.check),
                            label: Text(_saving ? 'Saving' : 'Save changes'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      );

  Widget _profileHeader() => Container(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
        decoration: const BoxDecoration(
          color: _ink,
          border: Border(bottom: BorderSide(color: _lime, width: 4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'CREATOR / PROFILE',
                  style: TextStyle(
                    color: _lime,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                Icon(Icons.auto_awesome, color: _lime, size: 18),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: _lime,
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(child: _profilePicture()),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ListenableBuilder(
                    listenable: Listenable.merge([_name, _username]),
                    builder: (context, child) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _name.text.trim().isEmpty ? 'Your name' : _name.text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '@${_username.text.trim().isEmpty ? 'your.handle' : _username.text.replaceFirst(RegExp(r'^@'), '')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _lime, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF52635E)),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed:
                      _selectingPhoto || _saving ? null : _pickProfilePhoto,
                  icon: _selectingPhoto
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.photo_camera_outlined, size: 18),
                  label: Text(
                      _hasProfilePicture ? 'Change portrait' : 'Add portrait'),
                ),
                if (_hasProfilePicture)
                  TextButton(
                    onPressed: _saving ? null : _removeProfilePhoto,
                    child: const Text(
                      'Remove',
                      style: TextStyle(color: Color(0xFFD8B8AE)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );

  Widget _errorBanner() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFE9E2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );

  Widget _sectionDivider() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Divider(height: 1, color: _ink.withValues(alpha: .12)),
      );

  Widget _profilePicture() {
    final pendingPhotoBytes = _pendingPhotoBytes;
    if (pendingPhotoBytes != null) {
      return Image.memory(pendingPhotoBytes, fit: BoxFit.cover);
    }
    final photoData = _photoData;
    if (photoData != null && photoData.isNotEmpty) {
      try {
        return Image.memory(
          base64Decode(photoData),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _emptyProfilePicture(),
        );
      } on FormatException {
        return _emptyProfilePicture();
      }
    }
    final url = _photoUrl;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _emptyProfilePicture(),
      );
    }
    return _emptyProfilePicture();
  }

  Widget _emptyProfilePicture() => const ColoredBox(
        color: Color(0x11000000),
        child: Icon(Icons.person_outline, size: 48),
      );

  Widget _serviceFields(_ServiceRate service, int index) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFDDE3DB)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'SERVICE ${index.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove skill',
                  onPressed: () => _removeService(service),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            TextFormField(
              controller: service.skill,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Skill or service'),
              validator: (value) {
                final skillEmpty = (value ?? '').trim().isEmpty;
                final rateEmpty = service.price.text.trim().isEmpty;
                return skillEmpty && !rateEmpty
                    ? 'Add a skill or service'
                    : null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: service.price,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Rate per service',
                prefixText: 'INR ',
              ),
              validator: (value) {
                final rate = (value ?? '').trim();
                final skillEmpty = service.skill.text.trim().isEmpty;
                if (rate.isEmpty && !skillEmpty) return 'Add a rate';
                if (rate.isNotEmpty && int.tryParse(rate) == null) {
                  return 'Enter a whole number';
                }
                return null;
              },
            ),
          ],
        ),
      );

  Widget _sectionTitle(String number, String title) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: _lime,
                shape: BoxShape.circle,
              ),
              child: Text(
                number,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: _ink,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      );
}

class _ServiceRate {
  _ServiceRate({String skill = '', String price = ''})
      : skill = TextEditingController(text: skill),
        price = TextEditingController(text: price);

  final TextEditingController skill;
  final TextEditingController price;

  void dispose() {
    skill.dispose();
    price.dispose();
  }
}

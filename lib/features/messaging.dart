import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

class MessageService {
  static Future<String> startConversation({
    required String otherUid,
    required String otherName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Sign in to send messages.');
    if (user.uid == otherUid) {
      throw StateError('You cannot message your own profile.');
    }

    final participantIds = [user.uid, otherUid]..sort();
    final conversationId = participantIds.join('__');
    final ownName = user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : user.email?.split('@').first ?? 'User';

    final conversation = FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final existing = await transaction.get(conversation);
      if (!existing.exists) {
        transaction.set(conversation, {
          'participantIds': participantIds,
          'participantNames': {
            user.uid: ownName,
            otherUid: otherName,
          },
          'lastMessage': '',
          'lastMessageAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });

    return conversationId;
  }

  static Future<void> sendMessage({
    required String conversationId,
    String text = '',
    String? photoData,
    bool forwarded = false,
    String? replyTo,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Sign in to send messages.');

    final trimmed = text.trim();
    if (trimmed.isEmpty && (photoData?.isEmpty ?? true)) return;
    if (trimmed.length > 4000) {
      throw StateError('Messages must be 4,000 characters or fewer.');
    }
    if ((photoData?.length ?? 0) > 850 * 1024) {
      throw StateError('Choose a photo smaller than 600 KiB.');
    }

    final conversation = FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId);
    final message = conversation.collection('messages').doc();
    final conversationSnapshot = await conversation.get();
    final participants = List<String>.from(
      conversationSnapshot.data()?['participantIds'] as Iterable? ?? const [],
    );
    final recipient = participants.firstWhere(
      (participant) => participant != user.uid,
      orElse: () => '',
    );
    final preview = trimmed.isNotEmpty ? trimmed : 'Photo';
    final batch = FirebaseFirestore.instance.batch();
    batch.set(message, {
      'senderId': user.uid,
      'text': trimmed,
      if (photoData != null) 'photoData': photoData,
      'forwarded': forwarded,
      if (replyTo != null) 'replyTo': replyTo,
      'reactions': <String, dynamic>{},
      'readBy': {user.uid: true},
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(conversation, {
      'lastMessage': preview,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'unreadCounts.${user.uid}': 0,
      if (recipient.isNotEmpty)
        'unreadCounts.$recipient': FieldValue.increment(1),
      'typingUsers.${user.uid}': false,
    });
    await batch.commit();
  }

  static Future<void> markRead(
    String conversationId, {
    List<String> messageIds = const [],
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final database = FirebaseFirestore.instance;
    final conversation =
        database.collection('conversations').doc(conversationId);
    final messages = conversation.collection('messages');
    final ids = messageIds.toList();
    if (ids.isEmpty) {
      await conversation.update({
        'lastReadAt.${user.uid}': FieldValue.serverTimestamp(),
        'unreadCounts.${user.uid}': 0,
      });
      return;
    }

    for (var start = 0; start < ids.length; start += 450) {
      final batch = database.batch();
      if (start == 0) {
        batch.update(conversation, {
          'lastReadAt.${user.uid}': FieldValue.serverTimestamp(),
          'unreadCounts.${user.uid}': 0,
        });
      }
      for (final messageId in ids.skip(start).take(450)) {
        batch.update(messages.doc(messageId), {
          'readBy.${user.uid}': true,
        });
      }
      await batch.commit();
    }
  }

  static Future<void> setTyping(String conversationId, bool typing) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId)
        .update({'typingUsers.${user.uid}': typing});
  }
}

class InboxPage extends StatelessWidget {
  const InboxPage({
    super.key,
    this.onSettings,
    this.onProfile,
  });

  final VoidCallback? onSettings;
  final VoidCallback? onProfile;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Sign in to view your messages.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Open menu',
            icon: const Icon(Icons.menu),
            onSelected: (value) {
              if (value == 'settings') onSettings?.call();
              if (value == 'profile') onProfile?.call();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'settings', child: Text('Settings')),
              PopupMenuItem(value: 'profile', child: Text('Profile')),
            ],
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('conversations')
            .where('participantIds', arrayContains: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load messages.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final conversations = snapshot.data!.docs.toList()
            ..sort((first, second) {
              final firstDate = first.data()['updatedAt'] as Timestamp?;
              final secondDate = second.data()['updatedAt'] as Timestamp?;
              return (secondDate?.millisecondsSinceEpoch ?? 0)
                  .compareTo(firstDate?.millisecondsSinceEpoch ?? 0);
            });

          if (conversations.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No conversations yet. Open a creator profile to start one.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            itemCount: conversations.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
            itemBuilder: (context, index) {
              final document = conversations[index];
              final data = document.data();
              final participants = List<String>.from(
                data['participantIds'] as Iterable? ?? const [],
              );
              final otherUid = participants.firstWhere(
                (id) => id != user.uid,
                orElse: () => '',
              );
              final names = data['participantNames'];
              final otherName = names is Map
                  ? names[otherUid]?.toString() ?? 'Conversation'
                  : 'Conversation';
              final lastMessage = data['lastMessage']?.toString() ?? '';
              final unreadCounts = data['unreadCounts'];
              final unread = unreadCounts is Map
                  ? (unreadCounts[user.uid] as num?)?.toInt() ?? 0
                  : 0;

              return ListTile(
                leading: _ConversationAvatar(uid: otherUid, name: otherName),
                title: Text(otherName,
                    style: TextStyle(
                        fontWeight: unread > 0 ? FontWeight.w800 : null)),
                subtitle: Text(
                  lastMessage.isEmpty ? 'Start a conversation' : lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: unread > 0
                    ? CircleAvatar(
                        radius: 12,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: Text('$unread',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11)),
                      )
                    : null,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ChatPage(
                      conversationId: document.id,
                      otherName: otherName,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ConversationAvatar extends StatefulWidget {
  const _ConversationAvatar({required this.uid, required this.name});

  final String uid;
  final String name;

  @override
  State<_ConversationAvatar> createState() => _ConversationAvatarState();
}

class _ConversationAvatarState extends State<_ConversationAvatar> {
  late Future<String?> _photo;

  @override
  void initState() {
    super.initState();
    _photo = _loadPhoto();
  }

  @override
  void didUpdateWidget(covariant _ConversationAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) _photo = _loadPhoto();
  }

  Future<String?> _loadPhoto() async {
    if (widget.uid.isEmpty) return null;
    try {
      final profile = await FirebaseFirestore.instance
          .collection('creators')
          .doc(widget.uid)
          .get();
      final data = profile.data();
      final photoData = data?['photoData']?.toString();
      return photoData?.isNotEmpty == true
          ? photoData
          : data?['photoUrl']?.toString();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<String?>(
        future: _photo,
        builder: (context, snapshot) => CircleAvatar(
          backgroundImage: _memoryPhoto(snapshot.data),
          child: snapshot.data == null || snapshot.data!.isEmpty
              ? Text(widget.name.isEmpty ? '?' : widget.name[0].toUpperCase())
              : null,
        ),
      );
}

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.conversationId,
    required this.otherName,
  });

  final String conversationId;
  final String otherName;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();
  final _undoDrafts = <String>[];
  final _redoDrafts = <String>[];
  final _photoBytes = ValueNotifier<Uint8List?>(null);
  final _conversation = FirebaseFirestore.instance.collection('conversations');
  bool _sending = false;
  bool _choosingPhoto = false;
  bool _restoringDraft = false;
  String _lastDraft = '';
  String? _error;
  String? _replyText;
  final Set<String> _markingReadIds = {};
  Timer? _typingDebounce;
  Timer? _typingTimeout;
  Future<String?>? _otherPhoto;

  @override
  void initState() {
    super.initState();
    _otherPhoto = _loadOtherPhoto();
    _messageController.addListener(_trackDraft);
  }

  Future<void> _markMessagesRead(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
  ) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    final ids = documents
        .where((document) {
          final readBy = document.data()['readBy'];
          return (readBy is! Map || readBy[userId] != true) &&
              !_markingReadIds.contains(document.id);
        })
        .map((document) => document.id)
        .toList();
    if (ids.isEmpty) return;
    _markingReadIds.addAll(ids);
    try {
      await MessageService.markRead(widget.conversationId, messageIds: ids);
    } catch (_) {
      _markingReadIds.removeAll(ids);
    }
  }

  Future<String?> _loadOtherPhoto() async {
    final user = FirebaseAuth.instance.currentUser;
    final conversation = await _conversation.doc(widget.conversationId).get();
    final participants = List<String>.from(
      conversation.data()?['participantIds'] as Iterable? ?? const [],
    );
    final otherUid = participants.firstWhere(
      (participant) => participant != user?.uid,
      orElse: () => '',
    );
    if (otherUid.isEmpty) return null;
    final profile = await FirebaseFirestore.instance
        .collection('creators')
        .doc(otherUid)
        .get();
    final data = profile.data();
    final photoData = data?['photoData']?.toString();
    return photoData?.isNotEmpty == true
        ? photoData
        : data?['photoUrl']?.toString();
  }

  void _trackDraft() {
    if (_restoringDraft) return;
    final current = _messageController.text;
    if (current == _lastDraft) return;
    if (_lastDraft.isNotEmpty) _undoDrafts.add(_lastDraft);
    _redoDrafts.clear();
    _lastDraft = current;
    _typingDebounce?.cancel();
    if (current.trim().isEmpty) {
      _typingTimeout?.cancel();
      MessageService.setTyping(widget.conversationId, false).catchError((_) {});
    } else {
      _typingDebounce = Timer(const Duration(milliseconds: 450), () {
        MessageService.setTyping(widget.conversationId, true)
            .catchError((_) {});
        _typingTimeout?.cancel();
        _typingTimeout = Timer(const Duration(seconds: 3), () {
          MessageService.setTyping(widget.conversationId, false)
              .catchError((_) {});
        });
      });
    }
  }

  void _restoreDraft(List<String> from, List<String> to) {
    if (from.isEmpty) return;
    to.add(_messageController.text);
    _restoringDraft = true;
    _lastDraft = from.removeLast();
    _messageController.text = _lastDraft;
    _messageController.selection = TextSelection.collapsed(
      offset: _messageController.text.length,
    );
    _restoringDraft = false;
  }

  Future<void> _pickPhoto(ImageSource source) async {
    if (_choosingPhoto) return;
    setState(() => _choosingPhoto = true);
    try {
      final selected = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 70,
      );
      if (selected == null || !mounted) return;
      final bytes = await selected.readAsBytes();
      if (bytes.lengthInBytes > 600 * 1024) {
        setState(() => _error = 'Choose a photo smaller than 600 KiB.');
        return;
      }
      _photoBytes.value = bytes;
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not select a photo: $error');
    } finally {
      if (mounted) setState(() => _choosingPhoto = false);
    }
  }

  Future<void> _send() async {
    if (_sending ||
        (_messageController.text.trim().isEmpty && _photoBytes.value == null)) {
      return;
    }
    final text = _messageController.text;
    final photoData =
        _photoBytes.value == null ? null : base64Encode(_photoBytes.value!);
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await MessageService.sendMessage(
        conversationId: widget.conversationId,
        text: text,
        photoData: photoData,
        replyTo: _replyText,
      );
      _messageController.clear();
      _photoBytes.value = null;
      setState(() => _replyText = null);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _messageController.removeListener(_trackDraft);
    _typingDebounce?.cancel();
    _typingTimeout?.cancel();
    MessageService.setTyping(widget.conversationId, false).catchError((_) {});
    _messageController.dispose();
    _scrollController.dispose();
    _photoBytes.dispose();
    super.dispose();
  }

  Future<void> _react(String messageId, String emoji) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _conversation
        .doc(widget.conversationId)
        .collection('messages')
        .doc(messageId)
        .update({'reactions.$uid': emoji});
  }

  Future<void> _deleteMessage(
      String messageId, Map<String, dynamic> data) async {
    final ref = _conversation
        .doc(widget.conversationId)
        .collection('messages')
        .doc(messageId);
    await ref.update(
        {'deleted': true, 'text': '', 'photoData': FieldValue.delete()});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Message deleted'),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () => ref.update({
          'deleted': false,
          'text': data['text'] ?? '',
          if (data['photoData'] != null) 'photoData': data['photoData'],
        }),
      ),
    ));
  }

  Future<void> _forwardMessage(Map<String, dynamic> data) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final snapshot = await _conversation
        .where('participantIds', arrayContains: user.uid)
        .get();
    final choices =
        snapshot.docs.where((doc) => doc.id != widget.conversationId).toList();
    if (!mounted) return;
    if (choices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No other conversations to forward to.')),
      );
      return;
    }
    final targetId = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Forward to')),
            for (final doc in choices)
              ListTile(
                title: Text(_otherParticipantName(doc.data(), user.uid)),
                onTap: () => Navigator.pop(context, doc.id),
              ),
          ],
        ),
      ),
    );
    if (targetId == null) return;
    await MessageService.sendMessage(
      conversationId: targetId,
      text: data['text']?.toString() ?? '',
      photoData: data['photoData']?.toString(),
      forwarded: true,
    );
  }

  String _otherParticipantName(Map<String, dynamic> data, String uid) {
    final participants = List<String>.from(
      data['participantIds'] as Iterable? ?? const [],
    );
    final other = participants.firstWhere((id) => id != uid, orElse: () => '');
    final names = data['participantNames'];
    return names is Map
        ? names[other]?.toString() ?? 'Conversation'
        : 'Conversation';
  }

  Future<void> _showMessageActions(
    String messageId,
    Map<String, dynamic> data,
    bool isMine,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  for (final emoji in ['❤️', '😂', '🔥', '👏', '😮'])
                    IconButton(
                      tooltip: emoji,
                      onPressed: () => Navigator.pop(context, 'react:$emoji'),
                      icon: Text(emoji, style: const TextStyle(fontSize: 22)),
                    ),
                ],
              ),
            ),
            if ((data['text']?.toString() ?? '').isNotEmpty)
              ListTile(
                leading: const Icon(Icons.reply),
                title: const Text('Reply'),
                onTap: () => Navigator.pop(context, 'reply'),
              ),
            if ((data['text']?.toString() ?? '').isNotEmpty)
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: const Text('Copy text'),
                onTap: () => Navigator.pop(context, 'copy'),
              ),
            ListTile(
              leading: const Icon(Icons.forward_outlined),
              title: const Text('Forward'),
              onTap: () => Navigator.pop(context, 'forward'),
            ),
            if (isMine && data['deleted'] != true)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete message'),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    if (action.startsWith('react:')) {
      await _react(messageId, action.substring(6));
    } else if (action == 'reply') {
      setState(() => _replyText = data['text'].toString());
    } else if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: data['text'].toString()));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Text copied')),
        );
      }
    } else if (action == 'delete') {
      await _deleteMessage(messageId, data);
    } else if (action == 'forward') {
      await _forwardMessage(data);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final messages = FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            FutureBuilder<String?>(
              future: _otherPhoto,
              builder: (context, snapshot) => Padding(
                padding: const EdgeInsets.only(right: 10),
                child: CircleAvatar(
                  radius: 18,
                  backgroundImage: _memoryPhoto(snapshot.data),
                  child: snapshot.data == null
                      ? Text(widget.otherName.isEmpty
                          ? '?'
                          : widget.otherName[0].toUpperCase())
                      : null,
                ),
              ),
            ),
            Expanded(child: Text(widget.otherName)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Undo draft',
            onPressed: _undoDrafts.isEmpty
                ? null
                : () => setState(() => _restoreDraft(_undoDrafts, _redoDrafts)),
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            tooltip: 'Redo draft',
            onPressed: _redoDrafts.isEmpty
                ? null
                : () => setState(() => _restoreDraft(_redoDrafts, _undoDrafts)),
            icon: const Icon(Icons.redo),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: _conversation.doc(widget.conversationId).snapshots(),
                builder: (context, conversationSnapshot) =>
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: messages,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const Center(
                              child: Text('Could not load this chat.'));
                        }
                        if (!snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        final documents = snapshot.data!.docs;
                        final conversationData =
                            conversationSnapshot.data?.data() ?? {};
                        final participants = List<String>.from(
                          conversationData['participantIds'] as Iterable? ??
                              const [],
                        );
                        final otherUid = participants.firstWhere(
                          (id) => id != user?.uid,
                          orElse: () => '',
                        );
                        final typingUsers = conversationData['typingUsers'];
                        final otherTyping =
                            typingUsers is Map && typingUsers[otherUid] == true;
                        final unreadDocuments = documents.where((document) =>
                            document.data()['senderId'] != user?.uid);
                        _markMessagesRead(unreadDocuments.toList());
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (_scrollController.hasClients) {
                            _scrollController.jumpTo(
                              _scrollController.position.maxScrollExtent,
                            );
                          }
                        });
                        if (documents.isEmpty) {
                          return const Center(
                              child: Text('Send a message to start chatting.'));
                        }
                        return Column(children: [
                          Expanded(
                              child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: documents.length + (otherTyping ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (otherTyping && index == documents.length) {
                                return Align(
                                  alignment: Alignment.centerLeft,
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Text(
                                        '${widget.otherName} is typing…',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall),
                                  ),
                                );
                              }
                              final data = documents[index].data();
                              final isMine = data['senderId'] == user?.uid;
                              final deleted = data['deleted'] == true;
                              final photoData = data['photoData']?.toString();
                              final reactions = data['reactions'];
                              final reaction = reactions is Map
                                  ? reactions.values
                                      .map((value) => value.toString())
                                      .join(' ')
                                  : '';
                              final lastReadAt = conversationData['lastReadAt'];
                              final readAt = lastReadAt is Map
                                  ? lastReadAt[otherUid]
                                  : null;
                              final readBy = data['readBy'];
                              final createdAt = data['createdAt'];
                              final isRead =
                                  (readBy is Map && readBy[otherUid] == true) ||
                                      (readAt is Timestamp &&
                                          createdAt is Timestamp &&
                                          !readAt
                                              .toDate()
                                              .isBefore(createdAt.toDate()));
                              return GestureDetector(
                                onLongPress: () => _showMessageActions(
                                  documents[index].id,
                                  data,
                                  isMine,
                                ),
                                child: Align(
                                  alignment: isMine
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: Container(
                                    constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.sizeOf(context).width *
                                              .76,
                                    ),
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isMine
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                          : Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        if (data['forwarded'] == true)
                                          const Text('Forwarded',
                                              style: TextStyle(fontSize: 10)),
                                        if (data['replyTo'] != null)
                                          Text(
                                            'Replying to: ${data['replyTo']}',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style:
                                                const TextStyle(fontSize: 11),
                                          ),
                                        if (deleted)
                                          const Text('Message deleted',
                                              style: TextStyle(
                                                  fontStyle: FontStyle.italic)),
                                        if (!deleted && photoData != null)
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            child: Image.memory(
                                              base64Decode(photoData),
                                              width: 220,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  const Icon(
                                                      Icons.broken_image),
                                            ),
                                          ),
                                        if (!deleted &&
                                            (data['text']
                                                    ?.toString()
                                                    .isNotEmpty ??
                                                false))
                                          Text(
                                            data['text'].toString(),
                                            style: TextStyle(
                                              color: isMine
                                                  ? Theme.of(context)
                                                      .colorScheme
                                                      .onPrimary
                                                  : Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                            ),
                                          ),
                                        if (reaction.isNotEmpty)
                                          Text(reaction,
                                              style: const TextStyle(
                                                  fontSize: 16)),
                                        if (isMine)
                                          Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (isRead)
                                                  const Padding(
                                                    padding: EdgeInsets.only(
                                                        right: 4),
                                                    child: Text('Seen',
                                                        style: TextStyle(
                                                            color: Color(
                                                                0xFF1684FF),
                                                            fontSize: 10)),
                                                  ),
                                                Icon(
                                                  isRead
                                                      ? Icons.done_all
                                                      : Icons.done,
                                                  size: 15,
                                                  color: isRead
                                                      ? const Color(0xFF1684FF)
                                                      : null,
                                                ),
                                              ]),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ))
                        ]);
                      },
                    )),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ValueListenableBuilder<Uint8List?>(
            valueListenable: _photoBytes,
            builder: (context, photo, child) =>
                Column(mainAxisSize: MainAxisSize.min, children: [
              if (_replyText != null)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.reply, size: 18),
                  title: Text('Replying to: $_replyText',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    tooltip: 'Cancel reply',
                    onPressed: () => setState(() => _replyText = null),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ),
              if (photo != null)
                Stack(children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(photo,
                            height: 64, width: 64, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 68,
                    child: IconButton(
                      tooltip: 'Remove photo',
                      onPressed: () => _photoBytes.value = null,
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ]),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                  child: Row(
                    children: [
                      PopupMenuButton<String>(
                        tooltip: 'Attach photo',
                        icon: _choosingPhoto
                            ? const SizedBox.square(
                                dimension: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.add_circle_outline),
                        onSelected: (source) => _pickPhoto(
                          source == 'camera'
                              ? ImageSource.camera
                              : ImageSource.gallery,
                        ),
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                              value: 'gallery', child: Text('Choose photo')),
                          PopupMenuItem(
                              value: 'camera', child: Text('Take photo')),
                        ],
                      ),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          minLines: 1,
                          maxLines: 4,
                          maxLength: 4000,
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _send(),
                          decoration: const InputDecoration(
                            hintText: 'Write a message',
                            counterText: '',
                          ),
                        ),
                      ),
                      IconButton.filled(
                        tooltip: 'Send message',
                        onPressed: _sending ? null : _send,
                        icon: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
              )
            ]),
          ),
        ],
      ),
    );
  }
}

ImageProvider<Object>? _memoryPhoto(String? value) {
  if (value == null || value.isEmpty) return null;
  if (value.startsWith('https://') || value.startsWith('http://')) {
    return NetworkImage(value);
  }
  try {
    return MemoryImage(base64Decode(value));
  } on FormatException {
    return null;
  }
}

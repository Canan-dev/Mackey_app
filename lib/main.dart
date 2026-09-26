import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

const lime = Color(0xffd5f26a);
const background = Color(0xff111315);
const panel = Color(0xff232729);
const muted = Color(0xff969b9a);
const leadersAccessPassword = 'Dec2007';

class PendingMessage {
  final String localId;
  final String room;
  final String author;
  final String text;
  final String? attachmentUrl;
  final String? attachmentName;
  final DateTime createdAt;

  PendingMessage({
    required this.localId,
    required this.room,
    required this.author,
    required this.text,
    this.attachmentUrl,
    this.attachmentName,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'localId': localId,
        'room': room,
        'author': author,
        'text': text,
        'attachmentUrl': attachmentUrl,
        'attachmentName': attachmentName,
        'createdAt': createdAt.toIso8601String(),
      };

  factory PendingMessage.fromJson(Map<String, dynamic> json) => PendingMessage(
        localId: json['localId'] as String,
        room: json['room'] as String? ?? 'main',
        author: json['author'] as String? ?? 'Me',
        text: json['text'] as String? ?? '',
        attachmentUrl: json['attachmentUrl'] as String?,
        attachmentName: json['attachmentName'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  ChatMessage toChatMessage() => ChatMessage(
        id: localId,
        author: author,
        text: text,
        time: 'Pending 🕒',
        attachmentUrl: attachmentUrl,
        attachmentName: attachmentName,
        isPending: true,
      );
}

Future<void> savePendingQueue(List<PendingMessage> list) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = list.map((m) => jsonEncode(m.toJson())).toList();
  await prefs.setStringList('pending_messages_queue', raw);
}

Future<List<PendingMessage>> getPendingQueue() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getStringList('pending_messages_queue') ?? [];
  return raw
      .map((str) =>
          PendingMessage.fromJson(jsonDecode(str) as Map<String, dynamic>))
      .toList();
}

Future<void> saveCachedDbMessages(List<Map<String, dynamic>> list) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = list.map((m) => jsonEncode(m)).toList();
  await prefs.setStringList('cached_db_messages', raw);
}

Future<List<Map<String, dynamic>>> getCachedDbMessages() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getStringList('cached_db_messages') ?? [];
  return raw
      .map((str) => jsonDecode(str) as Map<String, dynamic>)
      .toList();
}

Future<void> saveSavedUsername(String name) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('saved_username', name);
}

Future<String?> getSavedUsername() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('saved_username');
}

Future<void> clearSavedUsername() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('saved_username');
}

Future<void> saveSavedBackground(int colorValue) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('saved_background_color', colorValue);
}

Future<int?> getSavedBackground() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt('saved_background_color');
}

Future<void> saveDeletedForMeIds(Set<String> ids) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList('deleted_for_me_ids', ids.toList());
}

Future<Set<String>> getDeletedForMeIds() async {
  final prefs = await SharedPreferences.getInstance();
  final list = prefs.getStringList('deleted_for_me_ids') ?? [];
  return list.toSet();
}

Future<bool> isUsernameTaken(String username, {String? excludeUser}) async {
  if (!supabaseReady) return false;
  final clean = username.trim();
  if (clean.isEmpty) return false;
  if (excludeUser != null && clean.toLowerCase() == excludeUser.toLowerCase()) {
    return false;
  }
  try {
    final response = await Supabase.instance.client
        .from('messages')
        .select('author')
        .ilike('author', clean)
        .limit(1);
    return (response as List).isNotEmpty;
  } catch (_) {
    return false;
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.author,
    required this.text,
    required this.time,
    this.attachmentUrl,
    this.attachmentName,
    this.isPending = false,
  });
  final String id;
  final String author;
  final String text;
  final String time;
  final String? attachmentUrl;
  final String? attachmentName;
  final bool isPending;

  bool get isImageAttachment {
    if (attachmentUrl == null) return false;
    final name = (attachmentName ?? attachmentUrl!).toLowerCase();
    return name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png') ||
        name.endsWith('.gif') ||
        name.endsWith('.webp') ||
        name.endsWith('.bmp') ||
        name.endsWith('.svg');
  }

  factory ChatMessage.fromMap(Map<String, dynamic> data) {
    final timestamp = DateTime.tryParse(data['created_at'] as String? ?? '');
    return ChatMessage(
      id: data['id'].toString(),
      author: data['author'] as String? ?? 'Unknown',
      text: data['text'] as String? ?? '',
      time: data['created_at'] == 'Pending 🕒'
          ? 'Pending 🕒'
          : timestamp == null
              ? ''
              : _formatTime(timestamp),
      attachmentUrl: data['attachment_url'] as String?,
      attachmentName: data['attachment_name'] as String?,
      isPending: data['isPending'] == true,
    );
  }

  static String _formatTime(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${value.hour >= 12 ? 'PM' : 'AM'}';
  }
}

String supabaseUrl = '';
String supabaseAnonKey = '';
final supabaseStartupError = ValueNotifier<String?>(null);
final supabaseReadyNotifier = ValueNotifier<bool>(false);
bool supabaseReady = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MmcApp());
  try {
    await dotenv.load(fileName: '.env', isOptional: true);
  } catch (_) {
    // The app still supports --dart-define when no dotenv file is available.
  }
  if (dotenv.env.isEmpty) {
    try {
      final rawEnv = (await rootBundle.loadString('.env')).trim();
      if (rawEnv.isNotEmpty && !rawEnv.contains('=')) {
        dotenv.env['SUPABASE_ANON_KEY'] = rawEnv;
      }
    } catch (_) {
      // Missing .env is reported below.
    }
  }
  supabaseUrl =
      dotenv.env['SUPABASE_URL'] ??
      const String.fromEnvironment('SUPABASE_URL');
  supabaseAnonKey =
      dotenv.env['SUPABASE_ANON_KEY'] ??
      const String.fromEnvironment('SUPABASE_ANON_KEY');
  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    final missing = [
      if (supabaseUrl.isEmpty) 'SUPABASE_URL',
      if (supabaseAnonKey.isEmpty) 'SUPABASE_ANON_KEY',
    ].join(' and ');
    supabaseStartupError.value = 'Missing $missing in .env.';
    return;
  }
  try {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
    );
    supabaseReady = true;
    supabaseReadyNotifier.value = true;
  } catch (error) {
    supabaseStartupError.value = error.toString();
  }
}

class MmcApp extends StatelessWidget {
  const MmcApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'MMC',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: lime,
        brightness: Brightness.dark,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: .06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: .1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: .1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lime),
        ),
      ),
    ),
    home: ValueListenableBuilder<String?>(
      valueListenable: supabaseStartupError,
      builder: (context, startupError, _) {
        if (startupError != null) {
          return LoginPage(startupError: startupError);
        }
        return FutureBuilder<String?>(
          future: getSavedUsername(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(color: lime),
                ),
              );
            }
            final saved = snapshot.data;
            if (saved != null && saved.trim().isNotEmpty) {
              return ChatPage(user: saved.trim());
            }
            return const LoginPage();
          },
        );
      },
    ),
  );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.startupError});

  final String? startupError;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final username = TextEditingController();
  String? error;
  bool isLoading = false;

  @override
  void dispose() {
    username.dispose();
    super.dispose();
  }

  Future<void> enter() async {
    final name = username.text.trim();
    if (name.isEmpty) {
      setState(() => error = 'Please enter your username.');
      return;
    }
    setState(() {
      isLoading = true;
      error = null;
    });

    final saved = await getSavedUsername();
    // Check if taken by someone else
    if (saved != name && await isUsernameTaken(name)) {
      if (mounted) {
        setState(() {
          isLoading = false;
          error = 'Username "$name" is already taken. Please choose another one.';
        });
      }
      return;
    }

    await saveSavedUsername(name);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ChatPage(user: name)),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Card(
            color: panel.withValues(alpha: .88),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: lime,
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: const Icon(
                      Icons.forum_rounded,
                      color: background,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'A QUIETER KIND OF CONNECTION',
                    style: TextStyle(
                      color: muted,
                      fontSize: 10,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text.rich(
                    TextSpan(
                      text: 'Welcome to ',
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w300,
                      ),
                      children: [
                        TextSpan(
                          text: 'MMC',
                          style: TextStyle(
                            color: lime,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Your private group space for the people and conversations that matter.',
                    style: TextStyle(color: Color(0xffadb2af), height: 1.5),
                  ),
                  if (widget.startupError != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Supabase setup: ${widget.startupError}',
                      style: const TextStyle(
                        color: Color(0xffffb1a8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  TextField(
                    controller: username,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => enter(),
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      hintText: 'Your name',
                    ),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        error!,
                        style: const TextStyle(
                          color: Color(0xffff9b8e),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: isLoading ? null : enter,
                      style: FilledButton.styleFrom(
                        backgroundColor: lime,
                        foregroundColor: background,
                        padding: const EdgeInsets.all(15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: background,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Enter MMC',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Icon(Icons.arrow_outward),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.user, this.room = 'main'});
  final String user;
  final String room;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final draft = TextEditingController();
  final profileUsername = TextEditingController();
  final scrollController = ScrollController();
  final messagesController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  RealtimeChannel? messagesChannel;
  Stream<List<Map<String, dynamic>>> get messageStream =>
      messagesController.stream;
  String? connectionError;
  Color selectedBackground = background;
  Color profileBackground = background;
  bool profileOpen = false;
  String currentUser = '';
  Set<String> deletedForMeIds = {};
  List<PendingMessage> pendingQueue = [];
  Timer? syncTimer;

  static const List<Color> palette = [
    Color(0xff111315),
    Color(0xff1f2a37),
    Color(0xff2d3727),
    Color(0xff3a1f2a),
  ];

  Color get composerBackground => _composerColor(selectedBackground);
  Color get composerText => _textColorForBackground(selectedBackground);

  @override
  void initState() {
    super.initState();
    currentUser = widget.user;
    profileUsername.text = widget.user;
    profileBackground = selectedBackground;
    _loadSavedBackground();
    _loadDeletedForMeIds();
    _loadPendingQueue();
    syncTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _syncPendingQueue(),
    );
    supabaseReadyNotifier.addListener(_onSupabaseReady);
    if (supabaseReady) _subscribeToMessages();
  }

  Future<void> _loadPendingQueue() async {
    final queue = await getPendingQueue();
    if (mounted) {
      setState(() {
        pendingQueue = queue;
      });
      _loadMessages();
    }
  }

  Future<void> _syncPendingQueue() async {
    if (pendingQueue.isEmpty || !supabaseReady) return;
    final toSync = List<PendingMessage>.from(pendingQueue);
    bool syncedAny = false;

    for (final pending in toSync) {
      try {
        await Supabase.instance.client.from('messages').insert({
          'room': pending.room,
          'author': pending.author,
          'text': pending.text,
          'attachment_url': pending.attachmentUrl,
          'attachment_name': pending.attachmentName,
        });
        pendingQueue.removeWhere((item) => item.localId == pending.localId);
        syncedAny = true;
      } catch (_) {
        break;
      }
    }

    if (syncedAny) {
      await savePendingQueue(pendingQueue);
      await _loadMessages();
    }
  }

  Future<void> _loadDeletedForMeIds() async {
    final ids = await getDeletedForMeIds();
    if (mounted) {
      setState(() {
        deletedForMeIds = ids;
      });
      _loadMessages();
    }
  }

  Future<void> _loadSavedBackground() async {
    final bgInt = await getSavedBackground();
    if (bgInt != null && mounted) {
      setState(() {
        selectedBackground = Color(bgInt);
        profileBackground = Color(bgInt);
      });
    }
  }

  void _onSupabaseReady() {
    if (supabaseReadyNotifier.value && messagesChannel == null) {
      _subscribeToMessages();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _subscribeToMessages() async {
    await _loadMessages();
    messagesChannel = Supabase.instance.client
        .channel('room-${widget.room}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room',
            value: widget.room,
          ),
          callback: (_) => _loadMessages(),
        )
        .subscribe();
  }

  Future<void> _loadMessages() async {
    List<Map<String, dynamic>> dbRows = [];
    if (supabaseReady) {
      try {
        final data = await Supabase.instance.client
            .from('messages')
            .select()
            .eq('room', widget.room)
            .order('created_at', ascending: false);
        dbRows = List<Map<String, dynamic>>.from(data);
        await saveCachedDbMessages(dbRows);
        if (mounted &&
            connectionError != null &&
            connectionError!.contains('offline')) {
          setState(() => connectionError = null);
        }
      } catch (_) {
        dbRows = await getCachedDbMessages();
      }
    } else {
      dbRows = await getCachedDbMessages();
    }

    if (!messagesController.isClosed) {
      final filteredDb = dbRows
          .where((row) => !deletedForMeIds.contains(row['id'].toString()))
          .toList();

      final roomPending = pendingQueue
          .where((item) => item.room == widget.room)
          .map((item) => {
                'id': item.localId,
                'author': item.author,
                'text': item.text,
                'created_at': 'Pending 🕒',
                'attachment_url': item.attachmentUrl,
                'attachment_name': item.attachmentName,
                'isPending': true,
              })
          .toList();

      final combined = [...roomPending, ...filteredDb];
      messagesController.add(combined);
      _scrollToBottom();
    }
  }

  Color _composerColor(Color base) {
    final hsl = HSLColor.fromColor(base);
    return hsl.withLightness((hsl.lightness + 0.12).clamp(0.0, 1.0)).toColor();
  }

  Color _bubbleColor(Color base) {
    final hsl = HSLColor.fromColor(base);
    return hsl.withLightness((hsl.lightness + 0.18).clamp(0.0, 1.0)).toColor();
  }

  Color _textColorForBackground(Color base) {
    final hsl = HSLColor.fromColor(base);
    return hsl.lightness > 0.55
        ? const Color(0xff111315)
        : const Color(0xfff6f4ef);
  }

  Future<void> saveProfile() async {
    setState(() {
      selectedBackground = profileBackground;
      profileOpen = false;
      connectionError = null;
    });

    await saveSavedBackground(profileBackground.toARGB32());
  }

  Future<void> openAttachment(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void showImagePreview(String url, String name) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: CircleAvatar(
                backgroundColor: Colors.black.withValues(alpha: 0.7),
                child: IconButton(
                  icon: const Icon(Icons.download_rounded, color: Colors.white),
                  onPressed: () => openAttachment(url),
                  tooltip: 'Download',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> send() async {
    final text = draft.text.trim();
    if (text.isEmpty) return;
    draft.clear();
    try {
      await _sendMessage(text: text);
    } on PostgrestException catch (error) {
      if (mounted) {
        setState(() => connectionError = _supabaseError(error));
      }
    } catch (_) {
      if (mounted) {
        setState(() => connectionError = 'Could not send this message.');
      }
    }
  }

  String _supabaseError(PostgrestException error) {
    if (error.code == '42501') {
      return 'Supabase permissions are blocking this message. Run the SQL setup.';
    }
    return error.message;
  }

  Future<void> _sendMessage({
    String text = '',
    String? attachmentUrl,
    String? attachmentName,
  }) async {
    if (text.isEmpty && attachmentUrl == null) return;

    final pending = PendingMessage(
      localId: 'pending_${DateTime.now().microsecondsSinceEpoch}',
      room: widget.room,
      author: currentUser,
      text: text,
      attachmentUrl: attachmentUrl,
      attachmentName: attachmentName,
      createdAt: DateTime.now(),
    );

    bool sentOnline = false;
    if (supabaseReady) {
      try {
        await Supabase.instance.client.from('messages').insert({
          'room': widget.room,
          'author': currentUser,
          'text': text,
          'attachment_url': attachmentUrl,
          'attachment_name': attachmentName,
        });
        sentOnline = true;
      } catch (_) {
        sentOnline = false;
      }
    }

    if (!sentOnline) {
      pendingQueue.add(pending);
      await savePendingQueue(pendingQueue);
      if (mounted) {
        setState(() {
          connectionError =
              'Saved offline. Message will send when back online.';
        });
      }
    }
    await _loadMessages();
  }

  Future<void> pickAttachment({required bool imageOnly}) async {
    final result = await FilePicker.pickFiles(
      type: imageOnly ? FileType.image : FileType.any,
    );
    if (result.isEmpty) {
      return;
    }
    final file = result.first;
    final data = await file.readAsBytes();
    final path =
        '${widget.room}/${DateTime.now().microsecondsSinceEpoch}_${file.name}';
    try {
      setState(() => connectionError = 'Uploading ${file.name}...');
      await Supabase.instance.client.storage
          .from('attachments')
          .uploadBinary(
            path,
            data,
            fileOptions: const FileOptions(upsert: false),
          );
      await _sendMessage(
        attachmentUrl: Supabase.instance.client.storage
            .from('attachments')
            .getPublicUrl(path),
        attachmentName: file.name,
      );
      if (mounted) setState(() => connectionError = null);
    } catch (error) {
      if (mounted) {
        setState(
          () => connectionError = error is PostgrestException
              ? _supabaseError(error)
              : error is StorageException
                  ? 'Storage error: ${error.message}'
                  : 'Could not upload ${file.name}: $error',
        );
      }
    }
  }

  Future<void> removeMessage(
    ChatMessage message, {
    required bool everywhere,
  }) async {
    if (mounted) Navigator.pop(context);
    if (everywhere) {
      try {
        final parsedId = int.tryParse(message.id);
        await Supabase.instance.client
            .from('messages')
            .delete()
            .eq('id', parsedId ?? message.id);
        await _loadMessages();
      } catch (error) {
        if (mounted) {
          setState(() => connectionError = 'Could not delete message: $error');
        }
      }
    } else {
      setState(() {
        deletedForMeIds.add(message.id);
      });
      await saveDeletedForMeIds(deletedForMeIds);
      await _loadMessages();
    }
  }

  Future<void> openLeadersSpace() async {
    setState(() => profileOpen = false);
    var enteredPassword = '';
    final password = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('MMC Leaders Chat Space'),
        content: TextField(
          autofocus: true,
          obscureText: true,
          textInputAction: TextInputAction.done,
          onChanged: (value) => enteredPassword = value,
          onSubmitted: (_) => Navigator.of(dialogContext).pop(enteredPassword),
          decoration: const InputDecoration(
            labelText: 'Password',
            hintText: 'Enter the leaders password',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(enteredPassword),
            child: const Text('Enter'),
          ),
        ],
      ),
    );
    if (!mounted || password == null) return;
    if (password != leadersAccessPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incorrect leaders password.')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatPage(user: currentUser, room: 'leaders'),
      ),
    );
  }

  @override
  void dispose() {
    syncTimer?.cancel();
    supabaseReadyNotifier.removeListener(_onSupabaseReady);
    messagesChannel?.unsubscribe();
    messagesController.close();
    scrollController.dispose();
    draft.dispose();
    profileUsername.dispose();
    super.dispose();
  }

  Widget _buildStatusBanner() {
    if (connectionError == null) return const SizedBox.shrink();

    final isInfo = connectionError!.contains('Uploading') ||
        connectionError!.contains('offline') ||
        connectionError!.contains('Saved') ||
        connectionError!.contains('Checking');

    final bg = isInfo
        ? lime.withValues(alpha: 0.15)
        : Colors.redAccent.withValues(alpha: 0.15);
    final border = isInfo
        ? lime.withValues(alpha: 0.4)
        : Colors.redAccent.withValues(alpha: 0.4);
    final fg = isInfo ? lime : const Color(0xffff9b8e);
    final icon = isInfo
        ? (connectionError!.contains('Uploading')
            ? Icons.cloud_upload_rounded
            : Icons.info_outline_rounded)
        : Icons.error_outline_rounded;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          if (connectionError!.contains('Uploading'))
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: fg,
              ),
            )
          else
            Icon(icon, color: fg, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              connectionError!,
              style: TextStyle(
                color: fg,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatBody = Column(
      children: [
        _buildStatusBanner(),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: messageStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('Could not load messages.'));
              }
              if (!snapshot.hasData && supabaseReady) {
                return const Center(child: CircularProgressIndicator());
              }
              final messages = (snapshot.data ?? <Map<String, dynamic>>[])
                  .map(ChatMessage.fromMap)
                  .toList();
              if (snapshot.hasData) {
                _scrollToBottom();
              }
              return messages.isEmpty
                  ? const Center(
                      child: Text(
                        'No messages yet',
                        style: TextStyle(color: muted),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                      itemCount: messages.length,
                      itemBuilder: (_, index) => messageTile(messages[index]),
                    );
            },
          ),
        ),
        SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: composerBackground,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: .08)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => pickAttachment(imageOnly: true),
                  icon: const Icon(Icons.photo_rounded),
                  color: composerText,
                  tooltip: 'Attach',
                  splashRadius: 18,
                ),
                IconButton(
                  onPressed: () => pickAttachment(imageOnly: false),
                  icon: const Icon(Icons.insert_drive_file_outlined),
                  color: composerText,
                  tooltip: 'Document',
                  splashRadius: 18,
                ),
                Expanded(
                  child: TextField(
                    controller: draft,
                    style: TextStyle(color: composerText),
                    onSubmitted: (_) => send(),
                    decoration: InputDecoration(
                      hintText: 'Message',
                      hintStyle: TextStyle(
                        color: composerText.withValues(alpha: .7),
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                CircleAvatar(
                  radius: 22,
                  backgroundColor: _bubbleColor(selectedBackground),
                  child: IconButton(
                    onPressed: send,
                    icon: const Icon(Icons.send_rounded),
                    color: _textColorForBackground(selectedBackground),
                    splashRadius: 20,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    final profileCard = Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: profileBackground.withValues(alpha: .96),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: .12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .2),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Profile',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              IconButton(
                onPressed: () => setState(() => profileOpen = false),
                icon: const Icon(Icons.close),
                splashRadius: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: .08)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: lime,
                  child: Text(
                    currentUser.isNotEmpty
                        ? currentUser[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      color: background,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentUser,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: const [
                          Icon(Icons.circle, color: Color(0xff4CAF50), size: 8),
                          SizedBox(width: 5),
                          Text(
                            'Active Member',
                            style: TextStyle(fontSize: 11, color: muted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: widget.room == 'leaders' ? null : openLeadersSpace,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.groups_rounded,
                    color: widget.room == 'leaders' ? muted : lime,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'MMC Leaders Chat Space',
                      style: TextStyle(
                        color: widget.room == 'leaders' ? muted : Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (widget.room != 'leaders')
                    const Icon(Icons.chevron_right, color: muted),
                ],
              ),
            ),
          ),
          if (widget.room == 'leaders') ...[
            const SizedBox(height: 4),
            InkWell(
              onTap: () => Navigator.of(context).pop(),
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.arrow_back_rounded, color: lime),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Back to MMC talk',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 6),
          const Text(
            'Background',
            style: TextStyle(fontSize: 12, color: muted),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(palette.length, (index) {
              final color = palette[index];
              final selected = profileBackground.toARGB32() == color.toARGB32();
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => setState(() => profileBackground = color),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 46,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? Colors.white
                              : Colors.white.withValues(alpha: .18),
                          width: selected ? 2 : 1,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      profileUsername.text = currentUser;
                      profileBackground = selectedBackground;
                      profileOpen = false;
                    });
                  },
                  child: const Text('Close'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: saveProfile,
                  style: FilledButton.styleFrom(
                    backgroundColor: lime,
                    foregroundColor: background,
                  ),
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () async {
                setState(() => profileOpen = false);
                await clearSavedUsername();
                if (context.mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                  );
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xffffb1a8),
              ),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: selectedBackground,
      appBar: AppBar(
        backgroundColor: selectedBackground.withValues(alpha: .96),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Image.asset(
                'assets/mmc-logo.jpg',
                width: 30,
                height: 30,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 9),
            Text(
              widget.room == 'leaders' ? 'MMC Leaders Chat Space' : 'MMC talk',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => setState(() {
                profileOpen = !profileOpen;
                if (profileOpen) {
                  profileUsername.text = currentUser;
                  profileBackground = selectedBackground;
                }
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .12),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: lime,
                      child: Text(
                        currentUser.isNotEmpty
                            ? currentUser[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          color: background,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      currentUser,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: profileOpen ? () => setState(() => profileOpen = false) : null,
        child: Stack(
          children: [
            chatBody,
            if (profileOpen)
              Positioned(
                top: 14,
                right: 14,
                child: GestureDetector(onTap: () {}, child: profileCard),
              ),
          ],
        ),
      ),
    );
  }

  Widget messageTile(ChatMessage message) {
    final mine =
        message.author.trim().toLowerCase() == currentUser.trim().toLowerCase();
    final bubbleColor = mine
        ? _bubbleColor(selectedBackground)
        : Colors.white.withValues(alpha: .08);
    final bubbleTextColor = mine
        ? _textColorForBackground(selectedBackground)
        : const Color(0xffd7dad6);
    final metaColor = mine
        ? _textColorForBackground(selectedBackground).withValues(alpha: .8)
        : muted;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => showModalBottomSheet(
          context: context,
          backgroundColor: panel,
          builder: (_) => SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  title: const Text('Delete for me'),
                  onTap: () => removeMessage(message, everywhere: false),
                ),
                if (mine)
                  ListTile(
                    title: const Text('Delete for everyone'),
                    onTap: () => removeMessage(message, everywhere: true),
                  ),
              ],
            ),
          ),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          margin: const EdgeInsets.symmetric(vertical: 7),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(mine ? 16 : 4),
              topRight: Radius.circular(mine ? 4 : 16),
              bottomLeft: const Radius.circular(16),
              bottomRight: const Radius.circular(16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${message.author}  ${message.time}',
                style: TextStyle(
                  color: message.isPending ? const Color(0xffffb74d) : metaColor,
                  fontSize: 10,
                  fontWeight:
                      message.isPending ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 5),
              if (message.text.isNotEmpty)
                Text(
                  message.text,
                  style: TextStyle(color: bubbleTextColor, height: 1.4),
                ),
              if (message.attachmentUrl != null) ...[
                if (message.text.isNotEmpty) const SizedBox(height: 8),
                if (message.isImageAttachment) ...[
                  GestureDetector(
                    onTap: () => showImagePreview(
                      message.attachmentUrl!,
                      message.attachmentName ?? 'Image',
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 220),
                        child: Image.network(
                          message.attachmentUrl!,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const SizedBox(
                              height: 100,
                              child: Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) => Row(
                            children: [
                              const Icon(Icons.broken_image, color: Colors.red),
                              const SizedBox(width: 8),
                              Text('Image unavailable', style: TextStyle(color: bubbleTextColor)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                InkWell(
                  onTap: () => openAttachment(message.attachmentUrl!),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        message.isImageAttachment
                            ? Icons.download_rounded
                            : Icons.attach_file,
                        color: bubbleTextColor,
                        size: 18,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          message.attachmentName ?? 'Attachment',
                          style: TextStyle(
                            color: bubbleTextColor,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

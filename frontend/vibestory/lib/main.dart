
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

// ─── Server ──────────────────────────────────────────────────────────────────
const String kBaseUrl = 'http://192.168.31.201:8000';

// ─── Color Palette (dark only) ────────────────────────────────────────────────
const Color kBg        = Color(0xFF0D0D0F);
const Color kSurface   = Color(0xFF161618);
const Color kCard      = Color(0xFF1C1C1F);
const Color kBorder    = Color(0xFF2A2A2E);
const Color kPrimary   = Color(0xFF7C6EFF);   // violet accent
const Color kAccent    = Color(0xFF4ECDC4);   // teal accent
const Color kGreen     = Color(0xFF34C759);
const Color kRed       = Color(0xFFFF453A);
const Color kText      = Color(0xFFF0F0F5);
const Color kMuted     = Color(0xFF8E8E9A);
const Color kDivider   = Color(0xFF252528);

// ─── Typography ───────────────────────────────────────────────────────────────
TextStyle kHead(double sz, {FontWeight fw = FontWeight.w700}) =>
    GoogleFonts.dmSans(fontSize: sz, fontWeight: fw, color: kText, letterSpacing: -0.3);

TextStyle kBody(double sz, {Color? color, FontWeight fw = FontWeight.w400}) =>
    GoogleFonts.dmSans(fontSize: sz, fontWeight: fw, color: color ?? kMuted);

// ─── API ──────────────────────────────────────────────────────────────────────
class Api {
  static String? _token;

  static Future<void> loadToken() async =>
      _token = (await SharedPreferences.getInstance()).getString('token');

  static Future<void> saveToken(String t) async {
    _token = t;
    (await SharedPreferences.getInstance()).setString('token', t);
  }

  static Future<void> clearToken() async {
    _token = null;
    final p = await SharedPreferences.getInstance();
    await p.remove('token');
    await p.remove('user_name');
  }

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  static Future<Map<String, dynamic>> post(String path, Map body) async {
    final r = await http.post(
      Uri.parse('$kBaseUrl$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    final d = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode >= 400) throw d['detail'] ?? 'Server error';
    return d;
  }

  static Future<Map<String, dynamic>> get(String path) async {
    final r = await http.get(Uri.parse('$kBaseUrl$path'), headers: _headers);
    final d = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode >= 400) throw d['detail'] ?? 'Server error';
    return d;
  }

  static Future<Map<String, dynamic>> uploadAudio(
      String path, String filePath) async {
    final req = http.MultipartRequest('POST', Uri.parse('$kBaseUrl$path'));
    req.headers['Authorization'] = 'Bearer $_token';
    req.files.add(await http.MultipartFile.fromPath('audio', filePath));
    final s = await req.send();
    return jsonDecode(await s.stream.bytesToString()) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> uploadImageBytes(
      String path, Uint8List bytes, String fn) async {
    final req = http.MultipartRequest('POST', Uri.parse('$kBaseUrl$path'));
    req.headers['Authorization'] = 'Bearer $_token';
    req.files.add(http.MultipartFile.fromBytes('image', bytes,
        filename: fn, contentType: MediaType('image', 'jpeg')));
    final s = await req.send();
    return jsonDecode(await s.stream.bytesToString()) as Map<String, dynamic>;
  }
}

// ─── App Entry ────────────────────────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(statusBarColor: Colors.transparent));
  await Api.loadToken();
  runApp(const VibeStoryApp());
}

class VibeStoryApp extends StatelessWidget {
  const VibeStoryApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'VibeStory',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: kBg,
          cardColor: kCard,
          dividerColor: kDivider,
          colorScheme: const ColorScheme.dark(
            primary: kPrimary,
            secondary: kAccent,
            surface: kSurface,
            background: kBg,
          ),
          textTheme: GoogleFonts.dmSansTextTheme(ThemeData.dark().textTheme),
        ),
        home: Api._token != null ? const MainNav() : const AuthScreen(),
      );
}

// ─── Shared UI components ─────────────────────────────────────────────────────

/// A card with a subtle border, no rounded corners by default
class VCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? color;
  final double radius;
  const VCard(
      {super.key,
      required this.child,
      this.padding,
      this.color,
      this.radius = 16});

  @override
  Widget build(BuildContext context) => Container(
        padding: padding ?? const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color ?? kCard,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: kBorder, width: 1),
        ),
        child: child,
      );
}

/// Primary action button
class VButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color color;
  final bool wide;
  final bool outlined;

  const VButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.color = kPrimary,
    this.wide = false,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedOpacity(
        opacity: disabled ? 0.45 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          width: wide ? double.infinity : null,
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: outlined ? Colors.transparent : color,
            borderRadius: BorderRadius.circular(12),
            border: outlined ? Border.all(color: color, width: 1.5) : null,
          ),
          child: Row(
            mainAxisSize: wide ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: outlined ? color : Colors.white, size: 18),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: GoogleFonts.dmSans(
                  color: outlined ? color : Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Labelled text field
class VField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboard;

  const VField({
    super.key,
    required this.ctrl,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.keyboard,
  });

  @override
  Widget build(BuildContext context) => TextField(
        controller: ctrl,
        obscureText: obscure,
        keyboardType: keyboard,
        style: kBody(15, color: kText),
        cursorColor: kPrimary,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: kBody(14),
          prefixIcon: Icon(icon, color: kMuted, size: 20),
          filled: true,
          fillColor: kSurface,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kBorder)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kBorder)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kPrimary, width: 1.5)),
        ),
      );
}

// ─── Auth Screen ──────────────────────────────────────────────────────────────
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true, _loading = false;
  String? _error;
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = _isLogin
          ? await Api.post('/api/auth/login',
              {'email': _emailCtrl.text.trim(), 'password': _passCtrl.text})
          : await Api.post('/api/auth/signup', {
              'name': _nameCtrl.text.trim(),
              'email': _emailCtrl.text.trim(),
              'password': _passCtrl.text,
            });
      await Api.saveToken(res['token']);
      (await SharedPreferences.getInstance())
          .setString('user_name', res['name']);
      if (!mounted) return;
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const MainNav()));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: kPrimary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.auto_stories_rounded,
                        color: kPrimary, size: 26),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _isLogin ? 'Welcome back' : 'Create account',
                    style: kHead(28),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isLogin
                        ? 'Sign in to continue'
                        : 'Start your story journey',
                    style: kBody(15),
                  ),
                  const SizedBox(height: 36),
                  if (!_isLogin) ...[
                    VField(
                        ctrl: _nameCtrl,
                        label: 'Full name',
                        icon: Icons.person_outline_rounded),
                    const SizedBox(height: 14),
                  ],
                  VField(
                      ctrl: _emailCtrl,
                      label: 'Email',
                      icon: Icons.mail_outline_rounded,
                      keyboard: TextInputType.emailAddress),
                  const SizedBox(height: 14),
                  VField(
                      ctrl: _passCtrl,
                      label: 'Password',
                      icon: Icons.lock_outline_rounded,
                      obscure: true),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: kRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: kRed.withOpacity(0.3)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.error_outline, color: kRed, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_error!, style: kBody(13, color: kRed))),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 24),
                  _loading
                      ? const Center(
                          child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  color: kPrimary, strokeWidth: 2)))
                      : VButton(
                          label: _isLogin ? 'Sign in' : 'Create account',
                          onTap: _submit,
                          wide: true),
                  const SizedBox(height: 20),
                  Center(
                    child: GestureDetector(
                      onTap: () => setState(() => _isLogin = !_isLogin),
                      child: Text(
                        _isLogin
                            ? "Don't have an account? Sign up"
                            : 'Already have an account? Sign in',
                        style: kBody(14, color: kPrimary,
                            fw: FontWeight.w500),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      );
}

// ─── Main Navigation ──────────────────────────────────────────────────────────
class MainNav extends StatefulWidget {
  const MainNav({super.key});
  @override
  State<MainNav> createState() => _MainNavState();
}

class _MainNavState extends State<MainNav> {
  int _idx = 0;

  static const _pages = [HomeScreen(), LearnScreen(), ProfileScreen()];

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(index: _idx, children: _pages),
        bottomNavigationBar: Container(
          height: 72,
          decoration: const BoxDecoration(
            color: kSurface,
            border: Border(top: BorderSide(color: kBorder)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(Icons.home_outlined, Icons.home_rounded, 'Home', 0),
              _NavItem(Icons.search_outlined, Icons.search_rounded, 'Learn', 1),
              _NavItem(Icons.person_outline_rounded,
                  Icons.person_rounded, 'Profile', 2),
            ].asMap().entries.map((e) {
              final item = e.value;
              return _NavItemWidget(
                icon: item.icon,
                activeIcon: item.activeIcon,
                label: item.label,
                idx: item.idx,
                sel: _idx,
                onTap: () => setState(() => _idx = item.idx),
              );
            }).toList(),
          ),
        ),
      );
}

class _NavItem {
  final IconData icon, activeIcon;
  final String label;
  final int idx;
  const _NavItem(this.icon, this.activeIcon, this.label, this.idx);
}

class _NavItemWidget extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final int idx, sel;
  final VoidCallback onTap;

  const _NavItemWidget({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.idx,
    required this.sel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = idx == sel;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(active ? activeIcon : icon,
                size: 22, color: active ? kPrimary : kMuted),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: active ? kPrimary : kMuted,
                fontWeight:
                    active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Home Screen ──────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _textCtrl = TextEditingController();
  final _recorder = AudioRecorder();
  bool _recording = false, _loading = false;
  String? _lang, _rawText, _error;
  int _numImages = 5;

  @override
  void dispose() {
    _textCtrl.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _toggleRecord() async {
    final perm = await Permission.microphone.request();
    if (!perm.isGranted) return;
    if (_recording) {
      final path = await _recorder.stop();
      setState(() => _recording = false);
      if (path != null) await _sendAudio(path);
    } else {
      final dir = await getTemporaryDirectory();
      await _recorder.start(const RecordConfig(),
          path: '${dir.path}/vs_rec.m4a');
      setState(() {
        _recording = true;
        _error = null;
      });
    }
  }

  Future<void> _pickAudio() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (r == null || r.files.isEmpty) return;
    final path = r.files.single.path;
    if (path != null) await _sendAudio(path);
  }

  Future<void> _sendAudio(String filePath) async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await Api.uploadAudio('/api/input/transcribe', filePath);
      setState(() {
        _textCtrl.text = res['english'] ?? '';
        _rawText = res['original'];
        _lang    = res['language'];
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Write or record your story idea first.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final res = await Api.post('/api/story/generate',
          {'text': text, 'num_images': _numImages});
      if (!mounted) return;
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  StoryGeneratingScreen(storyId: res['story_id'])));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding:
                  const EdgeInsets.fromLTRB(20, 20, 20, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Header
                  Row(children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: kPrimary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.auto_stories_rounded,
                          color: kPrimary, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Text('VibeStory', style: kHead(22)),
                  ]),
                  const SizedBox(height: 32),

                  Text('Your story', style: kHead(20)),
                  const SizedBox(height: 6),
                  Text('Describe what happened or imagine an adventure.',
                      style: kBody(14)),
                  const SizedBox(height: 16),

                  // Text input
                  VCard(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _textCtrl,
                      maxLines: 6,
                      style: kBody(15, color: kText),
                      cursorColor: kPrimary,
                      decoration: InputDecoration(
                        hintText:
                            'Once upon a time… (Hindi, Punjabi or English)',
                        hintStyle: kBody(14),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Voice input row
                  Text('Or use voice', style: kBody(13)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: VButton(
                        label: _recording ? 'Stop' : 'Record',
                        icon: _recording
                            ? Icons.stop_rounded
                            : Icons.mic_rounded,
                        color: _recording ? kRed : kAccent,
                        onTap: _loading ? null : _toggleRecord,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: VButton(
                        label: 'Upload audio',
                        icon: Icons.upload_file_rounded,
                        color: kSurface,
                        outlined: true,
                        onTap: _loading ? null : _pickAudio,
                      ),
                    ),
                  ]),

                  if (_recording) ...[
                    const SizedBox(height: 12),
                    Row(children: [
                      _PulseCircle(),
                      const SizedBox(width: 8),
                      Text('Recording…', style: kBody(13, color: kRed)),
                    ]),
                  ],

                  if (_lang != null && _lang != 'en' && _rawText != null) ...[
                    const SizedBox(height: 14),
                    VCard(
                      color: kAccent.withOpacity(0.07),
                      child: Row(children: [
                        const Icon(Icons.translate_rounded,
                            color: kAccent, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Translated from $_lang',
                              style: kBody(13, color: kAccent)),
                        ),
                      ]),
                    ),
                  ],

                  const SizedBox(height: 28),
                  const Divider(color: kDivider),
                  const SizedBox(height: 20),

                  // Number of images
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Images', style: kHead(15)),
                      Text('$_numImages', style: kHead(15)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: kPrimary,
                      inactiveTrackColor: kBorder,
                      thumbColor: kPrimary,
                      overlayColor: kPrimary.withOpacity(0.1),
                      trackHeight: 3,
                    ),
                    child: Slider(
                      value: _numImages.toDouble(),
                      min: 1,
                      max: 15,
                      divisions: 14,
                      onChanged: (v) =>
                          setState(() => _numImages = v.round()),
                    ),
                  ),

                  const SizedBox(height: 24),

                  if (_error != null) ...[
                    VCard(
                      color: kRed.withOpacity(0.08),
                      child: Row(children: [
                        const Icon(Icons.error_outline_rounded,
                            color: kRed, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(_error!, style: kBody(13, color: kRed))),
                      ]),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (_loading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: kPrimary, strokeWidth: 2),
                        ),
                      ),
                    )
                  else
                    VButton(
                      label: 'Generate story',
                      icon: Icons.bolt_rounded,
                      onTap: _recording ? null : _submit,
                      wide: true,
                    ),

                  const SizedBox(height: 40),
                ]),
              ),
            ),
          ],
        ),
      );
}

class _PulseCircle extends StatefulWidget {
  @override
  State<_PulseCircle> createState() => _PulseCircleState();
}

class _PulseCircleState extends State<_PulseCircle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext ctx) => AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: Color.lerp(kRed, Colors.red.shade300, _c.value),
            shape: BoxShape.circle,
          ),
        ),
      );
}

// ─── Story Generating Screen ──────────────────────────────────────────────────
class StoryGeneratingScreen extends StatefulWidget {
  final String storyId;
  const StoryGeneratingScreen({super.key, required this.storyId});
  @override
  State<StoryGeneratingScreen> createState() =>
      _StoryGeneratingScreenState();
}

class _StoryGeneratingScreenState extends State<StoryGeneratingScreen> {
  Timer? _poll;
  String _step = 'Starting…';
  List<String> _images = [];
  List<Map<String, dynamic>> _parts = [];
  String? _audioUrl;
  bool _done = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 2), (_) => _tick());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _tick() async {
    try {
      final res = await Api.get('/api/story/${widget.storyId}/status');
      if (!mounted) return;
      final status = res['status'] ?? '';
      setState(() {
        _step   = res['step']   ?? '';
        _images = List<String>.from(res['images'] ?? []);
        _parts  = List<Map<String, dynamic>>.from(res['parts'] ?? []);
        _audioUrl = res['audio_url'];
      });
      if (status == 'done')  { _poll?.cancel(); setState(() => _done = true); }
      if (status == 'error') { _poll?.cancel(); setState(() => _error = _step); }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: kBg,
        appBar: AppBar(
          backgroundColor: kBg,
          elevation: 0,
          iconTheme: const IconThemeData(color: kText),
          title: Text('Generating', style: kHead(17)),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: kMuted, size: 20),
              onPressed: _tick,
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              // Status card
              VCard(
                child: Row(children: [
                  if (!_done && _error == null)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: kPrimary, strokeWidth: 2),
                    )
                  else
                    Icon(_done ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                        color: _done ? kGreen : kRed, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(_error ?? _step, style: kBody(14, color: kText)),
                  ),
                ]),
              ),
              const SizedBox(height: 12),

              // Info note
              VCard(
                color: kPrimary.withOpacity(0.06),
                child: Row(children: [
                  const Icon(Icons.info_outline_rounded,
                      color: kPrimary, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You can go back while this generates.',
                      style: kBody(12, color: kPrimary),
                    ),
                  ),
                ]),
              ),

              const SizedBox(height: 16),

              Expanded(
                child: _images.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.image_search_rounded,
                                color: kMuted, size: 48),
                            const SizedBox(height: 12),
                            Text('Images will appear here…',
                                style: kBody(14)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _images.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 16),
                        itemBuilder: (_, i) => ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(
                            '$kBaseUrl${_images[i]}',
                            width: double.infinity,
                            fit: BoxFit.cover,
                            loadingBuilder: (_, child, prog) => prog == null
                                ? child
                                : const SizedBox(
                                    height: 160,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                          color: kPrimary, strokeWidth: 2),
                                    ),
                                  ),
                          ),
                        ),
                      ),
              ),

              if (_done) ...[
                const SizedBox(height: 16),
                VButton(
                  label: 'Play story',
                  icon: Icons.play_circle_outline_rounded,
                  wide: true,
                  color: kGreen,
                  onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StoryPlayScreen(
                        storyId: widget.storyId,
                        images: _images,
                        parts: _parts,
                        audioUrl: _audioUrl ?? '',
                      ),
                    ),
                  ),
                ),
              ],
            ]),
          ),
        ),
      );
}

// ─── Story Play Screen ────────────────────────────────────────────────────────
class StoryPlayScreen extends StatefulWidget {
  final String storyId, audioUrl;
  final List<String> images;
  final List<Map<String, dynamic>> parts;

  const StoryPlayScreen({
    super.key,
    required this.storyId,
    required this.images,
    required this.parts,
    required this.audioUrl,
  });

  @override
  State<StoryPlayScreen> createState() => _StoryPlayScreenState();
}

class _StoryPlayScreenState extends State<StoryPlayScreen> {
  final _player = AudioPlayer();
  int _imgIdx = 0;
  bool _playing = false, _loading = false;
  Duration _pos = Duration.zero, _dur = Duration.zero;
  String? _audioError;

  @override
  void initState() {
    super.initState();
    _player.setReleaseMode(ReleaseMode.stop);
    _player.onDurationChanged
        .listen((d) { if (mounted) setState(() => _dur = d); });
    _player.onPositionChanged.listen((p) {
      if (!mounted) return;
      setState(() {
        _pos = p;
        if (_dur.inMilliseconds > 0 && widget.images.isNotEmpty) {
          final frac = p.inMilliseconds / _dur.inMilliseconds;
          _imgIdx = (frac * widget.images.length)
              .floor()
              .clamp(0, widget.images.length - 1);
        }
      });
    });
    _player.onPlayerComplete
        .listen((_) { if (mounted) setState(() { _playing = false; _imgIdx = 0; }); });
  }

  Future<void> _togglePlay() async {
    if (_playing) {
      await _player.pause();
      setState(() => _playing = false);
      return;
    }
    if (widget.audioUrl.isEmpty) {
      setState(() => _audioError = 'Audio not available.');
      return;
    }
    setState(() { _loading = true; _audioError = null; });
    try {
      if (_pos == Duration.zero || _pos >= _dur) {
        await _player.stop();
        await _player.setSourceUrl('$kBaseUrl${widget.audioUrl}');
      }
      await _player.resume();
      setState(() => _playing = true);
    } catch (e) {
      setState(() => _audioError = 'Cannot play audio.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  void _goLearn() async {
    if (_playing) { await _player.pause(); setState(() => _playing = false); }
    if (!mounted) return;
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => LearnFromStoryScreen(
                storyId: widget.storyId, images: widget.images)));
  }

  @override
  void dispose() { _player.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final imgs    = widget.images;
    final partTxt = _imgIdx < widget.parts.length
        ? (widget.parts[_imgIdx]['text'] as String? ?? '')
        : '';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: kText),
        title: Text('Story', style: kHead(17)),
        actions: [
          TextButton.icon(
            onPressed: _goLearn,
            icon: const Icon(Icons.school_outlined, color: kAccent, size: 18),
            label: Text('Learn',
                style: GoogleFonts.dmSans(
                    color: kAccent,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(children: [
          // Main image
          Expanded(
            child: imgs.isEmpty
                ? const Center(
                    child: Icon(Icons.image_outlined, color: kMuted, size: 64))
                : AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    child: Image.network(
                      '$kBaseUrl${imgs[_imgIdx]}',
                      key: ValueKey(_imgIdx),
                      width: double.infinity,
                      fit: BoxFit.contain,
                    ),
                  ),
          ),

          // Dot indicators
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                imgs.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _imgIdx ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _imgIdx ? kPrimary : kBorder,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),

          // Part text
          if (partTxt.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              child: Text(partTxt,
                  textAlign: TextAlign.center,
                  style: kBody(13, color: kText, fw: FontWeight.w500)),
            ),

          if (_audioError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(_audioError!, style: kBody(12, color: kRed)),
            ),

          // Controls
          Container(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            color: Colors.black,
            child: Column(children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: kPrimary,
                  inactiveTrackColor: kBorder,
                  thumbColor: kPrimary,
                  trackHeight: 3,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 6),
                ),
                child: Slider(
                  value: _dur.inMilliseconds == 0
                      ? 0
                      : (_pos.inMilliseconds / _dur.inMilliseconds)
                          .clamp(0.0, 1.0),
                  onChanged: _dur.inMilliseconds > 0
                      ? (v) => _player.seek(Duration(
                          milliseconds: (v * _dur.inMilliseconds).round()))
                      : null,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_fmt(_pos), style: kBody(11)),
                    Text(_fmt(_dur), style: kBody(11)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous_rounded,
                      color: kMuted, size: 28),
                  onPressed: () => setState(() =>
                      _imgIdx = (_imgIdx - 1).clamp(0, imgs.length - 1)),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: _loading ? null : _togglePlay,
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: kPrimary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: kPrimary.withOpacity(0.35),
                            blurRadius: 20)
                      ],
                    ),
                    child: _loading
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Icon(
                            _playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 30),
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.skip_next_rounded,
                      color: kMuted, size: 28),
                  onPressed: () => setState(() =>
                      _imgIdx = (_imgIdx + 1).clamp(0, imgs.length - 1)),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─── Learn From Story Screen ──────────────────────────────────────────────────
class LearnFromStoryScreen extends StatefulWidget {
  final String storyId;
  final List<String> images;

  const LearnFromStoryScreen(
      {super.key, required this.storyId, required this.images});

  @override
  State<LearnFromStoryScreen> createState() => _LearnFromStoryScreenState();
}

class _LearnFromStoryScreenState extends State<LearnFromStoryScreen> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: kBg,
        appBar: AppBar(
          backgroundColor: kBg,
          elevation: 0,
          iconTheme: const IconThemeData(color: kText),
          title: Text('Learn from story', style: kHead(17)),
        ),
        body: SafeArea(
          child: Column(children: [
            // Horizontal image picker
            SizedBox(
              height: 88,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: widget.images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => setState(() => _selected = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: i == _selected ? kPrimary : kBorder,
                        width: i == _selected ? 2 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: Image.network(
                        '$kBaseUrl${widget.images[i]}',
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Divider(color: kDivider, height: 1),
            Expanded(
              child: LearnImageScreen(
                imageUrl: widget.images[_selected],
                storyId: widget.storyId,
                imageIndex: _selected,
              ),
            ),
          ]),
        ),
      );
}

// ─── Learn Screen (tab) ───────────────────────────────────────────────────────
class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});
  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  List<Map<String, dynamic>> _stories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res =
          await Api.get('/api/profile');
      setState(() =>
          _stories = List<Map<String, dynamic>>.from(res['stories'] ?? []));
    } catch (_) {}
    finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(children: [
                Text('Learn', style: kHead(22)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded,
                      color: kMuted, size: 20),
                  onPressed: _load,
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Text('Tap a story image to explore it.',
                  style: kBody(14)),
            ),
            const Divider(color: kDivider, height: 1),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: kPrimary, strokeWidth: 2))
                  : _stories.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.menu_book_outlined,
                                  color: kMuted, size: 48),
                              const SizedBox(height: 12),
                              Text('No stories yet.', style: kBody(14)),
                            ],
                          ),
                        )
                      : _buildList(),
            ),
          ],
        ),
      );

  Widget _buildList() => ListView.separated(
        padding:
            const EdgeInsets.fromLTRB(20, 16, 20, 100),
        itemCount: _stories.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (ctx, i) {
          final s    = _stories[i];
          final imgs = List<String>.from(s['images'] ?? []);
          return VCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text('Story ${i + 1}',
                  style: kHead(14)),
              const SizedBox(height: 10),
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: imgs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, j) => GestureDetector(
                    onTap: () => Navigator.push(
                      ctx,
                      MaterialPageRoute(
                        builder: (_) => LearnImageScreen(
                          imageUrl: imgs[j],
                          storyId: s['_id'],
                          imageIndex: j,
                        ),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        '$kBaseUrl${imgs[j]}',
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          );
        },
      );
}

// ─── Learn Image Screen ───────────────────────────────────────────────────────
class LearnImageScreen extends StatefulWidget {
  final String imageUrl, storyId;
  final int imageIndex;

  const LearnImageScreen({
    super.key,
    required this.imageUrl,
    required this.storyId,
    required this.imageIndex,
  });

  @override
  State<LearnImageScreen> createState() => _LearnImageScreenState();
}

class _UserBox {
  Offset start, end;
  String label;
  _UserBox({required this.start, required this.end, this.label = ''});
  Rect get rect => Rect.fromPoints(start, end);
}

class _LearnImageScreenState extends State<LearnImageScreen> {
  List<Map<String, dynamic>> _yoloDets = [];
  bool _detectLoading = false, _showYolo = false;
  bool _drawMode = false, _submitted = false;
  Offset? _drawStart, _drawCurrent;
  List<_UserBox> _userBoxes = [];
  final GlobalKey _imgKey = GlobalKey();
  static const double _natW = 800, _natH = 400;

  Future<void> _runYolo() async {
    setState(() { _detectLoading = true; _showYolo = false; });
    try {
      final r = await http.get(
        Uri.parse('$kBaseUrl${widget.imageUrl}'),
        headers: {'Authorization': 'Bearer ${Api._token}'},
      );
      final res = await Api.uploadImageBytes(
          '/api/learn/detect', r.bodyBytes, 'image.jpg');
      setState(() {
        _yoloDets = List<Map<String, dynamic>>.from(res['detections'] ?? []);
        _showYolo = true;
      });
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Detection failed: $e')));
    } finally {
      if (mounted) setState(() => _detectLoading = false);
    }
  }

  Future<void> _renameYoloDet(int idx) async {
    final ctrl =
        TextEditingController(text: _yoloDets[idx]['label'] as String? ?? '');
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kCard,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Rename label', style: kHead(16)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: kBody(14, color: kText),
          cursorColor: kPrimary,
          decoration: InputDecoration(
            hintText: 'Correct label…',
            hintStyle: kBody(14),
            filled: true,
            fillColor: kSurface,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: kBorder)),
          ),
        ),
        actions: [
          VButton(
            label: 'Save',
            onTap: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) { Navigator.pop(context); return; }
              setState(() => _yoloDets[idx]['label'] = name);
              Navigator.pop(context);
              try {
                await Api.post('/api/learn/rename-label', {
                  'story_id':    widget.storyId,
                  'image_index': widget.imageIndex,
                  'label_index': idx,
                  'new_name':    name,
                });
              } catch (_) {}
            },
          ),
        ],
      ),
    );
  }

  Future<void> _submitLabels() async {
    if (_userBoxes.isEmpty ||
        _userBoxes.any((b) => b.label.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Label all boxes first.')));
      return;
    }
    final sz = (_imgKey.currentContext?.findRenderObject() as RenderBox?)?.size;
    final labels = _userBoxes.map((b) {
      final r  = b.rect;
      final sx = _natW / (sz?.width ?? _natW);
      final sy = _natH / (sz?.height ?? _natH);
      return {
        'label': b.label,
        'box': {
          'x':      (r.left * sx).round(),
          'y':      (r.top * sy).round(),
          'width':  (r.width * sx).round(),
          'height': (r.height * sy).round(),
        },
      };
    }).toList();

    try {
      final res = await Api.post('/api/learn/submit-labels', {
        'story_id':    widget.storyId,
        'image_index': widget.imageIndex,
        'image_url':   widget.imageUrl,
        'labels':      labels,
      });
      setState(() => _submitted = true);
      if (mounted)
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: kCard,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: Text('Submitted', style: kHead(16)),
            content: Text(
              'Found ${_userBoxes.length} object${_userBoxes.length == 1 ? '' : 's'}.\n'
              '+${res['points_awarded']} pts  ·  Total: ${res['new_score']}',
              style: kBody(14, color: kText),
            ),
            actions: [
              VButton(
                  label: 'Done',
                  onTap: () => Navigator.pop(context))
            ],
          ),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  void _onPanStart(DragStartDetails d) {
    if (!_drawMode) return;
    final box =
        _imgKey.currentContext!.findRenderObject() as RenderBox;
    setState(() => _drawStart = box.globalToLocal(d.globalPosition));
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (!_drawMode || _drawStart == null) return;
    final box =
        _imgKey.currentContext!.findRenderObject() as RenderBox;
    setState(() => _drawCurrent = box.globalToLocal(d.globalPosition));
  }

  void _onPanEnd(DragEndDetails _) {
    if (!_drawMode || _drawStart == null || _drawCurrent == null) return;
    final nb =
        _UserBox(start: _drawStart!, end: _drawCurrent!);
    setState(() {
      _userBoxes.add(nb);
      _drawStart = null;
      _drawCurrent = null;
    });
    _promptLabel(_userBoxes.length - 1);
  }

  void _promptLabel(int idx) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kCard,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('What is this?', style: kHead(16)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: kBody(14, color: kText),
          cursorColor: kPrimary,
          decoration: InputDecoration(
            hintText: 'e.g. tree, cat…',
            hintStyle: kBody(14),
            filled: true,
            fillColor: kSurface,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: kBorder)),
          ),
        ),
        actions: [
          VButton(
            label: 'Done',
            onTap: () {
              setState(() => _userBoxes[idx].label = ctrl.text.trim());
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        iconTheme: const IconThemeData(color: kText),
        title: Text('Explore image', style: kHead(17)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(children: [
            // Instruction
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: VCard(
                color: kPrimary.withOpacity(0.06),
                child: Text(
                  _drawMode
                      ? 'Draw a box around objects to label them.'
                      : 'Tap "AI Detect" or draw boxes yourself.',
                  style: kBody(13, color: kPrimary),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            // Image + overlays
            GestureDetector(
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              child: SizedBox(
                width: sw,
                height: sw * (_natH / _natW),
                child: Stack(children: [
                  Positioned.fill(
                    child: Image.network(
                      '$kBaseUrl${widget.imageUrl}',
                      key: _imgKey,
                      fit: BoxFit.contain,
                    ),
                  ),

                  // YOLO detections
                  if (_showYolo)
                    ..._yoloDets.asMap().entries.map((e) {
                      final d  = e.value;
                      final b  = d['box'] as Map;
                      final sx = sw / _natW;
                      final sy = (sw * (_natH / _natW)) / _natH;
                      return Positioned(
                        left:   (b['x'] as int) * sx,
                        top:    (b['y'] as int) * sy,
                        width:  (b['width'] as int) * sx,
                        height: (b['height'] as int) * sy,
                        child: GestureDetector(
                          onTap: () => _renameYoloDet(e.key),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: kAccent, width: 2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: Container(
                                color: kAccent,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 2),
                                child: Text(
                                  '${d['label']}  ${((d['confidence'] as double) * 100).round()}%',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),

                  // User boxes
                  ..._userBoxes.asMap().entries.map((e) {
                    final r = e.value.rect;
                    return Positioned(
                      left: r.left, top: r.top,
                      width: r.width, height: r.height,
                      child: GestureDetector(
                        onTap: () => _promptLabel(e.key),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: kPrimary, width: 2),
                            borderRadius: BorderRadius.circular(4),
                            color: kPrimary.withOpacity(0.07),
                          ),
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: Container(
                              color: kPrimary,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 2),
                              child: Text(
                                e.value.label.isEmpty
                                    ? 'Tap to label'
                                    : e.value.label,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),

                  // Live draw preview
                  if (_drawStart != null && _drawCurrent != null)
                    Positioned(
                      left: min(_drawStart!.dx, _drawCurrent!.dx),
                      top:  min(_drawStart!.dy, _drawCurrent!.dy),
                      width: (_drawStart!.dx - _drawCurrent!.dx).abs(),
                      height: (_drawStart!.dy - _drawCurrent!.dy).abs(),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: kPrimary.withOpacity(0.7), width: 1.5),
                          color: kPrimary.withOpacity(0.06),
                        ),
                      ),
                    ),
                ]),
              ),
            ),

            // Controls
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                if (_userBoxes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: VCard(
                      color: kGreen.withOpacity(0.07),
                      child: Row(children: [
                        const Icon(Icons.check_circle_outline_rounded,
                            color: kGreen, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          '${_userBoxes.length} object${_userBoxes.length == 1 ? '' : 's'} marked',
                          style: kBody(13, color: kGreen),
                        ),
                      ]),
                    ),
                  ),

                VButton(
                  label: _detectLoading
                      ? 'Detecting…'
                      : _showYolo
                          ? 'AI found ${_yoloDets.length} (tap to rename)'
                          : 'AI detect',
                  icon: Icons.image_search_rounded,
                  color: kAccent,
                  wide: true,
                  onTap: _detectLoading ? null : _runYolo,
                ),
                const SizedBox(height: 10),
                VButton(
                  label: _drawMode ? 'Stop drawing' : 'Draw boxes',
                  icon: _drawMode
                      ? Icons.stop_rounded
                      : Icons.draw_outlined,
                  color: _drawMode ? kRed : kPrimary,
                  outlined: !_drawMode,
                  wide: true,
                  onTap: () => setState(() => _drawMode = !_drawMode),
                ),
                if (_userBoxes.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  VButton(
                    label: 'Submit labels',
                    icon: Icons.upload_rounded,
                    color: kGreen,
                    wide: true,
                    onTap: _submitted ? null : _submitLabels,
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _userBoxes.clear()),
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: kRed, size: 16),
                    label: Text('Clear boxes',
                        style: kBody(13, color: kRed)),
                  ),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─── Profile Screen ───────────────────────────────────────────────────────────
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await Api.get('/api/profile');
      setState(() => _profile = res);
    } catch (_) {}
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _logout() async {
    await Api.clearToken();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (_) => false);
  }

  String _badge(int s) {
    if (s >= 1000) return 'Legend Explorer';
    if (s >= 500)  return 'Super Finder';
    if (s >= 200)  return 'Object Hunter';
    if (s >= 50)   return 'Curious Learner';
    return 'Story Seedling';
  }

  @override
  Widget build(BuildContext context) {
    final p       = _profile;
    final score   = p?['score'] as int? ?? 0;
    final objects = p?['total_objects'] as int? ?? 0;
    final stories =
        List<Map<String, dynamic>>.from(p?['stories'] ?? []);

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Row(children: [
                  Text('Profile', style: kHead(22)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded,
                        color: kMuted, size: 20),
                    onPressed: _load,
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined,
                        color: kMuted, size: 20),
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SettingsScreen())),
                  ),
                ]),
                const SizedBox(height: 24),

                if (_loading)
                  const Center(
                    child: CircularProgressIndicator(
                        color: kPrimary, strokeWidth: 2))
                else ...[
                  // User card
                  VCard(
                    child: Row(children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: kPrimary.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            (p?['name'] as String? ?? 'U')
                                .substring(0, 1)
                                .toUpperCase(),
                            style: GoogleFonts.dmSans(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: kPrimary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(p?['name'] ?? 'Explorer',
                            style: kHead(17)),
                        const SizedBox(height: 2),
                        Text(_badge(score), style: kBody(13)),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 16),

                  // Stats row
                  Row(children: [
                    Expanded(
                        child: _StatCard(
                            icon: Icons.star_outline_rounded,
                            label: 'Points',
                            value: '$score')),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _StatCard(
                            icon: Icons.search_rounded,
                            label: 'Objects',
                            value: '$objects')),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _StatCard(
                            icon: Icons.auto_stories_outlined,
                            label: 'Stories',
                            value: '${stories.length}')),
                  ]),
                  const SizedBox(height: 24),

                  Text('My stories', style: kHead(17)),
                  const SizedBox(height: 12),

                  if (stories.isEmpty)
                    VCard(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text('No stories yet.',
                              style: kBody(14)),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: stories.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                      itemBuilder: (ctx, i) {
                        final s     = stories[i];
                        final imgs  = List<String>.from(s['images'] ?? []);
                        final parts = List<Map<String, dynamic>>.from(
                            s['parts'] ?? []);
                        final preview =
                            s['refined_story'] as String? ?? '';
                        return GestureDetector(
                          onTap: () {
                            if (imgs.isEmpty) return;
                            Navigator.push(
                              ctx,
                              MaterialPageRoute(
                                builder: (_) => StoryPlayScreen(
                                  storyId:  s['_id'],
                                  images:   imgs,
                                  parts:    parts,
                                  audioUrl: s['audio_url'] ?? '',
                                ),
                              ),
                            );
                          },
                          child: VCard(
                            child: Row(children: [
                              if (imgs.isNotEmpty)
                                ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(8),
                                  child: Image.network(
                                    '$kBaseUrl${imgs[0]}',
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      preview.length > 80
                                          ? '${preview.substring(0, 80)}…'
                                          : preview,
                                      style: kBody(13, color: kText),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(children: [
                                      const Icon(
                                          Icons.play_circle_outline_rounded,
                                          color: kPrimary, size: 14),
                                      const SizedBox(width: 4),
                                      Text('Play again',
                                          style: kBody(12,
                                              color: kPrimary,
                                              fw: FontWeight.w500)),
                                    ]),
                                  ],
                                ),
                              ),
                            ]),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 40),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _StatCard(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => VCard(
        child: Column(children: [
          Icon(icon, color: kPrimary, size: 20),
          const SizedBox(height: 6),
          Text(value, style: kHead(18)),
          const SizedBox(height: 2),
          Text(label, style: kBody(11)),
        ]),
      );
}

// ─── Settings Screen ──────────────────────────────────────────────────────────
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: kBg,
        appBar: AppBar(
          backgroundColor: kBg,
          elevation: 0,
          iconTheme: const IconThemeData(color: kText),
          title: Text('Settings', style: kHead(17)),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Account', style: kBody(12)),
                const SizedBox(height: 12),
                VButton(
                  label: 'Sign out',
                  icon: Icons.logout_rounded,
                  color: kRed,
                  outlined: true,
                  wide: true,
                  onTap: () async {
                    await Api.clearToken();
                    if (context.mounted)
                      Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AuthScreen()),
                          (_) => false);
                  },
                ),
              ],
            ),
          ),
        ),
      );
}
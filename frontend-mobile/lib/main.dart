import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/network/auth_repository.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_toggle_button.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/session_destination.dart';

void main() {
  runApp(const CampusSaveApp());
}

class CampusSaveApp extends StatefulWidget {
  const CampusSaveApp({super.key, this.authRepository});

  final AuthRepository? authRepository;

  @override
  State<CampusSaveApp> createState() => _CampusSaveAppState();
}

class _CampusSaveAppState extends State<CampusSaveApp> {
  static const _darkModeKey = 'campussave_dark_mode';

  late final _repository = widget.authRepository ?? AuthRepository();
  late final _session = _restoreSession();
  late final _preferences = _loadPreferences();
  ThemeMode _mode = ThemeMode.light;
  Future<void> _pendingWrite = Future<void>.value();
  bool _themeLoaded = false;

  @override
  void initState() {
    super.initState();
    _restoreTheme();
  }

  Future<SharedPreferences?> _loadPreferences() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  Future<void> _restoreTheme() async {
    final preferences = await _preferences;
    if (!mounted) return;
    setState(() {
      _mode = preferences?.get(_darkModeKey) == true
          ? ThemeMode.dark
          : ThemeMode.light;
      _themeLoaded = true;
    });
  }

  void _toggleTheme() {
    final isDark = _mode != ThemeMode.dark;
    setState(() {
      _mode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
    _pendingWrite = _pendingWrite.then((_) async {
      final preferences = await _preferences;
      try {
        await preferences?.setBool(_darkModeKey, isDark);
      } catch (_) {
        // A storage failure does not interrupt navigation or change the session.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ThemeSelection(
      mode: _mode,
      onToggle: _toggleTheme,
      child: MaterialApp(
        title: 'CampusSave',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: _mode,
        home: FutureBuilder<AuthSession?>(
          future: _session,
          builder: (context, snapshot) {
            if (!_themeLoaded ||
                snapshot.connectionState != ConnectionState.done) {
              return const SizedBox.shrink();
            }
            final session = snapshot.data;
            if (session != null) {
              return sessionDestination(_repository, session);
            }
            return LoginScreen(authRepository: _repository);
          },
        ),
      ),
    );
  }

  Future<AuthSession?> _restoreSession() async {
    try {
      return await _repository.restoreValidatedSession();
    } on AuthException {
      return null;
    }
  }
}

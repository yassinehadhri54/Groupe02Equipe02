import 'package:material_ui/material_ui.dart';

import 'core/theme/app_theme.dart';
import 'core/network/auth_repository.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/session_destination.dart';

void main() {
  runApp(const CampusSaveApp());
}

class CampusSaveApp extends StatelessWidget {
  const CampusSaveApp({super.key, this.authRepository});

  final AuthRepository? authRepository;

  @override
  Widget build(BuildContext context) {
    final repository = authRepository ?? AuthRepository();
    return MaterialApp(
      title: 'CampusSave',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: FutureBuilder<AuthSession?>(
        future: _restoreSession(repository),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox.shrink();
          }
          if (snapshot.hasData && snapshot.data != null) {
            return sessionDestination(repository, snapshot.data!);
          }
          return LoginScreen(authRepository: repository);
        },
      ),
    );
  }

  Future<AuthSession?> _restoreSession(AuthRepository repository) async {
    try {
      return await repository.restoreValidatedSession();
    } on AuthException {
      return null;
    }
  }
}

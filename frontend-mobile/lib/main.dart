import 'package:material_ui/material_ui.dart';

import 'core/theme/app_theme.dart';
import 'core/network/auth_repository.dart';
import 'features/auth/screens/login_screen.dart';
import 'core/widgets/main_navigation.dart';
import 'features/auth/screens/account_status_screen.dart';
import 'features/merchant/screens/merchant_dashboard_screen.dart';

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
            return _roleDestination(context, repository, snapshot.data!);
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

  Widget _roleDestination(
    BuildContext context,
    AuthRepository repository,
    AuthSession session,
  ) {
    final user = session.user;
    if (user.role == 'student' && user.status == 'active') {
      return MainNavigation(authRepository: repository);
    }
    if (user.role == 'merchant' && user.status == 'active') {
      return MerchantDashboardScreen();
    }
    if (user.role == 'merchant' && user.status == 'pending') {
      return AccountStatusScreen(
        title: 'Compte en attente',
        message:
            'Votre compte commerçant est en attente de validation par un administrateur.',
        pending: true,
        authRepository: repository,
      );
    }
    return AccountStatusScreen(
      title: 'Accès refusé',
      message:
          'Votre compte est désactivé ou votre rôle n’est pas autorisé.',
      authRepository: repository,
    );
  }
}

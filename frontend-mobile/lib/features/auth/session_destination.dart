import 'package:material_ui/material_ui.dart';

import '../../core/network/auth_repository.dart';
import '../../core/widgets/main_navigation.dart';
import '../admin/screens/admin_dashboard_screen.dart';
import '../merchant/screens/merchant_dashboard_screen.dart';
import 'screens/account_status_screen.dart';

Widget sessionDestination(AuthRepository repository, AuthSession session) {
  final user = session.user;
  return switch ((user.role, user.status)) {
    ('student', 'active') => MainNavigation(authRepository: repository),
    ('merchant', 'active' || 'pending') => MerchantDashboardScreen(
      authRepository: repository,
    ),
    ('admin', 'active') => AdminDashboardScreen(
      authRepository: repository,
      administrator: user,
    ),
    _ => AccountStatusScreen(
      title: 'Accès refusé',
      message: 'Votre compte est désactivé ou votre rôle n’est pas autorisé.',
      authRepository: repository,
    ),
  };
}

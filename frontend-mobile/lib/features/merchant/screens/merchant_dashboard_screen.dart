import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/preparation_screen.dart';

class MerchantDashboardScreen extends StatelessWidget {
  const MerchantDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PreparationScreen(
      key: ValueKey('merchant-dashboard-screen'),
      title: 'Espace commerçant',
    );
  }
}

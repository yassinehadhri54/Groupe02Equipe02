import 'package:material_ui/material_ui.dart';

import '../data/demo_merchant_repository.dart';
import '../../../core/widgets/preparation_screen.dart';

class MerchantOffersScreen extends StatelessWidget {
  const MerchantOffersScreen({super.key, this.repository});

  final MerchantRepository? repository;

  @override
  Widget build(BuildContext context) {
    return const PreparationScreen(
      key: ValueKey('merchant-offers-screen'),
      title: 'Offres commerçant',
    );
  }
}

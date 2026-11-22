import 'package:material_ui/material_ui.dart';

import '../data/demo_merchant_repository.dart';
import '../../../core/widgets/preparation_screen.dart';

class CreateOfferScreen extends StatelessWidget {
  const CreateOfferScreen({super.key, this.repository});

  final MerchantRepository? repository;

  @override
  Widget build(BuildContext context) {
    return const PreparationScreen(
      key: ValueKey('create-offer-screen'),
      title: 'Créer une offre',
    );
  }
}

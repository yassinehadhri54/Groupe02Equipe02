import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/preparation_screen.dart';

class CreateOfferScreen extends StatelessWidget {
  const CreateOfferScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PreparationScreen(
      key: ValueKey('create-offer-screen'),
      title: 'Créer une offre',
    );
  }
}

import 'package:material_ui/material_ui.dart';

import '../../../core/network/auth_repository.dart';
import '../../search/models/shop_offer.dart';
import '../data/merchant_api_repository.dart';
import 'create_offer_screen.dart';

class MerchantOffersScreen extends StatefulWidget {
  const MerchantOffersScreen({
    super.key,
    required this.repository,
    this.onChanged,
  });

  final MerchantApiRepository repository;
  final VoidCallback? onChanged;

  @override
  State<MerchantOffersScreen> createState() => _MerchantOffersScreenState();
}

class _MerchantOffersScreenState extends State<MerchantOffersScreen> {
  late Future<List<ShopOffer>> _offers = widget.repository.getOffers();

  void _reload() {
    setState(() {
      _offers = widget.repository.getOffers();
    });
  }

  Future<void> _openForm([ShopOffer? offer]) async {
    final updated = await Navigator.of(context).push<ShopOffer>(
      MaterialPageRoute(
        builder: (_) =>
            CreateOfferScreen(repository: widget.repository, offer: offer),
      ),
    );
    if (!mounted || updated == null) return;
    widget.onChanged?.call();
    _reload();
  }

  Widget _offerCard(ShopOffer offer) {
    final status = switch (offer) {
      ShopOffer(status: 'deleted') => 'Supprimée',
      ShopOffer(pickupExpired: true) => 'Expirée',
      ShopOffer(stockDepleted: true) => 'Épuisée',
      ShopOffer(status: 'available' || 'active') => 'Disponible',
      _ => offer.status ?? 'Statut indisponible',
    };
    final details = [
      if (offer.adminDisabled) 'Désactivée par l’administration' else status,
      if (offer.availableQuantity case final quantity?) '$quantity en stock',
      if (offer.discountPrice case final price?)
        '${price.toStringAsFixed(3)} DT',
    ];
    return Card(
      child: ListTile(
        title: Text(offer.name),
        subtitle: Text(details.join(' · ')),
        trailing: IconButton(
          key: ValueKey('merchant-edit-${offer.id}'),
          tooltip: 'Modifier ${offer.name}',
          onPressed: () => _openForm(offer),
          icon: const Icon(Icons.edit_outlined),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('merchant-offers-screen'),
      appBar: AppBar(
        title: const Text('Offres commerçant'),
        actions: [
          IconButton(
            onPressed: _reload,
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<List<ShopOffer>>(
          future: _offers,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              final error = snapshot.error;
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        error is AuthException
                            ? error.message
                            : 'Impossible de charger les offres.',
                      ),
                      TextButton(
                        onPressed: _reload,
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                ),
              );
            }
            final offers = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                FilledButton.icon(
                  onPressed: _openForm,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Ajouter une offre'),
                ),
                const SizedBox(height: 16),
                if (offers.isEmpty)
                  const Center(child: Text('Aucune offre publiée.')),
                for (final offer in offers)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _offerCard(offer),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

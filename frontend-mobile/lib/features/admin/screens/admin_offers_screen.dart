import 'package:material_ui/material_ui.dart';

import '../../search/models/shop_offer.dart';
import '../data/admin_api_repository.dart';
import '../models/admin_data.dart';
import '../widgets/admin_panel.dart';

class AdminOffersScreen extends StatefulWidget {
  const AdminOffersScreen({
    super.key,
    required this.repository,
    required this.onChanged,
    required this.onSignOut,
  });

  final AdminApiRepository repository;
  final VoidCallback onChanged;
  final VoidCallback onSignOut;

  @override
  State<AdminOffersScreen> createState() => _AdminOffersScreenState();
}

class _AdminOffersScreenState extends State<AdminOffersScreen> {
  final _query = TextEditingController();
  final _category = TextEditingController();
  String _moderation = '';
  late Future<List<ShopOffer>> _offers = widget.repository.loadOffers();

  @override
  void dispose() {
    _query.dispose();
    _category.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _offers = widget.repository.loadOffers(
        query: _query.text,
        category: _category.text,
        adminDisabled: _moderation.isEmpty ? null : _moderation == 'disabled',
      );
    });
  }

  Future<void> _open(ShopOffer offer) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _AdminOfferDetailsScreen(
          repository: widget.repository,
          summary: offer,
          onSignOut: widget.onSignOut,
        ),
      ),
    );
    if (!mounted || changed != true) return;
    widget.onChanged();
    _reload();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('La modération de l’offre a été mise à jour.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('admin-offer-search'),
                    controller: _query,
                    maxLength: 100,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _reload(),
                    decoration: const InputDecoration(
                      labelText: 'Rechercher une offre',
                      counterText: '',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Rechercher et actualiser les offres',
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    _reload();
                  },
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _category,
                    maxLength: 100,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _reload(),
                    decoration: const InputDecoration(
                      labelText: 'Catégorie',
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AdminFilter(
                    label: 'Modération',
                    value: _moderation,
                    choices: const ['disabled', 'enabled'],
                    labelFor: (value) =>
                        value == 'disabled' ? 'Désactivées' : 'Sans blocage',
                    onChanged: (value) {
                      _moderation = value;
                      _reload();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      Expanded(
        child: AdminDataView<List<ShopOffer>>(
          future: _offers,
          onReload: _reload,
          onSignOut: widget.onSignOut,
          builder: (offers) => AdminItems(
            items: offers,
            emptyMessage: 'Aucune offre pour cette recherche.',
            itemBuilder: (offer) => ListTile(
              title: Text(offer.name),
              subtitle: Text(
                [
                  ?offer.shopName,
                  _lifecycleLabel(offer),
                  if (offer.adminDisabled) 'Désactivée par l’administration',
                ].join(' · '),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(offer),
            ),
          ),
        ),
      ),
    ],
  );
}

String _lifecycleLabel(ShopOffer offer) {
  if (offer.status == 'deleted') return 'Supprimée';
  if (offer.pickupExpired) return 'Expirée';
  if (offer.stockDepleted) return 'Épuisée';
  return switch (offer.status) {
    'available' || 'active' => 'Active',
    final status? => status,
    _ => 'Statut indisponible',
  };
}

class _AdminOfferDetailsScreen extends StatefulWidget {
  const _AdminOfferDetailsScreen({
    required this.repository,
    required this.summary,
    required this.onSignOut,
  });

  final AdminApiRepository repository;
  final ShopOffer summary;
  final VoidCallback onSignOut;

  @override
  State<_AdminOfferDetailsScreen> createState() =>
      _AdminOfferDetailsScreenState();
}

class _AdminOfferDetailsScreenState extends State<_AdminOfferDetailsScreen> {
  final _reason = TextEditingController();
  late Future<AdminOfferDetail> _offer = widget.repository.loadOffer(
    widget.summary.id,
  );

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _offer = widget.repository.loadOffer(widget.summary.id);
    });
  }

  String? _price(double? price) {
    final formatted = price?.toStringAsFixed(3);
    return formatted == null ? null : '$formatted DT';
  }

  Widget _details(AdminOfferDetail detail) {
    final (offer: offer, shop: shop) = detail;
    final disable = !offer.adminDisabled;
    final label = disable ? 'Désactiver' : 'Réactiver';
    return AdminDetails(
      fields: {
        'Statut': _lifecycleLabel(offer),
        'Modération': disable
            ? 'Sans blocage administratif'
            : 'Désactivée par l’administration',
        'Offre': offer.name,
        'Description': offer.description,
        'Catégorie': offer.category,
        'Prix initial': _price(offer.originalPrice),
        'Prix réduit': _price(offer.discountPrice),
        'Stock disponible': offer.availableQuantity?.toString(),
        'Début du retrait': offer.pickupStart,
        'Fin du retrait': offer.pickupEnd,
        'Commerce': shop?.name ?? offer.shopName ?? 'Commerce indisponible',
        'Identifiant du commerce': shop?.id ?? offer.shopId,
        'Statut du commerce': shop == null
            ? null
            : adminStatusLabel(shop.status),
        'Adresse du commerce': shop?.address,
        'Téléphone du commerce': shop?.phone,
        'E-mail du commerce': shop?.email,
      },
      actions: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('admin-offer-reason'),
            controller: _reason,
            maxLength: 500,
            decoration: const InputDecoration(labelText: 'Motif (facultatif)'),
          ),
          AdminDecisionButtons(
            actions: [
              (
                label: label,
                question: '$label cette offre ?',
                note: disable
                    ? 'Les nouvelles réservations seront bloquées. Les réservations existantes sont conservées.'
                    : 'Le blocage administratif sera levé. Le stock, le créneau et le statut du commerce continuent de s’appliquer.',
                submit: () => widget.repository.moderateOffer(
                  offer.id,
                  adminDisabled: disable,
                  reason: _reason.text,
                ),
              ),
            ],
            onSuccess: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.summary.name)),
    body: SafeArea(
      child: AdminDataView<AdminOfferDetail>(
        future: _offer,
        onReload: _reload,
        onSignOut: widget.onSignOut,
        builder: _details,
      ),
    ),
  );
}

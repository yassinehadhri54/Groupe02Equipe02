import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../bookings/data/reservation_repository.dart';
import '../../bookings/screens/booking_summary_screen.dart';
import '../../search/data/shop_repository.dart';
import '../../search/models/shop_offer.dart';
import '../widgets/offer_photo.dart';

class OfferDetailScreen extends StatefulWidget {
  const OfferDetailScreen({
    required this.offer,
    required this.repository,
    super.key,
  });

  final ShopOffer offer;
  final ShopRepository repository;

  @override
  State<OfferDetailScreen> createState() => _OfferDetailScreenState();
}

class _OfferDetailScreenState extends State<OfferDetailScreen> {
  ShopOffer? _offer;
  bool _isLoading = true;
  bool _notFound = false;
  String? _errorMessage;
  int _quantity = 1;

  double get _total => (_offer?.discountPrice ?? 0) * _quantity;

  bool get _canContinue {
    final offer = _offer;
    return offer != null &&
        !offer.isUnavailable &&
        offer.discountPrice != null &&
        offer.originalPrice != null &&
        offer.availableQuantity != 0;
  }

  @override
  void initState() {
    super.initState();
    _loadOffer();
  }

  Future<void> _loadOffer() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _notFound = false;
    });

    try {
      final offer = await widget.repository.fetchOfferById(widget.offer.id);
      if (!mounted) return;
      setState(() {
        _offer = offer;
        _quantity = 1;
      });
    } on ShopRepositoryException catch (error) {
      if (!mounted) return;
      setState(() {
        _notFound = error.statusCode == 404;
        _errorMessage = error.message;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final offer = _offer;
    if (_isLoading) {
      return _buildStatusPage(
        body: const CircularProgressIndicator(color: AppTheme.burgundy),
      );
    }

    if (_errorMessage != null || offer == null) {
      return _buildStatusPage(
        body: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _notFound
                  ? 'Cette offre n’est plus disponible.'
                  : _errorMessage ?? 'Impossible de charger cette offre.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextButton(
              key: const ValueKey('offer-detail-retry'),
              onPressed: _loadOffer,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    return ScaffoldMessenger(
      child: Builder(
        builder: (screenContext) => Scaffold(
          key: const ValueKey('offer-detail-screen'),
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                automaticallyImplyLeading: false,
                expandedHeight: 290,
                collapsedHeight: kToolbarHeight,
                leadingWidth: 64,
                leading: Padding(
                  padding: const EdgeInsets.all(8),
                  child: IconButton.filledTonal(
                    key: const ValueKey('offer-detail-back'),
                    tooltip: 'Retour',
                    onPressed: () => Navigator.of(context).maybePop(),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.burgundy,
                    ),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: offer.imageUrl == null
                      ? const ColoredBox(
                          color: AppTheme.cream,
                          child: Center(
                            child: Icon(
                              Icons.restaurant_outlined,
                              size: 56,
                              color: AppTheme.burgundy,
                            ),
                          ),
                        )
                      : OfferPhoto(imageUrl: offer.imageUrl!, iconSize: 56),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (offer.category != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.gold.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            offer.category!.toUpperCase(),
                            style: const TextStyle(
                              color: AppTheme.burgundy,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Text(
                        offer.name,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: AppTheme.ink,
                              fontWeight: FontWeight.w800,
                            ),
                      ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.06),
                      if (offer.shopName != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.storefront_outlined,
                              size: 20,
                              color: AppTheme.gold,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                offer.shopName!,
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(
                                      color: AppTheme.ink.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (offer.description != null) ...[
                        const SizedBox(height: 22),
                        Text(
                          'À propos de cette offre',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: AppTheme.burgundy,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          offer.description!,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: AppTheme.ink.withValues(alpha: 0.75),
                                height: 1.5,
                              ),
                        ),
                      ],
                      if (offer.availableQuantity != null) ...[
                        const SizedBox(height: 18),
                        Text(
                          '${offer.availableQuantity} disponible(s)',
                          key: const ValueKey('offer-available-quantity'),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                      if (offer.pickupStart != null ||
                          offer.pickupEnd != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Retrait : ${offer.pickupStart ?? '—'} – ${offer.pickupEnd ?? '—'}',
                          key: const ValueKey('offer-pickup-window'),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppTheme.ink.withValues(alpha: 0.7),
                              ),
                        ),
                      ],
                      if (offer.isUnavailable) ...[
                        const SizedBox(height: 20),
                        const Text(
                          'Cette offre n’est plus disponible.',
                          key: ValueKey('offer-unavailable'),
                          style: TextStyle(
                            color: AppTheme.burgundy,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      if (offer.discountPrice != null) ...[
                        const SizedBox(height: 22),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatPrice(offer.discountPrice!),
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    color: AppTheme.burgundy,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            if (offer.originalPrice != null) ...[
                              const SizedBox(width: 12),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 3),
                                child: Text(
                                  _formatPrice(offer.originalPrice!),
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(
                                        color: AppTheme.ink.withValues(
                                          alpha: 0.55,
                                        ),
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                      if (_canContinue) ...[
                        const SizedBox(height: 24),
                        Text(
                          'Quantité',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        _buildQuantitySelector(context, offer),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: _buildReservationBar(screenContext, offer),
        ),
      ),
    );
  }

  Widget _buildStatusPage({required Widget body}) {
    return Scaffold(
      key: const ValueKey('offer-detail-screen'),
      backgroundColor: const Color(0xFFFFF7F0),
      appBar: AppBar(
        title: const Text('Détail de l’offre'),
        backgroundColor: AppTheme.burgundy,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(padding: const EdgeInsets.all(24), child: body),
      ),
    );
  }

  Widget _buildQuantitySelector(BuildContext context, ShopOffer offer) {
    final maxQuantity = offer.availableQuantity;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEAE2D9)),
      ),
      child: Row(
        children: [
          const Expanded(child: Text('Nombre de portions')),
          IconButton(
            key: const ValueKey('decrease-quantity'),
            tooltip: 'Diminuer la quantité',
            onPressed: _quantity > 1
                ? () => setState(() => _quantity -= 1)
                : null,
            icon: const Icon(Icons.remove_rounded),
          ),
          Text(
            '$_quantity',
            key: const ValueKey('offer-quantity-value'),
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          IconButton(
            key: const ValueKey('increase-quantity'),
            tooltip: 'Augmenter la quantité',
            onPressed: maxQuantity == null || _quantity < maxQuantity
                ? () => setState(() => _quantity += 1)
                : null,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildReservationBar(BuildContext context, ShopOffer offer) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 16,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Total ($_quantity portion${_quantity == 1 ? '' : 's'})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _offer?.discountPrice == null ? '—' : _formatPrice(_total),
                    key: const ValueKey('offer-total-value'),
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.burgundy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('reserve-offer-button'),
                onPressed: _canContinue
                    ? () {
                        Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => BookingSummaryScreen(
                              offer: offer,
                              quantity: _quantity,
                              repository: ReservationRepository(
                                authRepository:
                                    widget.repository.authRepository,
                              ),
                            ),
                          ),
                        );
                      }
                    : null,
                child: Text(
                  offer.isUnavailable
                      ? 'Indisponible'
                      : _canContinue
                      ? 'Réserver'
                      : 'Prix indisponible',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPrice(double amount) => '${amount.toStringAsFixed(3)} DT';
}

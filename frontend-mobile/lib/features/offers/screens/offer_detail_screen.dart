import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../bookings/screens/booking_summary_screen.dart';
import '../models/food_offer.dart';
import '../widgets/offer_photo.dart';

class OfferDetailScreen extends StatefulWidget {
  const OfferDetailScreen({required this.offer, super.key});

  final FoodOffer offer;

  @override
  State<OfferDetailScreen> createState() => _OfferDetailScreenState();
}

class _OfferDetailScreenState extends State<OfferDetailScreen> {
  int _quantity = 1;

  double get _total => widget.offer.price * _quantity;

  int get _discount => widget.offer.oldPrice > 0
      ? ((widget.offer.oldPrice - widget.offer.price) /
                widget.offer.oldPrice *
                100)
            .round()
      : 0;

  @override
  Widget build(BuildContext context) {
    final imageHeight = (MediaQuery.sizeOf(context).height * 0.34)
        .clamp(240.0, 360.0)
        .toDouble();

    return ScaffoldMessenger(
      child: Builder(
        builder: (screenContext) => Scaffold(
          key: const ValueKey('offer-detail-screen'),
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                automaticallyImplyLeading: false,
                expandedHeight: imageHeight,
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
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      OfferPhoto(imageUrl: widget.offer.imageUrl, iconSize: 56),
                      Positioned(
                        right: 20,
                        bottom: 20,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.burgundy,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Text(
                            '-$_discount%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                          widget.offer.category.toUpperCase(),
                          style: const TextStyle(
                            color: AppTheme.burgundy,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.offer.name,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: AppTheme.ink,
                              fontWeight: FontWeight.w800,
                            ),
                      ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.06),
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
                              widget.offer.shop,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: AppTheme.ink.withValues(alpha: 0.7),
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'À propos de cette offre',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTheme.burgundy,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.offer.description,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.ink.withValues(alpha: 0.75),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatPrice(widget.offer.price),
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: AppTheme.burgundy,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(width: 12),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Text(
                              _formatPrice(widget.offer.oldPrice),
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: AppTheme.ink.withValues(alpha: 0.55),
                                    decoration: TextDecoration.lineThrough,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Quantité',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      _buildQuantitySelector(context),
                    ],
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: _buildReservationBar(screenContext),
        ),
      ),
    );
  }

  Widget _buildQuantitySelector(BuildContext context) {
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
            onPressed: () => setState(() => _quantity += 1),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildReservationBar(BuildContext context) {
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total ($_quantity portion${_quantity == 1 ? '' : 's'})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  _formatPrice(_total),
                  key: const ValueKey('offer-total-value'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.burgundy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('reserve-offer-button'),
                onPressed: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (context) => BookingSummaryScreen(
                        offer: widget.offer,
                        quantity: _quantity,
                      ),
                    ),
                  );
                },
                child: const Text('Réserver'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPrice(double amount) => '${amount.toStringAsFixed(3)} DT';
}

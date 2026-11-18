import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../offers/models/food_offer.dart';
import '../../offers/widgets/offer_photo.dart';

class BookingSummaryScreen extends StatelessWidget {
  const BookingSummaryScreen({
    required this.offer,
    required this.quantity,
    super.key,
  }) : assert(quantity >= 1);

  final FoodOffer offer;
  final int quantity;

  double get _unitPrice => offer.price;
  double get _initialTotal => offer.oldPrice * quantity;
  double get _finalTotal => _unitPrice * quantity;
  double get _discountTotal {
    final discount = _initialTotal - _finalTotal;
    return discount > 0 ? discount : 0;
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      child: Builder(
        builder: (screenContext) => Scaffold(
          key: const ValueKey('booking-summary-screen'),
          appBar: AppBar(
            leading: IconButton(
              key: const ValueKey('booking-summary-back'),
              tooltip: 'Retour',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            title: const Text('Récapitulatif'),
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final contentWidth = constraints.maxWidth > 640
                  ? 600.0
                  : constraints.maxWidth;

              return Center(
                child: SizedBox(
                  width: contentWidth,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Card(
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AspectRatio(
                                aspectRatio: 16 / 9,
                                child: OfferPhoto(
                                  imageUrl: offer.imageUrl,
                                  iconSize: 52,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      offer.category.toUpperCase(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            color: AppTheme.gold,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.8,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      offer.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            color: AppTheme.ink,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 5),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.storefront_outlined,
                                          size: 18,
                                          color: AppTheme.gold,
                                        ),
                                        const SizedBox(width: 7),
                                        Expanded(
                                          child: Text(
                                            offer.shop,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  color: AppTheme.ink
                                                      .withValues(alpha: 0.7),
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Détail du montant',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: AppTheme.burgundy,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              children: [
                                _SummaryRow(
                                  label: 'Quantité',
                                  value:
                                      '$quantity portion${quantity == 1 ? '' : 's'}',
                                  valueKey: const ValueKey(
                                    'booking-quantity-value',
                                  ),
                                ),
                                const Divider(height: 24),
                                _SummaryRow(
                                  label: 'Prix unitaire',
                                  value: _formatPrice(_unitPrice),
                                  valueKey: const ValueKey(
                                    'booking-unit-price',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _SummaryRow(
                                  label: 'Prix initial',
                                  value: _formatPrice(_initialTotal),
                                  valueKey: const ValueKey(
                                    'booking-initial-total',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _SummaryRow(
                                  label: 'Réduction totale',
                                  value: '−${_formatPrice(_discountTotal)}',
                                  valueKey: const ValueKey(
                                    'booking-discount-total',
                                  ),
                                  valueColor: AppTheme.gold,
                                ),
                                const Divider(height: 28),
                                _SummaryRow(
                                  label: 'Montant final',
                                  value: _formatPrice(_finalTotal),
                                  valueKey: const ValueKey(
                                    'booking-final-total',
                                  ),
                                  emphasized: true,
                                  valueColor: AppTheme.burgundy,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('confirm-booking-button'),
                  onPressed: () {
                    ScaffoldMessenger.of(screenContext)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Mode démonstration : la réservation n'a pas été enregistrée.",
                          ),
                          duration: Duration(seconds: 3),
                        ),
                      );
                  },
                  child: const Text('Confirmer la réservation'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatPrice(double amount) => '${amount.toStringAsFixed(3)} DT';
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.valueKey,
    this.emphasized = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final Key valueKey;
  final bool emphasized;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final style = emphasized
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyLarge;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: style?.copyWith(
              color: emphasized
                  ? AppTheme.ink
                  : AppTheme.ink.withValues(alpha: 0.7),
              fontWeight: emphasized ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          key: valueKey,
          style: style?.copyWith(
            color: valueColor ?? AppTheme.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

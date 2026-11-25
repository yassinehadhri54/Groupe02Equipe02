import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../offers/widgets/offer_photo.dart';
import '../../search/models/shop_offer.dart';
import '../data/reservation_repository.dart';
import '../models/booking.dart';

class BookingSummaryScreen extends StatefulWidget {
  const BookingSummaryScreen({
    required this.offer,
    required this.quantity,
    required this.repository,
    super.key,
  }) : assert(quantity >= 1);

  final ShopOffer offer;
  final int quantity;
  final ReservationRepository repository;

  @override
  State<BookingSummaryScreen> createState() => _BookingSummaryScreenState();
}

class _BookingSummaryScreenState extends State<BookingSummaryScreen> {
  bool _isSubmitting = false;
  String? _errorMessage;
  Booking? _reservation;

  double get _unitPrice => widget.offer.discountPrice ?? 0;
  double get _estimatedTotal => _unitPrice * widget.quantity;

  Future<void> _createReservation() async {
    if (_isSubmitting || _reservation != null) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final reservation = await widget.repository.createReservation(
        offerId: widget.offer.id,
        quantity: widget.quantity,
      );
      if (mounted) setState(() => _reservation = reservation);
    } on ReservationException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = _localizedMessage(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _localizedMessage(ReservationException error) {
    if (error.statusCode == 400 &&
        error.message.toLowerCase().contains('quantity')) {
      return 'Le stock disponible est insuffisant pour cette quantité.';
    }
    if (error.statusCode == 404) {
      return 'Cette offre n’est plus disponible.';
    }
    return error.message;
  }

  @override
  Widget build(BuildContext context) {
    final reservation = _reservation;
    return Scaffold(
      key: const ValueKey('booking-summary-screen'),
      appBar: AppBar(
        leading: IconButton(
          key: const ValueKey('booking-summary-back'),
          tooltip: 'Retour',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(
          reservation == null ? 'Récapitulatif' : 'Réservation créée',
        ),
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
                child: reservation == null
                    ? _buildConfirmation(context)
                    : _buildCreatedReservation(context, reservation),
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
              key: ValueKey(
                reservation == null
                    ? 'confirm-booking-button'
                    : 'booking-summary-done',
              ),
              onPressed: reservation != null
                  ? () => Navigator.of(context).maybePop()
                  : (_isSubmitting ? null : _createReservation),
              child: reservation != null
                  ? const Text('Terminé')
                  : _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Confirmer la réservation'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmation(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildOfferCard(context),
        const SizedBox(height: 20),
        Text(
          'Détail du montant estimé',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: context.colors.primary,
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
                      '${widget.quantity} portion${widget.quantity == 1 ? '' : 's'}',
                  valueKey: const ValueKey('booking-quantity-value'),
                ),
                const Divider(height: 24),
                _SummaryRow(
                  label: 'Prix unitaire',
                  value: _formatPrice(_unitPrice),
                  valueKey: const ValueKey('booking-unit-price'),
                ),
                const Divider(height: 24),
                _SummaryRow(
                  label: 'Total estimé',
                  value: _formatPrice(_estimatedTotal),
                  valueKey: const ValueKey('booking-estimated-total'),
                  emphasized: true,
                ),
              ],
            ),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            key: const ValueKey('reservation-create-error'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.colors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCreatedReservation(BuildContext context, Booking reservation) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.check_circle_rounded,
          key: const ValueKey('reservation-created-icon'),
          color: context.adaptiveColor(
            const Color(0xFF14752A),
            const Color(0xFF9AD98E),
          ),
          size: 64,
        ),
        const SizedBox(height: 12),
        Text(
          'Réservation enregistrée',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: context.colors.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                _SummaryRow(
                  label: 'Référence',
                  value: reservation.id,
                  valueKey: const ValueKey('created-reservation-id'),
                ),
                const Divider(height: 24),
                _SummaryRow(
                  label: 'Statut',
                  value: reservation.statusLabel,
                  valueKey: const ValueKey('created-reservation-status'),
                ),
                if (reservation.paymentStatusLabel case final payment?) ...[
                  const SizedBox(height: 12),
                  _SummaryRow(
                    label: 'Paiement',
                    value: payment,
                    valueKey: const ValueKey('created-payment-status'),
                  ),
                ],
                const Divider(height: 24),
                _SummaryRow(
                  label: 'Quantité',
                  value:
                      '${reservation.quantity} portion${reservation.quantity == 1 ? '' : 's'}',
                ),
                const Divider(height: 24),
                _SummaryRow(
                  label: 'Total confirmé par le serveur',
                  value: _formatPrice(reservation.totalPrice),
                  valueKey: const ValueKey('created-reservation-total'),
                  emphasized: true,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOfferCard(BuildContext context) {
    final offer = widget.offer;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: offer.imageUrl == null
                ? ColoredBox(
                    color: context.colors.surface,
                    child: Center(
                      child: Icon(
                        Icons.restaurant_rounded,
                        color: context.colors.primary,
                        size: 52,
                      ),
                    ),
                  )
                : OfferPhoto(imageUrl: offer.imageUrl!),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (offer.category != null) ...[
                  Text(
                    offer.category!.toUpperCase(),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppTheme.gold,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                Text(
                  offer.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: context.colors.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (offer.shopName != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    offer.shopName!,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: context.colors.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(double amount) => '${amount.toStringAsFixed(3)} DT';
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueKey,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final Key? valueKey;
  final bool emphasized;

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
                  ? context.colors.onSurface
                  : context.colors.onSurfaceVariant,
              fontWeight: emphasized ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          key: valueKey,
          textAlign: TextAlign.end,
          style: style?.copyWith(
            color: emphasized
                ? context.colors.primary
                : context.colors.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

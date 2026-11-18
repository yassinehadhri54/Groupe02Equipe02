import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../models/booking.dart';
import '../../offers/widgets/offer_photo.dart';

class BookingDetailScreen extends StatelessWidget {
  const BookingDetailScreen({required this.booking, super.key});

  final Booking booking;

  double get _total => booking.price * booking.quantity;
  double get _savings {
    final savings = (booking.oldPrice - booking.price) * booking.quantity;
    return savings > 0 ? savings : 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('booking-detail-screen'),
      backgroundColor: AppTheme.cream,
      appBar: AppBar(
        leading: IconButton(
          key: const ValueKey('booking-detail-back'),
          tooltip: 'Retour',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Détail de réservation'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final contentWidth = constraints.maxWidth > 680
              ? 640.0
              : constraints.maxWidth;

          return Center(
            child: SizedBox(
              width: contentWidth,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildOfferCard(context),
                    const SizedBox(height: 16),
                    _buildReferenceAndStatus(),
                    const SizedBox(height: 16),
                    _buildPickupCard(context),
                    const SizedBox(height: 16),
                    _buildPriceCard(context),
                    const SizedBox(height: 16),
                    _buildInstructionsCard(context),
                    const SizedBox(height: 16),
                    _buildDemoCodeCard(context),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOfferCard(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: OfferPhoto(imageUrl: booking.image, iconSize: 52),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.name,
                  key: const ValueKey('booking-detail-name'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.storefront_outlined,
                      size: 19,
                      color: AppTheme.gold,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        booking.restaurant,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.ink.withValues(alpha: 0.72),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      key: const ValueKey('booking-detail-quantity'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.cream,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${booking.quantity} portion${booking.quantity == 1 ? '' : 's'}',
                        style: const TextStyle(
                          color: AppTheme.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      '${_formatPrice(booking.price)} / portion',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.burgundy,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferenceAndStatus() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 12,
          spacing: 12,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Référence',
                  style: TextStyle(
                    color: AppTheme.ink.withValues(alpha: 0.62),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  booking.id,
                  key: const ValueKey('booking-detail-reference'),
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            _BookingStatus(status: booking.status),
          ],
        ),
      ),
    );
  }

  Widget _buildPickupCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Récupération',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.burgundy,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            _InfoRow(
              icon: Icons.schedule_rounded,
              label: 'Date et heure',
              value: booking.date,
              valueKey: const ValueKey('booking-detail-date'),
            ),
            const SizedBox(height: 15),
            _InfoRow(
              icon: Icons.location_on_outlined,
              label: 'Adresse du commerçant',
              value: booking.address,
              valueKey: const ValueKey('booking-detail-address'),
            ),
            const SizedBox(height: 15),
            _InfoRow(
              icon: Icons.shopping_bag_outlined,
              label: 'Modalité',
              value: booking.pickup,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Récapitulatif du prix',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.burgundy,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            _PriceRow(
              label: 'Prix initial',
              value: _formatPrice(booking.oldPrice * booking.quantity),
            ),
            const SizedBox(height: 11),
            _PriceRow(
              label: 'Économies',
              value: _formatPrice(_savings),
              valueKey: const ValueKey('booking-detail-savings'),
              valueColor: AppTheme.gold,
            ),
            const Divider(height: 26),
            _PriceRow(
              label: 'Total payé',
              value: _formatPrice(_total),
              valueKey: const ValueKey('booking-detail-total'),
              emphasized: true,
              valueColor: AppTheme.burgundy,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionsCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: AppTheme.gold),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Instructions de récupération',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.burgundy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              booking.instructions,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.ink.withValues(alpha: 0.82),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDemoCodeCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Text(
              'Code de retrait fictif',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.burgundy,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'DÉMONSTRATION — ce code n’est pas valide pour un retrait.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppTheme.ink.withValues(alpha: 0.68)),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                color: AppTheme.cream,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.gold.withValues(alpha: 0.6)),
              ),
              child: Text(
                booking.pickupCode ?? 'Aucun code pour cette réservation',
                key: const ValueKey('booking-detail-demo-code'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: booking.pickupCode == null
                      ? AppTheme.ink.withValues(alpha: 0.65)
                      : AppTheme.burgundy,
                  fontSize: booking.pickupCode == null ? 14 : 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: booking.pickupCode == null ? 0 : 1.5,
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

class _BookingStatus extends StatelessWidget {
  const _BookingStatus({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (color, background, icon) = switch (status) {
      'En préparation' => (
        const Color(0xFF14752A),
        const Color(0xFFE5F5D8),
        Icons.access_time_rounded,
      ),
      'En cours' => (
        const Color(0xFFE07800),
        const Color(0xFFFFF0C7),
        Icons.access_time_rounded,
      ),
      'Terminée' => (
        const Color(0xFF14752A),
        const Color(0xFFE5F5D8),
        Icons.check_circle_rounded,
      ),
      'Annulée' => (
        const Color(0xFFC50000),
        const Color(0xFFFFDEDE),
        Icons.cancel_rounded,
      ),
      _ => (AppTheme.ink, AppTheme.cream, Icons.info_outline_rounded),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueKey,
  });

  final IconData icon;
  final String label;
  final String value;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppTheme.gold),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppTheme.ink.withValues(alpha: 0.62)),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                key: valueKey,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.value,
    this.valueKey,
    this.emphasized = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final Key? valueKey;
  final bool emphasized;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final style = emphasized
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyLarge;

    return Row(
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

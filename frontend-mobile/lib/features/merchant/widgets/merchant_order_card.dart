import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../models/merchant_order.dart';

class MerchantOrderCard extends StatelessWidget {
  const MerchantOrderCard({super.key, required this.order, this.actions});

  final MerchantOrder order;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final date = (order.createdAt ?? order.pickupDateTime)?.toLocal();
    final offerTitle = order.offerTitle.isEmpty
        ? 'Offre sans nom'
        : order.offerTitle;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.customerName ?? offerTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: context.colors.onSurface,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      if (order.customerName != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          offerTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: context.colors.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _OrderStatusBadge(status: order.status),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 18,
              runSpacing: 8,
              children: [
                if (order.quantity case final quantity?)
                  _OrderMeta(
                    icon: Icons.shopping_bag_outlined,
                    label: '$quantity portion${quantity == 1 ? '' : 's'}',
                  ),
                if (order.totalPrice case final price?)
                  _OrderMeta(
                    icon: Icons.payments_outlined,
                    label: '${price.toStringAsFixed(3)} DT',
                  ),
                if (order.paymentStatusLabel case final payment?)
                  _OrderMeta(icon: Icons.credit_card_outlined, label: payment),
                if (date != null)
                  _OrderMeta(
                    icon: Icons.schedule_rounded,
                    label:
                        '${localizations.formatMediumDate(date)} · '
                        '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(date))}',
                  ),
              ],
            ),
            if (actions case final actions?) ...[
              const SizedBox(height: 8),
              actions,
            ],
          ],
        ),
      ),
    );
  }
}

class _OrderMeta extends StatelessWidget {
  const _OrderMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppTheme.gold),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _OrderStatusBadge extends StatelessWidget {
  const _OrderStatusBadge({required this.status});

  final MerchantOrderStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color, background) = switch (status) {
      MerchantOrderStatus.pending => (
        'En attente',
        const Color(0xFF9A5A00),
        const Color(0xFFFFF0C7),
      ),
      MerchantOrderStatus.confirmed => (
        'Confirmée',
        const Color(0xFF145DA0),
        const Color(0xFFE2F0FF),
      ),
      MerchantOrderStatus.completed => (
        'Terminée',
        const Color(0xFF14752A),
        const Color(0xFFE5F5D8),
      ),
      MerchantOrderStatus.cancelled => (
        'Annulée',
        const Color(0xFFC50000),
        const Color(0xFFFFDEDE),
      ),
      MerchantOrderStatus.rejected => (
        'Refusée',
        const Color(0xFFC50000),
        const Color(0xFFFFDEDE),
      ),
      MerchantOrderStatus.unknown => (
        'Statut inconnu',
        context.colors.onSurface,
        context.colors.surface,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

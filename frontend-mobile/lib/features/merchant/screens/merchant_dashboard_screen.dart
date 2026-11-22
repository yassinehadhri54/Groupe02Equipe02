import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../data/demo_merchant_repository.dart';
import '../models/merchant_order.dart';
import 'create_offer_screen.dart';
import 'merchant_offers_screen.dart';

class MerchantDashboardScreen extends StatefulWidget {
  const MerchantDashboardScreen({super.key, this.repository});

  final MerchantRepository? repository;

  @override
  State<MerchantDashboardScreen> createState() =>
      _MerchantDashboardScreenState();
}

class _MerchantDashboardScreenState extends State<MerchantDashboardScreen> {
  final _ordersSectionKey = GlobalKey();

  MerchantRepository get _repository =>
      widget.repository ?? DemoMerchantRepository.shared;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _repository,
      builder: (context, _) => Scaffold(
        key: const ValueKey('merchant-dashboard-screen'),
        backgroundColor: AppTheme.cream,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final contentWidth = constraints.maxWidth > 900
                  ? 860.0
                  : constraints.maxWidth;

              return Center(
                child: SizedBox(
                  width: contentWidth,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(context),
                        const SizedBox(height: 22),
                        _buildStatistics(context),
                        const SizedBox(height: 26),
                        _buildQuickActions(context),
                        const SizedBox(height: 28),
                        _buildOrdersSection(context),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 17, 16, 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF720000), AppTheme.burgundy, Color(0xFFB31511)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppTheme.burgundy.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                    children: [
                      TextSpan(
                        text: 'Campus',
                        style: TextStyle(color: Colors.white),
                      ),
                      TextSpan(
                        text: 'Save',
                        style: TextStyle(color: AppTheme.gold),
                      ),
                      TextSpan(text: ' 🌱'),
                    ],
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('merchant-notifications'),
                tooltip: 'Notifications',
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Aucune nouvelle notification pour le moment.',
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.notifications_none_rounded),
              ),
            ],
          ),
          const SizedBox(height: 19),
          Text(
            'Espace commerçant',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            'Bienvenue ! Voici l’activité de votre commerce.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: Colors.white.withValues(alpha: 0.88)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatistics(BuildContext context) {
    final statistics = _repository.statistics;
    final values = [
      _StatisticData(
        key: const ValueKey('merchant-stat-active-offers'),
        label: 'Offres actives',
        value: '${statistics.activeOfferCount}',
        icon: Icons.local_offer_outlined,
      ),
      _StatisticData(
        key: const ValueKey('merchant-stat-orders'),
        label: 'Réservations reçues',
        value: '${statistics.orderCount}',
        icon: Icons.receipt_long_outlined,
      ),
      _StatisticData(
        key: const ValueKey('merchant-stat-revenue'),
        label: 'Chiffre d’affaires',
        value: '${statistics.revenue.toStringAsFixed(3)} DT',
        icon: Icons.payments_outlined,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vue d’ensemble',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(color: AppTheme.ink, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 13),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth > 700
                ? 3
                : constraints.maxWidth > 440
                ? 2
                : 1;
            final spacing = 12.0;
            final cardWidth =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: values
                  .map(
                    (statistic) => SizedBox(
                      width: cardWidth,
                      child: _StatisticCard(statistic: statistic),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Actions rapides',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(color: AppTheme.ink, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 13),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              key: const ValueKey('merchant-open-offers'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => MerchantOffersScreen(repository: _repository),
                ),
              ),
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Text('Mes offres'),
            ),
            FilledButton.icon(
              key: const ValueKey('merchant-create-offer'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CreateOfferScreen(repository: _repository),
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.burgundy,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Ajouter une offre'),
            ),
            OutlinedButton.icon(
              key: const ValueKey('merchant-view-orders'),
              onPressed: _scrollToOrders,
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Voir les réservations'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOrdersSection(BuildContext context) {
    final orders = _repository.orders.toList()
      ..sort((first, second) {
        return second.pickupDateTime.compareTo(first.pickupDateTime);
      });
    final latestOrders = orders.take(5).toList();

    return Column(
      key: _ordersSectionKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Dernières réservations',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              '${latestOrders.length} / ${orders.length}',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppTheme.ink.withValues(alpha: 0.62),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 13),
        if (latestOrders.isEmpty)
          const _EmptyOrdersCard()
        else
          ...latestOrders.map(
            (order) => Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: _OrderCard(order: order),
            ),
          ),
      ],
    );
  }

  void _scrollToOrders() {
    final sectionContext = _ordersSectionKey.currentContext;
    if (sectionContext == null) return;

    Scrollable.ensureVisible(
      sectionContext,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }
}

class _StatisticData {
  const _StatisticData({
    required this.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  final Key key;
  final String label;
  final String value;
  final IconData icon;
}

class _StatisticCard extends StatelessWidget {
  const _StatisticCard({required this.statistic});

  final _StatisticData statistic;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: statistic.key,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: AppTheme.gold.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(statistic.icon, color: AppTheme.burgundy, size: 23),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statistic.label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.ink.withValues(alpha: 0.65),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    statistic.value,
                    key: ValueKey('${statistic.key}-value'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final MerchantOrder order;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final pickupTime = TimeOfDay.fromDateTime(order.pickupDateTime);
    final formattedPickup =
        '${localizations.formatMediumDate(order.pickupDateTime)} · '
        '${localizations.formatTimeOfDay(pickupTime)}';

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
                        order.customerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: AppTheme.ink,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        order.offerTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.ink.withValues(alpha: 0.68),
                        ),
                      ),
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
                _OrderMeta(
                  icon: Icons.shopping_bag_outlined,
                  label:
                      '${order.quantity} portion${order.quantity == 1 ? '' : 's'}',
                ),
                _OrderMeta(
                  icon: Icons.payments_outlined,
                  label: '${order.totalPrice.toStringAsFixed(3)} DT',
                ),
                _OrderMeta(
                  icon: Icons.schedule_rounded,
                  label: formattedPickup,
                ),
              ],
            ),
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
            color: AppTheme.ink.withValues(alpha: 0.75),
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

class _EmptyOrdersCard extends StatelessWidget {
  const _EmptyOrdersCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const ValueKey('merchant-empty-orders'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 42,
              color: AppTheme.burgundy.withValues(alpha: 0.55),
            ),
            const SizedBox(height: 10),
            Text(
              'Aucune réservation pour le moment',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: AppTheme.ink, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 5),
            Text(
              'Les réservations reçues apparaîtront ici.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppTheme.ink.withValues(alpha: 0.65)),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:material_ui/material_ui.dart';

import '../../../core/network/auth_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/screens/login_screen.dart';
import '../data/demo_merchant_repository.dart';
import '../data/merchant_api_repository.dart';
import '../models/merchant_dashboard_stats.dart';
import '../models/merchant_order.dart';
import '../models/merchant_shop.dart';
import '../widgets/merchant_order_card.dart';
import 'create_offer_screen.dart';
import 'merchant_offers_screen.dart';
import 'merchant_reservations_screen.dart';
import 'merchant_shop_screen.dart';
import 'verify_pickup_screen.dart';

class MerchantDashboardScreen extends StatefulWidget {
  const MerchantDashboardScreen({
    super.key,
    this.repository,
    this.authRepository,
  }) : assert(repository != null || authRepository != null);

  final MerchantRepository? repository;
  final AuthRepository? authRepository;

  @override
  State<MerchantDashboardScreen> createState() =>
      _MerchantDashboardScreenState();
}

class _MerchantDashboardScreenState extends State<MerchantDashboardScreen> {
  MerchantRepository get _repository => widget.repository!;
  late final _api = MerchantApiRepository(widget.authRepository!);
  late Future<MerchantShop?> _shop = _api.getShop();
  Future<MerchantDashboardStats>? _dashboard;

  @override
  Widget build(BuildContext context) {
    final repository = widget.repository;
    return repository == null
        ? _buildPage(context)
        : AnimatedBuilder(
            animation: repository,
            builder: (context, _) => _buildPage(context),
          );
  }

  Widget _buildPage(BuildContext context) {
    return Scaffold(
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
                      if (widget.repository == null)
                        _buildShop(context)
                      else ...[
                        _buildStatistics(context, _repository.statistics),
                        const SizedBox(height: 28),
                        _buildOrdersSection(
                          context,
                          _demoRecentOrders(),
                          _repository.orders.length,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _reloadShop() {
    setState(() {
      _shop = _api.getShop();
      _dashboard = null;
    });
  }

  Future<void> _editShop(MerchantShop? shop) async {
    final updated = await Navigator.of(context).push<MerchantShop>(
      MaterialPageRoute(
        builder: (_) => MerchantShopScreen(repository: _api, shop: shop),
      ),
    );
    if (!mounted || updated == null) return;
    setState(() {
      _shop = Future.value(updated);
    });
  }

  Future<void> _logout() async {
    final auth = widget.authRepository!;
    await auth.clearSession();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => LoginScreen(authRepository: auth),
      ),
      (_) => false,
    );
  }

  Widget _buildShop(BuildContext context) {
    return FutureBuilder<MerchantShop?>(
      future: _shop,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          final error = snapshot.error;
          return Column(
            children: [
              Text(
                error is AuthException
                    ? error.message
                    : 'Impossible de charger le commerce.',
              ),
              if (error is! AuthException || error.statusCode != 401)
                TextButton(
                  onPressed: _reloadShop,
                  child: const Text('Réessayer'),
                ),
            ],
          );
        }

        final shop = snapshot.data;
        if (shop == null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Inscris ton commerce pour demander sa validation.'),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: () => _editShop(null),
                child: const Text('Inscrire mon commerce'),
              ),
            ],
          );
        }

        final status = switch (shop.status) {
          'approved' => 'Commerce approuvé',
          'pending' => 'En attente de validation',
          'rejected' => 'Commerce refusé',
          'suspended' => 'Commerce suspendu',
          _ => 'Statut indisponible',
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shop.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(status),
                    if (shop.address.isNotEmpty) Text(shop.address),
                    const SizedBox(height: 6),
                    Wrap(
                      children: [
                        TextButton(
                          onPressed: () => _editShop(shop),
                          child: const Text('Modifier le commerce'),
                        ),
                        TextButton(
                          onPressed: _reloadShop,
                          child: const Text('Actualiser le statut'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (shop.status == 'approved') ...[
              const SizedBox(height: 26),
              _buildQuickActions(context),
              const SizedBox(height: 26),
              _buildDashboard(context),
            ],
          ],
        );
      },
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
              if (widget.repository == null)
                IconButton(
                  tooltip: 'Se déconnecter',
                  onPressed: _logout,
                  color: Colors.white,
                  icon: const Icon(Icons.logout_rounded),
                )
              else
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

  Widget _buildDashboard(BuildContext context) {
    return FutureBuilder<MerchantDashboardStats>(
      future: _dashboard ??= _api.getDashboard(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          final error = snapshot.error;
          return Column(
            children: [
              Text(
                error is AuthException
                    ? error.message
                    : 'Impossible de charger les statistiques.',
              ),
              if (error is! AuthException || error.statusCode != 401)
                TextButton(
                  onPressed: _reloadDashboard,
                  child: const Text('Réessayer'),
                ),
            ],
          );
        }

        final stats = snapshot.requireData;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _reloadDashboard,
                icon: const Icon(Icons.refresh),
                label: const Text('Actualiser les statistiques'),
              ),
            ),
            _buildStatistics(context, stats),
            if (stats.revenueByMode.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  for (final entry in stats.revenueByMode.entries)
                    Chip(
                      label: Text(
                        '${_paymentModeLabel(entry.key)} · ${entry.value.toStringAsFixed(3)} DT',
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            _buildTopOffers(context, stats.topOffers),
            const SizedBox(height: 24),
            _buildOrdersSection(
              context,
              stats.recentReservations,
              stats.orderCount,
            ),
          ],
        );
      },
    );
  }

  String _paymentModeLabel(String mode) => switch (mode) {
    'mock' => 'Mock',
    'sandbox' => 'Sandbox',
    _ => 'Autre mode',
  };

  void _reloadDashboard() {
    setState(() {
      _dashboard = null;
    });
  }

  Future<void> _openActivity(Widget Function(VoidCallback) screen) async {
    var changed = false;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => screen(() {
          changed = true;
        }),
      ),
    );
    if (mounted && changed) _reloadDashboard();
  }

  Future<void> _createOffer() async {
    final created = await Navigator.of(context).push<Object>(
      MaterialPageRoute(builder: (_) => CreateOfferScreen(repository: _api)),
    );
    if (mounted && created != null) _reloadDashboard();
  }

  Widget _buildTopOffers(BuildContext context, List<MerchantTopOffer> offers) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Meilleures offres',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(color: AppTheme.ink, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        if (offers.isEmpty) const Text('Aucune offre classée pour le moment.'),
        for (final offer in offers)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: ListTile(
                title: Text(offer.name.isEmpty ? 'Offre sans nom' : offer.name),
                subtitle: Text(
                  '${offer.reservations} réservation(s) · '
                  '${offer.quantityReserved} portion(s) réservée(s) · '
                  '${offer.paidRevenue.toStringAsFixed(3)} DT payés',
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatistics(
    BuildContext context,
    MerchantDashboardStats statistics,
  ) {
    final offerCount = statistics.offerCount;
    final values = [
      _StatisticData(
        key: ValueKey(
          offerCount == null
              ? 'merchant-stat-active-offers'
              : 'merchant-stat-offers',
        ),
        label: offerCount == null ? 'Offres actives' : 'Offres au total',
        value: '${offerCount ?? statistics.activeOfferCount}',
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
        label: offerCount == null
            ? 'Chiffre d’affaires'
            : 'Recettes comptabilisées',
        value: '${statistics.revenue.toStringAsFixed(3)} DT',
        icon: Icons.payments_outlined,
      ),
      if (statistics.itemsSold case final itemsSold?)
        _StatisticData(
          key: const ValueKey('merchant-stat-items-sold'),
          label: 'Articles remis',
          value: '$itemsSold',
          icon: Icons.shopping_bag_outlined,
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
              onPressed: () => _openActivity(
                (onChanged) => MerchantOffersScreen(
                  repository: _api,
                  onChanged: onChanged,
                ),
              ),
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Text('Mes offres'),
            ),
            FilledButton.icon(
              key: const ValueKey('merchant-create-offer'),
              onPressed: _createOffer,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.burgundy,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Ajouter une offre'),
            ),
            OutlinedButton.icon(
              key: const ValueKey('merchant-view-orders'),
              onPressed: () => _openActivity(
                (onChanged) => MerchantReservationsScreen(
                  repository: _api,
                  onChanged: onChanged,
                ),
              ),
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Réservations reçues'),
            ),
            OutlinedButton.icon(
              key: const ValueKey('merchant-verify-pickup'),
              onPressed: () => _openActivity(
                (onChanged) =>
                    VerifyPickupScreen(repository: _api, onChanged: onChanged),
              ),
              icon: const Icon(Icons.qr_code_rounded),
              label: const Text('Vérifier un retrait'),
            ),
          ],
        ),
      ],
    );
  }

  List<MerchantOrder> _demoRecentOrders() {
    final orders = _repository.orders.toList()
      ..sort(
        (first, second) => (second.pickupDateTime?.millisecondsSinceEpoch ?? 0)
            .compareTo(first.pickupDateTime?.millisecondsSinceEpoch ?? 0),
      );
    return orders.take(5).toList();
  }

  Widget _buildOrdersSection(
    BuildContext context,
    List<MerchantOrder> latestOrders,
    int total,
  ) {
    return Column(
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
              '${latestOrders.length} / $total',
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
              child: MerchantOrderCard(order: order),
            ),
          ),
      ],
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

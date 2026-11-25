import 'package:material_ui/material_ui.dart';

import '../../../core/network/auth_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_toggle_button.dart';
import '../../auth/screens/login_screen.dart';
import '../../impact/screens/impact_dashboard_screen.dart';
import '../data/admin_api_repository.dart';
import '../models/admin_data.dart';
import '../widgets/admin_panel.dart';
import 'admin_offers_screen.dart';
import 'admin_shops_screen.dart';
import 'admin_users_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({
    super.key,
    required this.authRepository,
    required this.administrator,
  });

  final AuthRepository authRepository;
  final AuthUser administrator;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  static const _tabs = [
    (label: 'Tableau de bord', icon: Icons.space_dashboard_outlined),
    (label: 'Commerces', icon: Icons.storefront_outlined),
    (label: 'Utilisateurs', icon: Icons.people_outline),
    (label: 'Offres', icon: Icons.local_offer_outlined),
    (label: 'Profil', icon: Icons.person_outline),
  ];

  late final _repository = AdminApiRepository(
    widget.authRepository,
    administratorId: widget.administrator.uid,
  );
  Future<AdminStats>? _stats;
  int _tab = 0;
  bool _signingOut = false;

  void _invalidateStats() {
    setState(() {
      _stats = null;
    });
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      await widget.authRepository.clearSession();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => LoginScreen(authRepository: widget.authRepository),
        ),
        (_) => false,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _signingOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de fermer la session. Réessaie.'),
        ),
      );
    }
  }

  Widget _currentPage() => switch (_tab) {
    0 => AdminDataView<AdminStats>(
      future: _stats ??= _repository.loadDashboard(),
      onReload: _invalidateStats,
      onSignOut: _signOut,
      builder: (stats) => _AdminOverview(
        stats: stats,
        onReload: _invalidateStats,
        onImpact: () =>
            openImpact(context, widget.authRepository, ImpactScope.admin),
      ),
    ),
    1 => AdminShopsScreen(
      repository: _repository,
      onChanged: _invalidateStats,
      onSignOut: _signOut,
    ),
    2 => AdminUsersScreen(
      repository: _repository,
      onChanged: _invalidateStats,
      onSignOut: _signOut,
    ),
    3 => AdminOffersScreen(
      repository: _repository,
      onChanged: _invalidateStats,
      onSignOut: _signOut,
    ),
    _ => AdminDetails(
      fields: {
        'Nom': widget.administrator.fullName,
        'Adresse e-mail': widget.administrator.email,
        'Rôle': adminRoleLabel(widget.administrator.role),
        'Statut': adminStatusLabel(widget.administrator.status),
      },
      actions: OutlinedButton.icon(
        onPressed: _signingOut ? null : _signOut,
        icon: const Icon(Icons.logout),
        label: const Text('Se déconnecter'),
      ),
    ),
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Administration CampusSave'),
      actions: const [ThemeToggleButton(), SizedBox(width: 8)],
    ),
    body: SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 760;
          final content = Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: _currentPage(),
            ),
          );
          if (!wide) return content;
          return Row(
            children: [
              NavigationRail(
                selectedIndex: _tab,
                onDestinationSelected: (tab) => setState(() => _tab = tab),
                labelType: NavigationRailLabelType.all,
                indicatorColor: AppTheme.gold.withValues(alpha: 0.25),
                destinations: [
                  for (final (index, item) in _tabs.indexed)
                    NavigationRailDestination(
                      icon: Icon(item.icon, key: ValueKey('admin-tab-$index')),
                      label: Text(item.label),
                    ),
                ],
              ),
              Expanded(child: content),
            ],
          );
        },
      ),
    ),
    bottomNavigationBar: MediaQuery.sizeOf(context).width >= 760
        ? null
        : NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (tab) => setState(() => _tab = tab),
            labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
            indicatorColor: AppTheme.gold.withValues(alpha: 0.25),
            destinations: [
              for (final (index, item) in _tabs.indexed)
                NavigationDestination(
                  key: ValueKey('admin-tab-$index'),
                  icon: Icon(item.icon),
                  label: item.label,
                ),
            ],
          ),
  );
}

class _AdminOverview extends StatelessWidget {
  const _AdminOverview({
    required this.stats,
    required this.onReload,
    required this.onImpact,
  });

  final AdminStats stats;
  final VoidCallback onReload;
  final VoidCallback onImpact;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      if (stats.users case final total?)
        ('Utilisateurs', total, Icons.people_outline),
      if (stats.shops case final total?)
        ('Commerces', total, Icons.storefront_outlined),
      if (stats.pendingShops case final total?)
        ('Commerces en attente', total, Icons.hourglass_empty),
      if (stats.offers case final total?)
        ('Offres', total, Icons.local_offer_outlined),
      if (stats.reservations case final total?)
        ('Réservations', total, Icons.receipt_long_outlined),
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Vue d’ensemble',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            IconButton(
              tooltip: 'Actualiser les statistiques',
              onPressed: onReload,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: onImpact,
            icon: const Icon(Icons.eco_outlined),
            label: const Text('Impact global'),
          ),
        ),
        const SizedBox(height: 12),
        if (metrics.isEmpty)
          const Text('Aucune statistique disponible.')
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 660
                  ? 3
                  : constraints.maxWidth >= 380
                  ? 2
                  : 1;
              final width =
                  (constraints.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final (label, count, icon) in metrics)
                    SizedBox(
                      width: width,
                      child: Card(
                        child: ListTile(
                          leading: Icon(icon, color: context.colors.primary),
                          title: Text(
                            '$count',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          subtitle: Text(label),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

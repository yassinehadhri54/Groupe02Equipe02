import 'dart:convert';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../core/network/auth_repository.dart';

enum ImpactScope { student, merchant, admin }

class ImpactReport {
  const ImpactReport(this.metrics, this.ecoPoints);

  final Map<String, dynamic> metrics;
  final Map<String, dynamic> ecoPoints;

  int get balance => _number(ecoPoints['total']).toInt();

  static Future<ImpactReport> load(
    AuthRepository repository,
    ImpactScope scope,
  ) async {
    final response = await repository.getAuthenticated(
      '/api/dashboard/${scope.name}',
    );
    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic> ||
        body['data'] is! Map<String, dynamic>) {
      throw const FormatException('Réponse du tableau de bord invalide.');
    }
    final data = body['data'] as Map<String, dynamic>;
    final metrics = data['impact'];
    if (metrics is! Map<String, dynamic> ||
        metrics['recoveredOrders'] is! num) {
      throw const FormatException('Indicateurs d’impact indisponibles.');
    }
    final points = data['ecoPoints'];
    return ImpactReport(
      metrics,
      points is Map<String, dynamic> ? points : const {},
    );
  }
}

num _number(Object? value) => value is num && value.isFinite ? value : 0;

List<Map<String, dynamic>> _rows(Object? data) =>
    data is List ? data.whereType<Map<String, dynamic>>().toList() : const [];

const _frenchMonths = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

String _day(Object? value, {bool month = false, bool week = false}) {
  final date = value is String ? DateTime.tryParse(value) : null;
  if (date == null) return 'Date indisponible';
  final period = '${_frenchMonths[date.month - 1]} ${date.year}';
  if (month) return period;
  final day = '${date.day == 1 ? '1er' : date.day} $period';
  return week ? 'Semaine du $day' : day;
}

Future<void> openImpact(
  BuildContext context,
  AuthRepository repository,
  ImpactScope scope,
) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) =>
          ImpactDashboardScreen(repository: repository, scope: scope),
    ),
  );
}

class StudentImpactTile extends StatefulWidget {
  const StudentImpactTile({super.key, required this.repository});
  final AuthRepository repository;

  @override
  State<StudentImpactTile> createState() => _StudentImpactTileState();
}

class _StudentImpactTileState extends State<StudentImpactTile> {
  late Future<ImpactReport> _report = ImpactReport.load(
    widget.repository,
    ImpactScope.student,
  );

  bool _opening = false;

  Future<void> _open() async {
    if (_opening) return;
    _opening = true;
    try {
      await openImpact(context, widget.repository, ImpactScope.student);
      if (!mounted) return;
      final report = ImpactReport.load(widget.repository, ImpactScope.student);
      setState(() {
        _report = report;
      });
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ImpactReport>(
    future: _report,
    builder: (context, snapshot) => Card(
      child: ListTile(
        leading: Icon(
          Icons.eco_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(
          snapshot.hasData
              ? '${snapshot.data!.balance} EcoPoints'
              : 'EcoPoints',
        ),
        subtitle: const Text('Voir mon impact'),
        trailing: const Icon(Icons.chevron_right),
        onTap: snapshot.connectionState == ConnectionState.done ? _open : null,
      ),
    ),
  );
}

class ImpactDashboardScreen extends StatefulWidget {
  const ImpactDashboardScreen({
    super.key,
    required this.repository,
    required this.scope,
  });
  final AuthRepository repository;
  final ImpactScope scope;

  @override
  State<ImpactDashboardScreen> createState() => _ImpactDashboardScreenState();
}

class _ImpactDashboardScreenState extends State<ImpactDashboardScreen> {
  late Future<ImpactReport> _report = _load();
  bool _monthly = false;
  bool _refreshing = false;

  Future<ImpactReport> _load() =>
      ImpactReport.load(widget.repository, widget.scope);

  Future<void> _refresh() async {
    if (!mounted || _refreshing) return;
    _refreshing = true;
    final report = _load();
    setState(() {
      _report = report;
    });
    try {
      await report;
    } on Exception {
      // FutureBuilder displays the failed request.
    } finally {
      _refreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tableau d’impact')),
    body: SafeArea(
      child: FutureBuilder<ImpactReport>(
        future: _report,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: TextButton(
                onPressed: _refresh,
                child: const Text('Impact indisponible · Réessayer'),
              ),
            );
          }
          return _content(context, snapshot.data!);
        },
      ),
    ),
  );

  Widget _content(BuildContext context, ImpactReport report) {
    final metrics = report.metrics;
    final student = widget.scope == ImpactScope.student;
    final admin = widget.scope == ImpactScope.admin;
    final recovered = _number(metrics['recoveredOrders']).toInt();
    final history = _rows(report.ecoPoints['history']);
    final savings = metrics['savings'];
    final missingSavings = _number(metrics['missingSavings']);
    final savingsLabel =
        savings is num &&
            savings.isFinite &&
            (recovered == 0 || missingSavings < recovered)
        ? '${savings.toStringAsFixed(3).replaceAll('.', ',')} DT'
        : 'Indisponible';

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Retraits validés',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('Commandes récupérées'),
                  trailing: Text('$recovered'),
                ),
                ListTile(
                  title: const Text('Portions sauvées'),
                  trailing: Text('${_number(metrics['portions'])}'),
                ),
                if (admin)
                  ListTile(
                    title: const Text('Commerces participants'),
                    trailing: Text('${_number(metrics['participatingShops'])}'),
                  ),
                if (student) ...[
                  ListTile(
                    title: const Text('Économies sur les offres'),
                    trailing: Text(savingsLabel),
                  ),
                  ListTile(
                    title: const Text('EcoPoints cumulés'),
                    trailing: Text('${report.balance}'),
                  ),
                ],
              ],
            ),
          ),
          if (student && missingSavings > 0)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Les anciens retraits sans prix initial enregistré sont exclus des économies.',
              ),
            ),
          const SizedBox(height: 24),
          Text('Évolution', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Semaines'),
                selected: !_monthly,
                onSelected: (_) => setState(() => _monthly = false),
              ),
              ChoiceChip(
                label: const Text('Mois'),
                selected: _monthly,
                onSelected: (_) => setState(() => _monthly = true),
              ),
            ],
          ),
          if (recovered == 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Aucun retrait validé pour le moment.'),
            )
          else ...[
            _ImpactBars(
              rows: _rows(metrics[_monthly ? 'monthly' : 'weekly']),
              monthly: _monthly,
              showShops: admin,
            ),
            if (_number(metrics['missingPickupDate']) > 0)
              const Text(
                'Les anciens retraits sans date sont inclus dans les totaux.',
              ),
          ],
          if (student) ...[
            const SizedBox(height: 24),
            Text(
              'Historique EcoPoints',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (history.isEmpty)
              const Text('Aucun point gagné pour le moment.'),
            for (final entry in history)
              ListTile(
                title: Text('+${_number(entry['points'])} EcoPoints'),
                subtitle: Text(
                  '${_day(entry['date'])} · Réservation ${entry['reservationId'] ?? '—'}',
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ImpactBars extends StatelessWidget {
  const _ImpactBars({
    required this.rows,
    required this.monthly,
    required this.showShops,
  });
  final List<Map<String, dynamic>> rows;
  final bool monthly;
  final bool showShops;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final maximum = rows.fold<num>(
      1,
      (value, row) => math.max(value, _number(row['portions'])),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_day(row['start'], month: monthly, week: !monthly)),
                const SizedBox(height: 4),
                ExcludeSemantics(
                  child: LinearProgressIndicator(
                    value: (_number(row['portions']) / maximum)
                        .clamp(0, 1)
                        .toDouble(),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(8),
                    color: colors.primary,
                    backgroundColor: colors.surfaceContainerHighest,
                  ),
                ),
                Text(
                  '${_number(row['portions'])} portions · ${_number(row['recoveredOrders'])} retraits'
                  '${showShops ? " · ${_number(row['participatingShops'])} commerces" : ""}',
                ),
              ],
            ),
          ),
      ],
    );
  }
}

import 'package:material_ui/material_ui.dart';

import '../../../core/network/auth_repository.dart';
import '../data/merchant_api_repository.dart';
import '../models/merchant_order.dart';
import '../widgets/merchant_confirmation.dart';
import '../widgets/merchant_order_card.dart';

class MerchantReservationsScreen extends StatefulWidget {
  const MerchantReservationsScreen({
    super.key,
    required this.repository,
    this.onChanged,
  });

  final MerchantApiRepository repository;
  final VoidCallback? onChanged;

  @override
  State<MerchantReservationsScreen> createState() =>
      _MerchantReservationsScreenState();
}

class _MerchantReservationsScreenState
    extends State<MerchantReservationsScreen> {
  late Future<List<MerchantOrder>> _orders = widget.repository
      .getReservations();
  String? _busyOrder;
  bool _submitting = false;

  void _reload() {
    setState(() {
      _orders = widget.repository.getReservations();
    });
  }

  Future<void> _changeStatus(
    MerchantOrder order,
    MerchantOrderAction action,
  ) async {
    if (_busyOrder != null || !order.allows(action)) return;
    setState(() => _busyOrder = order.id);
    final confirming = action == MerchantOrderAction.confirm;

    try {
      final accepted = await confirmMerchantAction(
        context,
        title: confirming
            ? 'Confirmer la réservation ?'
            : 'Refuser la réservation ?',
        message: confirming
            ? 'La réservation sera confirmée et pourra être retirée.'
            : 'La réservation sera refusée et ses portions seront remises en stock.',
        actionLabel: confirming ? 'Confirmer' : 'Refuser',
        actionKey: const ValueKey('merchant-confirm-status-change'),
      );
      if (!mounted || accepted != true) return;
      setState(() => _submitting = true);
      await widget.repository.updateReservationStatus(order.id, action);
      if (!mounted) return;
      widget.onChanged?.call();
      _reload();
      _notify(confirming ? 'Réservation confirmée.' : 'Réservation refusée.');
    } on AuthException catch (error) {
      if (mounted) _notify(error.message);
    } finally {
      if (mounted) {
        setState(() {
          _busyOrder = null;
          _submitting = false;
        });
      }
    }
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget? _actions(MerchantOrder order) {
    if (_busyOrder == order.id && _submitting) {
      return const LinearProgressIndicator();
    }
    return switch (order) {
      _ when order.allows(MerchantOrderAction.confirm) => FilledButton.tonal(
        key: ValueKey('merchant-confirm-${order.id}'),
        onPressed: _busyOrder == null
            ? () => _changeStatus(order, MerchantOrderAction.confirm)
            : null,
        child: const Text('Confirmer'),
      ),
      _ when order.allows(MerchantOrderAction.reject) => OutlinedButton(
        key: ValueKey('merchant-reject-${order.id}'),
        onPressed: _busyOrder == null
            ? () => _changeStatus(order, MerchantOrderAction.reject)
            : null,
        child: const Text('Refuser'),
      ),
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _busyOrder == null,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Réservations reçues'),
          actions: [
            IconButton(
              tooltip: 'Actualiser les réservations',
              onPressed: _busyOrder == null ? _reload : null,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: SafeArea(
          child: FutureBuilder<List<MerchantOrder>>(
            future: _orders,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                final error = snapshot.error;
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          error is AuthException
                              ? error.message
                              : 'Impossible de charger les réservations.',
                        ),
                        if (error is! AuthException || error.statusCode != 401)
                          TextButton(
                            onPressed: _reload,
                            child: const Text('Réessayer'),
                          ),
                      ],
                    ),
                  ),
                );
              }
              final orders = snapshot.requireData;
              if (orders.isEmpty) {
                return const Center(child: Text('Aucune réservation reçue.'));
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: orders.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final order = orders[index];
                  return MerchantOrderCard(
                    key: ValueKey('merchant-reservation-${order.id}'),
                    order: order,
                    actions: _actions(order),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

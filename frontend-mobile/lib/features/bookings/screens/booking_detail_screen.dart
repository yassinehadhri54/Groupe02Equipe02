import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../data/payment_repository.dart';
import '../data/reservation_repository.dart';
import '../models/booking.dart';

class BookingDetailScreen extends StatefulWidget {
  const BookingDetailScreen({
    required this.booking,
    required this.repository,
    this.paymentRepository,
    this.onReservationChanged,
    super.key,
  });

  final Booking booking;
  final ReservationRepository repository;
  final PaymentRepository? paymentRepository;
  final VoidCallback? onReservationChanged;

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  late Booking _booking = widget.booking;
  late final PaymentRepository _paymentRepository =
      widget.paymentRepository ??
      PaymentRepository(authRepository: widget.repository.authRepository);
  bool _isCancelling = false;
  bool _isLoadingQr = false;
  bool _isLoadingPaymentMode = false;
  bool _isPaymentDialogOpen = false;
  bool _isProcessingPayment = false;
  String? _actionError;
  String? _paymentConfigError;
  String? _paymentError;
  PaymentMode? _paymentMode;
  ReservationQr? _qr;

  @override
  void initState() {
    super.initState();
    if (_booking.canPay) _loadPaymentMode();
  }

  Future<void> _loadPaymentMode() async {
    if (!_booking.canPay || _isLoadingPaymentMode) return;

    setState(() {
      _isLoadingPaymentMode = true;
      _paymentConfigError = null;
    });
    try {
      final mode = await _paymentRepository.fetchMode();
      if (mounted) setState(() => _paymentMode = mode);
    } on PaymentException catch (error) {
      if (mounted) {
        setState(() {
          _paymentMode = null;
          _paymentConfigError = error.message;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingPaymentMode = false);
    }
  }

  Future<void> _simulatePayment() async {
    if (!_booking.canPay ||
        _paymentMode != PaymentMode.mock ||
        _isLoadingPaymentMode ||
        _isPaymentDialogOpen ||
        _isProcessingPayment) {
      return;
    }

    setState(() => _isPaymentDialogOpen = true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Simuler le paiement ?'),
        content: const Text(
          'Paiement de démonstration — aucun débit réel. '
          'Continuer avec la simulation ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Retour'),
          ),
          FilledButton(
            key: const ValueKey('payment-simulate-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() => _isPaymentDialogOpen = false);
    if (confirmed != true) return;

    setState(() {
      _isProcessingPayment = true;
      _paymentError = null;
    });
    try {
      PaymentMode currentMode;
      try {
        currentMode = await _paymentRepository.fetchMode();
      } on PaymentException catch (error) {
        if (mounted) {
          setState(() {
            _paymentMode = null;
            _paymentConfigError = error.message;
          });
        }
        rethrow;
      }
      if (!mounted) return;
      if (currentMode != PaymentMode.mock) {
        setState(() => _paymentMode = currentMode);
        throw const PaymentException(
          'Le mode de paiement a changé. La simulation a été arrêtée.',
        );
      }

      final initiated = await _paymentRepository.initiatePayment(_booking.id);
      if (!mounted) return;
      if (initiated.mode != PaymentMode.mock) {
        setState(() => _paymentMode = initiated.mode);
        throw const PaymentException(
          'Le serveur n’a pas confirmé le mode Mock. Aucun paiement '
          'de démonstration n’a été confirmé.',
        );
      }
      if (initiated.status != 'pending') {
        throw const PaymentException(
          'Le paiement reçu du serveur n’est pas en attente.',
        );
      }

      final confirmation = await _paymentRepository.confirmMockPayment(
        initiated.id,
      );
      if (!mounted) return;
      if (confirmation.id != initiated.id || confirmation.status != 'paid') {
        throw const PaymentException(
          'Le serveur n’a pas confirmé le paiement comme payé.',
        );
      }

      final payment = await _paymentRepository.fetchPayment(initiated.id);
      if (!mounted) return;
      if (payment.id != initiated.id ||
          payment.mode != PaymentMode.mock ||
          payment.status != 'paid') {
        throw const PaymentException(
          'Le statut réel du paiement n’est pas confirmé comme payé.',
        );
      }

      final reservations = await widget.repository.fetchMyReservations();
      if (!mounted) return;
      Booking? refreshedBooking;
      for (final reservation in reservations) {
        if (reservation.id == _booking.id) {
          refreshedBooking = reservation;
          break;
        }
      }
      if (refreshedBooking == null ||
          refreshedBooking.paymentStatus != 'paid') {
        throw const PaymentException(
          'Le paiement est confirmé, mais la réservation n’est pas encore '
          'à jour. Réessaie de recharger tes réservations.',
        );
      }

      setState(() => _booking = refreshedBooking!);
      widget.onReservationChanged?.call();
    } on PaymentException catch (error) {
      if (mounted) {
        setState(() {
          _paymentError = _paymentConfigError == null ? error.message : null;
        });
      }
    } on ReservationException catch (error) {
      if (mounted) setState(() => _paymentError = error.message);
    } finally {
      if (mounted) setState(() => _isProcessingPayment = false);
    }
  }

  Future<void> _cancelReservation() async {
    if (!_booking.canCancel || _isCancelling) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler la réservation ?'),
        content: const Text('Cette action libérera la quantité réservée.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Garder'),
          ),
          FilledButton(
            key: const ValueKey('booking-cancel-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _isCancelling = true;
      _actionError = null;
    });
    try {
      final updated = await widget.repository.cancelReservation(_booking.id);
      if (!mounted) return;
      setState(() => _booking = updated);
      widget.onReservationChanged?.call();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Réservation annulée.')));
    } on ReservationException catch (error) {
      if (mounted) setState(() => _actionError = error.message);
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  Future<void> _loadQr() async {
    if (!_booking.canRequestQr || _isLoadingQr || _qr != null) return;

    setState(() {
      _isLoadingQr = true;
      _actionError = null;
    });
    try {
      final qr = await widget.repository.fetchQr(_booking.id);
      if (mounted) setState(() => _qr = qr);
    } on ReservationException catch (error) {
      if (mounted) setState(() => _actionError = error.message);
    } finally {
      if (mounted) setState(() => _isLoadingQr = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('booking-detail-screen'),
      backgroundColor: context.colors.surface,
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
                    _buildReservationCard(context),
                    _buildPaymentCard(context),
                    const SizedBox(height: 16),
                    _buildQrCard(context),
                    if (_actionError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _actionError!,
                        key: const ValueKey('booking-action-error'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.colors.primary),
                      ),
                    ],
                    if (_booking.canCancel) ...[
                      const SizedBox(height: 16),
                      OutlinedButton(
                        key: const ValueKey('booking-cancel-button'),
                        onPressed: _isCancelling ? null : _cancelReservation,
                        child: _isCancelling
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Annuler la réservation'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPaymentCard(BuildContext context) {
    if (!_booking.canPay) return const SizedBox.shrink();

    final mode = _paymentMode;
    return Card(
      key: const ValueKey('booking-payment-card'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Paiement',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: context.colors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            if (_isLoadingPaymentMode)
              const Center(
                child: CircularProgressIndicator(
                  key: ValueKey('payment-mode-loading'),
                ),
              )
            else if (_paymentConfigError != null) ...[
              Text(
                'Configuration du paiement indisponible : '
                '$_paymentConfigError',
                key: const ValueKey('payment-config-error'),
                textAlign: TextAlign.center,
              ),
              TextButton(
                key: const ValueKey('payment-config-retry'),
                onPressed: _loadPaymentMode,
                child: const Text('Réessayer'),
              ),
            ] else if (mode == PaymentMode.mock) ...[
              const Text(
                'Démonstration — aucun débit réel.',
                key: ValueKey('payment-mock-disclaimer'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(
                key: const ValueKey('payment-simulate-button'),
                onPressed: _isPaymentDialogOpen || _isProcessingPayment
                    ? null
                    : _simulatePayment,
                child: _isProcessingPayment
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _isPaymentDialogOpen
                            ? 'Confirmation…'
                            : 'Simuler le paiement',
                      ),
              ),
            ] else if (mode == PaymentMode.sandbox)
              const Text(
                'Le paiement Sandbox n’est pas encore intégré. '
                'Aucune confirmation Mock ne sera proposée.',
                key: ValueKey('payment-sandbox-unavailable'),
                textAlign: TextAlign.center,
              )
            else
              const Text(
                'Mode de paiement inconnu. Le paiement est désactivé.',
                key: ValueKey('payment-mode-unknown'),
                textAlign: TextAlign.center,
              ),
            if (_paymentError != null) ...[
              const SizedBox(height: 10),
              Text(
                _paymentError!,
                key: const ValueKey('payment-error'),
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.primary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReservationCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _booking.name,
              key: const ValueKey('booking-detail-name'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: context.colors.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (_booking.restaurant != null) ...[
              const SizedBox(height: 6),
              Text(
                _booking.restaurant!,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: context.colors.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 18),
            _InfoRow(
              label: 'Référence',
              value: _booking.id,
              valueKey: const ValueKey('booking-detail-reference'),
            ),
            const SizedBox(height: 14),
            _InfoRow(
              label: 'Statut de réservation',
              value: _booking.statusLabel,
              valueKey: const ValueKey('booking-detail-status'),
            ),
            if (_booking.paymentStatusLabel case final payment?) ...[
              const SizedBox(height: 14),
              _InfoRow(
                label: 'Statut du paiement',
                value: payment,
                valueKey: const ValueKey('booking-detail-payment-status'),
              ),
            ],
            const Divider(height: 28),
            _InfoRow(
              label: 'Quantité',
              value:
                  '${_booking.quantity} portion${_booking.quantity == 1 ? '' : 's'}',
              valueKey: const ValueKey('booking-detail-quantity'),
            ),
            const SizedBox(height: 14),
            _InfoRow(
              label: 'Prix unitaire',
              value: _formatPrice(_booking.unitPrice),
            ),
            const SizedBox(height: 14),
            _InfoRow(
              label: 'Total de la réservation',
              value: _formatPrice(_booking.totalPrice),
              valueKey: const ValueKey('booking-detail-total'),
            ),
            if (_booking.createdAtLabel case final date?) ...[
              const SizedBox(height: 14),
              _InfoRow(label: 'Créée le', value: date),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQrCard(BuildContext context) {
    final qr = _qr;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'QR de retrait',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: context.colors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            if (qr != null)
              _buildQrImage(qr.imageDataUrl)
            else if (_booking.canRequestQr)
              FilledButton.icon(
                key: const ValueKey('booking-qr-load'),
                onPressed: _isLoadingQr ? null : _loadQr,
                icon: _isLoadingQr
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.qr_code_2_rounded),
                label: Text(
                  _isLoadingQr ? 'Chargement…' : 'Afficher le QR réel',
                ),
              )
            else
              Text(
                _booking.paymentStatus == 'paid'
                    ? 'Le QR n’est pas disponible pour ce statut.'
                    : 'Le QR sera disponible après paiement confirmé.',
                key: ValueKey('booking-qr-unavailable'),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrImage(String imageDataUrl) {
    final separator = imageDataUrl.indexOf(',');
    if (separator < 0) {
      return const Text('Le QR reçu du serveur est invalide.');
    }

    try {
      final imageBytes = base64Decode(imageDataUrl.substring(separator + 1));
      return ColoredBox(
        key: const ValueKey('booking-qr-background'),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Image.memory(
            imageBytes,
            key: const ValueKey('booking-qr-image'),
            width: 220,
            height: 220,
            errorBuilder: (_, _, _) => const Text(
              'Impossible d’afficher le QR.',
              style: TextStyle(color: AppTheme.ink),
            ),
          ),
        ),
      );
    } on FormatException {
      return const Text('Le QR reçu du serveur est invalide.');
    }
  }

  String _formatPrice(double amount) => '${amount.toStringAsFixed(3)} DT';
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.valueKey});

  final String label;
  final String value;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: context.colors.onSurfaceVariant),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            key: valueKey,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.colors.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

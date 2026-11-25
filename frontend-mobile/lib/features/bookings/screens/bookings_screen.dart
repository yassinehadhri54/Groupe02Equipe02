import 'package:material_ui/material_ui.dart';

import '../../../core/network/auth_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../data/reservation_repository.dart';
import '../models/booking.dart';
import 'booking_detail_screen.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key, this.repository});

  final ReservationRepository? repository;

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  static const Color gold = AppTheme.gold;

  late final ReservationRepository _repository =
      widget.repository ??
      ReservationRepository(authRepository: AuthRepository());

  String selectedFilter = 'Toutes';
  List<Booking> bookings = const [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadReservations();
  }

  Future<void> _loadReservations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _repository.fetchMyReservations();
      if (mounted) setState(() => bookings = result);
    } on ReservationException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Booking> get filteredBookings {
    if (selectedFilter == 'Toutes') return bookings;
    final status = switch (selectedFilter) {
      'En attente' => ReservationStatus.pending,
      'Confirmées' => ReservationStatus.confirmed,
      'Refusées' => ReservationStatus.rejected,
      'Terminées' => ReservationStatus.completed,
      'Annulées' => ReservationStatus.cancelled,
      _ => ReservationStatus.unknown,
    };
    return bookings.where((booking) => booking.parsedStatus == status).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('bookings-screen'),
      backgroundColor: context.colors.surface,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 110),
                children: [
                  _buildFilters(),
                  const SizedBox(height: 24),
                  if (_isLoading)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 80),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: context.colors.primary,
                        ),
                      ),
                    )
                  else if (_errorMessage != null)
                    _buildErrorState()
                  else if (filteredBookings.isEmpty)
                    _buildEmptyState()
                  else
                    ...filteredBookings.map(
                      (booking) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _buildBookingCard(booking),
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

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 55, 22, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF780000), Color(0xFFAA0000), Color(0xFF8F0401)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(42),
          bottomRight: Radius.circular(42),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              RichText(
                text: const TextSpan(
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  children: [
                    TextSpan(
                      text: 'Campus',
                      style: TextStyle(color: Colors.white),
                    ),
                    TextSpan(
                      text: 'Save',
                      style: TextStyle(color: gold),
                    ),
                    TextSpan(text: ' 🌱'),
                  ],
                ),
              ),
              const Spacer(),
              Stack(
                children: [
                  IconButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Notifications bientôt disponibles'),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const Positioned(
                    right: 10,
                    top: 7,
                    child: CircleAvatar(radius: 4, backgroundColor: gold),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 25),
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Réservations',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 7),
                    Text(
                      'Suivez vos réservations et commandes.',
                      style: TextStyle(fontSize: 13, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Container(
                width: 75,
                height: 75,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.event_available_rounded,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    const filters = [
      ('Toutes', Icons.inventory_2_outlined),
      ('En attente', Icons.hourglass_top_rounded),
      ('Confirmées', Icons.check_circle_outline),
      ('Refusées', Icons.block_outlined),
      ('Terminées', Icons.check_circle_outline),
      ('Annulées', Icons.cancel_outlined),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final selected = selectedFilter == filter.$1;

          return Padding(
            padding: const EdgeInsets.only(right: 9),
            child: InkWell(
              key: ValueKey('booking-filter-${filter.$1}'),
              borderRadius: BorderRadius.circular(30),
              onTap: () {
                setState(() {
                  selectedFilter = filter.$1;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(
                  horizontal: 17,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? AppTheme.burgundy
                      : context.colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: context.colors.primary.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      filter.$2,
                      size: 20,
                      color: selected ? Colors.white : context.colors.onSurface,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      filter.$1,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: selected
                            ? Colors.white
                            : context.colors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBookingCard(Booking booking) {
    final statusColor = _statusColor(booking.parsedStatus);
    final statusBackground = _statusBackground(booking.parsedStatus);

    return Material(
      color: context.colors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(22),
      elevation: 0,
      child: InkWell(
        key: ValueKey('booking-card-${booking.id}'),
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => BookingDetailScreen(
                booking: booking,
                repository: _repository,
                onReservationChanged: _loadReservations,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: context.colors.primary.withValues(alpha: 0.07),
                blurRadius: 16,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 94,
                    height: 105,
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      Icons.restaurant_rounded,
                      color: context.colors.primary,
                      size: 36,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: context.colors.onSurface,
                          ),
                        ),
                        if (booking.restaurant != null) ...[
                          const SizedBox(height: 5),
                          Text(
                            booking.restaurant!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.adaptiveColor(
                                const Color(0xFF766B66),
                                context.colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Text(
                          '${booking.quantity} × ${_formatPrice(booking.unitPrice)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: context.adaptiveColor(
                              const Color(0xFF645954),
                              context.colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${_formatPrice(booking.totalPrice)} au total',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: context.colors.primary,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Wrap(
                          spacing: 7,
                          runSpacing: 6,
                          children: [
                            _statusPill(
                              booking.statusLabel,
                              statusColor,
                              statusBackground,
                            ),
                            if (booking.paymentStatusLabel case final label?)
                              _statusPill(
                                'Paiement : $label',
                                const Color(0xFF5F554F),
                                context.colors.surface,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: context.colors.onSurface,
                    size: 24,
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Divider(
                height: 1,
                color: context.adaptiveColor(
                  const Color(0xFFF0E8E0),
                  context.colors.outlineVariant,
                ),
              ),
              const SizedBox(height: 12),
              if (booking.createdAtLabel case final date?)
                Row(
                  children: [
                    Icon(
                      Icons.calendar_month_outlined,
                      size: 17,
                      color: context.colors.onSurface,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      date,
                      style: TextStyle(
                        fontSize: 11,
                        color: context.adaptiveColor(
                          const Color(0xFF645954),
                          context.colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(ReservationStatus status) => switch (status) {
    ReservationStatus.pending => const Color(0xFFE07800),
    ReservationStatus.confirmed ||
    ReservationStatus.completed => const Color(0xFF14752A),
    ReservationStatus.rejected ||
    ReservationStatus.cancelled => const Color(0xFFC50000),
    ReservationStatus.unknown => context.colors.onSurface,
  };

  Color _statusBackground(ReservationStatus status) => switch (status) {
    ReservationStatus.pending => const Color(0xFFFFF0C7),
    ReservationStatus.confirmed ||
    ReservationStatus.completed => const Color(0xFFE5F5D8),
    ReservationStatus.rejected ||
    ReservationStatus.cancelled => const Color(0xFFFFDEDE),
    ReservationStatus.unknown => context.colors.surface,
  };

  Widget _statusPill(String label, Color color, Color background) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  String _formatPrice(double amount) => '${amount.toStringAsFixed(3)} DT';

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 65,
            color: context.colors.primary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 15),
          Text(
            'Aucune réservation trouvée',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: context.colors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tes réservations apparaîtront ici.',
            style: TextStyle(color: context.colors.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          TextButton(
            key: const ValueKey('reservations-retry'),
            onPressed: _loadReservations,
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Column(
        children: [
          Text(
            _errorMessage ?? 'Impossible de charger les réservations.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.onSurface),
          ),
          const SizedBox(height: 8),
          TextButton(
            key: const ValueKey('reservations-retry'),
            onPressed: _loadReservations,
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}

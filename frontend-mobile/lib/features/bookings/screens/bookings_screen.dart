
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../models/booking.dart';
import 'booking_detail_screen.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  static const Color burgundy = AppTheme.burgundy;
  static const Color gold = AppTheme.gold;
  static const Color cream = AppTheme.cream;
  static const Color ink = AppTheme.ink;

  String selectedFilter = 'Toutes';

  final List<Booking> bookings = const [
    Booking(
      id: 'CS-1001',
      name: 'Panier surprise',
      restaurant: 'Cafétéria ESSECT',
      image:
      'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=600',
      price: 5,
      oldPrice: 12,
      quantity: 1,
      date: 'Aujourd’hui, 12:30',
      pickup: 'À récupérer sur place',
      address: 'Campus ESSECT, Avenue de la Liberté, Tunis',
      instructions: 'Présente le code de retrait au comptoir de la cafétéria.',
      status: 'En préparation',
      pickupCode: 'DEMO-482731',
    ),
    Booking(
      id: 'CS-1002',
      name: 'Sandwich poulet',
      restaurant: 'Snack Campus',
      image:
      'https://images.unsplash.com/photo-1553909489-cd47e0ef937f?w=600',
      price: 3.5,
      oldPrice: 7,
      quantity: 2,
      date: 'Aujourd’hui, 18:00',
      pickup: 'À récupérer sur place',
      address: 'Snack Campus, Avenue Hédi Nouira, Tunis',
      instructions: 'Retire ta commande directement au comptoir.',
      status: 'En cours',
      pickupCode: 'DEMO-915204',
    ),
    Booking(
      id: 'CS-1003',
      name: 'Croissants',
      restaurant: 'Boulangerie Campus',
      image:
      'https://images.unsplash.com/photo-1555507036-ab1f4038808a?w=600',
      price: 4,
      oldPrice: 9,
      quantity: 1,
      date: 'Hier, 09:00',
      pickup: 'Récupérée',
      address: 'Boulangerie Campus, Rue de Marseille, Tunis',
      instructions: 'Cette réservation a déjà été récupérée.',
      status: 'Terminée',
    ),
    Booking(
      id: 'CS-1004',
      name: 'Pâtisseries du jour',
      restaurant: 'Boulangerie Campus',
      image:
      'https://images.unsplash.com/photo-1488477181946-6428a0291777?w=600',
      price: 4,
      oldPrice: 9,
      quantity: 2,
      date: '10 janv., 16:00',
      pickup: 'Commande annulée',
      address: 'Boulangerie Campus, Rue de Marseille, Tunis',
      instructions: 'Cette réservation a été annulée.',
      status: 'Annulée',
    ),
  ];

  List<Booking> get filteredBookings {
    if (selectedFilter == 'Toutes') return bookings;

    if (selectedFilter == 'En cours') {
      return bookings
          .where(
            (b) =>
        b.status == 'En cours' ||
            b.status == 'En préparation',
      )
          .toList();
    }

    if (selectedFilter == 'Terminées') {
      return bookings.where((b) => b.status == 'Terminée').toList();
    }

    return bookings.where((b) => b.status == 'Annulée').toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('bookings-screen'),
      backgroundColor: cream,
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
                  if (filteredBookings.isEmpty)
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
          colors: [
            Color(0xFF780000),
            Color(0xFFAA0000),
            Color(0xFF8F0401),
          ],
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
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
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
                          content: Text(
                            'Notifications bientôt disponibles',
                          ),
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
                    child: CircleAvatar(
                      radius: 4,
                      backgroundColor: gold,
                    ),
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
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                      ),
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
      ('En cours', Icons.access_time_rounded),
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
                  color: selected ? burgundy : Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: burgundy.withValues(alpha: 0.08),
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
                      color: selected ? Colors.white : ink,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      filter.$1,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: selected ? Colors.white : ink,
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
    final statusColor = _statusColor(booking.status);
    final statusBackground = _statusBackground(booking.status);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      elevation: 0,
      child: InkWell(
        key: ValueKey('booking-card-${booking.id}'),
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => BookingDetailScreen(booking: booking),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: burgundy.withValues(alpha: 0.07),
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
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.network(
                      booking.image,
                      width: 94,
                      height: 105,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 94,
                        height: 105,
                        color: cream,
                        child: const Icon(
                          Icons.restaurant_rounded,
                          color: burgundy,
                          size: 36,
                        ),
                      ),
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
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: ink,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          booking.restaurant,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF766B66),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 9,
                          children: [
                            Text(
                              '${booking.price.toStringAsFixed(2)} DT',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: burgundy,
                              ),
                            ),
                            Text(
                              '${booking.oldPrice.toStringAsFixed(2)} DT',
                              style: const TextStyle(
                                decoration: TextDecoration.lineThrough,
                                color: Colors.grey,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 9),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: statusBackground,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _statusIcon(booking.status),
                                size: 14,
                                color: statusColor,
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  booking.status,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: ink,
                    size: 24,
                  ),
                ],
              ),
              const SizedBox(height: 13),
              const Divider(
                height: 1,
                color: Color(0xFFF0E8E0),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_month_outlined,
                    size: 17,
                    color: ink,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      booking.date,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF645954),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.shopping_bag_outlined,
                    size: 17,
                    color: ink,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      booking.pickup,
                      maxLines: 2,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF645954),
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

  Color _statusColor(String status) {
    switch (status) {
      case 'En préparation':
        return const Color(0xFF14752A);
      case 'En cours':
        return const Color(0xFFE07800);
      case 'Terminée':
        return const Color(0xFF14752A);
      case 'Annulée':
        return const Color(0xFFC50000);
      default:
        return ink;
    }
  }

  Color _statusBackground(String status) {
    switch (status) {
      case 'En préparation':
      case 'Terminée':
        return const Color(0xFFE5F5D8);
      case 'En cours':
        return const Color(0xFFFFF0C7);
      case 'Annulée':
        return const Color(0xFFFFDEDE);
      default:
        return cream;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'En préparation':
      case 'En cours':
        return Icons.access_time_rounded;
      case 'Terminée':
        return Icons.check_circle_rounded;
      case 'Annulée':
        return Icons.cancel_rounded;
      default:
        return Icons.info_outline;
    }
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 65,
            color: burgundy.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 15),
          const Text(
            'Aucune réservation trouvée',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: ink,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tes réservations apparaîtront ici.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

}

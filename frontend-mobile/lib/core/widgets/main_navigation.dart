import 'package:material_ui/material_ui.dart';

import '../../features/bookings/screens/bookings_screen.dart';
import '../../features/bookings/data/reservation_repository.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/search/screens/search_screen.dart';
import '../../features/search/data/shop_repository.dart';
import '../theme/app_theme.dart';
import '../network/auth_repository.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({
    super.key,
    this.authRepository,
    this.offersRepository,
    this.reservationRepository,
  });

  final AuthRepository? authRepository;
  final ShopRepository? offersRepository;
  final ReservationRepository? reservationRepository;

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  late final AuthRepository _authRepository =
      widget.authRepository ?? AuthRepository();
  late final ShopRepository _offersRepository =
      widget.offersRepository ??
      ShopRepository(authRepository: _authRepository);
  late final ReservationRepository _reservationRepository =
      widget.reservationRepository ??
      ReservationRepository(authRepository: _authRepository);

  static const List<_NavigationItemData> _items = [
    _NavigationItemData(
      key: 'home',
      label: 'Accueil',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    _NavigationItemData(
      key: 'search',
      label: 'Recherche',
      icon: Icons.search_rounded,
      selectedIcon: Icons.search_rounded,
    ),
    _NavigationItemData(
      key: 'bookings',
      label: 'Réservations',
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long_rounded,
    ),
    _NavigationItemData(
      key: 'profile',
      label: 'Profil',
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      HomeScreen(repository: _offersRepository),
      SearchScreen(repository: _offersRepository),
      BookingsScreen(repository: _reservationRepository),
      ProfileScreen(authRepository: _authRepository),
    ];
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: SafeArea(
        top: false,
        child: SizedBox(
          height: 94,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Align(
              alignment: Alignment.center,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Container(
                  key: const ValueKey('main-navigation-bar'),
                  height: 74,
                  decoration: BoxDecoration(
                    color: AppTheme.burgundy,
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.ink.withValues(alpha: 0.22),
                        blurRadius: 22,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(40),
                    child: Row(
                      children: List.generate(_items.length, (index) {
                        final item = _items[index];
                        return Expanded(
                          child: _NavigationItem(
                            key: ValueKey('navigation-${item.key}'),
                            item: item,
                            selected: _selectedIndex == index,
                            onTap: () => setState(() => _selectedIndex = index),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationItemData {
  const _NavigationItemData({
    required this.key,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String key;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.item,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final _NavigationItemData item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: item.label,
      button: true,
      selected: selected,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(32),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    width: selected ? 18 : 0,
                    height: 3,
                    decoration: BoxDecoration(
                      color: AppTheme.gold,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Icon(
                    selected ? item.selectedIcon : item.icon,
                    color: Colors.white,
                    size: 23,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: selected ? AppTheme.gold : Colors.white,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

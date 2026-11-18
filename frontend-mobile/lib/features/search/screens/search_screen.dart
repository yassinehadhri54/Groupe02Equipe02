
import 'package:material_ui/material_ui.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const burgundy = Color(0xFF8F0401);
  static const darkRed = Color(0xFF690000);
  static const cream = Color(0xFFFFF7F0);
  static const ink = Color(0xFF292323);

  final _searchController = TextEditingController();

  String _query = '';
  String _category = 'Tous';
  bool _openOnly = false;
  bool _sortByRating = false;

  static const _categories = [
    'Tous',
    'Cafétérias',
    'Snacks',
    'Boulangeries',
  ];

  static const List<_Restaurant> _restaurants = [
    _Restaurant(
      name: 'Cafétéria ESSECT',
      type: 'Cafétéria',
      category: 'Cafétérias',
      distance: 150,
      rating: 4.8,
      reviews: 127,
      open: true,
      image:
      'https://images.unsplash.com/photo-1552566626-52f8b828add9?w=800',
      description:
      'Découvre les repas, paniers et invendus proposés par la cafétéria du campus.',
    ),
    _Restaurant(
      name: 'Snack Campus',
      type: 'Snack',
      category: 'Snacks',
      distance: 320,
      rating: 4.6,
      reviews: 89,
      open: true,
      image:
      'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=800',
      description:
      'Sandwichs, repas rapides et offres anti-gaspillage à petit prix.',
    ),
    _Restaurant(
      name: 'Boulangerie Campus',
      type: 'Boulangerie',
      category: 'Boulangeries',
      distance: 450,
      rating: 4.9,
      reviews: 54,
      open: false,
      image:
      'https://images.unsplash.com/photo-1608198093002-ad4e005484df?w=800',
      description:
      'Pains, viennoiseries et pâtisseries du jour à prix réduits.',
    ),
  ];

  List<_Restaurant> get _results {
    final normalized = _query.trim().toLowerCase();

    final result = _restaurants.where((restaurant) {
      final matchesText =
      '${restaurant.name} ${restaurant.type} ${restaurant.description}'
          .toLowerCase()
          .contains(normalized);

      final matchesCategory = _category == 'Tous' ||
          restaurant.category == _category;

      return matchesText &&
          matchesCategory &&
          (!_openOnly || restaurant.open);
    }).toList();

    if (_sortByRating) {
      result.sort((a, b) => b.rating.compareTo(a.rating));
    } else {
      result.sort((a, b) => a.distance.compareTo(b.distance));
    }

    return result;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _selectCategory(String category) {
    setState(() => _category = category);
  }

  void _showFilters() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: cream,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, updateSheet) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filtrer les restaurants',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SwitchListTile(
                      title: const Text('Ouverts uniquement'),
                      subtitle: const Text(
                        'Afficher les commerces ouverts',
                      ),
                      activeThumbColor: burgundy,
                      value: _openOnly,
                      onChanged: (value) {
                        updateSheet(() {
                          setState(() => _openOnly = value);
                        });
                      },
                    ),
                    SwitchListTile(
                      title: const Text('Meilleures notes'),
                      subtitle: const Text(
                        'Trier par note décroissante',
                      ),
                      activeThumbColor: burgundy,
                      value: _sortByRating,
                      onChanged: (value) {
                        updateSheet(() {
                          setState(() => _sortByRating = value);
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: burgundy,
                          foregroundColor: Colors.white,
                          shape: const StadiumBorder(),
                        ),
                        child: const Text(
                          'Afficher les résultats',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openRestaurant(_Restaurant restaurant) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _RestaurantDetailScreen(
          restaurant: restaurant,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;

    return Scaffold(
      key: const ValueKey('search-screen'),
      backgroundColor: cream,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 650),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 25, 18, 125),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildIntroduction(),
                          const SizedBox(height: 25),
                          _buildSearchBar(),
                          const SizedBox(height: 22),
                          _buildCategories(),
                          const SizedBox(height: 30),
                          _buildSectionTitle(results.length),
                          const SizedBox(height: 16),
                          if (results.isEmpty)
                            _buildEmptyState()
                          else
                            ...results.map(
                                  (restaurant) => Padding(
                                padding:
                                const EdgeInsets.only(bottom: 14),
                                child: _buildRestaurantCard(restaurant),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 185,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFB00000), darkRed],
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.elliptical(220, 48),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 35),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Retour',
                onPressed: () {
                  final navigator = Navigator.of(context);
                  if (navigator.canPop()) {
                    navigator.pop();
                  }
                },
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                  size: 29,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Recherche',
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntroduction() {
    return Row(
      children: [
        Expanded(
          flex: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: 'Trouve un '),
                    TextSpan(
                      text: 'restaurant',
                      style: TextStyle(color: burgundy),
                    ),
                    TextSpan(text: '\nsur ton campus'),
                  ],
                ),
                style: TextStyle(
                  fontSize: 24,
                  height: 1.22,
                  fontWeight: FontWeight.w900,
                  color: ink,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Recherche une cafétéria, un snack ou une boulangerie près de toi.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: ink.withValues(alpha: 0.68),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 4,
          child: Container(
            height: 150,
            decoration: const BoxDecoration(
              color: Color(0xFFFCE3D9),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: _ShopIllustration(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(35),
              boxShadow: [
                BoxShadow(
                  color: burgundy.withValues(alpha: 0.11),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: TextField(
              key: const ValueKey('restaurant-search-field'),
              controller: _searchController,
              onChanged: (value) {
                setState(() => _query = value);
              },
              style: const TextStyle(
                color: ink,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'Rechercher un restaurant...',
                hintStyle: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF918984),
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: burgundy,
                  size: 28,
                ),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                  tooltip: 'Effacer',
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                  icon: const Icon(Icons.close_rounded),
                )
                    : null,
                filled: true,
                fillColor: Colors.transparent,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(35),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(35),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(35),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                const EdgeInsets.symmetric(vertical: 18),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Material(
          color: Colors.white,
          elevation: 3,
          shadowColor: burgundy.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: _showFilters,
            borderRadius: BorderRadius.circular(24),
            child: const SizedBox(
              width: 58,
              height: 58,
              child: Icon(
                Icons.tune_rounded,
                color: burgundy,
                size: 28,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategories() {
    const icons = [
      Icons.restaurant_rounded,
      Icons.local_cafe_outlined,
      Icons.lunch_dining_outlined,
      Icons.bakery_dining_outlined,
    ];

    return Row(
      children: List.generate(_categories.length, (index) {
        final category = _categories[index];
        final selected = _category == category;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              decoration: BoxDecoration(
                color: selected ? burgundy : Colors.white,
                borderRadius: BorderRadius.circular(23),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(23),
                  onTap: () => _selectCategory(category),
                  child: SizedBox(
                    height: 92,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            icons[index],
                            size: 28,
                            color: selected
                                ? Colors.white
                                : const Color(0xFFE36B10),
                          ),
                          const SizedBox(height: 9),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              category,
                              maxLines: 1,
                              style: TextStyle(
                                color: selected ? Colors.white : ink,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSectionTitle(int count) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Restaurants à proximité',
            style: TextStyle(
              color: ink,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 5),
        PopupMenuButton<String>(
          tooltip: 'Trier les restaurants',
          onSelected: (value) {
            setState(() => _sortByRating = value == 'rating');
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'distance',
              child: Text('Distance'),
            ),
            PopupMenuItem(
              value: 'rating',
              child: Text('Meilleures notes'),
            ),
          ],
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.location_on_outlined,
                color: burgundy,
                size: 18,
              ),
              const SizedBox(width: 3),
              Text(
                _sortByRating ? 'Mieux notés' : 'Près de toi',
                style: const TextStyle(
                  color: burgundy,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: burgundy,
                size: 17,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRestaurantCard(_Restaurant restaurant) {
    return Material(
      color: Colors.white,
      elevation: 3,
      shadowColor: burgundy.withValues(alpha: 0.11),
      borderRadius: BorderRadius.circular(23),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openRestaurant(restaurant),
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(17),
                child: SizedBox(
                  width: 103,
                  height: 105,
                  child: Image.network(
                    restaurant.image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: const Color(0xFFF3E8DD),
                      child: const Icon(
                        Icons.storefront_rounded,
                        size: 42,
                        color: burgundy,
                      ),
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
                      restaurant.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${restaurant.type} • ${restaurant.distance} m',
                      style: const TextStyle(
                        color: Color(0xFF746B66),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 11),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFFFBC17),
                          size: 21,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          restaurant.rating.toStringAsFixed(1)
                              .replaceAll('.', ','),
                          style: const TextStyle(
                            color: burgundy,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '(${restaurant.reviews})',
                            style: const TextStyle(
                              color: Color(0xFF746B66),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: restaurant.open
                          ? const Color(0xFFE4F4DC)
                          : const Color(0xFFFFE8D2),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      restaurant.open ? 'Ouvert' : 'Fermé',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: restaurant.open
                            ? const Color(0xFF24752C)
                            : const Color(0xFFBC5A00),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF77675F),
                    size: 25,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 45),
        child: Column(
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 65,
              color: burgundy,
            ),
            const SizedBox(height: 15),
            const Text(
              'Aucun restaurant trouvé',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Essaie une autre recherche ou catégorie.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            TextButton(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _query = '';
                  _category = 'Tous';
                  _openOnly = false;
                });
              },
              child: const Text(
                'Réinitialiser',
                style: TextStyle(color: burgundy),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopIllustration extends StatelessWidget {
  const _ShopIllustration();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth.clamp(70.0, 145.0);

        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                top: size * 0.27,
                child: Container(
                  width: size * 0.74,
                  height: size * 0.53,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC98E),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              Positioned(
                top: size * 0.17,
                child: Container(
                  width: size * 0.92,
                  height: size * 0.23,
                  decoration: BoxDecoration(
                    color: const Color(0xFFB70B0B),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: List.generate(
                      5,
                          (index) => Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: index.isEven
                                ? const Color(0xFFFFF4E8)
                                : const Color(0xFFB70B0B),
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: size * 0.44,
                left: size * 0.24,
                child: Container(
                  width: size * 0.27,
                  height: size * 0.23,
                  decoration: BoxDecoration(
                    color: const Color(0xFF75C8DE),
                    border: Border.all(
                      color: const Color(0xFFB97C4E),
                      width: 3,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: size * 0.44,
                right: size * 0.18,
                child: Container(
                  width: size * 0.15,
                  height: size * 0.36,
                  color: const Color(0xFF9B2820),
                ),
              ),
              Positioned(
                top: 0,
                child: Container(
                  width: size * 0.34,
                  height: size * 0.34,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE67A26),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.restaurant_rounded,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Restaurant {
  const _Restaurant({
    required this.name,
    required this.type,
    required this.category,
    required this.distance,
    required this.rating,
    required this.reviews,
    required this.open,
    required this.image,
    required this.description,
  });

  final String name;
  final String type;
  final String category;
  final int distance;
  final double rating;
  final int reviews;
  final bool open;
  final String image;
  final String description;
}

class _RestaurantDetailScreen extends StatelessWidget {
  const _RestaurantDetailScreen({
    required this.restaurant,
  });

  final _Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7F0),
      appBar: AppBar(
        title: Text(restaurant.name),
        backgroundColor: const Color(0xFF8F0401),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.network(
              restaurant.image,
              height: 220,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox(
                height: 220,
                child: Center(
                  child: Icon(Icons.storefront, size: 70),
                ),
              ),
            ),
          ),
          const SizedBox(height: 25),
          Text(
            restaurant.name,
            style: const TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${restaurant.type} • ${restaurant.distance} m (distance de démonstration)',
            style: const TextStyle(
              color: Color(0xFF756B66),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            restaurant.description,
            style: const TextStyle(
              fontSize: 16,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 25),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Les offres de ce commerce seront affichées ici après la connexion au backend CampusSave.',
              style: TextStyle(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

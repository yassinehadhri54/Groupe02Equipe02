import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../offers/models/food_offer.dart';
import '../../offers/screens/offer_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color burgundy = Color(0xFF8F0401);
  static const Color gold = Color(0xFFDCA321);
  static const Color cream = Color(0xFFFFF6EE);
  static const Color ink = Color(0xFF292323);

  final TextEditingController _searchController = TextEditingController();
  final PageController _bannerController = PageController();

  String _searchQuery = '';
  String _selectedCategory = 'Toutes';
  int _bannerIndex = 0;

  static const List<String> _categories = [
    'Toutes',
    'Paniers',
    'Sandwichs',
    'Pâtisseries',
  ];

  static const List<FoodOffer> _offers = [
    FoodOffer(
      name: 'Panier surprise',
      shop: 'Cafétéria ESSECT',
      imageUrl:
          'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=1200',
      price: 5,
      oldPrice: 12,
      category: 'Paniers',
      description: 'Un assortiment de produits frais sélectionnés par la cafétéria, proposé à prix réduit pour éviter le gaspillage.',
    ),
    FoodOffer(
      name: 'Sandwich frais',
      shop: 'Snack Campus',
      imageUrl:
          'https://images.unsplash.com/photo-1553909489-cd47e0ef937f?w=1200',
      price: 3.5,
      oldPrice: 7,
      category: 'Sandwichs',
      description:
          'Un sandwich préparé le jour même avec des ingrédients frais.',
    ),
    FoodOffer(
      name: 'Pâtisseries du jour',
      shop: 'Boulangerie Campus',
      imageUrl:
          'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=1200',
      price: 4,
      oldPrice: 9,
      category: 'Pâtisseries',
      description: 'Une sélection de pâtisseries préparées dans la journée et disponibles à tarif réduit.',
    ),
  ];

  List<FoodOffer> get _filteredOffers {
    return _offers.where((offer) {
      final matchesCategory =
          _selectedCategory == 'Toutes' || offer.category == _selectedCategory;

      final searchText = '${offer.name} ${offer.shop} ${offer.category}'
          .toLowerCase();

      return matchesCategory &&
          searchText.contains(_searchQuery.trim().toLowerCase());
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _bannerController.dispose();
    super.dispose();
  }

  void _selectCategory(String category) {
    setState(() {
      _selectedCategory = category;
    });
  }

  void _openOffer(FoodOffer offer) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => OfferDetailScreen(offer: offer)),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final offers = _filteredOffers;

    return Scaffold(
      key: const ValueKey('home-screen'),
      backgroundColor: cream,
      body: CustomScrollView(
        key: const ValueKey('home-scroll'),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 650),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 22, 16, 125),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _animate(_buildPromoCarousel(), 0),
                      const SizedBox(height: 24),
                      _animate(_buildCategoryShortcuts(), 100),
                      const SizedBox(height: 30),
                      _animate(_buildCategoryFilters(), 180),
                      const SizedBox(height: 30),
                      _animate(_buildOffers(offers), 250),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _animate(Widget child, int delay) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 650 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, animatedChild) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - value)),
            child: animatedChild,
          ),
        );
      },
      child: child,
    );
  }

  Widget _buildHeader() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFA40000), Color(0xFF690000)],
          ),
        ),
        child: Stack(
          children: [
            const Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _HomeHeaderWavePainter()),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: const Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Campus',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  TextSpan(
                                    text: 'Save',
                                    style: TextStyle(color: gold),
                                  ),
                                  TextSpan(
                                    text: ' 🌱',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1.2,
                              ),
                            ),
                          ),
                        ),
                        Stack(
                          children: [
                            IconButton(
                              tooltip: 'Notifications',
                              onPressed: () => _showMessage(
                                'Notifications bientôt disponibles.',
                              ),
                              icon: const Icon(
                                Icons.notifications_none_rounded,
                                color: Colors.white,
                                size: 29,
                              ),
                            ),
                            Positioned(
                              right: 10,
                              top: 8,
                              child: Container(
                                width: 9,
                                height: 9,
                                decoration: const BoxDecoration(
                                  color: gold,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 56,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.13),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(30),
                              child: TextField(
                                key: const ValueKey('offer-search-field'),
                                controller: _searchController,
                                onChanged: (value) {
                                  setState(() => _searchQuery = value);
                                },
                                cursorColor: burgundy,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: ink,
                                ),
                                decoration: InputDecoration(
                                  filled: false,
                                  fillColor: Colors.transparent,
                                  hintText:
                                      'Rechercher un repas, un commerce...',
                                  hintStyle: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF77716E),
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.search_rounded,
                                    color: burgundy,
                                    size: 25,
                                  ),
                                  suffixIcon: _searchQuery.isEmpty
                                      ? null
                                      : IconButton(
                                          tooltip: 'Effacer la recherche',
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() => _searchQuery = '');
                                          },
                                          icon: const Icon(Icons.close),
                                        ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(23),
                          elevation: 2,
                          shadowColor: Colors.black.withValues(alpha: 0.12),
                          child: InkWell(
                            key: const ValueKey('header-filter-button'),
                            borderRadius: BorderRadius.circular(23),
                            onTap: _showFilterSheet,
                            child: const SizedBox(
                              height: 56,
                              width: 56,
                              child: Icon(
                                Icons.tune_rounded,
                                color: burgundy,
                                size: 27,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromoCarousel() {
    final compact = MediaQuery.sizeOf(context).width < 380;
    const titles = [
      'Mange bien,\ngaspille moins ! 🌍',
      'Des paniers\nà petit prix !',
      'Une pause\ngourmande !',
    ];
    const subtitles = [
      "Jusqu'à -60% sur des repas près de ton campus.",
      'Découvre les invendus de ton campus.',
      'Des repas savoureux à prix réduits.',
    ];
    const labels = ['Offre du jour', 'Anti-gaspillage', 'À découvrir'];
    const imageUrls = [
      'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=800',
      'https://images.unsplash.com/photo-1542838132-92c53300491e?w=800',
      'https://images.unsplash.com/photo-1553909489-cd47e0ef937f?w=800',
    ];
    const fallbackImages = ['🥗', '🛍️', '🥪'];

    return Column(
      children: [
        SizedBox(
          height: 280,
          child: PageView.builder(
            key: const ValueKey('promo-carousel'),
            controller: _bannerController,
            itemCount: 3,
            onPageChanged: (index) {
              setState(() => _bannerIndex = index);
            },
            itemBuilder: (context, index) => _PromoBanner(
              key: ValueKey('promo-banner-$index'),
              title: titles[index],
              subtitle: subtitles[index],
              label: labels[index],
              imageUrl: imageUrls[index],
              fallbackImage: fallbackImages[index],
              compact: compact,
              onDiscover: () {
                _selectCategory('Toutes');
                _showMessage('Découvre les offres disponibles ci-dessous.');
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            3,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 8,
              width: _bannerIndex == index ? 24 : 8,
              decoration: BoxDecoration(
                color: _bannerIndex == index
                    ? burgundy
                    : const Color(0xFFE1D6CE),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryShortcuts() {
    const items = [
      ('Paniers', Icons.shopping_basket_outlined, burgundy),
      ('Sandwichs', Icons.lunch_dining_outlined, Color(0xFFDF6514)),
      ('Pâtisseries', Icons.cake_outlined, burgundy),
      ('Boissons', Icons.local_drink_outlined, Color(0xFF348A31)),
    ];

    return Row(
      children: items.map((item) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Material(
              color: Colors.white,
              elevation: 2,
              shadowColor: Colors.black.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(22),
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () {
                  if (item.$1 == 'Boissons') {
                    _showMessage('Aucune boisson disponible actuellement.');
                  } else {
                    _selectCategory(item.$1);
                  }
                },
                child: SizedBox(
                  height: 105,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(item.$2, color: item.$3, size: 33),
                      const SizedBox(height: 10),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          item.$1,
                          style: const TextStyle(
                            color: ink,
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
        );
      }).toList(),
    );
  }

  Widget _buildCategoryFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Catégories',
                style: TextStyle(
                  color: ink,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            TextButton(
              onPressed: () => _selectCategory('Toutes'),
              child: const Text(
                'Voir tout →',
                style: TextStyle(color: burgundy, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 9),
            itemBuilder: (context, index) {
              final category = _categories[index];
              final selected = category == _selectedCategory;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                decoration: BoxDecoration(
                  color: selected ? burgundy : Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.07),
                      blurRadius: 9,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: InkWell(
                  key: ValueKey('category-filter-$category'),
                  borderRadius: BorderRadius.circular(30),
                  onTap: () => _selectCategory(category),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 17),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (selected) ...[
                          const Icon(Icons.check, size: 17, color: gold),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          category,
                          style: TextStyle(
                            color: selected ? Colors.white : ink,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOffers(List<FoodOffer> offers) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Offres disponibles',
                style: TextStyle(
                  color: burgundy,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              '${offers.length} offres',
              style: const TextStyle(color: Color(0xFF77716E), fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 17),
        if (offers.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 35),
            child: Center(child: Text('Aucune offre trouvée.')),
          )
        else
          SizedBox(
            height: 310,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: offers.length,
              separatorBuilder: (_, _) => const SizedBox(width: 15),
              itemBuilder: (context, index) {
                final offer = offers[index];

                return SizedBox(
                  width: 250,
                  child: _HomeOfferCard(
                    key: ValueKey('offer-card-${offer.name}'),
                    offer: offer,
                    onTap: () => _openOffer(offer),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: cream,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filtrer les offres',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 15),
              ..._categories.map(
                (category) => ListTile(
                  title: Text(category),
                  leading: Icon(
                    category == _selectedCategory
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: burgundy,
                  ),
                  onTap: () {
                    _selectCategory(category);
                    Navigator.pop(sheetContext);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeOfferCard extends StatefulWidget {
  const _HomeOfferCard({super.key, required this.offer, required this.onTap});

  final FoodOffer offer;
  final VoidCallback onTap;

  @override
  State<_HomeOfferCard> createState() => _HomeOfferCardState();
}

class _HomeOfferCardState extends State<_HomeOfferCard> {
  bool _favorite = false;

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;

    final discount = offer.oldPrice > 0
        ? ((1 - offer.price / offer.oldPrice) * 100).round().clamp(0, 100)
        : 0;

    return Material(
      color: Colors.white,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(23),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 170,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    offer.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const ColoredBox(
                      color: Color(0xFFF1E6DC),
                      child: Center(
                        child: Icon(
                          Icons.restaurant_rounded,
                          size: 45,
                          color: Color(0xFF8F0401),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFB00000),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Text(
                        '-$discount%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 7,
                    left: 7,
                    child: IconButton(
                      tooltip: _favorite
                          ? 'Retirer des favoris'
                          : 'Ajouter aux favoris',
                      onPressed: () {
                        setState(() => _favorite = !_favorite);
                      },
                      icon: Icon(
                        _favorite ? Icons.favorite : Icons.favorite_border,
                        color: _favorite ? Colors.redAccent : Colors.white,
                        size: 27,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offer.category.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFFDC7C00),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      offer.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF292323),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      offer.shop,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF77716E),
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Text(
                          '${offer.price.toStringAsFixed(2)} DT',
                          style: const TextStyle(
                            color: Color(0xFF8F0401),
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          offer.oldPrice.toStringAsFixed(2),
                          style: const TextStyle(
                            color: Color(0xFF99908B),
                            fontSize: 11,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromoBanner extends StatelessWidget {
  const _PromoBanner({
    required this.title,
    required this.subtitle,
    required this.label,
    required this.imageUrl,
    required this.fallbackImage,
    required this.compact,
    required this.onDiscover,
    super.key,
  });

  final String title;
  final String subtitle;
  final String label;
  final String imageUrl;
  final String fallbackImage;
  final bool compact;
  final VoidCallback onDiscover;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF720000), Color(0xFFB4110B), Color(0xFF9C0804)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.burgundy.withValues(alpha: 0.19),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _PromoBackgroundPainter()),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(compact ? 16 : 21),
            child: Row(
              children: [
                Expanded(
                  flex: 58,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD45A),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Text(
                              '💡 $label',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppTheme.burgundy,
                                fontWeight: FontWeight.w800,
                                fontSize: compact ? 11 : 12,
                              ),
                            ),
                          ),
                          SizedBox(height: compact ? 8 : 11),
                          Text(
                            title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: compact ? 20 : 24,
                              height: 1.08,
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.92),
                              fontSize: compact ? 11 : 13,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                      _PromoDiscoverButton(onPressed: onDiscover),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 42,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final diameter =
                          constraints.maxWidth < constraints.maxHeight
                          ? constraints.maxWidth
                          : constraints.maxHeight;

                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: diameter,
                            height: diameter,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(
                            width: diameter,
                            height: diameter,
                            child: ClipOval(
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return ColoredBox(
                                        color: const Color(0xFFF2E6D8),
                                        child: Center(
                                          child: Text(
                                            fallbackImage,
                                            style: TextStyle(
                                              fontSize: diameter * 0.48,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  const DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: RadialGradient(
                                        colors: [
                                          Colors.transparent,
                                          Color(0x28720000),
                                        ],
                                        stops: [0.62, 1],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            top: diameter * 0.08,
                            right: diameter * 0.08,
                            child: Icon(
                              Icons.auto_awesome_rounded,
                              size: compact ? 16 : 20,
                              color: const Color(0xFFFFD45A),
                            ),
                          ),
                          Positioned(
                            bottom: diameter * 0.12,
                            left: diameter * 0.06,
                            child: Container(
                              width: compact ? 7 : 9,
                              height: compact ? 7 : 9,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFFD45A),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PromoDiscoverButton extends StatefulWidget {
  const _PromoDiscoverButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_PromoDiscoverButton> createState() => _PromoDiscoverButtonState();
}

class _PromoDiscoverButtonState extends State<_PromoDiscoverButton> {
  bool _pressed = false;

  void _setPressed(bool pressed) {
    if (_pressed != pressed) {
      setState(() => _pressed = pressed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: ElevatedButton.icon(
          onPressed: widget.onPressed,
          iconAlignment: IconAlignment.end,
          icon: const Icon(Icons.arrow_forward_rounded, size: 17),
          label: const Text('Découvrir'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFC83D),
            foregroundColor: AppTheme.burgundy,
            elevation: 0,
            minimumSize: const Size(0, 40),
            visualDensity: VisualDensity.compact,
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 15),
            shape: const StadiumBorder(),
          ),
        ),
      ),
    );
  }
}

class _HomeHeaderWavePainter extends CustomPainter {
  const _HomeHeaderWavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height * 0.48)
      ..cubicTo(
        size.width * 0.24,
        size.height * 0.26,
        size.width * 0.46,
        size.height * 0.88,
        size.width * 0.70,
        size.height * 0.55,
      )
      ..cubicTo(
        size.width * 0.84,
        size.height * 0.34,
        size.width * 0.93,
        size.height * 0.44,
        size.width,
        size.height * 0.30,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = Colors.white.withValues(alpha: 0.045),
    );
  }

  @override
  bool shouldRepaint(covariant _HomeHeaderWavePainter oldDelegate) => false;
}

class _PromoBackgroundPainter extends CustomPainter {
  const _PromoBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.035);
    canvas.drawCircle(
      Offset(size.width * 0.84, size.height * 0.15),
      size.height * 0.38,
      paint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.78, size.height * 0.85),
      size.height * 0.22,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _PromoBackgroundPainter oldDelegate) => false;
}

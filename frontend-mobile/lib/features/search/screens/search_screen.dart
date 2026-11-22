
import '../../../core/network/auth_repository.dart';
import 'package:material_ui/material_ui.dart';
import '../../offers/screens/offer_detail_screen.dart';
import '../data/shop_repository.dart';
import '../models/shop_offer.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.repository});

  final ShopRepository? repository;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const burgundy = Color(0xFF8F0401);
  static const darkRed = Color(0xFF690000);
  static const cream = Color(0xFFFFF7F0);
  static const ink = Color(0xFF292323);

  final _searchController = TextEditingController();
  final _maxPriceController = TextEditingController();
  late final ShopRepository _repository =
      widget.repository ??
      ShopRepository(authRepository: AuthRepository());

  String _query = '';
  String _category = 'Tous';
  double? _maxPrice;
  List<ShopOffer> _offers = const [];
  List<String> _categories = const ['Tous'];
  bool _isLoading = true;
  String? _errorMessage;

  List<ShopOffer> get _results {
    final normalized = _query.trim().toLowerCase();
    return _offers.where((offer) {
      final text =
          '${offer.name} ${offer.shopName ?? ''} ${offer.category ?? ''} '
                  '${offer.description ?? ''}'
              .toLowerCase();
      return text.contains(normalized) &&
          (_maxPrice == null ||
              (offer.discountPrice != null &&
                  offer.discountPrice! <= _maxPrice!));
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadOffers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  Future<void> _loadOffers({String? query}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final offers = await _repository.fetchOffers(
        category: _category == 'Tous' ? null : _category,
        maxPrice: _maxPrice,
        query: query ?? (_query.trim().isEmpty ? null : _query.trim()),
      );
      if (!mounted) return;
      final categories = <String>{
        ..._categories.skip(1),
        ...offers.map((offer) => offer.category).whereType<String>(),
      }.toList()..sort();
      setState(() {
        _offers = offers;
        _categories = ['Tous', ...categories];
      });
    } on ShopRepositoryException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  void _selectCategory(String category) {
    setState(() => _category = category);
    _loadOffers(query: _query);
  }

  void _showFilters() {
    _maxPriceController.text = _maxPrice?.toString() ?? '';
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
                      'Filtrer les offres',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      key: const ValueKey('offer-max-price'),
                      controller: _maxPriceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Prix maximum (DT)',
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          final input = _maxPriceController.text.trim();
                          final price = input.isEmpty
                              ? null
                              : double.tryParse(input.replaceAll(',', '.'));
                          if (input.isNotEmpty &&
                              (price == null || price < 0)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Saisis un prix valide.'),
                              ),
                            );
                            return;
                          }
                          setState(() => _maxPrice = price);
                          Navigator.pop(sheetContext);
                          _loadOffers(query: _query);
                        },
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

  void _openOffer(ShopOffer offer) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => OfferDetailScreen(
          offer: offer,
          repository: _repository,
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
                          if (_isLoading)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32),
                                child: CircularProgressIndicator(
                                  color: burgundy,
                                ),
                              ),
                            )
                          else if (_errorMessage != null)
                            _buildErrorState()
                          else if (results.isEmpty)
                            _buildEmptyState()
                          else
                            ...results.map(
                                  (offer) => Padding(
                                padding:
                                const EdgeInsets.only(bottom: 14),
                                child: _buildOfferCard(offer),
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
                    TextSpan(text: 'Trouve une '),
                    TextSpan(
                      text: 'offre',
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
                'Recherche des repas et produits réellement proposés près de toi.',
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
              onSubmitted: (value) => _loadOffers(query: value),
              textInputAction: TextInputAction.search,
              style: const TextStyle(
                color: ink,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'Rechercher une offre alimentaire...',
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
                    _loadOffers(query: '');
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

    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final category = _categories[index];
          final selected = _category == category;

          return SizedBox(
            width: 88,
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          icons[index % icons.length],
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
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(int count) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Offres alimentaires',
            style: TextStyle(
              color: ink,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Text(
          '$count',
          style: const TextStyle(
            color: Color(0xFF746B66),
            fontSize: 12,
          ),
        ),
        const SizedBox(width: 5),
        PopupMenuButton<String>(
          tooltip: 'Filtrer les offres par prix',
          onSelected: (value) {
            if (value == 'price') _showFilters();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'price',
              child: Text('Prix maximum'),
            ),
          ],
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.tune_rounded,
                color: burgundy,
                size: 18,
              ),
              const SizedBox(width: 3),
              Text(
                _maxPrice == null
                    ? 'Filtres'
                    : '≤ ${_maxPrice!.toStringAsFixed(2)} DT',
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

  Widget _buildOfferCard(ShopOffer offer) {
    final price = offer.discountPrice;
    return Material(
      key: ValueKey('search-offer-${offer.id}'),
      color: Colors.white,
      elevation: 3,
      shadowColor: burgundy.withValues(alpha: 0.11),
      borderRadius: BorderRadius.circular(23),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openOffer(offer),
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(17),
                child: SizedBox(
                  width: 103,
                  height: 105,
                  child: offer.imageUrl == null
                      ? Container(
                      color: const Color(0xFFF3E8DD),
                      child: const Icon(
                        Icons.restaurant_rounded,
                        size: 42,
                        color: burgundy,
                      ),
                    )
                      : Image.network(
                          offer.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: const Color(0xFFF3E8DD),
                            child: const Icon(
                              Icons.restaurant_rounded,
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
                      offer.name,
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
                      [
                        if (offer.category != null) offer.category!,
                        if (offer.availableQuantity != null)
                          '${offer.availableQuantity} disponible(s)',
                      ].join(' • '),
                      style: const TextStyle(
                        color: Color(0xFF746B66),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 11),
                    if (offer.shopName != null)
                      Text(
                        offer.shopName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF746B66),
                          fontSize: 12,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      price == null
                          ? 'Prix indisponible'
                          : '${price.toStringAsFixed(3)} DT',
                      style: const TextStyle(
                        color: burgundy,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
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

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 35),
        child: Column(
          children: [
            Text(_errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton(
              key: const ValueKey('search-retry'),
              onPressed: () => _loadOffers(query: _query),
              child: const Text('Réessayer'),
            ),
          ],
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
              'Aucune offre alimentaire trouvée',
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
                  _maxPrice = null;
                  _maxPriceController.clear();
                });
                _loadOffers(query: '');
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

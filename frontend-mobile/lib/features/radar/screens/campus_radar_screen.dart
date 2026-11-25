import 'dart:async';
import 'dart:convert';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../../offers/screens/offer_detail_screen.dart';
import '../../search/data/shop_repository.dart';
import '../../search/models/shop_offer.dart';

typedef RadarLocation = Future<LatLng?> Function();

Future<LatLng?> readRadarLocation() async {
  const channel = MethodChannel('campussave/location');
  final coordinates = await channel.invokeListMethod<num>('currentPosition');
  if (coordinates == null || coordinates.length != 2) return null;
  return LatLng(coordinates[0].toDouble(), coordinates[1].toDouble());
}

class _RadarShop {
  const _RadarShop(
    this.id,
    this.name,
    this.address,
    this.position,
    this.meters,
  );
  final String id;
  final String name;
  final String address;
  final LatLng position;
  final int meters;

  static _RadarShop? decode(Object? item) {
    if (item is! Map<String, dynamic>) return null;
    final lat = item['latitude'];
    final lng = item['longitude'];
    final id = item['shopId'];
    final meters = item['distanceMeters'];
    if (id is! String ||
        id.isEmpty ||
        meters is! int ||
        meters < 0 ||
        lat is! num ||
        lng is! num ||
        !lat.isFinite ||
        !lng.isFinite ||
        lat.abs() > 90 ||
        lng.abs() > 180) {
      return null;
    }
    return _RadarShop(
      id,
      item['name']?.toString() ?? '',
      item['address']?.toString() ?? '',
      LatLng(lat.toDouble(), lng.toDouble()),
      meters,
    );
  }
}

class CampusRadarScreen extends StatefulWidget {
  const CampusRadarScreen({
    super.key,
    required this.repository,
    this.locate = readRadarLocation,
    this.showTiles = true,
  });

  final ShopRepository repository;
  final RadarLocation locate;
  final bool showTiles;

  @override
  State<CampusRadarScreen> createState() => _CampusRadarScreenState();
}

class _CampusRadarScreenState extends State<CampusRadarScreen> {
  // Initial viewport, not a shop or a device location.
  static const _initialCenter = LatLng(36.8065, 10.1815);
  static const _tileUrl = String.fromEnvironment(
    'CAMPUS_RADAR_TILE_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );

  final _map = MapController();
  late final _tiles = NetworkTileProvider(
    headers: {
      'User-Agent':
          'CampusSave/1.0 (+https://github.com/yassinehadhri54/CampusSave)',
    },
  );
  Future<List<_RadarShop>>? _shops;
  LatLng? _position;
  LatLng _center = _initialCenter;
  int _radius = 5;
  bool _locating = false;
  bool _searching = false;
  String? _message;

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  Future<List<_RadarShop>> _fetchShops(LatLng center, int radius) async {
    final response = await widget.repository.authRepository.getPublic(
      '/api/shops/nearby',
      queryParameters: {
        'lat': center.latitude.toString(),
        'lng': center.longitude.toString(),
        'radius': radius.toString(),
      },
    );
    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic> || body['data'] is! List) {
      throw const FormatException('Réponse Campus Radar invalide.');
    }
    return (body['data'] as List)
        .map(_RadarShop.decode)
        .whereType<_RadarShop>()
        .toList()
      ..sort((first, second) => first.meters.compareTo(second.meters));
  }

  Future<void> _search(LatLng center, {int? radius}) async {
    if (!mounted || _searching || _locating) return;
    final selectedRadius = radius ?? _radius;
    final shops = _fetchShops(center, selectedRadius);
    setState(() {
      _searching = true;
      _radius = selectedRadius;
      _center = center;
      _shops = shops;
    });
    try {
      await shops;
    } on Exception {
      // FutureBuilder displays the failed request.
    } finally {
      if (mounted) {
        setState(() {
          _searching = false;
        });
      }
    }
  }

  Future<void> _locate() async {
    if (_searching || _locating) return;
    setState(() {
      _locating = true;
      _message = null;
    });
    LatLng? position;
    try {
      position = await widget.locate();
    } on Exception {
      // Map search remains available when the device cannot provide a fix.
    }
    if (!mounted) return;
    setState(() {
      _locating = false;
      _position = position;
      _message = position == null
          ? 'Localisation indisponible. Déplace la carte puis recherche dans cette zone.'
          : null;
    });
    if (position != null) {
      _map.move(position, 14);
      _search(position);
    }
  }

  void _openShop(_RadarShop shop) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            _RadarShopOffers(shop: shop, repository: widget.repository),
      ),
    );
  }

  String _distance(int meters) =>
      meters < 1000 ? '$meters m' : '${(meters / 1000).toStringAsFixed(1)} km';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Campus Radar')),
      body: SafeArea(
        child: FutureBuilder<List<_RadarShop>>(
          future: _shops,
          builder: (context, snapshot) {
            final ready =
                snapshot.connectionState == ConnectionState.done &&
                !snapshot.hasError;
            final shops = ready
                ? snapshot.data ?? const <_RadarShop>[]
                : const <_RadarShop>[];
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    alignment: WrapAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _locating || _searching ? null : _locate,
                        icon: const Icon(Icons.my_location),
                        label: Text(
                          _locating ? 'Localisation…' : 'Ma position',
                        ),
                      ),
                      FilledButton.tonal(
                        onPressed: _locating || _searching
                            ? null
                            : () => _search(_map.camera.center),
                        child: const Text('Rechercher ici'),
                      ),
                      for (final radius in [1, 3, 5, 10])
                        ChoiceChip(
                          label: Text('$radius km'),
                          selected: _radius == radius,
                          onSelected: _locating || _searching
                              ? null
                              : (_) =>
                                    _search(_map.camera.center, radius: radius),
                        ),
                    ],
                  ),
                ),
                if (_message case final message?)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(message),
                  ),
                Expanded(
                  flex: 3,
                  child: FlutterMap(
                    mapController: _map,
                    options: MapOptions(
                      initialCenter: _initialCenter,
                      initialZoom: 12,
                      minZoom: 3,
                      maxZoom: 19,
                      backgroundColor: colors.surfaceContainer,
                    ),
                    children: [
                      if (widget.showTiles)
                        TileLayer(
                          urlTemplate: _tileUrl,
                          tileProvider: _tiles,
                          panBuffer: 0,
                        ),
                      MarkerLayer(
                        markers: [
                          if (_position case final position?)
                            Marker(
                              point: position,
                              child: Icon(
                                Icons.my_location,
                                color: colors.primary,
                              ),
                            ),
                          for (final shop in shops)
                            Marker(
                              point: shop.position,
                              width: 48,
                              height: 48,
                              child: IconButton.filled(
                                tooltip: shop.name,
                                icon: const Icon(Icons.storefront_outlined),
                                onPressed: () => _openShop(shop),
                              ),
                            ),
                        ],
                      ),
                      const SimpleAttributionWidget(
                        source: Text('OpenStreetMap contributors'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: switch (snapshot.connectionState) {
                    ConnectionState.none => const Center(
                      child: Text(
                        'Choisis ta position ou une zone sur la carte.',
                      ),
                    ),
                    ConnectionState.waiting || ConnectionState.active =>
                      const Center(child: CircularProgressIndicator()),
                    ConnectionState.done when snapshot.hasError => Center(
                      child: TextButton(
                        onPressed: _locating || _searching
                            ? null
                            : () => _search(_center),
                        child: const Text('Chargement impossible · Réessayer'),
                      ),
                    ),
                    ConnectionState.done when shops.isEmpty => const Center(
                      child: Text('Aucun commerce localisé dans ce rayon.'),
                    ),
                    _ => ListView.builder(
                      itemCount: shops.length,
                      itemBuilder: (context, index) {
                        final shop = shops[index];
                        return ListTile(
                          title: Text(shop.name),
                          subtitle: Text(shop.address),
                          trailing: Text(_distance(shop.meters)),
                          onTap: () => _openShop(shop),
                        );
                      },
                    ),
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RadarShopOffers extends StatefulWidget {
  const _RadarShopOffers({required this.shop, required this.repository});

  final _RadarShop shop;
  final ShopRepository repository;

  @override
  State<_RadarShopOffers> createState() => _RadarShopOffersState();
}

class _RadarShopOffersState extends State<_RadarShopOffers> {
  Future<List<ShopOffer>> _load() =>
      widget.repository.fetchOffersForShop(widget.shop.id);
  late Future<List<ShopOffer>> _offers = _load();
  bool _retrying = false;

  Future<void> _retry() async {
    if (!mounted || _retrying) return;
    _retrying = true;
    final offers = _load();
    setState(() {
      _offers = offers;
    });
    try {
      await offers;
    } on Exception {
      // FutureBuilder displays the failed request.
    } finally {
      _retrying = false;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.shop.name)),
    body: SafeArea(
      child: FutureBuilder<List<ShopOffer>>(
        future: _offers,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: TextButton(
                onPressed: _retry,
                child: const Text('Chargement impossible · Réessayer'),
              ),
            );
          }
          final offers = snapshot.data!
              .where((offer) => !offer.isUnavailable)
              .toList();
          if (offers.isEmpty) {
            return const Center(child: Text('Aucune offre disponible.'));
          }
          return ListView(
            children: [
              for (final offer in offers)
                ListTile(
                  title: Text(offer.name),
                  subtitle: offer.isSurpriseBasket
                      ? const Text('Panier surprise')
                      : null,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => OfferDetailScreen(
                        offer: offer,
                        repository: widget.repository,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}

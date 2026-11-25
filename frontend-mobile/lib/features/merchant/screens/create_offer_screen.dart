import 'package:material_ui/material_ui.dart';

import '../../../core/network/auth_repository.dart';
import '../../search/models/shop_offer.dart';
import '../data/merchant_api_repository.dart';

class CreateOfferScreen extends StatefulWidget {
  const CreateOfferScreen({super.key, required this.repository, this.offer});

  final MerchantApiRepository repository;
  final ShopOffer? offer;

  @override
  State<CreateOfferScreen> createState() => _CreateOfferScreenState();
}

class _CreateOfferScreenState extends State<CreateOfferScreen> {
  static final _timePattern = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');
  static final _datePattern = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})T([01]\d|2[0-3]):[0-5]\d',
  );
  static const _categories = [
    'Paniers',
    'Repas',
    'Sandwichs',
    'Pâtisseries',
    'Boissons',
    'Autres',
  ];

  final _form = GlobalKey<FormState>();
  late final _initialFields = <String, Object?>{
    'name': widget.offer?.name,
    'description': widget.offer?.description ?? '',
    'category': widget.offer?.category,
    'originalPrice': widget.offer?.originalPrice,
    'discountPrice': widget.offer?.discountPrice,
    'quantity': widget.offer?.quantity,
    'pickupStart': widget.offer?.pickupStart,
    'pickupEnd': widget.offer?.pickupEnd,
    'imageURL': widget.offer?.imageUrl ?? '',
    'foodInfo': widget.offer?.foodInfo ?? '',
    'allergenInfo': widget.offer?.allergenInfo ?? '',
  };
  late final _fields = _initialFields.map(
    (key, value) => MapEntry(
      key,
      TextEditingController(
        text:
            value?.toString() ??
            (key == 'category' && widget.offer == null ? 'Paniers' : ''),
      ),
    ),
  );
  late bool _isBasket = widget.offer?.isSurpriseBasket ?? false;
  bool _saving = false;
  String? _error;

  String _text(String field) => _fields[field]!.text.trim();
  double? _price(String field) =>
      double.tryParse(_text(field).replaceAll(',', '.'));

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  DateTime? _date(String value) {
    final match = _datePattern.firstMatch(value);
    if (match == null) return null;
    final year = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final day = int.parse(match[3]!);
    final calendarDate = DateTime.utc(year, month, day);
    if (calendarDate.month != month || calendarDate.day != day) return null;
    return DateTime.tryParse(value);
  }

  String? _pickupError() {
    final start = _text('pickupStart');
    final end = _text('pickupEnd');
    if (start == _initialFields['pickupStart'] &&
        end == _initialFields['pickupEnd']) {
      return null;
    }
    if (_timePattern.hasMatch(start) && _timePattern.hasMatch(end)) {
      return start.compareTo(end) < 0
          ? null
          : 'Le retrait doit finir après son début.';
    }
    final startDate = _date(start);
    final endDate = _date(end);
    if (startDate == null || endDate == null) {
      return 'Utilise le même format pour le début et la fin.';
    }
    if (!endDate.isAfter(startDate)) {
      return 'Le retrait doit finir après son début.';
    }
    if (!endDate.isAfter(DateTime.now())) {
      return 'La fin du retrait doit être future.';
    }
    return null;
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    final fields = <String, Object>{
      for (final key in _fields.keys)
        if (_isBasket || (key != 'foodInfo' && key != 'allergenInfo'))
          key: _text(key),
      if (_isBasket && widget.offer == null) 'offerType': 'surprise_basket',
      'originalPrice': _price('originalPrice')!,
      'discountPrice': _price('discountPrice')!,
      'quantity': int.parse(_text('quantity')),
    };
    final offer = widget.offer;
    if (offer != null) {
      fields.removeWhere((key, value) => _initialFields[key] == value);
      if (fields.isEmpty) {
        Navigator.of(context).pop();
        return;
      }
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await widget.repository.saveOffer(
        fields,
        offerId: offer?.id,
      );
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _nameError(String? value) {
    final length = value?.trim().length ?? 0;
    return length < 1 || length > 100
        ? 'Saisis entre 1 et 100 caractères.'
        : null;
  }

  String? _priceError(String field) {
    final price = _price(field);
    if (price == null || !price.isFinite || price <= 0) {
      return 'Saisis un prix strictement positif.';
    }
    final original = _price('originalPrice');
    if (field == 'discountPrice' && original != null && price >= original) {
      return 'Le prix réduit doit être inférieur au prix initial.';
    }
    if (_isBasket &&
        field == 'discountPrice' &&
        original != null &&
        price > original / 2) {
      return 'Un panier surprise coûte au maximum 50 % du prix initial.';
    }
    return null;
  }

  String? _basketInfoError(String? value) {
    final length = value?.trim().length ?? 0;
    return length < 1 || length > 500
        ? 'Saisis entre 1 et 500 caractères.'
        : null;
  }

  String? _quantityError(String? value) {
    final quantity = int.tryParse(value?.trim() ?? '', radix: 10);
    if (quantity == null || quantity <= 0) return 'Saisis un entier positif.';
    final offer = widget.offer;
    final total = offer?.quantity;
    final available = offer?.availableQuantity;
    if (total != null && available != null && quantity < total - available) {
      return 'Le total doit couvrir les portions déjà réservées.';
    }
    return null;
  }

  String? _imageError(String? value) {
    final image = value?.trim() ?? '';
    if (image.isEmpty) return null;
    final uri = Uri.tryParse(image);
    if (image.length > 2048 ||
        uri == null ||
        !{'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty) {
      return 'Saisis une URL HTTP(S) valide.';
    }
    return null;
  }

  Widget _field(
    String field,
    String label, {
    String? hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int lines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        key: ValueKey('merchant-offer-$field'),
        controller: _fields[field],
        enabled: !_saving,
        decoration: InputDecoration(labelText: label, hintText: hint),
        validator: validator,
        keyboardType: keyboardType,
        maxLines: lines,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final edit = widget.offer != null;
    const priceKeyboard = TextInputType.numberWithOptions(decimal: true);
    const pickupHint = 'HH:MM ou AAAA-MM-JJTHH:MM';
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        key: const ValueKey('create-offer-screen'),
        appBar: AppBar(
          title: Text(edit ? 'Modifier l’offre' : 'Créer une offre'),
        ),
        body: SafeArea(
          child: Form(
            key: _form,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.offer == null)
                    SwitchListTile(
                      key: const ValueKey('surprise-basket-switch'),
                      title: const Text('Panier surprise'),
                      value: _isBasket,
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _isBasket = value),
                    ),
                  _field('name', 'Nom', validator: _nameError),
                  _field('description', 'Description (facultative)', lines: 3),
                  if (_isBasket) ...[
                    _field(
                      'foodInfo',
                      'Informations alimentaires',
                      lines: 2,
                      validator: _basketInfoError,
                    ),
                    _field(
                      'allergenInfo',
                      'Allergènes et traces possibles',
                      lines: 2,
                      validator: _basketInfoError,
                    ),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _field(
                          'category',
                          'Catégorie',
                          validator: _nameError,
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Choisir une catégorie',
                        enabled: !_saving,
                        onSelected: (category) =>
                            _fields['category']!.text = category,
                        itemBuilder: (_) => [
                          for (final category in _categories)
                            PopupMenuItem(
                              value: category,
                              child: Text(category),
                            ),
                        ],
                      ),
                    ],
                  ),
                  _field(
                    'originalPrice',
                    'Prix initial (DT)',
                    validator: (_) => _priceError('originalPrice'),
                    keyboardType: priceKeyboard,
                  ),
                  _field(
                    'discountPrice',
                    'Prix réduit (DT)',
                    validator: (_) => _priceError('discountPrice'),
                    keyboardType: priceKeyboard,
                  ),
                  _field(
                    'quantity',
                    'Quantité totale',
                    validator: _quantityError,
                    keyboardType: TextInputType.number,
                  ),
                  _field('pickupStart', 'Début du retrait', hint: pickupHint),
                  _field(
                    'pickupEnd',
                    'Fin du retrait',
                    hint: pickupHint,
                    validator: (_) => _pickupError(),
                  ),
                  _field(
                    'imageURL',
                    'URL de l’image (facultative)',
                    validator: _imageError,
                    keyboardType: TextInputType.url,
                  ),
                  if (_error case final error?)
                    Text(
                      error,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Enregistrement…' : 'Enregistrer'),
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

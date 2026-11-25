import 'package:material_ui/material_ui.dart';

import '../../../core/network/auth_repository.dart';
import '../data/merchant_api_repository.dart';
import '../models/merchant_shop.dart';

class MerchantShopScreen extends StatefulWidget {
  const MerchantShopScreen({super.key, required this.repository, this.shop});

  final MerchantApiRepository repository;
  final MerchantShop? shop;

  @override
  State<MerchantShopScreen> createState() => _MerchantShopScreenState();
}

class _MerchantShopScreenState extends State<MerchantShopScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.shop?.name);
  late final _address = TextEditingController(text: widget.shop?.address);
  late final _phone = TextEditingController(text: widget.shop?.phone);
  late final _email = TextEditingController(text: widget.shop?.email);
  late final _description = TextEditingController(
    text: widget.shop?.description,
  );
  late final _latitude = TextEditingController(
    text: widget.shop?.latitude?.toString(),
  );
  late final _longitude = TextEditingController(
    text: widget.shop?.longitude?.toString(),
  );
  bool _saving = false;
  bool _checkExisting = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _address,
      _phone,
      _email,
      _description,
      _latitude,
      _longitude,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      MerchantShop? existing;
      if (widget.shop == null && _checkExisting) {
        existing = await widget.repository.getShop();
      }
      if (!mounted) return;
      final shop =
          existing ??
          await widget.repository.saveShop(
            name: _name.text.trim(),
            address: _address.text.trim(),
            phone: _phone.text.trim(),
            email: _email.text.trim(),
            description: _description.text.trim(),
            latitude: _coordinate(_latitude.text),
            longitude: _coordinate(_longitude.text),
            edit: widget.shop != null,
          );
      if (!mounted) return;
      Navigator.of(context).pop(shop);
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _checkExisting = true;
        _error = error.message;
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  double? _coordinate(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));

  String? _coordinateError(
    String? value,
    TextEditingController other,
    double limit,
  ) {
    final text = value?.trim() ?? '';
    if (text.isEmpty && other.text.trim().isEmpty) return null;
    final number = _coordinate(text);
    return number == null || !number.isFinite || number.abs() > limit
        ? 'Saisis une coordonnée entre -$limit et $limit.'
        : null;
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    bool required = false,
    TextInputType? keyboardType,
    int lines = 1,
    String? Function(String?)? validate,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        enabled: !_saving,
        decoration: InputDecoration(labelText: label),
        keyboardType: keyboardType,
        maxLines: lines,
        validator: (value) {
          final text = value?.trim() ?? '';
          if (validate != null) return validate(value);
          if (required && text.isEmpty) return 'Ce champ est obligatoire.';
          if (keyboardType == TextInputType.emailAddress &&
              text.isNotEmpty &&
              !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
            return 'Saisis une adresse e-mail valide.';
          }
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final edit = widget.shop != null;
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(edit ? 'Modifier le commerce' : 'Inscrire mon commerce'),
        ),
        body: SafeArea(
          child: Form(
            key: _form,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _field('Nom du commerce', _name, required: true),
                  _field('Adresse', _address, required: true),
                  _field(
                    'Téléphone',
                    _phone,
                    required: true,
                    keyboardType: TextInputType.phone,
                  ),
                  _field(
                    'E-mail du commerce (facultatif)',
                    _email,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  _field('Description (facultative)', _description, lines: 3),
                  Text(
                    'Campus Radar',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Text(
                    'Renseigne les deux coordonnées publiques du point de retrait.',
                  ),
                  const SizedBox(height: 12),
                  _field(
                    'Latitude (facultative)',
                    _latitude,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    validate: (value) =>
                        _coordinateError(value, _longitude, 90),
                  ),
                  _field(
                    'Longitude (facultative)',
                    _longitude,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    validate: (value) =>
                        _coordinateError(value, _latitude, 180),
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

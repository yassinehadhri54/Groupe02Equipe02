import 'package:material_ui/material_ui.dart';

import '../../../core/network/auth_repository.dart';
import '../data/merchant_api_repository.dart';
import '../widgets/merchant_confirmation.dart';

class VerifyPickupScreen extends StatefulWidget {
  const VerifyPickupScreen({
    super.key,
    required this.repository,
    this.onChanged,
  });

  final MerchantApiRepository repository;
  final VoidCallback? onChanged;

  @override
  State<VerifyPickupScreen> createState() => _VerifyPickupScreenState();
}

class _VerifyPickupScreenState extends State<VerifyPickupScreen> {
  static final _tokenPattern = RegExp(r'^[a-fA-F0-9]{64}$');
  final _form = GlobalKey<FormState>();
  final _token = TextEditingController();
  bool _busy = false;
  bool _submitting = false;
  String? _error;
  String? _reservationId;

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_busy || !_form.currentState!.validate()) return;
    final token = _token.text.trim();
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _reservationId = null;
    });

    try {
      final accepted = await confirmMerchantAction(
        context,
        title: 'Valider le retrait ?',
        message: 'Si le code est accepté, la réservation sera terminée et le code ne pourra plus être utilisé.',
        actionLabel: 'Valider le retrait',
        actionKey: const ValueKey('merchant-confirm-pickup'),
      );
      if (!mounted || accepted != true) return;
      setState(() => _submitting = true);
      final reservationId = await widget.repository.verifyPickup(token);
      if (!mounted) return;
      _token.clear();
      widget.onChanged?.call();
      setState(() => _reservationId = reservationId);
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Vérifier un retrait')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    key: const ValueKey('merchant-pickup-token'),
                    controller: _token,
                    enabled: !_busy,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _verify(),
                    onChanged: (_) {
                      if (_error == null && _reservationId == null) return;
                      setState(() {
                        _error = null;
                        _reservationId = null;
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Code QR de la réservation',
                      helperText: 'Saisis ou colle le code à 64 caractères.',
                    ),
                    validator: (value) =>
                        _tokenPattern.hasMatch(value?.trim() ?? '')
                        ? null
                        : 'Saisis un code QR valide à 64 caractères.',
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _busy ? null : _verify,
                    child: const Text('Vérifier le code'),
                  ),
                  if (_submitting) const LinearProgressIndicator(),
                  if (_error case final message?)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        message,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  if (_reservationId case final id?)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.check_circle_outline),
                        title: const Text('Retrait validé'),
                        subtitle: Text('Réservation $id · Terminée · Payée'),
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

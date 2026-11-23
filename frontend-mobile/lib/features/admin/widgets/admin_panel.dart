import 'package:material_ui/material_ui.dart';

import '../../../core/network/auth_repository.dart';
import '../../merchant/widgets/merchant_confirmation.dart';

String adminErrorMessage(Object? error) => switch (error) {
  AuthException(statusCode: 400) =>
    'Cette opération est incompatible avec l’état du compte ou du commerce.',
  AuthException(statusCode: 401) => 'Ta session a expiré. Reconnecte-toi.',
  AuthException(statusCode: 403) =>
    'Tu n’as pas les droits nécessaires pour accéder à cette ressource.',
  AuthException(statusCode: 404) => 'Cette ressource est introuvable.',
  AuthException(statusCode: 409) =>
    'Le statut a changé. Actualise la liste avant de réessayer.',
  AuthException(:final message) => message,
  _ => 'Impossible de charger les données.',
};

class AdminDataView<T> extends StatelessWidget {
  const AdminDataView({
    super.key,
    required this.future,
    required this.onReload,
    required this.onSignOut,
    required this.builder,
  });

  final Future<T> future;
  final VoidCallback onReload;
  final VoidCallback onSignOut;
  final Widget Function(T) builder;

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (!snapshot.hasError) return builder(snapshot.requireData);
      final status = snapshot.error is AuthException
          ? (snapshot.error as AuthException).statusCode
          : null;
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                adminErrorMessage(snapshot.error),
                textAlign: TextAlign.center,
              ),
              if (status == 401 || status == 403)
                TextButton(
                  onPressed: onSignOut,
                  child: const Text('Retour à la connexion'),
                )
              else
                TextButton(onPressed: onReload, child: const Text('Réessayer')),
            ],
          ),
        ),
      );
    },
  );
}

class AdminItems<T> extends StatelessWidget {
  const AdminItems({
    super.key,
    required this.items,
    required this.emptyMessage,
    required this.itemBuilder,
  });

  final List<T> items;
  final String emptyMessage;
  final Widget Function(T item) itemBuilder;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(emptyMessage, textAlign: TextAlign.center),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, index) => Card(child: itemBuilder(items[index])),
    );
  }
}

class AdminFilter extends StatelessWidget {
  const AdminFilter({
    super.key,
    required this.label,
    required this.value,
    required this.choices,
    required this.labelFor,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> choices;
  final String Function(String) labelFor;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => InputDecorator(
    decoration: InputDecoration(labelText: label),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        isExpanded: true,
        isDense: true,
        value: value,
        items: [
          const DropdownMenuItem(value: '', child: Text('Tous')),
          for (final choice in choices)
            DropdownMenuItem(value: choice, child: Text(labelFor(choice))),
        ],
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    ),
  );
}

typedef AdminDecision = ({
  String label,
  String question,
  String note,
  Future<void> Function() submit,
});

class AdminDecisionButtons extends StatefulWidget {
  const AdminDecisionButtons({
    super.key,
    required this.actions,
    required this.onSuccess,
  });

  final List<AdminDecision> actions;
  final VoidCallback onSuccess;

  @override
  State<AdminDecisionButtons> createState() => _AdminDecisionButtonsState();
}

class _AdminDecisionButtonsState extends State<AdminDecisionButtons> {
  bool _busy = false;
  bool _submitting = false;
  String? _error;

  Future<void> _submit(AdminDecision action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final accepted = await confirmMerchantAction(
        context,
        title: action.question,
        message: action.note,
        actionLabel: action.label,
        actionKey: const ValueKey('admin-confirm-decision'),
      );
      if (!mounted || accepted != true) return;
      setState(() => _submitting = true);
      await action.submit();
      if (mounted) widget.onSuccess();
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = adminErrorMessage(error));
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
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final action in widget.actions)
              FilledButton.tonal(
                onPressed: _busy ? null : () => _submit(action),
                child: Text(action.label),
              ),
          ],
        ),
        if (_submitting) const LinearProgressIndicator(),
        if (_error case final error?)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    ),
  );
}

class AdminDetails extends StatelessWidget {
  const AdminDetails({super.key, required this.fields, this.actions});

  final Map<String, String?> fields;
  final Widget? actions;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Card(
        child: Column(
          children: [
            for (final entry in fields.entries)
              if (entry.value case final value? when value.trim().isNotEmpty)
                ListTile(title: Text(entry.key), subtitle: Text(value)),
          ],
        ),
      ),
      if (actions case final actions?) ...[const SizedBox(height: 16), actions],
    ],
  );
}

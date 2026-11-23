import 'package:material_ui/material_ui.dart';

Future<bool?> confirmMerchantAction(
  BuildContext context, {
  required String title,
  required String message,
  required String actionLabel,
  required Key actionKey,
}) {
  var closed = false;
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      void close(bool accepted) {
        if (!closed && ModalRoute.of(dialogContext)?.isCurrent == true) {
          closed = true;
          Navigator.pop(dialogContext, accepted);
        }
      }

      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => close(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            key: actionKey,
            onPressed: () => close(true),
            child: Text(actionLabel),
          ),
        ],
      );
    },
  );
}

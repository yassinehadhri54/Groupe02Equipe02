import 'package:material_ui/material_ui.dart';

import '../data/admin_api_repository.dart';
import '../models/admin_data.dart';
import '../widgets/admin_panel.dart';

class AdminShopsScreen extends StatefulWidget {
  const AdminShopsScreen({
    super.key,
    required this.repository,
    required this.onChanged,
    required this.onSignOut,
  });

  final AdminApiRepository repository;
  final VoidCallback onChanged;
  final VoidCallback onSignOut;

  @override
  State<AdminShopsScreen> createState() => _AdminShopsScreenState();
}

class _AdminShopsScreenState extends State<AdminShopsScreen> {
  String _status = '';
  late Future<List<AdminShop>> _shops = widget.repository.loadShops();

  void _load(String status) {
    setState(() {
      _status = status;
      _shops = widget.repository.loadShops(
        status: status.isEmpty ? null : status,
      );
    });
  }

  Future<void> _open(AdminShop shop) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            AdminShopDetailsScreen(repository: widget.repository, entry: shop),
      ),
    );
    if (!mounted || changed != true) return;
    widget.onChanged();
    _load(_status);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Le statut du commerce a été mis à jour.')),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
        child: Row(
          children: [
            Expanded(
              child: AdminFilter(
                key: const ValueKey('admin-shop-filter'),
                label: 'Statut du commerce',
                value: _status,
                choices: adminShopStatuses,
                labelFor: adminStatusLabel,
                onChanged: _load,
              ),
            ),
            IconButton(
              tooltip: 'Actualiser les commerces',
              onPressed: () => _load(_status),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      ),
      Expanded(
        child: AdminDataView<List<AdminShop>>(
          future: _shops,
          onReload: () => _load(_status),
          onSignOut: widget.onSignOut,
          builder: (shops) => AdminItems(
            items: shops,
            emptyMessage: 'Aucun commerce pour ce filtre.',
            itemBuilder: (entry) => ListTile(
              title: Text(_shopName(entry)),
              subtitle: Text(adminStatusLabel(entry.shop.status)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(entry),
            ),
          ),
        ),
      ),
    ],
  );
}

class AdminShopDetailsScreen extends StatelessWidget {
  const AdminShopDetailsScreen({
    super.key,
    required this.repository,
    required this.entry,
  });

  final AdminApiRepository repository;
  final AdminShop entry;

  @override
  Widget build(BuildContext context) {
    final shop = entry.shop;
    final actions = <AdminDecision>[
      if (entry.allows(AdminShopAction.approve))
        (
          label: 'Approuver',
          question: 'Approuver ce commerce ?',
          note:
              'Le commerce sera approuvé et le compte commerçant sera activé.',
          submit: () => repository.updateShop(entry, AdminShopAction.approve),
        ),
      if (entry.allows(AdminShopAction.reject))
        (
          label: 'Refuser',
          question: 'Refuser ce commerce ?',
          note:
              'Le commerce et le compte commerçant passeront au statut Refusé.',
          submit: () => repository.updateShop(entry, AdminShopAction.reject),
        ),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(_shopName(entry))),
      body: SafeArea(
        child: AdminDetails(
          fields: {
            'Statut': adminStatusLabel(shop.status),
            'Adresse': shop.address,
            'Téléphone': shop.phone,
            'E-mail du commerce': shop.email,
            'Description': shop.description,
            'Propriétaire': entry.ownerName,
            'E-mail du propriétaire': entry.ownerEmail,
          },
          actions: actions.isEmpty
              ? null
              : AdminDecisionButtons(
                  actions: actions,
                  onSuccess: () => Navigator.of(context).pop(true),
                ),
        ),
      ),
    );
  }
}

String _shopName(AdminShop entry) =>
    entry.shop.name.trim().isEmpty ? 'Commerce sans nom' : entry.shop.name;

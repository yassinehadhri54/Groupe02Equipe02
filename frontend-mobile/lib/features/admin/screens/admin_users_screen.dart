import 'package:material_ui/material_ui.dart';

import '../data/admin_api_repository.dart';
import '../models/admin_data.dart';
import '../widgets/admin_panel.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({
    super.key,
    required this.repository,
    required this.onChanged,
    required this.onSignOut,
  });

  final AdminApiRepository repository;
  final VoidCallback onChanged;
  final VoidCallback onSignOut;

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  late Future<List<AdminUser>> _users = widget.repository.loadUsers();
  String _role = '';
  String _status = '';
  String _query = '';

  void _reload() {
    setState(() {
      _users = widget.repository.loadUsers();
    });
  }

  Future<void> _open(AdminUser user) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AdminUserDetailsScreen(
          repository: widget.repository,
          uid: user.uid,
          onSignOut: widget.onSignOut,
        ),
      ),
    );
    if (!mounted || changed != true) return;
    widget.onChanged();
    _reload();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Le statut du compte a été mis à jour.')),
    );
  }

  bool _matches(AdminUser user) =>
      (_role.isEmpty || user.profile.role == _role) &&
      (_status.isEmpty || user.status == _status) &&
      (_query.isEmpty ||
          [
            user.displayName,
            user.profile.email ?? '',
            user.uid,
          ].any((value) => value.toLowerCase().contains(_query)));

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('admin-user-search'),
                    decoration: const InputDecoration(
                      labelText: 'Rechercher un utilisateur',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (query) =>
                        setState(() => _query = query.trim().toLowerCase()),
                  ),
                ),
                IconButton(
                  tooltip: 'Actualiser les utilisateurs',
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: AdminFilter(
                    label: 'Rôle',
                    value: _role,
                    choices: adminRoles,
                    labelFor: adminRoleLabel,
                    onChanged: (role) => setState(() => _role = role),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AdminFilter(
                    label: 'Statut',
                    value: _status,
                    choices: adminUserStatuses,
                    labelFor: adminStatusLabel,
                    onChanged: (status) => setState(() => _status = status),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      Expanded(
        child: AdminDataView<List<AdminUser>>(
          future: _users,
          onReload: _reload,
          onSignOut: widget.onSignOut,
          builder: (users) => AdminItems(
            items: users.where(_matches).toList(growable: false),
            emptyMessage: 'Aucun utilisateur pour cette recherche.',
            itemBuilder: (user) => ListTile(
              title: Text(user.displayName),
              subtitle: Text(
                '${adminRoleLabel(user.profile.role)} · ${adminStatusLabel(user.status)}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(user),
            ),
          ),
        ),
      ),
    ],
  );
}

class AdminUserDetailsScreen extends StatefulWidget {
  const AdminUserDetailsScreen({
    super.key,
    required this.repository,
    required this.uid,
    required this.onSignOut,
  });

  final AdminApiRepository repository;
  final String uid;
  final VoidCallback onSignOut;

  @override
  State<AdminUserDetailsScreen> createState() => _AdminUserDetailsScreenState();
}

class _AdminUserDetailsScreenState extends State<AdminUserDetailsScreen> {
  late Future<AdminUser> _user = widget.repository.loadUser(widget.uid);

  void _reload() {
    setState(() {
      _user = widget.repository.loadUser(widget.uid);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Compte utilisateur')),
    body: SafeArea(
      child: AdminDataView<AdminUser>(
        future: _user,
        onReload: _reload,
        onSignOut: widget.onSignOut,
        builder: (user) {
          final action = user.availableAction(
            widget.repository.administratorId,
          );
          final suspend = action == AdminUserAction.suspend;
          final profile = user.profile;
          return AdminDetails(
            fields: {
              'Nom': profile.name,
              'Adresse e-mail': profile.email,
              'Téléphone': profile.phone,
              'Identifiant': user.uid,
              'Rôle': adminRoleLabel(profile.role),
              'Statut': adminStatusLabel(user.status),
            },
            actions: action == null
                ? null
                : AdminDecisionButtons(
                    actions: [
                      (
                        label: suspend ? 'Suspendre' : 'Réactiver',
                        question: suspend
                            ? 'Suspendre ce compte ?'
                            : 'Réactiver ce compte ?',
                        note: suspend
                            ? 'Le compte perdra son accès et ses sessions seront révoquées.'
                            : 'Le compte retrouvera son statut antérieur à la suspension.',
                        submit: () async {
                          await widget.repository.updateUser(user, action);
                        },
                      ),
                    ],
                    onSuccess: () => Navigator.of(context).pop(true),
                  ),
          );
        },
      ),
    ),
  );
}

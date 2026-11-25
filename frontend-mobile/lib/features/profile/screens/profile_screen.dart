import 'package:material_ui/material_ui.dart';

import '../../../core/network/auth_repository.dart';
import '../../auth/screens/login_screen.dart';
import '../data/profile_repository.dart';
import '../models/profile_data.dart';
import 'edit_profile_screen.dart';
import '../../../core/theme/app_theme.dart';
import '../../impact/screens/impact_dashboard_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.authRepository, this.profileRepository});

  final AuthRepository? authRepository;
  final ProfileRepository? profileRepository;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color gold = Color(0xFFDCA321);

  late final AuthRepository _authRepository =
      widget.authRepository ?? AuthRepository();
  late final ProfileRepository _profileRepository =
      widget.profileRepository ??
      ProfileRepository(authRepository: _authRepository);

  ProfileData? _profile;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<bool> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = await _profileRepository.fetchProfile();
      if (!mounted) return false;
      setState(() => _profile = profile);
      return true;
    } on AuthException catch (error) {
      if (!mounted) return false;
      setState(() => _errorMessage = _authErrorMessage(error));
    } on ProfileException catch (error) {
      if (!mounted) return false;
      setState(() => _errorMessage = error.message);
    } catch (_) {
      if (!mounted) return false;
      setState(() {
        _errorMessage = 'Impossible de charger le profil pour le moment.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }

    return false;
  }

  String _authErrorMessage(AuthException error) {
    return switch (error.statusCode) {
      401 => 'Ta session a expiré. Reconnecte-toi.',
      403 => 'Tu n’es pas autorisé à consulter ce profil.',
      _ => error.message,
    };
  }

  // Ouvrir le pop-up de modification
  Future<void> _openEditProfile() async {
    final profile = _profile;
    if (profile == null) return;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (context) {
        return EditProfileScreen(
          initialData: profile,
          profileRepository: _profileRepository,
        );
      },
    );

    if (!mounted) return;

    if (saved == true && await _loadProfile() && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil rechargé avec succès.'),
          backgroundColor: Color(0xFF16832A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('profile-screen'),
      backgroundColor: context.colors.surface,
      body: SafeArea(
        top: false,
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 115,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              Transform.translate(
                offset: const Offset(0, -24),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Column(
                    children: [
                      _buildProfileContent(),
                      const SizedBox(height: 18),
                      _buildStatistics(),
                      const SizedBox(height: 12),
                      if (_profile case final profile?)
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.eco_outlined),
                            title: Text('${profile.ecoPoints} EcoPoints'),
                            subtitle: const Text('Voir mon impact'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () async {
                              await openImpact(
                                context,
                                _authRepository,
                                ImpactScope.student,
                              );
                              if (mounted) await _loadProfile();
                            },
                          ),
                        ),
                      const SizedBox(height: 30),
                      _buildAccountSection(),
                      const SizedBox(height: 30),
                      _buildLogoutButton(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // HEADER
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        22,
        MediaQuery.of(context).padding.top + 18,
        22,
        58,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF800000), Color(0xFFB50008), Color(0xFF8F0401)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(42),
          bottomRight: Radius.circular(42),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              RichText(
                text: const TextSpan(
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
                  children: [
                    TextSpan(
                      text: 'Campus',
                      style: TextStyle(color: Colors.white),
                    ),
                    TextSpan(
                      text: 'Save',
                      style: TextStyle(color: gold),
                    ),
                    TextSpan(text: ' 🌱'),
                  ],
                ),
              ),
              const Spacer(),
              Stack(
                children: [
                  IconButton(
                    onPressed: () =>
                        _showMessage('Notifications bientôt disponibles'),
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
          const SizedBox(height: 26),
          const Text(
            'Mon Profil',
            style: TextStyle(
              fontSize: 35,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Gérez votre compte et votre expérience\nsur CampusSave.',
            style: TextStyle(fontSize: 14, color: Colors.white, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContent() {
    if (_isLoading) {
      return Container(
        key: const ValueKey('profile-loading'),
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 174),
        decoration: _cardDecoration(),
        child: Center(
          child: CircularProgressIndicator(color: context.colors.primary),
        ),
      );
    }

    if (_errorMessage != null || _profile == null) {
      return Container(
        key: const ValueKey('profile-error'),
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 174),
        padding: const EdgeInsets.all(18),
        decoration: _cardDecoration(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage ?? 'Les informations du profil sont indisponibles.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.onSurface, fontSize: 14),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isLoading
                  ? null
                  : () {
                      _loadProfile();
                    },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.colors.primary,
                side: BorderSide(color: context.colors.primary),
              ),
            ),
          ],
        ),
      );
    }

    return _buildUserCard(_profile!);
  }

  // CARTE UTILISATEUR
  Widget _buildUserCard(ProfileData profile) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Container(
                    width: 94,
                    height: 94,
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: gold,
                    ),
                    child: CircleAvatar(
                      backgroundColor: context.adaptiveColor(
                        const Color(0xFFFFE5CB),
                        context.colors.surfaceContainerHighest,
                      ),
                      child: Icon(
                        Icons.person_rounded,
                        color: context.colors.primary,
                        size: 52,
                      ),
                    ),
                  ),
                  if (profile.photoUrl != null)
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: ClipOval(
                          child: Image.network(
                            profile.photoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _openEditProfile,
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppTheme.burgundy,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.camera_alt_outlined,
                          color: Colors.white,
                          size: 17,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),

                    // Nom dynamique
                    Text(
                      profile.name ?? 'Nom non renseigné',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: context.colors.onSurface,
                      ),
                    ),

                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: context.adaptiveColor(
                          const Color(0xFFFFE4D3),
                          context.colors.surfaceContainerHighest,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _roleLabel(profile.role),
                        style: TextStyle(
                          color: context.colors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Bouton crayon
              IconButton(
                tooltip: 'Modifier le profil',
                onPressed: _openEditProfile,
                style: IconButton.styleFrom(
                  backgroundColor: context.adaptiveColor(
                    const Color(0xFFFFE1DE),
                    context.colors.surfaceContainerHighest,
                  ),
                  foregroundColor: context.colors.primary,
                  padding: const EdgeInsets.all(10),
                ),
                icon: const Icon(Icons.edit_outlined, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Email dynamique
          _contactRow(
            Icons.email_outlined,
            profile.email ?? 'E-mail non renseigné',
          ),

          const SizedBox(height: 10),

          // Téléphone dynamique
          _contactRow(
            Icons.phone_outlined,
            profile.phone ?? 'Téléphone non renseigné',
          ),
        ],
      ),
    );
  }

  String _roleLabel(String? role) {
    return switch (role?.toLowerCase()) {
      'student' => 'Étudiant',
      'merchant' => 'Commerçant',
      'admin' => 'Administrateur',
      _ => 'Rôle non renseigné',
    };
  }

  Widget _contactRow(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, color: context.colors.primary, size: 20),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: context.colors.onSurface, fontSize: 13),
          ),
        ),
      ],
    );
  }

  // STATISTIQUES
  Widget _buildStatistics() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 19, horizontal: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8F0401), Color(0xFFB70008), Color(0xFF790000)],
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: AppTheme.burgundy.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const SizedBox(
        height: 58,
        child: Center(
          child: Text(
            'Statistiques bientôt disponibles',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  // SECTION MON COMPTE
  Widget _buildAccountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 5, bottom: 18),
          child: Text(
            'Mon compte',
            style: TextStyle(
              color: context.colors.onSurface,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 12,
          childAspectRatio: 0.91,
          children: [
            _accountTile(
              icon: Icons.person_outline_rounded,
              title: 'Modifier le\nprofil',
              iconColor: context.colors.primary,
              iconBackground: const Color(0xFFFFE1DE),
              onTap: _openEditProfile,
            ),
            _accountTile(
              icon: Icons.credit_card_rounded,
              title: 'Moyens de\npaiement',
              iconColor: const Color(0xFF16832A),
              iconBackground: const Color(0xFFE3F2D9),
              onTap: () =>
                  _showMessage('Moyens de paiement bientôt disponibles'),
            ),
            _accountTile(
              icon: Icons.favorite_border_rounded,
              title: 'Mes favoris',
              iconColor: const Color(0xFFC10015),
              iconBackground: const Color(0xFFFFE1DE),
              onTap: () => _showMessage('Mes favoris bientôt disponibles'),
            ),
            _accountTile(
              icon: Icons.settings_outlined,
              title: 'Paramètres',
              iconColor: const Color(0xFF7432AD),
              iconBackground: const Color(0xFFF0E1F8),
              onTap: () => _showMessage('Paramètres bientôt disponibles'),
            ),
            _accountTile(
              icon: Icons.notifications_none_rounded,
              title: 'Notifications',
              iconColor: const Color(0xFFEA8B00),
              iconBackground: const Color(0xFFFFEAC4),
              onTap: () => _showMessage('Notifications bientôt disponibles'),
            ),
            _accountTile(
              icon: Icons.help_outline_rounded,
              title: 'Aide &\nSupport',
              iconColor: const Color(0xFF1262A7),
              iconBackground: const Color(0xFFDEECFF),
              onTap: () => _showMessage('Aide et support bientôt disponibles'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _accountTile({
    required IconData icon,
    required String title,
    required Color iconColor,
    required Color iconBackground,
    required VoidCallback onTap,
  }) {
    return Material(
      color: context.colors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(21),
      elevation: 2,
      shadowColor: context.colors.primary.withValues(alpha: 0.12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(21),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: iconColor, size: 27),
              ),
              const SizedBox(height: 11),
              Flexible(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.colors.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // DECONNEXION
  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 57,
      child: ElevatedButton.icon(
        onPressed: _confirmLogout,
        icon: Icon(Icons.logout_rounded, color: context.colors.primary),
        label: Text(
          'Se déconnecter',
          style: TextStyle(
            color: context.colors.primary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: context.adaptiveColor(
            const Color(0xFFFFDCD9),
            context.colors.surfaceContainerHighest,
          ),
          foregroundColor: context.colors.primary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.burgundy,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _confirmLogout() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.colors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.logout_rounded, color: context.colors.primary, size: 27),
            SizedBox(width: 12),
            Text(
              'Déconnexion',
              style: TextStyle(
                color: context.colors.onSurface,
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        content: Text(
          'Voulez-vous vraiment vous déconnecter de CampusSave ?',
          style: TextStyle(
            color: context.colors.onSurface,
            fontSize: 15,
            height: 1.5,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
            },
            child: Text(
              'Annuler',
              style: TextStyle(
                color: context.colors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              final repository = _authRepository;
              await repository.clearSession();
              if (!mounted) return;
              Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                MaterialPageRoute<void>(
                  builder: (_) => LoginScreen(authRepository: repository),
                ),
                (route) => false,
              );
            },
            icon: const Icon(
              Icons.logout_rounded,
              color: Colors.white,
              size: 18,
            ),
            label: const Text(
              'Se déconnecter',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.burgundy,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: context.colors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(27),
      boxShadow: [
        BoxShadow(
          color: context.colors.primary.withValues(alpha: 0.10),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}

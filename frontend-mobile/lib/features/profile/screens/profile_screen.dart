
import 'package:material_ui/material_ui.dart';
import 'package:myfirstflutterp/features/auth/screens/login_screen.dart';

import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color burgundy = Color(0xFF8F0401);
  static const Color gold = Color(0xFFDCA321);
  static const Color cream = Color(0xFFF3EEE5);
  static const Color ink = Color(0xFF292323);

  // Données du profil (temporaires, en attendant l'API)
  ProfileData _profile = const ProfileData(
    name: 'Malek Ben Ali',
    email: 'malek.benali@essect.tn',
    phone: '+216 52 123 456',
  );

  // Ouvrir le pop-up de modification
  Future<void> _openEditProfile() async {
    final result = await showModalBottomSheet<ProfileData>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (context) {
        return EditProfileScreen(
          initialData: _profile,
        );
      },
    );

    if (!mounted) return;

    if (result != null) {
      setState(() {
        _profile = result;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil modifié avec succès !'),
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
      backgroundColor: cream,
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
                      _buildUserCard(),
                      const SizedBox(height: 18),
                      _buildStatistics(),
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
          colors: [
            Color(0xFF800000),
            Color(0xFFB50008),
            Color(0xFF8F0401),
          ],
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
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
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
                    onPressed: () => _showMessage(
                      'Notifications bientôt disponibles',
                    ),
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
            style: TextStyle(
              fontSize: 14,
              color: Colors.white,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // CARTE UTILISATEUR
  Widget _buildUserCard() {
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
                    child: const CircleAvatar(
                      backgroundColor: Color(0xFFFFE5CB),
                      child: Icon(
                        Icons.person_rounded,
                        color: burgundy,
                        size: 52,
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
                          color: burgundy,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
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
                      _profile.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: ink,
                      ),
                    ),

                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE4D3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '🎓 Étudiant • ESSECT',
                        style: TextStyle(
                          color: burgundy,
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
                  backgroundColor: const Color(0xFFFFE1DE),
                  foregroundColor: burgundy,
                  padding: const EdgeInsets.all(10),
                ),
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Email dynamique
          _contactRow(
            Icons.email_outlined,
            _profile.email,
          ),

          const SizedBox(height: 10),

          // Téléphone dynamique
          _contactRow(
            Icons.phone_outlined,
            _profile.phone,
          ),
        ],
      ),
    );
  }

  Widget _contactRow(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, color: burgundy, size: 20),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: ink,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  // STATISTIQUES
  Widget _buildStatistics() {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 19,
        horizontal: 8,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF8F0401),
            Color(0xFFB70008),
            Color(0xFF790000),
          ],
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: burgundy.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _statItem(
              Icons.shopping_bag_outlined,
              '12',
              'Réservations',
            ),
          ),
          Container(
            width: 1,
            height: 57,
            color: Colors.white30,
          ),
          Expanded(
            child: _statItem(
              Icons.eco_outlined,
              '36 DT',
              'Économisés',
            ),
          ),
          Container(
            width: 1,
            height: 57,
            color: Colors.white30,
          ),
          Expanded(
            child: _statItem(
              Icons.recycling_rounded,
              '5,2 kg',
              'CO₂ évités',
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(
      IconData icon,
      String value,
      String label,
      ) {
    return Column(
      children: [
        Icon(icon, color: gold, size: 27),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  // SECTION MON COMPTE
  Widget _buildAccountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 5, bottom: 18),
          child: Text(
            'Mon compte',
            style: TextStyle(
              color: ink,
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
              iconColor: burgundy,
              iconBackground: const Color(0xFFFFE1DE),
              onTap: _openEditProfile,
            ),
            _accountTile(
              icon: Icons.credit_card_rounded,
              title: 'Moyens de\npaiement',
              iconColor: const Color(0xFF16832A),
              iconBackground: const Color(0xFFE3F2D9),
              onTap: () => _showMessage(
                'Moyens de paiement bientôt disponibles',
              ),
            ),
            _accountTile(
              icon: Icons.favorite_border_rounded,
              title: 'Mes favoris',
              iconColor: const Color(0xFFC10015),
              iconBackground: const Color(0xFFFFE1DE),
              onTap: () => _showMessage(
                'Mes favoris bientôt disponibles',
              ),
            ),
            _accountTile(
              icon: Icons.settings_outlined,
              title: 'Paramètres',
              iconColor: const Color(0xFF7432AD),
              iconBackground: const Color(0xFFF0E1F8),
              onTap: () => _showMessage(
                'Paramètres bientôt disponibles',
              ),
            ),
            _accountTile(
              icon: Icons.notifications_none_rounded,
              title: 'Notifications',
              iconColor: const Color(0xFFEA8B00),
              iconBackground: const Color(0xFFFFEAC4),
              onTap: () => _showMessage(
                'Notifications bientôt disponibles',
              ),
            ),
            _accountTile(
              icon: Icons.help_outline_rounded,
              title: 'Aide &\nSupport',
              iconColor: const Color(0xFF1262A7),
              iconBackground: const Color(0xFFDEECFF),
              onTap: () => _showMessage(
                'Aide et support bientôt disponibles',
              ),
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
      color: Colors.white,
      borderRadius: BorderRadius.circular(21),
      elevation: 2,
      shadowColor: burgundy.withValues(alpha: 0.12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(21),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 5,
            vertical: 12,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 27,
                ),
              ),
              const SizedBox(height: 11),
              Flexible(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ink,
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
        icon: const Icon(
          Icons.logout_rounded,
          color: burgundy,
        ),
        label: const Text(
          'Se déconnecter',
          style: TextStyle(
            color: burgundy,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFDCD9),
          foregroundColor: burgundy,
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
        content: Text(message),
        backgroundColor: burgundy,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _confirmLogout() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: const Row(
          children: [
            Icon(
              Icons.logout_rounded,
              color: burgundy,
              size: 27,
            ),
            SizedBox(width: 12),
            Text(
              'Déconnexion',
              style: TextStyle(
                color: ink,
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        content: const Text(
          'Voulez-vous vraiment vous déconnecter de CampusSave ?',
          style: TextStyle(
            color: ink,
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
            child: const Text(
              'Annuler',
              style: TextStyle(
                color: ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              // Fermer la fenêtre de confirmation
              Navigator.of(dialogContext).pop();

              // Revenir à la connexion et supprimer
              // toutes les pages précédentes.
              Navigator.of(context, rootNavigator: true)
                  .pushAndRemoveUntil(
                MaterialPageRoute<void>(
                  builder: (_) => const LoginScreen(),
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
              backgroundColor: burgundy,
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
      color: Colors.white,
      borderRadius: BorderRadius.circular(27),
      boxShadow: [
        BoxShadow(
          color: burgundy.withValues(alpha: 0.10),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}

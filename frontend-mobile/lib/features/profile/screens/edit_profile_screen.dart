import 'package:material_ui/material_ui.dart';

import '../../../core/network/auth_repository.dart';
import '../data/profile_repository.dart';
import '../models/profile_data.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    required this.initialData,
    required this.profileRepository,
  });

  final ProfileData initialData;
  final ProfileRepository profileRepository;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const burgundy = Color(0xFF8F0401);
  static const gold = Color(0xFFDCA321);
  static const cream = Color(0xFFF3EEE5);
  static const ink = Color(0xFF292323);

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  bool _isSaving = false;
  String? _errorMessage;
  bool _canRetry = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialData.name ?? '',
    );
    _emailController = TextEditingController(
      text: widget.initialData.email ?? 'Non renseigné',
    );
    _phoneController = TextEditingController(
      text: widget.initialData.phone ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _canRetry = false;
    });

    final phone = _phoneController.text.trim();
    final phoneChanged = phone != (widget.initialData.phone ?? '');

    try {
      await widget.profileRepository.updateProfile(
        name: _nameController.text.trim(),
        phone: phoneChanged ? phone : null,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _authErrorMessage(error);
        _canRetry = error.retryable;
      });
    } on ProfileException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Impossible de modifier le profil pour le moment.';
      });
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _authErrorMessage(AuthException error) {
    return switch (error.statusCode) {
      401 => 'Ta session a expiré. Reconnecte-toi.',
      403 => 'Tu n’es pas autorisé à modifier ce profil.',
      _ => error.message,
    };
  }

  Widget _avatarImage() {
    final photoUrl = widget.initialData.photoUrl;
    if (photoUrl == null) {
      return const CircleAvatar(
        backgroundColor: Color(0xFFFFE5CB),
        child: Icon(Icons.person_rounded, size: 65, color: burgundy),
      );
    }

    return ClipOval(
      child: Image.network(
        photoUrl,
        width: 102,
        height: 102,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const CircleAvatar(
          backgroundColor: Color(0xFFFFE5CB),
          child: Icon(Icons.person_rounded, size: 65, color: burgundy),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF77706B)),
      prefixIcon: Icon(icon, color: burgundy),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 19),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(color: Color(0xFFE7DDD6)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(color: Color(0xFFE7DDD6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(color: burgundy, width: 1.7),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(color: Colors.red, width: 1.7),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        decoration: const BoxDecoration(
          color: cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFCFBDB5),
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(22, 10, 22, 24 + keyboardHeight),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Modifier mon profil',
                                  style: TextStyle(
                                    fontSize: 25,
                                    fontWeight: FontWeight.w900,
                                    color: ink,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  'Personnalise tes informations',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: ink.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: burgundy,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 27),

                      Center(
                        child: Column(
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 110,
                                  height: 110,
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: gold,
                                    shape: BoxShape.circle,
                                  ),
                                  child: _avatarImage(),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: -3,
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: burgundy,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: cream,
                                        width: 3,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_rounded,
                                      color: Colors.white,
                                      size: 19,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 13),
                            TextButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Modification de photo bientôt disponible',
                                    ),
                                  ),
                                );
                              },
                              child: const Text(
                                'Changer la photo',
                                style: TextStyle(
                                  color: burgundy,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 22),

                      const Text(
                        'Informations personnelles',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: ink,
                        ),
                      ),

                      const SizedBox(height: 18),

                      TextFormField(
                        key: const ValueKey('profile-edit-name'),
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: _inputDecoration(
                          label: 'Nom complet',
                          icon: Icons.person_outline_rounded,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().length < 2) {
                            return 'Saisis ton nom complet';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 15),

                      TextFormField(
                        key: const ValueKey('profile-edit-email'),
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        readOnly: true,
                        decoration: _inputDecoration(
                          label: 'Adresse e-mail',
                          icon: Icons.email_outlined,
                        ),
                      ),

                      const SizedBox(height: 15),

                      TextFormField(
                        key: const ValueKey('profile-edit-phone'),
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: _inputDecoration(
                          label: 'Numéro de téléphone',
                          icon: Icons.phone_outlined,
                        ),
                        validator: (value) {
                          final digits = (value ?? '').replaceAll(
                            RegExp(r'\D'),
                            '',
                          );

                          if (digits.isNotEmpty && digits.length < 8) {
                            return 'Saisis un numéro valide';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 27),

                      if (_errorMessage != null) ...[
                        Text(
                          _errorMessage!,
                          key: const ValueKey('edit-profile-error'),
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                          ),
                        ),
                        if (_canRetry)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _isSaving ? null : _saveProfile,
                              child: const Text('Réessayer'),
                            ),
                          ),
                        const SizedBox(height: 12),
                      ],

                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          key: const ValueKey('profile-edit-save'),
                          onPressed: _isSaving ? null : _saveProfile,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.check_circle_outline_rounded,
                                  color: Colors.white,
                                ),
                          label: const Text(
                            'Enregistrer les modifications',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: burgundy,
                            elevation: 5,
                            shadowColor: burgundy.withValues(alpha: 0.25),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 13),

                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Annuler',
                            style: TextStyle(
                              color: Color(0xFF71645E),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

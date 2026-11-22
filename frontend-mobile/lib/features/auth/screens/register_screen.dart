import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/network/auth_repository.dart';
import '../widgets/auth_screen_layout.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, this.authRepository});

  final AuthRepository? authRepository;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _hidePassword = true;
  bool _hideConfirmPassword = true;
  bool _isLoading = false;
  late final AuthRepository _authRepository =
      widget.authRepository ?? AuthRepository();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await _authRepository.register(
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Compte créé. Tu peux maintenant te connecter.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).maybePop();
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          behavior: SnackBarBehavior.floating,
          action: error.retryable
              ? SnackBarAction(
                  label: 'Réessayer',
                  onPressed: () {
                    _register();
                  },
                )
              : null,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goToLogin() {
    Navigator.of(context).maybePop();
  }

  InputDecoration _inputDecoration(
    String hint,
    IconData icon, {
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF77716E), fontSize: 14),
      prefixIcon: Icon(icon, color: AppTheme.ink, size: 22),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFFFFCF9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: Color(0xFFE4D9CF)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: Color(0xFFE4D9CF)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: AppTheme.burgundy, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final compact =
        screenWidth < 370 ||
        MediaQuery.sizeOf(context).height < 740 ||
        MediaQuery.viewInsetsOf(context).bottom > 0;

    return AuthScreenLayout(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthHeader(compact: compact),

            SizedBox(height: compact ? 22 : 34),

            const Text(
              'Inscription',
              style: TextStyle(
                fontSize: 37,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.2,
                color: AppTheme.ink,
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              'Crée ton compte CampusSave',
              style: TextStyle(fontSize: 15, color: AppTheme.ink),
            ),

            SizedBox(height: compact ? 18 : 28),

            // Nom complet.
            TextFormField(
              key: const ValueKey('register-name'),
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: _inputDecoration('Nom complet', Icons.person_outline),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Saisis ton nom complet';
                }
                return null;
              },
            ),

            SizedBox(height: compact ? 12 : 15),

            // Adresse e-mail.
            TextFormField(
              key: const ValueKey('register-email'),
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: _inputDecoration(
                'Adresse e-mail',
                Icons.mail_outline,
              ),
              validator: (value) {
                final email = value?.trim() ?? '';

                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                  return 'Saisis une adresse e-mail valide';
                }

                return null;
              },
            ),

            SizedBox(height: compact ? 12 : 15),

            // Mot de passe.
            TextFormField(
              key: const ValueKey('register-password'),
              controller: _passwordController,
              obscureText: _hidePassword,
              textInputAction: TextInputAction.next,
              decoration: _inputDecoration(
                'Mot de passe',
                Icons.lock_outline,
                suffixIcon: IconButton(
                  tooltip: _hidePassword
                      ? 'Afficher le mot de passe'
                      : 'Masquer le mot de passe',
                  icon: Icon(
                    _hidePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: AppTheme.ink,
                  ),
                  onPressed: () {
                    setState(() {
                      _hidePassword = !_hidePassword;
                    });
                  },
                ),
              ),
              validator: (value) {
                if (value == null || value.length < 8) {
                  return 'Au moins 8 caractères requis';
                }
                return null;
              },
            ),

            SizedBox(height: compact ? 12 : 15),

            // Confirmation du mot de passe.
            TextFormField(
              key: const ValueKey('register-confirm-password'),
              controller: _confirmPasswordController,
              obscureText: _hideConfirmPassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _register(),
              decoration: _inputDecoration(
                'Confirmer le mot de passe',
                Icons.lock_outline,
                suffixIcon: IconButton(
                  tooltip: _hideConfirmPassword
                      ? 'Afficher la confirmation'
                      : 'Masquer la confirmation',
                  icon: Icon(
                    _hideConfirmPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: AppTheme.ink,
                  ),
                  onPressed: () {
                    setState(() {
                      _hideConfirmPassword = !_hideConfirmPassword;
                    });
                  },
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Confirme ton mot de passe';
                }

                if (value != _passwordController.text) {
                  return 'Les mots de passe ne correspondent pas';
                }

                return null;
              },
            ),

            SizedBox(height: compact ? 18 : 26),

            // Bouton inscription.
            SizedBox(
              height: 58,
              child: ElevatedButton(
                key: const ValueKey('register-submit'),
                onPressed: _isLoading ? null : _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.burgundy,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shadowColor: AppTheme.burgundy.withValues(alpha: 0.20),
                  shape: const StadiumBorder(),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 23,
                        height: 23,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "S'inscrire",
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 15),
                          Icon(Icons.arrow_forward, size: 23),
                        ],
                      ),
              ),
            ),

            SizedBox(height: compact ? 18 : 26),

            const Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 17),
                  child: Text(
                    'ou',
                    style: TextStyle(color: AppTheme.ink, fontSize: 15),
                  ),
                ),
                Expanded(child: Divider()),
              ],
            ),

            SizedBox(height: compact ? 16 : 24),

            // Inscription Google.
            SizedBox(
              height: 55,
              child: OutlinedButton(
                onPressed: null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.ink,
                  backgroundColor: const Color(0xFFFFFCF9),
                  disabledForegroundColor: AppTheme.ink,
                  disabledBackgroundColor: const Color(0xFFFFFCF9),
                  side: const BorderSide(color: Color(0xFFD7CBC1)),
                  shape: const StadiumBorder(),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'G',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF4285F4),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        'Bientôt disponible',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 12 : 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: compact ? 16 : 25),

            // Retour vers LoginScreen.
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              children: [
                const Text(
                  'Déjà un compte ?',
                  style: TextStyle(fontSize: 14, color: AppTheme.ink),
                ),
                TextButton(
                  key: const ValueKey('register-login'),
                  onPressed: _goToLogin,
                  child: const Text(
                    'Se connecter',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.burgundy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/network/auth_repository.dart';
import '../session_destination.dart';
import '../widgets/auth_screen_layout.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.authRepository});

  final AuthRepository? authRepository;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _hidePassword = true;
  bool _isLoading = false;
  late final AuthRepository _authRepository =
      widget.authRepository ?? AuthRepository();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final session = await _authRepository.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      await _authRepository.saveSession(session);
      if (!mounted) return;
      final destination = sessionDestination(_authRepository, session);
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute<void>(builder: (_) => destination));
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showComingSoon(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _register() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RegisterScreen(authRepository: _authRepository),
      ),
    );
  }

  InputDecoration _inputDecoration(
    String hint,
    IconData icon, {
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: context.adaptiveColor(
          const Color(0xFF77716E),
          context.colors.onSurfaceVariant,
        ),
        fontSize: 15,
      ),
      prefixIcon: Icon(icon, color: context.colors.onSurface, size: 22),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: context.adaptiveColor(
        const Color(0xFFFFFCF9),
        context.colors.surfaceContainerLow,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 19),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(
          color: context.adaptiveColor(
            const Color(0xFFE4D9CF),
            context.colors.outlineVariant,
          ),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(
          color: context.adaptiveColor(
            const Color(0xFFE4D9CF),
            context.colors.outlineVariant,
          ),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: context.colors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: context.colors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: context.colors.error, width: 1.5),
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

            SizedBox(height: compact ? 24 : 38),

            Text(
              'Connexion',
              style: TextStyle(
                fontSize: 37,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.2,
                color: context.colors.onSurface,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              'Accède à ton compte CampusSave',
              style: TextStyle(fontSize: 15, color: context.colors.onSurface),
            ),

            SizedBox(height: compact ? 20 : 28),

            // Adresse e-mail.
            TextFormField(
              key: const ValueKey('login-email'),
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

            SizedBox(height: compact ? 14 : 18),

            // Mot de passe.
            TextFormField(
              key: const ValueKey('login-password'),
              controller: _passwordController,
              obscureText: _hidePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _login(),
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
                    color: context.colors.onSurface,
                  ),
                  onPressed: () {
                    setState(() {
                      _hidePassword = !_hidePassword;
                    });
                  },
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Saisis ton mot de passe';
                }
                return null;
              },
            ),

            const SizedBox(height: 10),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _showComingSoon(
                  'Récupération du mot de passe bientôt disponible.',
                ),
                child: Text(
                  'Mot de passe oublié ?',
                  style: TextStyle(
                    color: context.colors.primary,
                    decoration: TextDecoration.underline,
                    decorationColor: context.colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            SizedBox(height: compact ? 18 : 25),

            // Connexion.
            SizedBox(
              height: 58,
              child: ElevatedButton(
                key: const ValueKey('login-submit'),
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.burgundy,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shadowColor: AppTheme.burgundy.withValues(alpha: 0.20),
                  shape: const StadiumBorder(),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Se connecter',
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

            SizedBox(height: compact ? 22 : 32),

            Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 17),
                  child: Text(
                    'ou',
                    style: TextStyle(
                      color: context.colors.onSurface,
                      fontSize: 15,
                    ),
                  ),
                ),
                Expanded(child: Divider()),
              ],
            ),

            SizedBox(height: compact ? 18 : 27),

            // Connexion Google (future).
            SizedBox(
              height: 55,
              child: OutlinedButton(
                onPressed: () =>
                    _showComingSoon('Connexion Google bientôt disponible.'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.colors.onSurface,
                  backgroundColor: context.adaptiveColor(
                    const Color(0xFFFFFCF9),
                    context.colors.surfaceContainerLow,
                  ),
                  side: BorderSide(
                    color: context.adaptiveColor(
                      const Color(0xFFD7CBC1),
                      context.colors.outlineVariant,
                    ),
                  ),
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
                        'Se connecter avec Google',
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

            SizedBox(height: compact ? 18 : 32),

            // Inscription.
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              children: [
                Text(
                  'Pas encore de compte ?',
                  style: TextStyle(
                    fontSize: 14,
                    color: context.colors.onSurface,
                  ),
                ),
                TextButton(
                  key: const ValueKey('login-register'),
                  onPressed: _register,
                  child: Text(
                    "S'inscrire",
                    style: TextStyle(
                      fontSize: 16,
                      color: context.colors.primary,
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

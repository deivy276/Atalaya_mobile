import 'package:flutter/material.dart';

import '../../../core/theme/layout_tokens.dart';

class LoginCard extends StatefulWidget {
  const LoginCard({
    super.key,
    required this.usernameController,
    required this.passwordController,
    required this.onSubmit,
    this.onForgotPassword,
    this.isLoading = false,
    this.errorText,
  });

  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final VoidCallback onSubmit;
  final VoidCallback? onForgotPassword;
  final bool isLoading;
  final String? errorText;

  @override
  State<LoginCard> createState() => _LoginCardState();
}

class _LoginCardState extends State<LoginCard> {
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: LayoutTokens.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: LayoutTokens.dividerSubtle),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Center(
            child: Image(
              image: AssetImage('assets/Atalaya.png'),
              height: 42,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'INICIAR SESIÓN',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: LayoutTokens.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 20,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: widget.usernameController,
            style: const TextStyle(color: LayoutTokens.textPrimary),
            decoration: _darkUnderlineInputDecoration(
              label: 'Usuario',
              prefixIcon: Icons.person_outline_rounded,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: widget.passwordController,
            obscureText: _obscurePassword,
            style: const TextStyle(color: LayoutTokens.textPrimary),
            decoration: _darkUnderlineInputDecoration(
              label: 'Contraseña',
              prefixIcon: Icons.lock_outline_rounded,
              suffixIcon: IconButton(
                tooltip: _obscurePassword ? 'Mostrar contraseña' : 'Ocultar contraseña',
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: LayoutTokens.textMuted,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: widget.onForgotPassword,
              child: const Text(
                '¿Olvidaste tu contraseña?',
                style: TextStyle(color: LayoutTokens.textSecondary),
              ),
            ),
          ),
          if (widget.errorText != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(widget.errorText!, style: const TextStyle(color: LayoutTokens.accentRed)),
          ],
          const SizedBox(height: 14),
          SizedBox(
            height: 46,
            child: FilledButton(
              style: FilledButton.styleFrom(
                shape: const StadiumBorder(),
              ),
              onPressed: widget.isLoading ? null : widget.onSubmit,
              child: widget.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : const Text(
                      'ENTRAR',
                      style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Sistema protegido. Acceso restringido.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: LayoutTokens.textMuted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _darkUnderlineInputDecoration({
    required String label,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    const border = UnderlineInputBorder(
      borderSide: BorderSide(color: LayoutTokens.dividerSubtle),
    );

    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: LayoutTokens.textSecondary),
      prefixIcon: Icon(prefixIcon, color: LayoutTokens.textMuted),
      suffixIcon: suffixIcon,
      enabledBorder: border,
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: LayoutTokens.accentBlue, width: 1.6),
      ),
      errorBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: LayoutTokens.accentRed, width: 1.2),
      ),
      focusedErrorBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: LayoutTokens.accentRed, width: 1.6),
      ),
    );
  }
}

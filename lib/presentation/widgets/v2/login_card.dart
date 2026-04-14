import 'package:flutter/material.dart';

import '../../../core/theme/layout_tokens.dart';

class LoginCard extends StatelessWidget {
  const LoginCard({
    super.key,
    required this.usernameController,
    required this.passwordController,
    required this.onSubmit,
    this.isLoading = false,
    this.errorText,
  });

  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final VoidCallback onSubmit;
  final bool isLoading;
  final String? errorText;

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
          const Icon(Icons.change_history_rounded, size: 40, color: LayoutTokens.textPrimary),
          const SizedBox(height: 8),
          const Text('INICIAR SESIÓN', textAlign: TextAlign.center, style: TextStyle(color: LayoutTokens.textPrimary, fontWeight: FontWeight.w700, fontSize: 20)),
          const SizedBox(height: 14),
          TextField(controller: usernameController, decoration: const InputDecoration(labelText: 'Usuario')),
          const SizedBox(height: 10),
          TextField(controller: passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña')),
          if (errorText != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(errorText!, style: const TextStyle(color: LayoutTokens.accentRed)),
          ],
          const SizedBox(height: 14),
          FilledButton(
            onPressed: isLoading ? null : onSubmit,
            child: isLoading ? const CircularProgressIndicator() : const Text('ENTRAR'),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme.dart';

/// Recuperação de senha — pede o e-mail e chama
/// `resetPasswordForEmail` do Supabase Auth. Alterna entre o formulário e
/// a confirmação de envio no mesmo widget (mesmo padrão já usado em
/// LoginScreen pro estado pós-cadastro), em vez de duas rotas separadas.
///
/// Nota de integração: o link que chega no e-mail precisa de uma URL de
/// redirect cadastrada em Supabase → Authentication → URL Configuration
/// pra voltar pro app. Diferente do login com Google (que abre um
/// servidor loopback local só durante o clique, ver login_screen.dart),
/// esse clique acontece minutos/horas depois, então não há um receptor
/// rodando pra capturá-lo ainda — falta essa parte de deep link antes de
/// este fluxo funcionar ponta a ponta em desktop/mobile. A tela de
/// definir nova senha (NewPasswordScreen) já está pronta pro momento em
/// que isso for resolvido — ver main.dart, onde `_AuthGate` escuta
/// `AuthChangeEvent.passwordRecovery`.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _submitting = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(_emailController.text.trim());
      if (mounted) setState(() => _sent = true);
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Não consegui enviar o e-mail. Tente de novo.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar senha')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: _sent ? _SentConfirmation(email: _emailController.text.trim()) : _buildForm(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: Image.asset('assets/images/mascot_avatar.png', width: 72, height: 72)),
          const SizedBox(height: 20),
          Text(
            'Digite o e-mail da sua conta — vamos te mandar um link pra criar uma senha nova.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'E-mail'),
            validator: (value) => (value == null || !value.contains('@')) ? 'Digite um e-mail válido' : null,
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!, style: const TextStyle(color: AppColors.red), textAlign: TextAlign.center),
          ],
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Enviar link de redefinição'),
          ),
        ],
      ),
    );
  }
}

class _SentConfirmation extends StatelessWidget {
  final String email;

  const _SentConfirmation({required this.email});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(color: AppColors.green.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: const Icon(Icons.mark_email_read_rounded, size: 26, color: AppColors.green),
        ),
        const SizedBox(height: 16),
        const Text(
          'Verifique seu e-mail',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          'Mandamos um link pra $email — clique nele pra criar uma senha nova.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppColors.textDim, height: 1.5),
        ),
        const SizedBox(height: 22),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: AppColors.line),
            foregroundColor: AppColors.textPrimary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text('Voltar para o login'),
        ),
      ],
    );
  }
}

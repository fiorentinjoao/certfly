import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme.dart';

/// RF-01: autenticação por e-mail/senha via Supabase Auth. OAuth Google
/// fica pra depois — precisa de um client OAuth configurado no Google
/// Cloud Console, fora do escopo desta tela.
///
/// Depois de logar/cadastrar com sucesso, não navega explicitamente: o
/// `onAuthStateChange` escutado em main.dart._Bootstrap troca pra Home
/// sozinho quando a sessão fica ativa.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum _Mode { signIn, signUp }

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  _Mode _mode = _Mode.signIn;
  bool _submitting = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _error = null;
      _info = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      if (_mode == _Mode.signIn) {
        await Supabase.instance.client.auth.signInWithPassword(email: email, password: password);
        // Sucesso: onAuthStateChange em main.dart cuida da navegação.
      } else {
        final response = await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
        );
        if (response.session == null) {
          // Confirmação de e-mail ativada no projeto — sem sessão ainda.
          setState(() {
            _info = 'Conta criada! Confirme seu e-mail ($email) pra poder entrar.';
            _mode = _Mode.signIn;
          });
        }
      }
    } on AuthException catch (e) {
      setState(() => _error = _friendlyError(e));
    } catch (e) {
      setState(() => _error = 'Não consegui falar com o Supabase. Tente de novo.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _friendlyError(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login credentials')) return 'E-mail ou senha incorretos.';
    if (msg.contains('user already registered')) return 'Já existe uma conta com esse e-mail.';
    if (msg.contains('password should be at least')) return 'Senha muito curta (mínimo 6 caracteres).';
    return e.message;
  }

  @override
  Widget build(BuildContext context) {
    final isSignUp = _mode == _Mode.signUp;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: Image.asset('assets/images/mascot_avatar.png', width: 84, height: 84)),
                    const SizedBox(height: 16),
                    Text(
                      'CertFly',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Estude. Pratique. Conquiste.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textDim, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'E-mail'),
                      validator: (value) =>
                          (value == null || !value.contains('@')) ? 'Digite um e-mail válido' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Senha'),
                      validator: (value) =>
                          (value == null || value.length < 6) ? 'Mínimo de 6 caracteres' : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(_error!, style: const TextStyle(color: AppColors.red), textAlign: TextAlign.center),
                    ],
                    if (_info != null) ...[
                      const SizedBox(height: 14),
                      Text(_info!, style: const TextStyle(color: AppColors.green), textAlign: TextAlign.center),
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
                          : Text(isSignUp ? 'Criar conta' : 'Entrar'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _submitting
                          ? null
                          : () => setState(() {
                              _mode = isSignUp ? _Mode.signIn : _Mode.signUp;
                              _error = null;
                              _info = null;
                            }),
                      child: Text(
                        isSignUp ? 'Já tenho conta — entrar' : 'Não tenho conta — criar uma',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme.dart';

/// RF-01: formulário de e-mail/senha — entrar OU criar conta, conforme a
/// escolha feita na WelcomeScreen (lib/screens/welcome_screen.dart), que é
/// quem decide qual instância desta tela empurrar. Login com Google só
/// aparece no modo "entrar" — pra criar conta nova, é e-mail/senha mesmo.
///
/// Depois de logar/cadastrar com sucesso, não navega explicitamente: o
/// `onAuthStateChange` escutado em main.dart._AuthGate troca pra Home
/// sozinho quando a sessão fica ativa.
class LoginScreen extends StatefulWidget {
  final bool isSignUp;

  const LoginScreen({super.key, required this.isSignUp});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

/// Porta do servidor loopback que recebe o redirect do OAuth no desktop
/// Linux (ver `_signInWithGoogle`). Precisa bater com a URL cadastrada em
/// Supabase → Authentication → URL Configuration → Redirect URLs
/// (`http://localhost:8910/**`). Em mobile (Android/iOS), o caminho normal
/// é deep link nativo — esse loopback é só a solução prática pro alvo de
/// desenvolvimento atual (desktop).
const _oauthLoopbackPort = 8910;

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  late bool _isSignUp;
  bool _submitting = false;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    _isSignUp = widget.isSignUp;
  }

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
      if (!_isSignUp) {
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
            _isSignUp = false;
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

  /// Fluxo OAuth pro desktop Linux: abre o navegador do sistema pro login
  /// do Google, e um servidor HTTP local (loopback) recebe o redirect de
  /// volta — sem isso, o app não tem como saber que o login terminou (não
  /// há deep link nativo registrado no SO nesse ambiente de dev).
  Future<void> _signInWithGoogle() async {
    setState(() {
      _submitting = true;
      _error = null;
      _info = null;
    });

    HttpServer? server;
    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, _oauthLoopbackPort);

      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'http://localhost:$_oauthLoopbackPort/callback',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );

      final request = await server.first.timeout(
        const Duration(minutes: 2),
        onTimeout: () => throw TimeoutException('sem resposta do navegador'),
      );
      final callbackUri = request.requestedUri;

      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.html
        ..write('<html><body><h2>Pode fechar esta aba e voltar pro CertFly.</h2></body></html>');
      await request.response.close();

      await Supabase.instance.client.auth.getSessionFromUrl(callbackUri);
      // Sucesso: onAuthStateChange em main.dart cuida da navegação.
    } on AuthException catch (e) {
      setState(() => _error = _friendlyError(e));
    } catch (e) {
      setState(() => _error = 'Não consegui completar o login com Google. Tente de novo.');
    } finally {
      await server?.close(force: true);
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
    return Scaffold(
      appBar: AppBar(title: Text(_isSignUp ? 'Criar conta' : 'Entrar')),
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
                    Center(child: Image.asset('assets/images/mascot_avatar.png', width: 72, height: 72)),
                    const SizedBox(height: 28),
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
                          : Text(_isSignUp ? 'Criar conta' : 'Entrar'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _submitting
                          ? null
                          : () => setState(() {
                              _isSignUp = !_isSignUp;
                              _error = null;
                              _info = null;
                            }),
                      child: Text(
                        _isSignUp ? 'Já tenho conta — entrar' : 'Não tenho conta — criar uma',
                      ),
                    ),
                    // Google só faz sentido no modo "entrar" — pra criar
                    // conta nova, o fluxo pedido foi e-mail/senha mesmo.
                    if (!_isSignUp) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Expanded(child: Divider(color: AppColors.line)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text('ou', style: Theme.of(context).textTheme.bodySmall),
                          ),
                          const Expanded(child: Divider(color: AppColors.line)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _submitting ? null : _signInWithGoogle,
                        icon: Image.asset('assets/images/google_logo.png', width: 18, height: 18),
                        label: const Text('Continuar com Google'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: AppColors.line),
                          foregroundColor: AppColors.textPrimary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ],
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

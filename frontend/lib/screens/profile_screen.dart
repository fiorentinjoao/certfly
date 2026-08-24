import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/me.dart';
import '../theme.dart';

/// Aba Perfil da navegação inferior — avatar, XP/streak, e o logout, que
/// antes vivia escondido num popup menu da AppBar da Home. `onLogout` é
/// null no modo dev (token fixo do seed_dev.py) — sem sessão real pra
/// encerrar, ver lib/auth/auth_gateway.dart.
///
/// Busca `Me` sozinho (não recebe de fora) — mesmo padrão de HomeScreen:
/// cada tela busca só o que precisa, sem estado compartilhado entre abas
/// (RNF-06: monólito simples, solo dev consegue entender qualquer parte).
class ProfileScreen extends StatefulWidget {
  final ApiClient apiClient;
  final VoidCallback? onLogout;
  final VoidCallback onGoToCertifications;

  const ProfileScreen({
    super.key,
    required this.apiClient,
    required this.onLogout,
    required this.onGoToCertifications,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<Me> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.apiClient.getMe();
  }

  void _reload() => setState(() => _future = widget.apiClient.getMe());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: FutureBuilder<Me>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Não consegui carregar seu perfil',
                      style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _reload, child: const Text('Tentar novamente')),
                  ],
                ),
              ),
            );
          }
          return _ProfileBody(
            me: snapshot.data!,
            onLogout: widget.onLogout,
            onGoToCertifications: widget.onGoToCertifications,
          );
        },
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  final Me me;
  final VoidCallback? onLogout;
  final VoidCallback onGoToCertifications;

  const _ProfileBody({required this.me, required this.onLogout, required this.onGoToCertifications});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      children: [
        Center(
          child: Column(
            children: [
              const CircleAvatar(
                radius: 37,
                backgroundColor: AppColors.surfaceHigh,
                child: Icon(Icons.person_rounded, size: 36, color: AppColors.textDim),
              ),
              const SizedBox(height: 10),
              Text(
                me.email,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.line, width: 2),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _Stat(icon: Icons.bolt_rounded, color: AppColors.green, value: '${me.totalXp}', label: 'XP TOTAL'),
              Container(width: 2, height: 28, color: AppColors.line),
              _Stat(
                icon: Icons.local_fire_department_rounded,
                color: AppColors.amber,
                value: '${me.currentStreak}',
                label: 'DIAS SEGUIDOS',
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        _SettingsRow(
          icon: Icons.school_rounded,
          label: 'Trocar certificação',
          onTap: onGoToCertifications,
        ),
        const SizedBox(height: 8),
        _SettingsRow(icon: Icons.notifications_rounded, label: 'Notificações', onTap: null),
        const SizedBox(height: 8),
        _SettingsRow(icon: Icons.tune_rounded, label: 'Preferências de estudo', onTap: null),
        if (onLogout != null) ...[
          const SizedBox(height: 8),
          _SettingsRow(icon: Icons.logout_rounded, label: 'Sair', danger: true, onTap: onLogout),
        ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _Stat({required this.icon, required this.color, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.textPrimary)),
          ],
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppColors.textDim)),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool danger;
  final VoidCallback? onTap;

  const _SettingsRow({required this.icon, required this.label, required this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.red : AppColors.textPrimary;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(border: Border.all(color: AppColors.line, width: 2), borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: danger ? AppColors.red.withValues(alpha: 0.14) : AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 15, color: danger ? AppColors.red : AppColors.textDim),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
              ),
              if (!danger)
                const Icon(Icons.chevron_right_rounded, color: AppColors.textDim, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

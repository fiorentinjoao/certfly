import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/certification.dart';
import '../theme.dart';

/// Aba Certificações — GET /certifications (RF-02 estendido, ver
/// docs/product-spec.md, decisão de 2026-08-10: MVP cobre 3 certificações,
/// 1 por cloud). Mostra a % de domínio geral de cada uma que o backend já
/// tem cadastrada.
///
/// Nota: a TROCA de certificação ativa ainda não é real — o app hoje
/// decide qual certificação mostrar via `--dart-define` (AppConfig.
/// certificationId, fixo em tempo de build), não uma escolha persistida
/// em runtime. Fazer isso direito exigiria guardar a escolha (ex: via
/// shared_preferences, que hoje só entra como dependência transitiva, não
/// declarada) e propagar isso pra Home/Lição. Por ora só sinaliza qual é
/// a ativa; tocar numa outra não faz nada ainda.
class CertificationsScreen extends StatefulWidget {
  final ApiClient apiClient;
  final String activeCertificationId;

  const CertificationsScreen({
    super.key,
    required this.apiClient,
    required this.activeCertificationId,
  });

  @override
  State<CertificationsScreen> createState() => _CertificationsScreenState();
}

class _CertificationsScreenState extends State<CertificationsScreen> {
  late Future<List<CertificationOverview>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.apiClient.getCertifications();
  }

  void _reload() => setState(() => _future = widget.apiClient.getCertifications());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Certificações')),
      body: FutureBuilder<List<CertificationOverview>>(
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
                      'Não consegui carregar as certificações',
                      style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _reload, child: const Text('Tentar novamente')),
                  ],
                ),
              ),
            );
          }

          final certifications = snapshot.data!;
          if (certifications.isEmpty) {
            return const Center(
              child: Text(
                'Nenhuma certificação disponível ainda.',
                style: TextStyle(color: AppColors.textDim, fontWeight: FontWeight.w600),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: certifications.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _CertificationCard(
              certification: certifications[index],
              isActive: certifications[index].id == widget.activeCertificationId,
            ),
          );
        },
      ),
    );
  }
}

/// Logo do provedor pelo `provider_slug` da API — cai pro ícone genérico
/// se aparecer um provedor sem logo cadastrado ainda (ex: conteúdo novo
/// de um provedor que o time ainda não desenhou o selo). Compara por
/// substring, não igualdade exata, porque o slug pode variar entre seeds
/// ("google-cloud", "gcp", etc.) sem quebrar a UI por causa disso.
String? _logoAssetFor(String providerSlug) {
  final slug = providerSlug.toLowerCase();
  if (slug.contains('google') || slug.contains('gcp')) return 'assets/images/logo_gcp.png';
  if (slug.contains('aws') || slug.contains('amazon')) return 'assets/images/logo_aws.png';
  if (slug.contains('azure') || slug.contains('microsoft')) return 'assets/images/logo_azure.png';
  return null;
}

class _CertificationCard extends StatelessWidget {
  final CertificationOverview certification;
  final bool isActive;

  const _CertificationCard({required this.certification, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final logoAsset = _logoAssetFor(certification.providerSlug);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isActive ? AppColors.purple.withValues(alpha: 0.12) : AppColors.surface,
        border: Border.all(color: isActive ? AppColors.purple : AppColors.line, width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            padding: EdgeInsets.all(logoAsset != null ? 8 : 0),
            decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(11)),
            child: logoAsset != null
                ? Image.asset(logoAsset, fit: BoxFit.contain)
                : const Icon(Icons.cloud_rounded, color: AppColors.purpleLight, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  certification.providerName,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  certification.name,
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.textDim),
                ),
              ],
            ),
          ),
          if (isActive)
            Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
            )
          else
            Text(
              '${(certification.overallMasteryPct * 100).round()}%',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.textDim),
            ),
        ],
      ),
    );
  }
}

# Spec de MVP — versão consolidada

## Problema

Profissionais de dados estudando para certificações Google Cloud (ex: Professional Data Engineer) usam material fragmentado, denso, em inglês, e sem estrutura de hábito — resultando em estudo esporádico, baixa retenção e desistência.

## Usuário-alvo (v0)

O próprio dono do produto e pessoas no mesmo perfil: engenheiro(a) de dados pleno/sênior, já trabalha com o assunto no dia a dia, estuda pra certificação por objetivo profissional (promoção/vaga), tem pouco tempo livre (estuda em intervalos curtos).

## Hipótese central

Sessões curtas e diárias, com feedback imediato e foco automático nos pontos fracos, geram mais consistência de estudo e retenção do que material passivo (vídeo/PDF/dump), aumentando taxa de aprovação e reduzindo tempo total de preparo.

## Diferenciação (por que não Whizlabs / Tutorials Dojo / ExamTopics / CloudLearn?)

Ver detalhes em [market-research.md](market-research.md). Resumo: concorrentes existentes ou são banco de questões estático sem gamificação real (Whizlabs, Tutorials Dojo, ExamTopics), ou têm gamificação superficial — XP/badges/streak colados em cima de um quiz — sem o mecanismo estrutural que faz o Duolingo funcionar (trilha obrigatória, gate de domínio, vidas/corações, árvore de habilidades visual). O diferencial proposto: repetição espaçada real + hábito diário + foco automático nos pontos fracos, com a mecânica estrutural do Duolingo (não só o verniz visual).

## Conteúdo do MVP

**Decisão revisada (2026-08-10):** o MVP passa a cobrir as 3 clouds principais, uma certificação de dados por provedor — não mais só GCP. Motivo: "Duolingo para certificações de dados" como proposta de valor só é defensável de verdade se cobrir onde o mercado de dados realmente estuda (GCP, AWS, Azure), não só o provedor de origem do dono. Isso aumenta bastante o volume de conteúdo a escrever (ver seção "Fora do MVP" — o antigo item "Multi-certificação" foi promovido pra dentro do MVP).

- **Certificações do MVP** (1 por cloud, todas focadas em engenharia de dados — perfil do usuário-alvo):
  1. **Google Cloud** — Professional Data Engineer
  2. **AWS** — AWS Certified Data Engineer – Associate
  3. **Azure** — Microsoft Certified: Azure Data Engineer Associate (DP-203)
- **Domínios cobertos por certificação (MVP)**: por ora, escopo raso em todas as 3 — os 2 domínios de maior peso na prova de cada certificação (análogo ao que foi feito pra GCP: Designing/Processing + Storing). Detalhamento por certificação (AWS/Azure) fica para quando o conteúdo de fato começar a ser escrito.
- **Domínios do GCP PDE** (já detalhado, mantido como referência):
  1. Designing Data Processing Systems (~30%)
  2. Ingerindo e Processando Dados — batch + streaming (Dataflow, Apache Beam, Dataproc, Cloud Data Fusion, Pub/Sub)
  3. Armazenando Dados (Storing) — BigQuery, BigLake, Dataplex, AlloyDB, Bigtable, Spanner, Cloud SQL, Firestore
  4. Ensuring Solution Quality (~15%) — validação, qualidade, confiabilidade de dados
  5. Managing Data Security and Compliance (~10%) — segurança e conformidade regulatória

  Nota: "Building/Operationalizing" + "Ensuring Solution Quality" juntos respondem por ~60% do conteúdo da prova — o peso real está mais em "construir e operar" do que em "definir conceito". Domínios equivalentes de AWS Data Engineer – Associate e Azure DP-203 ainda precisam ser mapeados (próximo passo, junto com a escrita do conteúdo).

## Core loop do MVP

1. Usuário abre uma lição curta (8-10 perguntas) de um domínio
2. Responde, recebe explicação didática na hora (por que cada alternativa está certa/errada)
3. Ganha XP, mantém streak diário
4. Sistema recalcula % de domínio daquele tópico
5. Questões erradas voltam automaticamente depois de um tempo (repetição espaçada — ver [core-loop-srs.md](core-loop-srs.md))

## Fora do MVP (v1.1+)

- Simulado completo estilo prova real
- IA respondendo dúvidas livres
- Ranking / social / grupos de estudo
- Pagamento / monetização
- App mobile nativo

~~Multi-certificação~~ — **removido desta lista em 2026-08-10**: passou a fazer parte do MVP (3 certificações, 1 por cloud — ver "Conteúdo do MVP" acima). A arquitetura já era agnóstica de provedor desde o início (ver architecture-decisions.md); o que muda agora é que o conteúdo de AWS/Azure entra na Fase 1, não só o GCP.

## Monetização

Nenhuma no MVP. Ideia inicial para depois: freemium (grátis = X perguntas/dia + 1 trilha; pago = ilimitado + simulados completos + analytics de performance por domínio). Decisão de pricing adiada até existirem 2+ certificações no catálogo — no MVP o foco é validar retenção antes de validar disposição de pagar.

## Métrica de sucesso do MVP

% de usuários que mantêm streak de 7+ dias.

## Pontos que já foram debatidos e decididos

- Não travar a plataforma em "certificações de dados" como regra — dados é só o ponto de partida por ser onde o dono tem profundidade para gerar conteúdo de qualidade rápido. Arquitetura desde o início é agnóstica de provedor/domínio.
- Sem cobrança no MVP.
- Domínios do MVP escolhidos junto com o dono: Designing + Storing (GCP; equivalentes AWS/Azure a mapear).
- Métrica de sucesso escolhida: retenção via streak de 7+ dias.
- **2026-08-10**: MVP passa a lançar com 3 certificações (GCP PDE + AWS Data Engineer – Associate + Azure DP-203) em vez de só GCP. Aumenta o volume de conteúdo a escrever antes do lançamento — trade-off aceito pelo dono em troca de uma proposta de valor mais defensável ("cobre as 3 clouds", não só uma).

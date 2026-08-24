# Plano de conteúdo — blueprint completo das 3 certificações

Fontes oficiais usadas (pesquisado em 2026-08-10):
- **GCP PDE**: [guia oficial v4.2](https://services.google.com/fh/files/misc/professional_data_engineer_exam_guide_english.pdf)
- **AWS DEA-C01**: [guia oficial v1.0](https://d1.awsstatic.com/training-and-certification/docs-data-engineer-associate/AWS-Certified-Data-Engineer-Associate_Exam-Guide.pdf)
- **Azure DP-700**: [study guide oficial](https://learn.microsoft.com/credentials/certifications/resources/study-guides/dp-700) (skills measured em 21/07/2026)

Aviso legal (já discutido antes): tudo abaixo é a estrutura pública dos guias oficiais —
nenhum provedor proíbe estudar por ela. As **perguntas em si** precisam ser escritas do
zero pela equipe do CertFly, nunca copiadas/parafraseadas de bancos de questões reais
vazados (braindumps) — isso sim violaria o acordo de confidencialidade que todo
candidato assina ao fazer a prova.

## Árvore Domínio → Tópico

### 🟦 GCP — Professional Data Engineer (5 domínios)

| Domínio (peso) | Tópicos (viram `Topic` no catálogo) |
|---|---|
| 1. Designing data processing systems (~22%) | Segurança e Compliance no Design · Confiabilidade e Fidelidade no Design · Flexibilidade e Portabilidade · Migração de Dados |
| 2. Ingesting and processing the data (~25%) | Planejamento de Pipelines · Construção de Pipelines (batch/streaming) · Deploy e Operacionalização de Pipelines |
| 3. Storing the data (~20%) | Seleção de Sistema de Armazenamento · Data Warehouse (modelagem) · Data Lake · Design de Plataforma de Dados |
| 4. Preparing and using data for analysis (~15%) | Preparação para Visualização (BI) · Preparação para IA/ML · Compartilhamento de Dados |
| 5. Maintaining and automating data workloads (~18%) | Otimização de Recursos · Automação e Repetibilidade · Organização de Workloads · Monitoramento e Troubleshooting · Consciência de Falhas e Mitigação de Impacto *(estrutura completa confirmada via `pdftotext` do exam guide oficial em 2026-08-24 — tem 5.1 a 5.5, não só 2 itens como a suposição anterior)* |

**Já existe hoje**: domínio "Storing Data" com o tópico "BigQuery" (3 perguntas seed).

### 🟧 AWS — Data Engineer Associate (DEA-C01) (4 domínios)

| Domínio (peso) | Tópicos |
|---|---|
| 1. Data Ingestion and Transformation (34%) | Ingestão de Dados (batch/streaming) · Transformação e Processamento · Orquestração de Pipelines · Conceitos de Programação (CI/CD, IaC, SQL) |
| 2. Data Store Management (26%) | Escolha de Data Store · Catalogação de Dados · Ciclo de Vida dos Dados · Modelagem e Evolução de Schema |
| 3. Data Operations and Support (22%) | Automação de Processamento · Análise de Dados · Manutenção e Monitoramento de Pipelines · Qualidade de Dados |
| 4. Data Security and Governance (18%) | *(guia tem task statements 4.1-4.x — autenticação/autorização, criptografia, privacidade, governança, logging; detalhar na hora de escrever)* |

Nenhum conteúdo ainda — domínio novo no catálogo.

### 🟪 Azure — Fabric Data Engineer Associate (DP-700) (3 domínios)

| Domínio (peso) | Tópicos |
|---|---|
| 1. Implement and manage an analytics solution (30-35%) | Configuração do Workspace Fabric · Lifecycle Management (versionamento, deploy pipelines) · Segurança e Governança · Orquestração de Processos |
| 2. Ingest and transform data (30-35%) | Padrões de Carga (full/incremental) · Ingestão e Transformação Batch · Ingestão e Transformação Streaming |
| 3. Monitor and optimize an analytics solution (30-35%) | Monitoramento de Itens Fabric · Identificação e Resolução de Erros · Otimização de Performance |

Nenhum conteúdo ainda — certificação nova no catálogo (substitui a DP-203 descontinuada).

## Volume estimado

- **~11-14 tópicos por certificação** (34-38 no total das 3), considerando os domínios
  ainda não detalhados acima em GCP 5.x e AWS 4.x.
- Gate de domínio no app exige `MIN_QUESTIONS_SEEN_RATIO = 8/15` — na prática cada
  tópico precisa de **pelo menos ~15 perguntas** pra dar variedade real (sem repetir
  sempre as mesmas 8).
- **Estimativa total: ~35 tópicos × 15 perguntas ≈ 525 perguntas originais.**

Isso é um projeto de conteúdo grande — não dá pra escrever tudo numa tacada só com
qualidade. Proposta de ritmo:

1. **Fase 1 (piloto de formato)**: 1 domínio completo por cloud (3 domínios, ~10-12
   tópicos, ~150-180 perguntas) — valida formato de pergunta, explicações, e o processo
   de revisão antes de escalar pro resto.
2. **Fase 2+**: completar domínio por domínio, cloud por cloud, em lotes que dá pra
   revisar (ex: 1 domínio por vez, ~30-60 perguntas por lote).

## Formato de cada pergunta (mantendo o padrão já usado no seed)

- Enunciado com contexto realista (cenário curto, não só definição solta)
- 4 alternativas, 1 correta
- Explicação didática por alternativa (por que certa/errada) — é o que já existe em
  `scripts/seed_dev.py`, mantido igual

## Próximo passo técnico (antes de escrever a primeira pergunta)

O `scripts/seed_dev.py` atual tem as perguntas **hardcoded inline em Python** — funciona
para 3 perguntas, não para ~525. Antes de começar o conteúdo em volume, faz sentido
migrar pra arquivos de dados estruturados (ex: 1 YAML/JSON por certificação, carregado
pelo script de seed), separando "conteúdo" de "código de seed". Ver decisão em
[architecture-decisions.md](architecture-decisions.md) se for o caso de registrar isso lá.

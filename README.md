# CertFly

> Duolingo para certificações técnicas — sessões diárias curtas, com repetição espaçada e domínio por tópico, para quem estuda para certificações (começando por Google Cloud).

Side project solo, ainda em fase de spec/design — nenhuma linha de código de produto escrita ainda. Este repositório existe para versionar as decisões de produto e arquitetura à medida que amadurecem.

## Status atual (2026-08-06)

| Etapa | Status |
|---|---|
| Ideia validada (potencial real, nicho defensável) | ✅ |
| Pesquisa de mercado e concorrência | ✅ |
| Spec de MVP fechado | ✅ |
| Premissa arquitetural travada (agnóstico de provedor) | ✅ |
| Motor do core loop (SRS + % domínio + gate) | 🔄 desenhado, faltam 3 decisões de produto em aberto |
| Modelagem de domínio (entidades) | ⏳ próximo passo |
| System design (API, banco, deploy) | ⏳ |
| Setup do projeto + primeiro ciclo de TDD | ⏳ |

## Contexto

Origem do projeto: o dono é engenheiro de dados, estuda para certificações Google Cloud, e sente que o material disponível é fragmentado, denso, em inglês e sem estrutura de hábito. Ideia: um app estilo Duolingo que gamifica esse estudo.

Restrições de partida:
- Desenvolvedor solo (side project)
- Background forte em dados/backend, mais fraco em frontend/UX
- Quer projeto "bem feito": system design + TDD, não só "shippar rápido"
- Ambição inicial de MVP em ~1 mês (spec foi cortado agressivamente para caber nisso)

## Documentação

| Doc | O que tem |
|---|---|
| [`docs/market-research.md`](docs/market-research.md) | Tamanho de mercado, concorrentes (CloudLearn, Whizlabs, Tutorials Dojo), a ciência por trás do motor de repetição espaçada do Duolingo (HLR/SM-2/SuperMemo) |
| [`docs/product-spec.md`](docs/product-spec.md) | Spec de MVP consolidado: problema, hipótese, escopo de conteúdo, core loop, o que fica de fora, métrica de sucesso |
| [`docs/architecture-decisions.md`](docs/architecture-decisions.md) | Premissas arquiteturais travadas — modelagem 100% agnóstica de provedor/certificação |
| [`docs/core-loop-srs.md`](docs/core-loop-srs.md) | Motor de mastery e repetição espaçada (SM-2 adaptado) — fórmulas e perguntas de produto em aberto |

## Roadmap imediato

1. Resolver as 3 perguntas em aberto do motor do core loop (ver [`core-loop-srs.md`](docs/core-loop-srs.md))
2. Modelagem de domínio (entidades: Usuário, Certificação, Domínio, Questão, Tentativa, etc.)
3. System design (API, banco de dados, deploy)
4. Setup do projeto + primeiro ciclo de TDD

## Nota sobre origem deste documento

Este conjunto de docs foi reconstruído a partir de uma conversa no Claude.ai em 2026-08-06, recuperada e organizada via Claude Code. Pode haver pequenas lacunas em trechos intermediários da conversa original que não foram totalmente recuperados — revise e ajuste livremente.

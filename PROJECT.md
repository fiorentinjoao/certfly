# CertFly

> SaaS de gamificação de estudo para certificações técnicas — "Duolingo para certificações".

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

Origem do projeto: o dono é engenheiro de dados, estuda para certificações Google Cloud, sente que o material disponível é fragmentado, denso, em inglês e sem estrutura de hábito. Ideia: um app estilo Duolingo que gamifica esse estudo.

Restrições de partida:
- Desenvolvedor solo (side project)
- Background forte em dados/backend, mais fraco em frontend/UX
- Quer projeto "bem feito": system design + TDD, não só "shippar rápido"
- Ambição inicial de MVP em ~1 mês (spec foi cortado agressivamente para caber nisso)

## Documentos

- [Pesquisa de mercado e concorrência](docs/market-research.md)
- [Spec de produto do MVP](docs/product-spec.md)
- [Decisões de arquitetura](docs/architecture-decisions.md)
- [Motor do core loop — SRS e mastery](docs/core-loop-srs.md)

## Próximos passos

1. Resolver as 3 perguntas em aberto do motor do core loop (ver `core-loop-srs.md`)
2. Modelagem de domínio (entidades: Usuário, Certificação, Domínio, Questão, Tentativa, etc.)
3. System design (API, banco de dados, deploy)
4. Setup do projeto + primeiro ciclo de TDD

## Nota sobre origem deste documento

Este conjunto de docs foi reconstruído a partir de uma conversa no Claude.ai (chat "Greeting Claude") em 2026-08-06, recuperada e organizada via Claude Code. Pode haver pequenas lacunas em trechos intermediários da conversa original que não foram totalmente recuperados — revise e ajuste livremente.

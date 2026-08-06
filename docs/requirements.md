# Requisitos — MVP

> Requisitos funcionais e não funcionais do MVP, derivados do [product-spec.md](product-spec.md) e do [core-loop-srs.md](core-loop-srs.md). Servem de contrato entre produto e implementação — todo requisito aqui deve ser rastreável a um teste quando o código existir.

## Requisitos Funcionais (RF)

| ID | Requisito |
|---|---|
| RF-01 | O sistema deve permitir que o usuário se autentique via e-mail/senha **ou** OAuth Google |
| RF-02 | O sistema deve exibir ao usuário os domínios e tópicos da certificação ativa, cada um com seu % de domínio atual |
| RF-03 | O sistema deve gerar uma lição de 8-10 questões de um tópico, combinando questões novas e questões com revisão vencida (`due_date` passado) |
| RF-04 | Ao responder uma questão, o sistema deve exibir uma explicação didática de por que cada alternativa está certa ou errada |
| RF-05 | O sistema deve atualizar o estado de SRS da questão (`repetition_count`, `ease_factor`, `interval_days`, `due_date`) a cada resposta, segundo a regra SM-2 adaptada definida em `core-loop-srs.md` |
| RF-06 | O sistema deve recalcular o % de domínio do tópico após cada lição, com decaimento no tempo mesmo sem novas respostas |
| RF-07 | O sistema deve conceder XP ao usuário por questão respondida (10 XP se nova, 3 XP se revisão) |
| RF-08 | O sistema deve manter um contador de streak (dias consecutivos com ao menos 1 lição completa) |
| RF-09 | O sistema deve desbloquear o próximo tópico quando o % de domínio do tópico atual atingir 80% **e** o usuário tiver visto um mínimo de questões daquele tópico |
| RF-10 | O sistema deve registrar um histórico (log) de cada tentativa de resposta, independente do estado de SRS |
| RF-11 | O sistema deve exibir ao usuário, ao fim de cada lição, um resumo com XP ganho, streak atualizado e mudança no % de domínio |

## Requisitos Não Funcionais (RNF)

| ID | Categoria | Requisito |
|---|---|---|
| RNF-01 | Testabilidade | O motor de regras (SRS, mastery, gate, XP) deve ser implementado como lógica pura, sem dependência de banco/HTTP, testável via TDD isoladamente |
| RNF-02 | Extensibilidade | O schema de dados deve suportar múltiplos provedores/certificações/domínios sem alteração estrutural (ver `architecture-decisions.md`) |
| RNF-03 | Performance | Carregar uma lição (buscar questões + estado SRS do usuário) deve responder em menos de ~500ms sob carga de uso solo/baixo volume |
| RNF-04 | Segurança | Credenciais de autenticação nunca devem ser armazenadas em texto plano; comunicação sempre via HTTPS |
| RNF-05 | Custo | Sem monetização/receita no MVP — infraestrutura deve rodar dentro de tier gratuito/baixo custo |
| RNF-06 | Manutenibilidade | Solo dev deve conseguir entender/alterar qualquer parte do sistema sozinho — evitar complexidade desnecessária (sem microserviços, sem filas, monólito simples) |
| RNF-07 | Disponibilidade | Sem exigência de SLA formal no MVP, mas o app não deve perder dados de progresso do usuário (durabilidade > uptime) |
| RNF-08 | Usabilidade | Interface deve ser utilizável em sessões curtas (mobile-first, uso "no ônibus, no almoço") |
| RNF-09 | Idioma | Conteúdo (perguntas, explicações, interface) deve estar em português — endereça a dor original de material em inglês |

## Em aberto

- **Hosting/infra concreta**: ainda não decidido onde rodar (ex: GCP direto, ou algo mais simples tipo Railway/Render/Supabase para não lidar com infra GCP manualmente). Deve ser resolvido durante o system design (API, banco, deploy), respeitando RNF-05 e RNF-06.

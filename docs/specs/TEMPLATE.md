# SPEC-NNN: &lt;título curto&gt;

**Status:** Draft | Approved | Implemented | Superseded
**Autor:** &lt;nome&gt; · **Data:** YYYY-MM-DD
**Relacionado:** &lt;links pra outras specs/ADRs/memórias, se houver&gt;

> Por que este projeto usa SDD (Spec-Driven Development): o código aqui não é
> só "fazer funcionar" — é prática deliberada de arquitetura/engenharia de
> software (ver docs/product-spec.md). Escrever a spec antes do código força
> a pensar no problema, nas alternativas e nos riscos ANTES de comprometer
> com uma implementação — é o oposto de "codar primeiro, entender depois".
> Uma spec só vira código depois de **Approved**.

## 1. Contexto

Por que essa mudança existe agora? Qual sintoma/necessidade motivou? (link
pra memória, issue, conversa, etc. se vier de fora do código)

## 2. Problema

O que exatamente está errado ou faltando, hoje, no código real (não
hipotético). Cite arquivo:linha quando der.

## 3. Requisitos

- **Funcionais**: o que o sistema deve fazer depois da mudança
- **Não-funcionais**: performance, segurança, testabilidade, etc. — quando
  relevante

## 4. Modelo de ameaça *(só quando for mudança security-relevant)*

- Quem é o atacante (usuário autenticado mal-intencionado? não-autenticado?
  outro serviço?)
- O que ele ganha se o problema não for corrigido
- Qual o vetor exato (endpoint, parâmetro, sequência de chamadas)

## 5. Design / Abordagem

A solução proposta, com código-alvo (arquivo/função) quando fizer sentido.

**Alternativas consideradas** (e por que não foram escolhidas — isso é a
parte mais importante pra aprendizado, não só documentar a decisão final mas
o porquê ela venceu as outras):

| Alternativa | Prós | Contras | Descartada porque |
|---|---|---|---|

## 6. Plano de teste

Como provar que funciona E que o problema antigo não volta (teste de
regressão específico pro bug, não só teste genérico de feature).

## 7. Notas de rollout

Migração de dado necessária? Precisa de feature flag? Quebra algum client
existente (ex: dev.json, app já publicado)?

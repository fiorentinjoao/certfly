# Motor do core loop — SRS e mastery

> Regra de negócio pura, sem dependência de banco/API/frontend — candidata natural a ser a primeira coisa implementada com TDD.

## 1. Estado de cada questão (SRS por item)

Cada par usuário-questão guarda:

- `repetition_count` — quantas vezes acertou em sequência desde o último erro
- `ease_factor` (EF) — começa em 2.5; quanto "fácil" aquele item tem sido para esse usuário
- `interval_days` — quantos dias até a próxima revisão
- `due_date`

### Regra de atualização (SM-2 adaptado, binário — acertou ou errou, sem escala de 0-5 como o SM-2 original)

**Acertou:**
- `repetition_count += 1`
- Se `repetition_count == 1`: `interval = 1 dia`
- Se `repetition_count == 2`: `interval = 3 dias`
- Se `repetition_count >= 3`: `interval = round(interval_anterior * EF)`
- `EF = max(1.3, EF + 0.1)`

**Errou:**
- `repetition_count = 0`
- `interval = 0` (volta para a fila de revisão ainda na mesma sessão/no dia seguinte)
- `EF = max(1.3, EF - 0.2)`

Isso é o SM-2 clássico (usado pelo Anki), com os intervalos iniciais encurtados (1/3 dias em vez de 1/6) porque o contexto do produto é "sessão diária curta", não flashcard de vocabulário — o objetivo é reforço mais rápido no início.

## 2. De "questão individual" para "% de domínio do tópico"

Ponto mais delicado do design. Só contar "quantas questões já foram acertadas uma vez" faz o % nunca cair — mas na vida real o usuário esquece com o tempo (é literalmente o problema que motivou o Duolingo a criar o HLR, ver [market-research.md](market-research.md)).

Proposta para o MVP, mais simples que HLR mas ainda "viva": para cada questão já introduzida, calcular uma probabilidade estimada de lembrar agora:

```
p(questão) = 0.5 ^ (dias_desde_ultima_revisão / interval_atual)
```

`interval_atual` da própria questão é usado como proxy do "half-life" — uma aproximação grosseira do HLR, mas dá decaimento realista sem precisar de milhões de dados para treinar modelo.

```
% de domínio do tópico = média de p(questão) de todas as questões daquele tópico
```

(questões nunca vistas contam como 0)

Isso significa: a barra sobe quando o usuário acerta, e cai sozinha com o tempo se ele não revisita — comportamento desejado para criar urgência de voltar todo dia.

## 3. Gate de domínio (avançar de tópico)

Proposta: desbloqueia o próximo tópico quando `% domínio >= 80%` **e** o usuário já viu um mínimo de questões daquele tópico (ex: 8 de um pool de 15) — para evitar destravar com amostra pequena.

## 4. XP e streak

- XP fixo por questão respondida certa pela primeira vez (ex: 10 XP)
- XP menor por revisão bem-sucedida (ex: 3 XP) — recompensa mais quem aprende coisa nova, mas ainda incentiva revisão
- Streak: contador de dias consecutivos com pelo menos 1 lição completa (session-based, não importa quantas lições no dia)

## Perguntas em aberto (decisões de produto disfarçadas de matemática)

Ainda sem resposta do dono do projeto:

1. **Threshold de 80% para destravar tópico** — está bom, muito rígido ou muito frouxo?
2. **`interval_atual` como proxy de half-life** é uma simplificação grosseira — serve para o MVP (sem dados reais para calibrar melhor), ou vale um modelo mais preciso desde já?
3. **XP menor em revisão (3 vs 10)** faz sentido, ou deveria ser igual para não desincentivar revisão?

## Próximo passo depois de fechar essas 3 perguntas

Modelagem de domínio (entidades: Usuário, Certificação, Domínio, Questão, Tentativa, etc.) → system design (API, banco, deploy) → setup do projeto + primeiro ciclo de TDD.

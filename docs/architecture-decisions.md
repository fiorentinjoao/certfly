# Decisões de arquitetura (premissas travadas)

## Contexto

Depois da pesquisa de mercado (ver [market-research.md](market-research.md)) e da observação de que "gamificação de verdade" exige a mecânica estrutural do Duolingo (não só XP/badges/streak superficiais), o debate chegou a um conjunto de premissas arquiteturais que devem ser travadas **antes** do MVP, mesmo o MVP sendo estreito em conteúdo (uma única certificação, dois domínios).

## 1. Não travar em "dados" como regra de produto

A plataforma não deve ser hardcoded para certificações de dados. Dados é só o ponto de partida de **conteúdo**, porque é onde o dono tem profundidade para escrever perguntas boas rápido — isso é decisão de conteúdo, não de arquitetura. Ninguém deve precisar reescrever nada estrutural para adicionar AWS, Azure ou Terraform depois. O nome do produto (CertFly) já reflete essa premissa — não trava em nenhum provedor específico ("cloud", "GCP", etc.).

## 2. Modelagem de domínio 100% agnóstica de provedor

Hierarquia proposta:

```
Provedor (Google Cloud, AWS, Azure...)
  → Certificação (Professional Data Engineer...)
    → Domínio do exame (Storing Data...)
      → Tópico
        → Questão
```

Nada de código, schema de banco ou nome de tabela específico do GCP. GCP é só o primeiro conteúdo carregado no sistema, não uma decisão estrutural.

## 3. O "motor" (mastery + repetição espaçada) precisa ser genérico por design

O motor de cálculo de domínio e repetição espaçada opera sobre "tópico" e "questão" abstratos, sem saber se é BigQuery ou um serviço da AWS. Isso já era o plano, mas agora vira requisito não-negociável, não só boa prática — ver [core-loop-srs.md](core-loop-srs.md).

## 4. Pipeline de criação de conteúdo replicável

Hoje as questões de GCP são escritas manualmente com a expertise do dono, mas o processo (formato de pergunta, formato de explicação, critério de revisão de qualidade) precisa ser documentado como um **template reutilizável** — para quando o próprio dono (ou colaboradores futuros) forem escrever conteúdo de outro provedor, o processo não precisa ser reinventado do zero.

## 5. Multi-provedor não entra no MVP, mas nenhuma decisão do MVP pode criar dívida técnica que impeça expansão depois

Continua fazendo sentido nascer só com conteúdo GCP no MVP (pelas razões já discutidas: profundidade do dono, velocidade de gerar conteúdo bom). A diferença é: **nenhuma decisão técnica do MVP pode criar dívida técnica que impeça a expansão depois.** Qualquer proposta futura que "funcione mas prenda no GCP" deve ser questionada antes de entrar.

## Nomenclatura

Nome do produto definido: **CertFly**.

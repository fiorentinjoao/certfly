---
name: certfly-content-gen
description: Gera rascunhos de perguntas de certificação (GCP/AWS/Azure) embasados na documentação OFICIAL do produto (não em exam guides nem em bancos de questões vazados), com fact-check automático contra a fonte antes de qualquer coisa entrar no conteúdo real do app. Use quando o usuário pedir para "gerar perguntas", "criar conteúdo pro tópico X", "expandir o content/<cert>.yaml" ou similar.
---

## Propósito

CertFly precisa de ~15 perguntas por tópico (ver `docs/content-plan.md`) pra
alimentar o motor de SRS/mastery. Escrever isso manualmente é o maior gargalo
pro MVP. Essa skill gera rascunhos com uma LLM (você, Claude), mas com uma
regra dura: **toda pergunta precisa ser embasada num trecho real de
documentação oficial do produto**, nunca inventada de memória e nunca
parafraseada de um banco de questões de certificação real (isso violaria a
regra legal registrada em `docs/content-plan.md`: perguntas de exame reais
são confidenciais, documentação de produto é pública).

## Pré-requisito: leia antes de gerar

- `docs/content-plan.md` — árvore domínio → tópico de cada certificação, e a
  regra legal sobre fontes.
- `docs/content-sources.md` — mapa tópico → URLs de documentação oficial já
  levantadas (se o tópico pedido não estiver lá, procure a doc oficial do
  produto correspondente e adicione a entrada nesse arquivo).
- O YAML da certificação já existente em `content/<cert>.yaml`, pra não gerar
  pergunta duplicada de algo que já existe no tópico.

## Pipeline (passo a passo)

1. **Escopo**: confirme com o usuário (ou infira do pedido) certificação +
   domínio + tópico + quantas perguntas gerar (padrão: 3-5 por rodada — não
   tente gerar as ~15 de um tópico numa passada só, fica difícil revisar).

2. **Grounding**: use `WebFetch` para buscar a(s) URL(s) de documentação
   oficial do tópico (de `docs/content-sources.md`, ou pesquise se não
   existir). Extraia fatos concretos, números, nomes de recursos/comandos —
   não resuma vagamente, colete o suficiente para basear cada pergunta num
   fato verificável.

3. **Geração**: escreva as perguntas no formato exato usado em
   `content/*.yaml` (`prompt`, 4 `choices`, exatamente 1 `correct: true`,
   `explanation` em toda alternativa — certa e errada). Cada pergunta ganha
   dois campos extras (ignorados pelo `seed_dev.py`, só para rastreabilidade):
   - `source_url`: a URL exata usada como grounding daquela pergunta
   - `verified`: preenchido no passo 4, nunca `true` de saída

   Cenários realistas (não pergunta de definição solta) seguem melhor o
   padrão já usado no seed existente — veja exemplos em `content/*.yaml`.

4. **Verificação (obrigatória, não pule)**: para cada pergunta gerada, releia
   o trecho da doc que você buscou no passo 2 e confira se o `prompt` +
   `explanation` de cada alternativa estão factualmente corretos segundo
   aquele trecho — não segundo memória geral do modelo. Só marque
   `verified: true` se a alternativa correta e TODAS as explicações batem com
   a fonte. Se alguma pergunta falhar, descarte-a ou reescreva e verifique de
   novo — não inclua no draft com `verified: false` esperando que o usuário
   conserte.

5. **Escreva o draft**: salve em
   `content/_drafts/<cert>-<topico>.draft.yaml` com este formato de topo:

   ```yaml
   certification: <slug, ex: gcp-pde>
   domain_slug: <slug do domínio, precisa bater com content/<cert>.yaml>
   topic_slug: <slug do tópico>
   questions:
     - prompt: ...
       source_url: ...
       verified: true
       choices: [...]
   ```

   NUNCA escreva direto em `content/<cert>.yaml` — sempre passe pelo draft.

6. **Avise o usuário**: resuma quantas perguntas foram geradas, quantas
   passaram na verificação, e peça revisão humana antes do merge. Não rode o
   merge sozinho sem essa confirmação, a menos que o usuário já tenha pedido
   explicitamente "gera e já mescla".

7. **Merge (só depois da aprovação humana)**: rode
   `python3 scripts/merge_content_draft.py content/_drafts/<arquivo>.draft.yaml`.
   Isso funde só as perguntas `verified: true` no YAML final, criando
   domínio/tópico se ainda não existirem, e nunca sobrescreve perguntas já
   existentes. Rode `backend/.venv/bin/python scripts/seed_dev.py` depois
   pra confirmar que o YAML resultante ainda carrega sem erro.

## O que NÃO fazer

- Não gerar pergunta sem ter buscado a doc de verdade no passo 2 — "eu sei
  isso de cor" não é grounding válido aqui, é exatamente o risco que esse
  pipeline existe pra evitar.
- Não usar bancos de questões de certificação reais (braindumps, PDFs de
  "questões que caíram na prova") como fonte, mesmo que apareçam nos
  resultados de busca — isso é o que a regra legal do `content-plan.md`
  proíbe. Só documentação oficial do produto/serviço.
- Não pular a etapa de verificação pra ir mais rápido — é o único freio
  contra alucinação técnica indo pro conteúdo real do app.
- Não commitar o resultado do merge automaticamente — deixe pro usuário
  revisar o diff de `content/<cert>.yaml` e decidir quando commitar.

# Pesquisa de mercado e concorrência

## Validação de mercado (tamanho/demanda)

- Mercado global de IT training atingiu ~US$82,4 bilhões em 2025 (Technavio, IMARC) — número grande o suficiente para confirmar que "gente paga por preparação de certificação" não é a dúvida; a dúvida real é quanto desse bolo dá para capturar num nicho GCP gamificado.
- GCP está crescendo ~35% ao ano, com maior demanda concentrada justamente em Professional Cloud Architect e Data Engineer (Hakia).
- Empresas que investiram pesado em Google Cloud hoje têm dificuldade de achar profissionais que realmente saibam usar a plataforma — esse gap de oferta se traduz direto em prêmio salarial para quem é certificado (Precisionalacademy).
- Sinal quantitativo direto de demanda pela certificação específica: o curso oficial do Google no Coursera ("Preparing for your Professional Data Engineer Journey") tem 48.697 pessoas já inscritas e 1.014 avaliações com nota 4,6 — e isso é só um canal (Coursera), sem contar Udemy, YouTube, dumps, etc.
- A prova tem taxa de aprovação de aproximadamente 55% — quase metade reprova, o que motiva buscar melhores formas de se preparar (ExamCert).

## Validação mais forte: já existe alguém cobrando por isso

**CloudLearn** (cloudlearn.app) já roda um produto muito próximo da ideia — cobrando entre €9,99 e €19,99/mês por exatamente esse tipo de produto (quiz + XP + streak + badges), focado em AWS. Alguém validou com dinheiro real que esse modelo funciona nesse nicho adjacente.

### O que o CloudLearn (e similares) realmente têm

- Pontuação (XP), selos (badges), contador de streak
- Quiz adaptativo avulso, flashcards soltos, "quiz builder" onde o usuário escolhe serviço/quantidade de perguntas

### O que falta neles e o Duolingo tem de verdade

Ponto de atenção levantado durante o debate: "gamificação" no CloudLearn e afins é XP/badges/streak colados em cima de um banco de quiz — não é o mecanismo estrutural do Duolingo. São coisas diferentes:

- **Trilha estruturada e obrigatória** — o usuário não escolhe "quero praticar X hoje"; o app decide a próxima lição dentro de uma progressão desenhada
- **Unidades pequenas com gate de domínio** — só avança para a próxima unidade depois de demonstrar competência mínima na atual, não é livre-escolha
- **Vidas/corações** — penalidade por errar, cria tensão e cuidado na resposta (mecânica de risco/perda)
- **Árvore de habilidades visual** — o progresso é visto como um mapa de caminho, não como uma % numa lista

Conclusão: o que existe hoje no mercado adjacente é "quiz bank com vitaminas de gamificação", não a experiência estrutural do Duolingo. Essa é a lacuna que o produto se propõe a ocupar — trazendo a mecânica estrutural real do Duolingo, não só o verniz visual (XP/badges/streak).

## A ciência por trás do "motor" (Duolingo e cia)

- O próprio Duolingo desenvolveu o **half-life regression (HLR)**, um modelo treinável de repetição espaçada que une teoria psicolinguística com machine learning, treinado sobre 13 milhões de "traços de aprendizado" capturando acerto/erro, tempo de resposta e tempo desde a última exposição de cada item. É mais sofisticado que métodos clássicos porque prediz a probabilidade de recall com base no tempo decorrido desde a última prática, em vez de usar intervalos fixos como Leitner/SM-2.
  - Overkill para o MVP deste projeto (precisa de dataset gigante para treinar).
- O padrão-ouro mais simples e citado como base de tudo isso é o **SuperMemo**, onde o algoritmo prediz curvas de esquecimento individuais por item e agenda repetições para acontecer quando a probabilidade estimada de recall cai a um patamar-alvo (tipicamente 90%).
  - Isso é bem mais viável de implementar num mês — é o modelo recomendado como ponto de partida (SM-2 simplificado), não HLR.

## Concorrência "tradicional" (bancos de questão estático)

Whizlabs, Tutorials Dojo, ExamTopics, MeasureUp, CertBase — todos vivem de banco de questões + explicação, sem gamificação de hábito. Tutorials Dojo é conhecido por exames que espelham a dificuldade real, especialmente para AWS, vendidos como pacote único por certificação; Whizlabs é uma plataforma de assinatura tudo-incluído com labs e vídeo-aulas. Nenhum deles tem streak, XP ou repetição espaçada de verdade — é "prova simulada", não "hábito diário". Esse é o espaço que o produto mira ocupar.

## Leitura geral

Já existe um concorrente direto rodando exatamente a ideia de "gamificar estudo de certificação" (CloudLearn, focado em AWS) — o que valida a demanda, mas também confirma que o diferencial real não pode ser só "ter XP e streak". Precisa ser a mecânica estrutural do Duolingo (trilha obrigatória, gate de domínio, repetição espaçada de verdade) combinada com o gap de conteúdo bem feito e didático (explicação de cada alternativa, não só "resposta certa: C").

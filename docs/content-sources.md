# Fontes de documentação oficial para geração de conteúdo

Mapa tópico → URL(s) de documentação oficial do produto, usado pela skill
`certfly-content-gen` (`.claude/skills/certfly-content-gen/SKILL.md`) como
grounding para gerar perguntas. Diferente do `docs/content-plan.md` (que
mapeia a estrutura pública dos *exam guides*), este arquivo aponta pra
documentação técnica do produto em si — a fonte de fatos verificáveis pra
cada pergunta.

Regra: só documentação oficial do produto/serviço. Nunca bancos de questões
de certificação reais (braindumps), mesmo que apareçam numa busca.

## GCP — Professional Data Engineer

| Tópico (slug) | URLs oficiais |
|---|---|
| `bigquery` | https://cloud.google.com/bigquery/docs/partitioned-tables · https://cloud.google.com/bigquery/docs/clustered-tables · https://cloud.google.com/bigquery/docs/external-data-cloud-storage |
| `bancos-operacionais` | https://cloud.google.com/sql/docs/mysql/high-availability · https://cloud.google.com/alloydb/docs/columnar-engine/about |
| `planejamento-pipelines` | https://cloud.google.com/dataflow/docs/concepts/streaming-pipelines |
| `construcao-pipelines` | https://cloud.google.com/dataflow/docs/concepts/beam-programming-model · https://cloud.google.com/dataproc/docs/concepts/overview |
| `deploy-operacionalizacao` | https://cloud.google.com/composer/docs/composer-2/composer-overview · https://cloud.google.com/dataflow/docs/concepts/dataflow-templates |
| `preparacao-visualizacao` | https://cloud.google.com/bigquery/docs/bi-engine-intro |
| `preparacao-ia-ml` | https://cloud.google.com/bigquery/docs/bqml-introduction |
| `compartilhamento-dados` | https://cloud.google.com/bigquery/docs/analytics-hub-introduction · https://cloud.google.com/bigquery/docs/authorized-views |
| `seguranca-compliance-design` | https://cloud.google.com/iam/docs/overview · https://cloud.google.com/kms/docs/key-management-service · https://cloud.google.com/sensitive-data-protection/docs |
| `confiabilidade-fidelidade-design` | https://cloud.google.com/dataform/docs/overview · https://cloud.google.com/dataflow/docs/guides/monitoring-overview |
| `flexibilidade-portabilidade` | https://cloud.google.com/dataplex/docs/introduction |
| `migracao-dados` | https://cloud.google.com/bigquery/docs/dts-introduction · https://cloud.google.com/database-migration/docs/mysql/quickstart |
| `otimizacao-recursos` | https://cloud.google.com/dataproc/docs/concepts/overview |
| `automacao-repetibilidade` | https://cloud.google.com/composer/docs/composer-2/write-dags |
| `organizacao-workloads` | https://cloud.google.com/bigquery/docs/editions-intro |
| `monitoramento-troubleshooting` | https://cloud.google.com/bigquery/docs/information-schema-intro · https://cloud.google.com/logging/docs/overview |
| `consciencia-falhas-mitigacao` | https://cloud.google.com/sql/docs/mysql/replication · https://cloud.google.com/memorystore/docs/redis/redis-overview |

## AWS — Data Engineer Associate (DEA-C01)

_(ainda não mapeado — adicionar URLs de docs.aws.amazon.com conforme os
tópicos de `docs/content-plan.md` forem trabalhados)_

## Azure — Fabric Data Engineer Associate (DP-700)

_(ainda não mapeado — adicionar URLs de learn.microsoft.com/fabric conforme
os tópicos de `docs/content-plan.md` forem trabalhados)_

## Como adicionar uma entrada nova

Ao gerar conteúdo pra um tópico que ainda não está aqui: encontre a página
de documentação oficial do produto que cobre esse tópico, adicione a linha
na tabela correspondente, e só então gere as perguntas — isso mantém o mapa
crescendo junto com o conteúdo real, em vez de ficar um documento à parte
que desatualiza.

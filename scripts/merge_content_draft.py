#!/usr/bin/env python3
"""Funde um rascunho aprovado (content/_drafts/*.draft.yaml, gerado pelo
pipeline de content-gen — ver docs/content-gen-pipeline.md) dentro do YAML
final de uma certificação em content/.

Só funde perguntas com `verified: true`. Recusa apagar/sobrescrever
perguntas já existentes — só adiciona ao final da lista de `questions` do
tópico (cria o domínio/tópico se ainda não existir no YAML de destino).

Uso:
    python3 scripts/merge_content_draft.py content/_drafts/gcp-pde-bigquery-partitioning.draft.yaml

Depois de rodar, revise o diff em content/<cert>.yaml antes de commitar —
este script não deleta o rascunho automaticamente.
"""

import sys
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parent.parent
CONTENT_DIR = REPO_ROOT / "content"


def load_yaml(path: Path) -> dict:
    return yaml.safe_load(path.read_text()) or {}


def find_or_create(items: list, slug: str, factory) -> dict:
    for item in items:
        if item.get("slug") == slug:
            return item
    new_item = factory()
    items.append(new_item)
    return new_item


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit(f"Uso: {sys.argv[0]} <caminho-do-draft.yaml>")

    draft_path = Path(sys.argv[1])
    draft = load_yaml(draft_path)

    certification_slug = draft.get("certification")
    domain_slug = draft.get("domain_slug")
    topic_slug = draft.get("topic_slug")
    questions = draft.get("questions", [])
    if not (certification_slug and domain_slug and topic_slug):
        raise SystemExit(
            "Draft precisa ter 'certification', 'domain_slug' e 'topic_slug' no topo."
        )

    target_path = CONTENT_DIR / f"{certification_slug}.yaml"
    if not target_path.exists():
        raise SystemExit(
            f"{target_path} não existe — crie o YAML da certificação primeiro."
        )

    target = load_yaml(target_path)

    approved = [q for q in questions if q.get("verified") is True]
    skipped = len(questions) - len(approved)
    if not approved:
        raise SystemExit(
            "Nenhuma pergunta com verified: true neste draft — nada a fazer."
        )

    domain = find_or_create(
        target.setdefault("domains", []),
        domain_slug,
        lambda: {
            "name": domain_slug,
            "slug": domain_slug,
            "weight_pct": 0,
            "order": 0,
            "topics": [],
        },
    )
    topic = find_or_create(
        domain.setdefault("topics", []),
        topic_slug,
        lambda: {"name": topic_slug, "slug": topic_slug, "order": 0, "questions": []},
    )
    topic.setdefault("questions", [])

    for question in approved:
        # Remove metadados do pipeline (source_url/verified) — não fazem
        # parte do schema consumido por scripts/seed_dev.py.
        clean_question = {
            k: v for k, v in question.items() if k not in ("source_url", "verified")
        }
        topic["questions"].append(clean_question)

    target_path.write_text(
        yaml.dump(target, allow_unicode=True, sort_keys=False, width=80)
    )

    print(
        f"✓ {len(approved)} pergunta(s) mescladas em {target_path.name} "
        f"({domain_slug} → {topic_slug})."
    )
    if skipped:
        print(f"  {skipped} pergunta(s) ignoradas (verified != true) — reveja o draft.")


if __name__ == "__main__":
    main()

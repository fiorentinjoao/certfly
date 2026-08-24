#!/usr/bin/env python3
"""Seed de conteúdo (a partir de content/*.yaml) no backend + gera
frontend/dev.json com um JWT de teste — pra rodar o app Flutter localmente
sem precisar de um projeto Supabase real ainda (ver docs/requirements.md,
seção "Em aberto", e frontend/lib/auth/auth_gateway.dart).

O conteúdo em si (provedores/certificações/domínios/tópicos/perguntas) NÃO
mora mais neste script — vive em arquivos de dados versionados separados,
um por certificação, em content/*.yaml (ver docs/content-plan.md pro
formato e o plano de volume). Isso existe pra content authoring (escrever
centenas de perguntas) não virar um arquivo Python gigante e ilegível.

Uso (a partir da raiz do repo, com o venv do backend já criado):

    backend/.venv/bin/python scripts/seed_dev.py

Depois, suba o backend com o MESMO secret usado aqui:

    cd backend && SUPABASE_JWT_SECRET=dev-only-secret-nao-usar-em-producao \
        .venv/bin/uvicorn app.main:app

E rode o app apontando pro dev.json gerado (a certificação usada no
dev.json é a PRIMEIRA lida em ordem alfabética de arquivo — hoje
aws-dea-c01.yaml; troque manualmente o certificationId no dev.json se
quiser testar outra):

    cd frontend && flutter run -d linux --dart-define-from-file=dev.json

Idempotente: apaga o certfly.db anterior antes de semear de novo.
"""

import json
import os
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parent.parent
BACKEND_DIR = REPO_ROOT / "backend"
CONTENT_DIR = REPO_ROOT / "content"
sys.path.insert(0, str(BACKEND_DIR))

# DATABASE_URL default (app/repository/db.py) é relativo ao cwd do
# PROCESSO Python, não deste arquivo — sem isso, rodar o script da raiz do
# repo (uso documentado acima) grava num certfly.db na raiz, diferente do
# backend/certfly.db que o uvicorn abre quando sobe a partir de backend/.
os.chdir(BACKEND_DIR)
Path("certfly.db").unlink(missing_ok=True)

import jwt  # noqa: E402

from app.repository.db import Base, SessionLocal, engine  # noqa: E402
from app.repository.orm_models import (  # noqa: E402
    CertificationORM,
    ChoiceORM,
    DomainORM,
    ProviderORM,
    QuestionORM,
    TopicORM,
)

DEV_JWT_SECRET = "dev-only-secret-nao-usar-em-producao"


def load_content_file(db, path: Path) -> CertificationORM:
    """Lê um YAML de content/ e cria provider/certification/domain/topic/
    question/choice correspondentes. Cada execução do script recria o
    banco do zero (ver unlink acima), então isso sempre faz INSERT puro —
    sem lógica de upsert/dedup."""
    data = yaml.safe_load(path.read_text())

    provider = ProviderORM(id=uuid.uuid4(), **data["provider"])
    certification = CertificationORM(
        id=uuid.uuid4(),
        provider_id=provider.id,
        **data["certification"],
    )
    db.add_all([provider, certification])

    question_count = 0
    for domain_data in data["domains"]:
        topics_data = domain_data.pop("topics")
        domain = DomainORM(
            id=uuid.uuid4(), certification_id=certification.id, **domain_data
        )
        db.add(domain)

        for topic_data in topics_data:
            questions_data = topic_data.pop("questions")
            topic = TopicORM(id=uuid.uuid4(), domain_id=domain.id, **topic_data)
            db.add(topic)

            for question_data in questions_data:
                question = QuestionORM(
                    id=uuid.uuid4(),
                    topic_id=topic.id,
                    prompt=question_data["prompt"],
                    status="active",
                )
                db.add(question)
                question_count += 1
                for choice_data in question_data["choices"]:
                    db.add(
                        ChoiceORM(
                            id=uuid.uuid4(),
                            question_id=question.id,
                            text=choice_data["text"],
                            is_correct=choice_data["correct"],
                            explanation=choice_data["explanation"],
                        )
                    )

    print(f"✓ {path.name}: {question_count} perguntas em '{certification.name}'.")
    return certification


def main() -> None:
    Base.metadata.create_all(engine)
    db = SessionLocal()

    content_files = sorted(CONTENT_DIR.glob("*.yaml"))
    if not content_files:
        raise SystemExit(f"Nenhum arquivo .yaml encontrado em {CONTENT_DIR}")

    certifications = [load_content_file(db, path) for path in content_files]
    db.commit()

    user_id = uuid.uuid4()
    token = jwt.encode(
        {
            "sub": str(user_id),
            "email": "dev@example.com",
            "aud": "authenticated",
            "iat": datetime.now(timezone.utc),
        },
        DEV_JWT_SECRET,
        algorithm="HS256",
    )

    # Primeira certificação (ordem alfabética de arquivo) vira a default do
    # dev.json — troque certificationId manualmente pra testar outra.
    dev_config = {
        "apiBaseUrl": "http://localhost:8000",
        "devToken": token,
        "certificationId": str(certifications[0].id),
    }
    dev_json_path = REPO_ROOT / "frontend" / "dev.json"
    dev_json_path.write_text(json.dumps(dev_config, indent=2))

    print(
        f"✓ config de dev escrita em {dev_json_path} (certificação: {certifications[0].name})"
    )


if __name__ == "__main__":
    main()

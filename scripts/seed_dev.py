#!/usr/bin/env python3
"""Seed de conteúdo de exemplo no backend + gera frontend/dev.json com um
JWT de teste — pra rodar o app Flutter localmente sem precisar de um
projeto Supabase real ainda (ver docs/requirements.md, seção "Em aberto",
e frontend/lib/auth/auth_gateway.dart).

Uso (a partir da raiz do repo, com o venv do backend já criado):

    backend/.venv/bin/python scripts/seed_dev.py

Depois, suba o backend com o MESMO secret usado aqui:

    cd backend && SUPABASE_JWT_SECRET=dev-only-secret-nao-usar-em-producao \
        .venv/bin/uvicorn app.main:app

E rode o app apontando pro dev.json gerado:

    cd frontend && flutter run -d linux --dart-define-from-file=dev.json

Idempotente: apaga o certfly.db anterior antes de semear de novo.
"""

import json
import os
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
BACKEND_DIR = REPO_ROOT / "backend"
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

QUESTIONS = [
    (
        "Qual tipo de tabela do BigQuery reduz custo de consultas filtrando por "
        "uma coluna de data?",
        [
            (
                "Tabela particionada por data",
                True,
                "Particionar por data faz o BigQuery escanear só as partições "
                "relevantes, reduzindo bytes lidos e custo.",
            ),
            (
                "Tabela clusterizada por STRING",
                False,
                "Clustering ajuda em filtros/agrupamentos, mas não é a técnica "
                "específica pra reduzir custo em filtros de data.",
            ),
            (
                "View materializada",
                False,
                "Views materializadas aceleram consultas repetidas, mas não são "
                "a resposta pra particionamento por data.",
            ),
        ],
    ),
    (
        "Qual comando cria uma tabela externa no BigQuery apontando pro Cloud Storage?",
        [
            (
                "CREATE OR REPLACE EXTERNAL TABLE",
                True,
                "É o comando padrão do BigQuery pra registrar uma tabela externa "
                "sobre dados no GCS.",
            ),
            (
                "CREATE VIEW",
                False,
                "CREATE VIEW cria uma view lógica sobre uma query, não uma "
                "tabela externa sobre arquivos.",
            ),
            (
                "CREATE MATERIALIZED VIEW",
                False,
                "Materialized view pré-computa resultados de uma query; não "
                "aponta pra arquivos externos.",
            ),
        ],
    ),
    (
        "Qual serviço do Google Cloud é um banco NoSQL de baixa latência para "
        "séries temporais e IoT?",
        [
            (
                "Bigtable",
                True,
                "Bigtable é o banco NoSQL wide-column do GCP voltado a alta "
                "taxa de escrita/leitura, ideal pra séries temporais e IoT.",
            ),
            (
                "Firestore",
                False,
                "Firestore é um banco de documentos voltado a apps mobile/web, "
                "não otimizado pro perfil de série temporal em altíssima escala.",
            ),
            (
                "Cloud SQL",
                False,
                "Cloud SQL é relacional (Postgres/MySQL), não o encaixe pra "
                "esse padrão de acesso.",
            ),
        ],
    ),
]


def main() -> None:
    Base.metadata.create_all(engine)
    db = SessionLocal()

    provider = ProviderORM(id=uuid.uuid4(), name="Google Cloud", slug="google-cloud")
    certification = CertificationORM(
        id=uuid.uuid4(),
        provider_id=provider.id,
        name="Professional Data Engineer",
        slug="gcp-pde",
    )
    domain = DomainORM(
        id=uuid.uuid4(),
        certification_id=certification.id,
        name="Storing Data",
        slug="storing-data",
        order=1,
    )
    topic = TopicORM(id=uuid.uuid4(), domain_id=domain.id, name="BigQuery", slug="bigquery", order=1)

    question_rows = []
    for prompt, choices in QUESTIONS:
        question = QuestionORM(id=uuid.uuid4(), topic_id=topic.id, prompt=prompt, status="active")
        question_rows.append(question)
        db.add(question)
        for text, is_correct, explanation in choices:
            db.add(
                ChoiceORM(
                    id=uuid.uuid4(),
                    question_id=question.id,
                    text=text,
                    is_correct=is_correct,
                    explanation=explanation,
                )
            )

    db.add_all([provider, certification, domain, topic])
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

    dev_config = {
        "apiBaseUrl": "http://localhost:8000",
        "devToken": token,
        "certificationId": str(certification.id),
    }
    dev_json_path = REPO_ROOT / "frontend" / "dev.json"
    dev_json_path.write_text(json.dumps(dev_config, indent=2))

    print(f"✓ {len(question_rows)} questões de exemplo criadas em '{topic.name}'.")
    print(f"✓ config de dev escrita em {dev_json_path}")
    print()
    print("Suba o backend com o MESMO secret:")
    print(f"  cd backend && SUPABASE_JWT_SECRET={DEV_JWT_SECRET} .venv/bin/uvicorn app.main:app")
    print()
    print("Rode o app:")
    print("  cd frontend && flutter run -d linux --dart-define-from-file=dev.json")


if __name__ == "__main__":
    main()

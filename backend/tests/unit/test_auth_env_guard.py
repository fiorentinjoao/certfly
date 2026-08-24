"""Regressão de segurança: SUPABASE_JWT_SECRET (fallback dev-only de
tokens HS256 forjados localmente) nunca pode coexistir com
ENVIRONMENT=production — ver docstring/guard em app/auth.py."""

import importlib
import sys

import pytest


def _reimport_auth_with_env(monkeypatch, **env):
    monkeypatch.delenv("SUPABASE_JWT_SECRET", raising=False)
    monkeypatch.delenv("ENVIRONMENT", raising=False)
    for key, value in env.items():
        monkeypatch.setenv(key, value)

    # app.auth chama load_dotenv() no import — sem isolar, ele reinjeta
    # variáveis de backend/.env (o .env real de dev, gitignored) por cima
    # do que acabamos de limpar acima, mascarando o próprio cenário que o
    # teste quer simular.
    monkeypatch.setattr("dotenv.load_dotenv", lambda *a, **k: None)

    sys.modules.pop("app.auth", None)
    return importlib.import_module("app.auth")


def test_producao_com_jwt_secret_recusa_subir(monkeypatch):
    with pytest.raises(RuntimeError, match="SUPABASE_JWT_SECRET"):
        _reimport_auth_with_env(
            monkeypatch,
            ENVIRONMENT="production",
            SUPABASE_JWT_SECRET="algum-secret",
            SUPABASE_URL="https://example.supabase.co",
        )


def test_producao_sem_jwt_secret_sobe_normalmente(monkeypatch):
    module = _reimport_auth_with_env(
        monkeypatch,
        ENVIRONMENT="production",
        SUPABASE_URL="https://example.supabase.co",
    )
    assert module.SUPABASE_JWT_SECRET is None


def test_dev_com_jwt_secret_continua_permitido(monkeypatch):
    module = _reimport_auth_with_env(
        monkeypatch, ENVIRONMENT="development", SUPABASE_JWT_SECRET="dev-only-secret"
    )
    assert module.SUPABASE_JWT_SECRET == "dev-only-secret"

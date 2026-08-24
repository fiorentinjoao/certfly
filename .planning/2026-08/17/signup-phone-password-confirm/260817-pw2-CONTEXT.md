# Quick Task 260817-pw2: Adicionar telefone e confirmação de senha na tela de criação de conta - Context

**Gathered:** 2026-08-17
**Status:** Ready for planning

<domain>
## Task Boundary

Adicionar campo de número de telefone e campo de confirmação de senha na tela de
criação de conta (`frontend/lib/screens/login_screen.dart`, modo `isSignUp`). A
tela hoje usa Supabase Auth (`signUp` com email/password) e só tem 2 campos
(e-mail, senha).

</domain>

<decisions>
## Implementation Decisions

### Persistência do telefone
- Salvar via `user_metadata` do Supabase (`data:` no `signUp()`), não no backend
  FastAPI. Zero mudança de schema/endpoint no backend — o dado fica junto de
  outros metadados do usuário (ex: avatar/nome do Google OAuth).

### Formato/validação do telefone
- Campo obrigatório, com **máscara estruturada BR**: `(XX) XXXXX-XXXX`
  (DDD de 2 dígitos + 9 dígitos, formato celular).
- Formatação automática enquanto o usuário digita (TextInputFormatter).
- Validação: rejeitar se não completar os 11 dígitos (DDD + número).

### Confirmação de senha
- Campo client-side puro, sem chamada extra ao Supabase.
- Validação: valor deve ser idêntico ao campo de senha.
- Mostrar apenas no modo `isSignUp` (login continua com 1 campo de senha só).

### Claude's Discretion
- Nome exato da chave no `user_metadata` (ex: `phone`).
- Se salvar os dígitos crus ou já formatados no metadata (a task não travou isso).
- Detalhes de UI (labels, ordem dos campos, ícones).

</decisions>

<specifics>
## Specific Ideas

Nenhuma referência visual específica — seguir o padrão visual já existente na
tela (TextFormField + AppTheme.dark(), mesmo estilo dos campos de e-mail/senha
atuais).

</specifics>

<canonical_refs>
## Canonical References

No external specs — requirements fully captured in decisions above.

</canonical_refs>

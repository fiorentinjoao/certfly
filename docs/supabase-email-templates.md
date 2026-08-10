# Templates de e-mail do CertFly (Supabase Auth)

Onde colar: painel do Supabase → **Authentication → Emails → Templates**
(ver: https://supabase.com/dashboard/project/_/auth/templates)

Pra cada template abaixo: troque o **Subject heading** e cole o **HTML body**.
As variáveis `{{ .ConfirmationURL }}` etc. são do próprio Supabase — mantenha
exatamente como estão, só o texto ao redor muda.

---

## 1. Confirm signup (cadastro)

**Subject:** Confirme seu e-mail no CertFly 🐼

**Body:**
```html
<div style="background-color:#111827;padding:40px 20px;font-family:Verdana,Arial,sans-serif;">
  <table role="presentation" width="100%" style="max-width:420px;margin:0 auto;background-color:#1B2333;border-radius:18px;border:2px solid #2E3750;overflow:hidden;">
    <tr>
      <td style="padding:32px 28px;text-align:center;">
        <div style="font-size:32px;font-weight:900;color:#F3F4F6;letter-spacing:-0.5px;margin-bottom:4px;">
          CertFly
        </div>
        <div style="font-size:13px;color:#9AA3B8;margin-bottom:28px;">
          Estude. Pratique. Conquiste.
        </div>

        <div style="font-size:18px;font-weight:800;color:#F3F4F6;margin-bottom:12px;">
          Falta pouco pra começar 🎉
        </div>
        <p style="font-size:14px;color:#9AA3B8;line-height:1.5;margin:0 0 28px;">
          Confirma seu e-mail pra ativar sua conta e começar a estudar
          pra sua certificação.
        </p>

        <a href="{{ .ConfirmationURL }}"
           style="display:inline-block;background-color:#6D28D9;color:#ffffff;font-weight:800;font-size:15px;text-decoration:none;padding:14px 32px;border-radius:16px;">
          Confirmar e-mail
        </a>

        <p style="font-size:12px;color:#9AA3B8;margin:28px 0 0;line-height:1.5;">
          Não foi você quem criou essa conta? Pode ignorar este e-mail.
        </p>
      </td>
    </tr>
  </table>
</div>
```

---

## 2. Reset password (recuperação de senha)

**Subject:** Redefinir sua senha do CertFly

**Body:**
```html
<div style="background-color:#111827;padding:40px 20px;font-family:Verdana,Arial,sans-serif;">
  <table role="presentation" width="100%" style="max-width:420px;margin:0 auto;background-color:#1B2333;border-radius:18px;border:2px solid #2E3750;overflow:hidden;">
    <tr>
      <td style="padding:32px 28px;text-align:center;">
        <div style="font-size:32px;font-weight:900;color:#F3F4F6;letter-spacing:-0.5px;margin-bottom:4px;">
          CertFly
        </div>
        <div style="font-size:13px;color:#9AA3B8;margin-bottom:28px;">
          Estude. Pratique. Conquiste.
        </div>

        <div style="font-size:18px;font-weight:800;color:#F3F4F6;margin-bottom:12px;">
          Redefinir sua senha 🔑
        </div>
        <p style="font-size:14px;color:#9AA3B8;line-height:1.5;margin:0 0 28px;">
          Recebemos um pedido pra trocar a senha da sua conta. Clique
          abaixo pra criar uma nova.
        </p>

        <a href="{{ .ConfirmationURL }}"
           style="display:inline-block;background-color:#6D28D9;color:#ffffff;font-weight:800;font-size:15px;text-decoration:none;padding:14px 32px;border-radius:16px;">
          Criar nova senha
        </a>

        <p style="font-size:12px;color:#9AA3B8;margin:28px 0 0;line-height:1.5;">
          Não foi você quem pediu? Pode ignorar este e-mail — sua senha
          continua a mesma.
        </p>
      </td>
    </tr>
  </table>
</div>
```

---

## 3. Magic Link (se um dia usarem login sem senha — não usado hoje no app, mas fica pronto)

**Subject:** Seu link de acesso ao CertFly

**Body:**
```html
<div style="background-color:#111827;padding:40px 20px;font-family:Verdana,Arial,sans-serif;">
  <table role="presentation" width="100%" style="max-width:420px;margin:0 auto;background-color:#1B2333;border-radius:18px;border:2px solid #2E3750;overflow:hidden;">
    <tr>
      <td style="padding:32px 28px;text-align:center;">
        <div style="font-size:32px;font-weight:900;color:#F3F4F6;letter-spacing:-0.5px;margin-bottom:4px;">
          CertFly
        </div>
        <div style="font-size:13px;color:#9AA3B8;margin-bottom:28px;">
          Estude. Pratique. Conquiste.
        </div>

        <div style="font-size:18px;font-weight:800;color:#F3F4F6;margin-bottom:12px;">
          Seu link de acesso ✨
        </div>
        <p style="font-size:14px;color:#9AA3B8;line-height:1.5;margin:0 0 28px;">
          Clique abaixo pra entrar direto na sua conta.
        </p>

        <a href="{{ .ConfirmationURL }}"
           style="display:inline-block;background-color:#6D28D9;color:#ffffff;font-weight:800;font-size:15px;text-decoration:none;padding:14px 32px;border-radius:16px;">
          Entrar no CertFly
        </a>

        <p style="font-size:12px;color:#9AA3B8;margin:28px 0 0;line-height:1.5;">
          Não foi você? Pode ignorar este e-mail.
        </p>
      </td>
    </tr>
  </table>
</div>
```

---

## Passo a passo

1. Painel Supabase → seu projeto → **Authentication** → **Emails** (menu lateral).
2. Aba **Templates**.
3. Selecione "Confirm signup" → cole o Subject e o Body acima → **Save**.
4. Repita pra "Reset password" (e "Magic Link" se quiser deixar pronto).
5. Teste: cria uma conta nova (ou pede reset de senha) e confere no e-mail
   (o remetente continua `noreply@mail.app.supabase.io` por enquanto — isso
   só muda com SMTP customizado + domínio, que fica pra quando for lançar).

Nota: e-mail não roda JS/CSS externo — por isso tudo é inline e sem
`@font-face`/Nunito (cai no fallback `Verdana,Arial,sans-serif`, que é o
padrão seguro pra e-mail).

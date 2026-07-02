# Módulo: WhatsApp Templates (Admin)

Tela administrativa para **gerenciar templates oficiais do WhatsApp** (Meta Cloud API)
dentro do dashboard: listar, filtrar, sincronizar, **criar** e **excluir** templates.

> Este é um módulo do fork (`chatwoot-sm`). A arquitetura segue o padrão descrito em
> `.cursor/rules/custom-modules.mdc` (isolar feature, mínimo de edição no core).

---

## Objetivo

- Visualizar os templates já aprovados/pendentes/rejeitados de uma inbox WhatsApp.
- Sincronizar templates com a Meta (reaproveitando o fluxo nativo do Chatwoot).
- Criar novos templates e enviá-los para aprovação da Meta.
- Excluir templates existentes.

Sem novas tabelas: os dados vivem em `channel_whatsapp.message_templates` /
`message_templates_last_updated`, exatamente como o Chatwoot já usa.

---

## Como acessar

- Menu lateral: **WhatsApp → Templates**
- Rota: `/accounts/:accountId/whatsapp/templates`
- Acesso: **somente administrador** (rota e backend).

---

## Arquitetura e arquivos

### Backend (`enterprise/`)

| Arquivo | Responsabilidade |
|---------|------------------|
| `enterprise/app/controllers/api/v1/accounts/whatsapp/templates_controller.rb` | `index` (lê do banco), `create`, `destroy`. Admin only. |
| `enterprise/app/services/whatsapp/templates_management_service.rb` | Chamadas à Graph API da Meta (criar/excluir), espelhando `Whatsapp::CsatTemplateService`. |

### Frontend (`app/javascript/dashboard/modules/whatsappTemplates/`)

| Arquivo | Responsabilidade |
|---------|------------------|
| `index.js` | Registro do módulo (rotas + item de sidebar). |
| `routes.js` | Rota `whatsapp_templates_index` (`meta.permissions: ['administrator']`). |
| `api.js` | Client HTTP (`get`, `create`, `delete`). |
| `pages/Index.vue` | Tela principal: stats, busca, filtro de status, sincronizar, listagem. |
| `components/TemplateCard.vue` | Card por template (badges + preview expansível + excluir). |
| `components/CreateTemplateDialog.vue` | Formulário de criação (Meta) com variáveis `{{n}}` e botões. |
| `components/TemplateButtonsEditor.vue` | Editor de botões Meta (quick reply / URL / telefone). |
| `templateDisplay.js` | Helpers para extrair header/body/footer/buttons. |

### Costuras no core (seams — já existentes, não duplicar)

1. `app/javascript/dashboard/routes/dashboard/dashboard.routes.js` → `...customModuleRoutes,`
2. `app/javascript/dashboard/components-next/sidebar/Sidebar.vue` → `...getCustomSidebarItems(...)`
3. `app/javascript/dashboard/modules/index.js` → registro do módulo (arquivo nosso)
4. `config/routes.rb` → `resources :templates, only: [:index, :create, :destroy]` (dentro de `namespace :whatsapp`, com `if ChatwootApp.enterprise?`)

### i18n

- `app/javascript/dashboard/i18n/locale/en/whatsappTemplates.json` → bloco `WHATSAPP_TEMPLATES.ADMIN`
- `app/javascript/dashboard/i18n/locale/pt_BR/whatsappTemplates.json` → bloco `WHATSAPP_TEMPLATES.ADMIN`
- Sidebar: `SIDEBAR.WHATSAPP` / `SIDEBAR.WHATSAPP_TEMPLATES` em `settings.json`

---

## API

Base: `/api/v1/accounts/:account_id/whatsapp/templates`

| Método | Rota | Descrição | Corpo / Params |
|--------|------|-----------|----------------|
| `GET` | `/templates?inbox_id=:id` | Lista templates do banco | `inbox_id` (query) |
| `POST` | `/templates` | Cria template na Meta + re-sync | `{ inbox_id, template: {...} }` |
| `POST` | `/templates/upload_media` | Upload de mídia de exemplo (header) | `multipart`: `inbox_id`, `header_format`, `file` |
| `DELETE` | `/templates/:name?inbox_id=:id` | Exclui template na Meta + re-sync | `:name` na URL, `inbox_id` (query) |

### Cadeia de criação (o que acontece no `POST /templates`)

1. **Frontend** (`api.js`) → `POST /api/v1/accounts/:account_id/whatsapp/templates`
2. **Controller** (`enterprise/.../templates_controller.rb`) → valida admin + inbox WhatsApp Cloud
3. **Service** (`Whatsapp::TemplatesManagementService#create`) → monta `components` e chama a Meta:

```
POST https://graph.facebook.com/v14.0/{WABA_ID}/message_templates
Authorization: Bearer {channel.api_key}
```

4. Após sucesso → `channel.sync_templates` atualiza `message_templates` no banco.

Referência oficial da Meta:
[Message Templates — Business Management API](https://developers.facebook.com/docs/whatsapp/business-management-api/message-templates)

Componente `BUTTONS` aceita `QUICK_REPLY`, `URL` (com `example` se a URL tiver variável) e `PHONE_NUMBER`.

### Payload de criação (`template`)

```json
{
  "name": "confirmacao_pedido",
  "category": "UTILITY",
  "language": "pt_BR",
  "header_text": "Atualização do pedido",
  "body_text": "Olá {{1}}, seu pedido {{2}} foi confirmado.",
  "footer_text": "Equipe Loja",
  "body_examples": ["Maria", "#1234"]
}
```

O serviço monta os `components` no formato da Meta (`HEADER`/`BODY`/`FOOTER`/`BUTTONS`).
Headers suportados: `TEXT`, `IMAGE`, `VIDEO`, `DOCUMENT`, `LOCATION` (localização é preenchida no envio).
Se o corpo tiver variáveis, `body_examples` vira `example.body_text`.

Botões suportados na criação:

| Tipo | Limite | Campos |
|------|--------|--------|
| `QUICK_REPLY` | até 3 | `text` |
| `URL` | até 2 (CTA) | `text`, `url`, `example` (se URL tiver `{{1}}`) |
| `PHONE_NUMBER` | 1 por template (CTA) | `text`, `phone_number` |

Quick reply e call-to-action **não podem ser misturados** no mesmo template (regra da Meta).

---

## Permissões

Segue o padrão do Chatwoot — **não foi criado nenhum sistema de permissão novo**:

- Rota frontend: `meta.permissions: ['administrator']`
- Controller: `check_admin_authorization?`
- Sincronização: reaproveita `InboxPolicy#sync_templates?` (admin) via `POST .../inboxes/:id/sync_templates`

---

## Regras e limitações da Meta

- Criar/excluir só funciona em inbox **WhatsApp Cloud API** (`provider == 'whatsapp_cloud'`).
- Template recém-criado entra como **PENDING** até a Meta aprovar.
- **Não é possível editar** um template aprovado — o fluxo é excluir e recriar
  (por isso o módulo tem apenas criar/excluir, sem editar).
- A exclusão remove **todos os idiomas** com aquele nome (comportamento da Meta).

---

## Fluxo interno

1. **Listar:** `index` lê `channel.message_templates` (sem chamar a Meta).
2. **Sincronizar:** botão chama `InboxesAPI.syncTemplates` (fluxo nativo) e depois recarrega.
3. **Criar:** `POST` → `TemplatesManagementService#create` (Graph API) → `channel.sync_templates` → retorna lista atualizada.
4. **Excluir:** `DELETE` → `TemplatesManagementService#delete` (Graph API) → `channel.sync_templates` → retorna lista atualizada.

---

## Desenvolvimento local (sem rebuild de imagem a cada mudança)

Para iterar no módulo de templates **não é necessário** gerar nova imagem Docker a cada
alteração. Use um destes fluxos:

### Opção A — Nativo (mais rápido para UI)

```bash
bundle install && pnpm install
overmind start -f Procfile.dev
# ou: pnpm dev  (vite) + bin/rails s -p 3000 em outro terminal
```

- **Frontend** (`app/javascript/...`) recarrega via Vite (hot reload).
- **Backend** (`enterprise/app/...`) recarrega via Rails em development.
- Acesse `http://localhost:3000` e vá em **WhatsApp → Templates**.

> Para testar criação real na Meta, a inbox precisa ser WhatsApp Cloud com token válido
> (mesmo em dev local).

### Opção B — Docker Compose de desenvolvimento (código montado)

O `docker-compose.yaml` do projeto já monta o repositório local:

```yaml
volumes:
  - ./:/app:delegated
```

```bash
docker compose up rails vite sidekiq postgres redis
```

Alterações em `app/javascript` e `enterprise/` refletem no container sem rebuild,
desde que o serviço `vite` esteja rodando.

### Opção C — Imagem de produção + volume (só backend)

Se você já roda `sidneynma/chatwoot-sm:vX.Y.Z` em produção/staging e quer testar só
mudanças Ruby sem rebuild completo, monte pastas específicas:

```yaml
services:
  chatwoot:
    image: sidneynma/chatwoot-sm:v4.14.2.a
    volumes:
      - ./enterprise:/app/enterprise:ro
```

**Limitação:** a imagem de produção traz o frontend **pré-compilado**. Mudanças em
`app/javascript` exigem Opção A ou B (ou rebuild da imagem com `scripts/release.sh`).

### Debug rápido do formulário de botões

- Ao clicar **Adicionar botão → Acessar o site**, deve aparecer o card
  **Botão 1 (Acessar o site)** com campos Texto + URL.
- Quick reply e CTA não podem ser misturados (regra da Meta).
- URL com variável (`https://site.com/{{1}}`) exige campo de exemplo.

---

## Como estender (futuro)

- **COPY_CODE button:** suporte ao botão de copiar cupom (marketing).
- **Status detalhado:** exibir motivo de rejeição vindo da Meta (`rejected_reason`).

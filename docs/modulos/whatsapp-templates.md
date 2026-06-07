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
| `components/CreateTemplateDialog.vue` | Formulário de criação (Meta) com variáveis `{{n}}`. |
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
| `DELETE` | `/templates/:name?inbox_id=:id` | Exclui template na Meta + re-sync | `:name` na URL, `inbox_id` (query) |

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

O serviço monta os `components` no formato da Meta (`HEADER`/`BODY`/`FOOTER`).
Se o corpo tiver variáveis, `body_examples` vira `example.body_text`.

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

## Como estender (futuro)

- **Botões no template:** adicionar suporte a `BUTTONS` (quick reply / URL) em
  `CreateTemplateDialog.vue` e em `TemplatesManagementService#build_components`.
- **Mídia no header:** suportar `format: IMAGE/VIDEO/DOCUMENT` (upload + handle).
- **Status detalhado:** exibir motivo de rejeição vindo da Meta (`rejected_reason`).

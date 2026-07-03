# Módulo: CRM Kanban (Funis)

Quadro Kanban nativo para conversas, usando **etiquetas como etapas** de funis
comerciais. Cada conversa aparece em **uma coluna por funil** (modo exclusivo).

> Módulo do fork (`chatwoot-sm`). Arquitetura em `.cursor/rules/custom-modules.mdc`.

---

## Objetivo (Fase 1)

- Admin cria funis e associa etiquetas como etapas ordenadas.
- Agentes e admins abrem o quadro por funil.
- Cards mostram contato, responsável, última mensagem e não lidas.
- Arrastar card entre colunas **troca a etiqueta** da conversa (somente labels do funil).
- Clique no card abre a conversa no Chatwoot.
- Filtros: responsável (minhas / todas) e status (aberta / pendente / todas).

---

## Como acessar

| Público | Caminho |
|---------|---------|
| Todos (agente/admin) | Menu **CRM** → lista de funis → quadro |
| Admin | **Configurações → Funis CRM** |

Rotas:

- `/accounts/:accountId/crm` — lista de funis
- `/accounts/:accountId/crm/:funnelId` — quadro Kanban
- `/accounts/:accountId/settings/crm-funnels` — gestão (admin)

---

## Arquitetura

### Backend (`enterprise/`)

| Arquivo | Responsabilidade |
|---------|------------------|
| `enterprise/app/models/crm_funnel.rb` | Funil (nome, inbox opcional, ativo) |
| `enterprise/app/models/crm_funnel_stage.rb` | Etapa = etiqueta + posição |
| `enterprise/app/controllers/api/v1/accounts/crm_funnels_controller.rb` | CRUD + board + move |
| `enterprise/app/services/crm/board_query_service.rb` | Carrega colunas e conversas |
| `enterprise/app/services/crm/move_conversation_service.rb` | Move card → atualiza labels |
| `enterprise/app/services/crm/funnel_stages_sync_service.rb` | Sincroniza etapas do funil |
| `enterprise/app/policies/crm_funnel_policy.rb` | Admin CRUD; agente lê/move |

### Frontend (`app/javascript/dashboard/modules/crmKanban/`)

| Arquivo | Responsabilidade |
|---------|------------------|
| `index.js` | Registro + item CRM no sidebar |
| `routes.js` | Lista, board e settings |
| `api.js` | Cliente HTTP |
| `pages/FunnelList.vue` | Seleção de funil |
| `pages/Board.vue` | Quadro Kanban |
| `pages/FunnelSettings.vue` | CRUD admin |
| `components/KanbanColumn.vue` | Coluna com drag-and-drop |
| `components/KanbanCard.vue` | Card da conversa |
| `components/StageEditor.vue` | Editor de etapas (labels ordenáveis) |

### Costuras no core

1. `app/javascript/dashboard/modules/index.js`
2. `app/javascript/dashboard/routes/dashboard/dashboard.routes.js` (via `customModuleRoutes`)
3. `app/javascript/dashboard/components-next/sidebar/Sidebar.vue` (settings admin)
4. `config/routes.rb` — bloco `crm_funnels` com `if ChatwootApp.enterprise?`

### i18n

- `app/javascript/dashboard/i18n/locale/en/crmKanban.json`
- `app/javascript/dashboard/i18n/locale/pt_BR/crmKanban.json`
- Sidebar: `SIDEBAR.CRM`, `SIDEBAR.CRM_FUNNELS` em `settings.json`

---

## API

Base: `/api/v1/accounts/:account_id/crm_funnels`

| Método | Rota | Quem | Descrição |
|--------|------|------|-----------|
| `GET` | `/` | Agente/Admin | Lista funis |
| `POST` | `/` | Admin | Cria funil + etapas |
| `GET` | `/:id` | Agente/Admin | Detalhe do funil |
| `PATCH` | `/:id` | Admin | Atualiza funil + etapas |
| `DELETE` | `/:id` | Admin | Remove funil |
| `GET` | `/:id/board` | Agente/Admin | Colunas + cards paginados |
| `POST` | `/:id/move` | Agente/Admin | Move conversa de etapa |

### Move (exclusivo por funil)

Remove todas as labels do funil da conversa e adiciona a label da etapa destino.

```json
{
  "conversation_id": 42,
  "stage_id": 7
}
```

### Board params

- `assignee_type`: `me` | `all` (padrão: `all`)
- `status`: `open` | `pending` | `all` (padrão: `open`)
- `page`: paginação por coluna (20 cards)

---

## Segurança

- `Conversations::PermissionFilterService` — agente só vê inboxes atribuídas.
- `authorize conversation, :show?` no move.
- CRUD de funis: **somente administrador**.

---

## Fase 2 (parcial — gestão de funis)

- Inativar/ativar funil (some da lista do agente em `/crm`)
- Excluir funil (remove só configuração; contatos, conversas e etiquetas permanecem)
- Settings lista todos os funis (ativos e inativos) via `include_inactive=true`
- `/crm` é visão do agente — sem botões de gestão

### Excluir funil

Remove apenas `crm_funnels` e `crm_funnel_stages`. **Não** remove:

- Conversas
- Contatos
- Etiquetas da conta
- Etiquetas já aplicadas nas conversas

## Fase 2 (planejada)

- Métricas por etapa
- Automações ao mudar etapa
- Coluna “sem etapa” para conversas sem label do funil
- Filtros avançados (equipe, período)
- Paginação infinita por coluna

---

## Migration

```bash
bundle exec rails db:migrate
```

Tabelas: `crm_funnels`, `crm_funnel_stages`.

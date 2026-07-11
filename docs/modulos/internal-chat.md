# Módulo: Chat interno (Team chat)

Chat **somente entre agentes** da mesma account. Isolado de conversas e
contatos do Chatwoot (não usa `Conversation` / `Message`).

> Módulo do fork (`chatwoot-sm`). Arquitetura em `.cursor/rules/custom-modules.mdc`.

---

## Escopo

### Fase 1
- DM 1:1 (buscar agente e abrir chat)
- Grupos (admin cria / edita / exclui / gerencia membros)
- Mensagens de texto em tempo real (ActionCable)
- Só membros do grupo veem e participam

### Fase 2
- Emoji (`EmojiIconPicker`)
- Arquivos (upload account-scoped + ActiveStorage)
- Áudio (gravação no browser + upload)

### Fechar / agente inativo
- **Fechar conversa** (por membership `closed_at`) — some da lista; histórico preservado
- Nova mensagem ou buscar o mesmo agente e enviar — **reabre** a sala
- API `GET rooms` retorna só salas abertas
- Agente removido da conta — DM permanece com histórico; `peer_inactive` + envio bloqueado; banner na UI
- Agente só aparece na busca se for membro da **conta atual**

---

## Como acessar

| Público | Caminho |
|---------|---------|
| Agente / Admin | Menu **Chat interno** → `/internal-chat` |
| Admin | Botão **Novo grupo** na mesma tela |

Rotas:
- `/accounts/:accountId/internal-chat`
- `/accounts/:accountId/internal-chat/:roomId`

---

## Arquitetura

### Backend (`enterprise/`)

| Arquivo | Responsabilidade |
|---------|------------------|
| `enterprise/app/models/internal_chat_room.rb` | Room `direct` ou `group` |
| `enterprise/app/models/internal_chat_membership.rb` | Membros + `last_read_at` |
| `enterprise/app/models/internal_chat_message.rb` | Mensagem + attachments |
| `enterprise/app/controllers/api/v1/accounts/internal_chat/*` | Rooms / messages / members |
| `enterprise/app/services/internal_chat/*` | DM, create message, broadcast |
| `enterprise/app/policies/internal_chat_*_policy.rb` | Admin CRUD grupo; membro lê/envia |

### Frontend (`app/javascript/dashboard/modules/internalChat/`)

| Arquivo | Responsabilidade |
|---------|------------------|
| `index.js` | Registro + item no sidebar |
| `routes.js` / `api.js` | Rotas e HTTP |
| `cable.js` | Eventos realtime via mitt |
| `pages/Index.vue` | Lista + painel |
| `components/Composer.vue` | Texto, emoji, arquivo, áudio |

### Costuras no core

1. `app/javascript/dashboard/modules/index.js`
2. `config/routes.rb` — bloco `internal_chat` com `if ChatwootApp.enterprise?`
3. `app/javascript/dashboard/helper/actionCable.js` — re-emite eventos `internal_chat.*`
4. `enterprise/app/models/enterprise/concerns/account.rb` — `has_many :internal_chat_rooms`
5. i18n `en` + `pt_BR` (`internalChat.json` + `SIDEBAR.INTERNAL_CHAT`)

### Migration

`db/migrate/20260711000000_create_internal_chat.rb`
`db/migrate/20260711010000_add_closed_at_to_internal_chat_memberships.rb`

---

## API

```
GET    /api/v1/accounts/:id/internal_chat/rooms
POST   /api/v1/accounts/:id/internal_chat/rooms              # grupo (admin)
POST   /api/v1/accounts/:id/internal_chat/rooms/direct       # { user_id }
GET    /api/v1/accounts/:id/internal_chat/rooms/:id
PATCH  /api/v1/accounts/:id/internal_chat/rooms/:id          # admin
DELETE /api/v1/accounts/:id/internal_chat/rooms/:id          # admin, só group
POST   /api/v1/accounts/:id/internal_chat/rooms/:id/mark_read
POST   /api/v1/accounts/:id/internal_chat/rooms/:id/close
POST   /api/v1/accounts/:id/internal_chat/rooms/:id/reopen
GET    /api/v1/accounts/:id/internal_chat/rooms/search?q=
GET    /api/v1/accounts/:id/internal_chat/rooms/:id/messages
POST   /api/v1/accounts/:id/internal_chat/rooms/:id/messages # content, blob_signed_ids, is_voice
POST   /api/v1/accounts/:id/internal_chat/rooms/:id/members
DELETE /api/v1/accounts/:id/internal_chat/rooms/:id/members/:user_id
```

Anexos: upload via `POST /api/v1/accounts/:id/upload` → `blob_id` (signed) → `blob_signed_ids` na mensagem.

---

## Deploy

```bash
bundle exec rails db:migrate
./scripts/release.sh v4.15.1.a --push
```

Imagem: `sidneynma/chatwoot-sm:v4.15.1.a` (ajuste a tag conforme o release).

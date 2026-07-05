# Recursos por caixa de entrada

Escopo opcional por caixa (`inbox_id` nulo = todas as caixas) para etiquetas e respostas rápidas.

## Fase 1 — Etiquetas

| `inbox_id` | Visibilidade |
|------------|--------------|
| `null` | Global — todas as caixas |
| `N` | Só caixa `N` |

- **Admin (configurações):** vê e edita todas.
- **Agente (API):** globais + caixas em que é membro.
- **Sidebar:** mesma regra do agente.
- **Conversa:** globais + etiquetas da caixa da conversa.

## Fase 2 — Respostas rápidas

Mesma regra de visibilidade das etiquetas.

- **Configurações → Respostas rápidas:** seletor de caixa ao criar/editar.
- **Editor da conversa (`/` ou menu de respostas):** só respostas globais + da caixa da conversa.

## Arquitetura

| Camada | Local |
|--------|--------|
| Migrations | `labels.inbox_id`, `canned_responses.inbox_id` |
| Filtro compartilhado | `enterprise/app/services/inbox_scoped_resources/filter_service.rb` |
| Models | `enterprise/app/models/enterprise/label.rb`, `canned_response.rb` |
| Controllers | prepend em `labels_controller`, `canned_responses_controller` |
| Frontend | `modules/inboxScopedResources/` — `InboxScopeSelect`, filtros genéricos |

## Deploy

```bash
bundle exec rails db:migrate
```

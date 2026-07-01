# Módulo: Redistribuição de Conversas (Admin)

Tela administrativa para **redistribuir conversas em lote** entre agentes de uma
Inbox, com simulação obrigatória antes da execução.

> Módulo do fork (`chatwoot-sm`). Arquitetura em `.cursor/rules/custom-modules.mdc`.

---

## Objetivo

- Selecionar inbox e critérios de conversas (sem responsável, de um agente, ou todas correspondentes).
- Filtrar por status (`open`, `pending`, `snoozed`, `resolved`; padrão: `open` + `pending`).
- Escolher agentes participantes da inbox (mínimo 2).
- Escolher estratégia: **round robin** ou **balanceamento por carga**.
- **Simular** distribuição (sem alterar dados).
- **Confirmar e executar** em transação atômica (rollback total em caso de erro).

**Sem novas tabelas:** simulação e resultado são efêmeros (API/UI). O rastro por
conversa usa activity messages nativas do Chatwoot ao alterar `assignee_id`.

**Execução síncrona:** até ~500 conversas por operação (limite no serviço).

---

## Como acessar

- Menu lateral: **Configurações → Redistribuição de conversas**
- Rota: `/accounts/:accountId/settings/conversation-redistribution`
- Acesso: **somente administrador** (rota e backend).

---

## Arquitetura e arquivos

### Backend (`enterprise/`)

| Arquivo | Responsabilidade |
|---------|------------------|
| `enterprise/app/controllers/api/v1/accounts/conversation_redistributions_controller.rb` | `simulate`, `execute`. Admin only. |
| `enterprise/app/services/conversation_redistribution_service.rb` | Query, cálculo de distribuição, execução transacional. |

### Frontend (`app/javascript/dashboard/modules/conversationRedistribution/`)

| Arquivo | Responsabilidade |
|---------|------------------|
| `index.js` | Registro do módulo (rotas). |
| `routes.js` | Rota admin com `SettingsWrapper`. |
| `api.js` | `simulate`, `execute`, `getInboxAgents`. |
| `pages/Index.vue` | Formulário + fluxo simulate → confirm → execute → resultado. |
| `components/SimulationTable.vue` | Tabela Conversa / Agente Atual / Novo Agente. |

### Costuras no core (seams)

1. `app/javascript/dashboard/routes/dashboard/dashboard.routes.js` → `...customModuleRoutes,`
2. `app/javascript/dashboard/components-next/sidebar/Sidebar.vue` → item em **Configurações**
3. `app/javascript/dashboard/modules/index.js` → registro do módulo
4. `config/routes.rb` → bloco `conversation_redistribution` com `if ChatwootApp.enterprise?`

### i18n

- `app/javascript/dashboard/i18n/locale/en/conversationRedistribution.json`
- `app/javascript/dashboard/i18n/locale/pt_BR/conversationRedistribution.json`
- Sidebar: `SIDEBAR.CONVERSATION_REDISTRIBUTION` em `settings.json`

### Testes

- `spec/enterprise/services/conversation_redistribution_service_spec.rb`
- Roda apenas em ambiente de teste (`bundle exec rspec spec/enterprise/services/conversation_redistribution_service_spec.rb`)

---

## API

Base: `/api/v1/accounts/:account_id/conversation_redistribution`

| Método | Rota | Descrição |
|--------|------|-----------|
| `POST` | `/simulate` | Calcula distribuição sem persistir |
| `POST` | `/execute` | Revalida, executa em transação e retorna resumo |

### Body (simulate e execute)

```json
{
  "inbox_id": 12,
  "redistribution_type": "unassigned",
  "source_agent_id": null,
  "statuses": ["open", "pending"],
  "agent_ids": [3, 7, 15, 22],
  "strategy": "round_robin"
}
```

| Campo | Valores |
|-------|---------|
| `redistribution_type` | `unassigned` \| `from_agent` \| `all_open` |
| `source_agent_id` | Obrigatório quando `from_agent` |
| `statuses` | Subset de `open`, `pending`, `snoozed`, `resolved` |
| `strategy` | `round_robin` \| `load_balance` |

### Resposta

```json
{
  "total_conversations": 227,
  "agent_count": 4,
  "summary": [
    { "agent_id": 3, "name": "Felipe", "count": 57 }
  ],
  "assignments": [
    {
      "conversation_id": 36084,
      "display_id": 1042,
      "current_assignee": null,
      "new_assignee": { "id": 3, "name": "Felipe" }
    }
  ],
  "success": true
}
```

`success` só aparece em `execute`.

---

## Lógica de distribuição

### Round robin

Distribuição sequencial entre `agent_ids` na ordem informada.
**Não** usa `AutoAssignment::InboxRoundRobinService` (fila Redis da inbox).

### Balanceamento por carga

1. Conta conversas **abertas** (`status: open`) por agente na inbox.
2. Atribui cada conversa do lote ao participante com menor carga.
3. Incrementa carga virtual a cada atribuição.

---

## Execução e segurança

- ActiveRecord apenas — sem SQL manual.
- Escopo sempre `account_id` + `inbox_id`.
- Agentes validados como membros da inbox.
- Mínimo **2 agentes** participantes.
- Máximo **500 conversas** por operação.
- Transação única: qualquer erro → rollback completo.
- `execute` **revalida** no servidor (não confia no cliente).

### Auditoria (sem tabela)

- Activity message por conversa ao alterar `assignee_id`.
- Resumo exibido na tela de sucesso (efêmero).

---

## Permissões

- Frontend: `meta.permissions: ['administrator']`
- Backend: `check_admin_authorization?`

---

## Fluxo da UI

1. Admin preenche formulário → **Simular**
2. Exibe contagem, resumo por agente e tabela de prévia (até 100 linhas)
3. Modal: *"N conversas serão redistribuídas. Deseja continuar?"*
4. **Redistribuir** → spinner com etapas
5. Tela de sucesso com totais por agente

---

## Trade-offs (sem tabelas)

| Requisito | Decisão |
|-----------|---------|
| Histórico admin de redistribuições | Fora do escopo |
| Desfazer redistribuição | Fora do escopo |
| Lotes > 500 conversas | Requer job assíncrono (futuro) |

---

## Como estender (futuro)

- Job assíncrono + barra de progresso real para milhares de conversas.
- Histórico admin com 1 tabela + `summary` JSONB.
- Filtros extras: labels, team, prioridade.

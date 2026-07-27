# Changelog — chatwoot-sm

Histórico de releases do fork **chatwoot-sm** (`sidneynma/chatwoot-sm`).

## Convenção de versão

| Parte | Exemplo | Significado |
|-------|---------|-------------|
| Base upstream | `4.14.2` | Versão do Chatwoot mergeada |
| Sufixo fork | `.a` | Release customizada do fork |
| Tag completa | `v4.14.2.a` | Usada no Git e na imagem Docker |

Imagem Docker: `sidneynma/chatwoot-sm:v4.15.1.k`

---

## [v4.15.1.k] — 2026-07-27

**Base upstream:** Chatwoot `4.15.1`

### Melhorado

- **Aguardando resposta** (retentativa segura) — lista só com consulta à API existente; rota **lazy**; ícone do menu igual ao de “Não atendidas”; filtros por **caixa**, **tempo de espera** e responsável. Sem Vuex/WebSocket.

### Deploy

```yaml
# docker-compose.production.yaml
image: sidneynma/chatwoot-sm:v4.15.1.k
```

### Release

```bash
./scripts/release.sh v4.15.1.k --push
```

**Como validar:** inbox deve continuar recebendo mensagens **sem F5**; só então usar a nova página.

---

## [v4.15.1.j] — 2026-07-27

**Base upstream:** Chatwoot `4.15.1`

### Corrigido

- Remove a página **Aguardando resposta** (suspeita no teste h/i de quebrar atualização em tempo real das mensagens no inbox)
- Mantém o fix do **Disparador** (agendamento 1:1 reutiliza a conversa existente via `display_id`)

### Deploy

```yaml
# docker-compose.production.yaml
image: sidneynma/chatwoot-sm:v4.15.1.j
```

### Release

```bash
./scripts/release.sh v4.15.1.j --push
```

---

## [v4.15.1.i] — 2026-07-25

**Base upstream:** Chatwoot `4.15.1`

### Melhorado

- **Aguardando resposta** — lista clicável de conversas não atendidas / com `waiting_since`, reutilizando a API e permissões do inbox (sem campos ou SLA novos)

### Corrigido

- **Disparador** — agendamento 1:1 reutiliza a conversa existente (`display_id`) na criação e no envio, em vez de abrir outra

### Deploy

```yaml
# docker-compose.production.yaml
image: sidneynma/chatwoot-sm:v4.15.1.i
```

### Release

```bash
./scripts/release.sh v4.15.1.i --push
```

---

## [v4.15.1.h] — 2026-07-23

**Base upstream:** Chatwoot `4.15.1`

### Melhorado

- **CRM** — agentes com função personalizada `conversation_manage` (gestor) veem o filtro **Todas** e as conversas das inboxes, alinhado ao inbox; admin e agent sem função permanecem iguais
- **CRM** — etapa de funil aceita **vários times** no handoff (todos veem a coluna; a conversa é atribuída ao primeiro time)
- **CRM** — modal criar/editar funil mais largo e alto

### Deploy

```yaml
# docker-compose.production.yaml
image: sidneynma/chatwoot-sm:v4.15.1.h
```

Requer migration: `20260723000000_add_responsible_team_ids_to_crm_funnel_stages`

### Release

```bash
./scripts/release.sh v4.15.1.h --push
```

---

## [v4.15.1.g] — 2026-07-22

**Base upstream:** Chatwoot `4.15.1`

### Corrigido

- **Disparador** — webhook Meta `failed` (ex. `#131026` undeliverable) após `sent` passa a marcar falha e gravar o erro na coluna Erro

### Melhorado

- Cards da campanha filtráveis (todas / enviadas / entregues / lidas / respostas / falhas / total envios)
- Lista de destinatários paginada (50 por página) com meta na API
- Excel/PDF respeitam o filtro ativo

### Deploy

```yaml
# docker-compose.production.yaml
image: sidneynma/chatwoot-sm:v4.15.1.g
```

### Release

```bash
./scripts/release.sh v4.15.1.g --push
```

---

## [v4.15.1.f] — 2026-07-22

**Base upstream:** Chatwoot `4.15.1`

### Corrigido

- **Disparador** — respostas em Meta direto passam a bater telefone com/sem o 9º dígito BR (status respondida)
- Erro Meta `#132000` ao enviar parâmetros a mais no body do template
- Erro genérico “Meta did not return a message id” agora propaga a mensagem real da API

### Melhorado

- Duração da campanha na tela de detalhe (minutos e segundos)
- Preview dos botões estáticos do template (CALL / URL)
- Meta direto grava `contact_id` e vincula a conversa ao marcar respondida

### Deploy

```yaml
# docker-compose.production.yaml
image: sidneynma/chatwoot-sm:v4.15.1.f
```

Para leilões (2k–3k em 5–10 min), preferir **2 réplicas** do Sidekiq e modo **Rápido (Meta direto)**.

### Release

```bash
./scripts/release.sh v4.15.1.f --push
```

---

## [v4.15.1.e] — 2026-07-21

**Base upstream:** Chatwoot `4.15.1`

### Adicionado

- **Disparador** — módulo nativo de campanhas WhatsApp (Meta + Chatolhe API) e agendamento 1:1 na conversa
- Métricas de campanha: enviado / entregue / lida / respondida / falha (webhook Meta + listener Evolution/API)
- Importação opcional do Campaign Dashboard antigo (`rake disparador:import_from_dashboard`)

### Melhorado

- Agendamentos 1:1 vinculam a conversa ao destinatário para marcar respondida
- Lista de agendamentos atualiza sozinha e exibe status lida/respondida

### Deploy

```yaml
# docker-compose.production.yaml
image: sidneynma/chatwoot-sm:v4.15.1.e
```

Após o migrate, importar campanhas históricas da conta 10 (one-off, fora da imagem):

```bash
psql -d SEU_BANCO_CHATWOOT -v ON_ERROR_STOP=1 -f disparador_import_account_10_data.sql
```

### Release

```bash
./scripts/release.sh v4.15.1.e --push
```

---

## [v4.15.1.d] — 2026-07-19

**Base upstream:** Chatwoot `4.15.1`

### Melhorado

- **Contatos** — após criar um novo contato, abre a página de detalhes (`/contacts/:id`) em vez de voltar à lista

### Deploy

```yaml
# docker-compose.production.yaml
image: sidneynma/chatwoot-sm:v4.15.1.d
```

### Release

```bash
./scripts/release.sh v4.15.1.d --push
```

---

## [v4.15.1.c] — 2026-07-14

**Base upstream:** Chatwoot `4.15.1`

### Adicionado

- **CRM** — filtro de caixa na lista `/crm` e nome da caixa no card do funil (ao lado das etapas)

### Corrigido / UI

- Modal criar/editar funil mais compacto (altura limitada + scroll nas etapas)
- Opções de etapa independentes (`auto_resolve` não marca mais `clear_assignment` automaticamente)
- Tarja branca na lista com 3 cards (`flex-1 w-full` no layout CRM)

### Deploy

```yaml
# docker-compose.production.yaml
image: sidneynma/chatwoot-sm:v4.15.1.c
```

### Release

```bash
./scripts/release.sh v4.15.1.c --push
```

---

## [v4.15.1.b] — 2026-07-12

**Base upstream:** Chatwoot `4.15.1`

### Adicionado

- **CRM Kanban — handoff por time (etapa)** — associação de time responsável à etapa do funil
  - Ao entrar na etapa: conversa vai para o time; estado anterior em `crm_case_states`
  - Ao sair: restaura assignee/team anteriores
  - Time sem inbox: leitura + notas privadas; reply pública bloqueada; resolve só se `can_resolve`
  - Opções de etapa: `can_resolve`, `auto_resolve_on_enter`, `clear_assignment_on_resolve`
  - Filtros do quadro: **Minhas / fila do time**, **Meu time**; **Todas visíveis** só para admin
  - Lista de funis do agente: só inbox dele **ou** funil com etapa do time dele
- Migration `add_crm_team_handoff` (`crm_case_states` + campos nas etapas)
- **Chat interno** — badge de não lidas na sidebar (store + ActionCable + API)

### Corrigido

- Exclusão de funil: FK em `crm_funnel_stages` (`dependent: :destroy` síncrono)

### Documentação

- `docs/modulos/crm-kanban.md` (handoff, filtros, visibilidade)
- `docs/modulos/internal-chat.md` (badge)

### Deploy

```yaml
# docker-compose.production.yaml
image: sidneynma/chatwoot-sm:v4.15.1.b
```

### Release

```bash
bundle exec rails db:migrate
./scripts/release.sh v4.15.1.b --push
```

---

## [v4.15.1.a] — 2026-07-11

**Base upstream:** Chatwoot `4.15.1`

### Adicionado

- **Chat interno (Team chat)** — chat entre agentes da mesma conta, isolado de conversas/contatos
  - DM 1:1 (buscar agente) e grupos (admin cria/edita/exclui/membros)
  - Texto, emoji, arquivo e áudio em tempo real (ActionCable)
  - Fechar conversa (some da lista; histórico preservado); nova mensagem ou busca reabre
  - Agente removido da conta: histórico mantido, envio bloqueado, banner “agente inativo”
  - Busca encontra grupos fechados e DMs com agentes inativos para consultar histórico
  - Ícone de chat na sidebar (`i-ri-chat-1-line`)
- Migrations `create_internal_chat` e `add_closed_at_to_internal_chat_memberships`

### Documentação

- `docs/modulos/internal-chat.md`

### Deploy

```yaml
# docker-compose.production.yaml
image: sidneynma/chatwoot-sm:v4.15.1.a
```

### Release

```bash
bundle exec rails db:migrate
./scripts/release.sh v4.15.1.a --push
```

---

## [v4.14.2.f] — 2026-07-05

**Base upstream:** Chatwoot `4.14.2`

### Adicionado

- **Etiquetas por caixa de entrada** — ao criar/editar etiqueta, escolher **Todas as caixas** ou uma caixa específica (`labels.inbox_id`)
  - Agente: vê globais + etiquetas das caixas em que é membro (sidebar, conversa, API)
  - Admin: vê e edita todas em **Configurações → Etiquetas**
- **Respostas rápidas por caixa de entrada** — mesmo escopo para `canned_responses.inbox_id`
  - Editor da conversa (`/`) filtra pela caixa da conversa
  - Admin configura em **Configurações → Respostas rápidas**
- Módulo frontend `inboxScopedResources` — `InboxScopeSelect` e filtros reutilizáveis
- **CRM Kanban — scroll infinito por coluna** — carga inicial de 20 cards; ao rolar, busca próximas páginas (`stage_id` + `page`)
- **Funis CRM — scroll na lista de etapas** — dialog de criar/editar funil mantém tamanho fixo; etapas adicionadas rolam dentro do card

### Documentação

- `docs/modulos/inbox-scoped-resources.md`
- `docs/modulos/crm-kanban.md` (scroll infinito)

### Deploy

```yaml
# docker-compose.production.yaml
image: sidneynma/chatwoot-sm:v4.14.2.f
```

### Release

```bash
bundle exec rails db:migrate
./scripts/release.sh v4.14.2.f --push
```

---

## [v4.14.2.e] — 2026-07-03

**Base upstream:** Chatwoot `4.14.2`

### Adicionado

- **CRM Kanban (Funis)** — módulo merge-safe com funis comerciais baseados em etiquetas
  - Admin: criar/editar/inativar/excluir funis em **Configurações → Funis CRM** (`/settings/crm-funnels`)
  - Agente e admin: quadro Kanban em **CRM** (`/crm`) com drag-and-drop entre etapas (1 etiqueta por funil)
  - Cards com contato, responsável, última mensagem; clique abre a conversa
  - Agente vê **somente conversas atribuídas a ele**; admin pode alternar filtro de responsável
  - Excluir funil remove só a configuração — contatos, conversas e etiquetas são mantidos
- Tabelas `crm_funnels` e `crm_funnel_stages` (migration `20260702180000_create_crm_funnels`)

### Documentação

- `docs/modulos/crm-kanban.md`

### Deploy

```yaml
# docker-compose.production.yaml
image: sidneynma/chatwoot-sm:v4.14.2.e
```

### Release

```bash
bundle exec rails db:migrate
./scripts/release.sh v4.14.2.e --push
```

---

## [v4.14.2.d] — 2026-07-02

**Base upstream:** Chatwoot `4.14.2`

### Adicionado

- **Campaign Dashboard (Chatolhe)** — encaminhamento de status WhatsApp (`delivered`/`read`/`failed`) para webhook externo quando não há mensagem na conversa (envio rápido `meta_direct`)
- Config `CAMPAIGN_DASHBOARD_STATUS_WEBHOOK_URL` em Super Admin → Configurações

### Corrigido

- **WhatsApp Templates** — botão "Acessar o site" quebrava o editor com erro `Not allowed nest placeholder` (escape de `{{1}}` no placeholder de URL)
- Editor de botões — estado gerenciado no dialog pai com eventos `@add`/`@remove`/`@update`; menu dropdown e scroll ao adicionar botão

### Deploy

```yaml
# docker-compose.production.yaml
image: sidneynma/chatwoot-sm:v4.14.2.d
```

### Release

```bash
./scripts/release.sh v4.14.2.d --push
```

---

## [v4.14.2.c] — 2026-07-02

**Base upstream:** Chatwoot `4.14.2`

### Adicionado

- **WhatsApp Templates** — cabeçalho `LOCATION` na criação de templates (local definido no envio)
- Normalização automática do nome do template (`teste hoje` → `teste_hoje`)

### Corrigido

- Editor de botões URL/CTA — estado local no editor + seção antes do rodapé; card Texto + URL aparece ao clicar
- Tipo de cabeçalho **Localização** — `ComboBox` trocado por `Select` para exibir todas as opções

### Documentação

- `docs/modulos/whatsapp-templates.md` — fluxo de criação, dev local e headers suportados

### Deploy

```yaml
# docker-compose.production.yaml
image: sidneynma/chatwoot-sm:v4.14.2.c
```

### Release

```bash
# Republicar na mesma tag (após commit):
git tag -d v4.14.2.c && git push origin :refs/tags/v4.14.2.c
git tag -a v4.14.2.c -m "release v4.14.2.c" && git push origin v4.14.2.c
./scripts/release.sh v4.14.2.c --skip-tag --push
```

---

## [v4.14.2.b] — 2026-07-01

**Base upstream:** Chatwoot `4.14.2`

### Corrigido

- **Redistribuição de conversas** — erro PG `DISTINCT` em colunas JSON
- **WhatsApp Templates** — redesign do editor de botões (estilo Meta)

### Deploy

```yaml
# docker-compose.production.yaml
image: sidneynma/chatwoot-sm:v4.14.2.b
```

### Release

```bash
./scripts/release.sh v4.14.2.b --push
```

---

## [v4.14.2.a] — 2026-07-01

**Base upstream:** Chatwoot `4.14.2`

### Adicionado

- **Redistribuição de Conversas** — módulo admin para redistribuir conversas em lote entre agentes da inbox, com simulação, round robin e balanceamento por carga (`docs/modulos/conversation-redistribution.md`)
- Melhorias no módulo **WhatsApp Templates** — criação com mídia, variáveis e ajustes de UI/traduções
- Permissão customizada `contact_assigned_only` (custom role)
- Variáveis inteligentes de template WhatsApp (nome do agente, etc.)

### Alterado

- Merge do upstream `v4.14.2` (segurança, Captain, onboarding, webhooks, etc.)

### Deploy

```yaml
# docker-compose.production.yaml
image: sidneynma/chatwoot-sm:v4.14.2.a
```

### Release

```bash
./scripts/release.sh v4.14.2.a --push
```

---

## [v4.14.1-e] — (anterior)

**Base upstream:** Chatwoot `4.14.1`

Release anterior do fork. Incluía as customizações iniciais do período 4.14.1 (módulo WhatsApp Templates e ajustes correlatos).

Imagem: `sidneynma/chatwoot-sm:v4.14.1-e`

---

## Como publicar uma nova versão

1. Commitar todas as mudanças do fork
2. Atualizar este `CHANGELOG.md` com a nova seção
3. Executar o script de release:

```bash
chmod +x scripts/release.sh   # primeira vez
./scripts/release.sh v4.14.2.a              # build local + tag git
./scripts/release.sh v4.14.2.a --push     # publica imagem versionada + tag git
```

Após validar em produção, promova `:latest` (opcional):

```bash
./scripts/release.sh v4.14.2.a --promote-latest --push
```

Opções úteis:

| Flag | Efeito |
|------|--------|
| `--push` | Envia imagem Docker e tag Git para o remoto |
| `--promote-latest` | Aponta `:latest` para a versão informada (sem rebuild) |
| `--skip-docker` | Cria apenas a tag Git |
| `--skip-tag` | Apenas build/push da imagem |
| `--allow-dirty` | Permite working tree suja (não recomendado) |
| `-m "mensagem"` | Mensagem da tag anotada |

> O release padrão **não** publica `:latest`. Use sempre a tag de versão no deploy
> (`sidneynma/chatwoot-sm:v4.14.2.a`) e promova `latest` só depois dos testes.

Variáveis de ambiente:

```bash
DOCKER_IMAGE=sidneynma/chatwoot-sm
DOCKER_PLATFORM=linux/amd64   # ou linux/arm64
RELEASE_EDITION=ee
```

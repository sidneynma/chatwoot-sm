# Changelog — chatwoot-sm

Histórico de releases do fork **chatwoot-sm** (`sidneynma/chatwoot-sm`).

## Convenção de versão

| Parte | Exemplo | Significado |
|-------|---------|-------------|
| Base upstream | `4.14.2` | Versão do Chatwoot mergeada |
| Sufixo fork | `.a` | Release customizada do fork |
| Tag completa | `v4.14.2.a` | Usada no Git e na imagem Docker |

Imagem Docker: `sidneynma/chatwoot-sm:v4.14.2.d`

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

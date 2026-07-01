# Changelog — chatwoot-sm

Histórico de releases do fork **chatwoot-sm** (`sidneynma/chatwoot-sm`).

## Convenção de versão

| Parte | Exemplo | Significado |
|-------|---------|-------------|
| Base upstream | `4.14.2` | Versão do Chatwoot mergeada |
| Sufixo fork | `.a` | Release customizada do fork |
| Tag completa | `v4.14.2.a` | Usada no Git e na imagem Docker |

Imagem Docker: `sidneynma/chatwoot-sm:v4.14.2.a`

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
./scripts/release.sh v4.14.2.a           # build local + tag git
./scripts/release.sh v4.14.2.a --push  # publica no Docker Hub e envia a tag
```

Opções úteis:

| Flag | Efeito |
|------|--------|
| `--push` | Envia imagem Docker e tag Git para o remoto |
| `--skip-docker` | Cria apenas a tag Git |
| `--skip-tag` | Apenas build/push da imagem |
| `--allow-dirty` | Permite working tree suja (não recomendado) |
| `-m "mensagem"` | Mensagem da tag anotada |

Variáveis de ambiente:

```bash
DOCKER_IMAGE=sidneynma/chatwoot-sm
DOCKER_PLATFORM=linux/amd64   # ou linux/arm64
RELEASE_EDITION=ee
```

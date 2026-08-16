#!/usr/bin/env bash
#
# Legacy / helper release script for chatwoot-sm (fork).
#
# Preferred flow (Docker build on GitHub Actions):
#   1. Update CHANGELOG.md and commit
#   2. ./scripts/release_git.sh v4.16.2.d
#   3. Wait for .github/workflows/release_chatwoot_sm.yml
#   4. After prod validation:
#      ./scripts/release.sh v4.16.2.d --promote-latest --push
#
# This script can still build the image locally if needed:
#   ./scripts/release.sh v4.16.2.d --push
#   ./scripts/release.sh v4.16.2.d --skip-docker   # tag only (prefer release_git.sh)
#   ./scripts/release.sh v4.16.2.d --promote-latest --push
#
# Environment overrides:
#   DOCKER_IMAGE=sidneynma/chatwoot-sm
#   DOCKER_PLATFORM=linux/amd64
#   RELEASE_EDITION=ee
#
# A tag :latest NÃO é criada no release padrão. Promova manualmente após validar
# em produção com --promote-latest.
set -euo pipefail

DOCKER_IMAGE="${DOCKER_IMAGE:-sidneynma/chatwoot-sm}"
DOCKER_PLATFORM="${DOCKER_PLATFORM:-linux/amd64}"
RELEASE_EDITION="${RELEASE_EDITION:-ee}"
VERSION=""
PUSH=false
SKIP_DOCKER=false
SKIP_TAG=false
PROMOTE_LATEST=false
ALLOW_DIRTY=false
TAG_MESSAGE=""

usage() {
  sed -n '3,20p' "$0" | sed 's/^# \{0,1\}//'
  echo
  echo "Options:"
  echo "  --push            Push Docker image and git tag to remote"
  echo "  --promote-latest  Tag :latest from an existing version image (after prod tests)"
  echo "  --skip-docker     Only create the git tag (prefer ./scripts/release_git.sh)"
  echo "  --skip-tag        Only build/push the Docker image"
  echo "  --allow-dirty     Allow uncommitted changes"
  echo "  -m, --message     Annotated tag message (default: release \$VERSION)"
  echo "  -h, --help        Show this help"
}

log() {
  printf '==> %s\n' "$*"
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

parse_args() {
  if [[ $# -lt 1 ]]; then
    usage
    die "version is required (example: v4.14.2.a)"
  fi

  VERSION="$1"
  shift

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --push) PUSH=true ;;
      --promote-latest) PROMOTE_LATEST=true ;;
      --skip-docker) SKIP_DOCKER=true ;;
      --skip-tag) SKIP_TAG=true ;;
      --allow-dirty) ALLOW_DIRTY=true ;;
      -m|--message)
        shift
        TAG_MESSAGE="${1:-}"
        [[ -n "$TAG_MESSAGE" ]] || die "--message requires a value"
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "unknown option: $1"
        ;;
    esac
    shift
  done
}

ensure_repo_root() {
  local root
  root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  [[ -n "$root" ]] || die "not inside a git repository"
  cd "$root"
}

validate_version() {
  [[ "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]] \
    || die "invalid version format: $VERSION (expected example: v4.14.2.a)"
}

ensure_clean_tree() {
  if [[ "$ALLOW_DIRTY" == true ]]; then
    return
  fi

  if [[ -n "$(git status --porcelain)" ]]; then
    die "working tree is not clean. Commit/stash changes or pass --allow-dirty"
  fi
}

ensure_docker() {
  command -v docker >/dev/null 2>&1 || die "docker is not installed or not in PATH"
}

create_git_tag() {
  if git rev-parse "$VERSION" >/dev/null 2>&1; then
    die "git tag $VERSION already exists"
  fi

  local message="${TAG_MESSAGE:-release $VERSION}"
  log "Creating annotated git tag $VERSION"
  git tag -a "$VERSION" -m "$message"
  log "Git tag created: $VERSION"

  if [[ "$PUSH" == true ]]; then
    log "Pushing git tag $VERSION"
    git push origin "$VERSION"
  fi
}

build_docker_image() {
  local dockerfile
  dockerfile="$(mktemp "${TMPDIR:-/tmp}/chatwoot-sm-Dockerfile.XXXXXX")"

  trap "rm -f '${dockerfile}'" EXIT

  cp docker/Dockerfile "$dockerfile"
  printf '\nENV CW_EDITION="%s"\n' "$RELEASE_EDITION" >> "$dockerfile"

  local image_tag="${DOCKER_IMAGE}:${VERSION}"

  log "Building Docker image ${image_tag} (${DOCKER_PLATFORM}, edition=${RELEASE_EDITION})"
  log "Tip: prefer ./scripts/release_git.sh so GitHub Actions builds the image"
  docker build \
    --platform "$DOCKER_PLATFORM" \
    -f "$dockerfile" \
    -t "$image_tag" \
    .

  if [[ "$PUSH" == true ]]; then
    log "Pushing ${image_tag}"
    docker push "$image_tag"
  else
    log "Skipping docker push (pass --push to publish)"
  fi
}

promote_latest_tag() {
  ensure_docker

  local image_tag="${DOCKER_IMAGE}:${VERSION}"
  local latest_tag="${DOCKER_IMAGE}:latest"

  if ! docker image inspect "$image_tag" >/dev/null 2>&1; then
    log "Local image not found, pulling ${image_tag}"
    docker pull "$image_tag"
  fi

  docker tag "$image_tag" "$latest_tag"
  log "Tagged ${latest_tag} from ${image_tag}"

  if [[ "$PUSH" == true ]]; then
    log "Pushing ${latest_tag}"
    docker push "$latest_tag"
  else
    log "Skipping docker push (pass --push to publish :latest)"
  fi
}

print_summary() {
  cat <<EOF

Release steps completed for ${VERSION}

Docker image:
  ${DOCKER_IMAGE}:${VERSION}

Git tag:
  ${VERSION}

Preferred release flow:
  1. Update CHANGELOG.md and commit
  2. ./scripts/release_git.sh ${VERSION}
  3. Wait for GitHub Actions (image + GitHub Release)
  4. Deploy: image: ${DOCKER_IMAGE}:${VERSION}
  5. After production validation, promote :latest:
     ./scripts/release.sh ${VERSION} --promote-latest --push

EOF
}

main() {
  parse_args "$@"
  ensure_repo_root
  validate_version

  if [[ "$PROMOTE_LATEST" == true ]]; then
    promote_latest_tag
    print_summary
    return
  fi

  ensure_clean_tree

  if [[ "$SKIP_TAG" == false ]]; then
    create_git_tag
  fi

  if [[ "$SKIP_DOCKER" == false ]]; then
    ensure_docker
    build_docker_image
  fi

  print_summary
}

main "$@"

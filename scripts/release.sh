#!/usr/bin/env bash
#
# Release script for chatwoot-sm (fork).
#
# Builds the Enterprise Docker image, tags it, and creates a matching git tag.
#
# Usage:
#   ./scripts/release.sh v4.14.2.a
#   ./scripts/release.sh v4.14.2.a --push
#   ./scripts/release.sh v4.14.2.a --skip-docker
#   ./scripts/release.sh v4.14.2.a --skip-tag
#
# Environment overrides:
#   DOCKER_IMAGE=sidneynma/chatwoot-sm
#   DOCKER_PLATFORM=linux/amd64
#   RELEASE_EDITION=ee
#
set -euo pipefail

DOCKER_IMAGE="${DOCKER_IMAGE:-sidneynma/chatwoot-sm}"
DOCKER_PLATFORM="${DOCKER_PLATFORM:-linux/amd64}"
RELEASE_EDITION="${RELEASE_EDITION:-ee}"
VERSION=""
PUSH=false
SKIP_DOCKER=false
SKIP_TAG=false
ALLOW_DIRTY=false
TAG_MESSAGE=""

usage() {
  sed -n '3,14p' "$0" | sed 's/^# \{0,1\}//'
  echo
  echo "Options:"
  echo "  --push         Push Docker image and git tag to remote"
  echo "  --skip-docker  Only create the git tag"
  echo "  --skip-tag     Only build/push the Docker image"
  echo "  --allow-dirty  Allow uncommitted changes"
  echo "  -m, --message  Annotated tag message (default: release \$VERSION)"
  echo "  -h, --help     Show this help"
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

  cleanup() {
    rm -f "$dockerfile"
  }
  trap cleanup EXIT

  cp docker/Dockerfile "$dockerfile"
  printf '\nENV CW_EDITION="%s"\n' "$RELEASE_EDITION" >> "$dockerfile"

  local image_tag="${DOCKER_IMAGE}:${VERSION}"
  local latest_tag="${DOCKER_IMAGE}:latest"

  log "Building Docker image ${image_tag} (${DOCKER_PLATFORM}, edition=${RELEASE_EDITION})"
  docker build \
    --platform "$DOCKER_PLATFORM" \
    -f "$dockerfile" \
    -t "$image_tag" \
    .

  docker tag "$image_tag" "$latest_tag"
  log "Tagged ${latest_tag}"

  if [[ "$PUSH" == true ]]; then
    log "Pushing ${image_tag}"
    docker push "$image_tag"
    log "Pushing ${latest_tag}"
    docker push "$latest_tag"
  else
    log "Skipping docker push (pass --push to publish)"
  fi
}

print_summary() {
  cat <<EOF

Release steps completed for ${VERSION}

Docker image:
  ${DOCKER_IMAGE}:${VERSION}
  ${DOCKER_IMAGE}:latest

Git tag:
  ${VERSION}

Next steps:
  1. Update CHANGELOG.md if not done yet
  2. Re-run with --push to publish image/tag when ready
  3. Deploy using:
     image: ${DOCKER_IMAGE}:${VERSION}

EOF
}

main() {
  parse_args "$@"
  ensure_repo_root
  validate_version
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

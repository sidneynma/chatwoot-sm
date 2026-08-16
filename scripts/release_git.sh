#!/usr/bin/env bash
#
# Prepare a chatwoot-sm git release (no local Docker build).
#
# Creates an annotated tag, pushes the current branch, then pushes the tag.
# GitHub Actions (.github/workflows/release_chatwoot_sm.yml) builds/pushes the
# Docker image and creates the GitHub Release when the tag arrives.
#
# Usage:
#   ./scripts/release_git.sh v4.16.2.d
#   ./scripts/release_git.sh v4.16.2.d -m "fix disparador schedule status"
#   ./scripts/release_git.sh v4.16.2.d --dry-run
#
# Prerequisites:
#   1. Feature commits already done
#   2. CHANGELOG.md updated for this version and committed
#   3. Working tree clean
#
set -euo pipefail

VERSION=""
TAG_MESSAGE=""
DRY_RUN=false
ALLOW_DIRTY=false
SKIP_CHANGELOG_CHECK=false

usage() {
  sed -n '3,18p' "$0" | sed 's/^# \{0,1\}//'
  echo
  echo "Options:"
  echo "  -m, --message   Annotated tag message (default: release \$VERSION)"
  echo "  --dry-run       Print actions without tagging/pushing"
  echo "  --allow-dirty   Allow uncommitted changes"
  echo "  --skip-changelog-check  Do not require CHANGELOG.md to mention the version"
  echo "  -h, --help      Show this help"
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
    die "version is required (example: v4.16.2.d)"
  fi

  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    usage
    exit 0
  fi

  VERSION="$1"
  shift

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -m|--message)
        shift
        TAG_MESSAGE="${1:-}"
        [[ -n "$TAG_MESSAGE" ]] || die "--message requires a value"
        ;;
      --dry-run) DRY_RUN=true ;;
      --allow-dirty) ALLOW_DIRTY=true ;;
      --skip-changelog-check) SKIP_CHANGELOG_CHECK=true ;;
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
    || die "invalid version format: $VERSION (expected example: v4.16.2.d)"
}

ensure_clean_tree() {
  if [[ "$ALLOW_DIRTY" == true ]]; then
    return
  fi

  if [[ -n "$(git status --porcelain)" ]]; then
    die "working tree is not clean. Commit/stash changes or pass --allow-dirty"
  fi
}

ensure_changelog() {
  if [[ "$SKIP_CHANGELOG_CHECK" == true ]]; then
    return
  fi

  [[ -f CHANGELOG.md ]] || die "CHANGELOG.md not found — update it before releasing"

  if ! grep -qF "## [${VERSION}]" CHANGELOG.md; then
    die "CHANGELOG.md has no section ## [${VERSION}] — update and commit it first"
  fi
}

ensure_tag_absent() {
  if git rev-parse "$VERSION" >/dev/null 2>&1; then
    die "git tag $VERSION already exists"
  fi
}

current_branch() {
  local branch
  branch="$(git rev-parse --abbrev-ref HEAD)"
  [[ "$branch" != "HEAD" ]] || die "detached HEAD — checkout a branch before releasing"
  printf '%s\n' "$branch"
}

run() {
  if [[ "$DRY_RUN" == true ]]; then
    printf 'dry-run: %s\n' "$*"
    return
  fi
  "$@"
}

main() {
  parse_args "$@"
  ensure_repo_root
  validate_version
  ensure_clean_tree
  ensure_changelog
  ensure_tag_absent

  local branch message
  branch="$(current_branch)"
  message="${TAG_MESSAGE:-release $VERSION}"

  log "Branch: $branch"
  log "Version: $VERSION"

  log "Creating annotated git tag $VERSION"
  run git tag -a "$VERSION" -m "$message"

  log "Pushing branch $branch"
  run git push -u origin "$branch"

  log "Pushing tag $VERSION"
  run git push origin "$VERSION"

  cat <<EOF

Git release prepared for ${VERSION}

Branch pushed: ${branch}
Tag pushed:    ${VERSION}

GitHub Actions will:
  1. Build/push Docker image sidneynma/chatwoot-sm:${VERSION}
  2. Create GitHub Release titled ${VERSION}

Watch: https://github.com/sidneynma/chatwoot-sm/actions

After production validation, promote :latest:
  ./scripts/release.sh ${VERSION} --promote-latest --push

EOF
}

main "$@"

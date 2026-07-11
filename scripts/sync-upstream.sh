#!/usr/bin/env bash
#
# Rebase the Zeo commit stack (patches + rebrand) onto a newer upstream snapshot.
#
#   sync-upstream.sh [--repo <path>] [--to <ref>] [--build-cmd <cmd>]
#
# Failure is non-destructive by design (design.md D6): on a rebase conflict or a
# failing build gate the branch is left pinned at its last-good SHA and the script
# exits non-zero. No temporary tag or rebase state survives any outcome (R5.4).

set -euo pipefail

REPO="fork"
TO="upstream/main"
BUILD_CMD="cargo check"

readonly BRANCH="zeo"
readonly TAG="zeo-pre-sync"

usage() {
    cat <<'EOF'
Usage: sync-upstream.sh [--repo <path>] [--to <ref>] [--build-cmd <cmd>]

  --repo       path to the fork repository        (default: fork)
  --to         ref to rebase onto                 (default: upstream/main)
  --build-cmd  build gate run after the rebase    (default: cargo check)

Exit status: 0 on a clean sync; non-zero on conflict or a failing build gate
(in both cases the branch stays at its pre-sync, last-good SHA).
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --repo)      REPO="${2:?--repo needs a path}";       shift 2 ;;
        --to)        TO="${2:?--to needs a ref}";            shift 2 ;;
        --build-cmd) BUILD_CMD="${2:?--build-cmd needs a command}"; shift 2 ;;
        -h|--help)   usage; exit 0 ;;
        *) printf 'unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
done

git_in_repo=(git -C "$REPO")

if ! "${git_in_repo[@]}" rev-parse --git-dir >/dev/null 2>&1; then
    printf 'FAIL: not a git repository: %s\n' "$REPO" >&2
    exit 1
fi

GIT_DIR_ABS="$("${git_in_repo[@]}" rev-parse --absolute-git-dir)"
readonly GIT_DIR_ABS

if ! "${git_in_repo[@]}" show-ref --verify --quiet "refs/heads/$BRANCH"; then
    printf 'FAIL: branch %s does not exist in %s\n' "$BRANCH" "$REPO" >&2
    exit 1
fi

# R5.4: whatever happens, never leave a rollback tag or a half-finished rebase behind.
cleanup() {
    if [ -d "$GIT_DIR_ABS/rebase-merge" ] || [ -d "$GIT_DIR_ABS/rebase-apply" ]; then
        "${git_in_repo[@]}" rebase --abort >/dev/null 2>&1 || true
    fi
    "${git_in_repo[@]}" tag -d "$TAG" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# Conflict resolutions recorded here replay on the next daily rebase.
"${git_in_repo[@]}" config rerere.enabled true

remote="${TO%%/*}"
printf 'fetching %s\n' "$remote"
if ! "${git_in_repo[@]}" fetch "$remote"; then
    printf 'FAIL: could not fetch from remote %s\n' "$remote" >&2
    exit 1
fi

"${git_in_repo[@]}" switch "$BRANCH" >/dev/null 2>&1 || "${git_in_repo[@]}" checkout "$BRANCH"

pre_sha="$("${git_in_repo[@]}" rev-parse "$BRANCH")"
"${git_in_repo[@]}" tag -f "$TAG" "$pre_sha" >/dev/null
pre_short="${pre_sha:0:12}"

# Detect a no-op BEFORE rebasing: `git rebase` exits 0 and prints its own
# "up to date" chatter when there is nothing to replay, which would otherwise
# be indistinguishable from a real rebase in the summary line below.
to_sha="$("${git_in_repo[@]}" rev-parse "$TO")"
rebased=1
if "${git_in_repo[@]}" merge-base --is-ancestor "$to_sha" "$BRANCH"; then
    rebased=0
    printf '%s is already an ancestor of %s; nothing to rebase (pre-sync %s)\n' \
        "$TO" "$BRANCH" "$pre_short"
else
    printf 'rebasing %s onto %s (pre-sync %s)\n' "$BRANCH" "$TO" "$pre_short"
    if ! "${git_in_repo[@]}" rebase "$TO"; then
        "${git_in_repo[@]}" rebase --abort >/dev/null 2>&1 || true
        "${git_in_repo[@]}" reset --hard "$pre_sha" >/dev/null
        printf 'FAIL: rebase onto %s hit a conflict; aborted. %s stays pinned at the last-good SHA %s. Resolve manually, then re-run.\n' \
            "$TO" "$BRANCH" "$pre_short" >&2
        exit 1
    fi
fi

new_sha="$("${git_in_repo[@]}" rev-parse "$BRANCH")"
new_short="${new_sha:0:12}"

printf 'build gate: %s\n' "$BUILD_CMD"
if ! (cd "$REPO" && bash -c "$BUILD_CMD"); then
    "${git_in_repo[@]}" reset --hard "$pre_sha" >/dev/null
    rebase_clause=""
    if [ "$rebased" -eq 1 ]; then
        rebase_clause=" after the rebase"
    fi
    printf 'FAIL: build gate failed%s; %s restored to its pre-sync state %s.\n' \
        "$rebase_clause" "$BRANCH" "$pre_short" >&2
    exit 1
fi

printf '%s\n' "$new_sha" >"$GIT_DIR_ABS/zeo-last-good"
if [ "$rebased" -eq 1 ]; then
    printf 'OK: %s rebased onto %s and gated green; last-good recorded as %s\n' \
        "$BRANCH" "$TO" "$new_short"
else
    printf 'OK: %s already up to date with %s at %s (nothing to rebase)\n' \
        "$BRANCH" "$TO" "$new_short"
fi

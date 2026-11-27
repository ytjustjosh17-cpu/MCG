#!/usr/bin/env bash
# Push in one command, ONLY after the owner has said "push":
#   tools/release.sh
# Refuses with uncommitted changes, runs every check, pushes the working
# branch and waits for GitHub's checks. A push never makes a release: that
# only happens when the owner says "release" (Actions > Android APK > Run
# workflow, then Tidy releases).
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
REPO="ytjustjosh17-cpu/MCG"

if [ -n "$(git status --porcelain)" ]; then
	echo "Uncommitted changes: commit them first."; git status --short | head; exit 1
fi
if [ -z "$(git log "origin/$BRANCH..HEAD" --oneline 2>/dev/null)" ]; then
	echo "Nothing new to release."; exit 0
fi
if [ "$(cat .git/sol-checked 2>/dev/null)" = "$(git rev-parse HEAD)" ]; then
	echo "All checks already passed on this exact version: skipping the local run."
else
	"$ROOT/tools/check_all.sh" || { echo "Checks failed: not pushing."; exit 1; }
fi

for i in 1 2 3 4; do
	git push -q origin "$BRANCH" && break
	echo "push failed, retrying"; sleep $((2 ** i))
done
SHA="$(git rev-parse --short=7 HEAD)"
echo "Pushed $SHA, waiting for the checks..."
for i in $(seq 1 90); do
	r=$(curl -s "https://api.github.com/repos/$REPO/actions/runs?per_page=5" | python3 -c "
import sys,json
for d in json.load(sys.stdin).get('workflow_runs',[]):
    if d['head_sha'].startswith('$SHA'):
        print(d['run_number'], d['status'], d['conclusion']); break" 2>/dev/null)
	case "$r" in
		*completed*success*) echo "Checks and build ok (run ${r%% *}). Not released: that needs \"release\"."; exit 0;;
		*completed*) echo "Build finished but not ok: $r. Check the Actions log."; exit 1;;
	esac
	sleep 20
done
echo "Still building after 30 minutes; check GitHub Actions."; exit 1

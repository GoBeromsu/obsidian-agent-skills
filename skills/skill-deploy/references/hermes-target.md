# hermes-target — skill-deploy reference

## Why Hermes (not ClawHub) + why per-skill docker cp

Hermes classifies skills by source similarly to OpenClaw's `openclaw-managed` pattern. ClawHub's CLI (`openclaw skills install` / `update`) was always a read-only consume path for third-party skills — there was no publish command and no local `clawhub` CLI for pushing a vault SSOT upstream. Hermes inherits the same model: skills you own live in `~/.hermes/skills/<name>/` (global) or `~/.hermes/agents/<agent>/workspace/skills/<name>/` (agent-scoped), and the only safe ingress is `docker cp`.

Running `docker cp` per-skill (rather than at the `~/.hermes/skills/` root) is essential because Hermes may have private skills installed by `hermes claw migrate` that are not in the vault. A root-level copy or rsync with `--delete` would destroy them. Scoping to one `$skill/` directory removes only stale files inside that skill, never sibling skills.

Direct `rsync` into a running container's overlayfs is unreliable — Docker overlayfs does not guarantee atomic visibility of rsync's incremental writes. The safe pattern is: rsync to a host staging directory (`~/.hermes-stage/`), then `docker cp` the staged directory into the container in a single operation.

Historical note: before 2026-04-21, target #4 deployed to `m1-pro:~/.openclaw/skills/` via rsync. The `~/.openclaw/` tree is kept as a 30-day standby (`ai.openclaw.gateway.plist` stays loaded until BNC on Hermes completes its first successful scheduled run). After that, unload with `launchctl unload ~/Library/LaunchAgents/ai.openclaw.gateway.plist`.

## GitHub deploy runbook (Steps 2–5)

```bash
REPO="${OBSIDIAN_AGENT_SKILLS_REPO_PATH:-$HOME/dev/obsidian-agent-skills}"
VAULT="/Users/beomsu/Documents/01. Obsidian/Ataraxia/50. AI/04 Skills/Obsidian"

# Step 2 — Prepare repo
if [ ! -d "$REPO/.git" ]; then
  gh repo view GoBeromsu/obsidian-agent-skills &>/dev/null || \
    gh repo create GoBeromsu/obsidian-agent-skills --public \
      --description "Personal Claude Code + Codex + Hermes skill collection"
  gh repo clone GoBeromsu/obsidian-agent-skills "$REPO"
fi
git -C "$REPO" pull --rebase

# Step 3 — Copy publishable skills
for skill in <publishable-skill-list>; do
  DEST="$REPO/skills/Obsidian/$skill"
  mkdir -p "$DEST"
  cp "$VAULT/$skill/SKILL.md" "$DEST/"
  for dir in scripts references assets; do
    [ -d "$VAULT/$skill/$dir" ] && cp -r "$VAULT/$skill/$dir/" "$DEST/$dir/"
  done
  # Write agent_skill_scope marker for Step 6 gating
  STUB="$VAULT/$skill/$skill.md"
  awk '/^agent_skill_scope:/{flag=1;next} /^[a-zA-Z_]+:/{flag=0} flag && /^  - /{print $2}' "$STUB" > "$DEST/.agent_skill_scope"
  # Default to [claude] if the stub is missing the field
  [ -s "$DEST/.agent_skill_scope" ] || echo claude > "$DEST/.agent_skill_scope"
done

# Step 4 — Version bump
PLUGIN_JSON="$REPO/.claude-plugin/plugin.json"
CURRENT=$(grep -o '"version": "[^"]*"' "$PLUGIN_JSON" | grep -o '[0-9]*\.[0-9]*\.[0-9]*')
PATCH=$(echo "$CURRENT" | cut -d. -f3)
NEW_VERSION="$(echo "$CURRENT" | cut -d. -f1-2).$((PATCH + 1))"
sed -i '' "s/\"version\": \"$CURRENT\"/\"version\": \"$NEW_VERSION\"/" "$PLUGIN_JSON"
echo "Version: $CURRENT → $NEW_VERSION"

# Step 5 — Branch, commit, PR, merge
BRANCH="deploy/$(date +%Y%m%d-%H%M%S)"
git -C "$REPO" checkout -b "$BRANCH"
git -C "$REPO" add skills/ .claude-plugin/plugin.json
git -C "$REPO" diff --cached --quiet && {
  echo "Already up to date."
  git -C "$REPO" checkout main
  git -C "$REPO" branch -D "$BRANCH"
  exit 0
}
git -C "$REPO" commit -m "deploy: sync skills from vault ($(date +%Y-%m-%d))"
git -C "$REPO" push -u origin "$BRANCH"
PR_URL=$(gh pr create --repo GoBeromsu/obsidian-agent-skills \
  --title "deploy: sync skills from vault ($(date +%Y-%m-%d))" \
  --body "Automated deploy from skill-deploy. See commits for details." \
  --base main --head "$BRANCH")
echo "Opened $PR_URL"
gh pr merge "$PR_URL" --squash --admin --delete-branch
git -C "$REPO" checkout main
git -C "$REPO" pull --rebase
```

**Why `--admin`?** The repo is personal, unprotected, single-maintainer. There is no reviewer to wait on. If the repo ever gains branch protection (required reviews/checks), drop `--admin` and block on review before Step 6.

**Why `--delete-branch`?** Keeps the branch list clean. The squash-merged content is already on `main`.

## Hermes cron CLI fallback runbook

Preferred path — if the Hermes CLI supports it:

```bash
ssh m1-pro "docker exec $HC hermes cron add --agent xia --skill brian-note-challenge --schedule '0 7 * * *'"
ssh m1-pro "docker exec $HC hermes cron list"
```

Fallback — if `hermes cron` CLI is unavailable, use host crontab:

```bash
# On m1-pro
crontab -e
# Add:
0 7 * * * docker exec $HC hermes skill run brian-note-challenge
```

Guardrail: never run `docker cp` during a cron quiet window while the skill is actively executing. If deploying to a busy container, signal graceful shutdown first:

```bash
ssh m1-pro "docker exec $HC pkill -SIGTERM hermes-gateway"
# wait for shutdown, then docker cp, then restart
ssh m1-pro "docker exec $HC hermes gateway start"
```

## Container lifecycle notes

Confirm vault is mounted into the container:

```bash
ssh m1-pro 'docker inspect $HC --format "{{json .Mounts}}"' | jq .
```

If the vault is not mounted, BNC (and any other vault-writing skill) will fail silently. Remediation: recreate the container with `-v $HOME/Documents/01. Obsidian:/obsidian` and re-run `hermes claw migrate`.

Verify `gws` auth is alive inside the container before the first cron run:

```bash
ssh m1-pro "docker exec $HC gws auth status"
```

If auth is missing, either run `docker exec $HC gws auth login` or bind-mount the host credentials: add `-v $HOME/.config/gws:/root/.config/gws` to the container run command.

## OpenClaw and Hermes coexist

OpenClaw and Hermes run in parallel on m1-pro. A single skill whose `agent_skill_scope` lists both `openclaw` and `hermes` is deployed to both runtimes in the same run — OpenClaw via rsync to its workspace (see the `openclaw` skill for the current workspace path), Hermes via the `docker cp` leg above. Do not treat either runtime as deprecated unless the skill's own stub explicitly carries `deprecated: true`.

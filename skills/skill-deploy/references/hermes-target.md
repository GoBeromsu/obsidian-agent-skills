# hermes-target — skill-deploy reference

## Why native Hermes (not Docker) + why per-skill rsync

Hermes now runs natively on m1-pro (`/Users/beomsu/.local/bin/hermes`, v0.10.0+). The prior Docker path is retired. Skills the vault owns land at `~/.hermes/skills/openclaw-imports/<name>/`; the parent `openclaw-imports/` folder groups everything that entered Hermes through the vault-SSOT pipeline. Sibling Hermes-private skills (installed via `hermes claw migrate`) live alongside them in the same folder.

Because private skills and vault skills coexist under `openclaw-imports/`, a root-level `rsync --delete` would destroy private skills. The safe pattern is per-skill rsync scoped to a single `<skill>/` directory — `--delete` then removes only stale files inside that skill, never sibling skills. The same rule applies to OpenClaw (`~/.openclaw/skills/`) and Codex (`~/.codex/skills/`): each hosts sibling skills the vault does not own.

Hermes classifies skills by source similarly to OpenClaw's `openclaw-managed` pattern. ClawHub's CLI (`openclaw skills install` / `update`) was a read-only consume path for third-party skills — there was no publish command and no local `clawhub` CLI for pushing a vault SSOT upstream. Hermes inherits the same model: skills you own ingress via per-skill rsync; there is no publish command on the Hermes side.

Historical notes:
- Before 2026-04-22, Hermes ingress was `rsync → host stage → docker cp` into a Docker container. The container path was deprecated when Hermes moved to a native install; all deploys now use plain filesystem rsync over ssh.
- Before 2026-04-21, target `openclaw` deployed to `m1-pro:~/.openclaw/skills/` only. The `~/.openclaw/` tree is kept as a 30-day standby (`ai.openclaw.gateway.plist` stays loaded until BNC on Hermes completes its first successful scheduled run). After that, unload with `launchctl unload ~/Library/LaunchAgents/ai.openclaw.gateway.plist`.

## GitHub deploy runbook (Steps 2–5)

```bash
REPO="${OBSIDIAN_AGENT_SKILLS_REPO_PATH:-$HOME/dev/agent-skills}"
VAULT="/Users/beomsu/Documents/01. Obsidian/Ataraxia/50. AI/04 Skills/Obsidian"

# Step 2 — Prepare repo
if [ ! -d "$REPO/.git" ]; then
  gh repo view GoBeromsu/obsidian-agent-skills &>/dev/null || \
    gh repo create GoBeromsu/obsidian-agent-skills --public \
      --description "Personal Claude Code + Codex + Hermes skill collection"
  gh repo clone GoBeromsu/obsidian-agent-skills "$REPO"
fi
git -C "$REPO" pull --rebase

# Step 3 — Copy publishable skills (exclude vault stub from repo)
for skill in <publishable-skill-list>; do
  DEST="$REPO/skills/$skill"
  mkdir -p "$DEST"
  rsync -a --delete \
    --exclude="$skill.md" \
    --exclude=".DS_Store" \
    --exclude=".obsidian" \
    "$VAULT/$skill/" "$DEST/"
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

**Repo rename note.** The repo was renamed on GitHub from `GoBeromsu/agent-skills` to `GoBeromsu/obsidian-agent-skills`. Pushes to the old URL still succeed via GitHub's redirect, but `gh` subcommands that require an explicit repo flag must use the new name (`--repo GoBeromsu/obsidian-agent-skills`). The Claude Code plugin name is still `agent-skills@beomsu-koh` — the plugin name is independent of the repo slug and should not be renamed lightly (settings, marketplace, and cache paths all key off it).

## Hermes cron runbook

Preferred path — the Hermes CLI supports cron directly:

```bash
ssh m1-pro "hermes cron add --agent xia --skill brian-note-challenge --schedule '0 7 * * *'"
ssh m1-pro "hermes cron list"
```

Fallback — if `hermes cron` is unavailable for a given build, use host crontab on m1-pro:

```bash
ssh m1-pro 'crontab -l'
# To edit interactively:
ssh m1-pro -t 'crontab -e'
# Sample entry:
# 0 7 * * * /Users/beomsu/.local/bin/hermes skill run brian-note-challenge
```

Guardrail: do not rsync a Hermes skill while it is actively executing. If the skill has a long-running cron job, schedule deploys during quiet windows or signal a graceful pause first:

```bash
ssh m1-pro "hermes gateway stop"
# deploy (per-skill rsync)
ssh m1-pro "hermes gateway start"
```

## Runtime verification

Confirm the native Hermes binary is present and healthy:

```bash
ssh m1-pro 'which hermes && hermes --version'
```

Confirm the expected skill landed:

```bash
ssh m1-pro "ls ~/.hermes/skills/openclaw-imports/<skill>/SKILL.md"
```

Verify `gws` auth is alive before the first cron run for any skill that writes to Google Workspace:

```bash
ssh m1-pro "gws auth status"
```

If auth is missing, run `ssh m1-pro "gws auth login"`.

## OpenClaw and Hermes coexist

OpenClaw and Hermes run in parallel on m1-pro. A single skill whose `agent_skill_scope` lists either `openclaw` / `openclaw-xia` plus `hermes` is deployed to both runtimes in the same run — OpenClaw via per-skill rsync to `~/.openclaw/skills/<skill>/` (global) or `~/.openclaw/workspace/skills/<skill>/` (xia-only), Hermes via per-skill rsync to `~/.hermes/skills/openclaw-imports/<skill>/`. Both use plain filesystem transport over tailscale ssh; neither requires Docker. Do not treat either runtime as deprecated unless the skill's own stub explicitly carries `deprecated: true`.

## openclaw vs openclaw-xia — agent-scoped routing

OpenClaw has no first-class per-agent skill directory yet. `agents.list[].skills` in `~/.openclaw/openclaw.json` is an **allowlist** that replaces the defaults rather than augmenting them, so using it to make a skill agent-specific would require restating every other skill the agent consumes. The workable alternative is the agent's workspace path: OpenClaw loads skills from `<workspace>/skills/` in addition to the global roots.

- **Main `xia` agent** resolves its workspace to `~/.openclaw/workspace/` (the default when `agents.list[].workspace` is unset or empty). No other agent shares that exact path; sibling agents get `~/.openclaw/workspace-xia-pkm-roundup/`, `workspace-obsidian-maestro/`, etc.
- Placing a skill at `~/.openclaw/workspace/skills/<skill>/` therefore loads only for main (`xia`) and is invisible to every other agent.
- Global skills stay in `~/.openclaw/skills/<skill>/` and load for every agent unless an agent's allowlist narrows the set.

Why obsidian-* skills route to `openclaw-xia`:

- Obsidian vault tooling (cli, bases, markdown, mermaid, sync, vault-doctor, clipper-template-creator) is only meaningful when an Obsidian instance is attached. In the current setup only `xia` runs attached to the vault; other agents (`xia-pkm-roundup`, `obsidian-maestro`) are scheduled/batch jobs that should not trigger or surface these skills.
- Keeping obsidian-* out of the global pool avoids the skill list growing for every agent in the gateway (reduces prompt surface + prevents accidental loading).

Mutual exclusivity: `openclaw` and `openclaw-xia` never coexist on one stub. `skill-deploy` aborts on that combination because rsync would leave the skill under both roots and OpenClaw would load it twice, double-counting the skill in the agent's context.

Migration: to flip a global skill to xia-only, (a) edit the stub's `agent_skill_scope` (replace `openclaw` with `openclaw-xia`), (b) run `/skill-deploy` (rsync deposits the skill under `~/.openclaw/workspace/skills/<skill>/`), (c) remove the stale global copy with `ssh m1-pro 'rm -rf ~/.openclaw/skills/<skill>'`. Step (c) is manual because skill-deploy's per-skill `rsync --delete` only removes files inside the destination it's writing; it never clears the opposite OpenClaw root.

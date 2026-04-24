# Safe File Update Pattern: Rename with Backlink Sync

## Context

This document captures a real session case where a vault file was renamed from
`📚 805 Job` to `📚 804 Job`. The session demonstrates the correct round-trip
pattern for renaming vault files when backlink integrity must be preserved.

---

## The Wrong Way: `bash mv`

```bash
# BAD — renames the file on disk but Obsidian does not detect the change
mv "Ataraxia/📚 805 Job.md" "Ataraxia/📚 804 Job.md"
```

**Result:** The file exists under the new name, but all `[[📚 805 Job]]` wikilinks
across the vault still point to the old name and resolve as unresolved links.
Obsidian's metadata cache is not notified, so backlinks break silently.

---

## The Right Way: `obsidian rename`

```bash
obsidian vault=Ataraxia rename file="📚 805 Job" name="📚 804 Job"
```

**Result:** Obsidian renames the file AND automatically updates every live
`[[📚 805 Job]]` reference across the vault to `[[📚 804 Job]]`. In the session
above, 22 files were updated in one command.

---

## Recovery Procedure

If you already used `bash mv` (wrong way) and need to recover:

1. **Revert the external rename** so Obsidian can see the original file again:
   ```bash
   mv "Ataraxia/📚 804 Job.md" "Ataraxia/📚 805 Job.md"
   ```
2. **Confirm Obsidian recognises the file** (wait a moment for the watcher):
   ```bash
   obsidian vault=Ataraxia file file="📚 805 Job"
   ```
3. **Perform the rename through Obsidian**:
   ```bash
   obsidian vault=Ataraxia rename file="📚 805 Job" name="📚 804 Job"
   ```

Obsidian will now update all backlinks automatically.

---

## Verification

After renaming, confirm zero stale references remain:

```bash
# 1. No live wikilinks to the old name
grep -rln '\[\[📚 805 Job' "Ataraxia/" --include="*.md"
# Expected: (empty output)

# 2. Backlinks point to the new name
obsidian vault=Ataraxia backlinks file="📚 804 Job"

# 3. File resolves under the new name
obsidian vault=Ataraxia file file="📚 804 Job"
```

---

## Edge Case: Escaped Markup

Escaped wikilinks such as `\[\[📚 805 Job\]\]` are **not** live links — they
are rendered as literal text in Obsidian. The `obsidian rename` command
correctly leaves these unchanged; they do not need updating and should not be
treated as broken references.

In the session above, one such escaped instance was found by grep but confirmed
to be a plain-text mention, not a resolvable link. This is expected and correct.

---

## Summary

| Approach | File renamed | Backlinks updated | Safe |
|----------|-------------|-------------------|------|
| `bash mv` | Yes | No | No |
| `obsidian rename` | Yes | Yes (automatic) | Yes |

Always use `obsidian rename` (or `obsidian move`) for vault file operations
that must preserve wikilink integrity.

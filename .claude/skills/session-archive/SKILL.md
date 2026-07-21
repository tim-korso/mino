---
name: session-archive
description: "会话结束时的结构化记忆存档——把设计决策、架构讨论、新模块方案从聊天提炼到持久化 memory 文件，让下一次启动不会失忆。七步管线：读索引→扫会话→更新 topic→建 session manifest→更新索引→更新导航→Git 提交。当用户说\"存档\"\"记一下\"\"存盘\"、会话涉及设计讨论或新模块、或结束活跃项目相关会话时触发。"
---

# Session Archive Skill

> **Trigger**: `/session-archive` — invoked manually at session end.
> **Purpose**: Capture design density from this session into structured memory files so future sessions can efficiently backtrack.

## When to Use

Invoke this skill:
- After any session where design exploration, architecture decisions, or new modules were discussed
- When the user says "archive this session", "记一下", "存盘"
- Before ending a session that touched active projects
- When new topic files were created or existing ones significantly updated

**Skip when**: purely conversational/Q&A, no design work done, no files changed.

## Pipeline

### Step 0: Read INDEX.md First

**Before scanning the session**, read `memory/INDEX.md`. You need to know:

- What topic files already exist (to avoid creating duplicates)
- What status each topic is in (active/dormant/complete)
- When each was last updated (to know what's stale)
- What recent sessions touched (to cross-reference)

Without this step, you're updating a map you haven't read.

### Step 1: Scan Session

Review the current conversation. Cross-reference against INDEX.md:

1. **Topics touched** — which existing topic files were discussed? Any new topics emerge? Check: does INDEX.md already list this topic?
2. **Decisions made** — what was chosen, what was rejected, and why?
3. **Files changed** — what was created, modified, or deleted?
4. **Design artifacts** — any sketches, diagrams, images shared?
5. **Pending items** — what was started but not finished? What should the next session pick up?

### Step 2: Update/Create Topic Files

For each topic touched:

**If topic file exists** → Update it:
- Update "last worked on" date in Quick Reference
- Add new decisions to "Key Design Decisions"
- Update "Known Limitations" if new ones discovered
- Update "Pending Optimizations" if priorities changed
- Add row to "Session History"

**If topic is new** → Create `memory/topics/<name>.md`:
- Copy from `memory/.template-topic.md`
- Fill all REQUIRED sections
- Cross-link to related topics with [[wikilinks]]

**Design capture rule**: When design sketches or images were shared, extract their content (text from images, structure from diagrams) and include in the Architecture section. Don't just reference the image path — images may not load in future sessions.

### Step 3: Create Session Manifest

Create `memory/sessions/YYYY-MM-DD-<slug>.md` using the template at `memory/.template-session.md`.

The `<slug>` should capture the session's main theme (e.g., `goal-loop-restore`, `memory-system-design`).

### Step 4: Update INDEX.md

Update `memory/INDEX.md`:
- Add new topics to the Active Topics table
- Update "last rebuilt" date
- Update stats (N topics, N sessions)
- Add this session to Recent Sessions table
- Add any new key files to Key Files table

### Step 5: Update 04-MEMORY.md

If new topics or projects were created, add pointers in `memory/.claude/rules/04-MEMORY.md` Active Projects table.

Do NOT duplicate information from INDEX.md into 04-MEMORY.md. 04-MEMORY is for navigation pointers + critical cross-project lessons only.

### Step 6: Write/Update Daily Journal

Write `memory/YYYY-MM-DD.md` if not already written. Include:
- What happened today
- Key decisions and their rationale
- Files created/modified
- Pending items for next session
- 探路叙事 (🧭 探索) if a non-trivial implementation was completed

### Step 7: Git Commit + Push

```bash
git add memory/ .claude/rules/04-MEMORY.md
git commit -m "memory: YYYY-MM-DD — <session summary>"
git push
```

Commit message format: `memory: YYYY-MM-DD — <one-line session summary>`

## Output

At the end of the archive process, output a summary:

```
📦 Session Archived: <YYYY-MM-DD>

Topics Updated: N (list names)
Topics Created: N (list names)
Session Manifest: memory/sessions/<file>.md
INDEX.md: updated
04-MEMORY.md: updated / no changes
Daily Journal: written / already exists
Git: committed + pushed ✅
```

## Design Principles

1. **Design density must survive the session.** Ideas discussed but not written to topic files are lost.
2. **INDEX.md is the gateway.** Every new session reads it first. Keep it current.
3. **Quick Reference is the second gateway.** Every topic file's Quick Reference must be readable in 10 seconds.
4. **Session manifests provide temporal navigation.** "What else were we working on when we designed goal loop?" → answer lives in session manifests.
5. **Don't just reference images — extract them.** Qwen-VL-Plus or similar vision models can extract text from design sketches. Do this at archive time, not at retrieval time.
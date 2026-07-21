# Domain Auto-Discovery

Static domain lists are dead on arrival. These live sources tell you what's actually working right now.

## Monitoring Services (check before every search)

```
Library Genesis:  https://libgen.help          — 5-min refresh, shows all mirrors + speed
Sci-Hub:          Wikipedia "Sci-Hub" article   — community-maintained domain list
Anna's Archive:   Wikipedia "Anna's Archive"    — official + community domains
Z-Library:        @Z_Lib_Official_Bot → /link   — official single-login portal
Cloud Search:     https://www.wowenda.com       — monitors all Chinese search engines
```

## Agent Integration

### 1. Before Any Search

```bash
# Quick check: which LibGen mirror is fastest?
curl -s https://libgen.help | grep -oP 'libgen\.[a-z]{2,3}' | head -5

# Or use our script
bash scripts/domain-check.sh --json
```

### 2. Domain Health Check

```bash
# Verify all domains in references are alive
bash scripts/domain-check.sh

# JSON output for programmatic use
bash scripts/domain-check.sh --json > /tmp/domain-status.json
```

### 3. Auto-Fallback Pattern

```
For each resource search:
  1. Read live domain list (libgen.help → fastest mirror)
  2. Try primary domain
  3. On failure → try next mirror
  4. On all mirrors failed → check Wikipedia for new domain
  5. Still failed → fall to TG Bot API channel
```

## Domain Rotation Patterns

### Shadow Libraries

| Service | Pattern | Frequency |
|---------|---------|-----------|
| Anna's Archive | Country TLDs (.gl → .pk → .gd) | Every 1-3 months |
| LibGen | Mirror list rotates (.li → .la → .ee) | Monthly |
| Sci-Hub | Country TLDs (.se → .st → .ru) | Every 6-12 months |
| Z-Library | Single-login portal + TG Bot most stable | — |

### Chinese Cloud Search

| Service | Pattern | Frequency |
|---------|---------|-----------|
| 猫狸盘搜 (alipansou.com) | Main domain stable | Rarely changes |
| 网盘搜索引擎 (small ones) | Random domain changes | Monthly/weekly |
| 鸠摩搜书 | jiumodiary.com stable | Rarely changes |

## What to Do When a Domain Dies

1. **Wikipedia** — search "X (website)" article → check infobox for current URL
2. **Reddit** — r/Piracy, r/libgen, r/Annas_Archive, r/Scholar → megathreads
3. **Telegram** — @jisou search for "X 最新地址" or "X mirror"
4. **网盘之家** — wowenda.com monitors cloud search engine health
5. **GitHub** — Search "awesome-piracy" or "awesome-cn-cafe" for updated lists

## Scheduled Domain Verification

For a cron-based auto-check:

```bash
# Runs daily, reports dead domains
bash scripts/domain-check.sh && echo "All domains OK" || echo "Some domains dead — check output"

# Set up via MyAgents cron
myagents cron add \
  --name "smmart-domain-check" \
  --prompt "Run bash scripts/domain-check.sh in smmart skill. Report any dead domains with suggested alternatives." \
  --every 1440
```

## Why This Exists

The old download-anything skill had 40 static domains. In the 2 months since it was written (May 31 → Jul 9):
- Anna's Archive lost .org, .li, .se, .in, .pm — only .gl, .pk, .gd remain
- cmacked/macbed/macserialjunkie went offline — replaced by xmac.app/haxmac.cc
- 123云盘 changed from free unlimited to 10GB/month login-required
- Alist was sold — community forked to OpenList

Static = stale. Live = works.

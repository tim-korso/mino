#!/bin/bash
# 每日学习摘要——自动生成 + 通知
DB="$HOME/.mac-learn.db"

python3 << PYEOF
import sqlite3, statistics
db = sqlite3.connect("$DB")

snaps = db.execute("SELECT COUNT(*) FROM snapshots").fetchone()[0]
rules = db.execute("SELECT COUNT(*) FROM suggested_rules").fetchone()[0]
adopted = db.execute("SELECT COUNT(*) FROM suggested_rules WHERE adopted=1").fetchone()[0]
lt = db.execute("SELECT * FROM learned_thresholds WHERE metric='cpu'").fetchone()

# 今日新增
today = db.execute("SELECT COUNT(*) FROM snapshots WHERE ts >= date('now','localtime')").fetchone()[0]

print(f"════════════════════════")
print(f"  🧠 每日学习摘要")
print(f"  {__import__('subprocess').run(['date','+%Y-%m-%d %H:%M'], capture_output=True, text=True).stdout.strip()}")
print(f"════════════════════════")
print(f"  总样本: {snaps} (+{today} 今日)")
print(f"  CPU基线: {lt[1]:.1f}% ± {lt[2]:.1f}%")
print(f"  异常阈值: > {lt[3]:.1f}%")
print(f"  建议规则: {rules} ({adopted} 已采纳)")
print(f"  学习质量: {'A' if snaps > 100 else 'B' if snaps > 50 else 'C'} ({snaps}/100 样本)")
PYEOF

echo ""
echo "─── 通知 ───"
terminal-notifier -title "每日学习摘要" -subtitle "$(date +%m/%d)" -message "总样本: $(python3 -c "import sqlite3;db=sqlite3.connect('$DB');print(db.execute('SELECT COUNT(*) FROM snapshots').fetchone()[0])")" -sound default 2>/dev/null

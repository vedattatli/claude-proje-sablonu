#!/usr/bin/env bash
# PreCompact hook — baglam sikistirilmadan ONCE calisir.
#
# Cozdugu problem: sikistirma ozeti kurallari "bilgi"ye cevirir (CLAUDE.md'nin
# kendi itirafi). Sikistirmadan once durumu DISKE yaziyoruz ki ozet ne kadar
# kayip verirse versin, gercek durum dosyada dursun.

set -uo pipefail
P="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
cd "$P" 2>/dev/null || exit 0

DEVIR_DIZINI="05_OTURUM_DEVIR"; [ -f .claude/proje.conf ] && . .claude/proje.conf
kayit="${DEVIR_DIZINI}/.sikistirma-anlik-goruntu.md"
{
  echo "# Sikistirma oncesi anlik goruntu"
  echo "**Zaman:** $(date '+%Y-%m-%d %H:%M:%S')"
  echo
  if [ -d .git ]; then
    echo "## Git"
    git log --oneline -8 2>/dev/null | sed 's/^/- /'
    echo
    echo "## Commit'lenmemis"
    git status --short 2>/dev/null | sed 's/^/- /' | head -20
    echo
    echo "## Bu oturumda degisen dosyalar"
    git diff --stat HEAD~3..HEAD 2>/dev/null | tail -15 | sed 's/^/- /'
  fi
} > "${kayit}" 2>/dev/null

python3 -c 'import json,sys;print(json.dumps({"systemMessage":sys.argv[1]},ensure_ascii=False))' \
  "💾 Sikistirma oncesi durum diske yazildi: ${kayit}"
exit 0

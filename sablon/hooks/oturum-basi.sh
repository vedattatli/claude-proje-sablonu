#!/usr/bin/env bash
# SessionStart — oturum acilirken PROJE DURUMUNU otomatik baglama enjekte eder.
# Ayarlar: .claude/proje.conf
set -uo pipefail
P="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
cd "$P" 2>/dev/null || exit 0

DEVIR_DIZINI="05_OTURUM_DEVIR"; KARAR_DOSYASI="03_KARAR_GUNLUGU.md"
KURALLAR_DOSYASI="01_KIRMIZI_CIZGILER.md"; SORULAR_DOSYASI="02_ACIK_SORULAR.md"
RAPOR_DOSYASI=""
[ -f .claude/proje.conf ] && . .claude/proje.conf

girdi="$(cat 2>/dev/null || true)"
oturum="$(printf '%s' "$girdi" | python3 -c 'import sys,json
try: print(json.load(sys.stdin).get("session_id","bilinmiyor"))
except Exception: print("bilinmiyor")' 2>/dev/null || echo bilinmiyor)"
: > "/tmp/claude-oturum-${oturum}.damga" 2>/dev/null || true

{
echo "=== PROJE DURUMU — otomatik yuklendi (SessionStart hook) ==="
echo

# --- 0) SESSIZ ARIZALAR — en uste, cunku gomulurse fark edilmez ------------
# 02.08.2026 denetimi: Stop hook'unun systemMessage kanali modele ulasmiyor.
# Bu yuzden push arizasi ve PII uyarilari DISKTEN okunup buraya basilir.
if [ -f .claude/.push-basarisiz ]; then
  echo "## 🔴 UYARI — SON PUSH BASARISIZ OLDU"
  echo
  sed 's/^/    /' .claude/.push-basarisiz
  echo
  echo "    Calisma yalnizca bu diskte. Once bunu coz:  git push"
  echo "    Duzelince bu uyari kendiliginden kalkar."
  echo
fi

if [ -f .claude/pii-uyari.log ]; then
  adet_uyari="$(wc -l < .claude/pii-uyari.log 2>/dev/null || echo 0)"
  if [ "${adet_uyari}" -gt 0 ] 2>/dev/null; then
    echo "## ⚠ PII icerik uyarisi: ${adet_uyari} kayit (.claude/pii-uyari.log)"
    echo "   Bunlar ENGELLENMEDI — yalnizca isaretlendi. Son 3:"
    tail -3 .claude/pii-uyari.log | sed 's/^/    /'
    echo "   Ornek numaraysa sorun yok. Gercek veriyse kirmizi cizgi ihlali."
    echo
  fi
fi

son="$(ls -1t "${DEVIR_DIZINI}"/*.md 2>/dev/null | head -1)"
if [ -n "${son}" ]; then
  echo "## Son oturum devri: $(basename "${son}")"; echo
  sed -n '1,32p' "${son}"
  [ "$(wc -l < "${son}")" -gt 32 ] && { echo; echo "  (...devami: ${son})"; }
  echo
else
  echo "## ⚠ Hic oturum devri yok — ilk oturum."; echo
fi

if [ -f "${KARAR_DOSYASI}" ]; then
  echo "## Son 3 karar"
  grep -m 3 '^### ' "${KARAR_DOSYASI}" 2>/dev/null | sed 's/^### /- /'; echo
fi

if [ -n "${RAPOR_DOSYASI}" ] && [ -f "${RAPOR_DOSYASI}" ]; then
  s="$(sed -n '/^# 6 /,/^# 7 /p' "${RAPOR_DOSYASI}" 2>/dev/null | grep '^| [0-9]' || true)"
  [ -n "${s}" ] && { echo "## Bekleyen isler"; printf '%s\n' "${s}"; echo; }
fi

[ -f "${SORULAR_DOSYASI}" ] && { echo "## Acik sorular: $(grep -c '^| \*\*' "${SORULAR_DOSYASI}" 2>/dev/null | head -1) adet"; echo; }

if [ -d .git ]; then
  echo "## Git"
  if git rev-parse HEAD >/dev/null 2>&1; then
    echo "- Son commit: $(git log -1 --format='%h %s (%ar)' 2>/dev/null)"
  else echo "- ⚠ HIC COMMIT YOK"; fi
  echo "- Commit'lenmemis dosya: $(git status --porcelain 2>/dev/null | wc -l)"
  if git remote get-url origin >/dev/null 2>&1; then
    i="$(git log --oneline @{u}..HEAD 2>/dev/null | wc -l)"
    [ "${i}" != "0" ] && echo "- ⚠ Push'lanmamis commit: ${i}"
  else echo "- ⚠ REMOTE YOK — kayip riski"; fi
  echo
fi

echo "⚠ Bu oturumun devir dosyasi HENUZ YAZILMADI."
echo "   Bitmeden ${DEVIR_DIZINI}/$(date +%Y-%m-%d)-<konu>.md yazilacak."
echo
echo "=== Kurallar: CLAUDE.md + ${KURALLAR_DOSYASI} gecerlidir ==="
} > /tmp/.ds_$$ 2>/dev/null

python3 -c '
import json,sys
print(json.dumps({"hookSpecificOutput":{"hookEventName":"SessionStart",
      "additionalContext":open(sys.argv[1],encoding="utf-8").read()}},ensure_ascii=False))
' /tmp/.ds_$$
rm -f /tmp/.ds_$$
exit 0

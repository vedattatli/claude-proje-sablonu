#!/usr/bin/env bash
# PostCompact hook — baglam sikistirildiktan SONRA calisir.
#
# Cozdugu problem (CLAUDE.md'nin kendi tespiti):
#   "Sikistirma ozeti kurallari 'bilgi'ye cevirir — bilinen mimari davranis."
# Sikistirmadan sonra kurallar kural olmaktan cikip "gecmiste soyle denmisti"
# bilgisine donusuyor. Bu hook onlari KURAL olarak geri enjekte eder.

set -uo pipefail
P="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
cd "$P" 2>/dev/null || exit 0
KURALLAR_DOSYASI="01_KIRMIZI_CIZGILER.md"; DEVIR_DIZINI="05_OTURUM_DEVIR"
[ -f .claude/proje.conf ] && . .claude/proje.conf

{
echo "=== SIKISTIRMA SONRASI KURAL YENIDEN YUKLEME (PostCompact hook) ==="
echo
echo "Baglam sikistirildi. Ozet kurallari zayiflatir. Asagidakiler HALA GECERLI"
echo "ve baglayicidir — 'gecmiste boyle denmisti' bilgisi degil, YURURLUKTEKI kural:"
echo
if [ -f ${KURALLAR_DOSYASI} ]; then
  grep '^| [0-9]' ${KURALLAR_DOSYASI} 2>/dev/null | head -12
  echo
fi
echo "## Degismez calisma kurallari"
if [ -f CLAUDE.md ]; then
  sed -n '/^## Degismez kurallar/,/^## Oturum sonunda/p' CLAUDE.md 2>/dev/null | grep '^- ' | head -12
fi
echo
echo "⚠ Ilk is: CLAUDE.md ve ${KURALLAR_DOSYASI} dosyalarini YENIDEN OKU."
if [ -f ${DEVIR_DIZINI}/.sikistirma-anlik-goruntu.md ]; then
  echo "⚠ Sikistirma oncesi durum: ${DEVIR_DIZINI}/.sikistirma-anlik-goruntu.md"
fi
} > /tmp/.pc_$$ 2>/dev/null

python3 -c '
import json,sys
print(json.dumps({"hookSpecificOutput":{"hookEventName":"PostCompact",
      "additionalContext":open(sys.argv[1],encoding="utf-8").read()}},ensure_ascii=False))
' /tmp/.pc_$$
rm -f /tmp/.pc_$$
exit 0

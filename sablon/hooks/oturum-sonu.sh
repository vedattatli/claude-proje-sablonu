#!/usr/bin/env bash
# Stop — her turun sonunda: (1) otomatik commit+push, (2) devir dosyasi zorlamasi.
#
# ⚠ Stop HER TURUN sonunda tetiklenir. Bu yuzden engelleme oturumda EN FAZLA
#   BIR KEZ olur ve ancak DEVIR_ESIGI kadar commit birikince devreye girer.
#   Kacis valfi: bir kez engelledikten sonra bir daha asla engellemez.
set -uo pipefail
P="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
cd "$P" 2>/dev/null || exit 0
[ -d .git ] || exit 0

DEVIR_DIZINI="05_OTURUM_DEVIR"; KARAR_DOSYASI="03_KARAR_GUNLUGU.md"
SORULAR_DOSYASI="02_ACIK_SORULAR.md"; DEVIR_ESIGI=3; OTO_COMMIT=1; OTO_PUSH=1
[ -f .claude/proje.conf ] && . .claude/proje.conf
DEVIR_ESIGI="${DEVIR_ESIGI_OVERRIDE:-$DEVIR_ESIGI}"

girdi="$(cat 2>/dev/null || true)"
oturum="$(printf '%s' "$girdi" | python3 -c 'import sys,json
try: print(json.load(sys.stdin).get("session_id","bilinmiyor"))
except Exception: print("bilinmiyor")' 2>/dev/null || echo bilinmiyor)"
damga="/tmp/claude-oturum-${oturum}.damga"; blok="/tmp/claude-devir-blok-${oturum}"
mesaj=""

json_cikti() { python3 -c 'import json,sys;print(json.dumps(json.loads(sys.argv[1]),ensure_ascii=False))' "$1"; }

# ---- 1) OTOMATIK COMMIT + PUSH -------------------------------------------
if [ "${OTO_COMMIT}" = "1" ] && [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  riskli="$(git status --porcelain 2>/dev/null | awk '{print $NF}' \
    | grep -E '\.env$|\.env\.|\.pem$|\.key$|id_rsa|id_ed25519|credentials|secrets?\.(json|ya?ml)' || true)"
  if [ -n "${riskli}" ]; then
    python3 -c 'import json,sys;print(json.dumps({"systemMessage":"⛔ Otomatik commit DURDURULDU — riskli dosya: "+sys.argv[1]},ensure_ascii=False))' \
      "$(printf '%s' "${riskli}" | tr '\n' ' ')"
    exit 0
  fi
  git add -A >/dev/null 2>&1
  git commit -q -m "oto: calisma kaydi $(date '+%Y-%m-%d %H:%M')" \
    -m "Stop hook tarafindan otomatik olusturuldu." >/dev/null 2>&1 && mesaj="✔ otomatik commit"
  # --- PUSH + BASARISIZLIK IZI ---------------------------------------------
  # 02.08.2026 denetimi: bu hook'un systemMessage kanali modele ULASMIYOR.
  # "(push BASARISIZ)" yazilsa da kimse gormuyor; calisma sessizce yalnizca
  # yerel diskte kaliyor — hook'un onlemek icin var oldugu senaryonun ta kendisi.
  # Cozum: arizayi DISKE yaz, SessionStart en ustte bassin.
  isaret="${P}/.claude/.push-basarisiz"
  if [ "${OTO_PUSH}" = "1" ] && git remote get-url origin >/dev/null 2>&1; then
    if git push -q >/dev/null 2>&1; then
      mesaj="${mesaj} + push"
      rm -f "${isaret}" 2>/dev/null || true
    else
      mesaj="${mesaj} (push BASARISIZ)"
      mkdir -p "${P}/.claude" 2>/dev/null || true
      {
        echo "Zaman : $(date '+%Y-%m-%d %H:%M')"
        echo "Dal   : $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
        echo "Uzak  : $(git remote get-url origin 2>/dev/null || echo '?')"
        if git rev-parse '@{u}' >/dev/null 2>&1; then
          echo "Push'lanmamis commit: $(git log '@{u}..HEAD' --oneline 2>/dev/null | wc -l)"
        else
          # Upstream hic kurulmamis olabilir; "0" yazmak yaniltici olurdu.
          echo "Push'lanmamis commit: BILINMIYOR (upstream ayarli degil)"
          echo "Yerel commit sayisi : $(git log --oneline 2>/dev/null | wc -l)"
        fi
      } > "${isaret}" 2>/dev/null || true
    fi
  fi
fi

# ---- 2) DEVIR DOSYASI KONTROLU -------------------------------------------
if [ -f "${blok}" ]; then
  [ -n "${mesaj}" ] && python3 -c 'import json,sys;print(json.dumps({"systemMessage":sys.argv[1]},ensure_ascii=False))' "${mesaj}"
  exit 0
fi

if [ -f "${damga}" ]; then
  # ⚠ Sayim "oto:" commit'lerini HARIC tutar. Aksi halde hook kendi urettigi
  #   commit'leri sayar ve kendi bloklama sartini kendisi imal eder — dosyaya
  #   dokunan 3 tur, isin agirligindan bagimsiz olarak esigi doldurur.
  #   (02.08.2026 denetim bulgusu.)
  adet="$(git log --oneline --since="$(date -r "${damga}" '+%Y-%m-%d %H:%M:%S')" 2>/dev/null \
          | grep -cv 'oto: calisma kaydi' || true)"
  [ -z "${adet}" ] && adet=0
  yeni="$(find "${DEVIR_DIZINI}" -name '*.md' -newer "${damga}" 2>/dev/null | head -1)"
  if [ "${adet}" -ge "${DEVIR_ESIGI}" ] && [ -z "${yeni}" ]; then
    : > "${blok}"
    gerekce="Bu oturumda ${adet} commit atildi ama devir dosyasi yazilmadi.

Bitirmeden once ${DEVIR_DIZINI}/$(date +%Y-%m-%d)-<konu>.md yaz. Dort baslik:
  ne yapildi / ne bulundu / ne acik kaldi / siradaki adim

Karar alindiysa ${KARAR_DOSYASI}'ye ekle.
Cevaplanan soru varsa ${SORULAR_DOSYASI}'den dus.

(Bu uyari oturumda yalnizca BIR KEZ cikar — is akisini kilitlemez.)"
    python3 -c 'import json,sys;print(json.dumps({"decision":"block","reason":sys.argv[1]},ensure_ascii=False))' "${gerekce}"
    exit 0
  fi
fi

[ -n "${mesaj}" ] && python3 -c 'import json,sys;print(json.dumps({"systemMessage":sys.argv[1]},ensure_ascii=False))' "${mesaj}"
exit 0

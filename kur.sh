#!/usr/bin/env bash
# Claude proje hafiza sistemini bir projeye kurar.
#
# Kullanim:
#   ~/projects/claude-proje-sablonu/kur.sh                 # bulundugun klasore
#   ~/projects/claude-proje-sablonu/kur.sh ~/projects/yeni # belirtilen klasore
#   ~/projects/claude-proje-sablonu/kur.sh --belgeler ...  # belge klasorlerini de olustur

set -euo pipefail
KAYNAK="$(cd "$(dirname "$0")" && pwd)/sablon"
BELGELER=0
HEDEF=""
for a in "$@"; do
  case "$a" in
    --belgeler) BELGELER=1 ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) HEDEF="$a" ;;
  esac
done
HEDEF="${HEDEF:-$(pwd)}"
HEDEF="$(cd "${HEDEF}" && pwd)"

echo "Kurulum hedefi: ${HEDEF}"
echo

# --- 1) .claude/ ------------------------------------------------------------
mkdir -p "${HEDEF}/.claude/hooks"

if [ -f "${HEDEF}/.claude/settings.json" ]; then
  echo "⚠ .claude/settings.json ZATEN VAR — uzerine yazilmadi."
  echo "  Yeni surum: ${HEDEF}/.claude/settings.json.yeni  (elle birlestir)"
  cp "${KAYNAK}/settings.json" "${HEDEF}/.claude/settings.json.yeni"
else
  cp "${KAYNAK}/settings.json" "${HEDEF}/.claude/settings.json"
  echo "✔ .claude/settings.json"
fi

[ -f "${HEDEF}/.claude/proje.conf" ] || { cp "${KAYNAK}/proje.conf" "${HEDEF}/.claude/proje.conf"; echo "✔ .claude/proje.conf"; }

for h in "${KAYNAK}"/hooks/*.sh; do
  ad="$(basename "$h")"
  if [ -f "${HEDEF}/.claude/hooks/${ad}" ]; then
    echo "  - ${ad} zaten var, atlandi"
  else
    cp "$h" "${HEDEF}/.claude/hooks/${ad}"; chmod +x "${HEDEF}/.claude/hooks/${ad}"
    echo "✔ .claude/hooks/${ad}"
  fi
done

# --- 2) CLAUDE.md -----------------------------------------------------------
if [ -f "${HEDEF}/CLAUDE.md" ]; then
  echo "  - CLAUDE.md zaten var, atlandi"
else
  cp "${KAYNAK}/CLAUDE.md" "${HEDEF}/CLAUDE.md"
  echo "✔ CLAUDE.md (iskelet — projene gore duzenle)"
fi

# --- 3) Belge klasorleri (opsiyonel) ---------------------------------------
if [ "${BELGELER}" = "1" ]; then
  for d in 00_DEVIR 04_CALISMA 05_OTURUM_DEVIR 06_TALIMATLAR 07_HAFIZA; do
    mkdir -p "${HEDEF}/${d}"; : > "${HEDEF}/${d}/.gitkeep"
  done
  for f in 01_KIRMIZI_CIZGILER.md 02_ACIK_SORULAR.md 03_KARAR_GUNLUGU.md; do
    [ -f "${HEDEF}/${f}" ] || echo "# ${f%.md}" > "${HEDEF}/${f}"
  done
  echo "✔ Belge klasorleri olusturuldu"
fi

# --- 4) .gitignore ----------------------------------------------------------
if [ ! -f "${HEDEF}/.gitignore" ]; then
  cat > "${HEDEF}/.gitignore" <<'EOF'
.env
.env.*
!.env.example
*.pem
*.key
*.p12
*.pfx
id_rsa
id_ed25519
credentials
secrets.json
secrets.yaml
.DS_Store
Thumbs.db
EOF
  echo "✔ .gitignore"
fi

# --- 5) git -----------------------------------------------------------------
if [ ! -d "${HEDEF}/.git" ]; then
  git -C "${HEDEF}" init -q -b main
  echo "✔ git deposu baslatildi (main)"
else
  echo "  - git deposu zaten var"
fi

# --- 6) HAFIZA symlink ------------------------------------------------------
slug="$(printf '%s' "${HEDEF}" | sed 's|/|-|g')"
hafiza_kok="${HOME}/.claude/projects/${slug}"
if [ -d "${HEDEF}/07_HAFIZA" ]; then
  mkdir -p "${hafiza_kok}"
  ln -sfn "${HEDEF}/07_HAFIZA" "${hafiza_kok}/memory"
  echo "✔ Hafiza symlink: ${hafiza_kok}/memory -> 07_HAFIZA"
  echo "  (Claude'un otomatik hafizasi artik repoya yaziyor)"
fi

# --- 7) Dogrulama -----------------------------------------------------------
echo
echo "=== DOGRULAMA ==="
python3 - "${HEDEF}" <<'PY'
import json,os,sys
h=sys.argv[1]
try: d=json.load(open(os.path.join(h,'.claude/settings.json')))
except Exception as e: print("  ✗ settings.json:",e); sys.exit(1)
for ev,g in d.get('hooks',{}).items():
    for grup in g:
        for x in grup.get('hooks',[]):
            yol=x.get('command','').replace('$CLAUDE_PROJECT_DIR',h)
            var=os.path.isfile(yol); ex=os.access(yol,os.X_OK)
            print(f"  {'✓' if var and ex else '✗'} {ev}: {os.path.basename(yol)}")
PY
[ -x "${HEDEF}/.claude/hooks/test-pii-guard.sh" ] && \
  ( cd "${HEDEF}" && bash .claude/hooks/test-pii-guard.sh 2>&1 | tail -1 | sed 's/^/  PII: /' )

cat <<EOF

=== KURULDU ===

Siradaki adimlar:
  1. CLAUDE.md'yi projene gore duzenle
  2. .claude/proje.conf icindeki klasor adlarini kontrol et
  3. Ilk commit:  cd "${HEDEF}" && git add -A && git commit -m "ilk commit"
  4. GitHub:      gh repo create <ad> --private --source=. --remote=origin --push
  5. Claude'u BU KLASORDEN ac:  cd "${HEDEF}" && claude

⚠ Hook'lar yeni oturumda devreye girer. Acik oturum varsa yeniden baslat.
EOF

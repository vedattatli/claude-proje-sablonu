#!/usr/bin/env bash
# pii-guard.sh dogrulama testi.
#
# Uc grubu ayri ayri olcer:
#   1) YOL/AD      -> exit 0 gecer, exit 2 bloke
#   2) BASH        -> yazan komut bloke, okuyan komut gecer
#   3) ICERIK      -> exit 0 (asla bloke etmez) + uyari cikti VAR mi YOK mu
#
# 02.08.2026 denetiminden sonra eklendi: onceki test yalniz 1. grubu olcuyordu,
# bu yuzden Bash ve icerik delikleri testten gecerken acikti.

H="$(cd "$(dirname "$0")" && pwd)/pii-guard.sh"
fail=0
GECICI="$(mktemp -d)"
trap 'rm -rf "${GECICI}"' EXIT

# tool_name + anahtar/deger ciftlerinden gecerli JSON uretir
pl() {
  python3 -c 'import json,sys
print(json.dumps({"tool_name": sys.argv[1],
                  "tool_input": dict(zip(sys.argv[2::2], sys.argv[3::2]))}))' "$@"
}

# --- 1 + 2: cikis kodu testi ------------------------------------------------
kod() {  # $1=aciklama $2=beklenen $3=arac  $4.. = anahtar deger ...
  local desc="$1" want="$2"; shift 2
  local out; out="$(pl "$@")"
  printf '%s' "${out}" | CLAUDE_PROJECT_DIR="${GECICI}" "$H" >/dev/null 2>&1
  local got=$?
  local gosterim="${4:-${3:-}}"
  if [ "${got}" = "${want}" ]; then
    printf 'GECTI  [bekl=%s]  %-34s %s\n' "${want}" "${desc}" "${gosterim}"
  else
    printf 'KALDI  [bekl=%s aldi=%s]  %-28s %s\n' "${want}" "${got}" "${desc}" "${gosterim}"
    fail=1
  fi
}

# --- 3: icerik uyarisi testi ------------------------------------------------
uyari() {  # $1=aciklama $2=VAR|YOK $3=icerik
  local desc="$1" want="$2" icerik="$3"
  local out kodu
  out="$(pl Write file_path "${GECICI}/notlar.md" content "${icerik}" \
         | CLAUDE_PROJECT_DIR="${GECICI}" "$H" 2>/dev/null)"
  kodu=$?
  local got="YOK"; [ -n "${out}" ] && got="VAR"
  if [ "${kodu}" != "0" ]; then
    printf 'KALDI  icerik ASLA bloke etmemeli ama exit=%s  %s\n' "${kodu}" "${desc}"
    fail=1
  elif [ "${got}" = "${want}" ]; then
    printf 'GECTI  [uyari=%s]  %s\n' "${want}" "${desc}"
  else
    printf 'KALDI  [uyari bekl=%s aldi=%s]  %s\n' "${want}" "${got}" "${desc}"
    fail=1
  fi
}

echo "═══ 1 · YOL/AD — gecmesi gerekenler (exit 0) ═══"
kod "normal markdown"   0 Write file_path "/proje/notlar.md"
kod "kural yaml"        0 Write file_path "/proje/rules/de.yaml"
kod "env sablonu"       0 Write file_path "/proje/.env.example"

echo
echo "═══ 1 · YOL/AD — bloke edilmesi gerekenler (exit 2) ═══"
kod "gercek PII fixture" 2 Write file_path "/proje/fixtures.json"
kod "real-docs klasoru"  2 Write file_path "/tmp/ml-data/real-docs/results.json"
kod "gercek .env"        2 Write file_path "/proje/.env"
kod "ozel anahtar"       2 Write file_path "/proje/id_ed25519"
kod "pem anahtar"        2 Write file_path "/proje/sunucu.pem"
kod "Edit araci da"      2 Edit  file_path "/proje/.env"

echo
echo "═══ 2 · BASH — bloke edilmesi gerekenler (exit 2) ═══"
kod "touch .env"        2 Bash command 'touch .env'
kod "cp -> real-docs/"  2 Bash command 'cp foto.jpg real-docs/'
kod "yonlendirme > .env" 2 Bash command 'echo SECRET=1 > .env'
kod "ekleme >> alt/.env" 2 Bash command 'cat a.txt >> config/.env'
kod "cp anahtar"        2 Bash command 'cp sunucu.pem /yedek/'
kod "curl -o pem"       2 Bash command 'curl https://x.test -o sunucu.pem'
kod "mv fixtures"       2 Bash command 'mv /tmp/fixtures.json .'

echo
echo "═══ 2 · BASH — gecmesi gerekenler (exit 0, okuma/arama mesru) ═══"
kod "grep ile arama"    0 Bash command 'grep -rn "real-docs" .'
kod "ls ile bakma"      0 Bash command 'ls -la .env'
kod "commit mesaji"     0 Bash command 'git commit -m "fix: .env handling"'
kod "git status"        0 Bash command 'git status --short'
kod "silme (cizgi 8 degil)" 0 Bash command 'rm -f .env'
# 02.08.2026'da yasanan yanlis pozitif: 2>&1 dosyaya yazma sanilmisti
kod "stderr birlestirme" 0 Bash command 'ls -la .env 2>&1 | head -1'
kod "stderr yutma"       0 Bash command 'cat .env 2>/dev/null'
kod "gercek yonlendirme yine bloke" 2 Bash command 'echo x 2>/dev/null > .env'

echo
echo "═══ 3 · ICERIK — asla bloke etmez, yalniz uyarir ═══"
uyari "gercekci TCKN benzeri"   VAR 'Basvuran no: 45678912345 kayitli.'
uyari "gercekci pasaport no"    VAR 'Pasaport U87654321 ile giris yapti.'
uyari "MRZ satiri"              VAR 'P<TURTESTOGLU<<AHMET<<<<<<<<<<<<<'
uyari "placeholder 11111111111" YOK 'Ornek TCKN: 11111111111 (uydurma).'
uyari "placeholder A12345678"   YOK 'Ornek pasaport: A12345678 (uydurma).'
uyari "duz markdown"            YOK '# Baslik

Normal metin, 2026-08-02 tarihli, sayfa 12.'

echo
if [ "${fail}" = 0 ]; then
  echo "SONUC: TUM TESTLER GECTI"
else
  echo "SONUC: BASARISIZ TEST VAR"
fi
exit "${fail}"

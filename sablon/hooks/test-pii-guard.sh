#!/usr/bin/env bash
# pii-guard.sh dogrulama testi. Beklenen: 0 = gecer, 2 = bloke.
H="$(dirname "$0")/pii-guard.sh"
fail=0

check() {
  local desc="$1" path="$2" want="$3"
  printf '{"tool_input":{"file_path":"%s"}}' "$path" | "$H" >/dev/null 2>&1
  local got=$?
  if [ "$got" = "$want" ]; then
    printf 'GECTI  [bekl=%s]  %-46s %s\n' "$want" "$desc" "$path"
  else
    printf 'KALDI  [bekl=%s aldi=%s]  %-40s %s\n' "$want" "$got" "$desc" "$path"
    fail=1
  fi
}

echo "=== GECMESI GEREKENLER (exit 0) ==="
check "normal markdown"      "/home/vedat/projects/paxdoc-v2/notlar.md"        0
check "kural yaml"           "/home/vedat/projects/paxdoc-v2/rules/de.yaml"    0
check "env sablonu"          "/home/vedat/projects/paxdoc-v2/.env.example"     0

echo
echo "=== BLOKE EDILMESI GEREKENLER (exit 2) ==="
check "gercek PII fixture"   "/home/vedat/projects/paxdoc-v2/fixtures.json"    2
check "real-docs klasoru"    "/tmp/ml-data/real-docs/results.json"             2
check "gercek .env"          "/home/vedat/projects/paxdoc-v2/.env"             2
check "ozel anahtar"         "/home/vedat/projects/paxdoc-v2/id_ed25519"       2
check "pem anahtar"          "/home/vedat/projects/paxdoc-v2/sunucu.pem"       2

echo
if [ "$fail" = 0 ]; then echo "SONUC: TUM TESTLER GECTI"; else echo "SONUC: BASARISIZ TEST VAR"; fi
exit $fail

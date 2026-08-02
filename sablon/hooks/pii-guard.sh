#!/usr/bin/env bash
# PaxDoc v2 - PII koruma hook'u (PreToolUse)
#
# Kirmizi cizgi 8: "PII repoya girmez."
# Bu dosya o kurali MODELIN HATIRLAMASINA birakmaz. Arac cagrisini
# calismadan once yakalar ve exit 2 ile BLOKE eder.
#
# Neden gerekli: CLAUDE.md ve hafiza dosyalari config olarak degil
# kullanici mesaji olarak yuklenir; uzun oturumda ve baglam sikistirmasi
# sonrasi kural olmaktan cikip bilgiye donusur.

set -uo pipefail

payload="$(cat)"

if command -v jq >/dev/null 2>&1; then
  path="$(printf '%s' "$payload" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')"
else
  path="$(printf '%s' "$payload" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
fi

[ -z "${path}" ] && exit 0

base="$(basename "${path}")"

deny() {
  {
    echo "PII-GUARD ENGELLEDI: $1"
    echo "Yol : ${path}"
    echo "Kural: kirmizi cizgi 8 - PII repoya girmez (01_KIRMIZI_CIZGILER.md)"
    echo "Bu bir hook engellemesidir; yeniden denemek ise yaramaz."
    echo "Gercekten gerekiyorsa once operatore sor."
  } >&2
  exit 2
}

# 1) Gercek belge verisi tasiyan yollar
case "${path}" in
  *real-docs/*|*real_docs/*) deny "gercek belge verisi klasoru (real-docs)" ;;
esac

# 2) Ad bazli engeller
case "${base}" in
  fixtures.json)
    deny "gercek PII fixture dosyasi (19 gercek belgeden cikarilmis)" ;;
  .env.example|.env.sample|.env.template|env.example)
    : ;;                                   # sablonlar serbest
  .env|.env.*|*.env)
    deny "gizli yapilandirma dosyasi (.env)" ;;
  id_rsa|id_ed25519|*.pem|*.p12|*.pfx|*.key)
    deny "ozel anahtar dosyasi" ;;
esac

exit 0

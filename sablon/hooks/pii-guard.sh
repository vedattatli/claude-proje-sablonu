#!/usr/bin/env bash
# PII koruma hook'u (PreToolUse) — kirmizi cizgi 8: "PII repoya girmez."
#
# Bu dosya o kurali MODELIN HATIRLAMASINA birakmaz; arac cagrisini
# calismadan once yakalar.
#
# IKI KATMAN:
#   1) YOL/AD ENGELLEME -> exit 2, arac hic calismaz.
#      Kapsam: Write | Edit | NotebookEdit | Bash
#   2) ICERIK UYARISI   -> exit 0, arac CALISIR ama iz birakilir.
#      Kapsam: Write | Edit | NotebookEdit  (yazilan metin)
#
# ── 02.08.2026 denetimi iki delik buldu; ikisi de burada kapatildi ──
#   Delik 1: Bash kapsanmiyordu. `touch .env` ve `cp foto.jpg real-docs/`
#            hic engellenmeden geciyordu — matcher yalniz Write|Edit|NotebookEdit'ti.
#   Delik 2: Icerige hic bakilmiyordu. Sadece dosya ADI kontrol ediliyordu,
#            yani `notlar.md` icine 19 kisinin pasaport numarasi yazilabilirdi.
#
# ── NEDEN icerik ENGELLEMIYOR, UYARIYOR ──
#   Kural ve fizibilite metinleri ornek numara tasir (ornek pasaport no,
#   ornek TCKN, MRZ ornegi). Engelleyici olsaydi belge yazimi surekli
#   kilitlenirdi ve hook devre disi birakilirdi — koruma sifira inerdi.
#   Bu yuzden: yazmaya izin verir, kaydeder, SessionStart'ta operatore bildirir.
#   Karar operatorun.

set -uo pipefail

PAYLOAD="$(cat)"
export PAYLOAD
PROJE_DIZINI="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." 2>/dev/null && pwd || echo .)}"
export PROJE_DIZINI

python3 - <<'PY'
import json, os, re, sys, datetime

payload = os.environ.get("PAYLOAD", "")
proje   = os.environ.get("PROJE_DIZINI", "") or "."

try:
    d = json.loads(payload)
except Exception:
    sys.exit(0)                      # anlasilamayan girdi engellenmez

arac = d.get("tool_name") or ""
ti   = d.get("tool_input") or {}

# ─────────────────────────── 1. KATMAN: yol / ad ───────────────────────────

IZINLI = {".env.example", ".env.sample", ".env.template", "env.example"}

def yol_tehlikesi(yol):
    """Tehlikeliyse sebep metni doner, degilse None."""
    if not yol or not isinstance(yol, str):
        return None
    y = yol.replace("\\", "/")
    if re.search(r'(^|/)real[-_]docs(/|$)', y):
        return "gercek belge verisi klasoru (real-docs)"
    ad = y.rsplit("/", 1)[-1]
    if ad in IZINLI:
        return None
    if ad == "fixtures.json":
        return "gercek PII fixture dosyasi (19 gercek belgeden cikarilmis)"
    if ad == ".env" or ad.startswith(".env.") or ad.endswith(".env"):
        return "gizli yapilandirma dosyasi (.env)"
    if ad in ("id_rsa", "id_ed25519", "id_ecdsa", "id_dsa"):
        return "ozel anahtar dosyasi"
    if re.search(r'\.(pem|p12|pfx|key)$', ad, re.I):
        return "ozel anahtar dosyasi"
    return None

# Bash: yalnizca YAZAN komutlar engellenir.
# `grep -rn "real-docs" .` veya `ls .env` mesru arama/bakma islemidir,
# kirmizi cizgi 8'i ihlal etmez — engellenirse hook gereksiz yere dayatir.
YAZMA_FIILI  = re.compile(r'(^|[;&|(]\s*|\s)(touch|cp|mv|tee|dd|install|ln|rsync|truncate)\b')
# `> dosya` dosyaya yazar; `2>&1` / `>&2` yalnizca betimleyici kopyalar.
# Ikisi ayrilmazsa her `2>&1` tasiyan komut yazma sanilir — 02.08.2026'da
# tam bu yanlis pozitif yasandi (`ls .env 2>&1` engellendi).
YONLENDIRME  = re.compile(r'>>?\s*[^&\s]')
SED_YERINDE  = re.compile(r'\bsed\b[^|;]*\s-i\b')
INDIRME      = re.compile(r'\b(curl|wget)\b[^|;]*\s(-o|-O|--output|--output-document)\b')

# ⚠ BILINEN SINIR: bu bir kabuk ayristiricisi degil, desen taramasidir.
#    Tirnak icindeki metin ile gercek sozdizimi ayirt edilemez. Yani
#    `git commit -m "cikti icin yonlendirme kullan"` gibi bir komutta
#    yonlendirme deseni gecerse yanlis pozitif olur. Kabul edilen bedel:
#    yanlis pozitif rahatsiz eder ama veri sizdirmaz; ters yon sizdirir.
#    Boyle bir durumda komutu yeniden ifade et ya da mesaji dosyadan ver
#    (`git commit -F dosya`).
YONLENDIRME_HEDEFI = re.compile(r'>>?\s*([^\s&;|<>()]+)')

def bash_tehlikesi(komut):
    if not komut or not isinstance(komut, str):
        return None

    # 1) Yonlendirmede yazilan sey yalnizca HEDEF'tir.
    #    `cat .env 2>/dev/null` .env'i OKUR, /dev/null'a yazar — engellenmemeli.
    #    Komuttaki her yolu suclamak 02.08.2026'da yanlis pozitif uretti.
    for m in YONLENDIRME_HEDEFI.finditer(komut):
        hedef = m.group(1).strip('"\'')
        sebep = yol_tehlikesi(hedef)
        if sebep:
            return "%s  [Bash yonlendirmesi: > %s]" % (sebep, hedef)

    # 2) Yazan fiillerde hangi argumanin kaynak hangisinin hedef oldugu
    #    guvenilir ayrilamaz (`cp gizli.pem /yedek/` kaynagi da tehlikeli),
    #    bu yuzden tum parcalar kontrol edilir.
    if (YAZMA_FIILI.search(komut) or SED_YERINDE.search(komut)
            or INDIRME.search(komut)):
        for parca in re.split(r'''[\s;&|<>()"']+''', komut):
            sebep = yol_tehlikesi(parca.strip())
            if sebep:
                return "%s  [Bash yoluyla: %s]" % (sebep, parca.strip())
    return None

hedef = ti.get("file_path") or ti.get("notebook_path") or ""
sebep = yol_tehlikesi(hedef)
if not sebep and arac == "Bash":
    sebep = bash_tehlikesi(ti.get("command") or "")

if sebep:
    sys.stderr.write(
        "PII-GUARD ENGELLEDI: %s\n"
        "Arac : %s\n"
        "Hedef: %s\n"
        "Kural: kirmizi cizgi 8 - PII repoya girmez (01_KIRMIZI_CIZGILER.md)\n"
        "Bu bir hook engellemesidir; yeniden denemek iste yaramaz.\n"
        "Gercekten gerekiyorsa once operatore sor.\n"
        % (sebep, arac or "?", hedef or (ti.get("command") or "?"))
    )
    sys.exit(2)

# ────────────────────── 2. KATMAN: icerik uyarisi (engellemez) ──────────────

def bariz_sahte(s):
    """Ornek/placeholder numaralari eleyip yanlis pozitifi azaltir."""
    rakam = re.sub(r'\D', '', s)
    if not rakam:
        return False
    if len(set(rakam)) <= 1:                      # 11111111111, 00000000
        return True
    if "000000" in rakam or "123456" in rakam:    # X00000000, A1234567
        return True
    return False

KALIPLAR = (
    ("TCKN benzeri 11 haneli numara", r'\b[1-9][0-9]{10}\b'),
    ("pasaport numarasi benzeri",     r'\b[A-Z][0-9]{7,8}\b'),
    ("MRZ satiri",                    r'P<[A-Z]{3}[A-Z<]{5,}'),
    ("IBAN (TR)",                     r'\bTR[0-9]{24}\b'),
)

metin = "\n".join(str(ti.get(k) or "") for k in
                  ("content", "new_string", "new_source"))

bulgular = []
for etiket, kalip in KALIPLAR:
    for m in re.finditer(kalip, metin):
        if not bariz_sahte(m.group(0)):
            bulgular.append((etiket, m.group(0)))

def maskele(s):
    """Kayda ACIK deger yazilmaz.

    Uyari kaydi diskte kalicidir ve repo dizinindedir. Eslesen deger GERCEK
    PII ise, onu duz yazmak kirmizi cizgi 8'i tam da korumasi gereken dosyada
    ihlal ederdi. Bicim gorunur kalsin diye ilk iki karakter birakilir.
    Acik deger yalnizca ekrana (stderr) gider — ucucudur, diske dusmez.
    """
    return s[:2] + "*" * max(0, len(s) - 2)

if bulgular:
    bulgular = bulgular[:10]
    an = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
    ozet      = "; ".join("%s -> %s" % (e, d) for e, d in bulgular)
    ozet_kayit = "; ".join("%s -> %s" % (e, maskele(d)) for e, d in bulgular)

    kayit_dizini = os.path.join(proje, ".claude")
    try:
        os.makedirs(kayit_dizini, exist_ok=True)
        with open(os.path.join(kayit_dizini, "pii-uyari.log"), "a",
                  encoding="utf-8") as f:
            f.write("%s\t%s\t%s\t%s\n" % (an, arac, hedef or "?", ozet_kayit))
    except Exception:
        pass

    uyari = ("PII-GUARD UYARI (engellenmedi): %s\nDosya: %s\n"
             "Ornek numara ise sorun yok. Gercek veriyse kirmizi cizgi 8 ihlali "
             "— dosyayi geri al ve operatore soyle." % (ozet, hedef or "?"))
    sys.stderr.write(uyari + "\n")
    print(json.dumps({"systemMessage": "⚠ " + uyari}, ensure_ascii=False))

sys.exit(0)
PY

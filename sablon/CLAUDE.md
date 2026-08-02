# <PROJE ADI> — Çalışma Protokolü

> Bu bir **iskelet**. `<...>` yerlerini doldur, gereksiz satırları sil.

## ⚠ Oturumu BU DİZİNDEN başlat

```bash
cd <proje yolu> && claude
```

Claude Code proje ayarlarını **çalışma dizinine göre** yükler. Başka dizinden
açılırsa bu dosya yüklenmez, hafıza gelmez ve **hook'lar devrede olmaz.**

## Her oturumun başında — sırayla oku

> `SessionStart` hook'u bunların özetini zaten otomatik yükler.
> Aşağıdakiler **derinlemesine** okunacaklar.

1. `01_KIRMIZI_CIZGILER.md`
2. `03_KARAR_GUNLUGU.md` — son 3 kayıt
3. `05_OTURUM_DEVIR/` — en son tarihli dosya
4. `07_HAFIZA/MEMORY.md`

## Değişmez kurallar

- **Önce haber ver, sonra yap.** Her işten önce *"şunu yapacağım"* de; operatör
  **"tamam"** deyince yap. İstisna: salt okuma ve doğrulama.
- **Aynı anda tek konu anlat.** Soru sorarken de tek soru sor.
- **Geri dönüşsüz iş operatörün.** Silme, ödeme, imza, hesap açma, e-posta
  gönderme → hazırla, sun, **uygulama.**
- **Kaynaksız iddia yok.** Her sayı URL + erişim tarihi taşır.
  Doğrulanmamışsa satırın sonuna `[DOĞRULANMADI]` yaz.
- **Abartılı iyimser rapor yok.** Ne çalışmıyor, ne eksik, ne doğrulanmadı —
  açıkça yaz. Test etmediğin şeye "çalışıyor" deme.
- **Her adımdan sonra dur ve raporla.**
- <projeye özgü kuralları buraya ekle>

## Oturum sonunda

`05_OTURUM_DEVIR/YYYY-AA-GG-<konu>.md` yaz. Dört başlık:
**ne yapıldı · ne bulundu · ne açık kaldı · sıradaki adım**

Karar alındıysa `03_KARAR_GUNLUGU.md`'ye ekle (ADR biçimi:
*karar · gerekçe · kim · tarih*). Cevap bulunduysa `02_ACIK_SORULAR.md`'den düş.

> `Stop` hook'u bunu unutursan **bir kez** hatırlatır ve engeller.

## Bağlam sıkışırsa (compaction)

Sıkıştırma özeti **kuralları "bilgi"ye çevirir** — bilinen mimari davranış.
`PostCompact` hook'u kırmızı çizgileri otomatik geri enjekte eder, ama ilk iş
yine de **bu dosyayı ve `01_KIRMIZI_CIZGILER.md`'yi yeniden okumaktır.**

---

Durum sohbette değil **dosyada** yaşar. Sohbette kalan her şey kaybolabilir.

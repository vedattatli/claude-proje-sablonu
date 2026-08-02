# Claude Proje Hafıza Sistemi

Claude Code oturumları arasında **proje durumunun kaybolmasını mekanik olarak
imkânsız hale getiren** hook sistemi + proje iskeleti.

> "Ben unutur giderim, onunla mı uğraşacağım projeyle mi?" — bu sistem tam olarak
> bunun cevabı. Sen hiçbir şey demezsin; hook'lar halleder.

## Kurulum

```bash
git clone https://github.com/vedattatli/claude-proje-sablonu ~/projects/claude-proje-sablonu
~/projects/claude-proje-sablonu/kur.sh --belgeler ~/projects/yeni-projen
```

Mevcut dosyaların **üzerine yazmaz.** Kurulum sonunda kendini doğrular.

## Ne yapıyor

| Hook | Ne zaman | Ne yapar |
|---|---|---|
| `SessionStart` | Oturum açılınca | Son devir, kararlar, bekleyen işler, git durumu → **bağlama otomatik enjekte** |
| `Stop` | Her turun sonunda | **Otomatik commit + push.** Devir dosyası yazılmadıysa oturumda bir kez engeller |
| `PreCompact` | Sıkıştırmadan önce | Durumu diske yazar |
| `PostCompact` | Sıkıştırmadan sonra | Kırmızı çizgileri **kural olarak** geri enjekte eder |
| `PreToolUse` | Her yazma öncesi | PII/sır dosyalarını bloke eder |

## Yapı

```
kur.sh              tek komutla kurar, kendini doğrular
KILAVUZ.md          ⭐ sistemin tamamı: neden, nasıl, sorun giderme
sablon/
├── CLAUDE.md       çalışma protokolü iskeleti
├── proje.conf      klasör adları, eşikler, aç/kapa
├── settings.json   hook bağlantıları
└── hooks/          beş hook betiği + PII testi
```

## Neden

`CLAUDE.md` config değil **kullanıcı mesajı** olarak yüklenir; uzun oturumda ve
bağlam sıkıştırması sonrasında kural olmaktan çıkıp bilgiye döner. Metne
güvenilmez — **hook'a güvenilir.**

Detaylı gerekçe, profesyonel kalıplar (ADR, CI kapıları, Conventional Commits)
ve tasarım kararları için → **[KILAVUZ.md](KILAVUZ.md)**

## Gereksinimler

`bash` · `git` · `python3` · (opsiyonel) `gh`

---

PaxDoc Navigator projesinde geliştirildi, orada çalışıyor. Dört senaryo test edildi.

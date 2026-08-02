# Claude Proje Hafıza Sistemi — Kılavuz

**Ne yapar:** Claude Code oturumları arasında proje durumunun kaybolmasını
**mekanik olarak** imkânsız hale getirir. Kimse "güncellemeyi unutmasın" demez;
sistem kendisi halleder.

**Kim için:** Claude Code ile uzun soluklu proje yürüten herkes.
Dile, çerçeveye, proje türüne bağımlı değil.

---

# 1 · Problem

Uzun bir oturum yaparsın. Kararlar alınır, işler biter, sorular cevaplanır.
Sonra oturum kapanır — ve **hepsi sohbetin içinde kalır.**

Ertesi gün yeni sohbet açarsın. Sıfır bilgi. Sen tekrar anlatırsın.

Üstüne üç ek problem:

| Problem | Neden olur |
|---|---|
| **Bağlam sıkıştırması kuralları eritir** | Uzun oturumda özet çıkarılır; kurallar kural olmaktan çıkıp *"geçmişte şöyle denmişti"* bilgisine döner |
| **Commit'lenmemiş iş buhar olur** | SSD ölür, uygulama yeniden kurulur, klasör silinir |
| **"Sen hatırla" çalışmaz** | Model bağlam dolduğunda unutur; insan zaten unutur |

## Neden metin yetmez

`CLAUDE.md` **config değil, kullanıcı mesajı olarak** yüklenir. Uzun oturumda ve
sıkıştırma sonrasında ağırlığını kaybeder. Model onu "kural" değil "bilgi" sanmaya
başlar.

**Bu bir kusur değil, mimari gerçek.** Çözüm modeli daha çok uyarmak değil —
**modele hiç bırakmamak.**

---

# 2 · Profesyoneller bunu nasıl çözüyor

Büyük şirketler *"unutmayalım"* demez. İnsan disiplinine hiç güvenmezler:

| Kalıp | Ne yapar | Nerede |
|---|---|---|
| **Durum kafada değil depoda** | Çalışan durumsuz, durum dosyada | Temel ilke, her yerde |
| **ADR** *(Architecture Decision Record)* | Her karar tarih + gerekçeyle ayrı kayda | AWS, Spotify, ThoughtWorks |
| **CI kapıları** | *"Changelog güncellenmediyse PR geçmez"* — hatırlatma değil **engel** | GitHub, Stripe, Google |
| **Conventional Commits** | Commit mesajından changelog otomatik üretilir | Angular, Vue, çoğu büyük OSS |

Ortak nokta: **kural metin değil, çalışan kod.**

Bu sistem aynı fikri Claude Code'a uygular. `03_KARAR_GUNLUGU.md` zaten ADR'dir;
eksik olan tek şey **zorlayıcı mekanizmaydı.**

---

# 3 · Sistem nasıl çalışıyor

Dört hook. Hepsi deterministik shell betiği — modelin hatırlamasına bağlı değil.

```
Oturum açılır
   └─► SessionStart ──► durumu bağlama ENJEKTE eder
                        (son devir, kararlar, bekleyen işler, git durumu)

   ...çalışma...

   Her turun sonunda
   └─► Stop ──► otomatik COMMIT + PUSH
              └─► devir dosyası yazılmadıysa BİR KEZ engeller

   Bağlam dolarsa
   ├─► PreCompact  ──► durumu diske yazar
   └─► PostCompact ──► kırmızı çizgileri KURAL olarak geri enjekte eder
```

## 3.1 · `SessionStart` → `oturum-basi.sh`

Oturum açılırken çalışır. `additionalContext` ile şunları **doğrudan bağlama** koyar:

- Son oturum devir dosyasının ilk 32 satırı
- Son 3 karar
- Operatörden bekleyen işler
- Açık soru sayısı
- Git durumu: son commit, commit'lenmemiş dosya sayısı, push'lanmamış commit, remote var mı

Ayrıca `/tmp/claude-oturum-<id>.damga` bırakır — `Stop` bunu kullanarak
*"devir dosyası **bu** oturumda mı yazıldı"* sorusunu doğru cevaplar.

> **Sonuç:** Yeni sohbet artık sıfırdan başlamıyor.

## 3.2 · `Stop` → `oturum-sonu.sh`

⚠ **`Stop` her turun sonunda tetiklenir** — oturum sonunda değil. Tasarım buna göre:

**a) Otomatik commit + push (her tur, sessiz)**
Çalışma hiçbir zaman bir turdan fazla commit'siz kalmaz.

⚠ **"SSD ölse en fazla bir turluk iş kaybolur" yalnızca push BAŞARILIYSA doğrudur.**
Commit yereldir; koruma push'tan gelir. Bu yüzden push başarısız olduğunda hook
`.claude/.push-basarisiz` dosyası bırakır ve `SessionStart` bunu en üstte basar.
Sebep: hook'un `systemMessage` kanalının modele **ulaşmadığı** ölçüldü (02.08.2026) —
yani ekrana yazmak yetmiyor, arıza **diske** yazılmalı.

Riskli dosya (`.env`, `*.pem`, `id_rsa`, `credentials`…) varsa **commit durdurulur**
ve uyarı basılır — ikinci savunma hattı.

**b) Devir dosyası zorlaması (oturumda EN FAZLA BİR KEZ)**
`DEVIR_ESIGI` (varsayılan 3) commit birikmiş **ve** bu oturumda devir dosyası
yazılmamışsa, `decision: "block"` döner ve Claude'a yazdırır.

⚠ Sayım **`oto:` commit'lerini hariç tutar.** Aksi halde hook kendi ürettiği
commit'leri sayar ve kendi bloklama şartını kendisi imal ederdi — dosyaya dokunan
3 tur, işin ağırlığından bağımsız olarak eşiği doldururdu. (02.08.2026 denetimi.)

> **Kaçış valfi:** bir kez engelledikten sonra o oturumda **bir daha asla**
> engellemez. İş akışı kilitlenemez.

## 3.3 · `PreCompact` → `sikistirma-oncesi.sh`

Sıkıştırmadan **önce** git geçmişi + commit'lenmemiş dosyaları
`<DEVIR_DIZINI>/.sikistirma-anlik-goruntu.md` dosyasına yazar.
Özet ne kadar kayıp verirse versin gerçek durum diskte durur.

## 3.4 · `PostCompact` → `sikistirma-sonrasi.sh`

Sıkıştırmadan **sonra** kırmızı çizgileri ve değişmez kuralları
`additionalContext` ile geri enjekte eder — *"geçmişte böyle denmişti"* değil,
**yürürlükteki kural** olarak.

Bu, yukarıdaki 1. bölümde anlatılan "kural erimesi" probleminin doğrudan panzehiri.

---

# 4 · Kurulum

```bash
git clone <bu-repo> ~/projects/claude-proje-sablonu
~/projects/claude-proje-sablonu/kur.sh --belgeler ~/projects/yeni-proje
```

`--belgeler` bayrağı belge iskeletini de kurar (`00_…07_`). Sadece hook'lar
isteniyorsa bayrağı kullanma.

Kurulum **hiçbir mevcut dosyanın üzerine yazmaz.** `settings.json` zaten varsa
`settings.json.yeni` olarak bırakır, elle birleştirirsin.

Kurulum sonunda otomatik doğrulama çalışır: her hook bağlı mı, dosya var mı,
çalıştırılabilir mi, PII testi geçiyor mu.

⚠ **Hook'lar yeni oturumda devreye girer.** Açık oturum varsa yeniden başlat.

---

# 5 · Özelleştirme — `.claude/proje.conf`

```bash
DEVIR_DIZINI="05_OTURUM_DEVIR"      # oturum devir klasörü
KARAR_DOSYASI="03_KARAR_GUNLUGU.md" # ADR
KURALLAR_DOSYASI="01_KIRMIZI_CIZGILER.md"
SORULAR_DOSYASI="02_ACIK_SORULAR.md"
RAPOR_DOSYASI="04_FIZIBILITE/00_FIZIBILITE_RAPORU.md"
DEVIR_ESIGI=3                        # kaç commit sonra devir istensin
OTO_COMMIT=1                         # 0 = kapat
OTO_PUSH=1                           # 0 = kapat
```

Dosya/klasör yoksa ilgili bölüm **sessizce atlanır** — hiçbir şey kırılmaz.
Boş bir projede de test edildi.

---

# 6 · Hafıza `07_HAFIZA/`

Claude Code'un **yerleşik otomatik hafızası** var; varsayılan yeri
`~/.claude/projects/<dizin-slug>/memory/`.

`kur.sh` oraya `07_HAFIZA/` klasörüne bir symlink kurar. Sonuç:

> Otomatik hafıza artık **doğrudan repoya yazıyor** — versiyonlu, yedekli,
> başka makineye taşınabilir.

Bu, hafızayı `~/.claude/` içinde bırakmanın en büyük riskini kapatır:
uygulama yeniden kurulunca `~/.claude/` sıfırlanır, repo sıfırlanmaz.

---

# 7 · Sorun giderme

| Belirti | Sebep / çözüm |
|---|---|
| Hook hiç çalışmıyor | Oturumu **proje klasöründen** açtın mı? `cd <proje> && claude` |
| Yeni kurdum, çalışmıyor | Hook'lar oturum başında yüklenir — yeniden başlat |
| Durum enjekte edilmiyor | `echo '{}' \| bash .claude/hooks/oturum-basi.sh` — JSON dönüyor mu? |
| Otomatik commit olmuyor | `.git` var mı? `OTO_COMMIT=1` mi? `git status` temiz olabilir |
| Push başarısız | Remote var mı, upstream ayarlı mı: `git push -u origin main` |
| Devir uyarısı hiç çıkmıyor | `DEVIR_ESIGI` kadar commit birikmemiş olabilir |
| Devir uyarısı sürekli çıkıyor | Çıkmaz — oturumda bir kez. Çıkıyorsa `/tmp/claude-devir-blok-*` yazılabilir mi? |

**Tek tek test:**
```bash
echo '{"session_id":"TEST"}' | bash .claude/hooks/oturum-basi.sh   | python3 -m json.tool
echo '{"session_id":"TEST"}' | bash .claude/hooks/oturum-sonu.sh   | python3 -m json.tool
bash .claude/hooks/test-pii-guard.sh
```

---

# 8 · Tasarım kararları ve sınırlar

**Neden `Stop` her turda engellemiyor?**
`Stop` her turun sonunda tetiklenir. Her turda engelleseydi ilk mesajdan itibaren
kilitlenirdin. Bu yüzden: eşik + oturumda tek engelleme + kaçış valfi.

**Neden `SessionEnd` değil?**
`SessionEnd` oturum bittikten sonra çalışır — o noktada Claude artık bir şey
yazamaz. Devir dosyası yazdırmak için `Stop` tek uygun yer.

**Neden her yazmada değil de tur sonunda commit?**
Her yazmada commit git geçmişini kullanılamaz hale getirir. Tur sonu doğru denge:
kayıp riski bir tur, geçmiş okunabilir kalıyor.

**Bilinen sınırlar:**
- `python3` gerekiyor (JSON üretimi için). `jq` gerekmiyor.
- Otomatik commit mesajları jenerik (`oto: calisma kaydi ...`). Anlamlı mesaj
  istiyorsan elle commit at; hook sadece kalanı toplar.
- Hook'lar sadece Claude Code oturumlarında çalışır — terminalden elle yapılan
  değişiklikleri yakalamaz.
- `decision: "block"` davranışı Claude Code sürümüne bağlı; sürüm değişiminde
  `Stop` hook'unu yeniden doğrula.

---

# 9 · Bu sistem neyi garanti eder, neyi etmez

✅ **Eder — canlı doğrulandı (02.08.2026, PaxDoc oturumu)**
- Yeni oturum durumu bilerek başlar *(SessionStart bloğu bağlama düştü)*
- Çalışma bir turdan fazla commit'siz kalmaz *(`oto:` commit'leri gözlendi)*
- Uzak depoya otomatik gider *(remote'a karşı doğrulandı; başarısızlık artık iz bırakır)*
- Devir dosyası unutulursa hatırlatılır *(⚠ bloklama yolu yalnız birim testinde görüldü)*
- Riskli dosya adları yazılmadan engellenir *(30 testlik paket + canlı deneme)*

⚠ **Henüz DOĞRULANMADI — betiği sağlam, tetiklendiği görülmedi**
- **Sıkıştırma sonrası kuralların geri gelmesi.** `PostCompact` bugüne kadar bir kez
  bile tetiklenirken gözlenmedi; koşul (bağlam sıkışması) hiç oluşmadı. Daha önce bu
  satır ✅ listesindeydi — **doğrulanmamış bir şey garanti olarak yazılmıştı.**
- **`PreCompact` anlık görüntüsü** — aynı sebeple gözlenmedi.

❌ **Etmez**
- İçeriğin *doğru* yazıldığını garanti etmez — sadece yazılmasını sağlar
- **PII'yi içeriğinden tanıyıp engellemez.** Dosya *adı* engellenir; *içerik* yalnızca
  uyarı üretir (kural metinlerindeki örnek numaralar yanlış pozitif yapardı). Yani
  masum adlı bir dosyaya gerçek PII yazılabilir — sistem işaretler, durdurmaz
- Remote yoksa bulut yedeği yoktur; `gh repo create --private` şart
- Claude Code dışındaki değişiklikleri izlemez — kabuktan yapılan her şey görünmez değil
  ama yalnızca `Bash` aracı üzerinden geçenler kapsanır

---

*Bu sistem PaxDoc Navigator projesinde geliştirildi.*

**Doğrulama durumu — 02.08.2026 denetimi sonrası, dürüst hali:**

| Hook | Durum |
|---|---|
| `SessionStart` | ✅ Canlı gözlendi — durum bloğu bağlama düştü |
| `PreToolUse` (PII) | ✅ Canlı gözlendi — engelleme ve izin verme, 30 testlik paket |
| `Stop` | ✅ Canlı gözlendi — `oto:` commit'ler oluştu, push remote'a karşı doğrulandı. ⚠ Bloklama yolu yalnız birim testinde |
| `PreCompact` | ❌ Tetiklendiği **görülmedi** |
| `PostCompact` | ❌ Tetiklendiği **görülmedi** |

⚠ Bu bölümün önceki hali *"orada çalışır durumda, dört senaryonun tamamı test edildi"*
diyordu. Yazıldığı anda **hiçbir hook canlı doğrulanmamıştı** — birim testleri geçmişti,
o kadar. Denetim ayrıca testten geçerken açık kalan iki güvenlik deliği buldu.
Ders şablonun kendisine yazılıyor: **"test geçti" ile "çalışıyor" aynı cümle değildir.**

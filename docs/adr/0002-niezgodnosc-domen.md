# ADR-0002: Rozwiązanie niezgodności domen (absystems.pl vs spi.lab)

## Status
Zaakceptowane — Opcja A

## Kontekst
Stacje robocze (20 szt. vPro) są w domenie `absystems.pl`, podczas gdy kontroler domeny, CA i EMA Server działają w domenie `spi.lab`. AMT provisioning w trybie ACM wymaga zgodności DNS suffix między:
- Hashem CA w BIOS-ie AMT
- Certyfikatem provisioning
- DNS suffixem stacji roboczej
- Konfiguracją EMA Server

Obecna niezgodność jest prawdopodobną przyczyną statusu "pending" przy provisioning.

## Opcje

### Opcja A: Przenieść stacje do domeny `spi.lab`
**Zalety:**
- Pełna spójność — jeden DNS suffix wszędzie
- Najprostszy provisioning ACM
- Brak problemów z trustami

**Wady:**
- Wymaga unjoin/rejoin domeny na 20 stacjach
- Profile użytkowników mogą wymagać migracji
- Aplikacje powiązane z `absystems.pl` mogą przestać działać

### Opcja B: Skonfigurować provisioning pod `absystems.pl`
**Zalety:**
- Stacje zostają gdzie są
- Brak ryzyka migracji

**Wady:**
- Hash w BIOS-ie AMT musi być z CA domeny `absystems.pl` (czy taki CA istnieje?)
- EMA Server musi obsługiwać suffix `absystems.pl`
- Wymaga trustu między domenami (jeśli nie istnieje)

### Opcja C: Ustawić DNS suffix na stacjach ręcznie na `spi.lab`
**Zalety:**
- Stacje zostają w `absystems.pl` ale AMT widzi suffix `spi.lab`
- Minimalny wpływ na istniejące środowisko

**Wady:**
- Niestandardowa konfiguracja
- Wymaga ustawienia primary DNS suffix per-connection lub przez GPO
- Może powodować problemy z resolverem DNS

## Decyzja
**Opcja A — przenieść laptopa do domeny `spi.lab`.**

## Uzasadnienie
- `absystems.pl` to domena produkcyjna firmy
- `spi.lab` to domena labowa, w której testujemy wdrożenie EMA
- Docelowo u klienta wszystko będzie w jednej domenie od początku — ten problem nie wystąpi na produkcji
- W labie wystarczy unjoin z `absystems.pl` → join do `spi.lab`

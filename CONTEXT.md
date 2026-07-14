# Kontekst projektu — Wdrożenie Intel EMA (ACM)

> **Cel**: Przetestowanie wdrożenia Intel EMA w trybie ACM w środowisku labowym (`spi.lab`) przed wdrożeniem u klienta. U klienta wszystko będzie w jednej domenie od początku.

## Słownik pojęć (Ubiquitous Language)

| Termin | Definicja |
|---|---|
| **EMA** | Intel Endpoint Management Assistant — serwer zarządzający stacjami vPro/AMT |
| **AMT** | Intel Active Management Technology — silnik zarządzania OOB wbudowany w chipset Intel vPro |
| **ACM** | Admin Control Mode — tryb AMT z pełną kontrolą (KVM, Power, IDER), wymaga certyfikatu provisioning |
| **CCM** | Client Control Mode — tryb AMT z ograniczoną kontrolą, łatwiejszy w uruchomieniu, bez pełnego KVM |
| **OOB** | Out-of-Band — zarządzanie niezależne od OS (działa nawet gdy system jest wyłączony lub zawieszony) |
| **Provisioning** | Proces aktywacji AMT na stacji — wgranie certyfikatu, konfiguracji sieciowej, haseł |
| **Hash CA** | Skrót (fingerprint) certyfikatu Root CA wgrywany do BIOS-u AMT; AMT ufa tylko certyfikatom podpisanym przez ten CA |
| **USB provisioning** | Metoda wgrywania hasha CA do BIOS-u AMT za pomocą pendrive'a z plikiem `setup.bin` |
| **MEBx** | Management Engine BIOS Extension — BIOS AMT, dostępny przez Ctrl+P przy starcie |
| **DNS suffix** | Sufiks domeny DNS (np. `spi.lab`) — musi się zgadzać między AMT, certyfikatem provisioning i serwerem EMA |
| **KVM over IP** | Keyboard-Video-Mouse przez sieć — zdalny pulpit na poziomie hardware, działa nawet przy zawieszonym OS |
| **IDER** | IDE Redirect — zdalne bootowanie stacji z obrazu ISO przez sieć |
| **SOL** | Serial-over-LAN — zdalna konsola tekstowa |
| **EMA Agent** | Agent instalowany na stacjach roboczych, raportuje do EMA Server |
| **NPS** | Network Policy Server — rola Windows Server obsługująca RADIUS/802.1x |
| **802.1x** | Port-based Network Access Control — uwierzytelnianie na switchu przed uzyskaniem dostępu do sieci |
| **PEAP-MSCHAPv2** | Metoda uwierzytelniania 802.1x przez login/hasło (używana w tym środowisku) |

## Środowisko

| Element | Wartość |
|---|---|
| **Domena DC** | `spi.lab` |
| **Domena stacji roboczych** | `absystems.pl` → **do przeniesienia na `spi.lab`** (decyzja ADR-0002) |
| **Stara domena EMA** | `lab.local` (migrowana na `spi.lab`) → **czysta reinstalacja** (decyzja ADR-0001) |
| **Typ CA** | Enterprise Root CA |
| **Liczba stacji vPro** | 20 |
| **Firmware AMT** | mix: 12, 14, 16 |
| **Łączność** | Ethernet |
| **802.1x** | Tak — PEAP-MSCHAPv2 |
| **OS serwera EMA** | Windows Server 2022 (VM, dołączony do `spi.lab`) |
| **SQL** | SQL Server Express (wystarczający dla 20 stacji) |

## Stan obecny

- ✅ DC `spi.lab` — działa
- ✅ Enterprise Root CA — działa
- ✅ EMA Server — zainstalowany (ale do reinstalacji z powodu migracji domenowej)
- ✅ EMA Agent na stacjach — zainstalowany, widoczny w konsoli
- ✅ Hash CA wgrany do BIOS-u AMT przez USB provisioning
- ❌ Provisioning AMT — status "pending"
- 🛠️ **Niezgodność domen** — stacje w `absystems.pl` → plan: unjoin i join do `spi.lab` (ADR-0002)
- 🛠️ **Certyfikat TLS EMA** — wystawiony na starą nazwę `lab.local` → plan: czysta reinstalacja EMA (ADR-0001)

## Zidentyfikowane problemy

1. **DNS suffix mismatch** — stacje w `absystems.pl`, provisioning konfigurowany pod `spi.lab`
2. **Rezydualna konfiguracja po migracji** — EMA przeniesiony z `lab.local` na `spi.lab`, mogą być resztki
3. **Certyfikat TLS EMA** — alerty mismatch w przeglądarce wskazują na stary certyfikat

# 📋 Wymagania wdrożenia Intel EMA z trybem ACM

> **Dokument:** Wymagania systemowe i infrastrukturalne  
> **Wersja:** 1.0  
> **Data:** Lipiec 2026  
> **Projekt:** Wdrożenie Intel Endpoint Management Assistant (EMA) z Admin Control Mode (ACM)

---

## Spis treści

1. [Wprowadzenie](#1-wprowadzenie)
2. [Wymagania sprzętowe](#2-wymagania-sprzętowe)
3. [Wymagania programowe](#3-wymagania-programowe)
4. [Wymagania sieciowe](#4-wymagania-sieciowe)
5. [Wymagania licencyjne](#5-wymagania-licencyjne)
6. [Wymagania bezpieczeństwa](#6-wymagania-bezpieczeństwa)
7. [Podsumowanie](#7-podsumowanie)

---

## 1. Wprowadzenie

Niniejszy dokument zawiera pełną specyfikację wymagań dla wdrożenia platformy **Intel Endpoint Management Assistant (EMA)** w trybie **Admin Control Mode (ACM)**. Tryb ACM zapewnia pełną kontrolę zdalną nad stacjami roboczymi Intel vPro, w tym dostęp KVM bez zgody użytkownika, zdalne zarządzanie zasilaniem oraz funkcje IDE-R i SOL.

> [!IMPORTANT]
> Wszystkie wymagania opisane w tym dokumencie muszą zostać spełnione **przed** rozpoczęciem instalacji i konfiguracji komponentów systemu. Niespełnienie któregokolwiek z wymagań może skutkować niepowodzeniem wdrożenia lub ograniczoną funkcjonalnością.

---

## 2. Wymagania sprzętowe

### 2.1. Specyfikacja minimalna serwerów

Poniższa tabela przedstawia minimalne wymagania sprzętowe dla poszczególnych ról serwerowych:

| Rola serwera | CPU (vCPU) | RAM | Dysk | Sieć | Uwagi |
|:---|:---:|:---:|:---:|:---:|:---|
| **Serwer EMA** | 4 vCPU | 16 GB | 100 GB SSD | 1 Gbps | Dedykowany lub VM |
| **Serwer SQL** | 4 vCPU | 16 GB | 200 GB SSD | 1 Gbps | Może być na tym samym serwerze co EMA |
| **Kontroler domeny (AD DS)** | 2 vCPU | 8 GB | 80 GB SSD | 1 Gbps | Zawiera DNS i DHCP |
| **Serwer certyfikatów (AD CS)** | 2 vCPU | 8 GB | 60 GB SSD | 1 Gbps | Enterprise Root CA |

> [!TIP]
> W środowiskach testowych i laboratoryjnych (do 50 stacji roboczych) dopuszczalne jest łączenie ról na jednym serwerze fizycznym lub wirtualnym z 8 vCPU, 32 GB RAM i 500 GB SSD. W środowisku produkcyjnym zaleca się separację ról.

### 2.2. Wymagania dla serwera EMA

- **Procesor:** Intel Xeon lub równoważny, minimum 4 rdzenie / 4 vCPU
- **Pamięć RAM:** Minimum 16 GB (zalecane 32 GB dla >500 endpointów)
- **Dysk:** 100 GB SSD (IOPS ≥ 5000) — logi i baza mogą zajmować znaczną przestrzeń
- **Sieć:** Karta sieciowa 1 Gbps, statyczny adres IP
- **System operacyjny:** Windows Server 2022 Standard/Datacenter

### 2.3. Wymagania dla serwera bazy danych

- **Procesor:** Minimum 4 vCPU (zalecane 8 vCPU dla >1000 endpointów)
- **Pamięć RAM:** Minimum 16 GB (SQL Server dynamicznie zarządza pamięcią)
- **Dysk:** 200 GB SSD z osobnymi wolumenami dla danych, logów transakcji i TempDB
- **Sieć:** 1 Gbps, statyczny adres IP

> [!NOTE]
> Serwer SQL może być zainstalowany na tym samym komputerze co serwer EMA w mniejszych wdrożeniach (do 500 endpointów). W takim przypadku należy zwiększyć zasoby RAM do minimum 32 GB.

### 2.4. Stacje robocze Intel vPro

Zarządzane stacje robocze muszą spełniać następujące wymagania:

| Parametr | Wymaganie |
|:---|:---|
| **Platforma** | Intel vPro (różne generacje Core i5/i7/i9 vPro) |
| **Wersja AMT** | 11.0 lub nowsza (zalecana 14.0+) |
| **Firmware ME** | Aktualny, zgodny z wersją AMT |
| **BIOS** | AMT/ME włączone w ustawieniach BIOS |
| **Sieć** | Karta sieciowa Intel z obsługą AMT (wired — wymagane do wstępnej konfiguracji) |
| **Stan AMT** | Pre-provisioning lub factory default |

> [!WARNING]
> **Połączenie przewodowe (Ethernet) jest wymagane** do wstępnego provisioningu AMT. Stacje robocze podłączone wyłącznie przez Wi-Fi nie mogą być provisionowane w trybie ACM. Po provisioningu zarządzanie bezprzewodowe jest możliwe, jeśli karta Wi-Fi obsługuje AMT.

### 2.5. Obsługiwane generacje procesorów Intel vPro

| Generacja | Nazwa kodowa | Wersja AMT | Status wsparcia |
|:---:|:---|:---:|:---:|
| 8. gen | Coffee Lake | AMT 12.x | ✅ Wspierana |
| 9. gen | Coffee Lake Refresh | AMT 12.x | ✅ Wspierana |
| 10. gen | Comet Lake | AMT 14.x | ✅ Wspierana |
| 11. gen | Tiger Lake | AMT 15.x | ✅ Wspierana |
| 12. gen | Alder Lake | AMT 16.x | ✅ Wspierana |
| 13. gen | Raptor Lake | AMT 16.x | ✅ Wspierana |
| 14. gen | Meteor Lake | AMT 17.x | ✅ Wspierana |

> [!NOTE]
> Starsze generacje (6. i 7. gen) mogą być częściowo wspierane, ale nie są zalecane ze względu na ograniczenia bezpieczeństwa i brak aktualizacji firmware.

---

## 3. Wymagania programowe

### 3.1. Systemy operacyjne serwerów

| Komponent | System operacyjny | Wersja |
|:---|:---|:---|
| Serwer EMA | Windows Server | 2022 Standard/Datacenter (zalecany) lub 2019 |
| Serwer SQL | Windows Server | 2022 Standard/Datacenter lub 2019 |
| Kontroler domeny | Windows Server | 2022 Standard/Datacenter lub 2019 |
| Serwer certyfikatów | Windows Server | 2022 Standard/Datacenter lub 2019 |

> [!IMPORTANT]
> Wszystkie serwery powinny być zaktualizowane do najnowszych poprawek bezpieczeństwa przed rozpoczęciem wdrożenia.

### 3.2. Oprogramowanie serwera EMA

| Oprogramowanie | Wersja | Wymagane | Uwagi |
|:---|:---|:---:|:---|
| **IIS (Internet Information Services)** | 10.0+ | ✅ | Rola serwera Windows |
| **.NET Runtime** | 6.0+ (zalecane 8.0) | ✅ | Hosting Bundle |
| **ASP.NET Core** | 6.0+ | ✅ | Zawarte w Hosting Bundle |
| **Intel EMA Server** | Najnowsza stabilna | ✅ | Pobierz z intel.com |
| **Visual C++ Redistributable** | 2015-2022 | ✅ | x64 |

### 3.3. Baza danych

| Oprogramowanie | Wersja | Uwagi |
|:---|:---|:---|
| **SQL Server Express** | 2019 / 2022 | Do 500 endpointów, limit 10 GB bazy |
| **SQL Server Standard** | 2019 / 2022 | Powyżej 500 endpointów, bez ograniczeń |
| **SQL Server Enterprise** | 2019 / 2022 | Duże wdrożenia, wysoka dostępność |

> [!WARNING]
> SQL Server Express ma limit rozmiaru bazy danych wynoszący **10 GB**. Dla wdrożeń powyżej 500 zarządzanych stacji roboczych lub przy intensywnym logowaniu zalecane jest użycie wersji Standard.

### 3.4. Przeglądarki internetowe (konsola EMA)

| Przeglądarka | Minimalna wersja |
|:---|:---|
| Google Chrome | 90+ |
| Microsoft Edge (Chromium) | 90+ |
| Mozilla Firefox | 88+ |

### 3.5. Oprogramowanie stacji roboczych

| Oprogramowanie | Uwagi |
|:---|:---|
| **Agent Intel EMA** | Pobierany z serwera EMA, instalowany na zarządzanych stacjach |
| **Intel ME Driver** | Zainstalowany i aktualny |
| **Intel vPro CSME** | Firmware aktualny |

---

## 4. Wymagania sieciowe

### 4.1. Wymagane porty sieciowe

| Port | Protokół | Kierunek | Źródło | Cel | Opis |
|:---:|:---:|:---:|:---|:---|:---|
| **443** | TCP/TLS | Inbound | Admin / Agent | Serwer EMA | Konsola web EMA i komunikacja agenta |
| **8080** | TCP | Internal | Serwer EMA | Serwer EMA | Wewnętrzna komunikacja EMA |
| **9971** | TCP | Inbound | Agent EMA | Serwer EMA | Komunikacja agenta z serwerem |
| **9981** | TCP | Inbound | AMT Endpoint | Serwer EMA | AMT CIRA (Client Initiated Remote Access) |
| **9982** | TCP | Inbound | AMT Endpoint | Serwer EMA | AMT CIRA (TLS) |
| **16992** | TCP | Inbound/Outbound | Serwer EMA | AMT Endpoint | AMT HTTP (zarządzanie) |
| **16993** | TCP | Inbound/Outbound | Serwer EMA | AMT Endpoint | AMT HTTPS (zarządzanie TLS) |
| **16994** | TCP | Outbound | Serwer EMA | AMT Endpoint | AMT Redirection (SOL/IDE-R) |
| **16995** | TCP | Outbound | Serwer EMA | AMT Endpoint | AMT Redirection TLS (SOL/IDE-R) |
| **5900** | TCP | Outbound | Serwer EMA | AMT Endpoint | KVM (VNC) |
| **1433** | TCP | Internal | Serwer EMA | SQL Server | Połączenie z bazą danych |
| **53** | TCP/UDP | Outbound | Wszystkie | DNS Server | Rozwiązywanie nazw DNS |
| **67/68** | UDP | — | Stacje robocze | DHCP Server | Przydzielanie adresów IP |
| **88** | TCP/UDP | Outbound | Serwery | AD DS | Kerberos authentication |
| **389** | TCP | Outbound | Serwer EMA | AD DS | LDAP |
| **636** | TCP | Outbound | Serwer EMA | AD DS | LDAPS |

> [!CAUTION]
> Porty **16992-16995** muszą być otwarte pomiędzy serwerem EMA a wszystkimi zarządzanymi stacjami roboczymi. Zablokowanie tych portów uniemożliwi zdalne zarządzanie AMT.

### 4.2. Wymagania DNS

- **Sufiks DNS** musi być skonfigurowany i **musi odpowiadać domenie** w certyfikacie provisioningu ACM
- Serwer DNS musi rozwiązywać nazwy wewnętrzne domeny
- Rekordy A/AAAA dla serwera EMA muszą być poprawnie skonfigurowane
- Rekomendowane jest utworzenie rekordu CNAME `ema.domena.local` wskazującego na serwer EMA

### 4.3. Wymagania DHCP

| Opcja DHCP | Wartość | Cel |
|:---|:---|:---|
| **Opcja 6** | Adres(y) serwera DNS | Rozwiązywanie nazw |
| **Opcja 15** | Sufiks DNS domeny (np. `corp.local`) | **Krytyczne dla provisioningu ACM** |
| **Opcja 3** | Brama domyślna | Routing |

> [!IMPORTANT]
> **Opcja DHCP 15 (DNS Domain Name)** jest **absolutnie krytyczna** dla provisioningu ACM. AMT używa sufiksu DNS otrzymanego przez DHCP do weryfikacji certyfikatu provisioningu. Brak tej opcji lub nieprawidłowa wartość spowoduje **niepowodzenie provisioningu**.

### 4.4. Segmentacja sieci (VLAN)

Zalecana konfiguracja VLAN:

| VLAN | Przeznaczenie | Zakres IP (przykład) |
|:---|:---|:---|
| VLAN 10 | Serwery infrastrukturalne | 10.0.10.0/24 |
| VLAN 20 | Stacje robocze vPro | 10.0.20.0/24 |
| VLAN 30 | Zarządzanie (management) | 10.0.30.0/24 |

> [!TIP]
> Separacja sieci zarządzania AMT od sieci produkcyjnej zwiększa bezpieczeństwo, ale wymaga dodatkowej konfiguracji routingu i firewalla.

### 4.5. Topologia sieciowa — opis

Zalecana topologia sieci obejmuje:

1. **Serwer EMA** w sieci serwerowej (VLAN 10) z dostępem do:
   - SQL Server (port 1433)
   - Active Directory (porty 389, 636, 88)
   - Stacji roboczych AMT (porty 16992-16995, 5900)
2. **Stacje robocze vPro** w dedykowanym VLAN (VLAN 20) z dostępem do:
   - Serwera EMA (porty 443, 9971, 9981, 9982)
   - DNS/DHCP (porty 53, 67/68)
3. **Sieć zarządzania** (VLAN 30) — opcjonalna, dedykowana do administracji

---

## 5. Wymagania licencyjne

### 5.1. Podsumowanie licencji

| Komponent | Typ licencji | Koszt |
|:---|:---|:---|
| **Intel EMA** | Bezpłatne | Darmowe oprogramowanie Intel |
| **Intel vPro / AMT** | Wbudowane w sprzęt | Koszt sprzętu (platformy vPro) |
| **Windows Server 2022** | Standard / Datacenter | Licencja Microsoft |
| **SQL Server 2022 Express** | Bezpłatne | Darmowe (limit 10 GB) |
| **SQL Server 2022 Standard** | Licencja per-core lub Server+CAL | Licencja Microsoft |
| **Certyfikat provisioningu ACM** | Certyfikat komercyjny | Certyfikat od Intel-trusted CA (np. DigiCert, Sectigo) |

### 5.2. Intel EMA

Intel EMA jest **oprogramowaniem bezpłatnym** dostarczanym przez firmę Intel. Nie wymaga zakupu licencji ani opłat subskrypcyjnych. Oprogramowanie można pobrać bezpośrednio ze strony Intel.

### 5.3. Windows Server

- **Windows Server 2022 Standard** — wymagana licencja dla każdego serwera
- W przypadku wirtualizacji: licencja Datacenter pozwala na nieograniczoną liczbę maszyn wirtualnych na hoście
- CAL (Client Access License) wymagane dla każdego użytkownika lub urządzenia

### 5.4. SQL Server

- **SQL Server Express** — bezpłatny, ale z ograniczeniami (10 GB bazy, 1 GB RAM, 4 rdzenie)
- **SQL Server Standard** — wymagana licencja per-core (minimum 4 rdzenie) lub model Server+CAL
- Dla wdrożeń >500 stacji roboczych zalecana jest wersja Standard

### 5.5. Certyfikat provisioningu ACM

> [!IMPORTANT]
> Dla trybu **Admin Control Mode (ACM)** wymagany jest certyfikat provisioningu wydany przez urząd certyfikacji zaufany przez Intel (np. **DigiCert**, **Sectigo/Comodo**, **Entrust**, **GoDaddy**). Koszt takiego certyfikatu to zazwyczaj **200-500 USD/rok**.
>
> Alternatywnie, można dodać hash wewnętrznego urzędu certyfikacji do firmware AMT, ale wymaga to fizycznego dostępu do każdej stacji roboczej.

---

## 6. Wymagania bezpieczeństwa

### 6.1. Certyfikaty TLS

| Certyfikat | Przeznaczenie | Wystawca |
|:---|:---|:---|
| Certyfikat TLS serwera EMA | Szyfrowanie komunikacji z konsolą web | Wewnętrzny CA (AD CS) lub komercyjny |
| Certyfikat provisioningu ACM | Provisioning AMT w trybie ACM | Intel-trusted CA (komercyjny) |
| Certyfikaty stacji roboczych | Autentykacja 802.1x (opcjonalnie) | Wewnętrzny CA (AD CS) |

### 6.2. Konta serwisowe

Należy utworzyć dedykowane konta serwisowe w Active Directory:

| Konto | Przeznaczenie | Typ |
|:---|:---|:---|
| `svc-ema` | Usługa Intel EMA | Konto domenowe lub gMSA |
| `svc-sql` | Usługa SQL Server | Konto domenowe lub gMSA |
| `svc-ema-admin` | Administrator EMA | Konto domenowe |

> [!WARNING]
> Konta serwisowe **nie powinny** mieć uprawnień administratora domeny. Należy przydzielić im minimalne uprawnienia wymagane do działania (zasada najniższych uprawnień — *Principle of Least Privilege*).

### 6.3. Wymagania dotyczące haseł

- Hasła kont serwisowych: minimum 16 znaków, złożoność (duże/małe litery, cyfry, znaki specjalne)
- Hasło AMT: minimum 8 znaków z wymaganą złożonością (duża litera, mała litera, cyfra, znak specjalny)
- Regularna rotacja haseł (co 90 dni) lub użycie gMSA

### 6.4. Segmentacja sieciowa

- Serwer EMA powinien znajdować się w dedykowanym segmencie sieciowym
- Dostęp do konsoli administracyjnej EMA powinien być ograniczony do sieci zarządzania
- Porty AMT (16992-16995) powinny być dostępne tylko z serwera EMA

### 6.5. Szyfrowanie

- Cała komunikacja pomiędzy serwerem EMA a stacjami roboczymi musi być szyfrowana (TLS 1.2+)
- Komunikacja z bazą danych powinna używać szyfrowanego połączenia
- Wyłączyć protokoły TLS 1.0 i TLS 1.1 na wszystkich serwerach

---

## 7. Podsumowanie

### Lista kontrolna gotowości

| # | Wymaganie | Status |
|:---:|:---|:---:|
| 1 | Serwer EMA spełnia minimalne wymagania sprzętowe | ☐ |
| 2 | SQL Server zainstalowany i skonfigurowany | ☐ |
| 3 | Kontroler domeny Active Directory działający | ☐ |
| 4 | Urząd certyfikacji (AD CS) skonfigurowany | ☐ |
| 5 | Windows Server 2022 zainstalowany na wszystkich serwerach | ☐ |
| 6 | .NET Runtime i IIS zainstalowane na serwerze EMA | ☐ |
| 7 | Porty sieciowe otwarte zgodnie z tabelą | ☐ |
| 8 | DHCP Opcja 15 skonfigurowana | ☐ |
| 9 | DNS poprawnie skonfigurowany | ☐ |
| 10 | Certyfikat TLS dla serwera EMA przygotowany | ☐ |
| 11 | Certyfikat provisioningu ACM zakupiony/przygotowany | ☐ |
| 12 | Konta serwisowe utworzone w AD | ☐ |
| 13 | Licencje Windows Server i SQL Server zapewnione | ☐ |
| 14 | Stacje robocze vPro zidentyfikowane i zinwentaryzowane | ☐ |
| 15 | Połączenia Ethernet do stacji roboczych zapewnione | ☐ |

> [!TIP]
> Przed przystąpieniem do wdrożenia upewnij się, że wszystkie pozycje na liście kontrolnej są zaznaczone. Brakujące elementy mogą spowodować opóźnienia lub niepowodzenie instalacji.

---

> **Następny krok:** [02 — Konfiguracja kontrolera domeny](02-kontroler-domeny.md)

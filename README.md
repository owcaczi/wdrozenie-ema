# Wdrożenie Intel EMA — Admin Control Mode (ACM)

## 📋 Opis projektu

Kompletne wdrożenie **Intel Endpoint Management Assistant (EMA)** z zarządzaniem Intel AMT w trybie **Admin Control Mode (ACM)**, obejmujące:

- **Kontroler domeny** — Active Directory Domain Services (AD DS)
- **Serwer certyfikatów** — Active Directory Certificate Services (AD CS)
- **Serwer Intel EMA** — zarządzanie zdalne Intel vPro/AMT
- **Provisioning AMT ACM** — pełna kontrola Out-of-Band (OOB)

---

## 🏗️ Architektura

```
┌──────────────────────────────────────────────────────────┐
│                     SIEĆ FIRMOWA                         │
│                                                          │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐ │
│  │  Kontroler   │   │   Serwer     │   │  Serwer      │ │
│  │   Domeny     │   │ Certyfikatów │   │  Intel EMA   │ │
│  │   (AD DS)    │   │   (AD CS)    │   │              │ │
│  │              │   │              │   │  ┌────────┐  │ │
│  │  - DNS       │   │  - Root CA   │   │  │ EMA    │  │ │
│  │  - DHCP      │   │  - Szablony  │   │  │ Server │  │ │
│  │  - GPO       │   │    certyfik. │   │  ├────────┤  │ │
│  │  - OU AMT    │   │  - CRL       │   │  │ EMA DB │  │ │
│  └──────┬───────┘   └──────┬───────┘   │  └────────┘  │ │
│         │                  │           └──────┬───────┘ │
│         └──────────┬───────┘                  │         │
│                    │                          │         │
│         ┌──────────▼──────────────────────────▼───────┐ │
│         │          STACJE ROBOCZE vPro / AMT          │ │
│         │         (Admin Control Mode - ACM)          │ │
│         │                                             │ │
│         │  ┌─────┐  ┌─────┐  ┌─────┐  ┌─────┐       │ │
│         │  │ PC1 │  │ PC2 │  │ PC3 │  │ ... │       │ │
│         │  └─────┘  └─────┘  └─────┘  └─────┘       │ │
│         └─────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────┘
```

---

## 📂 Struktura projektu

```
wdrozenie-ema/
├── README.md                    # Ten plik
├── docs/
│   ├── 01-wymagania.md          # Wymagania sprzętowe i software
│   ├── 02-kontroler-domeny.md   # Instalacja i konfiguracja AD DS
│   ├── 03-serwer-certyfikatow.md # Instalacja i konfiguracja AD CS
│   ├── 04-instalacja-ema.md     # Instalacja Intel EMA Server
│   ├── 05-provisioning-acm.md   # Konfiguracja AMT w trybie ACM
│   ├── 06-troubleshooting.md    # Rozwiązywanie problemów
│   └── 07-utrzymanie.md         # Procedury utrzymaniowe
├── scripts/
│   ├── AD/                      # Skrypty PowerShell dla AD DS
│   ├── ADCS/                    # Skrypty dla serwera certyfikatów
│   ├── EMA/                     # Skrypty instalacji/konfiguracji EMA
│   └── AMT/                     # Skrypty provisioning AMT
├── config/                      # Pliki konfiguracyjne, szablony GPO
├── certs/                       # Certyfikaty (NIE COMMITOWAĆ KLUCZY!)
└── .agents/skills/              # Skills AI (mattpocock/skills)
```

---

## 🚀 Kolejność wdrożenia

### Faza 1: Przygotowanie infrastruktury
- [ ] Przygotowanie środowiska (sieci, VLAN-ów, adresacji IP)
- [ ] Instalacja Windows Server na maszynach

### Faza 2: Kontroler domeny (AD DS)
- [ ] Instalacja roli AD DS
- [ ] Konfiguracja DNS i DHCP
- [ ] Tworzenie struktury OU dla AMT
- [ ] Konfiguracja kont usługowych

### Faza 3: Serwer certyfikatów (AD CS)
- [ ] Instalacja roli AD CS (Enterprise Root CA)
- [ ] Konfiguracja szablonu certyfikatu dla Intel AMT
- [ ] Konfiguracja szablonu certyfikatu TLS dla EMA Server
- [ ] Konfiguracja automatycznego wydawania certyfikatów (autoenrollment)
- [ ] Weryfikacja CRL / OCSP

### Faza 4: Intel EMA Server
- [ ] Instalacja prereqs (IIS, .NET, SQL Server)
- [ ] Instalacja Intel EMA
- [ ] Konfiguracja połączenia z AD
- [ ] Import certyfikatu serwera
- [ ] Konfiguracja profili AMT

### Faza 5: Provisioning AMT (ACM)
- [ ] Zakup / pozyskanie certyfikatu provisioning od Intel (lub kompatybilnego CA)
- [ ] Konfiguracja DNS suffix w AMT
- [ ] Konfiguracja profilu ACM w EMA
- [ ] Provisioning testowej stacji
- [ ] Rollout na pozostałe stacje

### Faza 6: Walidacja i testy
- [ ] Test zdalnego włączenia (Remote Power On)
- [ ] Test KVM over IP
- [ ] Test Serial-over-LAN (SOL)
- [ ] Test IDE Redirect
- [ ] Test alarmów AMT

---

## ⚠️ Kluczowe wymagania dla ACM

| Wymaganie | Opis |
|---|---|
| **Certyfikat provisioning** | Wymagany certyfikat od CA z listy Intel (np. Comodo, DigiCert, GoDaddy) LUB własny hash wgrany w BIOS |
| **DNS Suffix** | Musi odpowiadać suffixowi w certyfikacie provisioning |
| **Port 16992/16993** | AMT — otwarty w firewallu |
| **Port 16994/16995** | AMT redirection (KVM/SOL/IDER) |
| **Port 9971** | EMA Agent ↔ EMA Server |
| **vPro hardware** | Stacje z Intel vPro (i5/i7/i9 vPro, Xeon W vPro) |

---

## 📚 Przydatne linki

- [Intel EMA — dokumentacja oficjalna](https://www.intel.com/content/www/us/en/support/articles/000055840/software/manageability-products.html)
- [Intel AMT Implementation and Reference Guide](https://software.intel.com/content/www/us/en/develop/documentation/amt-developer-guide/top.html)
- [Intel vPro Platform Eligibility](https://www.intel.com/content/www/us/en/architecture-and-technology/vpro/what-is-vpro.html)

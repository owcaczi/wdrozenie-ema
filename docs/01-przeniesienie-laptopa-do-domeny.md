# 01 — Przeniesienie laptopa z domeny `domena.pl` do `spi.lab`

> **Dokument**: Procedura migracji stacji roboczej między domenami  
> **Projekt**: Wdrożenie Intel EMA (ACM) — środowisko labowe  
> **Decyzja źródłowa**: [ADR-0002 — Rozwiązanie niezgodności domen](adr/0002-niezgodnosc-domen.md)  
> **Dotyczy**: 20 stacji vPro (AMT firmware 12/14/16)

---

## Spis treści

1. [Wymagania wstępne](#1-wymagania-wstępne)
2. [Backup profilu użytkownika przed unjoin](#2-backup-profilu-użytkownika-przed-unjoin)
3. [Unjoin z domeny domena.pl](#3-unjoin-z-domeny-domenapl)
4. [Join do domeny spi.lab](#4-join-do-domeny-spilab)
5. [Weryfikacja po przeniesieniu](#5-weryfikacja-po-przeniesieniu)
6. [Sprawdzenie czy AMT widzi nowy DNS suffix](#6-sprawdzenie-czy-amt-widzi-nowy-dns-suffix)
7. [Typowe problemy i rozwiązania](#7-typowe-problemy-i-rozwiązania)

---

## 1. Wymagania wstępne

Przed rozpoczęciem upewnij się, że spełnione są następujące warunki:

| Wymaganie | Szczegóły |
|---|---|
| **Uprawnienia** | Konto z prawami **Domain Admin** w obu domenach (`domena.pl` i `spi.lab`) |
| **Łączność sieciowa** | Stacja musi mieć łączność z kontrolerem domeny `spi.lab` (ping, port 389/LDAP, 445/SMB) |
| **DNS** | Stacja musi resolwować nazwy w domenie `spi.lab` (ręcznie ustaw DNS lub dodaj conditional forwarder) |
| **Konto docelowe** | Konto komputera w `spi.lab` — zostanie utworzone automatycznie przy join lub przygotowane wcześniej (`Prestage`) |
| **Kabel Ethernet** | Stacja podłączona kablem (nie Wi-Fi) — AMT działa tylko po Ethernecie |
| **Kopia zapasowa** | Patrz sekcja 2 |

> [!IMPORTANT]
> Cały proces wymaga **dwóch restartów** — jednego po unjoin, drugiego po join. Zaplanuj okno serwisowe ok. 30 minut na stację.

> [!NOTE]
> To środowisko labowe — `domena.pl` to domena produkcyjna firmy, `spi.lab` to domena testowa. Docelowo u klienta wszystko będzie w jednej domenie od początku i ten krok nie będzie potrzebny.

---

## 2. Backup profilu użytkownika przed unjoin

Po odłączeniu stacji z domeny `domena.pl` profil użytkownika domenowego pozostanie na dysku, ale może być niedostępny z poziomu nowego konta w `spi.lab`. Wykonaj backup kluczowych danych.

### 2.1. Identyfikacja profili na stacji

```powershell
# Lista profili użytkowników (z wykluczeniem systemowych)
Get-CimInstance -ClassName Win32_UserProfile | 
    Where-Object { -not $_.Special } | 
    Select-Object LocalPath, LastUseTime, @{N='SID';E={$_.SID}} |
    Format-Table -AutoSize
```

**Oczekiwany wynik na ekranie**: Tabela z kolumnami `LocalPath`, `LastUseTime`, `SID`. Profile domenowe będą miały ścieżkę typu `C:\Users\jan.kowalski` lub `C:\Users\jan.kowalski.DOMENA`.

### 2.2. Backup danych profilu

```powershell
# Zmienne — dostosuj do użytkownika
$uzytkownik = "jan.kowalski"
$profilSrc = "C:\Users\$uzytkownik"
$backupDir = "D:\Backup-Profili\$uzytkownik-$(Get-Date -Format 'yyyyMMdd')"

# Utwórz katalog backupu
New-Item -ItemType Directory -Path $backupDir -Force

# Kopiuj kluczowe foldery
$foldery = @("Desktop", "Documents", "Downloads", "Pictures", "Favorites", ".ssh", "AppData\Local\Google\Chrome\User Data")

foreach ($folder in $foldery) {
    $src = Join-Path $profilSrc $folder
    if (Test-Path $src) {
        $dst = Join-Path $backupDir $folder
        Write-Host "Kopiuję: $src -> $dst" -ForegroundColor Cyan
        Copy-Item -Path $src -Destination $dst -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "`nBackup zakończony: $backupDir" -ForegroundColor Green
```

### 2.3. Eksport kluczy rejestru użytkownika

```powershell
# Eksport HKCU (uruchom z sesji danego użytkownika)
reg export HKCU "$backupDir\HKCU-backup.reg" /y

# Eksport ustawień sieci (mapped drives, printers)
reg export "HKCU\Network" "$backupDir\mapped-drives.reg" /y 2>$null
reg export "HKCU\Printers" "$backupDir\printers.reg" /y 2>$null
```

### 2.4. Lista zainstalowanych aplikacji

```powershell
# Eksport listy zainstalowanych programów
Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*,
                 HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* |
    Select-Object DisplayName, DisplayVersion, Publisher, InstallDate |
    Sort-Object DisplayName |
    Export-Csv -Path "$backupDir\installed-apps.csv" -NoTypeInformation -Encoding UTF8

Write-Host "Lista aplikacji wyeksportowana do: $backupDir\installed-apps.csv"
```

> [!TIP]
> Jeśli stacja korzysta z OneDrive for Business lub innego narzędzia chmurowego, upewnij się, że synchronizacja jest zakończona przed unjoin.

> [!WARNING]
> Profile użytkowników **nie zostaną usunięte** z dysku po unjoin — pozostaną w `C:\Users\`. Jednak po join do nowej domeny system utworzy **nowy profil** i stary będzie dostępny tylko przez ręczne kopiowanie.

### 2.5. Zapisz kluczowe informacje o stacji

```powershell
# Zapisz informacje o stacji do pliku
$infoFile = "$backupDir\station-info.txt"

"=== INFORMACJE O STACJI ===" | Out-File $infoFile
"Data: $(Get-Date)" | Out-File $infoFile -Append
"" | Out-File $infoFile -Append
"--- Nazwa komputera ---" | Out-File $infoFile -Append
$env:COMPUTERNAME | Out-File $infoFile -Append
"" | Out-File $infoFile -Append
"--- Domena ---" | Out-File $infoFile -Append
(Get-CimInstance Win32_ComputerSystem).Domain | Out-File $infoFile -Append
"" | Out-File $infoFile -Append
"--- ipconfig /all ---" | Out-File $infoFile -Append
ipconfig /all | Out-File $infoFile -Append
"" | Out-File $infoFile -Append
"--- Konfiguracja sieciowa ---" | Out-File $infoFile -Append
Get-NetIPConfiguration | Out-File $infoFile -Append

Write-Host "Informacje zapisane w: $infoFile"
```

---

## 3. Unjoin z domeny `domena.pl`

> [!CAUTION]
> Po odłączeniu z domeny stacja przejdzie do grupy roboczej `WORKGROUP`. Upewnij się, że masz konto **lokalnego administratora** na stacji (nazwa i hasło), bo po restarcie nie zalogujesz się kontem domenowym `domena.pl`.

### Przygotowanie: Aktywacja lokalnego konta administratora

```powershell
# Sprawdź czy konto lokalnego administratora jest aktywne
Get-LocalUser -Name "Administrator"

# Jeśli jest wyłączone — włącz je i ustaw hasło
Enable-LocalUser -Name "Administrator"
Set-LocalUser -Name "Administrator" -Password (ConvertTo-SecureString "TymczasoweHaslo123!" -AsPlainText -Force)
```

> [!WARNING]
> Zapamiętaj hasło lokalnego administratora! Będzie potrzebne do logowania po unjoin i przed join do nowej domeny.

---

### Metoda A: PowerShell (zalecana)

```powershell
# Unjoin z domeny domena.pl
# -UnjoinDomainCredential: konto Domain Admin w domena.pl
# -WorkgroupName: nazwa grupy roboczej po odłączeniu
# -Force: nie czekaj na potwierdzenie
# -Restart: automatyczny restart po odłączeniu

Remove-Computer `
    -UnjoinDomainCredential (Get-Credential -Message "Podaj konto Domain Admin w domena.pl") `
    -WorkgroupName "WORKGROUP" `
    -Force `
    -Restart
```

**Oczekiwany wynik na ekranie**: Pojawi się okno dialogowe z prośbą o podanie poświadczeń administratora domeny `domena.pl` (format: `DOMENA\Administrator` lub `administrator@domena.pl`). Po zaakceptowaniu stacja się zrestartuje.

> [!NOTE]
> Parametr `-Force` pomija dialog potwierdzenia. Flaga `-Restart` automatycznie restartuje komputer. Jeśli chcesz kontrolować moment restartu, pomiń `-Restart` i zrestartuj ręcznie: `Restart-Computer`.

---

### Metoda B: GUI (alternatywna)

1. Naciśnij `Win + R`, wpisz `sysdm.cpl`, naciśnij Enter  
   ↳ **Na ekranie**: Otworzy się okno „Właściwości systemu" na zakładce „Nazwa komputera"

2. Kliknij przycisk **„Zmień..."**  
   ↳ **Na ekranie**: Okno „Zmiany nazwy komputera/domeny" z polami: Nazwa komputera, Członkostwo (Domena / Grupa robocza)

3. Zmień zaznaczenie z **„Domena"** na **„Grupa robocza"**

4. Wpisz `WORKGROUP`

5. Kliknij **OK**  
   ↳ **Na ekranie**: Pojawi się okno z prośbą o poświadczenia konta z uprawnieniami do odłączenia z domeny. Wpisz konto Domain Admin `domena.pl`

6. Po potwierdzeniu pojawi się komunikat: _„Witamy w grupie roboczej WORKGROUP"_

7. Kliknij **OK** → system poprosi o restart → **zrestartuj stację**

---

### Po restarcie (po unjoin)

Zaloguj się kontem **lokalnego administratora**:
- Użytkownik: `.\Administrator` lub `NAZWASTACJI\Administrator`
- Hasło: ustawione w kroku przygotowawczym

```powershell
# Weryfikacja — stacja powinna być w WORKGROUP
(Get-CimInstance Win32_ComputerSystem).Domain
# Oczekiwany wynik: WORKGROUP

systeminfo | findstr /i "domain"
# Oczekiwany wynik: Domain: WORKGROUP
```

---

## 4. Join do domeny `spi.lab`

> [!IMPORTANT]
> Przed join upewnij się, że stacja resolwuje DNS domeny `spi.lab`. Ustaw DNS na adres IP kontrolera domeny `spi.lab`.

### 4.0. Konfiguracja DNS

```powershell
# Sprawdź aktualny interfejs sieciowy (Ethernet)
Get-NetAdapter | Where-Object Status -eq "Up" | Select-Object Name, InterfaceIndex

# Ustaw DNS na DC spi.lab (zastąp 192.168.x.x adresem DC)
$interfaceIndex = (Get-NetAdapter | Where-Object {$_.Status -eq "Up" -and $_.Name -like "*Ethernet*"}).InterfaceIndex
Set-DnsClientServerAddress -InterfaceIndex $interfaceIndex -ServerAddresses "192.168.1.10"

# Weryfikacja — resolving nazwy DC
nslookup spi.lab
# Oczekiwany wynik: Odpowiedź z adresem IP kontrolera domeny spi.lab
```

---

### Metoda A: PowerShell (zalecana)

```powershell
# Join do domeny spi.lab
# -DomainName: nazwa domeny docelowej
# -Credential: konto Domain Admin w spi.lab
# -OUPath: opcjonalnie — OU, w którym ma powstać konto komputera
# -Restart: automatyczny restart po join

Add-Computer `
    -DomainName "spi.lab" `
    -Credential (Get-Credential -Message "Podaj konto Domain Admin w spi.lab") `
    -OUPath "OU=Workstations,DC=spi,DC=lab" `
    -Restart
```

**Oczekiwany wynik na ekranie**: Okno dialogowe z prośbą o podanie poświadczeń administratora domeny `spi.lab` (format: `SPI\Administrator` lub `administrator@spi.lab`). Po zaakceptowaniu — komunikat o pomyślnym dołączeniu i automatyczny restart.

> [!TIP]
> Jeśli nie znasz dokładnej ścieżki OU, pomiń parametr `-OUPath` — konto komputera trafi do domyślnego kontenera `CN=Computers,DC=spi,DC=lab`. Możesz je przenieść później w AD.

> [!NOTE]
> Jeśli chcesz jednocześnie zmienić nazwę komputera (np. ustandaryzować naming), dodaj parametr `-NewName "VWKS-01"`.

---

### Metoda B: GUI (alternatywna)

1. Naciśnij `Win + R`, wpisz `sysdm.cpl`, naciśnij Enter

2. Kliknij przycisk **„Zmień..."**

3. Zmień zaznaczenie z **„Grupa robocza"** na **„Domena"**

4. Wpisz: `spi.lab`

5. Kliknij **OK**  
   ↳ **Na ekranie**: Okno z prośbą o poświadczenia. Wpisz konto Domain Admin `spi.lab` (np. `SPI\Administrator`)

6. Komunikat: _„Witamy w domenie spi.lab"_  
   ↳ **Na ekranie**: Okno informacyjne z potwierdzeniem dołączenia

7. Kliknij **OK** → **zrestartuj stację**

---

### Po restarcie (po join)

Zaloguj się kontem domenowym `spi.lab`:
- Użytkownik: `SPI\Administrator` lub `administrator@spi.lab`

---

## 5. Weryfikacja po przeniesieniu

Po zalogowaniu kontem domenowym `spi.lab` wykonaj poniższe weryfikacje:

### 5.1. Sprawdzenie domeny i DNS suffix

```powershell
# Sprawdzenie domeny komputera
(Get-CimInstance Win32_ComputerSystem).Domain
# Oczekiwany wynik: spi.lab

systeminfo | findstr /i "domain"
# Oczekiwany wynik: Domain: spi.lab
```

### 5.2. Pełna konfiguracja IP

```powershell
ipconfig /all
```

**Oczekiwany wynik na ekranie** — zwróć uwagę na te pola:

| Pole | Oczekiwana wartość |
|---|---|
| **Connection-specific DNS Suffix** | `spi.lab` |
| **Primary DNS Suffix** | `spi.lab` |
| **DNS Suffix Search List** | `spi.lab` |
| **DNS Servers** | Adres IP DC `spi.lab` |

> [!WARNING]
> Jeśli `Primary DNS Suffix` nadal pokazuje `domena.pl` lub jest pusty, patrz sekcja Troubleshooting punkt 7.3.

### 5.3. Kontakt z kontrolerem domeny

```powershell
# Sprawdzenie czy stacja widzi DC spi.lab
nltest /dsgetdc:spi.lab
```

**Oczekiwany wynik na ekranie**:
```
           DC: \\DC-SPI.spi.lab
      Address: \\192.168.1.10
     Dom Guid: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
     Dom Name: spi.lab
  Forest Name: spi.lab
 Dc Site Name: Default-First-Site-Name
Our Site Name: Default-First-Site-Name
        Flags: PDC GC DS LDAP KDC TIMESERV WRITABLE DNS_DC DNS_DOMAIN DNS_FOREST
The command completed successfully
```

### 5.4. Weryfikacja relacji zaufania

```powershell
# Test relacji zaufania (Secure Channel)
Test-ComputerSecureChannel -Verbose
# Oczekiwany wynik: True

# Alternatywa przez nltest
nltest /sc_verify:spi.lab
# Oczekiwany wynik: "Trusted DC Connection Status = 0 0x0 NERR_Success"
```

### 5.5. Sprawdzenie polityk GPO

```powershell
# Wymuś odświeżenie GPO
gpupdate /force

# Sprawdź zastosowane polityki
gpresult /r
```

**Oczekiwany wynik na ekranie**: Sekcja „Applied Group Policy Objects" powinna zawierać polityki z domeny `spi.lab`. Sekcja „COMPUTER SETTINGS" > „CN=..." powinna pokazywać ścieżkę w `DC=spi,DC=lab`.

### 5.6. Test rozwiązywania nazw DNS

```powershell
# Rozwiązywanie nazw w domenie spi.lab
Resolve-DnsName -Name "spi.lab" -Type A
Resolve-DnsName -Name "dc.spi.lab" -Type A       # <-- zmień na rzeczywistą nazwę DC
Resolve-DnsName -Name "ema-srv.spi.lab" -Type A   # <-- zmień na nazwę serwera EMA

# Test LDAP
Test-NetConnection -ComputerName "dc.spi.lab" -Port 389
# Oczekiwany wynik: TcpTestSucceeded: True
```

---

## 6. Sprawdzenie czy AMT widzi nowy DNS suffix

> [!IMPORTANT]
> To kluczowy krok! AMT provisioning w trybie ACM wymaga, aby DNS suffix widziany przez AMT zgadzał się z certyfikatem provisioning i konfiguracją EMA. Jeśli AMT nadal widzi `domena.pl`, provisioning nie zadziała.

### 6.1. Sprawdzenie DNS suffix przez konfigurację sieciową OS

```powershell
# Primary DNS Suffix — to jest wartość, którą AMT pobiera z OS
Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" | 
    Select-Object Domain, "NV Domain", SearchList

# Oczekiwany wynik:
# Domain    : spi.lab
# NV Domain : spi.lab
```

```powershell
# Connection-specific DNS suffix na interfejsie Ethernet
Get-DnsClient | Where-Object InterfaceAlias -like "*Ethernet*" | 
    Select-Object InterfaceAlias, ConnectionSpecificSuffix, UseSuffixWhenRegistering
```

### 6.2. Weryfikacja w konsoli EMA

1. Otwórz konsolę EMA: `https://ema-srv.spi.lab/ema`
2. Przejdź do sekcji **Endpoints**
3. Znajdź stację po nazwie komputera
4. Sprawdź kolumnę **DNS Suffix** — powinna pokazywać `spi.lab`
5. Sprawdź kolumnę **AMT Status** — jeśli stacja ma EMA Agenta, status powinien się zaktualizować

**Oczekiwany widok na ekranie**: Lista endpointów z kolumnami: Computer Name, IP Address, DNS Suffix, AMT Status, Last Check-in. Przy Twojej stacji DNS Suffix powinien być `spi.lab`.

> [!NOTE]
> Aktualizacja DNS suffix w EMA może zająć kilka minut — EMA Agent raportuje dane przy następnym check-in. Możesz wymusić check-in restartem usługi agenta: `Restart-Service "Intel EMA Agent"`.

### 6.3. Sprawdzenie w MEBx (BIOS AMT)

Jeśli masz fizyczny dostęp do stacji:

1. Zrestartuj stację
2. Podczas POST naciśnij **Ctrl+P** aby wejść do MEBx
3. Zaloguj się hasłem AMT (domyślne: `admin` — jeśli nie było zmieniane)
4. Przejdź do: **Intel(R) AMT Configuration** → **Network Setup** → **Intel(R) ME Network Name Settings**
5. Sprawdź pole **Domain Name** — powinno pokazywać `spi.lab`

**Oczekiwany widok na ekranie**: Ekran tekstowy MEBx z menu. W sekcji Network Name Settings pole „Domain Name" powinno mieć wartość `spi.lab`.

> [!TIP]
> AMT firmware pobiera DNS suffix z DHCP (opcja 15) lub z konfiguracji OS. Jeśli DHCP nie przekazuje opcji 15 z `spi.lab`, AMT może nie widzieć poprawnego suffixu. Sprawdź konfigurację DHCP:
> ```powershell
> # Na serwerze DHCP — sprawdź opcję 15 (DNS Domain Name)
> Get-DhcpServerv4OptionValue -ScopeId 192.168.1.0 | Where-Object OptionId -eq 15
> ```

### 6.4. Wymuszenie aktualizacji DNS suffix w AMT

Jeśli AMT nie zaktualizował DNS suffix automatycznie:

```powershell
# Restart usługi Intel Management Engine
Restart-Service "Intel(R) Management and Security Application Local Management Service" -Force -ErrorAction SilentlyContinue

# Alternatywa — restart LMS
Get-Service *LMS* | Restart-Service -Force
Get-Service *Intel*Management* | Restart-Service -Force
```

> [!NOTE]
> Po restarcie usługi LMS, AMT powinien pobrać aktualny DNS suffix z konfiguracji sieciowej OS. Proces może zająć 1-2 minuty.

---

## 7. Typowe problemy i rozwiązania

### 7.1. Profil użytkownika nie załadował się po join

**Objaw**: Po join do `spi.lab` i zalogowaniu kontem domenowym `spi.lab\jan.kowalski`, system tworzy nowy, pusty profil zamiast użyć starego.

**Przyczyna**: Profile domenowe są powiązane z SID konta w starej domenie. Konto w nowej domenie ma inny SID.

**Rozwiązanie**:

```powershell
# 1. Znajdź SID starego profilu
$staryProfil = Get-CimInstance Win32_UserProfile | 
    Where-Object { $_.LocalPath -like "*jan.kowalski*" -and $_.Loaded -eq $false }
$staryProfil | Select-Object LocalPath, SID

# 2. Skopiuj dane ze starego profilu do nowego
$staryPath = "C:\Users\jan.kowalski.DOMENA"   # <-- stary profil
$nowyPath  = "C:\Users\jan.kowalski"              # <-- nowy profil (spi.lab)

# Kopiuj Desktop, Documents, itp.
$foldery = @("Desktop", "Documents", "Downloads", "Pictures", "Favorites")
foreach ($f in $foldery) {
    if (Test-Path "$staryPath\$f") {
        Copy-Item "$staryPath\$f\*" "$nowyPath\$f\" -Recurse -Force
    }
}
```

> [!TIP]
> Narzędzia takie jak **User Profile Wizard** (ForensIT) lub **ProfWiz** pozwalają na automatyczną migrację profili między domenami, zachowując uprawnienia i ustawienia.

---

### 7.2. Brak dostępu do zasobów sieciowych

**Objaw**: Po join do `spi.lab` brak dostępu do udziałów sieciowych, drukarek, aplikacji powiązanych z `domena.pl`.

**Przyczyna**: Stacja nie jest już członkiem domeny `domena.pl` i nie ma tokenu Kerberos dla tej domeny.

**Rozwiązanie**:
- Zasoby w `domena.pl` — wymagają trustu między domenami lub dostępu po IP z kontem lokalnym
- Zasoby w `spi.lab` — powinny być dostępne natychmiast po poprawnym join

```powershell
# Wyczyść cache biletów Kerberos
klist purge

# Sprawdź aktualny bilet Kerberos
klist
```

---

### 7.3. DNS suffix nie zmienił się na `spi.lab`

**Objaw**: `ipconfig /all` nadal pokazuje `domena.pl` jako Primary DNS Suffix lub DNS suffix jest pusty.

**Przyczyna**: Rejestr nie zaktualizował się poprawnie lub GPO z `domena.pl` nadal jest cache'owane.

**Rozwiązanie**:

```powershell
# Sprawdź rejestr
Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" | 
    Select-Object Domain, "NV Domain"

# Jeśli Domain to nie spi.lab — wymuś
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "Domain" -Value "spi.lab"
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "NV Domain" -Value "spi.lab"

# Wyczyść cache DNS
Clear-DnsClientCache

# Zrestartuj stację
Restart-Computer
```

> [!WARNING]
> Ręczna zmiana rejestru powinna być ostatecznością. Jeśli join do domeny nie ustawił automatycznie DNS suffix, sprawdź czy stacja poprawnie resolwuje DC `spi.lab` i czy join w ogóle się powiódł (`Test-ComputerSecureChannel`).

---

### 7.4. Konto komputera już istnieje w `spi.lab`

**Objaw**: Przy join pojawia się błąd: _„The account already exists"_ lub _„Access is denied"_.

**Przyczyna**: Konto komputera o tej samej nazwie już istnieje w AD `spi.lab` (np. z wcześniejszej próby join).

**Rozwiązanie**:

```powershell
# Na kontrolerze domeny spi.lab — usuń stare konto komputera
# (uruchom jako Domain Admin na DC)
Remove-ADComputer -Identity "NAZWA-STACJI" -Confirm:$false

# Alternatywa — zresetuj konto komputera zamiast usuwać
Reset-ComputerMachinePassword -Server "dc.spi.lab" -Credential (Get-Credential)
```

Następnie ponów join na stacji roboczej.

---

### 7.5. Trust relationship broken (relacja zaufania zerwana)

**Objaw**: Po zalogowaniu pojawia się komunikat: _„The trust relationship between this workstation and the primary domain failed"_.

**Przyczyna**: Hasło konta komputera w AD nie zgadza się z lokalnym hasłem przechowywanym na stacji.

**Rozwiązanie**:

```powershell
# Zaloguj się kontem LOKALNEGO administratora (.\Administrator)

# Metoda 1: Reset relacji zaufania
Test-ComputerSecureChannel -Repair -Credential (Get-Credential -Message "Domain Admin spi.lab")

# Metoda 2: Jeśli metoda 1 nie pomoże — unjoin + join
Remove-Computer -WorkgroupName "WORKGROUP" -Force
Restart-Computer
# Po restarcie: Add-Computer -DomainName "spi.lab" -Credential (Get-Credential) -Restart
```

---

### 7.6. GPO nie aplikuje się po join

**Objaw**: `gpresult /r` nie pokazuje żadnych polityk GPO z `spi.lab` lub pokazuje stare polityki.

**Przyczyna**: Cache GPO z `domena.pl` nadal obecny, lub konto komputera jest w domyślnym kontenerze Computers (poza OU z GPO).

**Rozwiązanie**:

```powershell
# 1. Wymuś odświeżenie GPO
gpupdate /force /boot

# 2. Wyczyść cache GPO
Remove-Item "$env:windir\System32\GroupPolicy\Machine\Registry.pol" -Force -ErrorAction SilentlyContinue
Remove-Item "$env:windir\System32\GroupPolicy\User\Registry.pol" -Force -ErrorAction SilentlyContinue

# 3. Zrestartuj stację
Restart-Computer

# 4. Sprawdź czy komputer jest w odpowiednim OU
# (na DC spi.lab)
Get-ADComputer "NAZWA-STACJI" | Select-Object DistinguishedName
```

> [!TIP]
> Jeśli komputer jest w `CN=Computers,DC=spi,DC=lab`, przenieś go do właściwego OU, na który aplikują się GPO:
> ```powershell
> # Na DC spi.lab
> Move-ADObject -Identity "CN=NAZWA-STACJI,CN=Computers,DC=spi,DC=lab" `
>               -TargetPath "OU=Workstations,DC=spi,DC=lab"
> ```

---

### 7.7. AMT DNS suffix nadal pokazuje `domena.pl`

**Objaw**: W MEBx lub EMA Console DNS suffix stacji to nadal `domena.pl` mimo poprawnego join do `spi.lab`.

**Przyczyna**: AMT cache'uje DNS suffix i nie zawsze odświeża go automatycznie.

**Rozwiązanie**:

1. Sprawdź opcję 15 na serwerze DHCP (Domain Name) — powinna być `spi.lab`
2. Odśwież lease DHCP na stacji:
   ```powershell
   ipconfig /release
   ipconfig /renew
   ```
3. Zrestartuj usługę LMS:
   ```powershell
   Get-Service *LMS* | Restart-Service -Force
   ```
4. Jeśli nadal nie pomoże — wejdź w MEBx (Ctrl+P) i ręcznie ustaw Domain Name na `spi.lab`
5. Zrestartuj stację

> [!IMPORTANT]
> Jeśli AMT firmware nie aktualizuje DNS suffix mimo poprawnej konfiguracji OS i DHCP, może to być problem z konkretną wersją firmware. AMT firmware 12 ma znane problemy z automatyczną aktualizacją DNS suffix w niektórych konfiguracjach. Rozważ ręczne ustawienie w MEBx.

---

> [!NOTE]
> **Kolejny krok**: Po pomyślnym przeniesieniu stacji do `spi.lab` i potwierdzeniu, że AMT widzi poprawny DNS suffix, przejdź do [02 — Czysta instalacja EMA](02-czysta-instalacja-ema.md), a następnie do [03 — Konfiguracja profilu ACM](03-konfiguracja-profilu-acm.md).

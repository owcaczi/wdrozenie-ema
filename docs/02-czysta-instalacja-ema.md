# Krok 2: Czysta Instalacja Intel EMA Server

> [!NOTE]
> Zgodnie z ADR-0001, instalujemy Intel EMA od zera na nowej maszynie wirtualnej w domenie `spi.lab`, aby uniknąć problemów z certyfikatami i bazą danych po starej domenie `lab.local`.

## 1. Wymagania Wstępne i Przygotowanie VM

1. Postaw nową maszynę wirtualną z **Windows Server 2022**.
2. Zainstaluj wszystkie dostępne aktualizacje (Windows Update).
3. Dołącz maszynę do domeny **`spi.lab`**.
4. Zaloguj się na VM przy użyciu konta z uprawnieniami Administratora Domeny (lub lokalnego Administratora połączonego z kontem usługi).

## 2. Instalacja Ról i Wymagań (Prerequisites)

Uruchom PowerShell jako administrator i zainstaluj niezbędne role IIS:

```powershell
# Instalacja IIS i niezbędnych modułów
Install-WindowsFeature -Name Web-Server, Web-Mgmt-Tools, Web-Filtering, Web-Windows-Auth, Web-AppInit, Web-WebSockets, NET-Framework-45-ASPNET, Web-Net-Ext45, Web-ISAPI-Ext, Web-ISAPI-Filter, Web-Mgmt-Console -IncludeManagementTools
```

Następnie pobierz i zainstaluj:
1. **.NET 6.0 Hosting Bundle** (lub nowszy wspierany przez pobraną wersję EMA).
2. **SQL Server Express 2019/2022** (wystarczy domyślna instancja `SQLEXPRESS` z uwierzytelnianiem Windows). Wymagane narzędzie: SQL Server Management Studio (SSMS).

> [!TIP]
> Dla 20 stacji SQL Express jest całkowicie wystarczający (limit 10GB bazy danych).

## 3. Uzyskanie Certyfikatu TLS dla Serwera EMA

Zanim zainstalujesz EMA, serwer IIS potrzebuje ważnego certyfikatu TLS/SSL dla domeny `spi.lab` (np. `ema.spi.lab`). Ponieważ mamy własne Root CA (AD CS), użyjemy go do wygenerowania certyfikatu.

1. Na kontrolerze domeny / CA otwórz konsolę `certtmpl.msc` (Szablony certyfikatów).
2. Skopiuj szablon **Serwer sieci Web** (Web Server).
3. W zakładce *Zabezpieczenia* upewnij się, że komputer EMA (np. `EMA-SRV$`) ma uprawnienia do **Rejestracji** (Enroll).
4. Na nowym serwerze EMA otwórz PowerShell i wygeneruj certyfikat (albo użyj konsoli `certlm.msc` → Osobiste → Żądaj nowego certyfikatu):

Upewnij się, że "Subject Alternative Name" (SAN) certyfikatu pasuje do FQDN serwera, po którym będziesz się łączyć (np. `ema.spi.lab`).

## 4. Instalacja Intel EMA

1. Pobierz najnowszą paczkę Intel EMA ze strony Intel.
2. Wypakuj ZIP i uruchom `EMAServerInstaller.exe` (Uruchom jako Administrator).
3. Postępuj zgodnie z instalatorem:
   - **Database Configuration**: Wybierz `(local)\SQLEXPRESS` (lub nazwę instancji), uwierzytelnianie Windows.
   - **Authentication**: Zalecane logowanie zintegrowane z Active Directory.
   - **Certificate**: Wybierz certyfikat wygenerowany w kroku 3 z listy rozwijanej (dla interfejsu Web i Swarm).
   - **Platform Manager**: Pozostaw domyślne ustawienia (Local System).
4. Przeklikaj do końca i poczekaj na zakończenie instalacji (utworzenie baz danych, stron w IIS).

## 5. Konfiguracja Firewalla

Intel EMA wymaga otwarcia określonych portów na zaporze serwera. Otwórz PowerShell (Jako administrator) i wykonaj:

```powershell
# Port do zarządzania w konsoli WEB (HTTPS)
New-NetFirewallRule -DisplayName "Intel EMA Web Console" -Direction Inbound -LocalPort 443 -Protocol TCP -Action Allow

# Port do komunikacji EMA Agent -> EMA Server
New-NetFirewallRule -DisplayName "Intel EMA Agent Communication" -Direction Inbound -LocalPort 9971 -Protocol TCP -Action Allow

# Porty do komunikacji z Intel AMT (CIRA)
New-NetFirewallRule -DisplayName "Intel EMA CIRA 1" -Direction Inbound -LocalPort 16992,16993,16994,16995 -Protocol TCP -Action Allow
New-NetFirewallRule -DisplayName "Intel EMA CIRA 2" -Direction Inbound -LocalPort 4433 -Protocol TCP -Action Allow
```

## 6. Pierwsze Logowanie i Weryfikacja

1. Otwórz przeglądarkę na stacji roboczej (podłączonej do `spi.lab`).
2. Wejdź na adres `https://ema.spi.lab` (podmień na swój FQDN serwera).
3. Zaloguj się na utworzone podczas instalacji konto (lub swoje konto domenowe, jeśli dałeś mu uprawnienia Global Admina).
4. Upewnij się, że w przeglądarce nie ma ostrzeżeń o certyfikacie (kłódka powinna być zamknięta i bezpieczna). Jeśli są ostrzeżenia "mismatch", to instalacja używa złego certyfikatu.

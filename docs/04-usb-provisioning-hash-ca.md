# Krok 4: Provisioning Intel AMT przez klucz USB (Custom Root CA Hash)

> [!IMPORTANT]
> Maszyny w trybie **Admin Control Mode (ACM)** wymagają bezwzględnego uwierzytelnienia. W związku z tym, AMT na stacji bazowej musi zaufać Twojemu Enterprise Root CA. Osiągniemy to generując odpowiedni hash CA i eksportując go do pliku `setup.bin` wgrywanego wprost z nośnika USB do MEBx.

## 1. Eksport Certyfikatu Enterprise Root CA

Najpierw zrzuć publiczny klucz Twojego CA w odpowiednim formacie. Na kontrolerze domeny lub CA:

1. Otwórz konsolę *Urząd Certyfikacji* (`certsrv.msc`).
2. Kliknij prawym na serwer CA -> **Właściwości**.
3. Na zakładce *Ogólne*, w sekcji *Certyfikat urzędu certyfikacji*, wybierz certyfikat i kliknij **Wyświetl certyfikat**.
4. W zakładce *Szczegóły* kliknij **Kopiuj do pliku...**
5. Wyeksportuj w formacie **Certyfikat X.509 szyfrowany binarnie (DER) (*.cer)**.
6. Zapisz jako np. `C:\Temp\spi-root-ca.cer`.

Alternatywnie z PowerShell na serwerze CA:

```powershell
$cert = Get-ChildItem -Path Cert:\LocalMachine\Root | Where-Object Subject -match "spi.lab" | Select-Object -First 1
Export-Certificate -Cert $cert -FilePath "C:\Temp\spi-root-ca.cer" -Type CERT
```

## 2. Przygotowanie pliku "setup.bin" dla USB

Użyjemy wbudowanego w środowisko Intel konfiguratora do wygenerowania hasha CA i przygotowania paczki konfiguracyjnej dla USB. Czasem potrzebujesz narzędzia **Intel AMT Configuration Utility (ACUConfig)**. Narzędzie to można znaleźć w paczce *Intel SCS* lub pobrać ze stron Intela, często instaluje się obok serwera EMA.

1. Uruchom linię komend (jako administrator) w miejscu gdzie jest narzędzie konfigurujące profil AMT (np. Intel ACU Wizard).
2. Celem jest wygenerowanie `setup.bin`. W narzędziu zdefiniuj:
   - **Typ konfiguracji:** USB Provisioning.
   - **Włącz "Remote Configuration / Provisioning".**
   - Wskaż swój plik CA: `C:\Temp\spi-root-ca.cer`.
   - Wskaż domyślne hasło MEBx dla tych stacji: `admin` (Jeśli nie zostało wcześniej zmienione, jeśli zostało, podaj obecne).
   - Wpisz DNS Suffix dla stacji: `spi.lab`.
3. Wygenerowany plik `setup.bin` zapisz na sformatowany nośnik USB.

> [!TIP]
> Pendrive (nośnik USB) musi być w formacie **FAT32** z rozmiarem mniejszym lub równym **32GB**. Plik `setup.bin` bezwzględnie musi leżeć w **głównym folderze pendrive'a** (nie w podfolderach).

## 3. Aplikacja konfiguracji z USB do MEBx

1. Podejdź do maszyny vPro. Musi być ona na wczesnym etapie bootowania lub całkowicie wyłączona.
2. Umieść pendrive w porcie USB (najlepiej portach wprost w płycie głównej, z tyłu obudowy. Gniazda front panel czasem miewają problemy z poprawnym rozpoznaniem we wczesnej fazie).
3. Włącz maszynę.
4. Gdy pojawi się logo producenta (np. Dell, HP, Lenovo) na ekranie powinno po chwili mignąć pytanie o potwierdzenie konfiguracji z pamięci USB. Naciśnij klawisz "Y" (Yes). Czasem ekran może być bardzo nieczytelny i prośba wyświetli się na żółto lub biało na kilka sekund.
5. Proces zajmuje klika do kilkunastu sekund. Jeśli pojawi się monit o hasło, może chodzić o obecne (domyślne `admin`) lub nowo utworzone. Wciśnij OK/Y, nastąpi restart.

## 4. Weryfikacja instalacji hasha na maszynie vPro

Po wgraniu klucza, zalecana weryfikacja czy skrót SHA256 CA znajduje się faktycznie w MEBx.

1. Zrestartuj komputer, naciskając pulsacyjnie skrót **Ctrl+P** podczas bootowania (lub wybierz 'Intel MEBx' z menu pod `F12`/`Enter` u niektórych producentów).
2. Zaloguj się domyślnym hasłem `admin` (lub już nadanym nowym). Hasło wymaga zazwyczaj dużej litery, małej, cyfry i znaku specjalnego (np. `P@ssw0rd1`).
3. Przejdź do **Intel AMT Configuration** -> **Remote Setup and Configuration** -> **TLS PKI** -> **Manage Certificate Hashes**.
4. Wpisz hash Twojego Root CA do weryfikacji lub sprawdź czy istnieje tam już hash dodany z napędu USB (będzie na liście pod inną nazwą niż standardowe hashe komercyjne jak Verisign/Comodo).
5. Zamknij okna wychodząc z zapisem ustawień i pozwól komputerowi na uruchomienie Windowsa.

Możesz też zweryfikować hash po stronie CA/EMA wykonując w powershell komendę:
```powershell
certutil -hashfile "C:\Temp\spi-root-ca.cer" SHA256
```
Hash w `certutil` i w MEBx powinien być identyczny.

> [!WARNING]
> Tylko maszyny z hashem w MEBx zgodnym z Twoim Enterprise Root CA i pasującym do certyfikatu Provisioning w Intel EMA przejdą w pełni w tryb ACM bez błędu i bez zawieszenia na statusie "Pending".

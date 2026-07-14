# Krok 6: Troubleshooting

> [!WARNING]
> Ten dokument koncentruje się na typowych problemach, z naciskiem na scenariusz, gdy stacja zawisa na etapie "Pending" i nie chce przejść na pełny tryb AMC po wgraniu hasha i zainstalowaniu agenta.

## 1. Problem główny: Provisioning wisi na "Pending" (Zablokowane AMC)

To jest najczęstszy przypadek błędu we wdrożeniu AMT i z reguły wynika z "mismatchu" w certyfikatach i sufiksach. Gdy agent zawisa na tym procesie, stacja vPro nie ma prawa przejść do ACM. Poniżej check-lista diagnostyczna:

### A) Niezgodność Sufiksu Domeny (DNS Suffix Mismatch)

AMT jest bardzo restrykcyjnie uwrażliwione na Suffix DNS wpisywany podczas generowania pliku Provisioning `setup.bin` oraz Certyfikatu AMT i sufiksu OS serwera. W przypadku naszego wdrożenia mieliśmy domeny testowe `absystems.pl` ze stacją roboczą kontra `spi.lab` dla serwera i wgrany klucz CA dla AD `spi.lab`. 

**Rozwiązanie:** 
- Zgodnie z wytycznymi projektu, upewnij się, że przeniosłeś fizycznie domenę i sufiks Windowsowy stacji roboczej z powrotem do `spi.lab`. Serwer musi posługiwać się również jednym certyfikatem dla tej samej strefy.
- Jeżeli po unjoin/join problem występuje nadal: Odłącz AMT z MEBx (unprovision), wyczyść klucz z MEBx, zrestartuj sprzęt i wgraj nowo stworzony plik USB konfiguracyjny (patrz proces Unprovision niżej).

### B) Błędy z Certyfikatem (Certificate Mismatch / Wrong Template)

1. **Szablon w CA:** Sprawdź czy zduplikowany wczesniej Certyfikat AMT z Twojego Windowsowego AD CS posiada identyfikator dla AMT Provisioningu w OID, czyli numer OID `2.16.840.1.113741.1.2.3` (częsty błąd to skopiowanie OID tylko dla komunikacji SSL `1.3.6.1.5.5.7.3.1`).
2. **Hash nie pasuje:** Z poziomu BIOS/MEBx stacji vPro spisz palcem lub sfotografuj hashe po ich wgraniu USB w Remote Configuration. Na serwerze odpal `certutil -hashfile "c:\root-ca.cer" SHA256`. Pamiętaj, wielkość liter nie ma znaczenia, ciągi muszą się pokrywać jeden do jednego. Jeśli się nie zgadzają - Twój RootCA został wyeksportowany błędnie. Wgrywasz fałszywy klucz i AMT po cichu blokuje połączenie.
3. **Common Name:** CN Twojego certyfikatu wgrywanego do profilu serwera Intel EMA MUSI uwzględniać Suffix, inaczej wisi (jak punkt A). Pokaże też to błąd w przeglądarce jeśli wchodzisz na FQDN EMA a ten zgłosi że jest zainstalowany na starą `lab.local`. 

### C) Brak dostępu w Sieci (Ports blocked by Firewall)

Jeśli stacje są połączone do domeny i nie ma niezgodności, EMA Agent nie "dogada się" ze sprzętem vPro, a EMA serwer nie dokończy operacji z Agentem, jeżeli porty są zablokowane.

Użyj Powershell na stacji ze złą współpracą:
```powershell
Test-NetConnection -ComputerName emaserver.spi.lab -Port 9971
Test-NetConnection -ComputerName emaserver.spi.lab -Port 16992
Test-NetConnection -ComputerName emaserver.spi.lab -Port 16993
```
*Porty 16992 (HTTP) i 16993 (HTTPS) to standardowe komunikacyjne i logiki OOB AMT. Jeżeli w Test-NetConnection wyjdzie False dla `TcpTestSucceeded` - przepuść je przez zapory routerów.*

## 2. Procedura "Clean Slate" (Pełne wyczyszczenie Provisioningu AMT z MEBx)

Jeżeli coś "zawiesiło" się tak mocno, że system nie chce puścić stacji i ciągle widać "CCM" albo "Pending" pomimo poprawek:

1. Wejdź podczas włączania PCta w menu **MEBx** (CTRL+P). 
2. Wejdź w Remote Setup -> wciśnij **Unprovision** / **Full Unprovision**. Przeładuje to układ OOB do ustawień domyślnych fabryki. Od tego momentu skasuje mu się stare hasło admin i stary Hash pendrive. Zrób to ostrożnie!
3. W konsoli EMA, w zakładce endpointów wyrzuć ręcznie ten endpoint na siłę kasując powiązanie. 
4. Przejdź punkt powtórnie: wrzuć mu poprawnie zdefiniowanego nowego Pendrive'a i przejdź Kroki Wdrażania od zera. Agenta na windowsie nie trzeba wycinać (najlepiej tylko uruchomić na nowo jego usługę 'Intel EMA Agent' pod komendą w Services.msc). 

## 3. Lokalizacja ważnych logów

Dla serwera i powiązanych procesów OOB CIRA, najszybciej dojdziesz błędu w:
- Event Viewer Windows Servera z EMA pod aplikacjami w katalogach powiązanych z `Intel EMA`.
- Logach narzędzi firm trzecich z grupy Intela, jak np. **MeshCommander**. Ułatwia on samodzielne, lokalne dogrzebanie się do stacji vPro na wpół-uszkodzonej bez pełnego logowania do panelu webowego by wykluczyć usterki sprzętowe. Pamiętaj by na stacjach pobierać i testować połączenia przez małe narzędzie Intel SCS/ACU i wylistowanie lokalne "Get-Status". Opcja `SystemDiscovery.exe` jest kluczowa!

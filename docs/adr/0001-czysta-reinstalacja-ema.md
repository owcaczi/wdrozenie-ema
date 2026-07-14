# ADR-0001: Czysta reinstalacja EMA Server na nowej VM

## Status
Zaakceptowane

## Kontekst
Serwer EMA został pierwotnie zainstalowany w domenie `lab.local`, a następnie przeniesiony do `spi.lab`. Migracja spowodowała:
- Certyfikat TLS EMA wystawiony na starą nazwę FQDN (`lab.local`) — alerty mismatch w przeglądarce
- Potencjalne rezydualne wpisy w bazie SQL i konfiguracji EMA odwołujące się do `lab.local`
- Provisioning AMT zablokowany na statusie "pending"

## Decyzja
**Reinstalacja EMA od zera na czystej VM** z Windows Server 2022, zamiast naprawiania istniejącej instalacji.

## Uzasadnienie
1. Czysta instalacja eliminuje wszystkie rezydualne dane z `lab.local`
2. Nowy certyfikat TLS zostanie wystawiony poprawnie na FQDN w `spi.lab`
3. Przy 20 stacjach koszt ponownej konfiguracji jest minimalny
4. Próba naprawy migrowanej instalacji jest bardziej ryzykowna i czasochłonna niż fresh install

## Konsekwencje
- Trzeba ponownie skonfigurować profile AMT w EMA
- EMA Agent na stacjach trzeba będzie przekierować na nowy serwer (lub reinstalować)
- Stara VM może zostać wyłączona po weryfikacji nowej

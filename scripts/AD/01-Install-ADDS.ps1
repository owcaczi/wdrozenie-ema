<#
.SYNOPSIS
    Instalacja roli Active Directory Domain Services i promocja do kontrolera domeny.

.DESCRIPTION
    Skrypt instaluje rolę AD DS, promuje serwer do kontrolera domeny w nowym lesie,
    konfiguruje DNS oraz ustawia podstawowe parametry domeny.
    Wszystkie wartości konfiguracyjne są pobierane z pliku deployment-config.psd1.

.PARAMETER ConfigPath
    Ścieżka do pliku konfiguracyjnego wdrożenia (deployment-config.psd1).

.PARAMETER DomainName
    Pełna nazwa domeny (FQDN). Nadpisuje wartość z pliku konfiguracyjnego.

.PARAMETER NetBIOSName
    Nazwa NetBIOS domeny. Nadpisuje wartość z pliku konfiguracyjnego.

.PARAMETER DSRMPassword
    Hasło do trybu przywracania usług katalogowych (DSRM).
    Jeśli nie podano, zostanie wyświetlony monit o podanie hasła.

.EXAMPLE
    .\01-Install-ADDS.ps1 -DSRMPassword (ConvertTo-SecureString 'P@ssw0rd!' -AsPlainText -Force)

.EXAMPLE
    .\01-Install-ADDS.ps1 -DomainName 'firma.local' -NetBIOSName 'FIRMA'

.NOTES
    Autor:  Administrator
    Wersja: 1.0
    Data:   2026-07-14
    Wymagania: Windows Server 2016+, uprawnienia administratora
#>

#Requires -RunAsAdministrator
#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory = $false)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$ConfigPath = (Join-Path $PSScriptRoot '..\..\config\deployment-config.psd1'),

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^[a-zA-Z0-9]+(\.[a-zA-Z0-9]+)+$')]
    [string]$DomainName,

    [Parameter(Mandatory = $false)]
    [ValidateLength(1, 15)]
    [string]$NetBIOSName,

    [Parameter(Mandatory = $false)]
    [SecureString]$DSRMPassword
)

# ============================================================================
# Region: Funkcje pomocnicze
# ============================================================================

function Write-Log {
    <#
    .SYNOPSIS
        Zapisuje wpis do pliku logu oraz wyświetla komunikat na konsoli.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet('INFO', 'WARNING', 'ERROR', 'SUCCESS')]
        [string]$Level = 'INFO'
    )

    # Znacznik czasu w formacie ISO 8601
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry = "[$timestamp] [$Level] $Message"

    # Zapis do pliku logu
    if ($script:LogFile) {
        Add-Content -Path $script:LogFile -Value $logEntry -Encoding UTF8
    }

    # Wyświetlenie na konsoli z odpowiednim kolorem
    switch ($Level) {
        'INFO'    { Write-Host $logEntry -ForegroundColor Cyan }
        'WARNING' { Write-Host $logEntry -ForegroundColor Yellow }
        'ERROR'   { Write-Host $logEntry -ForegroundColor Red }
        'SUCCESS' { Write-Host $logEntry -ForegroundColor Green }
    }
}

function Test-Prerequisites {
    <#
    .SYNOPSIS
        Sprawdza wymagania wstępne przed instalacją AD DS.
    #>
    [CmdletBinding()]
    param()

    Write-Log -Message 'Sprawdzanie wymagań wstępnych...' -Level INFO

    # Sprawdzenie systemu operacyjnego - musi być Windows Server
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    if ($os.ProductType -ne 3) {
        Write-Log -Message 'Ten skrypt wymaga systemu Windows Server. Wykryto stację roboczą.' -Level ERROR
        return $false
    }
    Write-Log -Message "System operacyjny: $($os.Caption) - OK" -Level SUCCESS

    # Sprawdzenie, czy serwer nie jest już kontrolerem domeny
    try {
        $domainRole = (Get-CimInstance -ClassName Win32_ComputerSystem).DomainRole
        if ($domainRole -ge 4) {
            Write-Log -Message 'Serwer jest już kontrolerem domeny. Instalacja nie jest wymagana.' -Level WARNING
            return $false
        }
        Write-Log -Message 'Serwer nie jest kontrolerem domeny - można kontynuować.' -Level SUCCESS
    }
    catch {
        Write-Log -Message "Błąd podczas sprawdzania roli domeny: $_" -Level WARNING
    }

    # Sprawdzenie dostępnej pamięci RAM (minimum 2 GB)
    $ramGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    if ($ramGB -lt 2) {
        Write-Log -Message "Niewystarczająca ilość pamięci RAM: ${ramGB} GB. Wymagane minimum 2 GB." -Level ERROR
        return $false
    }
    Write-Log -Message "Pamięć RAM: ${ramGB} GB - OK" -Level SUCCESS

    # Sprawdzenie wolnego miejsca na dysku C: (minimum 10 GB)
    $disk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='C:'"
    $freeGB = [math]::Round($disk.FreeSpace / 1GB, 2)
    if ($freeGB -lt 10) {
        Write-Log -Message "Niewystarczające miejsce na dysku C: ${freeGB} GB. Wymagane minimum 10 GB." -Level ERROR
        return $false
    }
    Write-Log -Message "Wolne miejsce na dysku C: ${freeGB} GB - OK" -Level SUCCESS

    # Sprawdzenie, czy adres IP jest statyczny
    $adapter = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1
    if ($adapter) {
        $ipConfig = Get-NetIPConfiguration -InterfaceIndex $adapter.ifIndex
        $dhcpEnabled = (Get-NetIPInterface -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4).Dhcp
        if ($dhcpEnabled -eq 'Enabled') {
            Write-Log -Message 'UWAGA: Karta sieciowa używa DHCP. Kontroler domeny powinien mieć statyczny adres IP.' -Level WARNING
        }
        else {
            Write-Log -Message 'Karta sieciowa ma statyczny adres IP - OK' -Level SUCCESS
        }
    }

    return $true
}

# ============================================================================
# Region: Główna logika skryptu
# ============================================================================

try {
    # --- Inicjalizacja logowania ---
    $config = Import-PowerShellDataFile -Path $ConfigPath
    $logDir = $config.Logging.LogDirectory
    if (-not (Test-Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }
    $script:LogFile = Join-Path $logDir "01-Install-ADDS_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

    Write-Log -Message '============================================================' -Level INFO
    Write-Log -Message 'Rozpoczęcie instalacji Active Directory Domain Services' -Level INFO
    Write-Log -Message '============================================================' -Level INFO

    # --- Wczytanie konfiguracji ---
    Write-Log -Message "Wczytywanie konfiguracji z: $ConfigPath" -Level INFO

    # Zastosowanie wartości z pliku konfiguracyjnego (parametry wiersza poleceń mają priorytet)
    if (-not $DomainName) {
        $DomainName = $config.Domain.Name
    }
    if (-not $NetBIOSName) {
        $NetBIOSName = $config.Domain.NetBIOSName
    }

    Write-Log -Message "Nazwa domeny: $DomainName" -Level INFO
    Write-Log -Message "Nazwa NetBIOS: $NetBIOSName" -Level INFO

    # --- Sprawdzenie wymagań wstępnych ---
    if (-not (Test-Prerequisites)) {
        Write-Log -Message 'Wymagania wstępne nie zostały spełnione. Przerywanie.' -Level ERROR
        exit 1
    }

    # --- Prośba o hasło DSRM, jeśli nie podano ---
    if (-not $DSRMPassword) {
        Write-Log -Message 'Hasło DSRM nie zostało podane jako parametr. Wyświetlanie monitu.' -Level INFO
        $DSRMPassword = Read-Host -Prompt 'Podaj hasło trybu przywracania usług katalogowych (DSRM)' -AsSecureString
    }

    # Walidacja siły hasła DSRM
    $dsrmPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($DSRMPassword)
    )
    if ($dsrmPlain.Length -lt 8) {
        Write-Log -Message 'Hasło DSRM musi mieć co najmniej 8 znaków.' -Level ERROR
        exit 1
    }
    # Czyszczenie hasła z pamięci
    $dsrmPlain = $null

    # --- Potwierdzenie operacji przez użytkownika ---
    if ($PSCmdlet.ShouldProcess("Serwer $env:COMPUTERNAME", "Instalacja AD DS i promocja do kontrolera domeny '$DomainName'")) {

        # --- Krok 1: Instalacja roli AD DS ---
        Write-Log -Message 'Krok 1: Instalacja roli Active Directory Domain Services...' -Level INFO

        $installResult = Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools -IncludeAllSubFeature -ErrorAction Stop

        if ($installResult.Success) {
            Write-Log -Message 'Rola AD DS zainstalowana pomyślnie.' -Level SUCCESS
        }
        else {
            Write-Log -Message 'Instalacja roli AD DS nie powiodła się.' -Level ERROR
            Write-Log -Message "Szczegóły: $($installResult.ExitCode)" -Level ERROR
            exit 1
        }

        # --- Krok 2: Instalacja roli DNS ---
        Write-Log -Message 'Krok 2: Instalacja roli DNS Server...' -Level INFO

        $dnsResult = Install-WindowsFeature -Name DNS -IncludeManagementTools -ErrorAction Stop

        if ($dnsResult.Success) {
            Write-Log -Message 'Rola DNS zainstalowana pomyślnie.' -Level SUCCESS
        }
        else {
            Write-Log -Message 'Instalacja roli DNS nie powiodła się.' -Level ERROR
            exit 1
        }

        # --- Krok 3: Import modułu ADDSDeployment ---
        Write-Log -Message 'Krok 3: Import modułu ADDSDeployment...' -Level INFO
        Import-Module ADDSDeployment -ErrorAction Stop
        Write-Log -Message 'Moduł ADDSDeployment zaimportowany pomyślnie.' -Level SUCCESS

        # --- Krok 4: Testowanie konfiguracji przed promocją ---
        Write-Log -Message 'Krok 4: Testowanie konfiguracji przed promocją kontrolera domeny...' -Level INFO

        $testParams = @{
            DomainName                    = $DomainName
            DomainNetbiosName             = $NetBIOSName
            ForestMode                    = $config.Domain.ForestMode
            DomainMode                    = $config.Domain.DomainMode
            DatabasePath                  = $config.Domain.DatabasePath
            LogPath                       = $config.Domain.LogPath
            SysvolPath                    = $config.Domain.SysvolPath
            SafeModeAdministratorPassword = $DSRMPassword
            InstallDns                    = $true
            CreateDnsDelegation           = $false
            NoRebootOnCompletion          = $true
            Force                         = $true
        }

        $testResult = Test-ADDSForestInstallation @testParams -ErrorAction Stop

        if ($testResult.Status -eq 'Error') {
            Write-Log -Message 'Test konfiguracji lasu zakończony błędem.' -Level ERROR
            foreach ($msg in $testResult.Message) {
                Write-Log -Message "  -> $msg" -Level ERROR
            }
            exit 1
        }
        Write-Log -Message 'Test konfiguracji lasu zakończony pomyślnie.' -Level SUCCESS

        # --- Krok 5: Promocja do kontrolera domeny (nowy las) ---
        Write-Log -Message 'Krok 5: Promocja serwera do kontrolera domeny w nowym lesie...' -Level INFO
        Write-Log -Message 'UWAGA: Po promocji serwer zostanie automatycznie uruchomiony ponownie!' -Level WARNING

        $promoteParams = @{
            DomainName                    = $DomainName
            DomainNetbiosName             = $NetBIOSName
            ForestMode                    = $config.Domain.ForestMode
            DomainMode                    = $config.Domain.DomainMode
            DatabasePath                  = $config.Domain.DatabasePath
            LogPath                       = $config.Domain.LogPath
            SysvolPath                    = $config.Domain.SysvolPath
            SafeModeAdministratorPassword = $DSRMPassword
            InstallDns                    = $true
            CreateDnsDelegation           = $false
            NoRebootOnCompletion          = $false
            Force                         = $true
        }

        Install-ADDSForest @promoteParams -ErrorAction Stop

        Write-Log -Message 'Promocja do kontrolera domeny zakończona pomyślnie. Serwer zostanie uruchomiony ponownie.' -Level SUCCESS
    }
    else {
        Write-Log -Message 'Operacja anulowana przez użytkownika.' -Level WARNING
    }
}
catch {
    Write-Log -Message "Wystąpił krytyczny błąd: $($_.Exception.Message)" -Level ERROR
    Write-Log -Message "Szczegóły: $($_.ScriptStackTrace)" -Level ERROR
    exit 1
}
finally {
    Write-Log -Message '============================================================' -Level INFO
    Write-Log -Message 'Zakończenie skryptu instalacji AD DS' -Level INFO
    Write-Log -Message "Plik logu: $($script:LogFile)" -Level INFO
    Write-Log -Message '============================================================' -Level INFO
}

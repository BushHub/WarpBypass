<# : RUN
@echo off
title WarpBypass v4.7.1 by BUSH
cd /d "%~dp0"
net session >nul 2>&1
if %errorLevel% neq 0 (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)
set "WARP_BAT_PATH=%~f0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-Command -ScriptBlock ([ScriptBlock]::Create((Get-Content -LiteralPath '%~f0' -Encoding UTF8 -Raw)))"
exit /b
#>

$ProgressPreference = 'SilentlyContinue'
$WarningPreference = 'SilentlyContinue'

# =========================================================
# WarpBypass
# Author: BUSH
# =========================================================

$AppVersion = "4.7.1"
$RepoApiUrl = "https://api.github.com/repos/BushHub/WarpBypass/releases/latest"

# Disable console Quick-Edit mode
try {
    if (-not ("Win32.Win32Console" -as [type])) {
        $ConsoleCode = @'
        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern IntPtr GetStdHandle(int nStdHandle);
        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);
        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);
'@
        Add-Type -MemberDefinition $ConsoleCode -Name "Win32Console" -Namespace "Win32" -ErrorAction SilentlyContinue *> $null
    }
    $StdInputHandle = [Win32.Win32Console]::GetStdHandle(-10)
    $ConsoleMode = 0
    if ([Win32.Win32Console]::GetConsoleMode($StdInputHandle, [ref]$ConsoleMode)) {
        [Win32.Win32Console]::SetConsoleMode($StdInputHandle, ($ConsoleMode -band -not 0x0040)) | Out-Null
    }
} catch {}


function Get-WarpStatus {
    if (Test-Path $WarpCli) {
        $Status = & $WarpCli --accept-tos status 2>$null | Out-String
        if ($Status -match "Status update:\s*(\w+)") {
            return $Matches[1]
        }
    }
    return "Disconnected"
}

function Get-CachedWarpStatus {
    $Now = [DateTime]::Now
    if ($null -eq $global:CachedWarpStatus -or $null -eq $global:LastStatusCheck -or ($Now - $global:LastStatusCheck).TotalSeconds -ge 2) {
        $global:CachedWarpStatus = Get-WarpStatus
        $global:LastStatusCheck = $Now
    }
    return $global:CachedWarpStatus
}

$StorageDir = "$env:LOCALAPPDATA\WarpBypass"
if (-not (Test-Path $StorageDir)) { New-Item -ItemType Directory -Path $StorageDir -Force -ErrorAction SilentlyContinue *> $null }

$ZapretDir = "$StorageDir\zapret"
$ZapretZip = "$StorageDir\zapret.zip"
$ZapretUrl = "https://github.com/Flowseal/zapret-discord-youtube/archive/refs/heads/main.zip"
$WarpCli = "C:\Program Files\Cloudflare\Cloudflare WARP\warp-cli.exe"

$ConfigPath = "$StorageDir\config.json"
$PingListPath = "$StorageDir\ping_list.txt"

Clear-Host

$DefaultConfig = @{ AutoPreset = $false; LastPreset = ""; AutoPresetTimeout = 3; AutoPing = 1; DnsFix = $false; IgnoredVersion = "0.0"; AutoUpdate = $true; AutoKillConflicts = $false; PingInterval = 30 }

$FirstRun = -not (Test-Path $ConfigPath)
if (-not $FirstRun) {
    try { 
        $Config = Get-Content $ConfigPath -Raw | ConvertFrom-Json 
        foreach ($Key in $DefaultConfig.Keys) {
            if (-not (Get-Member -InputObject $Config -Name $Key)) {
                Add-Member -InputObject $Config -NotePropertyName $Key -NotePropertyValue $DefaultConfig[$Key]
            }
        }
        
        if ($Config.AutoPing -eq $true) { $Config.AutoPing = 1 }
        elseif ($Config.AutoPing -eq $false) { $Config.AutoPing = 0 }
    } catch { 
        $Config = New-Object PSObject -Property $DefaultConfig 
    }
} else {
    $Config = New-Object PSObject -Property $DefaultConfig
}

# Disable WARP GUI client auto-start to prevent boot-time connection loops blocking internet
try {
    foreach ($Hive in @("HKLM", "HKCU")) {
        $RegPath = "$Hive`:\Software\Microsoft\Windows\CurrentVersion\Run"
        foreach ($KeyName in @("CloudflareWARP", "Cloudflare WARP")) {
            if (Get-ItemProperty -Path $RegPath -Name $KeyName -ErrorAction SilentlyContinue) {
                Remove-ItemProperty -Path $RegPath -Name $KeyName -Force -ErrorAction SilentlyContinue *> $null
            }
        }
    }
} catch {}

if (-not (Test-Path $PingListPath)) {
    "discord.com`nyoutube.com`ngoogle.com" | Set-Content $PingListPath -Encoding UTF8
}

function Save-Config { $Config | ConvertTo-Json | Set-Content $ConfigPath }

$LogoText = @'
 _    _                    _                               
| |  | |                  | |                              
| |  | | __ _ _ __ _ __   | |__  _   _ _ __   __ _ ___ ___ 
| |/\| |/ _` | '__| '_ \  | '_ \| | | | '_ \ / _` / __/ __|
\  /\  / (_| | |  | |_) | | |_) | |_| | |_) | (_| \__ \__ \
 \/  \/ \__,_|_|  | .__/  |_.__/ \__, | .__/ \__,_|___/___/
                  | |             __/ | |                  
                  |_|            |___/|_|                  
'@

function Write-Header {
    Write-Host "=========================================================" -ForegroundColor Magenta
    Write-Host $LogoText -ForegroundColor Magenta
    Write-Host "=========================================================" -ForegroundColor Magenta
}

function Start-SetupWizard {
    Clear-Host
    Write-Header
    Write-Host "         ДОБРО ПОЖАЛОВАТЬ В МАСТЕР НАСТРОЙКИ v$AppVersion" -ForegroundColor Cyan
    Write-Host "=========================================================" -ForegroundColor DarkGray
    Write-Host " Приветствуем! WarpBypass поможет обойти блокировки сайтов" -ForegroundColor Gray
    Write-Host " (YouTube, Discord и др.) через Cloudflare WARP и zapret." -ForegroundColor Gray
    Write-Host " Давайте настроим утилиту под ваши предпочтения за 2 шага." -ForegroundColor Gray
    Write-Host "=========================================================" -ForegroundColor DarkGray
    Write-Host ""
    
    # Шаг 1: Базовые настройки
    Write-Host " [Шаг 1 из 2] Базовые настройки системы:" -ForegroundColor White
    $DnsFixChoice = Read-Host " 1. Очищать кэш DNS при каждом запуске? (Y/N) [Рекомендуется: Y]"
    if ($DnsFixChoice -match "^[NnНн]") { $Config.DnsFix = $false } else { $Config.DnsFix = $true }
    
    $UpdateChoice = Read-Host " 2. Включить автоматическое обновление батника и zapret? (Y/N) [Рекомендуется: Y]"
    if ($UpdateChoice -match "^[NnНн]") { $Config.AutoUpdate = $false } else { $Config.AutoUpdate = $true }
    
    # Шаг 2: Стратегия обхода
    Clear-Host
    Write-Header
    Write-Host "                 СТРАТЕГИЯ ОБХОДА" -ForegroundColor Cyan
    Write-Host "=========================================================" -ForegroundColor DarkGray
    Write-Host " Для работы необходимо выбрать пресет обхода блокировок." -ForegroundColor Gray
    Write-Host " У разных провайдеров работают разные пресеты." -ForegroundColor Gray
    Write-Host ""
    Write-Host " Выберите действие:" -ForegroundColor White
    Write-Host "   1. Использовать стандартный пресет (general ALT12)" -ForegroundColor Green
    Write-Host "      (Наиболее универсальный вариант, работает у многих)"
    Write-Host "   2. Выбрать вручную позже в главном меню" -ForegroundColor Gray
    Write-Host ""
    
    $PresetChoice = ""
    while ($PresetChoice -notmatch "^[12]$") {
        $PresetChoice = Read-Host " Выберите вариант (1-2)"
    }
    
    if ($PresetChoice -eq "1") {
        $Config.LastPreset = "$ZapretDir\general (ALT12).bat"
        $Config.AutoPreset = $true
    }
    
    Save-Config
    
    Write-Host "`n Первоначальная настройка успешно завершена!" -ForegroundColor Green
    Write-Host " Конфигурация сохранена в AppData\Local\WarpBypass\config.json" -ForegroundColor Gray
    Write-Host " Нажмите любую клавишу для продолжения..." -ForegroundColor White
    [console]::ReadKey($true) | Out-Null
}

$IsOnline = $false
try {
    $p = New-Object System.Net.NetworkInformation.Ping
    $res = $p.Send("8.8.8.8", 1500)
    if ($res.Status -eq "Success") { $IsOnline = $true }
} catch { }

function Check-AppUpdate {
    if (-not $IsOnline) { return }
    Write-Host "-> Проверка обновлений WarpBypass..." -ForegroundColor Gray
    
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
        $ReleaseInfo = Invoke-RestMethod -Uri $RepoApiUrl -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop

        $RemoteVersionStr = $ReleaseInfo.tag_name -replace '(?i)^v', ''
        $RemoteVer = [version]$RemoteVersionStr
        $LocalVer  = [version]$AppVersion

        if ($RemoteVer -gt $LocalVer -and $Config.IgnoredVersion -ne $RemoteVersionStr) {
            Write-Host ""
            Write-Host "=========================================================" -ForegroundColor Yellow
            Write-Host " Доступен новый релиз WarpBypass: v$RemoteVersionStr (Текущая: v$AppVersion)" -ForegroundColor Green
            Write-Host "=========================================================" -ForegroundColor Yellow
            $UpdateChoice = Read-Host "Инициировать процесс обновления прямо сейчас? (Y/N)"
            
            if ($UpdateChoice -match "^[YyДд]") {
                Write-Host "-> Загрузка и инсталляция пакета обновления..." -ForegroundColor Cyan
                
                $DownloadUrl = "https://raw.githubusercontent.com/BushHub/WarpBypass/$($ReleaseInfo.tag_name)/WarpBypass.bat"
                $BatPath = $env:WARP_BAT_PATH
                $TempFile = "$env:TEMP\WarpBypass_new.bat"
                $UpdaterBat = "$env:TEMP\WarpBypass_updater.bat"
                
                # BOM FIX: Download the file directly to preserve encoding
                Invoke-WebRequest -Uri $DownloadUrl -OutFile $TempFile -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
                
                $UpdaterCode = "@echo off`nchcp 65001 >nul`ntimeout /t 2 /nobreak >nul`nmove /y `"$TempFile`" `"$BatPath`" >nul`nstart `"`" `"$BatPath`"`ndel `"%~f0`""
                [IO.File]::WriteAllText($UpdaterBat, $UpdaterCode, [System.Text.Encoding]::UTF8)
                
                Start-Process -FilePath $UpdaterBat -WindowStyle Hidden
                Exit
            } else {
                $IgnoreChoice = Read-Host "Игнорировать версию $RemoteVersionStr при последующих проверках? (Y/N)"
                if ($IgnoreChoice -match "^[YyДд]") {
                    $Config.IgnoredVersion = $RemoteVersionStr
                    Save-Config
                    Write-Host "-> Версия $RemoteVersionStr внесена в список исключений." -ForegroundColor DarkGray
                    Start-Sleep -Seconds 1
                }
            }
        }
    } catch {
        Write-Host "-> Ошибка синхронизации с GitHub API. Сервер недоступен." -ForegroundColor DarkGray
        Start-Sleep -Seconds 1
    }
}

function Check-Updates {
    if (-not $IsOnline) {
        Write-Host "-> Сетевое подключение отсутствует. Оффлайн режим." -ForegroundColor DarkGray
        return
    }
    
    $WinwsPath = if (Test-Path $ZapretDir) { (Get-ChildItem -Path $ZapretDir -Filter winws.exe -Recurse | Select-Object -First 1).FullName } else { "" }
    $RepoAPI = "https://api.github.com/repos/Flowseal/zapret-discord-youtube/commits/main"
    $VersionFile = "$StorageDir\zapret_version.txt"
    $LastCheckFile = "$StorageDir\last_check.txt"
    
    $NeedUpdate = -not $WinwsPath
    if ($WinwsPath) {
        $Today = Get-Date
        $LastCheck = $null
        if (Test-Path $LastCheckFile) {
            try { $LastCheck = [DateTime]::Parse((Get-Content $LastCheckFile -Raw).Trim()) } catch { }
        }
        if (-not $LastCheck -or ($Today - $LastCheck).TotalDays -ge 3) {
            Write-Host "-> Аудит зависимостей маскировки трафика..." -ForegroundColor Gray
            try {
                $UpdateInfo = Invoke-RestMethod -Uri $RepoAPI -UseBasicParsing -UserAgent "WarpBypass" -TimeoutSec 5 -ErrorAction Stop
                $global:LatestSHA = $UpdateInfo.sha
                Out-File -FilePath $LastCheckFile -InputObject ($Today.ToString()) -Force
                $LocalSHA = if (Test-Path $VersionFile) { (Get-Content $VersionFile).Trim() } else { "" }
                if ($LocalSHA -ne $global:LatestSHA) { $NeedUpdate = $true }
            } catch { Write-Host "-> Ошибка проверки зависимостей. Используется локальный кэш." -ForegroundColor DarkGray }
        }
    }
    
    if ($NeedUpdate) {
        # Make sure no running winws is locking files
        try { Stop-Process -Name "winws" -Force -ErrorAction SilentlyContinue *>$null } catch {}
        Start-Sleep -Milliseconds 500
        
        Write-Host "-> Загрузка компонентов маскировки трафика..." -ForegroundColor Yellow
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
        Invoke-WebRequest -Uri $ZapretUrl -OutFile $ZapretZip -UseBasicParsing -UserAgent "WarpBypass" -ErrorAction SilentlyContinue
        if (Test-Path $ZapretZip) {
            if (Test-Path $ZapretDir) { Remove-Item $ZapretDir -Recurse -Force -ErrorAction SilentlyContinue }
            Expand-Archive -Path $ZapretZip -DestinationPath $StorageDir -Force
            $ExtractedDir = Get-ChildItem -Path $StorageDir -Directory | Where-Object { $_.Name -like "zapret-discord-youtube*" } | Select-Object -First 1
            if ($ExtractedDir) {
                if (-not (Test-Path $ZapretDir)) { New-Item -ItemType Directory -Path $ZapretDir -Force | Out-Null }
                Copy-Item -Path "$($ExtractedDir.FullName)\*" -Destination $ZapretDir -Recurse -Force -ErrorAction SilentlyContinue
                Remove-Item $ExtractedDir.FullName -Recurse -Force -ErrorAction SilentlyContinue
            }
            Remove-Item $ZapretZip -ErrorAction SilentlyContinue
            if ($global:LatestSHA) { Out-File -FilePath $VersionFile -InputObject $global:LatestSHA -Force }
        }
    }
}

function Get-ZapretArgs ($BatFile) {
    $GameFilterTCP = "12"
    $GameFilterUDP = "12"
    try {
        $EnvBlock = cmd.exe /c "cd /d `"$ZapretDir`" && call service.bat load_game_filter && call service.bat load_user_lists && set"
        foreach ($Line in $EnvBlock) {
            if ($Line -match "^GameFilterTCP=(.*)$") { $GameFilterTCP = $Matches[1] }
            if ($Line -match "^GameFilterUDP=(.*)$") { $GameFilterUDP = $Matches[1] }
        }
    } catch {}
    
    $BatContent = Get-Content $BatFile -Raw
    $BatContent = $BatContent -replace "\^\r?\n", " "
    $BatContent = $BatContent -replace "\^\n", " "
    
    if ($BatContent -match "(?ms)winws\.exe`"?\s+(.*)$") {
        $ArgsStr = $Matches[1].Trim()
        $ArgsStr = $ArgsStr -replace "%BIN%", "$ZapretDir\bin\"
        $ArgsStr = $ArgsStr -replace "%LISTS%", "$ZapretDir\lists\"
        $ArgsStr = $ArgsStr -replace "%GameFilterTCP%", $GameFilterTCP
        $ArgsStr = $ArgsStr -replace "%GameFilterUDP%", $GameFilterUDP
        $ArgsStr = $ArgsStr -replace "%~dp0", "$ZapretDir\"
        $ArgsStr = $ArgsStr -replace "\r?\n.*$", ""
        return $ArgsStr
    }
    return $null
}

$BypassListBaseUrl = "https://raw.githubusercontent.com/BushHub/WarpBypass/main"
$BypassCacheDir    = "$StorageDir\bypass"

function Get-LocalBypassVersion {
    $vf = "$BypassCacheDir\ru_bypass_version.txt"
    if (Test-Path $vf) { return (Get-Content $vf -Raw).Trim() }
    return $null
}

function Get-RemoteBypassVersion {
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
        $ver = (Invoke-WebRequest -Uri "$BypassListBaseUrl/ru_bypass_version.txt" -UseBasicParsing -TimeoutSec 5).Content -replace '[\s\r\n]',''
        return $ver
    } catch { return $null }
}

function Update-BypassLists {
    param([switch]$Force, [switch]$Silent)
    if (-not (Test-Path $BypassCacheDir)) { New-Item -ItemType Directory -Path $BypassCacheDir -Force | Out-Null }
    
    if (-not $Silent) { Write-Host "-> Проверка версии списков обхода..." -ForegroundColor Yellow }
    $LocalVer  = Get-LocalBypassVersion
    $RemoteVer = Get-RemoteBypassVersion
    
    if ($null -eq $RemoteVer) {
        if (-not $Silent) { Write-Host "  Нет связи с GitHub. Используются локальные списки." -ForegroundColor DarkGray }
        return $false
    }
    
    if (-not $Force -and $LocalVer -eq $RemoteVer) {
        if (-not $Silent) { Write-Host "  Версия актуальна: v$RemoteVer" -ForegroundColor Green }
        return $false
    }
    
    if (-not $Silent) {
        if ($LocalVer -and $LocalVer -ne $RemoteVer) {
            Write-Host "  Обновление: v$LocalVer -> v$RemoteVer" -ForegroundColor Cyan
        } elseif (-not $LocalVer) {
            Write-Host "  Первая загрузка списков (v$RemoteVer)..." -ForegroundColor Cyan
        } else {
            Write-Host "  Принудительная перезагрузка (v$RemoteVer)..." -ForegroundColor Yellow
        }
    }
    
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
        Invoke-WebRequest -Uri "$BypassListBaseUrl/ru_bypass_domain.txt" -OutFile "$BypassCacheDir\ru_bypass_domain.txt" -UseBasicParsing
        Invoke-WebRequest -Uri "$BypassListBaseUrl/ru_bypass_ip.txt"     -OutFile "$BypassCacheDir\ru_bypass_ip.txt"     -UseBasicParsing
        Set-Content -Path "$BypassCacheDir\ru_bypass_version.txt" -Value $RemoteVer -Encoding UTF8
        if (-not $Silent) { Write-Host "  Списки обновлены до v$RemoteVer!" -ForegroundColor Green }
        return $true
    } catch {
        if (-not $Silent) { Write-Host "  Ошибка загрузки: $_" -ForegroundColor Red }
        return $false
    }
}

function Invoke-ParallelWarpCli {
    param(
        [string[]]$CmdArgs,
        [int]$ThrottleLimit = 30
    )
    
    $warpCli = "C:\Program Files\Cloudflare\Cloudflare WARP\warp-cli.exe"
    if (-not (Test-Path $warpCli)) {
        # Fallback to variable if defined, or just warp-cli from PATH
        $warpCli = if ($global:WarpCli) { $global:WarpCli } else { "warp-cli" }
    }
    
    $jobs = [System.Collections.Generic.List[System.Diagnostics.Process]]::new()
    $total = $CmdArgs.Count
    $completed = 0
    
    foreach ($arg in $CmdArgs) {
        # Check if we reached the throttle limit
        while (($jobs | Where-Object { -not $_.HasExited }).Count -ge $ThrottleLimit) {
            Start-Sleep -Milliseconds 20
        }
        
        $argList = [System.Collections.ArrayList]::new()
        $argList.Add("--accept-tos") | Out-Null
        foreach ($part in $arg.Split(' ')) {
            if ($part.Trim() -ne "") { $argList.Add($part.Trim()) | Out-Null }
        }
        
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $warpCli
        $psi.Arguments = [string]::Join(" ", $argList.ToArray())
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        
        $p = New-Object System.Diagnostics.Process
        $p.StartInfo = $psi
        try {
            [void]$p.Start()
            $jobs.Add($p)
        } catch {}
        
        $completedCount = ($jobs | Where-Object { $_.HasExited }).Count
        if ($completedCount -ne $completed) {
            $completed = $completedCount
            $percent = [math]::Round(($completed / $total) * 100)
            Write-Host -NoNewline "`r   Применение: $percent% ($completed/$total)"
        }
    }
    
    while (($jobs | Where-Object { -not $_.HasExited }).Count -gt 0) {
        Start-Sleep -Milliseconds 50
        $completedCount = ($jobs | Where-Object { $_.HasExited }).Count
        if ($completedCount -ne $completed) {
            $completed = $completedCount
            $percent = [math]::Round(($completed / $total) * 100)
            Write-Host -NoNewline "`r   Применение: $percent% ($completed/$total)"
        }
    }
    
    Write-Host ""
    foreach ($p in $jobs) { $p.Dispose() }
}

function Apply-RuBypassTemplate {
    $DomainFile = "$BypassCacheDir\ru_bypass_domain.txt"
    $IpFile     = "$BypassCacheDir\ru_bypass_ip.txt"
    
    # Ensure lists exist, download if needed
    if (-not (Test-Path $DomainFile) -or -not (Test-Path $IpFile)) {
        Write-Host "-> Файлы списков не найдены, загрузка из репозитория..." -ForegroundColor Yellow
        Update-BypassLists | Out-Null
    }
    
    if (-not (Test-Path $DomainFile)) {
        Write-Host "❌ Не удалось получить список доменов. Проверьте подключение." -ForegroundColor Red
        return
    }
    
    Write-Host "-> Парсинг и фильтрация списков обхода..." -ForegroundColor Yellow
    
    $Domains  = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $IpRanges = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    
    foreach ($line in (Get-Content $DomainFile)) {
        $line = $line.Trim()
        if ($line -eq "" -or $line.StartsWith("#")) { continue }
        $Domains.Add($line) | Out-Null
    }
    
    if (Test-Path $IpFile) {
        foreach ($line in (Get-Content $IpFile)) {
            $line = $line.Trim()
            if ($line -eq "" -or $line.StartsWith("#")) { continue }
            if ($line -match "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}(/\d{1,2})?$") {
                $IpRanges.Add($line) | Out-Null
            }
        }
    }
    
    # Read existing exclusions to skip duplicates and avoid useless process spawns
    $ExistingHosts = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $ExistingIps   = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $WarpSettingsFile = "C:\ProgramData\Cloudflare\settings.json"
    
    if (Test-Path $WarpSettingsFile) {
        try {
            $WarpSettings = Get-Content $WarpSettingsFile -Raw | ConvertFrom-Json
            if ($WarpSettings.excluded_hosts) {
                foreach ($e in $WarpSettings.excluded_hosts) {
                    $k = if ($e -is [Array]) { $e[0] } else { $e }
                    $ExistingHosts.Add($k) | Out-Null
                }
            }
            if ($WarpSettings.excluded_ips) {
                foreach ($e in $WarpSettings.excluded_ips) {
                    $k = if ($e -is [Array]) { $e[0] } else { $e }
                    $ExistingIps.Add($k) | Out-Null
                }
            }
        } catch {}
    }
    
    $Cmds = [System.Collections.Generic.List[string]]::new()
    
    foreach ($dom in $Domains) {
        if (-not $ExistingHosts.Contains($dom)) {
            $Cmds.Add("tunnel host add $dom")
        }
    }
    
    foreach ($ip in $IpRanges) {
        if (-not $ExistingIps.Contains($ip)) {
            if ($ip.Contains('/')) {
                $Cmds.Add("tunnel ip add-range $ip")
            } else {
                $Cmds.Add("tunnel ip add $ip")
            }
        }
    }
    
    if ($Cmds.Count -gt 0) {
        Write-Host "-> Добавление новых исключений в WARP ($($Cmds.Count) команд)..." -ForegroundColor Yellow
        Invoke-ParallelWarpCli -CmdArgs $Cmds.ToArray() -ThrottleLimit 30
        
        Write-Host "-> Применение завершено. Переподключение туннеля WARP..." -ForegroundColor Yellow
        & $WarpCli --accept-tos disconnect | Out-Null
        Start-Sleep -Seconds 1
        & $WarpCli --accept-tos connect | Out-Null
        $global:CachedWarpStatus = $null
        Write-Host "✅ Шаблон успешно применен!" -ForegroundColor Green
    } else {
        Write-Host "✅ Все домены и IP-диапазоны уже есть в списке исключений WARP!" -ForegroundColor Green
    }
}

function Show-SplitTunnelSettings {
    while ($true) {
        $LocalVer = Get-LocalBypassVersion
        $VerStr   = if ($LocalVer) { " [список v$LocalVer]" } else { " [список не загружен]" }
        
        Clear-Host
        Write-Header
        Write-Host "            УПРАВЛЕНИЕ МАРШРУТИЗАЦИЕЙ (SPLIT TUNNEL)" -ForegroundColor Cyan
        Write-Host "=========================================================" -ForegroundColor DarkGray
        Write-Host " [1] Применить шаблон обхода RU-нета$VerStr" -ForegroundColor Green
        Write-Host "     Домены + IP-диапазоны -> напрямую, без VPN"
        Write-Host " [2] Обновить списки обхода из репозитория" -ForegroundColor Yellow
        Write-Host " [3] Просмотреть текущие исключения WARP" -ForegroundColor White
        Write-Host " [4] Полный сброс исключений к заводским дефолтам" -ForegroundColor Red
        Write-Host " [0] Назад" -ForegroundColor Gray
        Write-Host "=========================================================" -ForegroundColor DarkGray
        
        $sel = Read-Host "Выберите вариант"
        switch ($sel) {
            "1" {
                Apply-RuBypassTemplate
                Read-Host "Нажмите Enter для возврата..."
            }
            "2" {
                Write-Host ""
                Update-BypassLists -Force
                Read-Host "Нажмите Enter для возврата..."
            }
            "3" {
                Clear-Host
                Write-Header
                Write-Host "           ТЕКУЩИЙ СПИСОК ИСКЛЮЧЕНИЙ WARP" -ForegroundColor Cyan
                Write-Host "=========================================================" -ForegroundColor DarkGray
                $WarpSettingsFile = "C:\ProgramData\Cloudflare\settings.json"
                if (Test-Path $WarpSettingsFile) {
                    try {
                        $WarpSettings = Get-Content $WarpSettingsFile -Raw -Encoding UTF8 | ConvertFrom-Json
                        
                        # 1. Parse and extract custom hosts (all hosts are custom)
                        $CustomHosts = @()
                        if ($WarpSettings.excluded_hosts) {
                            foreach ($entry in $WarpSettings.excluded_hosts) {
                                $hostVal = if ($entry -is [Array]) { $entry[0] } else { $entry }
                                if ($hostVal) { $CustomHosts += $hostVal }
                            }
                        }
                        
                        # 2. Parse and extract custom IPs (filter out known WARP system defaults)
                        $SystemIps = [System.Collections.Generic.HashSet[string]]::new([string[]]@(
                            "10.0.0.0/8", "100.64.0.0/10", "169.254.0.0/16", "172.16.0.0/12",
                            "192.0.0.0/24", "192.168.0.0/16", "224.0.0.0/24", "240.0.0.0/4",
                            "239.255.255.250/32", "255.255.255.255/32", "fe80::/10",
                            "fd00::/8", "ff01::/16", "ff02::/16", "ff03::/16", "ff04::/16",
                            "ff05::/16", "fc00::/7", "2620:149:a44::/48", "2403:300:a42::/48",
                            "2403:300:a51::/48", "2a01:b740:a42::/48"
                        ), [System.StringComparer]::OrdinalIgnoreCase)
                        
                        $CustomIps = @()
                        if ($WarpSettings.excluded_ips) {
                            foreach ($entry in $WarpSettings.excluded_ips) {
                                $ipVal = if ($entry -is [Array]) { $entry[0] } else { $entry }
                                if ($ipVal -and -not $SystemIps.Contains($ipVal)) {
                                    $CustomIps += $ipVal
                                }
                            }
                        }
                        
                        # 3. Clean Display (first 15 entries + summary)
                        Write-Host "--- Кастомные домены (Hosts): $($CustomHosts.Count) ---" -ForegroundColor Yellow
                        if ($CustomHosts.Count -gt 0) {
                            $CustomHosts | Select-Object -First 15 | ForEach-Object { Write-Host "  $_" -ForegroundColor Green }
                            if ($CustomHosts.Count -gt 15) {
                                Write-Host "  ... и ещё $($CustomHosts.Count - 15) доменов" -ForegroundColor DarkGray
                            }
                        } else {
                            Write-Host "  (пусто)" -ForegroundColor DarkGray
                        }
                        
                        Write-Host "`n--- Кастомные IP-диапазоны (IPs): $($CustomIps.Count) ---" -ForegroundColor Yellow
                        if ($CustomIps.Count -gt 0) {
                            $CustomIps | Select-Object -First 15 | ForEach-Object { Write-Host "  $_" -ForegroundColor Cyan }
                            if ($CustomIps.Count -gt 15) {
                                Write-Host "  ... и ещё $($CustomIps.Count - 15) IP-диапазонов" -ForegroundColor DarkGray
                            }
                        } else {
                            Write-Host "  (пусто)" -ForegroundColor DarkGray
                        }
                        
                    } catch {
                        Write-Host "Ошибка чтения файла настроек WARP." -ForegroundColor Red
                    }
                } else {
                    Write-Host "Файл настроек WARP не найден." -ForegroundColor Red
                }
                Write-Host "=========================================================" -ForegroundColor DarkGray
                Read-Host "Нажмите Enter для возврата..." | Out-Null
            }
            "4" {
                $Confirm = Read-Host "Вы действительно хотите сбросить все исключения к дефолтным? (Y/N)"
                if ($Confirm -match "^[YyДд]") {
                    Write-Host "-> Сброс исключений..." -ForegroundColor Yellow
                    & $WarpCli --accept-tos tunnel host reset | Out-Null
                    & $WarpCli --accept-tos tunnel ip reset | Out-Null
                    Write-Host "Все кастомные исключения сброшены." -ForegroundColor Green
                    if ((Get-CachedWarpStatus) -eq "Connected") {
                        Write-Host "-> Переподключение туннеля WARP..." -ForegroundColor Yellow
                        & $WarpCli --accept-tos disconnect | Out-Null
                        Start-Sleep -Seconds 1
                        & $WarpCli --accept-tos connect | Out-Null
                        $global:CachedWarpStatus = $null
                    }
                    Start-Sleep -Seconds 2
                }
            }
            "0" { return }
        }
    }
}

function Start-Benchmark {
    Clear-Host
    Write-Header
    Write-Host "         АВТО-ПОДБОР ЛУЧШЕГО ПРЕСЕТА (BENCHMARK)" -ForegroundColor Cyan
    Write-Host "=========================================================" -ForegroundColor DarkGray
    Write-Host " Тестирование доступности узлов напрямую через пресеты zapret." -ForegroundColor Gray
    Write-Host " Это позволит найти лучший пресет для вашего провайдера." -ForegroundColor Gray
    Write-Host " Пожалуйста, подождите, это займет некоторое время..." -ForegroundColor Gray
    Write-Host "=========================================================" -ForegroundColor DarkGray
    
    $ZapretDirFullName = if (Test-Path $ZapretDir) { (Get-Item $ZapretDir).FullName } else { "" }
    if (-not $ZapretDirFullName) {
        Write-Host "❌ Ошибка: Папка компонентов zapret не найдена." -ForegroundColor Red
        Pause; return
    }
    
    # Exclude service.bat, service_install.bat, and service_remove.bat
    $BatFiles = Get-ChildItem -Path $ZapretDirFullName -Filter "*.bat" | Where-Object { $_.Name -notmatch "(?i)service(_install|_remove)?\.bat$" }
    if ($BatFiles.Count -eq 0) {
        Write-Host "❌ Ошибка: Файлы пресетов не найдены." -ForegroundColor Red
        Pause; return
    }
    
    if (Test-Path $WarpCli) {
        & $WarpCli --accept-tos disconnect *> $null
    }
    
    # Clean previous winws processes
    Stop-Process -Name "winws" -Force -ErrorAction SilentlyContinue *> $null
    while (Get-Process -Name "winws" -ErrorAction SilentlyContinue) { Start-Sleep -Milliseconds 100 }
    
    $Results = @()
    foreach ($File in $BatFiles) {
        $FileName = $File.Name
        Write-Host " -> Тестирование [$FileName]... " -NoNewline -ForegroundColor Gray
        
        $ArgsStr = Get-ZapretArgs $File.FullName
        $ZapretJob = $null
        if ($null -ne $ArgsStr) {
            $WinwsPath = "$ZapretDir\bin\winws.exe"
            $ZapretJob = Start-Process -FilePath $WinwsPath -ArgumentList $ArgsStr -WorkingDirectory "$ZapretDir\bin" -WindowStyle Hidden -PassThru
        } else {
            $ZapretJob = Start-Process -FilePath $File.FullName -WorkingDirectory (Split-Path $File.FullName) -WindowStyle Hidden -PassThru
        }
        
        Start-Sleep -Seconds 3
        
        $Pings = @()
        $SuccessCount = 0
        $TestTargets = @(
            @{ Host = "youtube.com"; Port = 443 }
            @{ Host = "discord.com"; Port = 443 }
            @{ Host = "162.159.36.1"; Port = 443 }
        )
        
        foreach ($Target in $TestTargets) {
            try {
                $TcpClient = New-Object System.Net.Sockets.TcpClient
                $Watch = [System.Diagnostics.Stopwatch]::StartNew()
                $AsyncResult = $TcpClient.BeginConnect($Target.Host, $Target.Port, $null, $null)
                $Success = $AsyncResult.AsyncWaitHandle.WaitOne(1500, $false)
                if ($Success) {
                    $TcpClient.EndConnect($AsyncResult)
                    $Watch.Stop()
                    $Pings += $Watch.Elapsed.TotalMilliseconds
                    $SuccessCount++
                }
                $TcpClient.Close()
            } catch {}
        }
        
        # Synchronously stop running winws and wait until port and WinDivert driver are freed
        if ($ZapretJob) { Stop-Process -Id $ZapretJob.Id -Force -ErrorAction SilentlyContinue *> $null }
        Stop-Process -Name "winws" -Force -ErrorAction SilentlyContinue *> $null
        while (Get-Process -Name "winws" -ErrorAction SilentlyContinue) { Start-Sleep -Milliseconds 100 }
        Start-Sleep -Milliseconds 500
        
        if ($SuccessCount -gt 0) {
            $AvgPing = [math]::Round(($Pings | Measure-Object -Average).Average)
            Write-Host "ДОСТУПЕН ($SuccessCount/$($TestTargets.Count) узлов, $AvgPing ms)" -ForegroundColor Green
            $Results += [PSCustomObject]@{ Preset = $File.FullName; Name = $FileName; Status = "OK"; SuccessRate = $SuccessCount; Ping = $AvgPing }
        } else {
            Write-Host "НЕ РАБОТАЕТ" -ForegroundColor Red
            $Results += [PSCustomObject]@{ Preset = $File.FullName; Name = $FileName; Status = "Fail"; SuccessRate = 0; Ping = 9999 }
        }
    }
    
    Write-Host "=========================================================" -ForegroundColor DarkGray
    Write-Host "                 РЕЗУЛЬТАТЫ ТЕСТИРОВАНИЯ" -ForegroundColor Cyan
    Write-Host "=========================================================" -ForegroundColor DarkGray
    
    $Best = $Results | Where-Object { $_.Status -eq "OK" } | Sort-Object @{Expression="SuccessRate";Descending=$true}, @{Expression="Ping";Ascending=$true} | Select-Object -First 1
    if ($Best) {
        Write-Host " -> Рекомендуемая стратегия: " -NoNewline
        Write-Host "[$($Best.Name)]" -ForegroundColor Green -NoNewline
        Write-Host " (обход: $($Best.SuccessRate)/3 узлов, средний пинг: $($Best.Ping) ms)" -ForegroundColor White
        Write-Host ""
        $SaveChoice = Read-Host " Сделать эту стратегию автоматической по умолчанию? (Y/N)"
        if ($SaveChoice -match "^[YyДд]") {
            $Config.LastPreset = $Best.Preset
            $Config.AutoPreset = $true
            Save-Config
            Write-Host " Настройки сохранены!" -ForegroundColor Green
        }
    } else {
        Write-Host "❌ Ни один пресет не смог разблокировать узлы напрямую." -ForegroundColor Yellow
        Write-Host " Возможно, провайдер блокирует все стратегии обхода DPI." -ForegroundColor Yellow
        Write-Host " Выберите пресет вручную или обновите zapret." -ForegroundColor Gray
    }
    Write-Host " Нажмите Enter для возврата..."
    Read-Host | Out-Null
}


function Show-PingSettings {
    while ($true) {
        Clear-Host
        Write-Header
        Write-Host "                 НАСТРОЙКИ ДИАГНОСТИКИ И ПИНГА" -ForegroundColor Cyan
        Write-Host "=========================================================" -ForegroundColor DarkGray
        Write-Host " [1] Диагностика задержки (Ping)   : " -NoNewline
        if ($Config.AutoPing -eq 1) { Write-Host "СТАТИЧЕСКАЯ" -ForegroundColor Green }
        elseif ($Config.AutoPing -eq 2) { Write-Host "ДИНАМИЧЕСКАЯ ($($Config.PingInterval) сек)" -ForegroundColor Cyan }
        else { Write-Host "ОТКЛЮЧЕНО" -ForegroundColor Red }
        
        Write-Host " [2] Изменить интервал динамического пинга" -ForegroundColor White
        Write-Host " [3] Редактировать список хостов для проверки" -ForegroundColor White
        Write-Host "=========================================================" -ForegroundColor DarkGray
        Write-Host " [D] Сбросить настройки пинга по умолчанию" -ForegroundColor Red
        Write-Host " [0] Назад" -ForegroundColor Gray
        Write-Host "=========================================================" -ForegroundColor DarkGray
        
        $sel = Read-Host "Выберите вариант"
        switch ($sel.Trim().ToLower()) {
            "1" {
                $Config.AutoPing = ($Config.AutoPing + 1) % 3
                Save-Config
            }
            "2" {
                if ($Config.AutoPing -ne 2) {
                    Write-Host "Интервал настраивается только для динамического режима пинга." -ForegroundColor Yellow
                    Start-Sleep -Seconds 2
                    continue
                }
                Clear-Host
                Write-Header
                Write-Host "         ИНТЕРВАЛ ОБНОВЛЕНИЯ ДИНАМИЧЕСКОГО ПИНГА" -ForegroundColor Cyan
                Write-Host "=========================================================" -ForegroundColor DarkGray
                Write-Host " Укажите частоту обновления доступности узлов:" -ForegroundColor White
                Write-Host "   1. 15 секунд"
                Write-Host "   2. 30 секунд (Рекомендуется)"
                Write-Host "   3. 60 секунд"
                Write-Host "   4. 120 секунд"
                Write-Host "   5. Указать вручную в секундах"
                Write-Host ""
                $IntChoice = Read-Host "Выберите вариант (1-5, по умолчанию: 2)"
                switch ($IntChoice.Trim()) {
                    "1" { $Config.PingInterval = 15 }
                    "2" { $Config.PingInterval = 30 }
                    "3" { $Config.PingInterval = 60 }
                    "4" { $Config.PingInterval = 120 }
                    "5" { 
                        $CustomVal = Read-Host "Введите время в секундах (минимум 5)"
                        $ParsedVal = 30
                        if ([int]::TryParse($CustomVal, [ref]$ParsedVal) -and $ParsedVal -ge 5) {
                            $Config.PingInterval = $ParsedVal
                        } else {
                            $Config.PingInterval = 30
                            Write-Host "Некорректное значение. Установлено 30 секунд." -ForegroundColor Yellow
                            Start-Sleep -Seconds 1
                        }
                    }
                    default { $Config.PingInterval = 30 }
                }
                Save-Config
            }
            "3" {
                Start-Process notepad.exe $PingListPath -Wait
            }
            "d" {
                $Confirm = Read-Host "Сбросить параметры пинга к дефолтным? (Y/N)"
                if ($Confirm.Trim().ToLower() -match "^[yд]") {
                    $Config.AutoPing = $DefaultConfig.AutoPing
                    $Config.PingInterval = $DefaultConfig.PingInterval
                    Save-Config
                    Write-Host "Настройки пинга сброшены!" -ForegroundColor Green
                    Start-Sleep -Seconds 1
                }
            }
            "0" { return }
        }
    }
}

function Uninstall-WarpBypass {
    Clear-Host
    Write-Header
    Write-Host "              ПОЛНОЕ УДАЛЕНИЕ WARPBYPASS" -ForegroundColor Red
    Write-Host "=========================================================" -ForegroundColor DarkGray
    
    Write-Host "-> Остановка фоновых процессов маскировки трафика..." -ForegroundColor Yellow
    try { Stop-Process -Name "winws" -Force -ErrorAction SilentlyContinue *>$null } catch {}
    Start-Sleep -Seconds 1
    

    
    Write-Host "-> Восстановление настроек Cloudflare WARP..." -ForegroundColor Yellow
    if (Test-Path $WarpCli) {
        & $WarpCli --accept-tos disconnect *> $null
        & $WarpCli --accept-tos mode warp *> $null
        & $WarpCli --accept-tos tunnel host reset *> $null
        & $WarpCli --accept-tos tunnel ip reset *> $null
    }
    try {
        Set-Service -Name "CloudflareWARP" -StartupType Manual -ErrorAction SilentlyContinue | Out-Null
    } catch {}
    
    Write-Host "-> Очистка реестра Windows..." -ForegroundColor Yellow
    try {
        foreach ($Hive in @("HKLM", "HKCU")) {
            $RegPath = "$Hive`:\Software\Microsoft\Windows\CurrentVersion\Run"
            foreach ($KeyName in @("CloudflareWARP", "Cloudflare WARP", "WarpBypass")) {
                if (Get-ItemProperty -Path $RegPath -Name $KeyName -ErrorAction SilentlyContinue) {
                    Remove-ItemProperty -Path $RegPath -Name $KeyName -Force -ErrorAction SilentlyContinue | Out-Null
                }
            }
        }
    } catch {}
    
    Write-Host "-> Удаление файлов в AppData..." -ForegroundColor Yellow
    $MyPID = $PID
    $CmdArgs = @(
        '-NoProfile'
        '-WindowStyle'
        'Hidden'
        '-Command'
        "while (Get-Process -Id $MyPID -ErrorAction SilentlyContinue) { Start-Sleep 1 }; Remove-Item -Path '$StorageDir' -Recurse -Force -ErrorAction SilentlyContinue"
    )
    Start-Process powershell -ArgumentList $CmdArgs -WindowStyle Hidden
    
    Write-Host "=========================================================" -ForegroundColor DarkGray
    Write-Host " Деинсталляция успешно завершена!" -ForegroundColor Green
    Write-Host " Все службы удалены. Папка AppData будет стерта через секунду." -ForegroundColor Gray
    Write-Host " Спасибо, что использовали WarpBypass!" -ForegroundColor Gray
    Write-Host "=========================================================" -ForegroundColor DarkGray
    Start-Sleep -Seconds 4
    exit
}

function Show-CommonSettings {
    while ($true) {
        Clear-Host
        Write-Header
        Write-Host "             ОБЩИЕ ПАРАМЕТРЫ СИСТЕМЫ WarpBypass" -ForegroundColor Cyan
        Write-Host "=========================================================" -ForegroundColor DarkGray
        Write-Host " [1] Автоматический запуск профиля : " -NoNewline; if ($Config.AutoPreset) { Write-Host "АКТИВНО" -ForegroundColor Green } else { Write-Host "ОТКЛЮЧЕНО" -ForegroundColor Red }
        Write-Host " [2] Принудительный сброс DNS-кэша : " -NoNewline; if ($Config.DnsFix) { Write-Host "АКТИВНО" -ForegroundColor Green } else { Write-Host "ОТКЛЮЧЕНО" -ForegroundColor Red }
        Write-Host " [3] Авто-синхронизация обновлений : " -NoNewline; if ($Config.AutoUpdate) { Write-Host "АКТИВНО" -ForegroundColor Green } else { Write-Host "ОТКЛЮЧЕНО" -ForegroundColor Red }
        Write-Host " [4] Задержка автозапуска профиля  : " -NoNewline; if ($Config.AutoPresetTimeout -eq 0) { Write-Host "0 сек (Мгновенный старт)" -ForegroundColor Cyan } else { Write-Host "$($Config.AutoPresetTimeout) сек" -ForegroundColor Green }
        Write-Host "=========================================================" -ForegroundColor DarkGray
        Write-Host " [U] Полное удаление утилиты WarpBypass (Деинсталляция)" -ForegroundColor Red
        Write-Host " [D] Сбросить общие параметры по умолчанию" -ForegroundColor Red
        Write-Host " [0] Назад" -ForegroundColor Gray
        Write-Host "=========================================================" -ForegroundColor DarkGray
        
        $sel = Read-Host "Выберите вариант"
        switch ($sel.Trim().ToLower()) {
            "1" { $Config.AutoPreset = -not $Config.AutoPreset; Save-Config }
            "2" { $Config.DnsFix = -not $Config.DnsFix; Save-Config }
            "3" { $Config.AutoUpdate = -not $Config.AutoUpdate; Save-Config }
            "4" {
                $Val = Read-Host "Введите задержку автозапуска в секундах (0 - запуск без ожидания)"
                $ParsedVal = 0
                if ([int]::TryParse($Val, [ref]$ParsedVal) -and $ParsedVal -ge 0) {
                    $Config.AutoPresetTimeout = $ParsedVal
                    Save-Config
                    Write-Host "Задержка автозапуска установлена в $ParsedVal сек." -ForegroundColor Green
                    Start-Sleep -Seconds 1
                } else {
                    Write-Host "Некорректное значение задержки." -ForegroundColor Red
                    Start-Sleep -Seconds 1
                }
            }
            "u" {
                $Confirm = Read-Host "ВНИМАНИЕ: Это полностью удалит все службы и файлы WarpBypass. Продолжить? (Y/N)"
                if ($Confirm.Trim().ToLower() -match "^[yд]") {
                    Uninstall-WarpBypass
                }
            }
            "d" {
                $Confirm = Read-Host "Сбросить общие настройки к дефолтным? (Y/N)"
                if ($Confirm.Trim().ToLower() -match "^[yд]") {
                    $Config.AutoPreset = $DefaultConfig.AutoPreset
                    $Config.DnsFix = $DefaultConfig.DnsFix
                    $Config.AutoUpdate = $DefaultConfig.AutoUpdate
                    $Config.AutoPresetTimeout = $DefaultConfig.AutoPresetTimeout
                    Save-Config
                    Write-Host "Общие параметры сброшены!" -ForegroundColor Green
                    Start-Sleep -Seconds 1
                }
            }
            "0" { return }
        }
    }
}

function Show-Settings {
    while ($true) {
        Clear-Host
        Write-Header
        Write-Host "                 КОНФИГУРАЦИЯ (v$AppVersion)" -ForegroundColor Cyan
        Write-Host "=========================================================" -ForegroundColor DarkGray
        Write-Host " [1] Показать детальную статистику соединения WARP" -ForegroundColor White
        Write-Host " [2] Настройки диагностики и пинга" -ForegroundColor White
        Write-Host " [3] Управление Split Tunneling (Маршрутизация)" -ForegroundColor White
        Write-Host " [4] Общие параметры (Автозапуск, сброс DNS, обновления)" -ForegroundColor White
        Write-Host " [B] Запустить авто-подбор пресетов (Бенчмарк)" -ForegroundColor Yellow
        Write-Host "=========================================================" -ForegroundColor DarkGray
        Write-Host " [D] Полный сброс всех настроек к заводским дефолтам" -ForegroundColor Red
        Write-Host " [0] Вернуться в главное меню" -ForegroundColor Gray
        Write-Host "=========================================================" -ForegroundColor DarkGray
        
        $sel = Read-Host "Выберите раздел"
        switch ($sel.Trim().ToLower()) {
            "1" {
                if (Test-Path $WarpCli) {
                    $Mtu = "Не определено"
                    $Speed = "0 KB/s"
                    $Dns = "Не определено"
                    $Api = "Не определено"
                    $Fw = "Не определено"
                    $Loss = "0.00%"
                    
                    while ($true) {
                        Clear-Host
                        Write-Header
                        Write-Host "          ДЕТАЛЬНАЯ СТАТИСТИКА СОЕДИНЕНИЯ WARP" -ForegroundColor Cyan
                        Write-Host "=========================================================" -ForegroundColor DarkGray
                        
                        $ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
                        $ProcessInfo.FileName = $WarpCli
                        $ProcessInfo.Arguments = "--accept-tos stats"
                        $ProcessInfo.RedirectStandardOutput = $true
                        $ProcessInfo.RedirectStandardError = $true
                        $ProcessInfo.UseShellExecute = $false
                        $ProcessInfo.CreateNoWindow = $true
                        
                        $Process = New-Object System.Diagnostics.Process
                        $Process.StartInfo = $ProcessInfo
                        
                        $StatsOutput = ""
                        try {
                            $Process.Start() | Out-Null
                            
                            # Fast dynamic wait (up to 1.5s with 20ms polling)
                            $WaitLimit = 1500
                            $Elapsed = 0
                            while ($Elapsed -lt $WaitLimit) {
                                Start-Sleep -Milliseconds 20
                                $Elapsed += 20
                                if ($Process.StandardOutput.Peek() -ne -1) {
                                    break
                                }
                            }
                            
                            if (-not $Process.HasExited) {
                                $Process.Kill()
                            }
                            $StatsOutput = $Process.StandardOutput.ReadToEnd()
                        } catch {
                            $StatsOutput = ""
                        }
                        
                        if ($StatsOutput.Trim() -ne "") {
                            $Lines = $StatsOutput -split "`r?`n"
                            foreach ($Line in $Lines) {
                                if ($Line -match "tunnel_mtu_current\s*\(value\s*=\s*([\d.]+)\)") {
                                    $Mtu = [math]::Round([double]$Matches[1])
                                }
                                elseif ($Line -match "quic_utilized_bandwidth\s*\(value\s*=\s*([\d.]+)\)") {
                                    $Bytes = [double]$Matches[1]
                                    if ($Bytes -gt 1MB) {
                                        $Speed = "$([math]::Round($Bytes / 1MB, 2)) MB/s ($([math]::Round(($Bytes * 8) / 1MB, 2)) Mbps)"
                                    } else {
                                        $Speed = "$([math]::Round($Bytes / 1KB, 2)) KB/s"
                                    }
                                }
                                elseif ($Line -match "doh_avg_ms\s*\(.*avg\s*=\s*([\d.]+)\)") {
                                    $Dns = "$([math]::Round([double]$Matches[1], 1)) ms"
                                }
                                elseif ($Line -match "api_req_avg_ms\s*\(.*avg\s*=\s*([\d.]+)\)") {
                                    $Api = "$([math]::Round([double]$Matches[1], 1)) ms"
                                }
                                elseif ($Line -match "fw_avg_ms\s*\(.*avg\s*=\s*([\d.]+)\)") {
                                    $Fw = "$([math]::Round([double]$Matches[1], 1)) ms"
                                }
                                elseif ($Line -match "Loss rate:\s*(.+)") {
                                    $Loss = $Matches[1].Trim()
                                }
                            }
                        }
                        
                        Write-Host "  Текущий MTU туннеля         : " -NoNewline -ForegroundColor White
                        Write-Host $Mtu -ForegroundColor Green
                        
                        Write-Host "  Текущая скорость (QUIC)     : " -NoNewline -ForegroundColor White
                        Write-Host $Speed -ForegroundColor Cyan
                        
                        Write-Host "  Потери пакетов (Loss rate)  : " -NoNewline -ForegroundColor White
                        $LossColor = if ($Loss -match "^0") { "Green" } else { "Red" }
                        Write-Host $Loss -ForegroundColor $LossColor
                        
                        Write-Host "  Средняя задержка DNS (DoH)  : " -NoNewline -ForegroundColor White
                        Write-Host $Dns -ForegroundColor Green
                        
                        Write-Host "  Задержка API Cloudflare     : " -NoNewline -ForegroundColor White
                        Write-Host $Api -ForegroundColor Green
                        
                        Write-Host "  Внутренняя задержка фильтра : " -NoNewline -ForegroundColor White
                        Write-Host $Fw -ForegroundColor Gray
                        
                        Write-Host "=========================================================" -ForegroundColor DarkGray
                        Write-Host " [R] Обновить показатели статистики" -ForegroundColor Green
                        Write-Host " [0] Вернуться в настройки" -ForegroundColor Gray
                        Write-Host "=========================================================" -ForegroundColor DarkGray
                        
                        $Opt = Read-Host "Выберите действие"
                        if ($Opt.Trim().ToLower() -eq "r") {
                            continue
                        } else {
                            break
                        }
                    }
                } else {
                    Write-Host "Клиент Cloudflare WARP не установлен." -ForegroundColor Red
                    Start-Sleep -Seconds 2
                }
            }
            "2" { Show-PingSettings }
            "3" { Show-SplitTunnelSettings }
            "4" { Show-CommonSettings }
            "b" { Start-Benchmark }
            "d" {
                $Confirm = Read-Host "ВНИМАНИЕ: Сбросить абсолютно ВСЕ настройки к заводским? (Y/N)"
                if ($Confirm.Trim().ToLower() -match "^[yд]") {
                    foreach ($Key in $DefaultConfig.Keys) {
                        $Config.$Key = $DefaultConfig[$Key]
                    }
                    Save-Config
                    if (Test-Path $WarpCli) {
                        & $WarpCli --accept-tos mode warp | Out-Null
                    }
                    Write-Host "Все настройки сброшены к заводским дефолтам!" -ForegroundColor Green
                    Start-Sleep -Seconds 2
                }
            }
            "0" { return }
        }
    }
}

function Measure-Latency {
    if ($Config.AutoPing -eq 0 -or -not (Test-Path $PingListPath)) { return }
    $global:PingResults = @()
    $Domains = Get-Content $PingListPath | Where-Object { $_.Trim() -ne "" }
    
    $Jobs = @()
    foreach ($Dom in $Domains) {
        $CleanDom = $Dom.Trim() -replace "(?i)^https?://", "" -replace "/.*$", ""
        $TcpClient = New-Object System.Net.Sockets.TcpClient
        $Watch = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $AsyncResult = $TcpClient.BeginConnect($CleanDom, 443, $null, $null)
            $Jobs += [PSCustomObject]@{ 
                Domain = $CleanDom; 
                Client = $TcpClient; 
                AsyncResult = $AsyncResult; 
                Watch = $Watch 
            }
        } catch {
            $global:PingResults += [PSCustomObject]@{ Domain = $CleanDom; Status = "Fail"; Latency = -1 }
        }
    }
    
    $Limit = 1500
    $Elapsed = 0
    while ($Elapsed -lt $Limit) {
        $AllCompleted = $true
        foreach ($Job in $Jobs) {
            if (-not $Job.AsyncResult.IsCompleted) {
                $AllCompleted = $false
            } else {
                if ($Job.Watch.IsRunning) { $Job.Watch.Stop() }
            }
        }
        if ($AllCompleted) { break }
        Start-Sleep -Milliseconds 10
        $Elapsed += 10
    }
    
    foreach ($Job in $Jobs) {
        if ($Job.Watch.IsRunning) { $Job.Watch.Stop() }
    }
    
    foreach ($Job in $Jobs) {
        $CleanDom = $Job.Domain
        $TcpClient = $Job.Client
        $AsyncResult = $Job.AsyncResult
        $Watch = $Job.Watch
        
        if ($AsyncResult.IsCompleted) {
            try {
                $TcpClient.EndConnect($AsyncResult)
                $PingMs = [math]::Round($Watch.Elapsed.TotalMilliseconds)
                if ($PingMs -lt 1) { $PingMs = 1 }
                $global:PingResults += [PSCustomObject]@{ Domain = $CleanDom; Status = "OK"; Latency = $PingMs }
            } catch {
                $global:PingResults += [PSCustomObject]@{ Domain = $CleanDom; Status = "Fail"; Latency = -1 }
            }
        } else {
            $global:PingResults += [PSCustomObject]@{ Domain = $CleanDom; Status = "Timeout"; Latency = -1 }
        }
        $TcpClient.Close()
    }
}

function Connect-WarpTunnel ($BatFile) {
    try { Stop-Service -Name "zapret" -Force -ErrorAction SilentlyContinue *> $null } catch {}
    try { Stop-Service -Name "goodbyedpi" -Force -ErrorAction SilentlyContinue *> $null } catch {}
    try { Stop-Process -Name "winws" -Force -ErrorAction SilentlyContinue *> $null } catch {}
    try { Stop-Process -Name "goodbyedpi" -Force -ErrorAction SilentlyContinue *> $null } catch {}

    if ($Config.DnsFix) {
        Write-Host "-> Очистка локального кэша DNS-резолвера..." -ForegroundColor Yellow
        ipconfig /flushdns | Out-Null
    }
    
    Write-Host "-> Инициализация компонента winws (Headless)..." -ForegroundColor Yellow
    $ArgsStr = Get-ZapretArgs $BatFile
    $ZapretJob = $null
    if ($null -ne $ArgsStr) {
        $WinwsPath = "$ZapretDir\bin\winws.exe"
        $ZapretJob = Start-Process -FilePath $WinwsPath -ArgumentList $ArgsStr -WorkingDirectory "$ZapretDir\bin" -WindowStyle Hidden -PassThru
    } else {
        $ZapretJob = Start-Process -FilePath $BatFile -WorkingDirectory (Split-Path $BatFile) -WindowStyle Hidden -PassThru
    }
    Start-Sleep -Seconds 4
    
    if (-not (Test-Path $WarpCli)) {
        Write-Host "-> Развертывание клиента Cloudflare WARP..." -ForegroundColor Green
        $WarpMsi = "$StorageDir\Cloudflare_WARP.msi"
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
        try {
            Invoke-WebRequest -Uri "https://downloads.cloudflareclient.com/v1/download/windows/ga" -OutFile $WarpMsi -UseBasicParsing -UserAgent "WarpBypass"
            Write-Host "-> Выполнение тихой установки компонента (ожидайте)..." -ForegroundColor Gray
            Start-Process msiexec.exe -ArgumentList "/i `"$WarpMsi`" /qn /norestart START_WPF_AS_USER=0" -Wait -NoNewWindow
            Remove-Item $WarpMsi -ErrorAction SilentlyContinue
            if (-not (Test-Path $WarpCli)) {
                Write-Host "`n❌ Критическая ошибка: Установка завершена, но исполняемый файл warp-cli.exe не найден." -ForegroundColor Red
                Pause; Exit
            }
            Write-Host "-> Служба Cloudflare WARP успешно установлена!" -ForegroundColor Green
            Start-Sleep -Seconds 2
        } catch {
            Write-Host "`n❌ Критическая ошибка: Сбой при загрузке или инсталляции Cloudflare WARP." -ForegroundColor Red
            Pause; Exit
        }
    }
    
    Set-Service -Name "CloudflareWARP" -StartupType Manual -ErrorAction SilentlyContinue
    
    if (Test-Path $WarpCli) {
        & $WarpCli --accept-tos mode warp | Out-Null
    }
    
    Write-Host "-> Перезапуск системной службы Cloudflare WARP..." -ForegroundColor Yellow
    Stop-Service -Name "CloudflareWARP" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
    Start-Service -Name "CloudflareWARP" -ErrorAction SilentlyContinue
    Stop-Process -Name "Cloudflare WARP" -Force -ErrorAction SilentlyContinue
    
    # Wait for daemon to be ready (up to 8 seconds)
    $DaemonReady = $false
    for ($i = 0; $i -lt 16; $i++) {
        $StatusCheck = & $WarpCli --accept-tos status 2>&1 | Out-String
        if ($StatusCheck -and $StatusCheck -notmatch "(?i)Unable to connect|not running") {
            $DaemonReady = $true
            break
        }
        Start-Sleep -Milliseconds 500
    }
    
    Write-Host "-> Подключение туннеля WARP..." -ForegroundColor Yellow
    $RegCheck = & $WarpCli --accept-tos registration show 2>$null | Out-String
    if (-not $RegCheck -or $RegCheck -match "(?i)error|not registered|No registration") {
        Write-Host "-> Первичная регистрация клиента WARP..." -ForegroundColor Yellow
        & $WarpCli --accept-tos registration new 2>$null | Out-Null
    }
    & $WarpCli --accept-tos connect | Out-Null
    
    $Timeout = 30
    $Connected = $false
    while ($Timeout -gt 0) {
        $WarpStatus = & $WarpCli --accept-tos status | Out-String
        if ($WarpStatus -and $WarpStatus.Contains("Connected") -and -not $WarpStatus.Contains("Connecting")) { $Connected = $true; break }
        Start-Sleep -Seconds 1
        $Timeout--
    }
    
    return $Connected
}

function Show-ActiveSessionMenu ($CurrentInput, $TimerVal) {
    [console]::CursorVisible = $false
    [console]::SetCursorPosition(0, 0)
    
    Write-Header
    
    $WarpState = Get-CachedWarpStatus
    
    Write-Host " Статус соединения WARP : " -NoNewline -ForegroundColor White
    if ($global:TunnelPaused) {
        Write-Host "ПАУЗА (Остановлен)       " -ForegroundColor Yellow
    } else {
        if ($WarpState -eq "Connected") {
            Write-Host "CONNECTED (Подключен)    " -ForegroundColor Green
        } elseif ($WarpState -eq "Connecting") {
            Write-Host "CONNECTING (Подключение...)" -ForegroundColor Yellow
        } else {
            Write-Host "$($WarpState.PadRight(25))" -ForegroundColor Red
        }
    }
    
    if (-not $global:TunnelPaused -and $global:PingResults -and $global:PingResults.Count -gt 0) {
        Write-Host "=========================================================" -ForegroundColor DarkGray
        Write-Host " [ Доступность узлов (TCP Ping) ]" -NoNewline -ForegroundColor Cyan
        if ($Config.AutoPing -eq 2) {
            if ($TimerVal -eq "измерение...") {
                Write-Host " (измерение...)            " -ForegroundColor Yellow
            } else {
                Write-Host " (обновление через $($TimerVal)с)   " -ForegroundColor Gray
            }
        } else {
            Write-Host "                                 " -ForegroundColor Gray
        }
        
        foreach ($Ping in $global:PingResults) {
            $DomName = $Ping.Domain
            if ($DomName.Length -gt 25) { $DomName = $DomName.Substring(0, 22) + "..." }
            Write-Host "  $($DomName.PadRight(25)) : " -NoNewline
            if ($Ping.Status -eq "OK") {
                Write-Host "$($Ping.Latency) ms     " -ForegroundColor Green
            } elseif ($Ping.Status -eq "Timeout") {
                Write-Host "Превышено время ожидания " -ForegroundColor Red
            } else {
                Write-Host "Узел недоступен          " -ForegroundColor Red
            }
        }
    } else {
        for ($i=0; $i -lt 5; $i++) {
            Write-Host "                                                         "
        }
    }
    
    Write-Host "=========================================================" -ForegroundColor DarkGray
    if ($global:TunnelPaused) {
        Write-Host " [R]  Возобновить работу туннеля                         " -ForegroundColor Green
    } else {
        Write-Host " [P]  Приостановить работу (Пауза)                       " -ForegroundColor Yellow
    }
    Write-Host " [C]  Переподключить туннель                             " -ForegroundColor Cyan
    Write-Host " [M]  Сменить стратегию (Главное меню)                   " -ForegroundColor White
    Write-Host " [S]  Настройки                                          " -ForegroundColor Yellow
    Write-Host " [Q]  Отключить туннель и выйти                          " -ForegroundColor Red
    Write-Host "=========================================================" -ForegroundColor DarkGray
    
    $CleanedInput = $CurrentInput.PadRight(10)
    Write-Host "Команда: $CleanedInput" -NoNewline
    [console]::SetCursorPosition(9 + $CurrentInput.Length, [console]::CursorTop)
    [console]::CursorVisible = $true
}

function Get-ActiveSessionInput ($BatFile, [ref]$TimeRemainingRef) {
    $InputStr = ""
    $LastTick = [DateTime]::Now
    
    while ($true) {
        $Now = [DateTime]::Now
        if (($Now - $LastTick).TotalSeconds -ge 1) {
            $LastTick = $Now
            if ($Config.AutoPing -eq 2 -and -not $global:TunnelPaused) {
                $TimeRemainingRef.Value--
                if ($TimeRemainingRef.Value -le 0) {
                    Show-ActiveSessionMenu $InputStr "измерение..."
                    Measure-Latency
                    $TimeRemainingRef.Value = $Config.PingInterval
                }
                Show-ActiveSessionMenu $InputStr $TimeRemainingRef.Value
            }
        }
        
        if ([console]::KeyAvailable) {
            $Key = [console]::ReadKey($true)
            if ($Key.Key -eq [ConsoleKey]::Enter) {
                $FinalInput = $InputStr.Trim().ToLower()
                if ($FinalInput -eq "") {
                    $global:CachedWarpStatus = $null
                    if ($Config.AutoPing -ne 0 -and -not $global:TunnelPaused) {
                        Show-ActiveSessionMenu $InputStr "измерение..."
                        Measure-Latency
                        $TimeRemainingRef.Value = $Config.PingInterval
                    }
                    $InputStr = ""
                    Show-ActiveSessionMenu $InputStr $TimeRemainingRef.Value
                } else {
                    Write-Host ""
                    return $FinalInput
                }
            }
            elseif ($Key.Key -eq [ConsoleKey]::Backspace) {
                if ($InputStr.Length -gt 0) {
                    $InputStr = $InputStr.Substring(0, $InputStr.Length - 1)
                    Show-ActiveSessionMenu $InputStr $TimeRemainingRef.Value
                }
            }
            else {
                $Char = $Key.KeyChar
                if ($Char -match "[a-zA-Z0-9]") {
                    $InputStr += $Char
                    Show-ActiveSessionMenu $InputStr $TimeRemainingRef.Value
                }
            }
        }
        
        Start-Sleep -Milliseconds 50
    }
}

function Launch-Tunnel ($BatFile) {
    $Config.LastPreset = $BatFile
    Save-Config
    
    $global:TunnelPaused = $false
    $TimeRemaining = $Config.PingInterval
    
    try {
        Clear-Host
        Write-Header
        
        $Success = Connect-WarpTunnel $BatFile
        if (-not $Success) {
            Write-Host "Ошибка: Отсутствует ответ от службы маршрутизации WARP." -ForegroundColor Red
            Pause; return $true
        }
        
        if ($Config.AutoPing -ne 0) {
            Write-Host "-> Диагностика задержки узлов (ожидайте)..." -ForegroundColor Yellow
            Measure-Latency
        }
        
        $MyPID = $PID
        Start-Process powershell -ArgumentList @('-NoProfile', '-WindowStyle', 'Hidden', '-Command', "while (Get-Process -Id $MyPID -ErrorAction SilentlyContinue) { Start-Sleep 1 }; & '$WarpCli' --accept-tos disconnect") -WindowStyle Hidden
        
        # Initial draw of the menu
        Clear-Host
        Show-ActiveSessionMenu "" $TimeRemaining
        
        # Interactive menu loop
        while ($true) {
            $CleanInput = Get-ActiveSessionInput $BatFile ([ref]$TimeRemaining)
            
            if ($CleanInput -eq 's') {
                Show-Settings
                Clear-Host
                
                if ($Config.AutoPing -ne 0) {
                    Write-Host "-> Обновление диагностики (ожидайте)..." -ForegroundColor Yellow
                    Measure-Latency
                }
                $TimeRemaining = $Config.PingInterval
                Clear-Host
                Show-ActiveSessionMenu "" $TimeRemaining
            }
            elseif ($CleanInput -eq 'q') {
                Write-Host "`nВы действительно хотите отключить туннель и выйти? (Y/N)" -ForegroundColor Yellow
                $Confirm = [console]::ReadKey($true).KeyChar.ToString().ToLower()
                if ($Confirm -match "[yд]") {
                    return $true
                }
                Clear-Host
                Show-ActiveSessionMenu "" $TimeRemaining
            }
            elseif ($CleanInput -eq 'p' -and -not $global:TunnelPaused) {
                Write-Host "`n-> Приостановка туннеля..." -ForegroundColor Yellow
                & $WarpCli --accept-tos disconnect | Out-Null
                $global:TunnelPaused = $true
                Clear-Host
                Show-ActiveSessionMenu "" $TimeRemaining
            }
            elseif ($CleanInput -eq 'r' -and $global:TunnelPaused) {
                Write-Host "`n-> Возобновление туннеля..." -ForegroundColor Yellow
                $Res = Connect-WarpTunnel $BatFile
                if ($Res) {
                    $global:TunnelPaused = $false
                    if ($Config.AutoPing -ne 0) {
                        Write-Host "-> Обновление пинга (ожидайте)..." -ForegroundColor Yellow
                        Measure-Latency
                    }
                } else {
                    Write-Host "❌ Ошибка возобновления туннеля." -ForegroundColor Red
                    Start-Sleep -Seconds 2
                }
                $TimeRemaining = $Config.PingInterval
                Clear-Host
                Show-ActiveSessionMenu "" $TimeRemaining
            }
            elseif ($CleanInput -eq 'c') {
                Write-Host "`n-> Переподключение туннеля..." -ForegroundColor Yellow
                & $WarpCli --accept-tos disconnect | Out-Null
                $Res = Connect-WarpTunnel $BatFile
                if ($Res) {
                    $global:TunnelPaused = $false
                    if ($Config.AutoPing -ne 0) {
                        Write-Host "-> Обновление пинга (ожидайте)..." -ForegroundColor Yellow
                        Measure-Latency
                    }
                } else {
                    Write-Host "❌ Ошибка переподключения туннеля." -ForegroundColor Red
                    Start-Sleep -Seconds 2
                }
                $TimeRemaining = $Config.PingInterval
                Clear-Host
                Show-ActiveSessionMenu "" $TimeRemaining
            }
            elseif ($CleanInput -eq 'm') {
                return $false
            }
        }
    }
    catch [System.Management.Automation.PipelineStoppedException], [System.Management.Automation.Host.HostException] {
        Write-Host "`nВы действительно хотите отключить туннель и выйти? (Y/N)" -ForegroundColor Yellow
        $Confirm = [console]::ReadKey($true).KeyChar.ToString().ToLower()
        if ($Confirm -match "[yд]") {
            return $true
        }
    }
    finally {
        Write-Host "`n-> Отключение туннеля и очистка маршрутов..." -ForegroundColor Yellow
        try {
            if (Test-Path $WarpCli) {
                & $WarpCli --accept-tos disconnect -ErrorAction SilentlyContinue *> $null
            }
            Stop-Process -Name "winws" -Force -ErrorAction SilentlyContinue *> $null
        } catch {}
        Write-Host "-> Сеанс завершен успешно." -ForegroundColor Green
        Start-Sleep -Seconds 1
    }
}



# Main loop

Clear-Host
Write-Header

if ($FirstRun) {
    Start-SetupWizard
    if (-not (Test-Path $ZapretDir)) {
        $IsOnline = $true
        Check-Updates
    }
}

if ($Config.AutoUpdate) {
    Check-AppUpdate
    Check-Updates
}

if ($Config.AutoPreset -and $Config.LastPreset -and (Test-Path $Config.LastPreset)) {
    $WaitSecs = $Config.AutoPresetTimeout
    if ($WaitSecs -gt 0) {
        $Interrupted = $false
        $BatName = Split-Path $Config.LastPreset -Leaf
        Write-Host "`n-> Автоматический запуск профиля [$BatName] через $WaitSecs сек." -ForegroundColor Cyan
        Write-Host "   Нажмите любую клавишу для прерывания и перехода к конфигурации..." -ForegroundColor Yellow
        
        # Clear console input buffer completely
        while ([console]::KeyAvailable) { $null = [console]::ReadKey($true) }
        while ($WaitSecs -gt 0) {
            Start-Sleep -Seconds 1
            $WaitSecs--
            if ([console]::KeyAvailable) { 
                $Interrupted = $true
                while ([console]::KeyAvailable) { $null = [console]::ReadKey($true) }
                break 
            }
        }
        if (-not $Interrupted) { $ExitProg = Launch-Tunnel $Config.LastPreset; if ($ExitProg) { Exit } }
    } else {
        $ExitProg = Launch-Tunnel $Config.LastPreset
        if ($ExitProg) { Exit }
    }
}

while ($true) {
    Clear-Host
    Write-Host "=========================================================" -ForegroundColor Magenta
    Write-Host $LogoText -ForegroundColor Magenta
    Write-Host "           Created By BUSH   |   v$AppVersion   " -ForegroundColor Cyan
    Write-Host "=========================================================" -ForegroundColor DarkGray
    
    $ZapretDirFullName = if (Test-Path $ZapretDir) { (Get-Item $ZapretDir).FullName } else { "" }
    $BatFiles = if ($ZapretDirFullName) { Get-ChildItem -Path $ZapretDirFullName -Filter "*.bat" | Where-Object { $_.Name -notmatch "service_remove|service_install" } } else { @() }
    
    Write-Host " [1-9] Инициализировать профиль маршрутизации" -ForegroundColor White
    Write-Host " [S]   Параметры утилиты" -ForegroundColor Yellow
    Write-Host " [Q]   Завершить работу" -ForegroundColor Gray
    Write-Host "=========================================================" -ForegroundColor DarkGray
    
    if ($BatFiles.Count -gt 0) {
        for ($i = 0; $i -lt $BatFiles.Count; $i++) {
            $Color = if ($BatFiles[$i].Name -like "*alt12*") { "Green" } else { "Gray" }
            Write-Host " [$($i + 1)] $($BatFiles[$i].Name)" -ForegroundColor $Color
        }
    } else { Write-Host " Профили конфигурации не обнаружены." -ForegroundColor Red }
    
    $input = Read-Host "Команда"
    if ($input.ToLower() -eq 's') { Show-Settings }
    elseif ($input.ToLower() -eq 'q') { Exit }
    else {
        $choice = 0
        if ([int]::TryParse($input, [ref]$choice) -and $choice -ge 1 -and $choice -le $BatFiles.Count) {
            $ExitProg = Launch-Tunnel $BatFiles[$choice - 1].FullName
            if ($ExitProg) { Exit }
        }
    }
}

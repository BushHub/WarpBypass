<# : RUN
@echo off
title WarpBypass v5.1 by BUSH
cd /d "%~dp0"
set "WARP_BAT_PATH=%~f0"
fltmc >nul 2>&1
if %errorLevel% neq 0 (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath $env:WARP_BAT_PATH -Verb RunAs"
    exit /b
)
powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-Command -ScriptBlock ([ScriptBlock]::Create((Get-Content -LiteralPath $env:WARP_BAT_PATH -Encoding UTF8 -Raw)))"
exit /b
#>

$ProgressPreference = 'SilentlyContinue'
$WarningPreference = 'SilentlyContinue'

# =========================================================
# WarpBypass
# Author: BUSH
# =========================================================

$AppVersion = "5.1"
$RepoApiUrl = "https://api.github.com/repos/BushHub/WarpBypass/releases/latest"

# Disable console Quick-Edit mode and set clean window title
try {
    if (-not ("Win32.Win32Console" -as [type])) {
        $ConsoleCode = @'
        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern IntPtr GetStdHandle(int nStdHandle);
        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);
        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);
        [DllImport("kernel32.dll")]
        public static extern IntPtr GetConsoleWindow();
        [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        public static extern bool SetWindowText(IntPtr hwnd, string lpString);
'@
        Add-Type -MemberDefinition $ConsoleCode -Name "Win32Console" -Namespace "Win32" -ErrorAction SilentlyContinue *> $null
    }
    $StdInputHandle = [Win32.Win32Console]::GetStdHandle(-10)
    $ConsoleMode = 0
    if ([Win32.Win32Console]::GetConsoleMode($StdInputHandle, [ref]$ConsoleMode)) {
        # Disable Quick-Edit (0x0040) using extended flags (0x0080)
        [Win32.Win32Console]::SetConsoleMode($StdInputHandle, (($ConsoleMode -band -bnot 0x0040) -bor 0x0080)) | Out-Null
    }
    
    # Set clean window title bypassing conhost Administrator prefixing
    $Hwnd = [Win32.Win32Console]::GetConsoleWindow()
    if ($Hwnd -ne [IntPtr]::Zero) {
        [Win32.Win32Console]::SetWindowText($Hwnd, "WarpBypass v$AppVersion by BUSH") | Out-Null
    }
} catch {}


# Job object with KILL_ON_JOB_CLOSE: child winws dies together with this process (window close, crash, kill)
try {
    if (-not ("WinwsJob" -as [type])) {
        Add-Type -ErrorAction Stop -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class WinwsJob {
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] static extern IntPtr CreateJobObject(IntPtr attrs, string name);
    [DllImport("kernel32.dll")] static extern bool SetInformationJobObject(IntPtr job, int infoClass, IntPtr info, uint size);
    [DllImport("kernel32.dll")] static extern bool AssignProcessToJobObject(IntPtr job, IntPtr process);
    [StructLayout(LayoutKind.Sequential)] struct BASIC {
        public long PerProcessUserTimeLimit; public long PerJobUserTimeLimit; public uint LimitFlags;
        public UIntPtr MinimumWorkingSetSize; public UIntPtr MaximumWorkingSetSize; public uint ActiveProcessLimit;
        public UIntPtr Affinity; public uint PriorityClass; public uint SchedulingClass;
    }
    [StructLayout(LayoutKind.Sequential)] struct IOC {
        public ulong ReadOps; public ulong WriteOps; public ulong OtherOps; public ulong ReadBytes; public ulong WriteBytes; public ulong OtherBytes;
    }
    [StructLayout(LayoutKind.Sequential)] struct EXT {
        public BASIC Basic; public IOC Io; public UIntPtr ProcessMemoryLimit; public UIntPtr JobMemoryLimit;
        public UIntPtr PeakProcessMemoryUsed; public UIntPtr PeakJobMemoryUsed;
    }
    static IntPtr job = IntPtr.Zero;
    public static bool Assign(IntPtr process) {
        if (job == IntPtr.Zero) {
            job = CreateJobObject(IntPtr.Zero, null);
            if (job == IntPtr.Zero) return false;
            EXT info = new EXT();
            info.Basic.LimitFlags = 0x2000; // JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
            int size = Marshal.SizeOf(typeof(EXT));
            IntPtr buf = Marshal.AllocHGlobal(size);
            try {
                Marshal.StructureToPtr(info, buf, false);
                if (!SetInformationJobObject(job, 9, buf, (uint)size)) { job = IntPtr.Zero; return false; }
            } finally { Marshal.FreeHGlobal(buf); }
        }
        return AssignProcessToJobObject(job, process);
    }
}
'@
    }
} catch {}

function Add-WinwsToJob ($Proc) {
    if (-not $Proc) { return }
    try { [void][WinwsJob]::Assign($Proc.Handle) } catch {}
}

function Stop-Winws {
    for ($i = 0; $i -lt 10; $i++) {
        $Procs = @(Get-Process -Name "winws" -ErrorAction SilentlyContinue)
        if ($Procs.Count -eq 0) { return }
        $Procs | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 200
    }
    & taskkill.exe /F /T /IM winws.exe *> $null
}

function Stop-WinDivert {
    $Names = @("WinDivert", "WinDivert14")
    foreach ($Name in $Names) { & sc.exe stop $Name *> $null }
    for ($i = 0; $i -lt 20; $i++) {
        $Busy = $false
        foreach ($Name in $Names) {
            $Q = & sc.exe query $Name 2>$null | Out-String
            if ($Q -match "RUNNING|STOP_PENDING") { $Busy = $true }
        }
        if (-not $Busy) { break }
        Start-Sleep -Milliseconds 250
    }
    foreach ($Name in $Names) { & sc.exe delete $Name *> $null }
}

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

$global:IpTask = $null
$global:IpSource = 0
$global:IpOk = $false
$global:IpAttempts = 0
$global:LastIpAttempt = [DateTime]::MinValue
$global:CurrentExternalIp = ""

function Start-IpLookup ($Source = 0) {
    $global:IpSource = $Source
    $global:LastIpAttempt = [DateTime]::Now
    try {
        if (-not ("System.Net.Http.HttpClient" -as [type])) { Add-Type -AssemblyName System.Net.Http }
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        if (-not $global:IpHttp) {
            $global:IpHttp = New-Object System.Net.Http.HttpClient
            $global:IpHttp.Timeout = [TimeSpan]::FromSeconds(4)
        }
        $Url = if ($Source -eq 0) { "https://1.1.1.1/cdn-cgi/trace" } else { "https://ipinfo.io/json" }
        $global:IpTask = $global:IpHttp.GetStringAsync($Url)
    } catch {
        $global:IpTask = $null
    }
}

# Non-blocking: starts a fresh lookup; the result is picked up by Receive-IpLookup
function Update-CachedExternalIp {
    $global:IpOk = $false
    $global:IpAttempts = 0
    $global:Ip6Fallback = $null
    $global:CurrentExternalIp = "определение..."
    Start-IpLookup 0
}

# Returns $true when the displayed value changed
function Receive-IpLookup {
    if (-not $global:IpTask -or -not $global:IpTask.IsCompleted) { return $false }
    $Task = $global:IpTask
    $global:IpTask = $null
    $Text = $null
    try { if (-not $Task.IsFaulted -and -not $Task.IsCanceled) { $Text = $Task.Result } } catch {}
    
    if ($Text) {
        if ($global:IpSource -eq 0 -and $Text -match "(?m)^ip=(\S+)") {
            $Ip = $Matches[1]
            $Loc = if ($Text -match "(?m)^loc=(\S+)") { $Matches[1] } else { "" }
            $Warp = if ($Text -match "(?m)^warp=(\w+)") { $Matches[1] } else { "" }
            $Tag = if ($Warp -eq "plus") { " [WARP+]" } elseif ($Warp -eq "on") { " [WARP]" } elseif ($Warp -eq "off") { " [напрямую]" } else { "" }
            $Shown = if ($Loc) { "$Ip ($Loc)$Tag" } else { "$Ip$Tag" }
            if ($Ip -notmatch ":") {
                $global:CurrentExternalIp = $Shown
                $global:IpOk = $true
                return $true
            }
            # IPv6 answer: remember it, but prefer an IPv4 address from the fallback source
            $global:Ip6Fallback = $Shown
        }
        if ($global:IpSource -eq 1) {
            try {
                $Info = $Text | ConvertFrom-Json
                if ($Info.ip) {
                    $global:CurrentExternalIp = if ($Info.country) { "$($Info.ip) ($($Info.country))" } else { "$($Info.ip)" }
                    $global:IpOk = $true
                    return $true
                }
            } catch {}
        }
    }
    
    if ($global:IpSource -eq 0) {
        Start-IpLookup 1
        return $false
    }
    if ($global:Ip6Fallback) {
        $global:CurrentExternalIp = $global:Ip6Fallback
        $global:IpOk = $true
        return $true
    }
    $global:CurrentExternalIp = "не определён"
    return $true
}

# Blocking helper for one-off flows (waits until the address is known or the time is up)
function Wait-ExternalIp ($Seconds = 20) {
    $End = [DateTime]::Now.AddSeconds($Seconds)
    while ([DateTime]::Now -lt $End) {
        [void](Receive-IpLookup)
        if ($global:IpOk) { return }
        if (-not $global:IpTask -and ([DateTime]::Now - $global:LastIpAttempt).TotalSeconds -ge 2) { Start-IpLookup 0 }
        Start-Sleep -Milliseconds 200
    }
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

$DefaultConfig = @{ AutoPreset = $false; LastPreset = ""; AutoPresetTimeout = 3; AutoPing = 1; DnsFix = $false; IgnoredVersion = "0.0"; AutoUpdate = $true; PingInterval = 30; WarpLicense = "" }

$FirstRun = -not (Test-Path $ConfigPath)
if (-not $FirstRun) {
    try { 
        $Config = Get-Content $ConfigPath -Raw | ConvertFrom-Json 
        foreach ($Key in $DefaultConfig.Keys) {
            if (-not (Get-Member -InputObject $Config -Name $Key)) {
                Add-Member -InputObject $Config -NotePropertyName $Key -NotePropertyValue $DefaultConfig[$Key]
            }
        }
        
        if ($Config.AutoPing -is [bool]) {
            if ($Config.AutoPing) { $Config.AutoPing = 1 } else { $Config.AutoPing = 0 }
        }
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

function Wait-Enter {
    Write-Host " Нажмите Enter для продолжения..." -ForegroundColor Gray
    Read-Host | Out-Null
}

function Set-WarpLicense ($Key) {
    if (-not $Key -or -not (Test-Path $WarpCli)) { return $false }
    & $WarpCli --accept-tos registration license $Key 2>&1 | Out-Null
    return ($LASTEXITCODE -eq 0)
}

function Save-Config { $Config | ConvertTo-Json | Set-Content $ConfigPath }

function Start-DownloadWithProgress {
    param(
        [string]$Uri,
        [string]$OutFile,
        [string]$Label = "Загрузка файла"
    )
    
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $Request = [System.Net.HttpWebRequest]::Create($Uri)
        $Request.UserAgent = "WarpBypass"
        $Request.Timeout = 20000
        
        $Response = $Request.GetResponse()
        $TotalBytes = $Response.ContentLength
        $Stream = $Response.GetResponseStream()
        $FileStream = New-Object IO.FileStream($OutFile, [IO.FileMode]::Create)
        
        $Buffer = New-Object byte[] 65536
        $DownloadedBytes = 0
        
        try { [console]::CursorVisible = $false } catch {}
        $Left = 0; $Top = 0
        try {
            $Left = [console]::CursorLeft
            $Top = [console]::CursorTop
        } catch {}
        
        while (($Read = $Stream.Read($Buffer, 0, $Buffer.Length)) -gt 0) {
            $FileStream.Write($Buffer, 0, $Read)
            $DownloadedBytes += $Read
            
            if ($TotalBytes -gt 0) {
                $Percent = ($DownloadedBytes / $TotalBytes) * 100
                $PercentInt = [int]$Percent
                
                $BarWidth = 20
                $Filled = [int]($PercentInt * $BarWidth / 100)
                $Empty = $BarWidth - $Filled
                $Bar = ("█" * $Filled) + ("░" * $Empty)
                
                $TotalMb = [math]::Round($TotalBytes / 1MB, 1)
                $CurrentMb = [math]::Round($DownloadedBytes / 1MB, 1)
                
                try { [console]::SetCursorPosition($Left, $Top) } catch {}
                Write-Host "-> ${Label}: [$Bar] $PercentInt% ($CurrentMb MB / $TotalMb MB)   " -ForegroundColor Cyan -NoNewline
            } else {
                $CurrentMb = [math]::Round($DownloadedBytes / 1MB, 1)
                try { [console]::SetCursorPosition($Left, $Top) } catch {}
                Write-Host "-> ${Label}: $CurrentMb MB загружено...   " -ForegroundColor Cyan -NoNewline
            }
        }
        
        try { [console]::SetCursorPosition($Left, $Top) } catch {}
        if ($TotalBytes -gt 0) {
            $TotalMb = [math]::Round($TotalBytes / 1MB, 1)
            Write-Host "-> ${Label}: [████████████████████] 100% ($TotalMb MB / $TotalMb MB)   " -ForegroundColor Green
        } else {
            Write-Host "-> ${Label}: Завершено!   " -ForegroundColor Green
        }
    }
    catch {
        throw $_
    }
    finally {
        if ($FileStream) { $FileStream.Close(); $FileStream.Dispose() }
        if ($Stream) { $Stream.Close(); $Stream.Dispose() }
        if ($Response) { $Response.Close() }
        try { [console]::CursorVisible = $true } catch {}
    }
}


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
    Write-Host "                 МАСТЕР ПЕРВОНАЧАЛЬНОЙ НАСТРОЙКИ" -ForegroundColor Cyan
    Write-Host "=========================================================" -ForegroundColor DarkGray
    Write-Host " Приветствуем! WarpBypass поможет обойти блокировки через Cloudflare Warp." -ForegroundColor Gray
    Write-Host " Давайте настроим утилиту под ваши предпочтения за 2 шага." -ForegroundColor Gray
    Write-Host "=========================================================" -ForegroundColor DarkGray
    Write-Host ""
    
    # Шаг 1: Базовые настройки
    Write-Host " [Шаг 1 из 2] Базовые настройки системы:" -ForegroundColor White
    $DnsFixChoice = Read-Host " 1. Очищать кэш DNS при каждом запуске? (Y/N) [Рекомендуется: Y]"
    if ($DnsFixChoice -match "^[NnНн]") { $Config.DnsFix = $false } else { $Config.DnsFix = $true }
    
    $UpdateChoice = Read-Host " 2. Проверять и скачивать обновления автоматически? (Y/N) [Рекомендуется: Y]"
    if ($UpdateChoice -match "^[NnНн]") { $Config.AutoUpdate = $false } else { $Config.AutoUpdate = $true }
    
    # Шаг 2: Стратегия обхода
    Clear-Host
    Write-Header
    Write-Host "                 СТРАТЕГИЯ ОБХОДА" -ForegroundColor Cyan
    Write-Host "=========================================================" -ForegroundColor DarkGray
    Write-Host " Необходимо выбрать профиль работы службы Zapret." -ForegroundColor Gray
    Write-Host " Для разных интернет-провайдеров подходят разные профили." -ForegroundColor Gray
    Write-Host ""
    Write-Host " Выберите вариант:" -ForegroundColor White
    Write-Host "   1. Включить рекомендуемый профиль (general ALT12)" -ForegroundColor Green
    Write-Host "   2. Настроить вручную в главном меню программы" -ForegroundColor Gray
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
if (-not $IsOnline) {
    # ICMP is often blocked: fall back to a TCP connect
    try {
        $Tcp = New-Object System.Net.Sockets.TcpClient
        if ($Tcp.ConnectAsync("api.github.com", 443).Wait(2500)) { $IsOnline = $true }
        $Tcp.Close()
    } catch { }
}

function Check-AppUpdate {
    if (-not $IsOnline) { return }
    Write-Host "-> Проверка обновлений WarpBypass..." -ForegroundColor Gray
    
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $ReleaseInfo = Invoke-RestMethod -Uri $RepoApiUrl -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
 
        $RemoteVersionStr = ($ReleaseInfo.tag_name -replace '(?i)^v', '') -replace '[-+].*$', ''
        $RemoteVer = [version]$RemoteVersionStr
        $LocalVer  = [version]$AppVersion
 
        if ($RemoteVer -gt $LocalVer) {
            if ($Config.IgnoredVersion -ne $RemoteVersionStr) {
                Write-Host ""
                Write-Host "=========================================================" -ForegroundColor Yellow
                Write-Host " Доступна новая версия WarpBypass: v$RemoteVersionStr (Текущая: v$AppVersion)" -ForegroundColor Green
                Write-Host "=========================================================" -ForegroundColor Yellow
                $UpdateChoice = Read-Host "Инициировать процесс обновления прямо сейчас? (Y/N)"
                
                if ($UpdateChoice -match "^[YyДд]") {
                    $DownloadUrl = "https://raw.githubusercontent.com/BushHub/WarpBypass/$($ReleaseInfo.tag_name)/WarpBypass.bat"
                    $BatPath = $env:WARP_BAT_PATH
                    $TempFile = "$env:TEMP\WarpBypass_new.bat"
                    $UpdaterBat = "$env:TEMP\WarpBypass_updater.bat"
                    
                    Start-DownloadWithProgress -Uri $DownloadUrl -OutFile $TempFile -Label "Загрузка обновления"
                    $NewText = Get-Content -LiteralPath $TempFile -Raw -Encoding UTF8
                    $Expected = $null
                    try {
                        $HashText = (Invoke-WebRequest -Uri "$DownloadUrl.sha256" -UseBasicParsing -TimeoutSec 5).Content
                        $Expected = (([string]$HashText).Trim() -split '\s+')[0]
                    } catch {}
                    $Valid = ($NewText -match '^\s*<# : RUN') -and ($NewText -match ('\$AppVersion = "' + [regex]::Escape($RemoteVersionStr) + '"'))
                    if ($Valid -and $Expected) {
                        $Valid = ((Get-FileHash -LiteralPath $TempFile -Algorithm SHA256).Hash -eq $Expected)
                    }
                    if (-not $Valid) {
                        Remove-Item -LiteralPath $TempFile -ErrorAction SilentlyContinue
                        Write-Host "-> Загруженный файл не прошёл проверку, обновление отменено." -ForegroundColor Red
                        Start-Sleep -Seconds 2
                        return
                    }
                    Write-Host "-> Установка пакета обновления..." -ForegroundColor Cyan
                    
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
        } else {
            Write-Host "-> Установлена последняя актуальная версия." -ForegroundColor Green
            Start-Sleep -Milliseconds 600
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
    
    $WinwsPath = if (Test-Path "$ZapretDir\bin\winws.exe") { "$ZapretDir\bin\winws.exe" } else { "" }
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
                $LocalSHA = if (Test-Path $VersionFile) { (Get-Content $VersionFile).Trim() } else { "" }
                if ($LocalSHA -ne $global:LatestSHA) { $NeedUpdate = $true } else { Out-File -FilePath $LastCheckFile -InputObject ($Today.ToString()) -Force }
            } catch { Write-Host "-> Ошибка проверки зависимостей. Используется локальный кэш." -ForegroundColor DarkGray }
        }
    }
    
    if ($NeedUpdate) {
        # Make sure no running winws is locking files
        try { Stop-Winws } catch {}
        Start-Sleep -Milliseconds 500
        
        $TmpDir = "$StorageDir\zapret_tmp"
        try {
            Start-DownloadWithProgress -Uri $ZapretUrl -OutFile $ZapretZip -Label "Загрузка компонентов Zapret"
            if (Test-Path $TmpDir) { Remove-Item $TmpDir -Recurse -Force -ErrorAction SilentlyContinue }
            Expand-Archive -Path $ZapretZip -DestinationPath $TmpDir -Force
            $ExtractedDir = Get-ChildItem -Path $TmpDir -Directory | Where-Object { $_.Name -like "zapret-discord-youtube*" } | Select-Object -First 1
            if (-not $ExtractedDir -or -not (Test-Path "$($ExtractedDir.FullName)\bin\winws.exe")) {
                throw "Архив не содержит ожидаемых файлов."
            }
            try { Stop-WinDivert } catch {}
            if (Test-Path $ZapretDir) { Remove-Item $ZapretDir -Recurse -Force -ErrorAction Stop }
            New-Item -ItemType Directory -Path $ZapretDir -Force | Out-Null
            Copy-Item -Path "$($ExtractedDir.FullName)\*" -Destination $ZapretDir -Recurse -Force
            if ($global:LatestSHA) { Out-File -FilePath $VersionFile -InputObject $global:LatestSHA -Force; Out-File -FilePath $LastCheckFile -InputObject ((Get-Date).ToString()) -Force }
            $global:ZapretEnvBlock = $null
        } catch {
            Write-Host "-> Не удалось обновить компоненты Zapret: $($_.Exception.Message)" -ForegroundColor Red
            if (-not (Test-Path "$ZapretDir\bin\winws.exe")) { Write-Host "   Компоненты Zapret не установлены, запуск профилей невозможен." -ForegroundColor Red }
            Start-Sleep -Seconds 2
        } finally {
            Remove-Item $ZapretZip -ErrorAction SilentlyContinue
            Remove-Item $TmpDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Get-ZapretArgs ($BatFile) {
    $GameFilterTCP = "12"
    $GameFilterUDP = "12"
    try {
        $EnvBlock = if ($global:ZapretEnvBlock) { $global:ZapretEnvBlock } else { $global:ZapretEnvBlock = cmd.exe /c "cd /d `"$ZapretDir`" && call service.bat load_game_filter && call service.bat load_user_lists && set"; $global:ZapretEnvBlock }
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
        $ArgsStr = ($ArgsStr -split "\r?\n")[0].Trim()
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
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $ver = (Invoke-WebRequest -Uri "$BypassListBaseUrl/ru_bypass_version.txt" -UseBasicParsing -TimeoutSec 5).Content -replace '[\s\r\n]',''
        return $ver
    } catch { return $null }
}

function Update-BypassLists {
    param([switch]$Force, [switch]$Silent)
    if (-not (Test-Path $BypassCacheDir)) { New-Item -ItemType Directory -Path $BypassCacheDir -Force | Out-Null }
    
    if (-not $Silent) { Write-Host "-> Проверка обновлений списка..." -ForegroundColor Yellow }
    $LocalVer  = Get-LocalBypassVersion
    $RemoteVer = Get-RemoteBypassVersion
    
    if ($null -eq $RemoteVer) {
        if (-not $Silent) {
            Write-Host "  Не удалось связаться с сервером обновлений." -ForegroundColor Red
            Write-Host "  Используется сохранённый список." -ForegroundColor DarkGray
        }
        return $false
    }
    
    if (-not $Force -and $LocalVer -eq $RemoteVer) {
        if (-not $Silent) { Write-Host "  Список актуален (v$RemoteVer)." -ForegroundColor Green }
        return $false
    }
    
    if (-not $Silent) {
        if ($LocalVer -and $LocalVer -ne $RemoteVer) {
            Write-Host "  Обновление: v$LocalVer -> v$RemoteVer" -ForegroundColor Cyan
        } elseif (-not $LocalVer) {
            Write-Host "  Загрузка списка (v$RemoteVer)..." -ForegroundColor Cyan
        } else {
            Write-Host "  Повторная загрузка списка (v$RemoteVer)..." -ForegroundColor Yellow
        }
    }
    
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri "$BypassListBaseUrl/ru_bypass_domain.txt" -OutFile "$BypassCacheDir\ru_bypass_domain.txt" -UseBasicParsing
        Invoke-WebRequest -Uri "$BypassListBaseUrl/ru_bypass_ip.txt"     -OutFile "$BypassCacheDir\ru_bypass_ip.txt"     -UseBasicParsing
        Set-Content -Path "$BypassCacheDir\ru_bypass_version.txt" -Value $RemoteVer -Encoding UTF8
        if (-not $Silent) { Write-Host "  Список обновлён до v$RemoteVer." -ForegroundColor Green }
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
    
    $Cli = if (Test-Path $WarpCli) { $WarpCli } else { "warp-cli" }
    $Running = [System.Collections.Generic.List[object]]::new()
    $Failures = [System.Collections.Generic.List[string]]::new()
    $Total = $CmdArgs.Count
    $Next = 0
    $Done = 0
    
    while ($Next -lt $Total -or $Running.Count -gt 0) {
        for ($i = $Running.Count - 1; $i -ge 0; $i--) {
            $Item = $Running[$i]
            if ($Item.Proc.HasExited) {
                [void]$Item.Out.Wait(500)
                [void]$Item.Err.Wait(500)
                if ($Item.Proc.ExitCode -ne 0) {
                    $Msg = ""
                    if ($Item.Err.IsCompleted -and $Item.Err.Result) { $Msg = $Item.Err.Result.Trim() }
                    if (-not $Msg -and $Item.Out.IsCompleted -and $Item.Out.Result) { $Msg = $Item.Out.Result.Trim() }
                    $Failures.Add("$($Item.Cmd) -> $Msg")
                }
                $Item.Proc.Dispose()
                $Running.RemoveAt($i)
                $Done++
            }
        }
        
        while ($Next -lt $Total -and $Running.Count -lt $ThrottleLimit) {
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = $Cli
            $psi.Arguments = "--accept-tos " + $CmdArgs[$Next]
            $psi.UseShellExecute = $false
            $psi.CreateNoWindow = $true
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError = $true
            $p = New-Object System.Diagnostics.Process
            $p.StartInfo = $psi
            try {
                [void]$p.Start()
                $Running.Add([PSCustomObject]@{ Proc = $p; Cmd = $CmdArgs[$Next]; Out = $p.StandardOutput.ReadToEndAsync(); Err = $p.StandardError.ReadToEndAsync() })
            } catch {
                $Failures.Add("$($CmdArgs[$Next]) -> не удалось запустить warp-cli")
                $Done++
            }
            $Next++
        }
        
        $percent = [math]::Round(($Done / [math]::Max(1, $Total)) * 100)
        Write-Host -NoNewline "`r   Применение: $percent% ($Done/$Total)"
        Start-Sleep -Milliseconds 30
    }
    
    Write-Host ""
    return ,$Failures.ToArray()
}

function Apply-RuBypassTemplate {
    $DomainFile = "$BypassCacheDir\ru_bypass_domain.txt"
    $IpFile     = "$BypassCacheDir\ru_bypass_ip.txt"
    
    # Ensure lists exist, download if needed
    if (-not (Test-Path $DomainFile) -or -not (Test-Path $IpFile)) {
        Write-Host "-> Загрузка списка сайтов и IP..." -ForegroundColor Yellow
        Update-BypassLists | Out-Null
    }
    
    if (-not (Test-Path $DomainFile)) {
        Write-Host "❌ Не удалось загрузить список сайтов. Проверьте подключение к интернету." -ForegroundColor Red
        return
    }
    
    Write-Host "-> Подготовка правил..." -ForegroundColor Yellow
    
    $Domains  = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $IpRanges = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    
    foreach ($line in (Get-Content $DomainFile)) {
        $line = $line.Trim()
        if ($line -eq "" -or $line.StartsWith("#")) { continue }
        if ($line -notmatch '^(\*\.)?[^\s/\\"''&|<>]+$') { continue }
        $Domains.Add($line) | Out-Null
    }
    
    if (Test-Path $IpFile) {
        foreach ($line in (Get-Content $IpFile)) {
            $line = $line.Trim()
            if ($line -eq "" -or $line.StartsWith("#")) { continue }
            if ($line -match "^(\d{1,3}(\.\d{1,3}){3})(/(\d{1,2}))?$" -and [ipaddress]::TryParse($Matches[1], [ref]$null) -and (-not $Matches[4] -or [int]$Matches[4] -le 32)) {
                $IpRanges.Add($line) | Out-Null
            }
        }
    }
    
    # Drop entries already covered by a "*.tld" wildcard (e.g. *.ru covers foo.ru)
    $WildTails = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($d in $Domains) { if ($d -match '^\*\.([^.]+)$') { $WildTails.Add($Matches[1]) | Out-Null } }
    $Covered = @()
    foreach ($d in $Domains) {
        if ($d -notmatch '^\*\.[^.]+$' -and $WildTails.Contains($d.Substring($d.LastIndexOf('.') + 1))) { $Covered += $d }
    }
    foreach ($d in $Covered) { $Domains.Remove($d) | Out-Null }
    
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
        Write-Host "-> Добавление правил в WARP: $($Cmds.Count) шт...." -ForegroundColor Yellow
        $Failures = @(Invoke-ParallelWarpCli -CmdArgs $Cmds.ToArray() -ThrottleLimit 30)
        if ($Failures.Count -gt 0) {
            Write-Host "-> Не удалось добавить правил: $($Failures.Count)" -ForegroundColor Red
            foreach ($F in ($Failures | Select-Object -First 5)) { Write-Host "   $F" -ForegroundColor DarkGray }
        }
        $WasConnected = ((Get-WarpStatus) -eq "Connected")
        
        if ($WasConnected -and -not $global:TunnelPaused) {
            Write-Host "-> Переподключение туннеля WARP для применения правил..." -ForegroundColor Yellow
            Restart-WarpConnection
        }
        $global:CachedWarpStatus = $null
        Write-Host "✅ Правила «Россия напрямую» применены." -ForegroundColor Green
    } else {
        Write-Host "✅ Правила уже применены, добавлять нечего." -ForegroundColor Green
    }
}

function Get-SplitTunnelEntries {
    $Result = [PSCustomObject]@{ Hosts = @(); Ips = @() }
    $File = "C:\ProgramData\Cloudflare\settings.json"
    if (-not (Test-Path $File)) { return $Result }
    try {
        $Settings = Get-Content $File -Raw -Encoding UTF8 | ConvertFrom-Json
        $SystemIps = [System.Collections.Generic.HashSet[string]]::new([string[]]@(
            "10.0.0.0/8", "100.64.0.0/10", "169.254.0.0/16", "172.16.0.0/12",
            "192.0.0.0/24", "192.168.0.0/16", "224.0.0.0/24", "240.0.0.0/4",
            "239.255.255.250/32", "255.255.255.255/32", "fe80::/10",
            "fd00::/8", "ff01::/16", "ff02::/16", "ff03::/16", "ff04::/16",
            "ff05::/16", "fc00::/7", "2620:149:a44::/48", "2403:300:a42::/48",
            "2403:300:a51::/48", "2a01:b740:a42::/48"
        ), [System.StringComparer]::OrdinalIgnoreCase)
        $Hosts = @()
        if ($Settings.excluded_hosts) {
            foreach ($entry in $Settings.excluded_hosts) {
                $v = if ($entry -is [Array]) { $entry[0] } else { $entry }
                if ($v) { $Hosts += $v }
            }
        }
        $Ips = @()
        if ($Settings.excluded_ips) {
            foreach ($entry in $Settings.excluded_ips) {
                $v = if ($entry -is [Array]) { $entry[0] } else { $entry }
                if ($v -and -not $SystemIps.Contains($v)) { $Ips += $v }
            }
        }
        $Result.Hosts = $Hosts
        $Result.Ips = $Ips
    } catch {}
    return $Result
}

function Show-SplitTunnelSettings {
    while ($true) {
        $LocalVer = Get-LocalBypassVersion
        $Entries  = Get-SplitTunnelEntries
        $HostCount = @($Entries.Hosts).Count
        $IpCount   = @($Entries.Ips).Count
        
        Clear-Host
        Write-Header
        Write-Host "               МАРШРУТИЗАЦИЯ: РОССИЯ НАПРЯМУЮ" -ForegroundColor Cyan
        Write-Host "=========================================================" -ForegroundColor DarkGray
        Write-Host " Российские сайты и IP-адреса идут напрямую, без WARP:" -ForegroundColor Gray
        Write-Host " банки, Госуслуги и другие сервисы работают как обычно." -ForegroundColor Gray
        Write-Host "=========================================================" -ForegroundColor DarkGray
        Write-Host " Состояние : " -NoNewline -ForegroundColor White
        if ($HostCount + $IpCount -gt 0) {
            Write-Host "ВКЛЮЧЕНО (сайтов: $HostCount, IP-диапазонов: $IpCount)" -ForegroundColor Green
        } else {
            Write-Host "ВЫКЛЮЧЕНО" -ForegroundColor Red
        }
        Write-Host " Список    : " -NoNewline -ForegroundColor White
        if ($LocalVer) { Write-Host "версия $LocalVer" -ForegroundColor Gray } else { Write-Host "не загружен" -ForegroundColor DarkGray }
        Write-Host "=========================================================" -ForegroundColor DarkGray
        Write-Host " [1] Включить (применить правила)" -ForegroundColor Green
        Write-Host " [2] Обновить список сайтов и IP" -ForegroundColor Yellow
        Write-Host " [3] Показать действующие правила" -ForegroundColor White
        Write-Host " [4] Выключить (удалить все правила)" -ForegroundColor Red
        Write-Host " [0] Назад" -ForegroundColor Gray
        Write-Host "=========================================================" -ForegroundColor DarkGray
        
        $sel = Read-Host "Выберите вариант"
        switch ($sel.Trim()) {
            "1" {
                Apply-RuBypassTemplate
                Read-Host "Нажмите Enter для возврата..." | Out-Null
            }
            "2" {
                Write-Host ""
                Update-BypassLists -Force | Out-Null
                Read-Host "Нажмите Enter для возврата..." | Out-Null
            }
            "3" {
                Clear-Host
                Write-Header
                Write-Host "                 ДЕЙСТВУЮЩИЕ ПРАВИЛА" -ForegroundColor Cyan
                Write-Host "=========================================================" -ForegroundColor DarkGray
                Write-Host "--- Сайты: $HostCount ---" -ForegroundColor Yellow
                if ($HostCount -gt 0) {
                    $Entries.Hosts | Select-Object -First 15 | ForEach-Object { Write-Host "  $_" -ForegroundColor Green }
                    if ($HostCount -gt 15) { Write-Host "  ... и ещё $($HostCount - 15)" -ForegroundColor DarkGray }
                } else {
                    Write-Host "  (нет)" -ForegroundColor DarkGray
                }
                Write-Host "`n--- IP-диапазоны: $IpCount ---" -ForegroundColor Yellow
                if ($IpCount -gt 0) {
                    $Entries.Ips | Select-Object -First 15 | ForEach-Object { Write-Host "  $_" -ForegroundColor Cyan }
                    if ($IpCount -gt 15) { Write-Host "  ... и ещё $($IpCount - 15)" -ForegroundColor DarkGray }
                } else {
                    Write-Host "  (нет)" -ForegroundColor DarkGray
                }
                Write-Host "=========================================================" -ForegroundColor DarkGray
                Read-Host "Нажмите Enter для возврата..." | Out-Null
            }
            "4" {
                $Confirm = Read-Host "Удалить все правила и пускать весь трафик через WARP? (Y/N)"
                if ($Confirm -match "^[YyДд]") {
                    Write-Host "-> Удаление правил..." -ForegroundColor Yellow
                    & $WarpCli --accept-tos tunnel host reset | Out-Null
                    & $WarpCli --accept-tos tunnel ip reset | Out-Null
                    Write-Host "Правила удалены." -ForegroundColor Green
                    if ((Get-CachedWarpStatus) -eq "Connected") {
                        Write-Host "-> Переподключение туннеля WARP..." -ForegroundColor Yellow
                        Restart-WarpConnection
                    }
                    Start-Sleep -Seconds 2
                }
            }
            "0" { return }
        }
    }
}

function Test-TlsHandshake ($Server, $TimeoutMs = 2500) {
    $Client = New-Object System.Net.Sockets.TcpClient
    $Ssl = $null
    try {
        $Watch = [System.Diagnostics.Stopwatch]::StartNew()
        $Task = $Client.ConnectAsync($Server, 443)
        if (-not $Task.Wait($TimeoutMs)) { return $null }
        $Left = [math]::Max(500, $TimeoutMs - [int]$Watch.ElapsedMilliseconds)
        $Ssl = New-Object System.Net.Security.SslStream($Client.GetStream(), $false)
        $Ar = $Ssl.BeginAuthenticateAsClient($Server, $null, [System.Security.Authentication.SslProtocols]::Tls12, $false, $null, $null)
        if (-not $Ar.AsyncWaitHandle.WaitOne($Left)) { return $null }
        $Ssl.EndAuthenticateAsClient($Ar)
        return [math]::Round($Watch.Elapsed.TotalMilliseconds)
    } catch {
        return $null
    } finally {
        if ($Ssl) { $Ssl.Dispose() }
        $Client.Close()
    }
}

function Start-Benchmark {
    Clear-Host
    Write-Header
    Write-Host "         АВТО-ПОДБОР СТРАТЕГИИ МАСКИРОВКИ" -ForegroundColor Cyan
    Write-Host "=========================================================" -ForegroundColor DarkGray
    Write-Host " Утилита автоматически переберет разные профили работы Zapret и измерит связь с популярными сайтами." -ForegroundColor Gray
    Write-Host " Мы определим, какой профиль работает быстрее и стабильнее всего в вашей сети." -ForegroundColor Gray
    Write-Host " Ожидайте, это займет около минуты..." -ForegroundColor Gray
    Write-Host "=========================================================" -ForegroundColor DarkGray
    
    $ZapretDirFullName = if (Test-Path $ZapretDir) { (Get-Item $ZapretDir).FullName } else { "" }
    if (-not $ZapretDirFullName) {
        Write-Host "❌ Ошибка: Папка компонентов zapret не найдена." -ForegroundColor Red
        Wait-Enter; return
    }
    
    $WasConnected = ((Get-WarpStatus) -eq "Connected")
    
    # Exclude service.bat, service_install.bat, and service_remove.bat
    $BatFiles = Get-ChildItem -Path $ZapretDirFullName -Filter "*.bat" | Where-Object { $_.Name -notmatch "(?i)service(_install|_remove)?\.bat$" }
    if ($BatFiles.Count -eq 0) {
        Write-Host "❌ Ошибка: Файлы пресетов не найдены." -ForegroundColor Red
        Wait-Enter; return
    }
    
    if (Test-Path $WarpCli) {
        & $WarpCli --accept-tos disconnect *> $null
    }
    
    # Clean previous winws processes
    Stop-Winws
    
    $TestTargets = @("www.youtube.com", "discord.com", "gateway.discord.gg", "i.ytimg.com")
    $Results = @()
    foreach ($File in $BatFiles) {
        $FileName = $File.Name
        Write-Host " -> Тестирование [$FileName]... " -NoNewline -ForegroundColor Gray
        
        $ArgsStr = Get-ZapretArgs $File.FullName
        $ZapretJob = $null
        if ($null -ne $ArgsStr) {
            $WinwsPath = "$ZapretDir\bin\winws.exe"
            $ZapretJob = Start-Process -FilePath $WinwsPath -ArgumentList $ArgsStr -WorkingDirectory "$ZapretDir\bin" -WindowStyle Hidden -PassThru
            Add-WinwsToJob $ZapretJob
        } else {
            $ZapretJob = Start-Process -FilePath $File.FullName -WorkingDirectory (Split-Path $File.FullName) -WindowStyle Hidden -PassThru
            Add-WinwsToJob $ZapretJob
        }
        
        Start-Sleep -Seconds 3
        
        $Pings = @()
        $SuccessCount = 0
        foreach ($Target in $TestTargets) {
            $Ms = Test-TlsHandshake $Target 2500
            if ($null -ne $Ms) { $Pings += $Ms; $SuccessCount++ }
        }
        
        # Synchronously stop running winws and wait until port and WinDivert driver are freed
        if ($ZapretJob) { Stop-Process -Id $ZapretJob.Id -Force -ErrorAction SilentlyContinue *> $null }
        Stop-Winws
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
        Write-Host " (обход: $($Best.SuccessRate)/$($TestTargets.Count) узлов, средний пинг: $($Best.Ping) ms)" -ForegroundColor White
        Write-Host ""
        $SaveChoice = Read-Host " Применить выбранную стратегию как основную для автозапуска? (Y/N)"
        if ($SaveChoice -match "^[YyДд]") {
            $Config.LastPreset = $Best.Preset
            $Config.AutoPreset = $true
            Save-Config
            Write-Host " Настройки сохранены!" -ForegroundColor Green
        }
    } else {
        Write-Host "❌ Тестирование завершено: ни одна из стратегий не вернула успешный пинг." -ForegroundColor Red
    }
    if ($WasConnected -and $global:ActivePreset) {
        Write-Host " -> Восстановление активного сеанса..." -ForegroundColor Yellow
        Connect-WarpTunnel $global:ActivePreset | Out-Null
        $global:CachedWarpStatus = $null
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
                $Confirm = Read-Host "Восстановить стандартные параметры проверки хостов? (Y/N)"
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
    Write-Host "              УДАЛЕНИЕ УТИЛИТЫ WARPBYPASS ИЗ СИСТЕМЫ" -ForegroundColor Red
    Write-Host "=========================================================" -ForegroundColor DarkGray
    
    Write-Host "-> Завершение фоновых модулей маскировки трафика..." -ForegroundColor Yellow
    try { Stop-Winws } catch {}
    try { Stop-WinDivert } catch {}
    Start-Sleep -Seconds 1
    

    
    Write-Host "-> Восстановление настроек Cloudflare WARP..." -ForegroundColor Yellow
    if (Test-Path $WarpCli) {
        & $WarpCli --accept-tos disconnect *> $null
        & $WarpCli --accept-tos mode warp *> $null
        & $WarpCli --accept-tos tunnel host reset *> $null
        & $WarpCli --accept-tos tunnel ip reset *> $null
    }
    try {
        Set-Service -Name "CloudflareWARP" -StartupType Automatic -ErrorAction SilentlyContinue | Out-Null
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
        "while (Get-Process -Id $MyPID -ErrorAction SilentlyContinue) { Start-Sleep 1 }; for (`$i = 0; `$i -lt 15 -and (Test-Path -LiteralPath '$($StorageDir.Replace("'","''"))'); `$i++) { Remove-Item -LiteralPath '$($StorageDir.Replace("'","''"))' -Recurse -Force -ErrorAction SilentlyContinue; Start-Sleep 1 }"
    )
    Start-Process powershell -ArgumentList $CmdArgs -WindowStyle Hidden
    
    Write-Host "=========================================================" -ForegroundColor DarkGray
    Write-Host " Программа успешно удалена." -ForegroundColor Green
    Write-Host " Службы и конфигурационные папки очищены." -ForegroundColor Gray
    Write-Host " Спасибо за использование WarpBypass!" -ForegroundColor Gray
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
        Write-Host " [5] Лицензионный ключ WARP+       : " -NoNewline; if ($Config.WarpLicense) { Write-Host "ЗАДАН" -ForegroundColor Green } else { Write-Host "НЕ ЗАДАН" -ForegroundColor Red }
        Write-Host "=========================================================" -ForegroundColor DarkGray
        Write-Host " [U] Стереть утилиту WarpBypass из системы" -ForegroundColor Red
        Write-Host " [D] Восстановить настройки по умолчанию" -ForegroundColor Red
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
            "5" {
                $Sec = Read-Host "Ключ WARP+ (xxxxxxxx-xxxxxxxx-xxxxxxxx, пусто - удалить)" -AsSecureString
                $Bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Sec)
                try { $Key = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($Bstr).Trim() } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($Bstr) }
                if ($Key -eq "") {
                    $Config.WarpLicense = ""
                    Save-Config
                    Write-Host "Ключ удалён из настроек. Уже применённый ключ действует до перерегистрации." -ForegroundColor Yellow
                } elseif ($Key -notmatch "^[A-Za-z0-9]{8}-[A-Za-z0-9]{8}-[A-Za-z0-9]{8}$") {
                    Write-Host "Некорректный формат ключа." -ForegroundColor Red
                } else {
                    $Config.WarpLicense = $Key
                    Save-Config
                    if (Set-WarpLicense $Key) {
                        Write-Host "Ключ принят клиентом WARP." -ForegroundColor Green
                        if ((Get-WarpStatus) -eq "Connected" -and -not $global:TunnelPaused) {
                            Write-Host "-> Переподключение для проверки ключа..." -ForegroundColor Yellow
                            Restart-WarpConnection
                            Wait-ExternalIp 15
                            if ($global:CurrentExternalIp -match "WARP\+") {
                                Write-Host "WARP+ активен." -ForegroundColor Green
                            } else {
                                Write-Host "Ключ принят, но WARP+ не активен (аккаунт Free): ключ недействителен или исчерпан лимит устройств." -ForegroundColor Yellow
                            }
                        } else {
                            Write-Host "Проверить ключ можно после подключения: в строке IP-адреса появится [WARP+]." -ForegroundColor Gray
                        }
                    } else {
                        Write-Host "Клиент WARP не принял ключ (неверный, уже использован или исчерпан лимит устройств)." -ForegroundColor Red
                        Write-Host "Ключ сохранён и будет повторно применён при следующей регистрации." -ForegroundColor Gray
                    }
                }
                Start-Sleep -Seconds 4
            }
            "u" {
                $Confirm = Read-Host "ВНИМАНИЕ: Все файлы конфигурации и зависимости программы будут безвозвратно удалены. Продолжить? (Y/N)"
                if ($Confirm.Trim().ToLower() -match "^[yд]") {
                    Uninstall-WarpBypass
                }
            }
            "d" {
                $Confirm = Read-Host "Восстановить настройки по умолчанию? (Y/N)"
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
        Write-Host "                 КОНФИГУРАЦИЯ" -ForegroundColor Cyan
        Write-Host "=========================================================" -ForegroundColor DarkGray
        Write-Host " [1] Статистика и метрики WARP" -ForegroundColor White
        Write-Host " [2] Настройки диагностики и пинга" -ForegroundColor White
        Write-Host " [3] Управление Split Tunneling (Маршрутизация)" -ForegroundColor White
        Write-Host " [4] Общие настройки" -ForegroundColor White
        Write-Host " [B] Авто-подбор стратегии маскировки" -ForegroundColor Yellow
        Write-Host "=========================================================" -ForegroundColor DarkGray
        Write-Host " [D] Сброс всех настроек по умолчанию" -ForegroundColor Red
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
                        Write-Host "                    СТАТИСТИКА WARP" -ForegroundColor Cyan
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
                            $OutTask = $Process.StandardOutput.ReadToEndAsync()
                            $ErrTask = $Process.StandardError.ReadToEndAsync()
                            if (-not $Process.WaitForExit(3000)) { $Process.Kill() }
                            $null = $OutTask.Wait(1000)
                            if ($OutTask.IsCompleted) { $StatsOutput = $OutTask.Result }
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
                                    $Bits = [double]$Matches[1]
                                    if ($Bits -ge 1e6) {
                                        $Speed = "$([math]::Round($Bits / 1e6, 1)) Мбит/с ($([math]::Round($Bits / 8e6, 1)) МБ/с)"
                                    } else {
                                        $Speed = "$([math]::Round($Bits / 1e3, 1)) Кбит/с"
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
                        if ($Key -ne "WarpLicense") { $Config.$Key = $DefaultConfig[$Key] }
                    }
                    Save-Config
                    if (Test-Path $WarpCli) {
                        & $WarpCli --accept-tos mode warp | Out-Null
                    }
                    Write-Host "Все настройки программы восстановлены по умолчанию!" -ForegroundColor Green
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
            $AsyncResult = $TcpClient.ConnectAsync($CleanDom, 443)
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
                if ($AsyncResult.IsFaulted -or -not $TcpClient.Connected) { throw "connect failed" }
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

function Start-Winws ($BatFile) {
    try { Stop-Winws } catch {}
    Write-Host "-> Запуск сетевого фильтра winws (в фоновом режиме)..." -ForegroundColor Yellow
    $ArgsStr = Get-ZapretArgs $BatFile
    if ($null -ne $ArgsStr) {
        $Job = Start-Process -FilePath "$ZapretDir\bin\winws.exe" -ArgumentList $ArgsStr -WorkingDirectory "$ZapretDir\bin" -WindowStyle Hidden -PassThru
    } else {
        $Job = Start-Process -FilePath $BatFile -WorkingDirectory (Split-Path $BatFile) -WindowStyle Hidden -PassThru
    }
    Add-WinwsToJob $Job
    for ($i = 0; $i -lt 20; $i++) {
        if (Get-Process -Name "winws" -ErrorAction SilentlyContinue) { break }
        Start-Sleep -Milliseconds 500
    }
    Start-Sleep -Seconds 1
    if (-not (Get-Process -Name "winws" -ErrorAction SilentlyContinue)) {
        Write-Host "-> Предупреждение: процесс winws не запущен (конфликт WinDivert или антивирус)." -ForegroundColor Red
    }
}

function Wait-WarpConnected ($Seconds = 30) {
    while ($Seconds -gt 0) {
        $WarpStatus = & $WarpCli --accept-tos status | Out-String
        if ($WarpStatus -and $WarpStatus.Contains("Connected") -and -not $WarpStatus.Contains("Connecting")) { return $true }
        Start-Sleep -Seconds 1
        $Seconds--
    }
    return $false
}

# Reconnect the tunnel: winws on -> reconnect -> winws off (winws is only needed while WARP is connecting)
function Restart-WarpConnection {
    $Preset = $global:ActivePreset
    if ($Preset) { Start-Winws $Preset }
    & $WarpCli --accept-tos disconnect | Out-Null
    Start-Sleep -Seconds 1
    & $WarpCli --accept-tos connect | Out-Null
    $Ok = Wait-WarpConnected 30
    if ($Preset) { try { Stop-Winws } catch {} }
    $global:CachedWarpStatus = $null
    if ($Ok) { Update-CachedExternalIp }
}

function Connect-WarpTunnel ($BatFile) {
    try { Stop-Service -Name "zapret" -Force -ErrorAction SilentlyContinue *> $null } catch {}
    try { Stop-Service -Name "goodbyedpi" -Force -ErrorAction SilentlyContinue *> $null } catch {}
    try { Stop-Winws } catch {}
    try { Stop-Process -Name "goodbyedpi" -Force -ErrorAction SilentlyContinue *> $null } catch {}

    if ($Config.DnsFix) {
        Write-Host "-> Сброс системного кэша адресов DNS..." -ForegroundColor Yellow
        ipconfig /flushdns | Out-Null
    }
    
    Start-Winws $BatFile
    
    if (-not (Test-Path $WarpCli)) {
        $WarpMsi = "$StorageDir\Cloudflare_WARP.msi"
        try {
            Start-DownloadWithProgress -Uri "https://downloads.cloudflareclient.com/v1/download/windows/ga" -OutFile $WarpMsi -Label "Загрузка Cloudflare WARP"
            Write-Host "-> Установка Cloudflare WARP..." -ForegroundColor Gray
            Start-Process msiexec.exe -ArgumentList "/i `"$WarpMsi`" /qn /norestart START_WPF_AS_USER=0" -Wait -NoNewWindow
            Remove-Item $WarpMsi -ErrorAction SilentlyContinue
            if (-not (Test-Path $WarpCli)) {
                Write-Host "`n❌ Критическая ошибка: Установка завершена, но исполняемый файл warp-cli.exe не найден." -ForegroundColor Red
                Wait-Enter; Exit
            }
            Write-Host "-> Служба Cloudflare WARP успешно зарегистрирована в системе." -ForegroundColor Green
            Start-Sleep -Seconds 2
        } catch {
            Write-Host "`n❌ Критическая ошибка: Сбой при загрузке или установке Cloudflare WARP." -ForegroundColor Red
            Wait-Enter; Exit
        }
    }
    
    Set-Service -Name "CloudflareWARP" -StartupType Manual -ErrorAction SilentlyContinue
    
    if (Test-Path $WarpCli) {
        & $WarpCli --accept-tos mode warp | Out-Null
    }
    
    Write-Host "-> Перезапуск сетевой службы Cloudflare WARP..." -ForegroundColor Yellow
    Stop-Service -Name "CloudflareWARP" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
    Start-Service -Name "CloudflareWARP" -ErrorAction SilentlyContinue
    Stop-Process -Name "Cloudflare WARP" -Force -ErrorAction SilentlyContinue
    
    # Wait for daemon to be ready (up to 8 seconds)
    Write-Host "-> Ожидание готовности интерфейса Cloudflare WARP..." -ForegroundColor Yellow
    $DaemonReady = $false
    for ($i = 0; $i -lt 16; $i++) {
        $StatusCheck = & $WarpCli --accept-tos status 2>&1 | Out-String
        if ($StatusCheck -and $StatusCheck -notmatch "(?i)Unable to connect|not running") {
            $DaemonReady = $true
            break
        }
        Start-Sleep -Milliseconds 500
    }
    
    Write-Host "-> Инициализация туннелирования трафика..." -ForegroundColor Yellow
    if (-not $DaemonReady) { Write-Host "-> Служба WARP не отвечает, регистрация пропущена." -ForegroundColor Red }
    $RegCheck = & $WarpCli --accept-tos registration show 2>$null | Out-String
    if ($DaemonReady -and (-not $RegCheck -or $RegCheck -match "(?i)error|not registered|No registration")) {
        Write-Host "-> Регистрация клиентского профиля в сети Cloudflare..." -ForegroundColor Yellow
        & $WarpCli --accept-tos registration new 2>$null | Out-Null
        if ($Config.WarpLicense) {
            Write-Host "-> Применение лицензионного ключа WARP+..." -ForegroundColor Yellow
            Set-WarpLicense $Config.WarpLicense | Out-Null
        }
    }
    & $WarpCli --accept-tos connect | Out-Null
    
    $Connected = Wait-WarpConnected 30
    
    # winws is only needed to get WARP connected
    try { Stop-Winws } catch {}
    
    if ($Connected) { Update-CachedExternalIp }
    return $Connected
}

function Show-ActiveSessionMenu ($CurrentInput, $TimerVal) {
    [console]::CursorVisible = $false
    [console]::SetCursorPosition(0, 0)
    
    Write-Header
    
    $WarpState = Get-CachedWarpStatus
    
    Write-Host " Статус соединения WARP : " -NoNewline -ForegroundColor White
    if ($global:TunnelPaused) {
        Write-Host "ПАУЗА                     " -ForegroundColor Yellow
    } else {
        switch ($WarpState.Trim()) {
            "Connected"     { Write-Host "ПОДКЛЮЧЕН                 " -ForegroundColor Green }
            "Connecting"    { Write-Host "ПОДКЛЮЧЕНИЕ...            " -ForegroundColor Yellow }
            "Disconnected"  { Write-Host "ОТКЛЮЧЕН                  " -ForegroundColor Red }
            "Disconnecting" { Write-Host "ОТКЛЮЧЕНИЕ...             " -ForegroundColor Yellow }
            "Paused"        { Write-Host "ПАУЗА                     " -ForegroundColor Yellow }
            default         { Write-Host "$($WarpState.PadRight(25))" -ForegroundColor Red }
        }
    }
    
    Write-Host " Внешний IP-адрес       : " -NoNewline -ForegroundColor White
    if ($global:TunnelPaused -or $WarpState.Trim() -ne "Connected") {
        Write-Host ("-".PadRight(31)) -ForegroundColor Gray
    } else {
        $DisplayIp = if ($global:CurrentExternalIp) { $global:CurrentExternalIp } else { "определение..." }
        Write-Host ($DisplayIp.PadRight(31)) -ForegroundColor Gray
    }
    
    if (-not $global:TunnelPaused -and $global:PingResults -and $global:PingResults.Count -gt 0) {
        Write-Host "=========================================================" -ForegroundColor DarkGray
        Write-Host " [ Доступность хостов (Ping) ]" -NoNewline -ForegroundColor Cyan
        if ($Config.AutoPing -eq 2) {
            if ($TimerVal -eq "измерение...") {
                Write-Host " (измерение...)            " -ForegroundColor Yellow
            } else {
                Write-Host " (следующий опрос через $($TimerVal) сек)   " -ForegroundColor Gray
            }
        } else {
            Write-Host "                                 " -ForegroundColor Gray
        }
        
        foreach ($Ping in $global:PingResults) {
            $DomName = $Ping.Domain
            if ($DomName.Length -gt 25) { $DomName = $DomName.Substring(0, 22) + "..." }
            Write-Host "  $($DomName.PadRight(25)) : " -NoNewline
            if ($Ping.Status -eq "OK") {
                Write-Host (("$($Ping.Latency) ms").PadRight(30)) -ForegroundColor Green
            } elseif ($Ping.Status -eq "Timeout") {
                Write-Host ("Превышено время ожидания".PadRight(30)) -ForegroundColor Red
            } else {
                Write-Host ("Узел недоступен".PadRight(30)) -ForegroundColor Red
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
    Write-Host " [I]  Сменить IP-адрес (перерегистрация)                 " -ForegroundColor Cyan
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
        if (Receive-IpLookup) { Show-ActiveSessionMenu $InputStr $TimeRemainingRef.Value }
        if (($Now - $LastTick).TotalSeconds -ge 1) {
            $LastTick = $Now
            if (-not $global:TunnelPaused -and -not $global:IpOk -and -not $global:IpTask -and $global:IpAttempts -lt 6 -and ([DateTime]::Now - $global:LastIpAttempt).TotalSeconds -ge 5 -and (Get-CachedWarpStatus).Trim() -eq "Connected") {
                $global:IpAttempts++
                Start-IpLookup 0
            }
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
                    if ((Get-CachedWarpStatus).Trim() -eq "Connected" -and -not $global:TunnelPaused) { Update-CachedExternalIp }
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
    $global:ActivePreset = $BatFile
    $Watchdog = $null
    
    $global:TunnelPaused = $false
    $TimeRemaining = $Config.PingInterval
    
    try {
        Clear-Host
        Write-Header
        
        $Success = Connect-WarpTunnel $BatFile
        if (-not $Success) {
            Write-Host "Ошибка: Отсутствует ответ от службы маршрутизации WARP." -ForegroundColor Red
            Wait-Enter; return $false
        }
        
        if ($Config.AutoPing -ne 0) {
            Write-Host "-> Диагностика задержки узлов (ожидайте)..." -ForegroundColor Yellow
            Measure-Latency
        }
        
        $MyPID = $PID
        $Watchdog = Start-Process powershell -PassThru -ArgumentList @('-NoProfile', '-WindowStyle', 'Hidden', '-Command', "while (Get-Process -Id $MyPID -ErrorAction SilentlyContinue) { Start-Sleep 1 }; Stop-Process -Name winws -Force -ErrorAction SilentlyContinue; & '$WarpCli' --accept-tos disconnect") -WindowStyle Hidden
        
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
                Write-Host "`nВы действительно хотите отключить соединение и закрыть программу? (Y/N)" -ForegroundColor Yellow
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
            elseif ($CleanInput -eq 'i') {
                Write-Host "`nКлиент WARP будет перерегистрирован, адрес может измениться. Продолжить? (Y/N)" -ForegroundColor Yellow
                $Ans = [console]::ReadKey($true).KeyChar.ToString().ToLower()
                if ($Ans -match "[yд]") {
                    $OldIp = if ($global:IpOk) { $global:CurrentExternalIp } else { "" }
                    $RestoreSplit = $false
                    $SettingsFile = "C:\ProgramData\Cloudflare\settings.json"
                    if (Test-Path $SettingsFile) {
                        try {
                            $Cur = Get-Content $SettingsFile -Raw -Encoding UTF8 | ConvertFrom-Json
                            if (($Cur.excluded_hosts -and @($Cur.excluded_hosts).Count -gt 0) -or ($Cur.excluded_ips -and @($Cur.excluded_ips).Count -gt 0)) { $RestoreSplit = $true }
                        } catch {}
                    }
                    Write-Host "-> Удаление текущей регистрации клиента WARP..." -ForegroundColor Yellow
                    & $WarpCli --accept-tos disconnect | Out-Null
                    & $WarpCli --accept-tos registration delete 2>$null | Out-Null
                    Write-Host "-> Новая регистрация выполнится при подключении." -ForegroundColor Gray
                    $Res = Connect-WarpTunnel $BatFile
                    if ($Res) {
                        $global:TunnelPaused = $false
                        if ($RestoreSplit) {
                            Write-Host "-> Восстановление маршрутизации Split Tunneling..." -ForegroundColor Yellow
                            Apply-RuBypassTemplate
                        }
                        Write-Host "-> Определение нового IP-адреса..." -ForegroundColor Yellow
                        Wait-ExternalIp 20
                        if ($Config.AutoPing -ne 0) {
                            Write-Host "-> Обновление пинга (ожидайте)..." -ForegroundColor Yellow
                            Measure-Latency
                        }
                        $NewIp = $global:CurrentExternalIp
                        $Was = if ($OldIp) { $OldIp } else { "неизвестно" }
                        if (-not $global:IpOk) {
                            Write-Host "Новый IP определить не удалось, нажмите Enter в меню для повторного опроса." -ForegroundColor Yellow
                        } elseif ($OldIp -and (($OldIp -split " ")[0] -eq ($NewIp -split " ")[0])) {
                            Write-Host "Адрес не изменился: $NewIp (Cloudflare выдал тот же)." -ForegroundColor Yellow
                        } else {
                            Write-Host "IP: $Was -> $NewIp" -ForegroundColor Green
                        }
                    } else {
                        Write-Host "Ошибка подключения после перерегистрации." -ForegroundColor Red
                    }
                    Start-Sleep -Seconds 4
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
        Write-Host "`nВы действительно хотите отключить соединение и закрыть программу? (Y/N)" -ForegroundColor Yellow
        $Confirm = [console]::ReadKey($true).KeyChar.ToString().ToLower()
        if ($Confirm -match "[yд]") {
            return $true
        }
    }
    finally {
        Write-Host "`n-> Отключение туннеля и очистка маршрутов..." -ForegroundColor Yellow
        try { Stop-Winws } catch {}
        try {
            if (Test-Path $WarpCli) {
                & $WarpCli --accept-tos disconnect *> $null
            }
        } catch {}
        $global:ActivePreset = $null
        if ($Watchdog) { Stop-Process -Id $Watchdog.Id -Force -ErrorAction SilentlyContinue }
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
        Write-Host "`n-> Запуск профиля [$BatName] начнется через $WaitSecs сек." -ForegroundColor Cyan
        Write-Host "   Нажмите любую клавишу для отмены и перехода в главное меню..." -ForegroundColor Yellow
        
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
        if (-not $Interrupted) { $ExitProg = @(Launch-Tunnel $Config.LastPreset)[-1]; if ($ExitProg -eq $true) { Exit } }
    } else {
        $ExitProg = @(Launch-Tunnel $Config.LastPreset)[-1]
        if ($ExitProg -eq $true) { Exit }
    }
}

while ($true) {
    Clear-Host
    Write-Host "=========================================================" -ForegroundColor Magenta
    Write-Host $LogoText -ForegroundColor Magenta
    Write-Host "           Created By BUSH   |   v$AppVersion   " -ForegroundColor Cyan
    Write-Host "=========================================================" -ForegroundColor DarkGray
    
    $ZapretDirFullName = if (Test-Path $ZapretDir) { (Get-Item $ZapretDir).FullName } else { "" }
    $BatFiles = if ($ZapretDirFullName) { Get-ChildItem -Path $ZapretDirFullName -Filter "*.bat" | Where-Object { $_.Name -notmatch "(?i)^service(_install|_remove)?\.bat$" } } else { @() }
    
    Write-Host " [N]   Запустить профиль Zapret (номер из списка)" -ForegroundColor White
    Write-Host " [S]   Настройки" -ForegroundColor Yellow
    Write-Host " [Q]   Завершить работу" -ForegroundColor Gray
    Write-Host "=========================================================" -ForegroundColor DarkGray
    
    if ($BatFiles.Count -gt 0) {
        for ($i = 0; $i -lt $BatFiles.Count; $i++) {
            $Color = if ($BatFiles[$i].Name -like "*alt12*") { "Green" } else { "Gray" }
            Write-Host " [$($i + 1)] $($BatFiles[$i].Name)" -ForegroundColor $Color
        }
    } else { Write-Host " Профили конфигурации не обнаружены." -ForegroundColor Red }
    
    $Cmd = Read-Host "Команда"
    if ($Cmd.ToLower() -eq 's') { Show-Settings }
    elseif ($Cmd.ToLower() -eq 'q') { Exit }
    else {
        $choice = 0
        if ([int]::TryParse($Cmd, [ref]$choice) -and $choice -ge 1 -and $choice -le $BatFiles.Count) {
            $ExitProg = @(Launch-Tunnel $BatFiles[$choice - 1].FullName)[-1]
            if ($ExitProg -eq $true) { Exit }
        }
    }
}

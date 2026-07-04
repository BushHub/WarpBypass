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
        [Win32.Win32Console]::SetConsoleMode($StdInputHandle, ($ConsoleMode -band -not 0x0040))
    }
} catch {}

$StorageDir = "$env:LOCALAPPDATA\WarpBypass"
if (-not (Test-Path $StorageDir)) { New-Item -ItemType Directory -Path $StorageDir -Force -ErrorAction SilentlyContinue *> $null }

$ZapretDir = "$StorageDir\zapret"
$ZapretZip = "$StorageDir\zapret.zip"
$ZapretUrl = "https://github.com/Flowseal/zapret-discord-youtube/archive/refs/heads/main.zip"
$WarpCli = "C:\Program Files\Cloudflare\Cloudflare WARP\warp-cli.exe"

$ConfigPath = "$StorageDir\config.json"
$PingListPath = "$StorageDir\ping_list.txt"

# Terminate conflicting processes and services
try { Stop-Service -Name "zapret" -Force -ErrorAction SilentlyContinue *> $null } catch {}
try { Stop-Service -Name "goodbyedpi" -Force -ErrorAction SilentlyContinue *> $null } catch {}
try { Stop-Process -Name "winws" -Force -ErrorAction SilentlyContinue *> $null } catch {}
try { Stop-Process -Name "goodbyedpi" -Force -ErrorAction SilentlyContinue *> $null } catch {}
try { Stop-Process -Name "Cloudflare WARP" -Force -ErrorAction SilentlyContinue *> $null } catch {}

# Reset Cloudflare WARP service to clear any frozen connection states
try {
    if (Get-Service -Name "Cloudflare WARP" -ErrorAction SilentlyContinue) {
        Stop-Service -Name "Cloudflare WARP" -Force -ErrorAction SilentlyContinue *> $null
        Start-Sleep -Seconds 1
        Start-Service -Name "Cloudflare WARP" -ErrorAction SilentlyContinue *> $null
    }
} catch {}

try { if (Test-Path $WarpCli) { & $WarpCli --accept-tos disconnect -ErrorAction SilentlyContinue *> $null } } catch {}
Clear-Host

$DefaultConfig = @{ AutoPreset = $false; LastPreset = ""; AutoPing = $true; DnsFix = $false; IgnoredVersion = "0.0"; AutoUpdate = $true }

if (Test-Path $ConfigPath) {
    try { 
        $Config = Get-Content $ConfigPath -Raw | ConvertFrom-Json 
        if (-not $Config.TargetObject) {
            foreach ($Key in $DefaultConfig.Keys) {
                if ($null -eq $Config.$Key) { Add-Member -InputObject $Config -NotePropertyName $Key -NotePropertyValue $DefaultConfig[$Key] }
            }
        }
    } catch { 
        $Config = New-Object PSObject -Property $DefaultConfig 
    }
} else {
    $Config = New-Object PSObject -Property $DefaultConfig
    $Config | ConvertTo-Json | Set-Content $ConfigPath
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
        Write-Host "-> Загрузка компонентов маскировки трафика..." -ForegroundColor Yellow
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
        Invoke-WebRequest -Uri $ZapretUrl -OutFile $ZapretZip -UseBasicParsing -UserAgent "WarpBypass" -ErrorAction SilentlyContinue
        if (Test-Path $ZapretZip) {
            if (Test-Path $ZapretDir) { Remove-Item $ZapretDir -Recurse -Force -ErrorAction SilentlyContinue }
            Expand-Archive -Path $ZapretZip -DestinationPath $StorageDir -Force
            $ExtractedDir = Get-ChildItem -Path $StorageDir -Directory | Where-Object { $_.Name -like "zapret-discord-youtube*" } | Select-Object -First 1
            if ($ExtractedDir) { Rename-Item -Path $ExtractedDir.FullName -NewName "zapret" -Force }
            Remove-Item $ZapretZip -ErrorAction SilentlyContinue
            if ($global:LatestSHA) { Out-File -FilePath $VersionFile -InputObject $global:LatestSHA -Force }
        }
    }
}

function Show-Settings {
    while ($true) {
        Clear-Host
        Write-Header
        Write-Host "                 КОНФИГУРАЦИЯ (v$AppVersion)" -ForegroundColor Cyan
        Write-Host "=========================================================" -ForegroundColor DarkGray
        Write-Host " [1] Автоматический запуск профиля : " -NoNewline; if ($Config.AutoPreset) { Write-Host "АКТИВНО" -ForegroundColor Green } else { Write-Host "ОТКЛЮЧЕНО" -ForegroundColor Red }
        Write-Host " [2] Диагностика задержки (Ping)   : " -NoNewline; if ($Config.AutoPing) { Write-Host "АКТИВНО" -ForegroundColor Green } else { Write-Host "ОТКЛЮЧЕНО" -ForegroundColor Red }
        Write-Host " [3] Принудительный сброс DNS-кэша : " -NoNewline; if ($Config.DnsFix) { Write-Host "АКТИВНО" -ForegroundColor Green } else { Write-Host "ОТКЛЮЧЕНО" -ForegroundColor Red }
        Write-Host " [4] Авто-синхронизация обновлений : " -NoNewline; if ($Config.AutoUpdate) { Write-Host "АКТИВНО" -ForegroundColor Green } else { Write-Host "ОТКЛЮЧЕНО" -ForegroundColor Red }
        Write-Host " [5] Редактировать список хостов для проверки" -ForegroundColor White
        Write-Host " [0] Сохранить и вернуться в главное меню" -ForegroundColor Gray
        Write-Host "=========================================================" -ForegroundColor DarkGray
        
        $sel = Read-Host "Укажите параметр"
        switch ($sel) {
            "1" { $Config.AutoPreset = -not $Config.AutoPreset; Save-Config }
            "2" { $Config.AutoPing = -not $Config.AutoPing; Save-Config }
            "3" { $Config.DnsFix = -not $Config.DnsFix; Save-Config }
            "4" { $Config.AutoUpdate = -not $Config.AutoUpdate; Save-Config }
            "5" { Start-Process notepad.exe $PingListPath -Wait }
            "0" { return }
        }
    }
}

function Launch-Tunnel ($BatFile) {
    $Config.LastPreset = $BatFile
    Save-Config
    
    try {
        Clear-Host
        Write-Header
        
        if ($Config.DnsFix) {
            Write-Host "-> Очистка локального кэша DNS-резолвера..." -ForegroundColor Yellow
            ipconfig /flushdns | Out-Null
        }
        
        Write-Host "-> Инициализация компонента winws..." -ForegroundColor Yellow
        $ZapretJob = Start-Process -FilePath $BatFile -WorkingDirectory (Split-Path $BatFile) -WindowStyle Hidden -PassThru
        Start-Sleep -Seconds 4
        
        if (-not (Test-Path $WarpCli)) {
            Write-Host "-> Развертывание клиента Cloudflare WARP..." -ForegroundColor Green
            $WarpMsi = "$StorageDir\Cloudflare_WARP.msi"
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
            try {
                Invoke-WebRequest -Uri "https://downloads.cloudflareclient.com/v1/download/windows/ga" -OutFile $WarpMsi -UseBasicParsing -UserAgent "WarpBypass"
                
                Write-Host "-> Выполнение тихой установки компонента (ожидайте)..." -ForegroundColor Gray
                
                # LAUNCH FIX: Use single argument string to support spaces in paths and wait for completion
                Start-Process msiexec.exe -ArgumentList "/i `"$WarpMsi`" /qn /norestart START_WPF_AS_USER=0" -Wait -NoNewWindow
                
                Remove-Item $WarpMsi -ErrorAction SilentlyContinue
                
                # INSTALL VALIDATION: Stop execution if warp-cli.exe is not found
                if (-not (Test-Path $WarpCli)) {
                    Write-Host "`n❌ Критическая ошибка: Установка завершена, но исполняемый файл warp-cli.exe не найден." -ForegroundColor Red
                    Write-Host "Возможно, антивирус заблокировал распаковку или требуются права администратора." -ForegroundColor Yellow
                    Write-Host "Решение: Установите Cloudflare WARP вручную с официального сайта https://1.1.1.1" -ForegroundColor Gray
                    Pause; Exit
                }
                
                Write-Host "-> Служба Cloudflare WARP успешно установлена!" -ForegroundColor Green
                Start-Sleep -Seconds 2
            } catch { 
                Write-Host "`n❌ Критическая ошибка: Сбой при загрузке или инсталляции Cloudflare WARP." -ForegroundColor Red
                Pause; Exit 
            }
        }

        # Configure Cloudflare WARP service startup type to Manual
        Set-Service -Name "Cloudflare WARP" -StartupType Manual -ErrorAction SilentlyContinue

        Write-Host "-> Перезапуск системной службы Cloudflare WARP..." -ForegroundColor Yellow
        Stop-Service -Name "Cloudflare WARP" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
        Start-Service -Name "Cloudflare WARP" -ErrorAction SilentlyContinue
        Stop-Process -Name "Cloudflare WARP" -Force -ErrorAction SilentlyContinue

        Write-Host "-> Аутентификация и установка туннеля..." -ForegroundColor Yellow
        & $WarpCli --accept-tos register 2>$null | Out-Null
        & $WarpCli --accept-tos registration new 2>$null | Out-Null
        & $WarpCli --accept-tos connect | Out-Null

        $Timeout = 30
        $Connected = $false
        while ($Timeout -gt 0) {
            $WarpStatus = & $WarpCli --accept-tos status | Out-String
            if ($WarpStatus -and $WarpStatus.Contains("Connected") -and -not $WarpStatus.Contains("Connecting")) { $Connected = $true; break }
            Start-Sleep -Seconds 1
            $Timeout--
        }

        if (-not $Connected) {
            Write-Host "Ошибка: Отсутствует ответ от службы маршрутизации WARP." -ForegroundColor Red
            Pause; Exit
        }

        Stop-Process -Id $ZapretJob.Id -Force -ErrorAction SilentlyContinue
        Stop-Process -Name "winws" -Force -ErrorAction SilentlyContinue
        
        $MyPID = $PID
        Start-Process powershell -ArgumentList @('-NoProfile', '-WindowStyle', 'Hidden', '-Command', "while (Get-Process -Id $MyPID -ErrorAction SilentlyContinue) { Start-Sleep 1 }; & '$WarpCli' --accept-tos disconnect") -WindowStyle Hidden
        
        if ($Config.AutoPing -and (Test-Path $PingListPath)) {
            Write-Host "`n====== [ ДИАГНОСТИКА УЗЛОВ (TCP Ping) ] ======" -ForegroundColor Cyan
            Write-Host "Отображается время установки сессии (включает TLS Handshake)" -ForegroundColor DarkGray
            
            $Domains = Get-Content $PingListPath | Where-Object { $_.Trim() -ne "" }
            foreach ($Dom in $Domains) {
                $CleanDom = $Dom.Trim() -replace "(?i)^https?://", "" -replace "/.*$", ""
                
                try {
                    $TcpClient = New-Object System.Net.Sockets.TcpClient
                    $Watch = [System.Diagnostics.Stopwatch]::StartNew()
                    
                    $AsyncResult = $TcpClient.BeginConnect($CleanDom, 443, $null, $null)
                    $Success = $AsyncResult.AsyncWaitHandle.WaitOne(3000, $false)
                    
                    if ($Success) {
                        $TcpClient.EndConnect($AsyncResult)
                        $Watch.Stop()
                        $PingMs = [math]::Round($Watch.Elapsed.TotalMilliseconds)
                        Write-Host " [$CleanDom] : $PingMs ms" -ForegroundColor Green
                    } else {
                        $Watch.Stop()
                        Write-Host " [$CleanDom] : Превышено время ожидания" -ForegroundColor Red
                    }
                    $TcpClient.Close()
                } catch {
                    Write-Host " [$CleanDom] : Узел недоступен" -ForegroundColor Red
                }
            }
            Write-Host "==============================================" -ForegroundColor Cyan
        }
        
        Write-Host "`nТуннель WarpBypass успешно инициализирован." -ForegroundColor Green
        Write-Host "Сеанс активен. Для отключения туннеля и сброса маршрутов закройте окно." -ForegroundColor Gray
        Start-Sleep -Seconds 2
        
        # Interactive menu for the active session
        while ($true) {
            try {
                Clear-Host
                Write-Header
                Write-Host "              СЕАНС АКТИВЕН (Туннель WarpBypass)" -ForegroundColor Green
                Write-Host "=========================================================" -ForegroundColor DarkGray
                Write-Host " [S]  Параметры утилиты (Настройки)" -ForegroundColor Yellow
                Write-Host " [Q]  Отключить туннель и выйти" -ForegroundColor Red
                Write-Host "=========================================================" -ForegroundColor DarkGray
                
                $ExitInput = Read-Host "Команда"
                $CleanInput = $ExitInput.Trim().ToLower()
                
                if ($CleanInput -eq 's') {
                    Show-Settings
                }
                elseif ($CleanInput -eq 'q') {
                    $Confirm = Read-Host "Вы действительно хотите отключить туннель и выйти? (Y/N)"
                    if ($Confirm.Trim().ToLower() -match "^[yд]") {
                        return
                    }
                }
            }
            catch [System.Management.Automation.PipelineStoppedException], [System.Management.Automation.Host.HostException] {
                Write-Host "`n[!] Обнаружен сигнал прерывания (Ctrl+C)." -ForegroundColor Yellow
                $Confirm = Read-Host "Вы действительно хотите отключить туннель и выйти? (Y/N)"
                if ($Confirm.Trim().ToLower() -match "^[yд]") {
                    return
                }
            }
        }
    }
    finally {
        Write-Host "`n-> Деактивация туннелирования и очистка маршрутов..." -ForegroundColor Yellow
        try {
            if (Test-Path $WarpCli) {
                & $WarpCli --accept-tos disconnect -ErrorAction SilentlyContinue *> $null
            }
            if ($ZapretJob) {
                Stop-Process -Id $ZapretJob.Id -Force -ErrorAction SilentlyContinue *> $null
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

if ($Config.AutoUpdate) {
    Check-AppUpdate
    Check-Updates
}

if ($Config.AutoPreset -and $Config.LastPreset -and (Test-Path $Config.LastPreset)) {
    $WaitSecs = 3
    $Interrupted = $false
    $BatName = Split-Path $Config.LastPreset -Leaf
    Write-Host "`n-> Автоматический запуск профиля [$BatName] через $WaitSecs сек." -ForegroundColor Cyan
    Write-Host "   Нажмите любую клавишу для прерывания и перехода к конфигурации..." -ForegroundColor Yellow
    
    $Host.UI.RawUI.FlushInputBuffer()
    while ($WaitSecs -gt 0) {
        Start-Sleep -Seconds 1
        $WaitSecs--
        if ([console]::KeyAvailable) { $Interrupted = $true; $Host.UI.RawUI.FlushInputBuffer(); break }
    }
    if (-not $Interrupted) { Launch-Tunnel $Config.LastPreset; Exit }
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
            Launch-Tunnel $BatFiles[$choice - 1].FullName
            Exit
        }
    }
}

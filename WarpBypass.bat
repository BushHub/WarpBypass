<# : RUN
@echo off
title WarpBypass v5.1 by BUSH
cd /d "%~dp0"
set "WARP_BAT_PATH=%~f0"
fltmc >nul 2>&1
if %errorLevel% neq 0 (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "$q=[string][char]39; $c='$env:WARP_BAT_PATH='+$q+$env:WARP_BAT_PATH.Replace($q,$q+$q)+$q+'; Invoke-Command -ScriptBlock ([ScriptBlock]::Create((Get-Content -LiteralPath $env:WARP_BAT_PATH -Encoding UTF8 -Raw)))'; $e=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($c)); Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-EncodedCommand',$e"
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

# The file was started by the user: drop the "downloaded from the Internet" mark so Windows stops warning on every launch
try { Unblock-File -LiteralPath $env:WARP_BAT_PATH -ErrorAction SilentlyContinue } catch {}
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

# ---------------------------------------------------------
# Localization: string tables (ru / en)
# Format: key=value, one per line. Placeholders: {0}, {1}. No backslashes.
# ---------------------------------------------------------
$StringsRu = @'
yn=Y/N
prompt.choose=Выберите пункт
prompt.cmd=Команда
press.enter=Нажмите Enter, чтобы продолжить
press.key=Нажмите любую клавишу, чтобы продолжить
on=ВКЛ
off=ВЫКЛ
back=Назад
none=нет
na=н/д
sec={0} сек
ms.fmt={0} мс
unit.mb=МБ
recommended=рекомендуется
fail.start=не удалось запустить warp-cli
wiz.title=ПЕРВИЧНАЯ НАСТРОЙКА
wiz.welcome1=WarpBypass обходит блокировки через Cloudflare WARP.
wiz.welcome2=Настройка займёт два коротких шага.
wiz.step1=Шаг 1 из 2. Параметры системы
wiz.dns=Очищать кэш DNS при подключении? (рекомендуется)
wiz.route=Включить маршрутизацию «Россия напрямую»? (рекомендуется)
wiz.route.applying=Применение маршрутизации «Россия напрямую»...
wiz.upd=Автоматически проверять обновления? (рекомендуется)
wiz.profile.title=ПРОФИЛЬ ОБХОДА
wiz.profile.hint=Шаг 2 из 2. Разным провайдерам подходят разные профили.
wiz.profile.rec=Рекомендуемый профиль (general ALT12)
wiz.profile.later=Выбрать позже в главном меню
wiz.profile.prompt=Выберите пункт [1-2, Enter = 1]
wiz.done=Первичная настройка завершена.
wiz.saved=Настройки сохранены в {0}
upd.checking=Проверка обновлений WarpBypass...
upd.available=Доступна новая версия: v{0} (установлена v{1})
upd.ask=Обновить сейчас?
upd.downloading=Загрузка обновления
upd.invalid=Загруженный файл не прошёл проверку, обновление отменено.
upd.installing=Установка обновления...
upd.ignore.ask=Больше не напоминать о версии {0}?
upd.ignored=Версия {0} добавлена в исключения.
upd.latest=Установлена последняя версия.
upd.failed=Не удалось проверить обновления (GitHub недоступен).
zap.offline=Нет подключения к сети. Работа в автономном режиме.
zap.checking=Проверка компонентов Zapret...
zap.audit.fail=Не удалось проверить компоненты, используется локальная копия.
zap.download=Загрузка компонентов Zapret
zap.badarchive=Архив не содержит ожидаемых файлов.
zap.updfail=Не удалось обновить компоненты Zapret: {0}
zap.missing=Компоненты Zapret не установлены, запуск профилей невозможен.
dl.file=Загрузка файла
dl.size={0} МБ загружено
dl.done=Готово
bl.checking=Проверка обновлений списка...
bl.srvfail=Не удалось связаться с сервером обновлений.
bl.local=Используется сохранённый список.
bl.current=Список актуален (v{0}).
bl.updating=Обновление списка: v{0} -> v{1}
bl.first=Загрузка списка (v{0})...
bl.reload=Повторная загрузка списка (v{0})...
bl.updated=Список обновлён до v{0}.
bl.error=Ошибка загрузки: {0}
ru.loading=Загрузка списка доменов и IP...
ru.fail.list=Не удалось загрузить список доменов. Проверьте подключение к интернету.
ru.preparing=Подготовка правил...
ru.adding=Добавление правил в WARP: {0} шт.
ru.failed=Не удалось применить правил: {0}
ru.reconnect=Переподключение туннеля для применения правил...
ru.done=Правила «Россия напрямую» применены.
ru.already=Правила уже применены, добавлять нечего.
ru.progress=Применение: {0}% ({1}/{2})
ru.retry=Повторная попытка для {0} правил...
ru.nowarp=Клиент WARP не установлен. Правила можно применить после первого подключения.
ru.daemon=Служба WARP не отвечает. Правила не применены.
conn.slow=Подключение занимает больше времени. Модуль обхода оставлен включённым и отключится после подключения.
conn.retry=Повторная попытка подключения...
wait.install=Установка Cloudflare WARP
wait.uninstall=Удаление Cloudflare WARP
wait.winws=Запуск модуля обхода (winws)
wait.daemon=Ожидание службы WARP
wait.connect=Подключение WARP
wait.ip=Определение IP-адреса
wait.done=готово
wait.timeout=время ожидания истекло
route.title=МАРШРУТИЗАЦИЯ: РОССИЯ НАПРЯМУЮ
route.sub1=Российские сайты и IP-адреса открываются напрямую,
route.sub2=без WARP, чтобы банки и Госуслуги работали как обычно.
route.state=Состояние
route.state.on=ВКЛ (доменов: {0}, IP-диапазонов: {1})
route.list=Список правил
route.list.ver=версия {0}
route.list.none=не загружен
route.i1=Включить (применить правила)
route.i2=Обновить список доменов и IP
route.i3=Показать действующие правила
route.i4=Выключить (удалить правила)
route.rules.title=ДЕЙСТВУЮЩИЕ ПРАВИЛА
route.sites=Домены: {0}
route.ips=IP-диапазоны: {0}
route.more=... и ещё {0}
route.confirm.off=Удалить все правила и направить весь трафик через WARP?
route.removing=Удаление правил...
route.removed=Правила удалены.
bench.title=ПОДБОР ПРОФИЛЯ ОБХОДА
bench.sub1=Программа по очереди запустит профили Zapret и проверит
bench.sub2=TLS-соединение с YouTube и Discord. Так мы найдём профиль,
bench.sub3=который лучше работает у вашего провайдера (около минуты).
bench.nodir=Папка компонентов Zapret не найдена.
bench.nofiles=Файлы профилей не найдены.
bench.testing=Проверка профиля {0}...
bench.ok=ДОСТУПЕН ({0}/{1} узлов, {2} мс)
bench.fail=НЕ РАБОТАЕТ
bench.results=РЕЗУЛЬТАТЫ
bench.best=Рекомендуемый профиль:
bench.best.d=доступно {0}/{1} узлов, средний отклик {2} мс
bench.save.ask=Сохранить как профиль для автозапуска?
bench.saved=Профиль сохранён.
bench.none=Ни один профиль не обеспечил доступ к тестовым сайтам.
bench.restore=Восстановление активного сеанса...
ping.title=ПРОВЕРКА ДОСТУПНОСТИ
ping.sub=Отклик популярных сервисов на экране подключения.
ping.mode=Режим
ping.mode.static=однократно при подключении
ping.mode.dynamic=регулярно (каждые {0} сек)
ping.i1=Сменить режим: выкл / однократно / регулярно
ping.i2=Интервал регулярной проверки
ping.i3=Изменить список узлов
ping.i4=Сбросить настройки проверки
ping.int.only=Интервал задаётся только в режиме «регулярно».
ping.int.title=ИНТЕРВАЛ ПРОВЕРКИ
ping.int.sub=Как часто обновлять доступность сервисов.
ping.int.custom=Указать вручную
ping.int.ask=Интервал в секундах (минимум 5)
ping.int.bad=Некорректное значение, установлено 30 сек.
ping.reset.ask=Вернуть стандартные параметры проверки?
ping.reset.done=Параметры проверки сброшены.
un.title=УДАЛЕНИЕ WARPBYPASS
un.warp.ask=Также удалить клиент Cloudflare WARP (Cloudflare One Client) с этого компьютера?
un.warp.done=Клиент Cloudflare WARP удалён.
un.warp.fail=Не удалось удалить клиент Cloudflare WARP. Его можно удалить вручную в списке установленных приложений.
un.stop=Остановка модулей обхода...
un.restore=Восстановление настроек Cloudflare WARP...
un.registry=Очистка автозапуска в реестре...
un.files=Удаление файлов программы...
un.done=WarpBypass удалён.
un.done2=Службы и папки с данными очищены.
un.done3=Спасибо, что пользовались WarpBypass!
conn.title=ПОДКЛЮЧЕНИЕ
conn.sub=Автозапуск профиля и параметры подключения.
conn.profile=Профиль по умолчанию
conn.profile.none=не выбран
conn.auto=Автозапуск профиля
conn.delay=Задержка автозапуска
conn.delay.instant=нет (сразу)
conn.dns=Сброс кэша DNS
conn.i1=Включить / выключить автозапуск профиля
conn.i2=Задать задержку автозапуска
conn.i3=Включить / выключить сброс кэша DNS
conn.delay.ask=Задержка в секундах (0 - без задержки)
conn.delay.bad=Некорректное значение.
sys.title=СИСТЕМА
sys.sub=Язык, ключ WARP+, обновления и удаление.
sys.lang=Язык
sys.key=Ключ WARP+
sys.key.set=задан
sys.key.unset=не задан
sys.upd=Автообновление
sys.ver=Версия
sys.i1=Язык / Language
sys.i2=Ключ WARP+
sys.i3=Автообновление: вкл / выкл
sys.i4=Сбросить настройки
sys.i5=Удалить WarpBypass
sys.reset.ask=Сбросить настройки программы? (язык и ключ WARP+ сохранятся)
sys.reset.done=Настройки сброшены.
sys.uninstall.ask=Удалить WarpBypass и все его данные безвозвратно?
key.title=КЛЮЧ WARP+
key.sub1=Введите лицензионный ключ из приложения WARP.
key.sub2=Формат: xxxxxxxx-xxxxxxxx-xxxxxxxx. Пустой ввод удалит ключ.
key.paste=Вставка: Ctrl+V или правая кнопка мыши.
key.prompt=Ключ WARP+
key.removed=Ключ удалён из настроек. Действующий ключ останется до перерегистрации.
key.badformat=Некорректный формат ключа.
key.accepted=Ключ принят клиентом WARP.
key.checking=Переподключение для проверки ключа...
key.plus.on=WARP+ активен.
key.plus.off=Ключ принят, но WARP+ не активен (аккаунт Free): ключ недействителен или исчерпан лимит устройств.
key.later=Проверить ключ можно после подключения: в строке IP появится [WARP+].
key.rejected=Клиент WARP не принял ключ: он неверный, уже использован или исчерпан лимит устройств.
key.kept=Ключ сохранён и будет применён при следующей регистрации.
stat.title=СТАТИСТИКА WARP
stat.sub=Состояние туннеля в реальном времени.
stat.nowarp=Клиент Cloudflare WARP не установлен.
stat.mtu=MTU туннеля
stat.speed=Скорость (QUIC)
stat.speed.fmt={0} Мбит/с ({1} МБ/с)
stat.speed.low={0} Кбит/с
stat.loss=Потери пакетов
stat.dns=Задержка DNS (DoH)
stat.api=Задержка API Cloudflare
stat.fw=Задержка фильтра
stat.refresh=Обновить показатели
diag.title=ДИАГНОСТИКА
diag.sub=Проверка связи и подбор профиля обхода.
diag.i1=Проверка доступности
diag.i1.d=режим и список узлов
diag.i2=Статистика WARP
diag.i2.d=MTU, скорость, задержки
diag.i3=Подбор профиля
diag.i3.d=поиск лучшего для вас
set.title=НАСТРОЙКИ
set.sub=Выберите раздел.
set.i1=Подключение
set.i1.d=автозапуск, задержка, DNS
set.i2=Маршрутизация
set.i2.d=Россия напрямую
set.i3=Диагностика
set.i3.d=доступность, статистика, подбор
set.i4=Система
set.i4.d=язык, ключ WARP+, обновления
winws.fail=Модуль winws не запустился (возможен конфликт WinDivert или антивирус).
conn.flushdns=Очистка кэша DNS...
conn.dl.warp=Загрузка Cloudflare WARP
conn.warp.missing=Установка завершена, но warp-cli.exe не найден.
conn.warp.installed=Cloudflare WARP установлен.
conn.warp.failed=Не удалось загрузить или установить Cloudflare WARP.
conn.restart.svc=Перезапуск службы Cloudflare WARP...
conn.wait.daemon=Ожидание готовности службы WARP...
conn.init=Подготовка подключения...
conn.daemon.fail=Служба WARP не отвечает, регистрация пропущена.
conn.register=Регистрация клиента в сети Cloudflare...
conn.license=Применение ключа WARP+...
conn.noresp=Служба WARP не отвечает. Подключение не выполнено.
sess.status=Подключение WARP
sess.ip=Внешний IP-адрес
sess.ip.wait=определение...
st.connected=ПОДКЛЮЧЕНО
st.connecting=ПОДКЛЮЧЕНИЕ...
st.disconnected=ОТКЛЮЧЕНО
st.disconnecting=ОТКЛЮЧЕНИЕ...
st.paused=ПАУЗА
sess.avail=[ Доступность сервисов ]
sess.measuring=проверка...
sess.next=следующая через {0} сек
sess.timeout=нет ответа
sess.unreachable=недоступен
sess.pause=Пауза
sess.resume=Продолжить работу
sess.reconnect=Переподключить туннель
sess.changeip=Сменить IP-адрес
sess.profile=Сменить профиль обхода
sess.settings=Настройки
sess.quit=Отключить туннель и выйти
sess.measuring.wait=Проверка доступности сервисов...
sess.pausing=Пауза туннеля...
sess.resuming=Возобновление туннеля...
sess.resume.fail=Не удалось возобновить туннель.
sess.reconnecting=Переподключение туннеля...
sess.reconnect.fail=Не удалось переподключить туннель.
sess.quit.ask=Отключить туннель и закрыть программу?
sess.closing=Отключение туннеля и очистка маршрутов...
sess.closed=Сеанс завершён.
ip.direct=напрямую
ip.unknown=не определён
ip.unknown.old=неизвестно
ip.ask=Клиент WARP будет перерегистрирован, адрес может измениться. Продолжить?
ip.step.reset=Сброс регистрации клиента WARP...
ip.step.new=Новая регистрация выполнится при подключении.
ip.step.route=Восстановление правил маршрутизации...
ip.step.detect=Определение нового IP-адреса...
ip.detect.fail=Не удалось определить новый IP. Нажмите Enter в меню для повторной проверки.
ip.same=Адрес не изменился: {0} (Cloudflare выдал тот же).
ip.changed=IP-адрес изменён: {0} -> {1}
ip.reconnect.fail=Не удалось подключиться после перерегистрации.
main.title=ГЛАВНОЕ МЕНЮ
main.sub=Выберите профиль обхода для запуска (введите номер).
main.last=последний запуск
main.noprofiles=Профили не найдены. Проверьте подключение к интернету.
main.settings=Настройки
main.quit=Выход
auto.starting=Запуск профиля «{0}» через {1} сек.
auto.cancel=Нажмите любую клавишу, чтобы отменить и открыть меню.
'@

$StringsEn = @'
yn=Y/N
prompt.choose=Select an option
prompt.cmd=Command
press.enter=Press Enter to continue
press.key=Press any key to continue
on=ON
off=OFF
back=Back
none=none
na=n/a
sec={0} sec
ms.fmt={0} ms
unit.mb=MB
recommended=recommended
fail.start=could not start warp-cli
wiz.title=INITIAL SETUP
wiz.welcome1=WarpBypass bypasses blocks through Cloudflare WARP.
wiz.welcome2=Setup takes just two short steps.
wiz.step1=Step 1 of 2. System options
wiz.dns=Flush the DNS cache on connect? (recommended)
wiz.route=Enable "Russia direct" routing? (recommended)
wiz.route.applying=Applying "Russia direct" routing...
wiz.upd=Check for updates automatically? (recommended)
wiz.profile.title=BYPASS PROFILE
wiz.profile.hint=Step 2 of 2. Different ISPs need different profiles.
wiz.profile.rec=Recommended profile (general ALT12)
wiz.profile.later=Choose later in the main menu
wiz.profile.prompt=Select an option [1-2, Enter = 1]
wiz.done=Initial setup complete.
wiz.saved=Settings saved to {0}
upd.checking=Checking for WarpBypass updates...
upd.available=A new version is available: v{0} (installed v{1})
upd.ask=Update now?
upd.downloading=Downloading update
upd.invalid=The downloaded file failed verification, update cancelled.
upd.installing=Installing update...
upd.ignore.ask=Stop reminding about version {0}?
upd.ignored=Version {0} added to the ignore list.
upd.latest=You are running the latest version.
upd.failed=Could not check for updates (GitHub unreachable).
zap.offline=No network connection. Running in offline mode.
zap.checking=Checking Zapret components...
zap.audit.fail=Could not check components, using the local copy.
zap.download=Downloading Zapret components
zap.badarchive=The archive does not contain the expected files.
zap.updfail=Could not update Zapret components: {0}
zap.missing=Zapret components are not installed, profiles cannot be started.
dl.file=Downloading file
dl.size={0} MB downloaded
dl.done=Done
bl.checking=Checking for list updates...
bl.srvfail=Could not reach the update server.
bl.local=Using the saved list.
bl.current=The list is up to date (v{0}).
bl.updating=Updating the list: v{0} -> v{1}
bl.first=Downloading the list (v{0})...
bl.reload=Downloading the list again (v{0})...
bl.updated=The list was updated to v{0}.
bl.error=Download error: {0}
ru.loading=Downloading the domain and IP list...
ru.fail.list=Could not download the domain list. Check your internet connection.
ru.preparing=Preparing rules...
ru.adding=Adding rules to WARP: {0}
ru.failed=Rules that could not be applied: {0}
ru.reconnect=Reconnecting the tunnel to apply the rules...
ru.done="Russia direct" rules applied.
ru.already=The rules are already applied, nothing to add.
ru.progress=Applying: {0}% ({1}/{2})
ru.retry=Retrying {0} rules...
ru.nowarp=The WARP client is not installed. The rules can be applied after the first connection.
ru.daemon=The WARP service is not responding. The rules were not applied.
conn.slow=Connecting takes longer than usual. The bypass module was left running and will stop after the connection is up.
conn.retry=Retrying the connection...
wait.install=Installing Cloudflare WARP
wait.uninstall=Removing Cloudflare WARP
wait.winws=Starting the bypass module (winws)
wait.daemon=Waiting for the WARP service
wait.connect=Connecting WARP
wait.ip=Detecting the IP address
wait.done=done
wait.timeout=timed out
route.title=ROUTING: RUSSIA DIRECT
route.sub1=Russian sites and IP addresses open directly,
route.sub2=bypassing WARP, so banks and gov services work as usual.
route.state=Status
route.state.on=ON (domains: {0}, IP ranges: {1})
route.list=Rule list
route.list.ver=version {0}
route.list.none=not downloaded
route.i1=Enable (apply the rules)
route.i2=Update the domain and IP list
route.i3=Show active rules
route.i4=Disable (remove the rules)
route.rules.title=ACTIVE RULES
route.sites=Domains: {0}
route.ips=IP ranges: {0}
route.more=... and {0} more
route.confirm.off=Remove all rules and send all traffic through WARP?
route.removing=Removing rules...
route.removed=Rules removed.
bench.title=BYPASS PROFILE TEST
bench.sub1=The program will start each Zapret profile in turn and
bench.sub2=test the TLS connection to YouTube and Discord to find
bench.sub3=the profile that works best on your ISP (about a minute).
bench.nodir=The Zapret components folder was not found.
bench.nofiles=No profile files found.
bench.testing=Testing profile {0}...
bench.ok=AVAILABLE ({0}/{1} hosts, {2} ms)
bench.fail=NOT WORKING
bench.results=RESULTS
bench.best=Recommended profile:
bench.best.d={0}/{1} hosts reachable, average response {2} ms
bench.save.ask=Save it as the autostart profile?
bench.saved=Profile saved.
bench.none=No profile gave access to the test sites.
bench.restore=Restoring the active session...
ping.title=AVAILABILITY CHECK
ping.sub=Response time of popular services on the session screen.
ping.mode=Mode
ping.mode.static=once when connecting
ping.mode.dynamic=periodic (every {0} sec)
ping.i1=Change mode: off / once / periodic
ping.i2=Periodic check interval
ping.i3=Edit the host list
ping.i4=Reset check settings
ping.int.only=The interval only applies to the periodic mode.
ping.int.title=CHECK INTERVAL
ping.int.sub=How often to refresh service availability.
ping.int.custom=Enter manually
ping.int.ask=Interval in seconds (minimum 5)
ping.int.bad=Invalid value, set to 30 sec.
ping.reset.ask=Restore the default check settings?
ping.reset.done=Check settings reset.
un.title=UNINSTALL WARPBYPASS
un.warp.ask=Also remove the Cloudflare WARP client (Cloudflare One Client) from this computer?
un.warp.done=The Cloudflare WARP client was removed.
un.warp.fail=Could not remove the Cloudflare WARP client. You can remove it manually in the installed apps list.
un.stop=Stopping bypass modules...
un.restore=Restoring Cloudflare WARP settings...
un.registry=Cleaning startup entries in the registry...
un.files=Removing program files...
un.done=WarpBypass has been removed.
un.done2=Services and data folders were cleaned up.
un.done3=Thank you for using WarpBypass!
conn.title=CONNECTION
conn.sub=Profile autostart and connection options.
conn.profile=Default profile
conn.profile.none=not selected
conn.auto=Profile autostart
conn.delay=Autostart delay
conn.delay.instant=none (instant)
conn.dns=Flush DNS cache
conn.i1=Turn profile autostart on / off
conn.i2=Set the autostart delay
conn.i3=Turn DNS cache flush on / off
conn.delay.ask=Delay in seconds (0 - no delay)
conn.delay.bad=Invalid value.
sys.title=SYSTEM
sys.sub=Language, WARP+ key, updates and uninstall.
sys.lang=Language
sys.key=WARP+ key
sys.key.set=set
sys.key.unset=not set
sys.upd=Automatic updates
sys.ver=Version
sys.i1=Language / Язык
sys.i2=WARP+ key
sys.i3=Automatic updates: on / off
sys.i4=Reset settings
sys.i5=Uninstall WarpBypass
sys.reset.ask=Reset program settings? (language and WARP+ key are kept)
sys.reset.done=Settings reset.
sys.uninstall.ask=Uninstall WarpBypass and delete all its data permanently?
key.title=WARP+ KEY
key.sub1=Enter the license key from the WARP app.
key.sub2=Format: xxxxxxxx-xxxxxxxx-xxxxxxxx. Empty input removes the key.
key.paste=Paste: Ctrl+V or right mouse button.
key.prompt=WARP+ key
key.removed=The key was removed from settings. An applied key stays until re-registration.
key.badformat=Invalid key format.
key.accepted=The key was accepted by the WARP client.
key.checking=Reconnecting to verify the key...
key.plus.on=WARP+ is active.
key.plus.off=The key was accepted, but WARP+ is not active (Free account): the key is invalid or its device limit is reached.
key.later=You can verify the key after connecting: the IP line will show [WARP+].
key.rejected=The WARP client rejected the key: it is invalid, already used or its device limit is reached.
key.kept=The key is saved and will be applied on the next registration.
stat.title=WARP STATISTICS
stat.sub=Live state of the tunnel.
stat.nowarp=The Cloudflare WARP client is not installed.
stat.mtu=Tunnel MTU
stat.speed=Speed (QUIC)
stat.speed.fmt={0} Mbit/s ({1} MB/s)
stat.speed.low={0} Kbit/s
stat.loss=Packet loss
stat.dns=DNS latency (DoH)
stat.api=Cloudflare API latency
stat.fw=Filter latency
stat.refresh=Refresh values
diag.title=DIAGNOSTICS
diag.sub=Connection checks and bypass profile test.
diag.i1=Availability check
diag.i1.d=mode and host list
diag.i2=WARP statistics
diag.i2.d=MTU, speed, latency
diag.i3=Profile test
diag.i3.d=find the best one for you
set.title=SETTINGS
set.sub=Choose a section.
set.i1=Connection
set.i1.d=autostart, delay, DNS
set.i2=Routing
set.i2.d=Russia direct
set.i3=Diagnostics
set.i3.d=availability, statistics, test
set.i4=System
set.i4.d=language, WARP+ key, updates
winws.fail=The winws module did not start (possible WinDivert conflict or antivirus).
conn.flushdns=Flushing the DNS cache...
conn.dl.warp=Downloading Cloudflare WARP
conn.warp.missing=Installation finished, but warp-cli.exe was not found.
conn.warp.installed=Cloudflare WARP installed.
conn.warp.failed=Could not download or install Cloudflare WARP.
conn.restart.svc=Restarting the Cloudflare WARP service...
conn.wait.daemon=Waiting for the WARP service to be ready...
conn.init=Preparing the connection...
conn.daemon.fail=The WARP service is not responding, registration skipped.
conn.register=Registering the client with Cloudflare...
conn.license=Applying the WARP+ key...
conn.noresp=The WARP service is not responding. Connection failed.
sess.status=WARP connection
sess.ip=External IP address
sess.ip.wait=detecting...
st.connected=CONNECTED
st.connecting=CONNECTING...
st.disconnected=DISCONNECTED
st.disconnecting=DISCONNECTING...
st.paused=PAUSED
sess.avail=[ Service availability ]
sess.measuring=checking...
sess.next=next check in {0} sec
sess.timeout=no response
sess.unreachable=unreachable
sess.pause=Pause
sess.resume=Resume
sess.reconnect=Reconnect the tunnel
sess.changeip=Change IP address
sess.profile=Change bypass profile
sess.settings=Settings
sess.quit=Disconnect and exit
sess.measuring.wait=Checking service availability...
sess.pausing=Pausing the tunnel...
sess.resuming=Resuming the tunnel...
sess.resume.fail=Could not resume the tunnel.
sess.reconnecting=Reconnecting the tunnel...
sess.reconnect.fail=Could not reconnect the tunnel.
sess.quit.ask=Disconnect the tunnel and close the program?
sess.closing=Disconnecting the tunnel and cleaning up routes...
sess.closed=Session closed.
ip.direct=direct
ip.unknown=unknown
ip.unknown.old=unknown
ip.ask=The WARP client will be re-registered, the address may change. Continue?
ip.step.reset=Resetting the WARP client registration...
ip.step.new=A new registration is created when connecting.
ip.step.route=Restoring routing rules...
ip.step.detect=Detecting the new IP address...
ip.detect.fail=Could not detect the new IP. Press Enter in the menu to retry.
ip.same=The address did not change: {0} (Cloudflare assigned the same one).
ip.changed=IP address changed: {0} -> {1}
ip.reconnect.fail=Could not connect after re-registration.
main.title=MAIN MENU
main.sub=Choose a bypass profile to start (enter its number).
main.last=last used
main.noprofiles=No profiles found. Check your internet connection.
main.settings=Settings
main.quit=Exit
auto.starting=Starting profile "{0}" in {1} sec.
auto.cancel=Press any key to cancel and open the menu.
'@

function Initialize-Language ($Code) {
    $global:Lang = if ($Code -eq "en") { "en" } else { "ru" }
    if (-not $global:StrRu) { $global:StrRu = ConvertFrom-StringData -StringData $StringsRu }
    $global:Str = if ($global:Lang -eq "en") { ConvertFrom-StringData -StringData $StringsEn } else { $global:StrRu }
}

function Get-DefaultLanguage {
    try { if ((Get-Culture).TwoLetterISOLanguageName -eq "ru") { return "ru" } } catch {}
    return "en"
}

function T {
    param([string]$Key, [Parameter(ValueFromRemainingArguments = $true)]$A)
    $S = $global:Str[$Key]
    if ($null -eq $S) { $S = $global:StrRu[$Key] }
    if ($null -eq $S) { return $Key }
    if ($null -ne $A -and @($A).Count -gt 0) { return ($S -f @($A)) }
    return $S
}

# ---------------------------------------------------------
# Console UI helpers (single screen layout, 57 columns)
# ---------------------------------------------------------
function Write-Rule ($Color = "DarkGray") { Write-Host ("=" * 57) -ForegroundColor $Color }

function Write-Center ([string]$Text, $Color = "Cyan") {
    $Pad = [math]::Max(0, [int][math]::Floor((57 - $Text.Length) / 2))
    Write-Host ((" " * $Pad) + $Text) -ForegroundColor $Color
}

# Screen: logo, centered title, optional gray description lines, rule
function Write-Screen ([string]$Title, [string[]]$Sub = @(), $TitleColor = "Cyan") {
    Set-ConsoleQuickEdit $false
    Clear-Host
    Write-Header
    Write-Center $Title $TitleColor
    foreach ($Line in $Sub) { Write-Host (" " + $Line) -ForegroundColor Gray }
    Write-Rule
}

# "Label        : value" row
function Write-Row ([string]$Label, [string]$Value, $Color = "Gray", [int]$Pad = 0) {
    Write-Host (" " + $Label.PadRight(26) + ": ") -NoNewline -ForegroundColor White
    Write-Host ($Value.PadRight($Pad)) -ForegroundColor $Color
}

# "[K] Action        description" menu item
function Write-Item ([string]$Key, [string]$Text, $Color = "White", [string]$Desc = "") {
    if ($Desc) {
        Write-Host (" [" + $Key + "] " + $Text.PadRight(22)) -NoNewline -ForegroundColor $Color
        Write-Host $Desc -ForegroundColor DarkGray
    } else {
        Write-Host (" [" + $Key + "] " + $Text) -ForegroundColor $Color
    }
}

function Write-OnOff ([string]$Label, [bool]$On) {
    if ($On) { Write-Row $Label (T 'on') "Green" } else { Write-Row $Label (T 'off') "DarkGray" }
}

function Write-Step ([string]$Text, $Color = "Yellow") { Write-Host (" -> " + $Text) -ForegroundColor $Color }
function Write-Ok ([string]$Text) { Write-Host (" [OK] " + $Text) -ForegroundColor Green }
function Write-Fail ([string]$Text) { Write-Host (" [!] " + $Text) -ForegroundColor Red }
function Write-Note ([string]$Text, $Color = "Gray") { Write-Host ("      " + $Text) -ForegroundColor $Color }

# Indeterminate progress line (same style as the download bar) for operations of unknown length
function Show-Busy ([string]$Label, [int]$Tick, [double]$Elapsed) {
    $Width = 20; $Block = 6; $Span = $Width - $Block
    $Pos = $Tick % (2 * $Span)
    if ($Pos -gt $Span) { $Pos = 2 * $Span - $Pos }
    $Bar = ("░" * $Pos) + ("█" * $Block) + ("░" * ($Span - $Pos))
    Write-Host ("`r -> " + $Label + ": [" + $Bar + "] " + (T 'sec' ([int]$Elapsed)) + "     ") -NoNewline -ForegroundColor Cyan
}

function Complete-Busy ([string]$Label, [bool]$Ok, [double]$Elapsed) {
    if ($Ok) {
        Write-Host ("`r -> " + $Label + ": [" + ("█" * 20) + "] " + (T 'sec' ([int]$Elapsed)) + ", " + (T 'wait.done') + "     ") -ForegroundColor Green
    } else {
        Write-Host ("`r -> " + $Label + ": [" + ("░" * 20) + "] " + (T 'wait.timeout') + "     ") -ForegroundColor Yellow
    }
}

function Read-Choice {
    $Answer = Read-Host (" " + (T 'prompt.choose'))
    Set-ConsoleQuickEdit $false
    return $Answer.Trim().ToLower()
}

function Read-Confirm ([string]$Text, [bool]$Default = $false) {
    $Hint = if ($Default) { "Y/n" } else { "y/N" }
    $Answer = (Read-Host (" " + $Text + " [" + $Hint + "]")).Trim()
    Set-ConsoleQuickEdit $false
    if ($Answer -eq "") { return $Default }
    return ($Answer -match "^[YyДд]")
}

function Wait-Enter {
    Write-Host (" " + (T 'press.enter')) -ForegroundColor Gray
    Read-Host | Out-Null
    Set-ConsoleQuickEdit $false
}

# Quick-Edit is switched off for the session (accidental clicks freeze the console);
# turn it on while the user types a pasted value so right-click paste works
function Set-ConsoleQuickEdit ([bool]$Enable) {
    try {
        $Handle = [Win32.Win32Console]::GetStdHandle(-10)
        $Mode = 0
        if ([Win32.Win32Console]::GetConsoleMode($Handle, [ref]$Mode)) {
            if ($Enable) { $Mode = $Mode -bor 0x0040 -bor 0x0080 } else { $Mode = ($Mode -band -bnot 0x0040) -bor 0x0080 }
            [void][Win32.Win32Console]::SetConsoleMode($Handle, [uint32]$Mode)
        }
    } catch {}
}

function Read-LicenseKey {
    Write-Note (T 'key.paste') "DarkGray"
    Set-ConsoleQuickEdit $true
    try { $Raw = Read-Host (" " + (T 'key.prompt')) } finally { Set-ConsoleQuickEdit $false }
    return ($Raw -replace '[\s"''`]', '')
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

$global:WinwsPendingStop = $false
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
    $global:CurrentExternalIp = T 'sess.ip.wait'
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
            $Tag = if ($Warp -eq "plus") { " [WARP+]" } elseif ($Warp -eq "on") { " [WARP]" } elseif ($Warp -eq "off") { (" [" + (T 'ip.direct') + "]") } else { "" }
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
    $global:CurrentExternalIp = T 'ip.unknown'
    return $true
}

# Blocking helper for one-off flows (waits until the address is known or the time is up)
function Wait-ExternalIp ($Seconds = 20) {
    $Label = T 'wait.ip'
    $Sw = [Diagnostics.Stopwatch]::StartNew()
    for ($Tick = 0; $Tick -lt ($Seconds * 4); $Tick++) {
        [void](Receive-IpLookup)
        if ($global:IpOk) { Complete-Busy $Label $true $Sw.Elapsed.TotalSeconds; return }
        if (-not $global:IpTask -and ([DateTime]::Now - $global:LastIpAttempt).TotalSeconds -ge 2) { Start-IpLookup 0 }
        Show-Busy $Label $Tick $Sw.Elapsed.TotalSeconds
        Start-Sleep -Milliseconds 250
    }
    Complete-Busy $Label $false $Sw.Elapsed.TotalSeconds
}

$StorageDir = "$env:LOCALAPPDATA\WarpBypass"
if (-not (Test-Path $StorageDir)) { New-Item -ItemType Directory -Path $StorageDir -Force -ErrorAction SilentlyContinue *> $null }

$ZapretDir = "$StorageDir\zapret"
$ZapretZip = "$StorageDir\zapret.zip"
$ZapretUrl = "https://github.com/Flowseal/zapret-discord-youtube/archive/refs/heads/main.zip"
$WarpCli = "C:\Program Files\Cloudflare\Cloudflare WARP\warp-cli.exe"
$WarpSettingsPath = "C:\ProgramData\Cloudflare\settings.json"

$ConfigPath = "$StorageDir\config.json"
$PingListPath = "$StorageDir\ping_list.txt"

Clear-Host

$DefaultConfig = @{ AutoPreset = $false; LastPreset = ""; AutoPresetTimeout = 0; Language = ""; PendingRuRouting = $false; AutoPing = 1; DnsFix = $false; IgnoredVersion = "0.0"; AutoUpdate = $true; PingInterval = 30; WarpLicense = "" }

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

if ($Config.Language -ne "ru" -and $Config.Language -ne "en") { $Config.Language = Get-DefaultLanguage }
Initialize-Language $Config.Language

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
        [string]$Label = ""
    )
    if (-not $Label) { $Label = T 'dl.file' }
    $UnitMb = T 'unit.mb'
    
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
                Write-Host (" -> ${Label}: [$Bar] $PercentInt% ($CurrentMb / $TotalMb $UnitMb)   ") -ForegroundColor Cyan -NoNewline
            } else {
                $CurrentMb = [math]::Round($DownloadedBytes / 1MB, 1)
                try { [console]::SetCursorPosition($Left, $Top) } catch {}
                Write-Host (" -> ${Label}: " + (T 'dl.size' $CurrentMb) + "   ") -ForegroundColor Cyan -NoNewline
            }
        }
        
        try { [console]::SetCursorPosition($Left, $Top) } catch {}
        if ($TotalBytes -gt 0) {
            $TotalMb = [math]::Round($TotalBytes / 1MB, 1)
            Write-Host (" -> ${Label}: [████████████████████] 100% ($TotalMb / $TotalMb $UnitMb)   ") -ForegroundColor Green
        } else {
            Write-Host (" -> ${Label}: " + (T 'dl.done') + "   ") -ForegroundColor Green
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
    # Step 0: language (shown in both languages)
    Clear-Host
    Write-Header
    Write-Center "LANGUAGE / ЯЗЫК"
    Write-Rule
    Write-Item "1" "English" "White"
    Write-Item "2" "Русский" "White"
    Write-Rule
    $DefaultLang = Get-DefaultLanguage
    $DefaultNum = if ($DefaultLang -eq "ru") { "2" } else { "1" }
    $Sel = (Read-Host (" Select / Выберите [1-2, Enter = " + $DefaultNum + "]")).Trim()
    $Code = if ($Sel -eq "1") { "en" } elseif ($Sel -eq "2") { "ru" } else { $DefaultLang }
    $Config.Language = $Code
    Initialize-Language $Code

    Write-Screen (T 'wiz.title') @((T 'wiz.welcome1'), (T 'wiz.welcome2'))
    Write-Host ""
    Write-Host (" " + (T 'wiz.step1')) -ForegroundColor White
    $Config.DnsFix = Read-Confirm (T 'wiz.dns') $true
    $Config.AutoUpdate = Read-Confirm (T 'wiz.upd') $true
    $Config.PendingRuRouting = Read-Confirm (T 'wiz.route') $true

    Write-Screen (T 'wiz.profile.title') @((T 'wiz.profile.hint'))
    Write-Item "1" (T 'wiz.profile.rec') "Green"
    Write-Item "2" (T 'wiz.profile.later') "Gray"
    Write-Rule
    $Choice = "x"
    while ($Choice -notmatch "^[12]$") {
        $Choice = (Read-Host (" " + (T 'wiz.profile.prompt'))).Trim()
        if ($Choice -eq "") { $Choice = "1" }
    }
    Set-ConsoleQuickEdit $false
    if ($Choice -eq "1") {
        $Config.LastPreset = "$ZapretDir\general (ALT12).bat"
        $Config.AutoPreset = $true
    }
    Save-Config

    Write-Host ""
    Write-Ok (T 'wiz.done')
    Write-Note (T 'wiz.saved' "AppData\Local\WarpBypass\config.json")
    Write-Host ""
    Write-Host (" " + (T 'press.key')) -ForegroundColor White
    [console]::ReadKey($true) | Out-Null
}

function Check-AppUpdate {
    if (-not $IsOnline) { return }
    Write-Step (T 'upd.checking') "Gray"
    
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $ReleaseInfo = Invoke-RestMethod -Uri $RepoApiUrl -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
 
        $RemoteVersionStr = ($ReleaseInfo.tag_name -replace '(?i)^v', '') -replace '[-+].*$', ''
        $RemoteVer = [version]$RemoteVersionStr
        $LocalVer  = [version]$AppVersion
 
        if ($RemoteVer -gt $LocalVer) {
            if ($Config.IgnoredVersion -ne $RemoteVersionStr) {
                Write-Host ""
                Write-Rule "Yellow"
                Write-Host (" " + (T 'upd.available' $RemoteVersionStr $AppVersion)) -ForegroundColor Green
                Write-Rule "Yellow"
                $UpdateChoice = Read-Confirm (T 'upd.ask') $true
                
                if ($UpdateChoice) {
                    $DownloadUrl = "https://raw.githubusercontent.com/BushHub/WarpBypass/$($ReleaseInfo.tag_name)/WarpBypass.bat"
                    $BatPath = $env:WARP_BAT_PATH
                    $TempFile = "$env:TEMP\WarpBypass_new.bat"
                    $UpdaterBat = "$env:TEMP\WarpBypass_updater.bat"
                    
                    Start-DownloadWithProgress -Uri $DownloadUrl -OutFile $TempFile -Label (T 'upd.downloading')
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
                        Write-Fail (T 'upd.invalid')
                        Start-Sleep -Seconds 2
                        return
                    }
                    Write-Step (T 'upd.installing') "Cyan"
                    
                    $UpdaterCode = "@echo off`nchcp 65001 >nul`ntimeout /t 2 /nobreak >nul`nmove /y `"$TempFile`" `"$BatPath`" >nul`nstart `"`" `"$BatPath`"`ndel `"%~f0`""
                    [IO.File]::WriteAllText($UpdaterBat, $UpdaterCode, [System.Text.Encoding]::UTF8)
                    
                    Start-Process -FilePath $UpdaterBat -WindowStyle Hidden
                    Exit
                } else {
                    $IgnoreChoice = Read-Confirm (T 'upd.ignore.ask' $RemoteVersionStr) $false
                    if ($IgnoreChoice) {
                        $Config.IgnoredVersion = $RemoteVersionStr
                        Save-Config
                        Write-Step (T 'upd.ignored' $RemoteVersionStr) "DarkGray"
                        Start-Sleep -Seconds 1
                    }
                }
            }
        } else {
            Write-Ok (T 'upd.latest')
            Start-Sleep -Milliseconds 600
        }
    } catch {
        Write-Step (T 'upd.failed') "DarkGray"
        Start-Sleep -Seconds 1
    }
}

function Check-Updates {
    if (-not $IsOnline) {
        Write-Step (T 'zap.offline') "DarkGray"
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
            Write-Step (T 'zap.checking') "Gray"
            try {
                $UpdateInfo = Invoke-RestMethod -Uri $RepoAPI -UseBasicParsing -UserAgent "WarpBypass" -TimeoutSec 5 -ErrorAction Stop
                $global:LatestSHA = $UpdateInfo.sha
                $LocalSHA = if (Test-Path $VersionFile) { (Get-Content $VersionFile).Trim() } else { "" }
                if ($LocalSHA -ne $global:LatestSHA) { $NeedUpdate = $true } else { Out-File -FilePath $LastCheckFile -InputObject ($Today.ToString()) -Force }
            } catch { Write-Step (T 'zap.audit.fail') "DarkGray" }
        }
    }
    
    if ($NeedUpdate) {
        # fresh install: remember which commit was downloaded so the next check does not download it again
        if (-not $global:LatestSHA) {
            try { $global:LatestSHA = (Invoke-RestMethod -Uri $RepoAPI -UseBasicParsing -UserAgent "WarpBypass" -TimeoutSec 5 -ErrorAction Stop).sha } catch {}
        }
        # Make sure no running winws is locking files
        try { Stop-Winws } catch {}
        Start-Sleep -Milliseconds 500
        
        $TmpDir = "$StorageDir\zapret_tmp"
        try {
            Start-DownloadWithProgress -Uri $ZapretUrl -OutFile $ZapretZip -Label (T 'zap.download')
            if (Test-Path $TmpDir) { Remove-Item $TmpDir -Recurse -Force -ErrorAction SilentlyContinue }
            Expand-Archive -Path $ZapretZip -DestinationPath $TmpDir -Force
            $ExtractedDir = Get-ChildItem -Path $TmpDir -Directory | Where-Object { $_.Name -like "zapret-discord-youtube*" } | Select-Object -First 1
            if (-not $ExtractedDir -or -not (Test-Path "$($ExtractedDir.FullName)\bin\winws.exe")) {
                throw (T 'zap.badarchive')
            }
            try { Stop-WinDivert } catch {}
            if (Test-Path $ZapretDir) { Remove-Item $ZapretDir -Recurse -Force -ErrorAction Stop }
            New-Item -ItemType Directory -Path $ZapretDir -Force | Out-Null
            Copy-Item -Path "$($ExtractedDir.FullName)\*" -Destination $ZapretDir -Recurse -Force
            if ($global:LatestSHA) { Out-File -FilePath $VersionFile -InputObject $global:LatestSHA -Force; Out-File -FilePath $LastCheckFile -InputObject ((Get-Date).ToString()) -Force }
            $global:ZapretEnvBlock = $null
        } catch {
            Write-Fail (T 'zap.updfail' $_.Exception.Message)
            if (-not (Test-Path "$ZapretDir\bin\winws.exe")) { Write-Note (T 'zap.missing') "Red" }
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
    
    if (-not $Silent) { Write-Step (T 'bl.checking') }
    $LocalVer  = Get-LocalBypassVersion
    $RemoteVer = Get-RemoteBypassVersion
    
    if ($null -eq $RemoteVer) {
        if (-not $Silent) {
            Write-Note (T 'bl.srvfail') "Red"
            Write-Note (T 'bl.local') "DarkGray"
        }
        return $false
    }
    
    if (-not $Force -and $LocalVer -eq $RemoteVer) {
        if (-not $Silent) { Write-Note (T 'bl.current' $RemoteVer) "Green" }
        return $false
    }
    
    if (-not $Silent) {
        if ($LocalVer -and $LocalVer -ne $RemoteVer) {
            Write-Note (T 'bl.updating' $LocalVer $RemoteVer) "Cyan"
        } elseif (-not $LocalVer) {
            Write-Note (T 'bl.first' $RemoteVer) "Cyan"
        } else {
            Write-Note (T 'bl.reload' $RemoteVer) "Yellow"
        }
    }
    
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri "$BypassListBaseUrl/ru_bypass_domain.txt" -OutFile "$BypassCacheDir\ru_bypass_domain.txt" -UseBasicParsing
        Invoke-WebRequest -Uri "$BypassListBaseUrl/ru_bypass_ip.txt"     -OutFile "$BypassCacheDir\ru_bypass_ip.txt"     -UseBasicParsing
        Set-Content -Path "$BypassCacheDir\ru_bypass_version.txt" -Value $RemoteVer -Encoding UTF8
        if (-not $Silent) { Write-Note (T 'bl.updated' $RemoteVer) "Green" }
        return $true
    } catch {
        if (-not $Silent) { Write-Note (T 'bl.error' $_) "Red" }
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
    $Failures = [System.Collections.Generic.List[object]]::new()
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
                    $Failures.Add([PSCustomObject]@{ Cmd = $Item.Cmd; Msg = $Msg })
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
                $Failures.Add([PSCustomObject]@{ Cmd = $CmdArgs[$Next]; Msg = (T 'fail.start') })
                $Done++
            }
            $Next++
        }
        
        $percent = [math]::Round(($Done / [math]::Max(1, $Total)) * 100)
        Write-Host -NoNewline ("`r      " + (T 'ru.progress' $percent $Done $Total))
        Start-Sleep -Milliseconds 30
    }
    
    Write-Host ""
    return $Failures.ToArray()
}

# WARP works with ASCII host names: "*.бел" -> "*.xn--90ais"
function ConvertTo-AsciiDomain ([string]$Name) {
    if ($Name -match "^[\x00-\x7F]*$") { return $Name }
    try {
        $Idn = New-Object System.Globalization.IdnMapping
        return (($Name.Split('.') | ForEach-Object { if ($_ -match "^[\x00-\x7F]*$") { $_ } else { $Idn.GetAscii($_) } }) -join '.')
    } catch { return $Name }
}

function Apply-RuBypassTemplate {
    $DomainFile = "$BypassCacheDir\ru_bypass_domain.txt"
    $IpFile     = "$BypassCacheDir\ru_bypass_ip.txt"
    
    # Ensure lists exist, download if needed
    if (-not (Test-Path $DomainFile) -or -not (Test-Path $IpFile)) {
        Write-Step (T 'ru.loading')
        Update-BypassLists | Out-Null
    }
    
    if (-not (Test-Path $DomainFile)) {
        Write-Fail (T 'ru.fail.list')
        return
    }
    
    Write-Step (T 'ru.preparing')
    
    $Domains  = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $IpRanges = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    
    foreach ($line in (Get-Content $DomainFile -Encoding UTF8)) {
        $line = $line.Trim()
        if ($line -eq "" -or $line.StartsWith("#")) { continue }
        if ($line -notmatch '^(\*\.)?[^\s/\\"''&|<>]+$') { continue }
        [void]$Domains.Add((ConvertTo-AsciiDomain $line))
    }
    
    if (Test-Path $IpFile) {
        foreach ($line in (Get-Content $IpFile -Encoding UTF8)) {
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
    
    if (-not (Test-Path $WarpCli)) {
        Write-Fail (T 'ru.nowarp')
        return
    }
    $DaemonState = & $WarpCli --accept-tos status 2>&1 | Out-String
    if ($DaemonState -match "(?i)Unable to connect|not running|channel closed") {
        Write-Fail (T 'ru.daemon')
        return
    }
    
    $Sent = $false
    $Failures = @()
    for ($Round = 1; $Round -le 3; $Round++) {
        $Cmds = @(Get-MissingRuleCommands $Domains $IpRanges)
        if ($Cmds.Count -eq 0) { break }
        if ($Round -eq 1) {
            Write-Step (T 'ru.adding' $Cmds.Count)
        } else {
            Write-Step (T 'ru.retry' $Cmds.Count)
            Start-Sleep -Seconds 3
        }
        $Failures = @(Invoke-ParallelWarpCli -CmdArgs $Cmds -ThrottleLimit $(if ($Round -eq 1) { 30 } else { 4 }))
        $Sent = $true
        Start-Sleep -Seconds 1
    }
    
    $Left = @(Get-MissingRuleCommands $Domains $IpRanges)
    if (-not $Sent) {
        Write-Ok (T 'ru.already')
        return
    }
    
    # In an active session the tunnel is rebuilt after the rules change: keep winws on until it is connected again
    if ($global:ActivePreset -and -not $global:TunnelPaused) {
        Write-Step (T 'ru.reconnect')
        Restart-WarpConnection
    }
    $global:CachedWarpStatus = $null
    
    if ($Left.Count -gt 0) {
        Write-Fail (T 'ru.failed' $Left.Count)
        $Shown = if ($Failures.Count -gt 0) { @($Failures | Select-Object -First 5 | ForEach-Object { "$($_.Cmd) -> $($_.Msg)" }) } else { @($Left | Select-Object -First 5) }
        foreach ($F in $Shown) { Write-Note $F "DarkGray" }
        if ($Left.Count -gt 5) { Write-Note (T 'route.more' ($Left.Count - 5)) "DarkGray" }
    } else {
        Write-Ok (T 'ru.done')
    }
}

# Commands for the rules that are not in the WARP settings yet
function Get-MissingRuleCommands ($Domains, $IpRanges) {
    $ExistingHosts = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $ExistingIps   = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    
    if (Test-Path $WarpSettingsPath) {
        try {
            $WarpSettings = Get-Content $WarpSettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($WarpSettings.excluded_hosts) {
                foreach ($e in $WarpSettings.excluded_hosts) {
                    $k = if ($e -is [Array]) { $e[0] } else { $e }
                    [void]$ExistingHosts.Add($k)
                }
            }
            if ($WarpSettings.excluded_ips) {
                foreach ($e in $WarpSettings.excluded_ips) {
                    $k = if ($e -is [Array]) { $e[0] } else { $e }
                    [void]$ExistingIps.Add($k)
                }
            }
        } catch {}
    }
    
    $Cmds = [System.Collections.Generic.List[string]]::new()
    foreach ($dom in $Domains) {
        if (-not $ExistingHosts.Contains($dom)) { $Cmds.Add("tunnel host add $dom") }
    }
    foreach ($ip in $IpRanges) {
        if (-not $ExistingIps.Contains($ip)) {
            if ($ip.Contains('/')) { $Cmds.Add("tunnel ip add-range $ip") } else { $Cmds.Add("tunnel ip add $ip") }
        }
    }
    return $Cmds.ToArray()
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
        $LocalVer  = Get-LocalBypassVersion
        $Entries   = Get-SplitTunnelEntries
        $HostCount = @($Entries.Hosts).Count
        $IpCount   = @($Entries.Ips).Count
        
        Write-Screen (T 'route.title') @((T 'route.sub1'), (T 'route.sub2'))
        if ($HostCount + $IpCount -gt 0) {
            Write-Row (T 'route.state') (T 'route.state.on' $HostCount $IpCount) "Green"
        } else {
            Write-Row (T 'route.state') (T 'off') "DarkGray"
        }
        if ($LocalVer) { Write-Row (T 'route.list') (T 'route.list.ver' $LocalVer) "Gray" } else { Write-Row (T 'route.list') (T 'route.list.none') "DarkGray" }
        Write-Rule
        Write-Item "1" (T 'route.i1') "Green"
        Write-Item "2" (T 'route.i2') "Yellow"
        Write-Item "3" (T 'route.i3') "White"
        Write-Item "4" (T 'route.i4') "Red"
        Write-Item "0" (T 'back') "Gray"
        Write-Rule
        
        switch (Read-Choice) {
            "1" {
                Write-Host ""
                Apply-RuBypassTemplate
                Write-Host ""
                Wait-Enter
            }
            "2" {
                Write-Host ""
                Update-BypassLists -Force | Out-Null
                Write-Host ""
                Wait-Enter
            }
            "3" {
                Write-Screen (T 'route.rules.title')
                Write-Host (" " + (T 'route.sites' $HostCount)) -ForegroundColor Yellow
                if ($HostCount -gt 0) {
                    $Entries.Hosts | Select-Object -First 15 | ForEach-Object { Write-Host ("   " + $_) -ForegroundColor Green }
                    if ($HostCount -gt 15) { Write-Host ("   " + (T 'route.more' ($HostCount - 15))) -ForegroundColor DarkGray }
                } else {
                    Write-Host ("   " + (T 'none')) -ForegroundColor DarkGray
                }
                Write-Host ""
                Write-Host (" " + (T 'route.ips' $IpCount)) -ForegroundColor Yellow
                if ($IpCount -gt 0) {
                    $Entries.Ips | Select-Object -First 15 | ForEach-Object { Write-Host ("   " + $_) -ForegroundColor Cyan }
                    if ($IpCount -gt 15) { Write-Host ("   " + (T 'route.more' ($IpCount - 15))) -ForegroundColor DarkGray }
                } else {
                    Write-Host ("   " + (T 'none')) -ForegroundColor DarkGray
                }
                Write-Rule
                Wait-Enter
            }
            "4" {
                if (Read-Confirm (T 'route.confirm.off')) {
                    Write-Step (T 'route.removing')
                    & $WarpCli --accept-tos tunnel host reset | Out-Null
                    & $WarpCli --accept-tos tunnel ip reset | Out-Null
                    Write-Ok (T 'route.removed')
                    if ($global:ActivePreset -and -not $global:TunnelPaused) {
                        Write-Step (T 'ru.reconnect')
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
    Write-Screen (T 'bench.title') @((T 'bench.sub1'), (T 'bench.sub2'), (T 'bench.sub3'))
    
    $ZapretDirFullName = if (Test-Path $ZapretDir) { (Get-Item $ZapretDir).FullName } else { "" }
    if (-not $ZapretDirFullName) {
        Write-Fail (T 'bench.nodir')
        Wait-Enter; return
    }
    
    $WasConnected = ((Get-WarpStatus) -eq "Connected")
    
    # Exclude service.bat, service_install.bat, and service_remove.bat
    $BatFiles = Get-ChildItem -Path $ZapretDirFullName -Filter "*.bat" | Where-Object { $_.Name -notmatch "(?i)service(_install|_remove)?\.bat$" }
    if ($BatFiles.Count -eq 0) {
        Write-Fail (T 'bench.nofiles')
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
        $FileName = $File.BaseName
        Write-Host (" -> " + (T 'bench.testing' $FileName) + " ") -NoNewline -ForegroundColor Gray
        
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
            Write-Host (T 'bench.ok' $SuccessCount $TestTargets.Count $AvgPing) -ForegroundColor Green
            $Results += [PSCustomObject]@{ Preset = $File.FullName; Name = $FileName; Status = "OK"; SuccessRate = $SuccessCount; Ping = $AvgPing }
        } else {
            Write-Host (T 'bench.fail') -ForegroundColor Red
            $Results += [PSCustomObject]@{ Preset = $File.FullName; Name = $FileName; Status = "Fail"; SuccessRate = 0; Ping = 9999 }
        }
    }
    
    Write-Rule
    Write-Center (T 'bench.results')
    Write-Rule
    
    $Best = $Results | Where-Object { $_.Status -eq "OK" } | Sort-Object @{Expression="SuccessRate";Descending=$true}, @{Expression="Ping";Ascending=$true} | Select-Object -First 1
    if ($Best) {
        Write-Host (" " + (T 'bench.best') + " ") -NoNewline
        Write-Host $Best.Name -ForegroundColor Green -NoNewline
        Write-Host ("  (" + (T 'bench.best.d' $Best.SuccessRate $TestTargets.Count $Best.Ping) + ")") -ForegroundColor White
        Write-Host ""
        if (Read-Confirm (T 'bench.save.ask')) {
            $Config.LastPreset = $Best.Preset
            $Config.AutoPreset = $true
            Save-Config
            Write-Ok (T 'bench.saved')
        }
    } else {
        Write-Fail (T 'bench.none')
    }
    if ($WasConnected -and $global:ActivePreset) {
        Write-Step (T 'bench.restore')
        Connect-WarpTunnel $global:ActivePreset | Out-Null
        $global:CachedWarpStatus = $null
    }
    Write-Host ""
    Wait-Enter
}

function Show-PingSettings {
    while ($true) {
        Write-Screen (T 'ping.title') @((T 'ping.sub'))
        if ($Config.AutoPing -eq 1) { Write-Row (T 'ping.mode') (T 'ping.mode.static') "Green" }
        elseif ($Config.AutoPing -eq 2) { Write-Row (T 'ping.mode') (T 'ping.mode.dynamic' $Config.PingInterval) "Cyan" }
        else { Write-Row (T 'ping.mode') (T 'off') "DarkGray" }
        Write-Rule
        Write-Item "1" (T 'ping.i1') "White"
        Write-Item "2" (T 'ping.i2') "White"
        Write-Item "3" (T 'ping.i3') "White"
        Write-Item "4" (T 'ping.i4') "Red"
        Write-Item "0" (T 'back') "Gray"
        Write-Rule
        
        switch (Read-Choice) {
            "1" {
                $Config.AutoPing = ($Config.AutoPing + 1) % 3
                Save-Config
            }
            "2" {
                if ($Config.AutoPing -ne 2) {
                    Write-Fail (T 'ping.int.only')
                    Start-Sleep -Seconds 2
                    continue
                }
                Write-Screen (T 'ping.int.title') @((T 'ping.int.sub'))
                Write-Item "1" (T 'sec' 15) "White"
                Write-Item "2" ((T 'sec' 30) + " (" + (T 'recommended') + ")") "White"
                Write-Item "3" (T 'sec' 60) "White"
                Write-Item "4" (T 'sec' 120) "White"
                Write-Item "5" (T 'ping.int.custom') "White"
                Write-Rule
                switch (Read-Choice) {
                    "1" { $Config.PingInterval = 15 }
                    "2" { $Config.PingInterval = 30 }
                    "3" { $Config.PingInterval = 60 }
                    "4" { $Config.PingInterval = 120 }
                    "5" {
                        $CustomVal = Read-Host (" " + (T 'ping.int.ask'))
                        $ParsedVal = 30
                        if ([int]::TryParse($CustomVal, [ref]$ParsedVal) -and $ParsedVal -ge 5) {
                            $Config.PingInterval = $ParsedVal
                        } else {
                            $Config.PingInterval = 30
                            Write-Fail (T 'ping.int.bad')
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
            { $_ -eq "4" -or $_ -eq "d" } {
                if (Read-Confirm (T 'ping.reset.ask')) {
                    $Config.AutoPing = $DefaultConfig.AutoPing
                    $Config.PingInterval = $DefaultConfig.PingInterval
                    Save-Config
                    Write-Ok (T 'ping.reset.done')
                    Start-Sleep -Seconds 1
                }
            }
            "0" { return }
        }
    }
}

# Installed Cloudflare WARP / Cloudflare One Client MSI product (null when it is not installed)
function Get-WarpProduct {
    $Roots = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*")
    try {
        foreach ($Item in @(Get-ItemProperty -Path $Roots -ErrorAction SilentlyContinue)) {
            if ($Item.DisplayName -match "^Cloudflare (WARP|One)" -and $Item.DisplayName -notmatch "cloudflared") {
                $Guid = $null
                if ($Item.PSChildName -match "^\{[0-9A-Fa-f-]{36}\}$") { $Guid = $Item.PSChildName }
                elseif ($Item.UninstallString -match "(\{[0-9A-Fa-f-]{36}\})") { $Guid = $Matches[1] }
                if ($Guid) { return [PSCustomObject]@{ Name = $Item.DisplayName; Guid = $Guid } }
            }
        }
    } catch {}
    return $null
}

function Remove-WarpClient ($Product) {
    if (Test-Path $WarpCli) {
        & $WarpCli --accept-tos disconnect 2>&1 | Out-Null
        & $WarpCli --accept-tos registration delete 2>&1 | Out-Null
        & $WarpCli --accept-tos tunnel host reset 2>&1 | Out-Null
        & $WarpCli --accept-tos tunnel ip reset 2>&1 | Out-Null
    }
    Stop-WarpGui
    $Label = T 'wait.uninstall'
    $Sw = [Diagnostics.Stopwatch]::StartNew()
    $Msi = Start-Process msiexec.exe -ArgumentList "/x $($Product.Guid) /qn /norestart" -PassThru -WindowStyle Hidden
    $Tick = 0
    while (-not $Msi.HasExited -and $Sw.Elapsed.TotalMinutes -lt 3) {
        if ($Tick % 4 -eq 0) { Stop-WarpGui }
        Show-Busy $Label $Tick $Sw.Elapsed.TotalSeconds
        Start-Sleep -Milliseconds 250
        $Tick++
    }
    $Ok = $false
    if ($Msi.HasExited) { $Msi.WaitForExit(); $Ok = ($Msi.ExitCode -eq 0 -or $Msi.ExitCode -eq 3010 -or $Msi.ExitCode -eq 1605) }
    Complete-Busy $Label $Ok $Sw.Elapsed.TotalSeconds
    if ($Ok) { Write-Ok (T 'un.warp.done') } else { Write-Fail (T 'un.warp.fail') }
}

function Uninstall-WarpBypass {
    Write-Screen (T 'un.title') @() "Red"
    
    $Product = Get-WarpProduct
    $RemoveClient = $false
    if ($Product) {
        Write-Host ""
        $RemoveClient = Read-Confirm (T 'un.warp.ask') $true
        Write-Host ""
    }
    
    Write-Step (T 'un.stop')
    try { Stop-Winws } catch {}
    try { Stop-WinDivert } catch {}
    Start-Sleep -Seconds 1
    
    if ($RemoveClient) {
        Remove-WarpClient $Product
    } else {
        Write-Step (T 'un.restore')
        if (Test-Path $WarpCli) {
            & $WarpCli --accept-tos disconnect *> $null
            & $WarpCli --accept-tos mode warp *> $null
            & $WarpCli --accept-tos tunnel host reset *> $null
            & $WarpCli --accept-tos tunnel ip reset *> $null
        }
        try {
            Set-Service -Name "CloudflareWARP" -StartupType Automatic -ErrorAction SilentlyContinue | Out-Null
        } catch {}
    }
    
    Write-Step (T 'un.registry')
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
    
    Write-Step (T 'un.files')
    $MyPID = $PID
    $CmdArgs = @(
        '-NoProfile'
        '-WindowStyle'
        'Hidden'
        '-Command'
        "while (Get-Process -Id $MyPID -ErrorAction SilentlyContinue) { Start-Sleep 1 }; for (`$i = 0; `$i -lt 15 -and (Test-Path -LiteralPath '$($StorageDir.Replace("'","''"))'); `$i++) { Remove-Item -LiteralPath '$($StorageDir.Replace("'","''"))' -Recurse -Force -ErrorAction SilentlyContinue; Start-Sleep 1 }"
    )
    Start-Process powershell -ArgumentList $CmdArgs -WindowStyle Hidden
    
    Write-Rule
    Write-Ok (T 'un.done')
    Write-Note (T 'un.done2')
    Write-Note (T 'un.done3')
    Write-Rule
    Start-Sleep -Seconds 4
    exit
}

function Show-ConnectionSettings {
    while ($true) {
        Write-Screen (T 'conn.title') @((T 'conn.sub'))
        $ProfileName = if ($Config.LastPreset) { [IO.Path]::GetFileNameWithoutExtension($Config.LastPreset) } else { T 'conn.profile.none' }
        Write-Row (T 'conn.profile') $ProfileName "Cyan"
        Write-OnOff (T 'conn.auto') ([bool]$Config.AutoPreset)
        if ($Config.AutoPresetTimeout -eq 0) { Write-Row (T 'conn.delay') (T 'conn.delay.instant') "Cyan" } else { Write-Row (T 'conn.delay') (T 'sec' $Config.AutoPresetTimeout) "Green" }
        Write-OnOff (T 'conn.dns') ([bool]$Config.DnsFix)
        Write-Rule
        Write-Item "1" (T 'conn.i1') "White"
        Write-Item "2" (T 'conn.i2') "White"
        Write-Item "3" (T 'conn.i3') "White"
        Write-Item "0" (T 'back') "Gray"
        Write-Rule
        
        switch (Read-Choice) {
            "1" { $Config.AutoPreset = -not $Config.AutoPreset; Save-Config }
            "2" {
                $Val = Read-Host (" " + (T 'conn.delay.ask'))
                $ParsedVal = 0
                if ([int]::TryParse($Val, [ref]$ParsedVal) -and $ParsedVal -ge 0) {
                    $Config.AutoPresetTimeout = $ParsedVal
                    Save-Config
                } else {
                    Write-Fail (T 'conn.delay.bad')
                    Start-Sleep -Seconds 1
                }
            }
            "3" { $Config.DnsFix = -not $Config.DnsFix; Save-Config }
            "0" { return }
        }
    }
}

function Show-SystemSettings {
    while ($true) {
        Write-Screen (T 'sys.title') @((T 'sys.sub'))
        Write-Row (T 'sys.lang') $(if ($global:Lang -eq "en") { "English" } else { "Русский" }) "Cyan"
        if ($Config.WarpLicense) { Write-Row (T 'sys.key') (T 'sys.key.set') "Green" } else { Write-Row (T 'sys.key') (T 'sys.key.unset') "DarkGray" }
        Write-OnOff (T 'sys.upd') ([bool]$Config.AutoUpdate)
        Write-Row (T 'sys.ver') ("v" + $AppVersion) "Gray"
        Write-Rule
        Write-Item "1" (T 'sys.i1') "White"
        Write-Item "2" (T 'sys.i2') "White"
        Write-Item "3" (T 'sys.i3') "White"
        Write-Item "4" (T 'sys.i4') "Yellow"
        Write-Item "5" (T 'sys.i5') "Red"
        Write-Item "0" (T 'back') "Gray"
        Write-Rule
        
        switch (Read-Choice) {
            "1" {
                Write-Item "1" "English" "White"
                Write-Item "2" "Русский" "White"
                Write-Rule
                $L = Read-Choice
                if ($L -eq "1") { $Config.Language = "en" } elseif ($L -eq "2") { $Config.Language = "ru" }
                Initialize-Language $Config.Language
                Save-Config
            }
            "2" {
                Write-Screen (T 'key.title') @((T 'key.sub1'), (T 'key.sub2'))
                $Key = Read-LicenseKey
                if ($Key -eq "") {
                    $Config.WarpLicense = ""
                    Save-Config
                    Write-Ok (T 'key.removed')
                } elseif ($Key -notmatch "^[A-Za-z0-9]{8}-[A-Za-z0-9]{8}-[A-Za-z0-9]{8}$") {
                    Write-Fail (T 'key.badformat')
                } else {
                    $Config.WarpLicense = $Key
                    Save-Config
                    if (Set-WarpLicense $Key) {
                        Write-Ok (T 'key.accepted')
                        if ($global:ActivePreset -and -not $global:TunnelPaused) {
                            Write-Step (T 'key.checking')
                            Restart-WarpConnection
                            Wait-ExternalIp 15
                            if ($global:CurrentExternalIp -match "WARP\+") {
                                Write-Ok (T 'key.plus.on')
                            } else {
                                Write-Fail (T 'key.plus.off')
                            }
                        } else {
                            Write-Note (T 'key.later') "Gray"
                        }
                    } else {
                        Write-Fail (T 'key.rejected')
                        Write-Note (T 'key.kept') "Gray"
                    }
                }
                Start-Sleep -Seconds 4
            }
            "3" { $Config.AutoUpdate = -not $Config.AutoUpdate; Save-Config }
            "4" {
                if (Read-Confirm (T 'sys.reset.ask')) {
                    foreach ($Key in $DefaultConfig.Keys) {
                        if ($Key -ne "WarpLicense" -and $Key -ne "Language") { $Config.$Key = $DefaultConfig[$Key] }
                    }
                    Save-Config
                    if (Test-Path $WarpCli) {
                        & $WarpCli --accept-tos mode warp | Out-Null
                    }
                    Write-Ok (T 'sys.reset.done')
                    Start-Sleep -Seconds 2
                }
            }
            "5" {
                if (Read-Confirm (T 'sys.uninstall.ask')) { Uninstall-WarpBypass }
            }
            "0" { return }
        }
    }
}

function Show-WarpStats {
    if (-not (Test-Path $WarpCli)) {
        Write-Fail (T 'stat.nowarp')
        Start-Sleep -Seconds 2
        return
    }
    $Na = T 'na'
    $Mtu = $Na; $Speed = $Na; $Dns = $Na; $Api = $Na; $Fw = $Na; $Loss = "0.00%"
    
    while ($true) {
        Write-Screen (T 'stat.title') @((T 'stat.sub'))
        
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
                    $Mtu = [string][math]::Round([double]$Matches[1])
                }
                elseif ($Line -match "quic_utilized_bandwidth\s*\(value\s*=\s*([\d.]+)\)") {
                    $Bits = [double]$Matches[1]
                    if ($Bits -ge 1e6) {
                        $Speed = (T 'stat.speed.fmt' ([math]::Round($Bits / 1e6, 1)) ([math]::Round($Bits / 8e6, 1)))
                    } else {
                        $Speed = (T 'stat.speed.low' ([math]::Round($Bits / 1e3, 1)))
                    }
                }
                elseif ($Line -match "doh_avg_ms\s*\(.*avg\s*=\s*([\d.]+)\)") {
                    $Dns = (T 'ms.fmt' ([math]::Round([double]$Matches[1], 1)))
                }
                elseif ($Line -match "api_req_avg_ms\s*\(.*avg\s*=\s*([\d.]+)\)") {
                    $Api = (T 'ms.fmt' ([math]::Round([double]$Matches[1], 1)))
                }
                elseif ($Line -match "fw_avg_ms\s*\(.*avg\s*=\s*([\d.]+)\)") {
                    $Fw = (T 'ms.fmt' ([math]::Round([double]$Matches[1], 1)))
                }
                elseif ($Line -match "Loss rate:\s*(.+)") {
                    $Loss = $Matches[1].Trim()
                }
            }
        }
        
        Write-Row (T 'stat.mtu') $Mtu "Green"
        Write-Row (T 'stat.speed') $Speed "Cyan"
        $LossColor = if ($Loss -match "^0") { "Green" } else { "Red" }
        Write-Row (T 'stat.loss') $Loss $LossColor
        Write-Row (T 'stat.dns') $Dns "Green"
        Write-Row (T 'stat.api') $Api "Green"
        Write-Row (T 'stat.fw') $Fw "Gray"
        Write-Rule
        Write-Item "R" (T 'stat.refresh') "Green"
        Write-Item "0" (T 'back') "Gray"
        Write-Rule
        
        if ((Read-Choice) -ne "r") { return }
    }
}

function Show-DiagnosticsSettings {
    while ($true) {
        Write-Screen (T 'diag.title') @((T 'diag.sub'))
        Write-Item "1" (T 'diag.i1') "White" (T 'diag.i1.d')
        Write-Item "2" (T 'diag.i2') "White" (T 'diag.i2.d')
        Write-Item "3" (T 'diag.i3') "Yellow" (T 'diag.i3.d')
        Write-Item "0" (T 'back') "Gray"
        Write-Rule
        
        switch (Read-Choice) {
            "1" { Show-PingSettings }
            "2" { Show-WarpStats }
            "3" { Start-Benchmark }
            "0" { return }
        }
    }
}

function Show-Settings {
    while ($true) {
        Write-Screen (T 'set.title') @((T 'set.sub'))
        Write-Item "1" (T 'set.i1') "White" (T 'set.i1.d')
        Write-Item "2" (T 'set.i2') "White" (T 'set.i2.d')
        Write-Item "3" (T 'set.i3') "White" (T 'set.i3.d')
        Write-Item "4" (T 'set.i4') "White" (T 'set.i4.d')
        Write-Item "0" (T 'back') "Gray"
        Write-Rule
        
        switch (Read-Choice) {
            "1" { Show-ConnectionSettings }
            "2" { Show-SplitTunnelSettings }
            "3" { Show-DiagnosticsSettings }
            "4" { Show-SystemSettings }
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
    $Label = T 'wait.winws'
    $Sw = [Diagnostics.Stopwatch]::StartNew()
    Show-Busy $Label 0 0
    $ArgsStr = Get-ZapretArgs $BatFile
    if ($null -ne $ArgsStr) {
        $Job = Start-Process -FilePath "$ZapretDir\bin\winws.exe" -ArgumentList $ArgsStr -WorkingDirectory "$ZapretDir\bin" -WindowStyle Hidden -PassThru
    } else {
        $Job = Start-Process -FilePath $BatFile -WorkingDirectory (Split-Path $BatFile) -WindowStyle Hidden -PassThru
    }
    Add-WinwsToJob $Job
    # started = the process exists and stays alive for at least a second
    $SeenAt = -1
    for ($Tick = 0; $Tick -lt 44; $Tick++) {
        if ($Tick % 2 -eq 0) {
            $Alive = [bool](Get-Process -Name "winws" -ErrorAction SilentlyContinue)
            if ($Alive -and $SeenAt -lt 0) { $SeenAt = $Tick }
            if (-not $Alive) { $SeenAt = -1 }
            if ($Alive -and ($Tick - $SeenAt) -ge 4) { break }
        }
        Show-Busy $Label $Tick $Sw.Elapsed.TotalSeconds
        Start-Sleep -Milliseconds 250
    }
    $Started = [bool](Get-Process -Name "winws" -ErrorAction SilentlyContinue)
    Complete-Busy $Label $Started $Sw.Elapsed.TotalSeconds
    if (-not $Started) { Write-Fail (T 'winws.fail') }
}

function Wait-WarpConnected ($Seconds = 30) {
    $Label = T 'wait.connect'
    $Sw = [Diagnostics.Stopwatch]::StartNew()
    for ($Tick = 0; $Tick -lt ($Seconds * 4); $Tick++) {
        if ($Tick % 4 -eq 0) {
            $WarpStatus = & $WarpCli --accept-tos status 2>&1 | Out-String
            if ($WarpStatus -and $WarpStatus.Contains("Connected") -and -not $WarpStatus.Contains("Connecting")) {
                Complete-Busy $Label $true $Sw.Elapsed.TotalSeconds
                return $true
            }
        }
        Show-Busy $Label $Tick $Sw.Elapsed.TotalSeconds
        Start-Sleep -Milliseconds 250
    }
    Complete-Busy $Label $false $Sw.Elapsed.TotalSeconds
    return $false
}

# The WARP service is briefly unavailable after many settings changes ("IPC responder dropped")
function Wait-WarpDaemon ($Seconds = 30) {
    $Label = T 'wait.daemon'
    $Sw = [Diagnostics.Stopwatch]::StartNew()
    for ($Tick = 0; $Tick -lt ($Seconds * 4); $Tick++) {
        if ($Tick % 4 -eq 0) {
            $St = & $WarpCli --accept-tos status 2>&1 | Out-String
            if ($St -and $St -notmatch "(?i)Unable to connect|IPC|channel closed|responder dropped|not running") {
                # nothing to wait for: do not leave a progress line behind
                if ($Tick -gt 0) { Complete-Busy $Label $true $Sw.Elapsed.TotalSeconds }
                return $true
            }
        }
        if ($Tick -gt 0) { Show-Busy $Label $Tick $Sw.Elapsed.TotalSeconds }
        Start-Sleep -Milliseconds 250
    }
    Complete-Busy $Label $false $Sw.Elapsed.TotalSeconds
    return $false
}

# Reconnect the tunnel: winws on -> reconnect -> winws off once connected (winws is only needed while WARP is connecting)
function Restart-WarpConnection {
    $Preset = $global:ActivePreset
    if ($Preset) { Start-Winws $Preset }
    [void](Wait-WarpDaemon 30)
    & $WarpCli --accept-tos disconnect 2>&1 | Out-Null
    Start-Sleep -Seconds 1
    & $WarpCli --accept-tos connect 2>&1 | Out-Null
    $Ok = Wait-WarpConnected 60
    if (-not $Ok) {
        Write-Step (T 'conn.retry')
        [void](Wait-WarpDaemon 30)
        & $WarpCli --accept-tos disconnect 2>&1 | Out-Null
        Start-Sleep -Seconds 2
        & $WarpCli --accept-tos connect 2>&1 | Out-Null
        $Ok = Wait-WarpConnected 45
    }
    if ($Preset) {
        if ($Ok) {
            try { Stop-Winws } catch {}
            $global:WinwsPendingStop = $false
        } else {
            Write-Fail (T 'conn.slow')
            $global:WinwsPendingStop = $true
        }
    }
    $global:CachedWarpStatus = $null
    if ($Ok) { Update-CachedExternalIp }
}

# Closes the Cloudflare WARP GUI (the installer and the client start it); the service and warp-cli stay untouched
function Stop-WarpGui {
    $ErrorActionPreference = "SilentlyContinue"
    try {
        Get-Process -Name "Cloudflare*", "warp-taskbar" -ErrorAction SilentlyContinue |
            Where-Object { $_.ProcessName -notmatch "^(cloudflared|warp-svc|warp-cli|warp-dex|warp-diag)$" } |
            Stop-Process -Force -ErrorAction SilentlyContinue
    } catch {}
}

function Remove-WarpGuiAutostart {
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
}

function Connect-WarpTunnel ($BatFile) {
    try { Stop-Service -Name "zapret" -Force -ErrorAction SilentlyContinue *> $null } catch {}
    try { Stop-Service -Name "goodbyedpi" -Force -ErrorAction SilentlyContinue *> $null } catch {}
    try { Stop-Winws } catch {}
    try { Stop-Process -Name "goodbyedpi" -Force -ErrorAction SilentlyContinue *> $null } catch {}

    if ($Config.DnsFix) {
        Write-Step (T 'conn.flushdns')
        ipconfig /flushdns | Out-Null
    }
    
    Start-Winws $BatFile
    
    if (-not (Test-Path $WarpCli)) {
        $WarpMsi = "$StorageDir\Cloudflare_WARP.msi"
        try {
            Start-DownloadWithProgress -Uri "https://downloads.cloudflareclient.com/v1/download/windows/ga" -OutFile $WarpMsi -Label (T 'conn.dl.warp')
            Set-ConsoleQuickEdit $false
            $Msi = Start-Process msiexec.exe -ArgumentList "/i `"$WarpMsi`" /qn /norestart ONBOARDING=false START_WPF_AS_USER=0" -PassThru -WindowStyle Hidden
            # the installer launches the WARP window: close it as soon as it appears, also right after the install ends
            $Label = T 'wait.install'
            $Sw = [Diagnostics.Stopwatch]::StartNew()
            $Tick = 0
            while (-not $Msi.HasExited -and $Sw.Elapsed.TotalMinutes -lt 5) {
                if ($Tick % 4 -eq 0) { Stop-WarpGui }
                Show-Busy $Label $Tick $Sw.Elapsed.TotalSeconds
                Start-Sleep -Milliseconds 250
                $Tick++
            }
            $InstallOk = $Msi.HasExited
            if (-not $InstallOk) { try { $Msi.Kill() } catch {} }
            for ($i = 0; $i -lt 12; $i++) {
                Stop-WarpGui
                Show-Busy $Label $Tick $Sw.Elapsed.TotalSeconds
                Start-Sleep -Milliseconds 250
                $Tick++
            }
            Complete-Busy $Label $InstallOk $Sw.Elapsed.TotalSeconds
            Remove-WarpGuiAutostart
            Remove-Item $WarpMsi -ErrorAction SilentlyContinue
            if (-not (Test-Path $WarpCli)) {
                Write-Host ""
                Write-Fail (T 'conn.warp.missing')
                Wait-Enter; Exit
            }
            Write-Ok (T 'conn.warp.installed')
            Start-Sleep -Seconds 2
        } catch {
            Write-Host ""
            Write-Fail (T 'conn.warp.failed')
            Wait-Enter; Exit
        }
    }
    
    Set-Service -Name "CloudflareWARP" -StartupType Manual -ErrorAction SilentlyContinue
    
    if (Test-Path $WarpCli) {
        & $WarpCli --accept-tos mode warp | Out-Null
    }
    
    Write-Step (T 'conn.restart.svc')
    Stop-Service -Name "CloudflareWARP" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
    Start-Service -Name "CloudflareWARP" -ErrorAction SilentlyContinue
    Stop-WarpGui
    
    # Wait for daemon to be ready (up to 8 seconds)
    Write-Step (T 'conn.wait.daemon')
    $DaemonReady = $false
    for ($i = 0; $i -lt 16; $i++) {
        $StatusCheck = & $WarpCli --accept-tos status 2>&1 | Out-String
        if ($StatusCheck -and $StatusCheck -notmatch "(?i)Unable to connect|not running") {
            $DaemonReady = $true
            break
        }
        Start-Sleep -Milliseconds 500
    }
    
    Write-Step (T 'conn.init')
    if (-not $DaemonReady) { Write-Fail (T 'conn.daemon.fail') }
    $RegCheck = & $WarpCli --accept-tos registration show 2>$null | Out-String
    if ($DaemonReady -and (-not $RegCheck -or $RegCheck -match "(?i)error|not registered|No registration")) {
        Write-Step (T 'conn.register')
        & $WarpCli --accept-tos registration new 2>$null | Out-Null
        if ($Config.WarpLicense) {
            Write-Step (T 'conn.license')
            Set-WarpLicense $Config.WarpLicense | Out-Null
        }
    }
    & $WarpCli --accept-tos connect | Out-Null
    
    $Connected = Wait-WarpConnected 30
    
    # winws is only needed to get WARP connected; if it is still connecting, the session loop stops winws later
    if ($Connected) {
        try { Stop-Winws } catch {}
        $global:WinwsPendingStop = $false
    } else {
        $global:WinwsPendingStop = $true
    }
    
    if ($Connected) { Update-CachedExternalIp }
    return $Connected
}

function Show-ActiveSessionMenu ($CurrentInput, $TimerVal) {
    [console]::CursorVisible = $false
    [console]::SetCursorPosition(0, 0)
    
    Write-Header
    
    $WarpState = (Get-CachedWarpStatus).Trim()
    
    if ($global:TunnelPaused) {
        Write-Row (T 'sess.status') (T 'st.paused') "Yellow" 31
    } else {
        switch ($WarpState) {
            "Connected"     { Write-Row (T 'sess.status') (T 'st.connected') "Green" 31 }
            "Connecting"    { Write-Row (T 'sess.status') (T 'st.connecting') "Yellow" 31 }
            "Disconnected"  { Write-Row (T 'sess.status') (T 'st.disconnected') "Red" 31 }
            "Disconnecting" { Write-Row (T 'sess.status') (T 'st.disconnecting') "Yellow" 31 }
            "Paused"        { Write-Row (T 'sess.status') (T 'st.paused') "Yellow" 31 }
            default         { Write-Row (T 'sess.status') $WarpState "Red" 31 }
        }
    }
    
    if ($global:TunnelPaused -or $WarpState -ne "Connected") {
        Write-Row (T 'sess.ip') "-" "Gray" 31
    } else {
        $DisplayIp = if ($global:CurrentExternalIp) { $global:CurrentExternalIp } else { T 'sess.ip.wait' }
        Write-Row (T 'sess.ip') $DisplayIp "Gray" 31
    }
    
    if (-not $global:TunnelPaused -and $global:PingResults -and $global:PingResults.Count -gt 0) {
        Write-Rule
        Write-Host (" " + (T 'sess.avail')) -NoNewline -ForegroundColor Cyan
        if ($Config.AutoPing -eq 2) {
            if ($TimerVal -eq "measuring") {
                Write-Host ((" (" + (T 'sess.measuring') + ")").PadRight(34)) -ForegroundColor Yellow
            } else {
                Write-Host ((" (" + (T 'sess.next' $TimerVal) + ")").PadRight(34)) -ForegroundColor Gray
            }
        } else {
            Write-Host ("".PadRight(34))
        }
        
        foreach ($Ping in $global:PingResults) {
            $DomName = $Ping.Domain
            if ($DomName.Length -gt 24) { $DomName = $DomName.Substring(0, 21) + "..." }
            Write-Host ("  " + $DomName.PadRight(24) + " : ") -NoNewline
            if ($Ping.Status -eq "OK") {
                Write-Host ((T 'ms.fmt' $Ping.Latency).PadRight(30)) -ForegroundColor Green
            } elseif ($Ping.Status -eq "Timeout") {
                Write-Host ((T 'sess.timeout').PadRight(30)) -ForegroundColor Red
            } else {
                Write-Host ((T 'sess.unreachable').PadRight(30)) -ForegroundColor Red
            }
        }
    } else {
        for ($i = 0; $i -lt 5; $i++) {
            Write-Host ("".PadRight(57))
        }
    }
    
    Write-Rule
    if ($global:TunnelPaused) {
        Write-Item "R" ((T 'sess.resume').PadRight(50)) "Green"
    } else {
        Write-Item "P" ((T 'sess.pause').PadRight(50)) "Yellow"
    }
    Write-Item "C" ((T 'sess.reconnect').PadRight(50)) "Cyan"
    Write-Item "I" ((T 'sess.changeip').PadRight(50)) "Cyan"
    Write-Item "M" ((T 'sess.profile').PadRight(50)) "White"
    Write-Item "S" ((T 'sess.settings').PadRight(50)) "Yellow"
    Write-Item "Q" ((T 'sess.quit').PadRight(50)) "Red"
    Write-Rule
    
    $PromptText = " " + (T 'prompt.cmd') + ": "
    Write-Host ($PromptText + $CurrentInput.PadRight(10)) -NoNewline
    [console]::SetCursorPosition($PromptText.Length + $CurrentInput.Length, [console]::CursorTop)
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
            if ($global:WinwsPendingStop -and (Get-CachedWarpStatus).Trim() -eq "Connected") {
                try { Stop-Winws } catch {}
                $global:WinwsPendingStop = $false
            }
            if ($Config.AutoPing -eq 2 -and -not $global:TunnelPaused) {
                $TimeRemainingRef.Value--
                if ($TimeRemainingRef.Value -le 0) {
                    Show-ActiveSessionMenu $InputStr "measuring"
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
                        Show-ActiveSessionMenu $InputStr "measuring"
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
            Write-Fail (T 'conn.noresp')
            Wait-Enter; return $false
        }
        
        if ($Config.PendingRuRouting) {
            Write-Host ""
            Write-Step (T 'wiz.route.applying')
            Apply-RuBypassTemplate
            $Applied = Get-SplitTunnelEntries
            if (@($Applied.Hosts).Count + @($Applied.Ips).Count -gt 0) {
                $Config.PendingRuRouting = $false
                Save-Config
            }
        }
        
        if ($Config.AutoPing -ne 0) {
            Write-Step (T 'sess.measuring.wait')
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
                    Write-Step (T 'sess.measuring.wait')
                    Measure-Latency
                }
                $TimeRemaining = $Config.PingInterval
                Clear-Host
                Show-ActiveSessionMenu "" $TimeRemaining
            }
            elseif ($CleanInput -eq 'q') {
                Write-Host ("`n " + (T 'sess.quit.ask') + " [" + (T 'yn') + "]") -ForegroundColor Yellow
                $Confirm = [console]::ReadKey($true).KeyChar.ToString().ToLower()
                if ($Confirm -match "[yд]") {
                    return $true
                }
                Clear-Host
                Show-ActiveSessionMenu "" $TimeRemaining
            }
            elseif ($CleanInput -eq 'p' -and -not $global:TunnelPaused) {
                Write-Host ("`n -> " + (T 'sess.pausing')) -ForegroundColor Yellow
                & $WarpCli --accept-tos disconnect | Out-Null
                $global:TunnelPaused = $true
                Clear-Host
                Show-ActiveSessionMenu "" $TimeRemaining
            }
            elseif ($CleanInput -eq 'r' -and $global:TunnelPaused) {
                Write-Host ("`n -> " + (T 'sess.resuming')) -ForegroundColor Yellow
                $Res = Connect-WarpTunnel $BatFile
                if ($Res) {
                    $global:TunnelPaused = $false
                    if ($Config.AutoPing -ne 0) {
                        Write-Step (T 'sess.measuring.wait')
                        Measure-Latency
                    }
                } else {
                    Write-Fail (T 'sess.resume.fail')
                    Start-Sleep -Seconds 2
                }
                $TimeRemaining = $Config.PingInterval
                Clear-Host
                Show-ActiveSessionMenu "" $TimeRemaining
            }
            elseif ($CleanInput -eq 'c') {
                Write-Host ("`n -> " + (T 'sess.reconnecting')) -ForegroundColor Yellow
                & $WarpCli --accept-tos disconnect | Out-Null
                $Res = Connect-WarpTunnel $BatFile
                if ($Res) {
                    $global:TunnelPaused = $false
                    if ($Config.AutoPing -ne 0) {
                        Write-Step (T 'sess.measuring.wait')
                        Measure-Latency
                    }
                } else {
                    Write-Fail (T 'sess.reconnect.fail')
                    Start-Sleep -Seconds 2
                }
                $TimeRemaining = $Config.PingInterval
                Clear-Host
                Show-ActiveSessionMenu "" $TimeRemaining
            }
            elseif ($CleanInput -eq 'i') {
                Write-Host ("`n " + (T 'ip.ask') + " [" + (T 'yn') + "]") -ForegroundColor Yellow
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
                    Write-Step (T 'ip.step.reset')
                    & $WarpCli --accept-tos disconnect | Out-Null
                    & $WarpCli --accept-tos registration delete 2>$null | Out-Null
                    Write-Note (T 'ip.step.new') "Gray"
                    $Res = Connect-WarpTunnel $BatFile
                    if ($Res) {
                        $global:TunnelPaused = $false
                        if ($RestoreSplit) {
                            Write-Step (T 'ip.step.route')
                            Apply-RuBypassTemplate
                        }
                        Write-Step (T 'ip.step.detect')
                        Wait-ExternalIp 20
                        if ($Config.AutoPing -ne 0) {
                            Write-Step (T 'sess.measuring.wait')
                            Measure-Latency
                        }
                        $NewIp = $global:CurrentExternalIp
                        $Was = if ($OldIp) { $OldIp } else { T 'ip.unknown.old' }
                        if (-not $global:IpOk) {
                            Write-Fail (T 'ip.detect.fail')
                        } elseif ($OldIp -and (($OldIp -split " ")[0] -eq ($NewIp -split " ")[0])) {
                            Write-Note (T 'ip.same' $NewIp) "Yellow"
                        } else {
                            Write-Ok (T 'ip.changed' $Was $NewIp)
                        }
                    } else {
                        Write-Fail (T 'ip.reconnect.fail')
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
        Write-Host ("`n " + (T 'sess.quit.ask') + " [" + (T 'yn') + "]") -ForegroundColor Yellow
        $Confirm = [console]::ReadKey($true).KeyChar.ToString().ToLower()
        if ($Confirm -match "[yд]") {
            return $true
        }
    }
    finally {
        Write-Host ("`n -> " + (T 'sess.closing')) -ForegroundColor Yellow
        try { Stop-Winws } catch {}
        try {
            if (Test-Path $WarpCli) {
                & $WarpCli --accept-tos disconnect *> $null
            }
        } catch {}
        $global:ActivePreset = $null
        $global:WinwsPendingStop = $false
        if ($Watchdog) { Stop-Process -Id $Watchdog.Id -Force -ErrorAction SilentlyContinue }
        Write-Ok (T 'sess.closed')
        Start-Sleep -Seconds 1
    }
}



# Main loop

Clear-Host
Write-Header

$ZapretChecked = $false
if ($FirstRun) {
    Start-SetupWizard
    if (-not (Test-Path $ZapretDir)) {
        $IsOnline = $true
        Check-Updates
        $ZapretChecked = $true
    }
}

if ($Config.AutoUpdate) {
    Check-AppUpdate
    if (-not $ZapretChecked) { Check-Updates }
}

if ($Config.AutoPreset -and $Config.LastPreset -and (Test-Path $Config.LastPreset)) {
    $WaitSecs = $Config.AutoPresetTimeout
    if ($WaitSecs -gt 0) {
        $Interrupted = $false
        $BatName = [IO.Path]::GetFileNameWithoutExtension($Config.LastPreset)
        Write-Host ""
        Write-Step (T 'auto.starting' $BatName $WaitSecs) "Cyan"
        Write-Note (T 'auto.cancel') "Yellow"
        
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
    $ZapretDirFullName = if (Test-Path $ZapretDir) { (Get-Item $ZapretDir).FullName } else { "" }
    $BatFiles = if ($ZapretDirFullName) { @(Get-ChildItem -Path $ZapretDirFullName -Filter "*.bat" | Where-Object { $_.Name -notmatch "(?i)^service(_install|_remove)?\.bat$" }) } else { @() }
    
    Clear-Host
    Write-Header
    Write-Center ("WarpBypass v" + $AppVersion + "  |  by BUSH") "DarkCyan"
    Write-Center (T 'main.title')
    Write-Host (" " + (T 'main.sub')) -ForegroundColor Gray
    Write-Rule
    
    if ($BatFiles.Count -gt 0) {
        for ($i = 0; $i -lt $BatFiles.Count; $i++) {
            $Name = $BatFiles[$i].BaseName
            $Color = "Gray"
            $Tag = ""
            if ($Name -like "*alt12*") { $Color = "Green"; $Tag = "  <- " + (T 'recommended') }
            if ($Config.LastPreset -and $Config.LastPreset -eq $BatFiles[$i].FullName) { $Color = "Cyan"; $Tag = "  <- " + (T 'main.last') }
            Write-Item ([string]($i + 1)) ($Name + $Tag) $Color
        }
    } else {
        Write-Fail (T 'main.noprofiles')
    }
    Write-Rule
    Write-Item "S" (T 'main.settings') "Yellow"
    Write-Item "Q" (T 'main.quit') "Gray"
    Write-Rule
    
    $Cmd = (Read-Host (" " + (T 'prompt.cmd'))).Trim()
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

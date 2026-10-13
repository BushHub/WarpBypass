# WarpBypass

**Русский** | [English](README.en.md)

<img src=".github/assets/banner.png" alt="WarpBypass Banner" width="100%">
<p align="center">
  <a href="https://github.com/BushHub/WarpBypass/releases/latest"><img src="https://img.shields.io/github/v/release/BushHub/WarpBypass?style=for-the-badge&logo=github&color=blue" alt="Latest Release"></a>
  <a href="https://github.com/BushHub/WarpBypass/releases"><img src="https://img.shields.io/github/downloads/BushHub/WarpBypass/total?style=for-the-badge&logo=github&color=brightgreen" alt="Total Downloads"></a>
  <a href="https://github.com/BushHub/WarpBypass/stargazers"><img src="https://img.shields.io/github/stars/BushHub/WarpBypass?style=for-the-badge&logo=github&color=yellow" alt="Stars"></a>
  <a href="https://github.com/BushHub/WarpBypass/issues"><img src="https://img.shields.io/github/issues/BushHub/WarpBypass?style=for-the-badge&logo=github&color=orange" alt="Issues"></a>
  <a href="https://github.com/BushHub/WarpBypass/blob/main/LICENSE"><img src="https://img.shields.io/github/license/BushHub/WarpBypass?style=for-the-badge&color=blueviolet" alt="License"></a>
  <img src="https://img.shields.io/badge/OS-Windows%2010%20%7C%2011-0078D6?style=for-the-badge&logo=windows" alt="Windows Support">
  <a href="https://github.com/BushHub"><img src="https://img.shields.io/badge/Author-BUSH-9c27b0?style=for-the-badge&logo=github" alt="Author BUSH"></a>
  <a href="https://t.me/bushsquad"><img src="https://img.shields.io/badge/Telegram-2CA5E0?style=for-the-badge&logo=telegram&logoColor=white" alt="Telegram Community"></a>
  <a href="https://discord.gg/ebush"><img src="https://img.shields.io/badge/Discord-5865F2?style=for-the-badge&logo=discord&logoColor=white" alt="Discord Server"></a>
</p>

**WarpBypass** — один файл для Windows, который автоматически настраивает и запускает Cloudflare WARP вместе с маскировкой сетевых пакетов (Zapret). Вы выбираете профиль и нажимаете Enter — программа сама загрузит компоненты, подключит туннель и покажет состояние соединения.

Подходит тем, кому нужна стабильная работа Discord (голосовые каналы и трансляции), видеохостингов, игровых сервисов и других платформ, а российские сайты при этом должны открываться напрямую.

---

## Как это работает

1. **Zapret (`winws`)** маскирует пакеты, чтобы провайдер не мешал установить соединение с Cloudflare WARP.
2. **Cloudflare WARP** поднимает туннель. Как только он подключён, Zapret автоматически останавливается: для работы туннеля он не нужен.
3. **«Россия напрямую»** (по желанию) направляет российские домены и IP-адреса мимо WARP: банки, Госуслуги и другие сервисы работают как обычно.

---

## Возможности

**Подключение**
- Полная автоматизация: программа сама загружает Zapret, устанавливает Cloudflare WARP (если его нет), регистрирует клиент и подключает туннель.
- Мастер первого запуска: достаточно нажимать Enter, по умолчанию выбираются рекомендуемые значения.
- Автозапуск последнего профиля (по умолчанию без задержки), пауза и возобновление, переподключение одной клавишей.
- Смена IP-адреса (`I`): перерегистрация клиента WARP с показом старого и нового адреса.
- Поддержка WARP+: лицензионный ключ применяется при каждой регистрации, а в строке IP-адреса видно, действует ли он (`[WARP+]`).

**Обход блокировок**
- Подбор профиля: программа по очереди проверяет профили Zapret (TLS-соединение с YouTube и Discord) и предлагает лучший для вашего провайдера.
- Zapret работает только пока подключается WARP и всегда завершается вместе с программой, даже если окно закрыто крестиком.

**Маршрутизация «Россия напрямую»**
- Правила хранятся в репозитории и кэшируются локально, список можно обновить в один клик.
- Параллельное применение (до 30 вызовов `warp-cli`), повторные попытки при сбоях службы, пропуск записей, уже покрытых масками вроде `*.ru`.
- Просмотр действующих правил и полное отключение одним пунктом.

**Диагностика**
- Проверка доступности популярных сервисов на экране подключения (однократно, регулярно или выключена), список узлов редактируется.
- Статистика WARP: MTU, скорость, потери пакетов, задержки.
- Индикаторы выполнения для долгих операций: загрузка, установка WARP, ожидание службы.

**Интерфейс и безопасность**
- Два языка интерфейса, русский и английский: выбор в мастере и в «Настройки → Система», по умолчанию язык Windows.
- Скачанное обновление проверяется перед установкой (версия и контрольная сумма SHA256).
- Режим выделения мышью в консоли отключён, чтобы случайный клик не останавливал программу.
- Полное удаление с возможностью заодно удалить клиент Cloudflare WARP.

---

## Быстрый старт

1. [Скачайте актуальный `WarpBypass.bat`](https://github.com/BushHub/WarpBypass/releases/latest/download/WarpBypass.bat) и запустите его.
2. Windows может показать предупреждение «Не удаётся проверить издателя»: файл не имеет цифровой подписи. Подтвердите запуск, затем запрос UAC (права администратора нужны для служб, драйвера и сетевых настроек).
3. Пройдите мастер первого запуска: язык, автообновление, «Россия напрямую», профиль. Если просто нажимать Enter, будут выбраны рекомендуемые значения (профиль `general (ALT12)`).
4. Программа загрузит компоненты, установит WARP, подключится и откроет экран сеанса.
5. Чтобы закончить работу и вернуть сеть в исходное состояние, нажмите `Q`.

### Управление

| Клавиша | Экран сеанса |
|---|---|
| `P` / `R` | Приостановить / продолжить работу туннеля |
| `C` | Переподключить туннель |
| `I` | Сменить IP-адрес |
| `M` | Сменить профиль обхода |
| `S` | Настройки |
| `Q` | Отключить туннель и выйти |
| `Enter` | Обновить IP-адрес и проверку доступности |

В главном меню введите номер профиля, `S` открывает настройки, `Q` закрывает программу.

---

## Настройки (клавиша `S`)

| Раздел | Что внутри |
|---|---|
| **Подключение** | Автозапуск последнего профиля, задержка автозапуска (0 сек по умолчанию), сброс кэша DNS перед подключением |
| **Маршрутизация** | «Россия напрямую»: включить, обновить список, показать правила, выключить |
| **Диагностика** | Проверка доступности (режим, интервал, список узлов), статистика WARP, подбор профиля |
| **Система** | Язык интерфейса, ключ WARP+, автообновление, сброс настроек, удаление программы |

---

## Что меняется в системе

- Файлы программы лежат в `%LOCALAPPDATA%\WarpBypass` (настройки, Zapret, списки правил). «Настройки → Система → Удалить» убирает их.
- Если Cloudflare WARP не установлен, программа загрузит его с сайта Cloudflare и установит.
- Zapret загружается из репозитория [Flowseal/zapret-discord-youtube](https://github.com/Flowseal/zapret-discord-youtube); драйвер WinDivert используется только на время работы `winws`.
- Службе `CloudflareWARP` выставляется ручной запуск, а автозапуск окна клиента WARP отключается: туннелем управляет WarpBypass.
- При полном удалении можно заодно удалить клиент WARP (по умолчанию да) или оставить его, вернув его настройки.

---

## Частые вопросы

**Windows пишет «Не удаётся проверить издателя».** Это стандартное предупреждение для любого неподписанного файла из интернета. Исходный код открыт, обновления проверяются по контрольной сумме. После первого запуска программа снимает с себя метку «из сети», и предупреждение больше не появляется.

**Профиль не работает у моего провайдера.** Откройте «Настройки → Диагностика → Подбор профиля»: программа проверит все профили и предложит лучший. Также попробуйте включить сброс кэша DNS в «Настройки → Подключение».

**Как проверить, что ключ WARP+ действует?** После подключения в строке «Внешний IP-адрес» должна быть пометка `[WARP+]`. Ключи из публичных источников часто уже исчерпали лимит устройств, тогда останется `[WARP]`.

**Почему после применения правил подключение занимает до минуты?** Служба WARP перезагружает больше тысячи правил маршрутизации. Это ожидаемо, на экране виден индикатор.

**Антивирус блокирует загрузку или запуск.** Zapret использует драйвер WinDivert, который некоторые антивирусы считают подозрительным. Добавьте папку `%LOCALAPPDATA%\WarpBypass` в исключения.

**Как обновиться?** Программа сама предложит обновление при запуске. Вручную: скачайте [последний релиз](https://github.com/BushHub/WarpBypass/releases/latest) и замените файл.

Не нашли ответ? Создайте [issue](https://github.com/BushHub/WarpBypass/issues/new/choose) или спросите в [Telegram](https://t.me/bushsquad) / [Discord](https://discord.gg/ebush).

---

## Требования

Windows 10 или 11, права администратора, подключение к интернету. Встроенного Windows PowerShell 5.1 достаточно, ничего дополнительно ставить не нужно.

## Технологии

* **[zapret](https://github.com/Flowseal/zapret-discord-youtube):** низкоуровневая маскировка структуры сетевых пакетов.
* **Cloudflare WARP (`warp-cli`):** официальный консольный клиент для организации туннеля.

---

## ⭐ Поддержка проекта

Если проект оказался полезен, поставьте **Star** репозиторию (кнопка в правом верхнем углу страницы).

<a href="https://www.star-history.com/?repos=bushhub%2Fwarpbypass&type=timeline&legend=bottom-right">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/chart?repos=bushhub/warpbypass&type=timeline&theme=dark&legend=top-left&sealed_token=yJpg5sLTQYSk-R0CxMm2hrXxTDW8fxCc_YJ2wROW4Boz_EJWtGd1Im7JJaUDu2WqZgK0e-w4HxL0PEhR-sOn_tQ82ZF31XcrmMxrg6O5t7fN5_YaSwLy8SmLcUJWUSbHbD02U0IaWBTtTSp8YFZagbX4xEWke5-9tykkZ_Z27XyX2bUyE8yUK4Gihc5v" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/chart?repos=bushhub/warpbypass&type=timeline&legend=top-left&sealed_token=yJpg5sLTQYSk-R0CxMm2hrXxTDW8fxCc_YJ2wROW4Boz_EJWtGd1Im7JJaUDu2WqZgK0e-w4HxL0PEhR-sOn_tQ82ZF31XcrmMxrg6O5t7fN5_YaSwLy8SmLcUJWUSbHbD02U0IaWBTtTSp8YFZagbX4xEWke5-9tykkZ_Z27XyX2bUyE8yUK4Gihc5v" />
   <img alt="Star History Chart" src="https://api.star-history.com/chart?repos=bushhub/warpbypass&type=timeline&legend=top-left&sealed_token=yJpg5sLTQYSk-R0CxMm2hrXxTDW8fxCc_YJ2wROW4Boz_EJWtGd1Im7JJaUDu2WqZgK0e-w4HxL0PEhR-sOn_tQ82ZF31XcrmMxrg6O5t7fN5_YaSwLy8SmLcUJWUSbHbD02U0IaWBTtTSp8YFZagbX4xEWke5-9tykkZ_Z27XyX2bUyE8yUK4Gihc5v" />
 </picture>
</a>

---
*Created by BUSH*

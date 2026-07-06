# WarpBypass

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

**WarpBypass** — это удобный инструмент для автоматизации сетевых подключений и оптимизации маршрутизации трафика. Утилита обеспечивает стабильный, быстрый и бесперебойный доступ к глобальным ресурсам через протокол Cloudflare WARP, используя продвинутые методы маскировки сетевых пакетов для предотвращения разрывов соединения.

Разработано для пользователей, которым важна непрерывная работа Discord (голосовые каналы и трансляции), видеохостингов, игровых сервисов и профессиональных платформ.

---

## 🚀 Основные возможности

- **Всё в одном (Автоматизация):** Скрипт самостоятельно выполняет аудит системы, загружает недостающие компоненты, настраивает маршруты и инициализирует службы. Вам не нужно ничего настраивать вручную.
- **Интегрированный Split Tunneling (RU-direct):** 
  Позволяет пускать российские домены и IP-диапазоны напрямую (в обход защищенного соединения).
  - База правил загружается с репозитория и кэшируется локально.
  - Поддержка проверки актуальности версий и быстрого обновления списков.
  - Сверхбыстрое применение маршрутов (до 30 параллельных потоков `warp-cli`).
- **Авто-подбор стратегий маскировки (DPI Benchmark):**
  Встроенный инструмент для последовательного тестирования пресетов Zapret на отзывчивость к популярным серверам. Утилита сама найдет и предложит сохранить наиболее эффективный профиль для вашего провайдера.
- **Динамический индикатор загрузки:** 
  При скачивании крупных системных зависимостей (Cloudflare WARP, модули Zapret) в консоли отображается детальная шкала прогресса выполнения.
- **Локализованные статусы сети:** 
  Все состояния подключения WARP отображаются на русском языке в чистом текстовом представлении (например, `ПОДКЛЮЧЕН`, `ОТКЛЮЧЕН`, `ПАУЗА`).
- **Скрытие фоновых служб:** 
  Модуль маскировки и клиент WARP работают незаметно на уровне системы. Управление идет через лаунчер, окно которого можно свернуть.
- **Улучшенный UX консоли:**
  - Окно консоли избавлено от навязчивого заголовка «Администратор: » и Quick-Edit блокировок (случайные клики по терминалу больше не останавливают работу скрипта).
  - Отсутствие эффекта мерцания экрана благодаря посимвольной перерисовке интерфейса.

---

## ⚙️ Инструкция по запуску

1. **Запуск:** [Скачайте актуальную версию WarpBypass.bat](https://github.com/BushHub/WarpBypass/releases/latest/download/WarpBypass.bat) и запустите файл.
2. **Права администратора:** Подтвердите запрос UAC. Права необходимы утилите для конфигурирования сетевых интерфейсов, реестра и системных служб.
3. **Первичный запуск:** Мастер первого запуска поможет настроить автообновления и применить рекомендуемую стратегию.
4. **Выбор профиля:** В главном меню укажите номер желаемого профиля (рекомендуемый универсальный вариант — `general (ALT12)`).
5. **Управление сессией:** На экране активного подключения вы можете:
   - Поставить соединение на паузу (`P`)
   - Переподключить туннель (`C`)
   - Вернуться в меню настроек (`S`)
6. **Отключение:** Чтобы вернуть сеть в исходное состояние и закрыть программу, нажмите `Q` (Отключить туннель и выйти) на экране активной сессии.
---

## 🛠 Настройки (Клавиша 'S' в главном меню)

* **Статистика и метрики WARP:** Просмотр низкоуровневых параметров соединения (MTU, задержка DoH, потери пакетов).
* **Настройки диагностики и пинга:** Конфигурация пингера на экране активной сессии (выбор хостов, переключение режимов: статический, динамический или выключен).
* **Управление Split Tunneling (Маршрутизация):** Применение шаблона сайтов РФ напрямую, проверка обновлений базы адресов, просмотр и сброс активных исключений.
* **Общие настройки:** 
  * Настройка автозапуска последнего успешного профиля.
  * Управление задержкой автоматического старта (от 0 сек для мгновенного запуска).
  * Включение/выключение автообновления утилиты.
  * Принудительный сброс кэша DNS перед стартом.
* **Авто-подбор стратегии маскировки (Бенчмарк):** Автоматический подбор лучшего профиля под вашего провайдера.

---

## 🛠 Технологический стек

* **zapret:** Низкоуровневое решение для маскировки структуры сетевых пакетов.
* **Cloudflare WARP (CLI):** Официальный консольный клиент для организации сетевого взаимодействия.

---

## ⭐ Поддержка проекта

Вы можете поддержать проект, поставив **Star** этому репозиторию (кнопка сверху справа на этой странице).

<a href="https://www.star-history.com/?repos=bushhub%2Fwarpbypass&type=timeline&legend=bottom-right">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/chart?repos=bushhub/warpbypass&type=timeline&theme=dark&legend=top-left&sealed_token=yJpg5sLTQYSk-R0CxMm2hrXxTDW8fxCc_YJ2wROW4Boz_EJWtGd1Im7JJaUDu2WqZgK0e-w4HxL0PEhR-sOn_tQ82ZF31XcrmMxrg6O5t7fN5_YaSwLy8SmLcUJWUSbHbD02U0IaWBTtTSp8YFZagbX4xEWke5-9tykkZ_Z27XyX2bUyE8yUK4Gihc5v" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/chart?repos=bushhub/warpbypass&type=timeline&legend=top-left&sealed_token=yJpg5sLTQYSk-R0CxMm2hrXxTDW8fxCc_YJ2wROW4Boz_EJWtGd1Im7JJaUDu2WqZgK0e-w4HxL0PEhR-sOn_tQ82ZF31XcrmMxrg6O5t7fN5_YaSwLy8SmLcUJWUSbHbD02U0IaWBTtTSp8YFZagbX4xEWke5-9tykkZ_Z27XyX2bUyE8yUK4Gihc5v" />
   <img alt="Star History Chart" src="https://api.star-history.com/chart?repos=bushhub/warpbypass&type=timeline&legend=top-left&sealed_token=yJpg5sLTQYSk-R0CxMm2hrXxTDW8fxCc_YJ2wROW4Boz_EJWtGd1Im7JJaUDu2WqZgK0e-w4HxL0PEhR-sOn_tQ82ZF31XcrmMxrg6O5t7fN5_YaSwLy8SmLcUJWUSbHbD02U0IaWBTtTSp8YFZagbX4xEWke5-9tykkZ_Z27XyX2bUyE8yUK4Gihc5v" />
 </picture>
</a>

---
*Created by BUSH*

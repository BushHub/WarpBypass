# WarpBypass

<img src=".github/assets/banner.png" alt="WarpBypass Banner" width="100%">
<p align="center">
  <a href="https://github.com/BushHub/WarpBypass/releases/latest"><img src="https://img.shields.io/github/v/release/BushHub/WarpBypass?style=for-the-badge&logo=github&color=blue" alt="Latest Release"></a>
  <a href="https://github.com/BushHub/WarpBypass/releases"><img src="https://img.shields.io/github/downloads/BushHub/WarpBypass/total?style=for-the-badge&logo=github&color=brightgreen" alt="Total Downloads"></a>
  <a href="https://github.com/BushHub/WarpBypass/stargazers"><img src="https://img.shields.io/github/stars/BushHub/WarpBypass?style=for-the-badge&logo=github&color=yellow" alt="Stars"></a>
  <a href="https://github.com/BushHub/WarpBypass/issues"><img src="https://img.shields.io/github/issues/BushHub/WarpBypass?style=for-the-badge&logo=github&color=orange" alt="Issues"></a>
  <a href="https://github.com/BushHub/WarpBypass/blob/main/LICENSE"><img src="https://img.shields.io/github/license/BushHub/WarpBypass?style=for-the-badge&color=blueviolet" alt="License"></a>
  <img src="https://img.shields.io/badge/OS-Windows%2010%20%7C%2011-0078D6?style=for-the-badge&logo=windows" alt="Windows Support">
  <a href="https://github.com/rydve"><img src="https://img.shields.io/badge/Author-rydve-9c27b0?style=for-the-badge&logo=github" alt="Author rydve"></a>
  <a href="https://t.me/bushsquad"><img src="https://img.shields.io/badge/Telegram-2CA5E0?style=for-the-badge&logo=telegram&logoColor=white" alt="Telegram Community"></a>
  <a href="https://discord.gg/ebush"><img src="https://img.shields.io/badge/Discord-5865F2?style=for-the-badge&logo=discord&logoColor=white" alt="Discord Server"></a>
</p>

**WarpBypass** — это удобный инструмент для автоматизации сетевых подключений и оптимизации маршрутизации трафика. Утилита обеспечивает стабильный, быстрый и бесперебойный доступ к глобальным ресурсам через протокол Cloudflare WARP, используя продвинутые методы маскировки сетевых пакетов для предотвращения разрывов соединения.

Разработано для пользователей, которым важна непрерывная работа Discord (голосовые каналы и трансляции), игровых сервисов и профессиональных платформ.

## 🚀 Основные возможности

- **Всё в одном (Автоматизация):** Скрипт самостоятельно выполняет аудит системы, загружает недостающие компоненты, настраивает маршруты и инициализирует службы. Вам не нужно ничего настраивать вручную.
- **Стабилизация соединения:** Интеллектуальная маскировка структуры трафика на лету. Это предотвращает искусственные просадки скорости и минимизирует потери пакетов на стороне провайдера.
- **Фоновые сетевые службы:** Модуль маскировки и клиент WARP работают незаметно на уровне системы. Они не создают кучу дополнительных графических окон и не присылают навязчивых уведомлений. Всё управление идет через одно окно лаунчера, которое можно просто свернуть на время работы или игры.
- **Умная конфигурация:**
    - **Автозапуск пресетов:** Запоминает последний успешный профиль и мгновенно поднимает соединение при следующем старте.
    - **TCP Диагностика (Ping):** Встроенный инструмент замера реального времени отклика до интересующих вас сайтов (включает время на установку защищенного TLS-соединения).
    - **Чистый выход:** При закрытии программы утилита автоматически останавливает туннелирование и возвращает все сетевые настройки операционной системы в исходное состояние.
- **Отказоустойчивость:** Защита от случайного запуска нескольких копий программы и встроенная зачистка конфликтующих фоновых процессов.

## ⚙️ Инструкция по запуску

1. **Запуск:** Скачайте и запустите файл `WarpBypass.bat`.
2. **Права администратора:** Подтвердите запрос UAC. Права необходимы утилите исключительно для управления сетевыми адаптерами и службами Windows.
3. **Выбор профиля:** В главном меню укажите номер желаемого профиля (рекомендуемый актуальный вариант — `alt12`). При первом запуске программа сама скачает всё необходимое.
4. **Готово:** Как только появится строка `Туннель WarpBypass успешно инициализирован`, сеть оптимизирована и готова к работе. Окно лаунчера можно свернуть.
5. **Отключение:** Чтобы вернуть сеть в обычный режим, просто введите команду `exit` в консоли или закройте окно лаунчера.

## 🛠 Настройки (Клавиша 'S' в главном меню)
Вы можете гибко адаптировать утилиту под себя:
- **Авто-запуск профиля:** Мгновенное подключение к сохраненному пресету без необходимости заходить в главное меню.
- **Диагностика задержки:** Автоматический пинг ваших любимых доменов сразу после установки соединения.
- **Принудительный сброс DNS:** Очистка системного кэша (DNS Flush) перед подключением для исправления ошибок недоступности сайтов.
- **Авто-обновление:** Утилита сама проверяет наличие свежих версий скрипта и сетевых компонентов в репозитории BushHub.

## 🛠 Технологический стек
- **zapret:** Низкоуровневое решение для маскировки структуры сетевых пакетов и повышения стабильности линка.
- **Cloudflare WARP (CLI):** Официальный консольный клиент для организации надежного и защищенного сетевого взаимодействия.


## ⭐ Поддержка проекта

Вы можете поддержать проект, поставив **Star** этому репозиторию (кнопка сверху справа на этой странице).

<a href="https://www.star-history.com/?repos=bushhub%2Fwarpbypass&type=date&legend=top-left">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/chart?repos=bushhub/warpbypass&type=date&theme=dark&legend=top-left&v=2" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/chart?repos=bushhub/warpbypass&type=date&legend=top-left&v=2" />
   <img alt="Star History Chart" src="https://api.star-history.com/chart?repos=bushhub/warpbypass&type=date&legend=top-left&v=2" />
 </picture>
</a>

---
*Created by BUSH*

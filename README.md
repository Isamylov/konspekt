# Konspekt

Konspekt записывает звонки в Яндекс Телемост и делает конспект встречи.

Во время звонка приложение записывает ваш микрофон и звук звонка, после окончания
расшифровывает запись через OpenAI-совместимый ASR-сервис и формирует краткое резюме.

## Требования

- macOS 14.2 или новее
- Command Line Tools (`xcode-select --install`), Xcode не нужен

## Установка

```bash
scripts/install.sh
```

Скрипт собирает `Konspekt.app`, копирует его в `~/Applications`, создает LaunchAgent
`ru.konspekt.agent` и запускает фоновый процесс.

Конфигурация копируется из `./.env` в `~/.config/konspekt/.env` (только если этого файла
еще нет, права `600`). Файл `./.env` должен существовать при первой установке.

### Из релиза

Скачайте `Konspekt.zip` из GitHub Releases, распакуйте и переместите `Konspekt.app`
в `~/Applications` или `/Applications`. Откройте приложение, заполните настройки
инференса, нажмите "Сохранить", затем "Запустить": приложение само создаст LaunchAgent.

## Разрешения

При первом запуске macOS попросит разрешения:

- Микрофон
- Запись системного звука (System Audio Recording)
- Доступ к папке Документы (для записи в `~/Documents/Konspekt`)

## Где лежат файлы

Каждый звонок сохраняется в `~/Documents/Konspekt/<date_time>/`, где `<date_time>` - дата и время
начала записи, например `2026-10-21_10-05-03`:

- `mic.caf` - запись микрофона
- `call.caf` - запись звука звонка
- `transcript.md` - расшифровка
- `summary.md` - резюме
- `status.json` - статус обработки

## Командная строка

```bash
~/Applications/Konspekt.app/Contents/MacOS/konspekt status
~/Applications/Konspekt.app/Contents/MacOS/konspekt retry
~/Applications/Konspekt.app/Contents/MacOS/konspekt process <dir>
```

- `status` - состояние записей и обработки
- `retry` - повторить обработку записей с ошибкой
- `process <dir>` - обработать конкретную папку записи

## Логи

```bash
tail -f ~/Library/Logs/konspekt.log
```

## Настройка

Файл `~/.config/konspekt/.env`:

- `OPENAI_BASE_URL` - адрес OpenAI-совместимого API
- `OPENAI_API_KEY` - ключ API
- `OPENAI_MODEL_NAME` - модель ASR (распознавание речи)
- `SUMMARY_MODEL_NAME` - модель для резюме (необязательно, по умолчанию `qwen-3.8-27b`)
- `KONSPEKT_DIR` - папка для записей (необязательно, по умолчанию `~/Documents/Konspekt`)

## Удаление

```bash
scripts/install.sh --uninstall
```

Скрипт останавливает агент, удаляет LaunchAgent и `~/Applications/Konspekt.app`.
Конфигурация `~/.config/konspekt` и записи в `~/Documents/Konspekt` сохраняются.

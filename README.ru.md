# Claude Code Extras

Небольшие дополнения для Claude Code. Каждое работает само по себе, так что бери только то, что нравится.

**[Скачай ClaudeCodeExtras-Setup.zip](https://github.com/oozzzyy/claude-code-extras/releases/latest/download/ClaudeCodeExtras-Setup.zip)**, распакуй и дважды нажми на `install.cmd`. Установщик спросит, какие дополнения нужны, и всё настроит.

[English version](README.md)

![Строка состояния с лимитами за 5 часов и за неделю](docs/statusline.svg)

| Дополнение | Что делает |
|---|---|
| [Строка лимитов](#строка-лимитов) | Лимиты за 5 часов и за неделю в виде тонких голубых полос, со временем сброса |
| [Лимиты над строкой ввода](#моды) | Те же лимиты над строкой ввода, через мод |
| [Показ режима при смене](#моды) | Прячет метку режима разрешений и показывает её на 4 секунды при смене |
| [Скилл Gemini](#скилл-gemini) | Передаёт объёмное чтение в Gemini CLI, чтобы экономить токены Claude |
| [Тема Claude Sky](#тема-claude-sky) | Тёмно-синий фон для твоих сообщений |
| [Звуки](#звуки) | Тихая монетка, когда ответ готов, и мягкий сигнал, когда Claude ждёт тебя |

## Установка

Установщик не заменит твою строку состояния или тему, не спросив, и не трогает остальные настройки. Исходный файл настроек один раз сохраняется как `settings.json.before-extras`.

После установки перезапусти открытые сессии Claude Code. Чтобы убрать дополнения, запусти `install.cmd -Uninstall`. Удалится только то, что добавил установщик, а строка состояния или тема, которые ты разрешил заменить, вернутся. Файлы звуков останутся.

Если хочешь настроить всё вручную, инструкции есть в разделах ниже.

## Строка лимитов

Скопируй `statusline/statusline.ps1` в удобное место и добавь в `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "powershell.exe -NoProfile -ExecutionPolicy Bypass -File \"C:\\path\\to\\statusline.ps1\""
  }
}
```

## Моды

Скопируй папку мода туда, где она сможет остаться, затем подключи и установи его:

```powershell
claude plugin marketplace add C:\path\to\mods\mode-on-change
claude plugin install mode-on-change@mode-on-change-local
```

Для лимитов над строкой ввода укажи так же `limits-band` и `limits-band-local`. Этот мод повторяет строку лимитов, поэтому достаточно одного из двух.

**Показ режима при смене** закрашивает текст Claude Code и опирается на английские формулировки подсказок, поэтому обновление может его сломать.

## Скилл Gemini

Установи [Gemini CLI](https://github.com/google-gemini/gemini-cli), войди в аккаунт и скопируй `skills/gemini` в `~/.claude/skills/gemini`. Названия моделей и лимиты в `SKILL.md` взяты из тестов и могли устареть.

Всё, что ты передаёшь в Gemini, уходит в Google, поэтому не отправляй туда личные данные.

## Тема Claude Sky

Скопируй `themes/claude-sky.json` в `~/.claude/themes/` и укажи `"theme": "custom:claude-sky"` в `~/.claude/settings.json`.

## Звуки

Скопируй два файла `.wav` из `sounds/` в `~/.claude/sounds` и добавь содержимое `sounds/hooks.example.json` в `~/.claude/settings.json`. Команды работают только в Windows.

## Лицензия

[MIT](LICENSE)

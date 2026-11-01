# Claude Code Extras

Small add-ons for Claude Code. Each one works on its own, so take only what you like.

**[Download ClaudeCodeExtras-Setup.zip](https://github.com/oozzzyy/claude-code-extras/releases/latest/download/ClaudeCodeExtras-Setup.zip)**, unpack it and double-click `install.cmd`. It asks which add-ons you want and sets them up.

[Русская версия](README.ru.md)

![Status line with 5-hour and weekly limits](docs/statusline.svg)

| Add-on | What it does |
|---|---|
| [Status line](#status-line) | 5-hour and weekly plan limits as thin blue bars, with reset times |
| [Limits band](#mods) | The same limits, drawn above the prompt by a mod |
| [Mode on change](#mods) | Hides the permission mode label and shows it for 4 seconds when the mode changes |
| [Gemini skill](#gemini-skill) | Hands bulky reading to the Gemini CLI to save Claude tokens |
| [Claude Sky theme](#claude-sky-theme) | Navy backgrounds for your messages |
| [Sounds](#sounds) | A quiet coin when a response finishes and a soft signal when Claude needs you |

## Install

Setup never replaces your status line or theme without asking, and it keeps your other settings. The original settings file is saved once as `settings.json.before-extras`.

Restart open Claude Code sessions afterwards. To remove the add-ons, run `install.cmd -Uninstall`. It only removes what setup added, and brings back a status line or theme you agreed to replace. The sound files stay.

Prefer to set things up by hand? Each section below explains how.

## Status line

Copy `statusline/statusline.ps1` somewhere and add this to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "powershell.exe -NoProfile -ExecutionPolicy Bypass -File \"C:\\path\\to\\statusline.ps1\""
  }
}
```

## Mods

Copy the mod's folder somewhere it can stay, then add and install it:

```powershell
claude plugin marketplace add C:\path\to\mods\mode-on-change
claude plugin install mode-on-change@mode-on-change-local
```

For the limits band, use `limits-band` and `limits-band-local` the same way. It repeats the status line, so you only need one of the two.

**Mode on change** paints over text drawn by Claude Code and relies on its English hint wording, so an update can break it.

## Gemini skill

Install the [Gemini CLI](https://github.com/google-gemini/gemini-cli), log in, and copy `skills/gemini` to `~/.claude/skills/gemini`. The model names and quotas in `SKILL.md` come from testing and may be out of date.

Whatever you delegate is sent to Google, so keep private data out of it.

## Claude Sky theme

Copy `themes/claude-sky.json` to `~/.claude/themes/` and set `"theme": "custom:claude-sky"` in `~/.claude/settings.json`.

## Sounds

Copy the two `.wav` files from `sounds/` to `~/.claude/sounds` and merge `sounds/hooks.example.json` into `~/.claude/settings.json`. The commands are Windows-only.

## License

[MIT](LICENSE)

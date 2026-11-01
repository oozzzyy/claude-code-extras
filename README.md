# Claude Code Extras

Small add-ons for Claude Code. Each one works on its own, so take only what you like.

![Status line with 5-hour and weekly limits](docs/statusline.svg)

| Add-on | What it does |
|---|---|
| [Status line](#status-line) | 5-hour and weekly plan limits as thin blue bars, with reset times |
| [Limits band](#mods) | The same limits, drawn above the prompt by a mod |
| [Mode on change](#mods) | Hides the permission mode label and shows it for 4 seconds when the mode changes |
| [Gemini skill](#gemini-skill) | Hands bulky reading to the Gemini CLI to save Claude tokens |
| [Claude Sky theme](#claude-sky-theme) | Navy backgrounds for your messages |
| [Sounds](#sounds) | A quiet coin when a response finishes and a soft signal when Claude needs you |

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

Register a mod's folder and enable it in `~/.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "mode-on-change-local": {
      "source": { "source": "directory", "path": "C:\\path\\to\\mods\\mode-on-change" }
    }
  },
  "enabledPlugins": { "mode-on-change@mode-on-change-local": true }
}
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

import type { Register } from 'claude-code'

const SHOW_MS = 4000
const OWN_REDRAW_MS = 300
const LABELS = "manual mode on|accept edits on|plan mode on|auto mode on|bypass permissions on|don't ask on"
// The hint lags the screen by one draw, so a label or an interrupt hint can arrive late.
const NOISE = new RegExp(
  `[^\\x20-\\x7e]*\\s*(?:${LABELS})|\\(?[a-z+-]*tab to cycle\\)?|\\(?esc to interrupt\\)?`,
  'gi',
)
// How far left the line starts, past the longest label the engine puts before it.
const REACH = 40
const GUTTER = 2
const SEPARATOR = 3
// A plain space leaves what is beneath it on screen; a no-break space replaces it.
const COVER = ' '

function cleaned(hint: string): string {
  return hint.replace(NOISE, '').replace(/^[\s·]+|[\s·]+$/g, '')
}

export const register: Register = (on) => {
  // The engine offers no mode value or event. It raises this hook when the draft or
  // working flag changes or when the mode changes, so a raise with both flags as
  // they were, and not asked for by this mod, is a mode change.
  let isDraft = false
  let isWorking = false
  // One invalidate can raise this hook more than once, so own redraws are told apart
  // by time: counting them would read an extra raise as a change and never stop.
  let ownRedrawUntil = 0
  let visibleUntil = 0

  on('session.start', async ($, e, next) => {
    const result = await next(e)
    // Without a first answer the engine keeps its own line, label included.
    await $.clock.after(500, async () => {
      ownRedrawUntil = (await $.clock.now()) + OWN_REDRAW_MS
      await $.ui.invalidate('ui.render')
    })
    return result
  })

  on('ui.render', { component: 'PromptHint', surface: 'terminal' }, async ($, e, next) => {
    const flagsSame = e.props.isDraft === isDraft && e.props.isWorking === isWorking
    isDraft = e.props.isDraft
    isWorking = e.props.isWorking

    const now = await $.clock.now()
    if (flagsSame && now >= ownRedrawUntil) {
      visibleUntil = now + SHOW_MS
      await $.clock.after(SHOW_MS, async () => {
        const later = await $.clock.now()
        if (later < visibleUntil) return
        ownRedrawUntil = later + OWN_REDRAW_MS
        await $.ui.invalidate('ui.render')
      })
    }

    const { Box, Text } = await $.ui.resolve(e)

    // The label stays; only the separator the engine puts after it is painted over.
    if (now < visibleUntil) {
      return h(
        Box,
        { position: 'absolute', left: -SEPARATOR, top: 0, width: SEPARATOR },
        h(Text, null, COVER.repeat(SEPARATOR)),
      )
    }

    // The engine keeps its mode label beside any line a hook draws and offers no
    // way to drop it, so this line is painted over it from the left.
    const text = e.props.isWorking ? '' : cleaned(e.props.hint)
    const line = COVER.repeat(REACH + GUTTER) + text.padEnd(REACH, COVER)
    return h(
      Box,
      { position: 'absolute', left: -REACH, top: 0, width: line.length },
      h(Text, { dimColor: true, wrap: 'truncate' }, line),
    )
  })
}

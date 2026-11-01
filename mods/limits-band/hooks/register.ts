import type { Register } from 'claude-code'

const BLUE = '#4FC3F7'
const DARK_BLUE = '#1F5F7A'
const BAR_WIDTH = 10

const WINDOWS = [
  { kind: 'five_hour', label: '5h', format: { hour: '2-digit', minute: '2-digit' } },
  { kind: 'seven_day', label: 'week', format: { weekday: 'short', hour: '2-digit', minute: '2-digit' } },
] as const

function resetText(resetsAt: string | undefined, format: Intl.DateTimeFormatOptions): string {
  if (resetsAt === undefined) return ''
  return ` until ${new Date(resetsAt).toLocaleString('en-US', format)}`
}

export const register: Register = (on) => {
  on('session.measure', async ($, e, next) => {
    if (e.changed.includes('rateLimits')) await $.ui.invalidate('ui.render')
    return next(e)
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    if (e.props.hasSurvey) return next(e)

    const usage = await $.session.usage()
    const shown = WINDOWS.flatMap((window) => {
      const limit = usage.rateLimits.find(({ kind }) => kind === window.kind)
      return limit === undefined ? [] : [{ ...window, limit }]
    })
    if (shown.length === 0) return next(e)

    const { Box, Text } = await $.ui.resolve(e)
    const children = shown.flatMap(({ label, format, limit }, index) => {
      const percent = Math.round(limit.percentUsed)
      const filled = Math.min(BAR_WIDTH, Math.floor(percent / 10))
      return [
        ...(index === 0 ? [] : ['   ']),
        `${label} `,
        '━'.repeat(filled),
        h(Text, { color: DARK_BLUE },'─'.repeat(BAR_WIDTH - filled)),
        ` ${percent}%${resetText(limit.resetsAt, format)}`,
      ]
    })

    return h(Box, null, h(Text, { key: 'limits', color: BLUE, wrap: 'truncate' }, ...children))
  })
}

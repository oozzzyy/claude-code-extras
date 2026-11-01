import { expect, test } from 'claude-code/testing'

const band = {
  plugin: 'limits-band',
  surface: 'terminal',
  component: 'AbovePrompt',
} as const

const usage = (rateLimits: unknown[]) => ({ startedAt: 0, context: {}, rateLimits })

test('draws both limits as thin lines', async ($, on) => {
  on('session.usage', () => ({
    value: usage([
      { kind: 'five_hour', percentUsed: 23.5 },
      { kind: 'seven_day', percentUsed: 7 },
    ]),
  }))
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)
    return h(Text, null, 'engine')
  })
  const ui = await $.ui.mount({ ...band, props: { hasSurvey: false, isWorking: false, rows: 20 } })
  const text = (await ui.find({ type: 'Text', text: /week/ }))?.text
  expect(text).toContain('5h ━━──────── 24%')
  expect(text).toContain('week ────────── 7%')
  expect(text).not.toContain('█')
  await ui.unmount()
})

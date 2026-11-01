import { expect, test } from 'claude-code/testing'

const hintProps = (hint: string, isWorking = false, isDraft = true) => ({
  plugin: 'mode-on-change',
  component: 'PromptHint',
  surface: 'terminal',
  props: { isDraft, isWorking, hint },
}) as const

test('the line keeps its other hints and loses the noise', async ($, on) => {
  on('clock.now', () => ({ value: 1000 }))
  const ui = await $.ui.mount(hintProps('(shift+tab to cycle) · esc to interrupt · ? for shortcuts'))
  const text = (await ui.find({ type: 'Text' }))?.text
  await ui.unmount()
  expect(text).toContain('? for shortcuts')
  expect(text).not.toContain('to cycle')
  expect(text).not.toContain('esc to interrupt')
})

test('nothing is written while working', async ($, on) => {
  on('clock.now', () => ({ value: 1000 }))
  const ui = await $.ui.mount(hintProps('esc to interrupt · ? for shortcuts', true, false))
  const text = (await ui.find({ type: 'Text' }))?.text
  await ui.unmount()
  expect(text).not.toContain('esc')
  expect(text).not.toContain('shortcuts')
})

test('a raise with the flags unchanged leaves the label uncovered', async ($, on) => {
  on('clock.now', () => ({ value: 1000 }))
  on('clock.after', () => ({ value: undefined }))
  const ui = await $.ui.mount(hintProps('? for shortcuts', false, false))
  const text = (await ui.find({ type: 'Text' }))?.text ?? ''
  await ui.unmount()
  expect(text).not.toContain('shortcuts')
  expect(text.length).toBe(3)
})

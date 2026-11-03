import { describe, it, expect } from 'vitest'
import { jsonToCollapsibleHtml } from '../composables/useJsonViewer'

describe('jsonToCollapsibleHtml', () => {
  it('renders null', () => {
    const html = jsonToCollapsibleHtml(null)
    expect(html).toContain('jv-null')
    expect(html).toContain('null')
  })

  it('renders undefined as null', () => {
    const html = jsonToCollapsibleHtml(undefined)
    expect(html).toContain('jv-null')
  })

  it('renders a number', () => {
    const html = jsonToCollapsibleHtml(42)
    expect(html).toContain('jv-number')
    expect(html).toContain('42')
  })

  it('renders a boolean', () => {
    const html = jsonToCollapsibleHtml(true)
    expect(html).toContain('jv-boolean')
    expect(html).toContain('true')
  })

  it('renders a plain string', () => {
    const html = jsonToCollapsibleHtml('hello')
    expect(html).toContain('jv-string')
    expect(html).toContain('hello')
  })

  it('renders a URL string as a link', () => {
    const html = jsonToCollapsibleHtml('https://example.com')
    expect(html).toContain('jv-link')
    expect(html).toContain('href="https://example.com"')
  })

  it('renders an empty object', () => {
    const html = jsonToCollapsibleHtml({})
    expect(html).toContain('{ }')
  })

  it('renders an empty array', () => {
    const html = jsonToCollapsibleHtml([])
    expect(html).toContain('[ ]')
  })

  it('renders an object with keys', () => {
    const html = jsonToCollapsibleHtml({ name: 'test', count: 5 })
    expect(html).toContain('jv-key')
    expect(html).toContain('name')
    expect(html).toContain('jv-number')
    expect(html).toContain('5')
    expect(html).toContain('jv-toggle')
  })

  it('renders an array with items', () => {
    const html = jsonToCollapsibleHtml([1, 2, 3])
    expect(html).toContain('jv-number')
    expect(html).toContain('1')
    expect(html).toContain('jv-children')
  })

  it('escapes HTML in string values', () => {
    const html = jsonToCollapsibleHtml('<script>alert("xss")</script>')
    expect(html).not.toContain('<script>')
    expect(html).toContain('&lt;script&gt;')
  })

  it('escapes HTML in object keys', () => {
    const html = jsonToCollapsibleHtml({ '<b>key</b>': 'val' })
    expect(html).not.toContain('<b>key</b>')
    expect(html).toContain('&lt;b&gt;key&lt;/b&gt;')
  })

  it('renders collapsed at deep levels', () => {
    const data = { a: { b: { c: 'deep' } } }
    const html = jsonToCollapsibleHtml(data, 1)
    expect(html).toContain('jv-collapsed')
  })

  it('renders expanded at shallow levels', () => {
    const data = { a: { b: 'shallow' } }
    const html = jsonToCollapsibleHtml(data, 3)
    expect(html).not.toContain('jv-collapsed')
  })

  it('renders ellipsis preview for collapsed objects', () => {
    const data = { a: { b: 'deep' } }
    const html = jsonToCollapsibleHtml(data, 0)
    expect(html).toContain('jv-ellipsis')
  })

  it('renders item count for collapsed arrays', () => {
    const data = { arr: [1, 2, 3] }
    const html = jsonToCollapsibleHtml(data, 0)
    expect(html).toContain('3 items')
  })

  it('handles nested objects and arrays', () => {
    const data = {
      users: [
        { name: 'Alice', age: 30 },
        { name: 'Bob', age: 25 },
      ],
    }
    const html = jsonToCollapsibleHtml(data, 2)
    expect(html).toContain('Alice')
    expect(html).toContain('Bob')
    expect(html).toContain('30')
    expect(html).toContain('25')
  })

  it('truncates large object preview to 5 keys', () => {
    const data = { obj: { a: 1, b: 2, c: 3, d: 4, e: 5, f: 6, g: 7 } }
    const html = jsonToCollapsibleHtml(data, 0)
    const match = html.match(/jv-ellipsis[^>]*>([^<]*)/)
    expect(match).toBeTruthy()
    const preview = match![1]
    expect(preview).toContain('a')
    expect(preview).toContain('+2')
  })

  it('shows all keys when object has ≤5 keys', () => {
    const data = { obj: { a: 1, b: 2, c: 3 } }
    const html = jsonToCollapsibleHtml(data, 0)
    const match = html.match(/jv-ellipsis[^>]*>([^<]*)/)
    expect(match).toBeTruthy()
    expect(match![1]).toContain('a, b, c')
  })

  it('includes commas between array items', () => {
    const html = jsonToCollapsibleHtml([1, 2, 3], 3)
    expect(html).toContain('jv-punct')
  })

  it('renders expand toggle button with aria-label', () => {
    const html = jsonToCollapsibleHtml({ a: 1 }, 0)
    expect(html).toContain('aria-label="expand"')
  })

  it('renders collapse toggle button for shallow depth', () => {
    const html = jsonToCollapsibleHtml({ a: 1 }, 3)
    expect(html).toContain('aria-label="collapse"')
  })
})

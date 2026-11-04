import { describe, it, expect } from 'vitest'
import { renderInlineMarkdown } from '../composables/useMarkdownLite'

describe('renderInlineMarkdown', () => {
  it('returns empty for empty string', () => {
    expect(renderInlineMarkdown('')).toBe('')
  })

  it('renders bold text', () => {
    expect(renderInlineMarkdown('**bold**')).toBe('<strong>bold</strong>')
  })

  it('renders italic text', () => {
    expect(renderInlineMarkdown('*italic*')).toBe('<em>italic</em>')
  })

  it('renders inline code', () => {
    expect(renderInlineMarkdown('`code`')).toBe('<code class="md-code">code</code>')
  })

  it('renders links', () => {
    const result = renderInlineMarkdown('[click](https://example.com)')
    expect(result).toContain('<a href="https://example.com"')
    expect(result).toContain('class="md-link"')
    expect(result).toContain('>click</a>')
  })

  it('escapes HTML', () => {
    expect(renderInlineMarkdown('<b>no</b>')).toBe('&lt;b&gt;no&lt;/b&gt;')
  })

  it('returns plain text unchanged', () => {
    expect(renderInlineMarkdown('hello world')).toBe('hello world')
  })

  it('handles mixed formatting', () => {
    const result = renderInlineMarkdown('Use `method` for **special** cases.')
    expect(result).toContain('<code class="md-code">method</code>')
    expect(result).toContain('<strong>special</strong>')
  })

  it('renders fenced code blocks', () => {
    const result = renderInlineMarkdown('```js\nconst x = 1\n```')
    expect(result).toContain('<pre class="md-pre">')
    expect(result).toContain('<code>const x = 1</code>')
  })

  it('renders bullet lists', () => {
    const result = renderInlineMarkdown('- item1\n- item2')
    expect(result).toContain('<ul class="md-list">')
    expect(result).toContain('<li>item1</li>')
    expect(result).toContain('<li>item2</li>')
    expect(result).toContain('</ul>')
  })

  it('renders numbered lists', () => {
    const result = renderInlineMarkdown('1. first\n2. second')
    expect(result).toContain('<ol class="md-list">')
    expect(result).toContain('<li>first</li>')
    expect(result).toContain('<li>second</li>')
    expect(result).toContain('</ol>')
  })

  it('renders headings', () => {
    const result = renderInlineMarkdown('### Title')
    expect(result).toContain('<h5 class="md-heading">Title</h5>')
  })

  it('converts line breaks to br', () => {
    const result = renderInlineMarkdown('line1\nline2')
    expect(result).toContain('line1<br>line2')
  })

  it('renders bold with __', () => {
    expect(renderInlineMarkdown('__bold__')).toBe('<strong>bold</strong>')
  })

  it('renders italic with _', () => {
    expect(renderInlineMarkdown('_italic_')).toBe('<em>italic</em>')
  })

  it('renders link target="_blank"', () => {
    const result = renderInlineMarkdown('[docs](https://example.com)')
    expect(result).toContain('target="_blank"')
    expect(result).toContain('rel="noopener"')
  })

  describe('GFM tables', () => {
    it('renders a header and body rows', () => {
      const result = renderInlineMarkdown(
        '| Name | Type |\n| --- | --- |\n| id | string |\n| age | integer |',
      )

      expect(result).toContain('<table class="md-table">')
      expect(result).toContain('<thead><tr><th>Name</th><th>Type</th></tr></thead>')
      expect(result).toContain('<tr><td>id</td><td>string</td></tr>')
      expect(result).toContain('<tr><td>age</td><td>integer</td></tr>')
    })

    it('applies alignment from the separator row', () => {
      const result = renderInlineMarkdown(
        '| a | b | c |\n| :--- | :---: | ---: |\n| 1 | 2 | 3 |',
      )

      expect(result).toContain('<th class="md-align-left">a</th>')
      expect(result).toContain('<th class="md-align-center">b</th>')
      expect(result).toContain('<th class="md-align-right">c</th>')
    })

    it('formats inline markdown inside cells', () => {
      const result = renderInlineMarkdown(
        '| Name |\n| --- |\n| **bold** |',
      )

      expect(result).toContain('<td><strong>bold</strong></td>')
    })

    it('leaves pipe text without a separator as plain text', () => {
      const result = renderInlineMarkdown('a | b without separator')

      expect(result).not.toContain('<table')
    })

    it('stops the table at the first non-row line', () => {
      const result = renderInlineMarkdown(
        '| a |\n| --- |\n| 1 |\nafter',
      )

      expect(result).toContain('</table>')
      expect(result).toContain('after')
      expect(result.indexOf('</table>')).toBeLessThan(result.indexOf('after'))
    })
  })
})

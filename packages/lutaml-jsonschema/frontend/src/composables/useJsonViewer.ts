/**
 * Generates collapsible HTML from a JSON value, similar to Redoc's jsonToHtml.
 * Supports configurable max expand level, clickable +/- toggles, and
 * expand/collapse all controls.
 */
const MAX_DEFAULT_EXPAND = 2

export function jsonToCollapsibleHtml(data: unknown, maxExpand: number = MAX_DEFAULT_EXPAND): string {
  let level = 0
  return renderValue(data, maxExpand, level + 1)
}

function escHtml(s: string): string {
  return s.replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
}

function punct(val: string): string {
  return `<span class="jv-punct">${val}</span>`
}

function token(val: string, cls: string): string {
  return `<span class="${cls}">${escHtml(val)}</span>`
}

function renderValue(value: unknown, maxExpand: number, level: number): string {
  if (value === null || value === undefined) {
    return token('null', 'jv-null')
  }
  if (Array.isArray(value)) {
    return renderArray(value, maxExpand, level + 1)
  }
  if (typeof value === 'object') {
    return renderObject(value as Record<string, unknown>, maxExpand, level + 1)
  }
  if (typeof value === 'number') return token(String(value), 'jv-number')
  if (typeof value === 'boolean') return token(String(value), 'jv-boolean')
  if (typeof value === 'string') {
    if (/^(https?):\/\/[^\s]+$/.test(value)) {
      return token('"', 'jv-string') + `<a href="${encodeURI(value)}" target="_blank" rel="noopener" class="jv-link">${escHtml(value)}</a>` + token('"', 'jv-string')
    }
    return token(JSON.stringify(value), 'jv-string')
  }
  return token(String(value), 'jv-string')
}

function renderArray(arr: unknown[], maxExpand: number, level: number): string {
  if (!arr.length) return punct('[ ]')
  const collapsed = level > maxExpand ? 'jv-collapsed' : ''
  let html = `<button class="jv-toggle" aria-label="${level > maxExpand ? 'expand' : 'collapse'}"></button>`
  html += punct('[')
  html += `<ul class="jv-children ${collapsed}">`
  arr.forEach((item, i) => {
    html += `<li><div class="jv-row ${collapsed}">`
    html += renderValue(item, maxExpand, level)
    if (i < arr.length - 1) html += punct(',')
    html += '</div></li>'
  })
  html += '</ul>'
  html += `<span class="jv-ellipsis">${arr.length} items</span>`
  html += punct(']')
  return html
}

function renderObject(obj: Record<string, unknown>, maxExpand: number, level: number): string {
  const keys = Object.keys(obj)
  if (!keys.length) return punct('{ }')
  const collapsed = level > maxExpand ? 'jv-collapsed' : ''
  let html = `<button class="jv-toggle" aria-label="${level > maxExpand ? 'expand' : 'collapse'}"></button>`
  html += punct('{')
  html += `<ul class="jv-children ${collapsed}">`
  keys.forEach((key, i) => {
    html += `<li><div class="jv-row ${collapsed}">`
    html += `<span class="jv-key">"${escHtml(key)}"</span>: `
    html += renderValue(obj[key], maxExpand, level)
    if (i < keys.length - 1) html += punct(',')
    html += '</div></li>'
  })
  html += '</ul>'
  const previewKeys = keys.length <= 5 ? keys : [...keys.slice(0, 5), `+${keys.length - 5}`]
  html += `<span class="jv-ellipsis">${previewKeys.map(k => escHtml(k)).join(', ')}</span>`
  html += punct('}')
  return html
}

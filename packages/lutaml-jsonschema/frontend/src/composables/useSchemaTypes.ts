import type { SpaProperty, SpaSchema, SpaDiffEntry } from '../types'
import { t } from '../i18n'

/**
 * Extract the primary JSON Schema type from a type string.
 * Handles union types like "string,integer" by returning the first component.
 * Composition types (anyOf/oneOf/not) are returned as-is.
 */
export function primaryType(type?: string): string {
  const t = (type || '').split(',')[0].trim()
  return t || 'any'
}

/** Whether the type string includes `null` (e.g. "string,null"). */
export function isNullableType(type?: string): boolean {
  return (type || '').split(',').map(s => s.trim()).includes('null')
}

/** Extract the definition name from a $ref string (e.g. "#/$defs/MD_Identifier" → "MD_Identifier"). */
export function refLabel(ref: string): string {
  const parts = ref.split('/')
  return parts[parts.length - 1]
}

export interface PatternPropertyRow {
  pattern: string
  type?: string
}

/** Flatten a patternProperties map into table rows, preserving document order. */
export function patternPropertyRows(
  map?: Record<string, { type?: string }>,
): PatternPropertyRow[] {
  return Object.entries(map ?? {}).map(([pattern, info]) => ({
    pattern,
    type: info?.type,
  }))
}

export interface ConditionalRow {
  name: string
  type?: string
}

export interface ConditionalSection {
  label: string
  rows: ConditionalRow[]
  required: string[]
}

/** if/then/else as display sections; empty when the schema is unconditional. */
export function conditionalSections(schema: SpaSchema): ConditionalSection[] {
  const sections: ConditionalSection[] = []
  const toRows = (props?: SpaProperty[]): ConditionalRow[] =>
    (props ?? []).map(p => ({ name: p.name, type: p.type }))

  if (schema.ifSchema) {
    sections.push({
      label: t('panel.if'),
      rows: toRows(schema.ifSchema.properties),
      required: [],
    })
  }
  const thenRows = toRows(schema.thenProperties)
  const thenRequired = schema.thenRequired ?? []
  if (thenRows.length || thenRequired.length) {
    sections.push({ label: t('panel.then'), rows: thenRows, required: thenRequired })
  }
  const elseRows = toRows(schema.elseProperties)
  if (elseRows.length) {
    sections.push({ label: t('panel.else'), rows: elseRows, required: [] })
  }
  return sections
}

export interface VariantOption {
  label: string
  source: 'oneOf' | 'anyOf'
  type?: string
  format?: string
  description?: string
  enum?: string[]
  fields: ConditionalRow[]
}

/** oneOf/anyOf members as tab options, oneOf first. Discriminator values
 * label the variants whose $ref appears in the mapping. */
export function variantOptions(
  holder: {
    oneOfVariants?: SpaProperty[]
    anyOfVariants?: SpaProperty[]
  },
  mapping?: Record<string, string>,
): VariantOption[] {
  const build = (
    variants: SpaProperty[] | undefined,
    source: 'oneOf' | 'anyOf',
  ): VariantOption[] =>
    (variants ?? []).map((variant, index) => {
      const discriminatorValue = variant.ref
        ? Object.entries(mapping ?? {})
          .find(([, ref]) => ref === variant.ref)?.[0]
        : undefined
      return {
        label: discriminatorValue || variant.title || variant.type ||
          `Variant ${index + 1}`,
        source,
        type: variant.type,
        format: variant.format,
        description: variant.description,
        enum: variant.enum,
        fields: (variant.properties ?? []).map(p => ({
          name: p.name,
          type: p.type,
        })),
      }
    })

  return [
    ...build(holder.oneOfVariants, 'oneOf'),
    ...build(holder.anyOfVariants, 'anyOf'),
  ]
}

const DIFF_ORDER: SpaDiffEntry['classification'][] = [
  'breaking',
  'additive',
  'cosmetic',
]

export interface DiffSection {
  label: string
  rows: SpaDiffEntry[]
}

/** Changes grouped by consumer impact, most severe first. */
export function diffSections(entries: SpaDiffEntry[]): DiffSection[] {
  return DIFF_ORDER.flatMap(label => {
    const rows = entries.filter(entry => entry.classification === label)
    return rows.length ? [{ label, rows }] : []
  })
}

export interface EnumRow {
  value: string
  description?: string
}

/** Enum values paired with x-enumDescriptions entries. */
export function enumRows(
  values?: string[],
  descriptions?: Record<string, string>,
): EnumRow[] {
  return (values ?? []).map(value => ({
    value,
    description: descriptions?.[value],
  }))
}

/** Whether the type string is a composition indicator from the backend. */
export function isCompositionType(type?: string): boolean {
  const t = type || ''
  return t.startsWith('anyOf:') || t.startsWith('oneOf:') || t.startsWith('not ')
}

/**
 * Human-readable type display for the type badge.
 * Shows resolved definition title for $ref props, "array of X" notation,
 * and format suffix for primitives.
 */
export function displayType(prop: SpaProperty, resolvedTitle?: string): string {
  const t = primaryType(prop.type)
  const suffix = isNullableType(prop.type) ? ' | null' : ''
  if (isCompositionType(t)) return t + suffix
  if (t === 'array') {
    const itemType = (prop.itemsRef && (!prop.itemsType || prop.itemsType === 'object'))
      ? refLabel(prop.itemsRef)
      : prop.itemsType
    const tuple = prop.itemsTuple?.length
      ? `[${prop.itemsTuple.join(', ')}${prop.itemsTail ? `, *${prop.itemsTail}` : ''}]`
      : undefined
    let label = tuple
      ? `array of ${tuple}`
      : itemType ? `array of ${itemType}` : 'array'
    if (prop.itemsClosed) label += ' (closed)'
    if (prop.minItems != null && prop.maxItems != null) label += ` [ ${prop.minItems} .. ${prop.maxItems} ]`
    else if (prop.minItems != null) label += ` >= ${prop.minItems}`
    else if (prop.maxItems != null) label += ` <= ${prop.maxItems}`
    return label + suffix
  }
  if (resolvedTitle && (t === 'object' || t === 'any') && prop.ref) return resolvedTitle + suffix
  if (prop.format) return `${t} (${prop.format})${suffix}`
  return t + suffix
}

/**
 * HTML input type based on JSON Schema format keyword.
 * Falls back to "text" for unrecognised formats.
 */
export function formatInputType(format?: string): string {
  switch (format) {
    case 'email': return 'email'
    case 'uri':
    case 'uri-reference': return 'url'
    case 'date': return 'date'
    case 'time': return 'time'
    case 'date-time': return 'datetime-local'
    default: return 'text'
  }
}

/**
 * Default string value based on format when no example/default is available.
 */
export function formatDefault(format?: string): string {
  switch (format) {
    case 'uri':
    case 'uri-reference': return 'https://example.com'
    case 'date-time': return '2024-01-01T00:00:00Z'
    case 'date': return '2024-01-01'
    case 'time': return '00:00:00Z'
    case 'email': return 'user@example.com'
    case 'uuid': return '00000000-0000-0000-0000-000000000000'
    default: return 'string'
  }
}

/**
 * The first meaningful value for a property: examples[0], default, first enum,
 * or a type-based fallback.
 */
export function initialValue(prop: SpaProperty): string {
  if (prop.examples?.length) return prop.examples[0]
  if (prop.default != null) return String(prop.default)
  if (prop.enum?.length) return prop.enum[0]
  if (prop.const != null) return String(prop.const)

  const t = primaryType(prop.type)
  switch (t) {
    case 'integer': return '0'
    case 'number': return '0.0'
    case 'boolean': return 'false'
    case 'string': return formatDefault(prop.format)
    case 'object': return '{}'
    default: return ''
  }
}

/**
 * HTML input type for individual array item elements.
 */
export function arrayItemInputType(itemsType?: string): string {
  switch (itemsType) {
    case 'integer':
    case 'number': return 'number'
    case 'boolean': return 'checkbox'
    default: return 'text'
  }
}

/**
 * Default string value for a new array item.
 */
export function arrayDefaultValue(itemsType?: string): string {
  switch (itemsType) {
    case 'integer': return '0'
    case 'number': return '0.0'
    case 'boolean': return 'false'
    default: return ''
  }
}

/**
 * Parse a single array item string to its correct runtime type.
 */
export function parseArrayItem(item: string, itemsType?: string): unknown {
  switch (itemsType) {
    case 'integer': return parseInt(item, 10) || 0
    case 'number': return parseFloat(item) || 0.0
    case 'boolean': return item === 'true'
    default: return item
  }
}

/**
 * Check whether a property is an object (type=object or has a $ref without a type).
 */
export function isObjectProperty(prop: SpaProperty): boolean {
  const t = primaryType(prop.type)
  if (isCompositionType(t)) return false
  return t === 'object' || (!prop.type && !!prop.ref)
}

/**
 * Check whether a property has constraints that should be displayed as chips.
 */
export function hasConstraints(prop: SpaProperty): boolean {
  return !!(
    prop.enum?.length ||
    prop.pattern ||
    prop.minimum != null ||
    prop.maximum != null ||
    prop.minLength != null ||
    prop.maxLength != null ||
    prop.default != null ||
    prop.examples?.length ||
    prop.minItems != null ||
    prop.maxItems != null ||
    prop.uniqueItems ||
    prop.multipleOf != null ||
    prop.const != null ||
    prop.exclusiveMinimum != null ||
    prop.exclusiveMaximum != null ||
    prop.contentMediaType ||
    prop.contentEncoding ||
    prop.itemsRef
  )
}

/**
 * Parse a property's raw string value to its correct runtime type.
 * Handles enums, booleans, numbers, arrays, and objects.
 */
export function parsePropertyValue(rawValue: string, prop: SpaProperty): unknown {
  const t = primaryType(prop.type)
  if (prop.enum?.length) return rawValue
  if (t === 'boolean') return rawValue === 'true'
  if (t === 'integer') {
    const n = parseInt(rawValue, 10)
    return isNaN(n) ? 0 : n
  }
  if (t === 'number') {
    const n = parseFloat(rawValue)
    return isNaN(n) ? 0 : n
  }
  if (t === 'object' && !prop.ref) {
    try { return JSON.parse(rawValue) } catch { return {} }
  }
  return rawValue
}

export interface ConstraintChip {
  label: string
  class?: string
}

export function numberRange(prop: SpaProperty): string | undefined {
  const hasMin = prop.minimum != null
  const hasMax = prop.maximum != null
  const hasExcMin = prop.exclusiveMinimum != null
  const hasExcMax = prop.exclusiveMaximum != null

  if (hasMin && hasMax) {
    const l = hasExcMin ? '( ' : '[ '
    const r = hasExcMax ? ' )' : ' ]'
    return `${l}${prop.minimum} .. ${prop.maximum}${r}`
  }
  if (hasMin && hasExcMax) {
    const l = hasExcMin ? '( ' : '[ '
    return `${l}${prop.minimum} .. ${prop.exclusiveMaximum} )`
  }
  if (hasExcMin && hasMax) {
    const r = hasExcMax ? ' )' : ' ]'
    return `( ${prop.exclusiveMinimum} .. ${prop.maximum}${r}`
  }
  if (hasMax) return `${hasExcMax ? '< ' : '<= '}${prop.maximum}`
  if (hasMin) return `${hasExcMin ? '> ' : '>= '}${prop.minimum}`
  if (hasExcMin && hasExcMax) return `( ${prop.exclusiveMinimum} .. ${prop.exclusiveMaximum} )`
  if (hasExcMax) return `< ${prop.exclusiveMaximum}`
  if (hasExcMin) return `> ${prop.exclusiveMinimum}`
  return undefined
}

export function stringRange(prop: SpaProperty): string | undefined {
  if (prop.minLength != null && prop.maxLength != null) {
    if (prop.minLength === prop.maxLength) return `= ${prop.minLength} characters`
    return `[ ${prop.minLength} .. ${prop.maxLength} ] characters`
  }
  if (prop.minLength != null) {
    if (prop.minLength === 1) return 'non-empty'
    return `>= ${prop.minLength} characters`
  }
  if (prop.maxLength != null) return `<= ${prop.maxLength} characters`
  return undefined
}

export function itemsRange(prop: SpaProperty): string | undefined {
  if (prop.minItems != null && prop.maxItems != null) {
    if (prop.minItems === prop.maxItems) return `= ${prop.minItems} items`
    return `[ ${prop.minItems} .. ${prop.maxItems} ] items`
  }
  if (prop.minItems != null) {
    if (prop.minItems === 1) return 'non-empty'
    return `>= ${prop.minItems} items`
  }
  if (prop.maxItems != null) return `<= ${prop.maxItems} items`
  return undefined
}

export function humanizeConstraints(prop: SpaProperty): ConstraintChip[] {
  const chips: ConstraintChip[] = []
  const t = primaryType(prop.type)

  if (prop.const != null) chips.push({ label: `const: ${prop.const}`, class: 'chip-const' })

  const tIsString = t === 'string' || !t || t === 'any'
  if (tIsString) {
    const range = stringRange(prop)
    if (range) chips.push({ label: range })
  }

  if (t === 'integer' || t === 'number') {
    const range = numberRange(prop)
    if (range) chips.push({ label: range })
    if (prop.multipleOf != null) {
      const s = prop.multipleOf.toString()
      if (/^0\.0*1$/.test(s)) {
        chips.push({ label: `decimal places <= ${s.split('.')[1].length}` })
      } else {
        chips.push({ label: `multiple of ${s}` })
      }
    }
  }

  if (t === 'array') {
    const range = itemsRange(prop)
    if (range) chips.push({ label: range })
    if (prop.uniqueItems) chips.push({ label: 'unique', class: 'chip-unique' })
  }

  if (prop.pattern) chips.push({ label: prop.pattern, class: 'chip-pattern' })
  if (prop.default != null) chips.push({ label: `default: ${prop.default}`, class: 'chip-default' })
  if (prop.examples?.length) chips.push({ label: `e.g. ${prop.examples.join(', ')}`, class: 'chip-example' })
  if (prop.contentMediaType) chips.push({ label: `content-type: ${prop.contentMediaType}` })
  if (prop.contentEncoding) chips.push({ label: `encoding: ${prop.contentEncoding}` })

  return chips
}

export type ValidationError = string

export function validateFieldValue(rawValue: string, prop: SpaProperty): ValidationError | null {
  const t = primaryType(prop.type)

  if (isCompositionType(t)) return null

  if (t === 'string' || t === 'any' || !t) {
    if (prop.minLength != null && rawValue.length < prop.minLength && rawValue.length > 0) {
      return `Min ${prop.minLength} characters`
    }
    if (prop.maxLength != null && rawValue.length > prop.maxLength) {
      return `Max ${prop.maxLength} characters`
    }
    if (prop.pattern && rawValue.length > 0) {
      try {
        if (!new RegExp(prop.pattern).test(rawValue)) {
          return `Must match /${prop.pattern.length > 30 ? prop.pattern.slice(0, 30) + '…' : prop.pattern}/`
        }
      } catch { /* invalid regex, skip */ }
    }
  }

  if (t === 'integer' || t === 'number') {
    const n = t === 'integer' ? parseInt(rawValue, 10) : parseFloat(rawValue)
    if (rawValue !== '' && isNaN(n)) return 'Invalid number'
    if (!isNaN(n)) {
      if (prop.minimum != null && n < prop.minimum) return `Must be >= ${prop.minimum}`
      if (prop.maximum != null && n > prop.maximum) return `Must be <= ${prop.maximum}`
      if (prop.exclusiveMinimum != null && n <= prop.exclusiveMinimum) return `Must be > ${prop.exclusiveMinimum}`
      if (prop.exclusiveMaximum != null && n >= prop.exclusiveMaximum) return `Must be < ${prop.exclusiveMaximum}`
      if (prop.multipleOf != null && n % prop.multipleOf !== 0) return `Must be multiple of ${prop.multipleOf}`
    }
  }

  if (t === 'array') {
    if (rawValue.length > 0) {
      try {
        const arr = JSON.parse(rawValue)
        if (Array.isArray(arr)) {
          if (prop.minItems != null && arr.length < prop.minItems) return `Min ${prop.minItems} items`
          if (prop.maxItems != null && arr.length > prop.maxItems) return `Max ${prop.maxItems} items`
          if (prop.uniqueItems && new Set(arr).size !== arr.length) return 'Items must be unique'
        }
      } catch { /* not JSON, skip */ }
    }
  }

  return null
}

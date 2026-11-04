import { describe, it, expect } from 'vitest'
import {
  primaryType,
  displayType,
  formatInputType,
  formatDefault,
  initialValue,
  arrayItemInputType,
  arrayDefaultValue,
  parseArrayItem,
  isObjectProperty,
  isNullableType,
  hasConstraints,
  parsePropertyValue,
  humanizeConstraints,
  validateFieldValue,
  numberRange,
  stringRange,
  itemsRange,
  refLabel,
} from '../composables/useSchemaTypes'
import type { SpaProperty } from '../types'

function prop(overrides: Partial<SpaProperty> = {}): SpaProperty {
  return { name: 'test', ...overrides }
}

describe('primaryType', () => {
  it('returns the first type from a comma-separated string', () => {
    expect(primaryType('string,integer')).toBe('string')
  })

  it('returns the single type', () => {
    expect(primaryType('object')).toBe('object')
  })

  it('returns "any" for undefined', () => {
    expect(primaryType(undefined)).toBe('any')
  })

  it('returns "any" for empty string', () => {
    expect(primaryType('')).toBe('any')
  })
})

describe('displayType', () => {
  it('shows "array of X" for arrays', () => {
    expect(displayType(prop({ type: 'array', itemsType: 'string' }))).toBe('array of string')
  })

  it('shows resolved title for $ref props', () => {
    expect(displayType(prop({ type: 'object', ref: '#/definitions/Addr' }), 'Address')).toBe('Address')
  })

  it('ignores resolved title when no ref', () => {
    expect(displayType(prop({ type: 'object' }), 'Address')).toBe('object')
  })

  it('shows type (format) when format is set', () => {
    expect(displayType(prop({ type: 'string', format: 'email' }))).toBe('string (email)')
  })

  it('shows plain type when no format', () => {
    expect(displayType(prop({ type: 'integer' }))).toBe('integer')
  })

  it('shows nullable suffix for union with null', () => {
    expect(displayType(prop({ type: 'string,null' }))).toBe('string | null')
  })

  it('shows composition type as-is', () => {
    expect(displayType(prop({ type: 'anyOf:string' }))).toBe('anyOf:string')
  })

  it('shows array with range constraints', () => {
    expect(displayType(prop({ type: 'array', itemsType: 'integer', minItems: 1, maxItems: 10 }))).toBe('array of integer [ 1 .. 10 ]')
  })

  it('shows array with only minItems', () => {
    expect(displayType(prop({ type: 'array', itemsType: 'string', minItems: 1 }))).toBe('array of string >= 1')
  })

  it('shows array with only maxItems', () => {
    expect(displayType(prop({ type: 'array', itemsType: 'string', maxItems: 5 }))).toBe('array of string <= 5')
  })

  it('shows array without itemsType', () => {
    expect(displayType(prop({ type: 'array' }))).toBe('array')
  })

  it('shows array with itemsRef when itemsType is missing', () => {
    expect(displayType(prop({ type: 'array', itemsRef: '#/$defs/MD_Identifier' }))).toBe('array of MD_Identifier')
  })

  it('prefers itemsType over itemsRef when both present', () => {
    expect(displayType(prop({ type: 'array', itemsType: 'string', itemsRef: '#/$defs/SomeDef' }))).toBe('array of string')
  })
})

describe('refLabel', () => {
  it('extracts last segment from $defs ref', () => {
    expect(refLabel('#/$defs/MD_Identifier')).toBe('MD_Identifier')
  })

  it('extracts last segment from definitions ref', () => {
    expect(refLabel('#/definitions/address')).toBe('address')
  })

  it('returns last segment for any path', () => {
    expect(refLabel('#/a/b/c')).toBe('c')
  })
})

describe('formatInputType', () => {
  it.each([
    ['email', 'email'],
    ['uri', 'url'],
    ['uri-reference', 'url'],
    ['date', 'date'],
    ['time', 'time'],
    ['date-time', 'datetime-local'],
    [undefined, 'text'],
    ['unknown', 'text'],
  ])('maps format %s to input type %s', (format, expected) => {
    expect(formatInputType(format)).toBe(expected)
  })
})

describe('formatDefault', () => {
  it('returns URI for uri format', () => {
    expect(formatDefault('uri')).toBe('https://example.com')
  })

  it('returns "string" for unknown format', () => {
    expect(formatDefault('unknown')).toBe('string')
  })

  it('returns "string" for no format', () => {
    expect(formatDefault(undefined)).toBe('string')
  })
})

describe('initialValue', () => {
  it('uses examples[0] first', () => {
    expect(initialValue(prop({ examples: ['hello', 'world'], type: 'string' }))).toBe('hello')
  })

  it('uses default second', () => {
    expect(initialValue(prop({ default: 'fallback', type: 'string' }))).toBe('fallback')
  })

  it('uses first enum value third', () => {
    expect(initialValue(prop({ enum: ['a', 'b'], type: 'string' }))).toBe('a')
  })

  it('uses type-based fallback for integer', () => {
    expect(initialValue(prop({ type: 'integer' }))).toBe('0')
  })

  it('uses type-based fallback for boolean', () => {
    expect(initialValue(prop({ type: 'boolean' }))).toBe('false')
  })

  it('uses format-aware default for string', () => {
    expect(initialValue(prop({ type: 'string', format: 'email' }))).toBe('user@example.com')
  })
})

describe('arrayItemInputType', () => {
  it.each([
    ['integer', 'number'],
    ['number', 'number'],
    ['boolean', 'checkbox'],
    ['string', 'text'],
    [undefined, 'text'],
  ])('maps itemsType %s to input type %s', (itemsType, expected) => {
    expect(arrayItemInputType(itemsType)).toBe(expected)
  })
})

describe('arrayDefaultValue', () => {
  it.each([
    ['integer', '0'],
    ['number', '0.0'],
    ['boolean', 'false'],
    ['string', ''],
    [undefined, ''],
  ])('returns %s default for itemsType %s', (itemsType, expected) => {
    expect(arrayDefaultValue(itemsType)).toBe(expected)
  })
})

describe('parseArrayItem', () => {
  it('parses integer', () => {
    expect(parseArrayItem('42', 'integer')).toBe(42)
  })

  it('parses number', () => {
    expect(parseArrayItem('3.14', 'number')).toBeCloseTo(3.14)
  })

  it('parses boolean true', () => {
    expect(parseArrayItem('true', 'boolean')).toBe(true)
  })

  it('parses boolean false', () => {
    expect(parseArrayItem('false', 'boolean')).toBe(false)
  })

  it('returns string for unknown itemsType', () => {
    expect(parseArrayItem('hello', 'string')).toBe('hello')
  })

  it('returns string for undefined itemsType', () => {
    expect(parseArrayItem('hello', undefined)).toBe('hello')
  })
})

describe('isObjectProperty', () => {
  it('returns true for type=object', () => {
    expect(isObjectProperty(prop({ type: 'object' }))).toBe(true)
  })

  it('returns true for no type but has ref', () => {
    expect(isObjectProperty(prop({ type: undefined, ref: '#/definitions/X' }))).toBe(true)
  })

  it('returns false for string', () => {
    expect(isObjectProperty(prop({ type: 'string' }))).toBe(false)
  })
})

describe('isNullableType', () => {
  it('returns true for type with null', () => {
    expect(isNullableType('string,null')).toBe(true)
  })

  it('returns true for type that is just null', () => {
    expect(isNullableType('null')).toBe(true)
  })

  it('returns false for non-null type', () => {
    expect(isNullableType('string')).toBe(false)
  })

  it('returns false for undefined', () => {
    expect(isNullableType(undefined)).toBe(false)
  })
})

describe('hasConstraints', () => {
  it('returns true for pattern', () => {
    expect(hasConstraints(prop({ pattern: '[0-9]+' }))).toBe(true)
  })

  it('returns true for minimum', () => {
    expect(hasConstraints(prop({ minimum: 0 }))).toBe(true)
  })

  it('returns true for examples', () => {
    expect(hasConstraints(prop({ examples: ['a'] }))).toBe(true)
  })

  it('returns false for no constraints', () => {
    expect(hasConstraints(prop({ type: 'string' }))).toBe(false)
  })

  it('returns true for minItems', () => {
    expect(hasConstraints(prop({ minItems: 1 }))).toBe(true)
  })

  it('returns true for maxItems', () => {
    expect(hasConstraints(prop({ maxItems: 10 }))).toBe(true)
  })

  it('returns true for uniqueItems', () => {
    expect(hasConstraints(prop({ uniqueItems: true }))).toBe(true)
  })

  it('returns true for multipleOf', () => {
    expect(hasConstraints(prop({ multipleOf: 0.5 }))).toBe(true)
  })

  it('returns true for const', () => {
    expect(hasConstraints(prop({ const: 'fixed' }))).toBe(true)
  })

  it('returns true for exclusiveMinimum', () => {
    expect(hasConstraints(prop({ exclusiveMinimum: 0 }))).toBe(true)
  })

  it('returns true for exclusiveMaximum', () => {
    expect(hasConstraints(prop({ exclusiveMaximum: 100 }))).toBe(true)
  })

  it('returns true for contentMediaType', () => {
    expect(hasConstraints(prop({ contentMediaType: 'text/html' }))).toBe(true)
  })

  it('returns true for contentEncoding', () => {
    expect(hasConstraints(prop({ contentEncoding: 'base64' }))).toBe(true)
  })
})

describe('humanizeConstraints', () => {
  it('returns string range constraint with bracket notation', () => {
    const chips = humanizeConstraints(prop({ type: 'string', minLength: 1, maxLength: 100 }))
    expect(chips).toEqual([{ label: '[ 1 .. 100 ] characters' }])
  })

  it('returns non-empty for minLength === 1', () => {
    const chips = humanizeConstraints(prop({ type: 'string', minLength: 1 }))
    expect(chips).toEqual([{ label: 'non-empty' }])
  })

  it('returns numeric range constraint with bracket notation', () => {
    const chips = humanizeConstraints(prop({ type: 'integer', minimum: 0, maximum: 100 }))
    expect(chips.map(c => c.label)).toEqual(['[ 0 .. 100 ]'])
  })

  it('returns exclusive bounds combined as range', () => {
    const chips = humanizeConstraints(prop({ type: 'number', exclusiveMinimum: 0, exclusiveMaximum: 100 }))
    expect(chips.map(c => c.label)).toEqual(['( 0 .. 100 )'])
  })

  it('returns inclusive range combined with exclusive modifier', () => {
    const chips = humanizeConstraints(prop({ type: 'integer', minimum: 0, maximum: 100, exclusiveMinimum: 0 }))
    expect(chips.map(c => c.label)).toEqual(['( 0 .. 100 ]'])
  })

  it('returns array range constraint with bracket notation', () => {
    const chips = humanizeConstraints(prop({ type: 'array', minItems: 1, maxItems: 10 }))
    expect(chips).toEqual([{ label: '[ 1 .. 10 ] items' }])
  })

  it('returns unique for uniqueItems', () => {
    const chips = humanizeConstraints(prop({ type: 'array', uniqueItems: true }))
    expect(chips.map(c => c.label)).toEqual(['unique'])
  })

  it('returns const chip', () => {
    const chips = humanizeConstraints(prop({ const: 'v1' }))
    expect(chips.map(c => c.label)).toEqual(['const: v1'])
  })

  it('returns pattern chip', () => {
    const chips = humanizeConstraints(prop({ pattern: '^[a-z]+$' }))
    expect(chips.map(c => c.label)).toEqual(['^[a-z]+$'])
  })

  it('returns default chip', () => {
    const chips = humanizeConstraints(prop({ default: 'hello' }))
    expect(chips.map(c => c.label)).toEqual(['default: hello'])
  })

  it('returns multipleOf chip', () => {
    const chips = humanizeConstraints(prop({ type: 'integer', multipleOf: 5 }))
    expect(chips.map(c => c.label)).toEqual(['multiple of 5'])
  })

  it('returns empty array for no constraints', () => {
    const chips = humanizeConstraints(prop({ type: 'string' }))
    expect(chips).toEqual([])
  })

  it('returns "non-empty" for minLength 1', () => {
    const chips = humanizeConstraints(prop({ type: 'string', minLength: 1 }))
    expect(chips.map(c => c.label)).toEqual(['non-empty'])
  })

  it('returns "= N characters" when min equals max', () => {
    const chips = humanizeConstraints(prop({ type: 'string', minLength: 10, maxLength: 10 }))
    expect(chips.map(c => c.label)).toEqual(['= 10 characters'])
  })

  it('returns "= N items" when minItems equals maxItems', () => {
    const chips = humanizeConstraints(prop({ type: 'array', minItems: 3, maxItems: 3 }))
    expect(chips.map(c => c.label)).toEqual(['= 3 items'])
  })

  it('returns decimal places for small multipleOf', () => {
    const chips = humanizeConstraints(prop({ type: 'number', multipleOf: 0.01 }))
    expect(chips.map(c => c.label)).toEqual(['decimal places <= 2'])
  })

  it('returns contentMediaType and contentEncoding', () => {
    const chips = humanizeConstraints(prop({ contentMediaType: 'text/html', contentEncoding: 'base64' }))
    expect(chips.map(c => c.label)).toEqual(['content-type: text/html', 'encoding: base64'])
  })
})

describe('numberRange', () => {
  it('returns undefined when no range constraints', () => {
    expect(numberRange(prop({ type: 'integer' }))).toBeUndefined()
  })

  it('returns inclusive range', () => {
    expect(numberRange(prop({ type: 'integer', minimum: 0, maximum: 100 }))).toBe('[ 0 .. 100 ]')
  })

  it('returns exclusive range', () => {
    expect(numberRange(prop({ type: 'number', exclusiveMinimum: 0, exclusiveMaximum: 100 }))).toBe('( 0 .. 100 )')
  })

  it('returns mixed inclusive-exclusive', () => {
    expect(numberRange(prop({ type: 'integer', minimum: 0, maximum: 100, exclusiveMinimum: 0 }))).toBe('( 0 .. 100 ]')
  })

  it('returns only minimum', () => {
    expect(numberRange(prop({ type: 'integer', minimum: 5 }))).toBe('>= 5')
  })

  it('returns exclusive minimum only', () => {
    expect(numberRange(prop({ type: 'integer', exclusiveMinimum: 5 }))).toBe('> 5')
  })

  it('returns only maximum', () => {
    expect(numberRange(prop({ type: 'integer', maximum: 100 }))).toBe('<= 100')
  })

  it('returns exclusive maximum only', () => {
    expect(numberRange(prop({ type: 'integer', exclusiveMaximum: 100 }))).toBe('< 100')
  })
})

describe('stringRange', () => {
  it('returns undefined when no string constraints', () => {
    expect(stringRange(prop({ type: 'string' }))).toBeUndefined()
  })

  it('returns range with characters suffix', () => {
    expect(stringRange(prop({ type: 'string', minLength: 1, maxLength: 100 }))).toBe('[ 1 .. 100 ] characters')
  })

  it('returns equal when min equals max', () => {
    expect(stringRange(prop({ type: 'string', minLength: 10, maxLength: 10 }))).toBe('= 10 characters')
  })

  it('returns non-empty for minLength 1', () => {
    expect(stringRange(prop({ type: 'string', minLength: 1 }))).toBe('non-empty')
  })

  it('returns only maxLength', () => {
    expect(stringRange(prop({ type: 'string', maxLength: 50 }))).toBe('<= 50 characters')
  })
})

describe('itemsRange', () => {
  it('returns undefined when no items constraints', () => {
    expect(itemsRange(prop({ type: 'array' }))).toBeUndefined()
  })

  it('returns range with items suffix', () => {
    expect(itemsRange(prop({ type: 'array', minItems: 1, maxItems: 10 }))).toBe('[ 1 .. 10 ] items')
  })

  it('returns equal when min equals max', () => {
    expect(itemsRange(prop({ type: 'array', minItems: 3, maxItems: 3 }))).toBe('= 3 items')
  })

  it('returns non-empty for minItems 1', () => {
    expect(itemsRange(prop({ type: 'array', minItems: 1 }))).toBe('non-empty')
  })

  it('returns only maxItems', () => {
    expect(itemsRange(prop({ type: 'array', maxItems: 5 }))).toBe('<= 5 items')
  })
})

describe('parsePropertyValue', () => {
  it('returns enum raw value', () => {
    expect(parsePropertyValue('a', prop({ enum: ['a', 'b'], type: 'string' }))).toBe('a')
  })

  it('parses boolean', () => {
    expect(parsePropertyValue('true', prop({ type: 'boolean' }))).toBe(true)
    expect(parsePropertyValue('false', prop({ type: 'boolean' }))).toBe(false)
  })

  it('parses integer', () => {
    expect(parsePropertyValue('42', prop({ type: 'integer' }))).toBe(42)
  })

  it('parses integer as 0 for NaN', () => {
    expect(parsePropertyValue('abc', prop({ type: 'integer' }))).toBe(0)
  })

  it('parses number', () => {
    expect(parsePropertyValue('3.14', prop({ type: 'number' }))).toBeCloseTo(3.14)
  })

  it('returns empty object for object without ref', () => {
    expect(parsePropertyValue('', prop({ type: 'object' }))).toEqual({})
  })

  it('returns raw string for string type', () => {
    expect(parsePropertyValue('hello', prop({ type: 'string' }))).toBe('hello')
  })
})

describe('validateFieldValue', () => {
  it('returns null for valid string', () => {
    expect(validateFieldValue('hello', prop({ type: 'string' }))).toBeNull()
  })

  it('returns null for composition types', () => {
    expect(validateFieldValue('x', prop({ type: 'anyOf:string' }))).toBeNull()
  })

  it('returns error for string too short', () => {
    expect(validateFieldValue('ab', prop({ type: 'string', minLength: 5 }))).toBe('Min 5 characters')
  })

  it('returns error for string too long', () => {
    expect(validateFieldValue('abcdef', prop({ type: 'string', maxLength: 3 }))).toBe('Max 3 characters')
  })

  it('returns null for empty string with minLength', () => {
    expect(validateFieldValue('', prop({ type: 'string', minLength: 5 }))).toBeNull()
  })

  it('returns error for pattern mismatch', () => {
    expect(validateFieldValue('abc', prop({ type: 'string', pattern: '^[0-9]+$' }))).toContain('Must match')
  })

  it('returns null for pattern match', () => {
    expect(validateFieldValue('123', prop({ type: 'string', pattern: '^[0-9]+$' }))).toBeNull()
  })

  it('returns error for invalid integer', () => {
    expect(validateFieldValue('abc', prop({ type: 'integer' }))).toBe('Invalid number')
  })

  it('returns error for integer below minimum', () => {
    expect(validateFieldValue('3', prop({ type: 'integer', minimum: 5 }))).toBe('Must be >= 5')
  })

  it('returns error for integer above maximum', () => {
    expect(validateFieldValue('15', prop({ type: 'integer', maximum: 10 }))).toBe('Must be <= 10')
  })

  it('returns error for integer below exclusiveMinimum', () => {
    expect(validateFieldValue('5', prop({ type: 'integer', exclusiveMinimum: 5 }))).toBe('Must be > 5')
  })

  it('returns error for integer at exclusiveMaximum', () => {
    expect(validateFieldValue('10', prop({ type: 'integer', exclusiveMaximum: 10 }))).toBe('Must be < 10')
  })

  it('returns error for non-multipleOf', () => {
    expect(validateFieldValue('7', prop({ type: 'integer', multipleOf: 3 }))).toBe('Must be multiple of 3')
  })

  it('returns null for valid multipleOf', () => {
    expect(validateFieldValue('9', prop({ type: 'integer', multipleOf: 3 }))).toBeNull()
  })

  it('returns error for number below minimum', () => {
    expect(validateFieldValue('2.5', prop({ type: 'number', minimum: 5 }))).toBe('Must be >= 5')
  })

  it('returns null for valid number', () => {
    expect(validateFieldValue('7.5', prop({ type: 'number', minimum: 5 }))).toBeNull()
  })

  it('returns error for array below minItems', () => {
    expect(validateFieldValue('[1,2]', prop({ type: 'array', minItems: 3 }))).toBe('Min 3 items')
  })

  it('returns error for array above maxItems', () => {
    expect(validateFieldValue('[1,2,3,4,5]', prop({ type: 'array', maxItems: 3 }))).toBe('Max 3 items')
  })

  it('returns error for non-unique array items', () => {
    expect(validateFieldValue('[1,2,1]', prop({ type: 'array', uniqueItems: true }))).toBe('Items must be unique')
  })

  it('returns null for unique array items', () => {
    expect(validateFieldValue('[1,2,3]', prop({ type: 'array', uniqueItems: true }))).toBeNull()
  })

  it('returns null for empty string with no constraints', () => {
    expect(validateFieldValue('', prop({ type: 'integer' }))).toBeNull()
  })
})

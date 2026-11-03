import { describe, it, expect } from 'vitest'
import { createField, buildDefaultJson, isCircular, parseFieldValue } from '../composables/useBuilderField'
import type { SpaProperty, SpaSchema, SpaDefinition } from '../types'

function prop(overrides: Partial<SpaProperty> = {}): SpaProperty {
  return { name: 'test', ...overrides }
}

function definition(overrides: Partial<SpaDefinition> = {}): SpaDefinition {
  return { name: 'Address', properties: [], required: [], ...overrides }
}

function spaSchema(overrides: Partial<SpaSchema> = {}): SpaSchema {
  return { name: 'Test', properties: [], definitions: [], required: [], ...overrides }
}

describe('createField', () => {
  it('marks field as required when in required list', () => {
    const field = createField(prop({ name: 'email' }), ['email'], spaSchema())
    expect(field.isRequired).toBe(true)
    expect(field.included).toBe(true)
  })

  it('marks field as optional when not in required list', () => {
    const field = createField(prop({ name: 'nickname' }), ['email'], spaSchema())
    expect(field.isRequired).toBe(false)
    expect(field.included).toBe(false)
  })

  it('resolves $ref to definition', () => {
    const addressDef = definition({
      name: 'address',
      properties: [
        prop({ name: 'street', type: 'string' }),
      ],
    })
    const s = spaSchema({ definitions: [addressDef] })
    const field = createField(
      prop({ name: 'address', type: 'object', ref: '#/definitions/address' }),
      [],
      s,
    )
    expect(field.resolvedDef).toBe(addressDef)
  })

  it('resolves cross-file $ref via allSchemas', () => {
    const unitRefDef = definition({ name: 'UnitReference', properties: [prop({ name: 'href', type: 'string' })] })
    const basicTypes = spaSchema({ name: 'basicTypes', definitions: [unitRefDef] })
    const quantity = spaSchema({ name: 'Quantity', definitions: [] })
    const allSchemas = [basicTypes, quantity]

    const field = createField(
      prop({ name: 'uom', ref: 'basicTypes.json#/$defs/UnitReference' }),
      [],
      quantity,
      allSchemas,
    )
    expect(field.resolvedDef).toBe(unitRefDef)
  })

  it('initializes array items for array type', () => {
    const field = createField(
      prop({ name: 'tags', type: 'array', itemsType: 'string' }),
      [],
      spaSchema(),
    )
    expect(field.arrayItems).toEqual([''])
  })

  it('marks field as required when prop.required is true', () => {
    const field = createField(prop({ name: 'x', required: true }), [], spaSchema())
    expect(field.isRequired).toBe(true)
    expect(field.included).toBe(true)
  })

  it('auto-expands definition with single property', () => {
    const def = definition({ name: 'Wrap', properties: [prop({ name: 'value', type: 'string' })] })
    const s = spaSchema({ definitions: [def] })
    const field = createField(
      prop({ name: 'wrap', type: 'object', ref: '#/definitions/Wrap' }),
      [],
      s,
      undefined,
      3, // deep nesting
    )
    expect(field.expanded).toBe(true)
  })

  it('auto-expands at depth 0 with ≤8 properties', () => {
    const props = Array.from({ length: 8 }, (_, i) => prop({ name: `f${i}`, type: 'string' }))
    const def = definition({ name: 'Small', properties: props })
    const s = spaSchema({ definitions: [def] })
    const field = createField(
      prop({ name: 'obj', type: 'object', ref: '#/definitions/Small' }),
      [],
      s,
    )
    expect(field.expanded).toBe(true)
  })

  it('does not auto-expand at depth 0 with >8 properties', () => {
    const props = Array.from({ length: 9 }, (_, i) => prop({ name: `f${i}`, type: 'string' }))
    const def = definition({ name: 'Big', properties: props })
    const s = spaSchema({ definitions: [def] })
    const field = createField(
      prop({ name: 'obj', type: 'object', ref: '#/definitions/Big' }),
      [],
      s,
    )
    expect(field.expanded).toBe(false)
  })

  it('does not auto-expand at depth >0 with multiple properties', () => {
    const props = [prop({ name: 'a', type: 'string' }), prop({ name: 'b', type: 'string' })]
    const def = definition({ name: 'Pair', properties: props })
    const s = spaSchema({ definitions: [def] })
    const field = createField(
      prop({ name: 'pair', type: 'object', ref: '#/definitions/Pair' }),
      [],
      s,
      undefined,
      1,
    )
    expect(field.expanded).toBe(false)
  })

  it('initializes boolean field with false', () => {
    const field = createField(prop({ name: 'flag', type: 'boolean' }), [], spaSchema())
    expect(field.rawValue).toBe('false')
  })

  it('initializes integer field with 0', () => {
    const field = createField(prop({ name: 'count', type: 'integer' }), [], spaSchema())
    expect(field.rawValue).toBe('0')
  })

  it('builds nestedJson for resolved definition', () => {
    const def = definition({
      name: 'Addr',
      properties: [prop({ name: 'city', type: 'string' })],
    })
    const s = spaSchema({ definitions: [def] })
    const field = createField(
      prop({ name: 'addr', type: 'object', ref: '#/definitions/Addr' }),
      [],
      s,
    )
    expect(field.nestedJson).toEqual({ city: 'string' })
  })

  it('leaves array items empty for non-array type', () => {
    const field = createField(prop({ name: 'name', type: 'string' }), [], spaSchema())
    expect(field.arrayItems).toEqual([])
  })
})

describe('buildDefaultJson', () => {
  it('builds object from properties', () => {
    const props = [
      prop({ name: 'name', type: 'string' }),
      prop({ name: 'age', type: 'integer' }),
    ]
    const result = buildDefaultJson(props)
    expect(result).toEqual({ name: 'string', age: 0 })
  })

  it('builds array property', () => {
    const props = [
      prop({ name: 'tags', type: 'array', itemsType: 'string' }),
    ]
    const result = buildDefaultJson(props)
    expect(result).toEqual({ tags: [''] })
  })

  it('builds empty object for object without ref', () => {
    const props = [
      prop({ name: 'meta', type: 'object' }),
    ]
    const result = buildDefaultJson(props)
    expect(result).toEqual({ meta: {} })
  })
})

describe('isCircular', () => {
  it('returns true when definition name is in visited set', () => {
    const field = createField(
      prop({ name: 'self', type: 'object', ref: '#/definitions/Address' }),
      [],
      spaSchema({ definitions: [definition({ name: 'Address' })] }),
    )
    expect(isCircular(field, new Set(['Address']))).toBe(true)
  })

  it('returns false when definition name is not in visited set', () => {
    const field = createField(
      prop({ name: 'self', type: 'object', ref: '#/definitions/Address' }),
      [],
      spaSchema({ definitions: [definition({ name: 'Address' })] }),
    )
    expect(isCircular(field, new Set())).toBe(false)
  })

  it('returns false when resolvedDef is null', () => {
    const field = createField(prop({ name: 'x', type: 'string' }), [], spaSchema())
    expect(isCircular(field, new Set())).toBe(false)
  })
})

describe('parseFieldValue', () => {
  it('parses string value', () => {
    const field = createField(prop({ name: 'x', type: 'string' }), [], spaSchema())
    field.rawValue = 'hello'
    expect(parseFieldValue(field)).toBe('hello')
  })

  it('parses integer value', () => {
    const field = createField(prop({ name: 'x', type: 'integer' }), [], spaSchema())
    field.rawValue = '42'
    expect(parseFieldValue(field)).toBe(42)
  })

  it('parses array from arrayItems', () => {
    const field = createField(prop({ name: 'x', type: 'array', itemsType: 'string' }), [], spaSchema())
    field.arrayItems = ['a', 'b']
    expect(parseFieldValue(field)).toEqual(['a', 'b'])
  })

  it('parses array of integers', () => {
    const field = createField(prop({ name: 'x', type: 'array', itemsType: 'integer' }), [], spaSchema())
    field.arrayItems = ['1', '2', '3']
    expect(parseFieldValue(field)).toEqual([1, 2, 3])
  })
})

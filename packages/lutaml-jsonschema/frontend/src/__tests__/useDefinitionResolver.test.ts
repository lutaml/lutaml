import { describe, it, expect } from 'vitest'
import { resolveSchemaRef } from '../composables/useDefinitionResolver'
import type { SpaSchema, SpaDefinition } from '../types'

function definition(overrides: Partial<SpaDefinition> = {}): SpaDefinition {
  return { name: 'Test', properties: [], required: [], ...overrides }
}

function schema(overrides: Partial<SpaSchema> = {}): SpaSchema {
  return { name: 'TestSchema', properties: [], definitions: [], required: [], ...overrides }
}

describe('resolveSchemaRef', () => {
  it('returns null for undefined ref', () => {
    expect(resolveSchemaRef(undefined, schema())).toBeNull()
  })

  it('returns null for empty string ref', () => {
    expect(resolveSchemaRef('', schema())).toBeNull()
  })

  it('resolves #/definitions/NAME', () => {
    const address = definition({ name: 'address', title: 'Address', type: 'object' })
    const s = schema({ definitions: [address] })
    expect(resolveSchemaRef('#/definitions/address', s)).toBe(address)
  })

  it('resolves #/$defs/NAME', () => {
    const email = definition({ name: 'email', type: 'object' })
    const s = schema({ definitions: [email] })
    expect(resolveSchemaRef('#/$defs/email', s)).toBe(email)
  })

  it('returns null for non-existent definition', () => {
    const s = schema({ definitions: [definition({ name: 'other' })] })
    expect(resolveSchemaRef('#/definitions/missing', s)).toBeNull()
  })

  it('returns null for malformed ref', () => {
    expect(resolveSchemaRef('not-a-ref', schema())).toBeNull()
  })

  it('returns null for partial ref without definition name', () => {
    expect(resolveSchemaRef('#/definitions/', schema())).toBeNull()
  })

  describe('cross-schema refs', () => {
    const unitRef = definition({ name: 'UnitReference', type: 'object', properties: [] })
    const basicTypes = schema({ name: 'basicTypes', definitions: [unitRef] })
    const coverage = schema({ name: 'coverage-schema', definitions: [] })
    const allSchemas = [basicTypes, coverage]

    it('resolves FILENAME#/$defs/NAME across schemas', () => {
      expect(resolveSchemaRef('basicTypes.json#/$defs/UnitReference', coverage, allSchemas)).toBe(unitRef)
    })

    it('resolves with ./ prefix', () => {
      expect(resolveSchemaRef('./basicTypes.json#/$defs/UnitReference', coverage, allSchemas)).toBe(unitRef)
    })

    it('returns null for unknown file', () => {
      expect(resolveSchemaRef('unknown.json#/$defs/X', coverage, allSchemas)).toBeNull()
    })

    it('returns null for unknown definition in known file', () => {
      expect(resolveSchemaRef('basicTypes.json#/$defs/Missing', coverage, allSchemas)).toBeNull()
    })

    it('returns null when allSchemas is not provided', () => {
      expect(resolveSchemaRef('basicTypes.json#/$defs/UnitReference', coverage)).toBeNull()
    })

    it('resolves ./FILENAME to root object as definition', () => {
      const person = schema({ name: 'person', title: 'Person', type: 'object', properties: [], definitions: [], required: [] })
      const all = [person, coverage]
      const result = resolveSchemaRef('./person.json', coverage, all)
      expect(result).not.toBeNull()
      expect(result!.name).toBe('person')
      expect(result!.title).toBe('Person')
    })

    it('returns null for unknown root file ref', () => {
      expect(resolveSchemaRef('./unknown.json', coverage, allSchemas)).toBeNull()
    })
  })
})

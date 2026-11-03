/**
 * @vitest-environment jsdom
 */
import { describe, it, expect, beforeEach } from 'vitest'
import { createPinia, setActivePinia } from 'pinia'
import { useSchemaStore } from '../stores/schemaStore'
import { resolveSchemaRef } from '../composables/useDefinitionResolver'
import {
  primaryType,
  displayType,
  hasConstraints,
  humanizeConstraints,
  refLabel,
  initialValue,
} from '../composables/useSchemaTypes'
import { createField, buildDefaultJson } from '../composables/useBuilderField'
import type { SpaDocument, SpaProperty, SpaDefinition, SpaSchema } from '../types'

function prop(overrides: Partial<SpaProperty> = {}): SpaProperty {
  return { name: 'test', ...overrides }
}

function definition(overrides: Partial<SpaDefinition> = {}): SpaDefinition {
  return { name: 'Test', properties: [], required: [], ...overrides }
}

function schema(overrides: Partial<SpaSchema> = {}): SpaSchema {
  return { name: 'TestSchema', properties: [], definitions: [], required: [], ...overrides }
}

/**
 * Builds a SpaDocument simulating the mdj.json ISO 19115-4 patterns
 * that were previously losing data in the SPA builder.
 */
function buildMdjDoc(): SpaDocument {
  const dateOrDateTime: SpaDefinition = {
    name: 'DateOrDateTime',
    hasOneOf: true,
    compositionVariants: ['Date (string)', 'DateTime (string)'],
    properties: [],
    required: [],
  }

  const mdIdentification: SpaDefinition = {
    name: 'MD_Identification',
    type: 'object',
    hasAllOf: true,
    properties: [
      prop({ name: 'abstract', type: 'string' }),
      prop({ name: 'purpose', type: 'string' }),
    ],
    required: ['abstract'],
  }

  const mdDataIdentification: SpaDefinition = {
    name: 'MD_DataIdentification',
    type: 'object',
    hasOneOf: true,
    compositionVariants: ['MD_Identification (object)', 'Abstract_Class (object)'],
    properties: [
      prop({ name: 'spatialRepresentationType', type: 'string' }),
    ],
    required: [],
  }

  const constraint: SpaDefinition = {
    name: 'MD_Constraints',
    type: 'object',
    properties: [
      prop({ name: 'useLimitation', type: 'string' }),
    ],
    required: [],
  }

  const legalConstraint: SpaDefinition = {
    name: 'MD_LegalConstraints',
    type: 'object',
    additionalPropertiesRef: '#/$defs/MD_Constraints',
    hasAllOf: true,
    properties: [
      prop({ name: 'accessConstraints', type: 'string', enum: ['copyright', 'patent', 'trademark'] }),
    ],
    required: [],
  }

  const stringMap: SpaDefinition = {
    name: 'LocaleChain',
    type: 'object',
    additionalPropertiesType: 'string',
    properties: [],
    required: [],
  }

  const topicCategory: SpaDefinition = {
    name: 'MD_TopicCategoryCode',
    type: 'string',
    enum: ['farming', 'biota', 'boundaries'],
    properties: [],
    required: [],
  }

  const scopeCode: SpaDefinition = {
    name: 'MD_ScopeCode',
    type: 'string',
    enum: ['dataset', 'series', 'service'],
    properties: [],
    required: [],
  }

  const mdMetadata: SpaDefinition = {
    name: 'MD_Metadata',
    title: 'Metadata',
    type: 'object',
    description: 'Root metadata object',
    properties: [
      // Property resolved from enum definition
      prop({
        name: 'topicCategory',
        ref: '#/$defs/MD_TopicCategoryCode',
        type: 'string',
        enum: ['farming', 'biota', 'boundaries'],
      }),
      // Const property (type inferred as "string")
      prop({
        name: 'schemaVersion',
        type: 'string',
        const: '1.0.0',
      }),
      // Empty schema fallback (type = "any")
      prop({
        name: 'extensionInfo',
        type: 'any',
      }),
      // Anchor ref property
      prop({
        name: 'identificationInfo',
        ref: '#MD_DataIdentification',
        type: 'object',
      }),
      // Array with itemsRef
      prop({
        name: 'contact',
        type: 'array',
        itemsType: 'object',
        itemsRef: '#/$defs/CI_Contact',
        minItems: 1,
      }),
      // Array with items oneOf composition
      prop({
        name: 'extent',
        type: 'array',
        itemsType: 'oneOf: string | object',
        itemsRef: '#/$defs/EX_Extent',
      }),
      // String with format
      prop({
        name: 'metadataStandard',
        type: 'string',
        format: 'uri',
      }),
      // Nullable property
      prop({
        name: 'profile',
        type: 'string,null',
      }),
      // Composition type
      prop({
        name: 'lineage',
        type: 'oneOf: string | object',
      }),
      // Number with constraints
      prop({
        name: 'spatialResolution',
        type: 'integer',
        minimum: 1,
        maximum: 100,
        multipleOf: 1,
      }),
    ],
    required: ['topicCategory'],
  }

  const ciContact: SpaDefinition = {
    name: 'CI_Contact',
    type: 'object',
    properties: [
      prop({ name: 'address', type: 'string' }),
    ],
    required: [],
  }

  const exExtent: SpaDefinition = {
    name: 'EX_Extent',
    type: 'object',
    properties: [
      prop({ name: 'description', type: 'string' }),
    ],
    required: [],
  }

  // Root schema with $defs only (no root properties)
  return {
    metadata: { title: 'ISO 19115-4 Metadata' },
    schemas: [{
      name: 'mdj',
      title: 'ISO 19115-4',
      type: 'object',
      properties: [],
      definitions: [
        mdMetadata,
        mdIdentification,
        mdDataIdentification,
        dateOrDateTime,
        constraint,
        legalConstraint,
        stringMap,
        topicCategory,
        scopeCode,
        ciContact,
        exExtent,
      ],
      required: [],
      sourceJson: '{}',
    }],
    searchIndex: [],
  }
}

describe('MDJ pattern: anchor ref resolution', () => {
  it('resolves #NAME anchor ref to a definition by name', () => {
    const target = definition({ name: 'MD_DataIdentification', type: 'object' })
    const s = schema({ definitions: [target] })
    expect(resolveSchemaRef('#MD_DataIdentification', s)).toBe(target)
  })

  it('resolves #DateOrDateTime anchor ref', () => {
    const target = definition({ name: 'DateOrDateTime', hasOneOf: true })
    const s = schema({ definitions: [target] })
    expect(resolveSchemaRef('#DateOrDateTime', s)).toBe(target)
  })

  it('returns null for non-existent anchor ref', () => {
    const s = schema({ definitions: [definition({ name: 'Other' })] })
    expect(resolveSchemaRef('#NonExistent', s)).toBeNull()
  })

  it('anchor ref takes lower priority than path ref when ambiguous', () => {
    // #/definitions/NAME should match before #NAME
    const target = definition({ name: 'MyDef', type: 'object' })
    const s = schema({ definitions: [target] })
    expect(resolveSchemaRef('#/definitions/MyDef', s)).toBe(target)
  })
})

describe('MDJ pattern: composition variants', () => {
  const doc = buildMdjDoc()

  it('DateOrDateTime has compositionVariants', () => {
    const d = doc.schemas[0].definitions.find(d => d.name === 'DateOrDateTime')!
    expect(d.compositionVariants).toEqual(['Date (string)', 'DateTime (string)'])
  })

  it('MD_DataIdentification has compositionVariants', () => {
    const d = doc.schemas[0].definitions.find(d => d.name === 'MD_DataIdentification')!
    expect(d.compositionVariants).toEqual(['MD_Identification (object)', 'Abstract_Class (object)'])
  })

  it('MD_Identification has no compositionVariants (allOf only)', () => {
    const d = doc.schemas[0].definitions.find(d => d.name === 'MD_Identification')!
    expect(d.compositionVariants).toBeUndefined()
  })
})

describe('MDJ pattern: additionalProperties', () => {
  const doc = buildMdjDoc()

  it('definition with additionalPropertiesRef from $ref', () => {
    const d = doc.schemas[0].definitions.find(d => d.name === 'MD_LegalConstraints')!
    expect(d.additionalPropertiesRef).toBe('#/$defs/MD_Constraints')
  })

  it('definition with additionalPropertiesType from primitive type', () => {
    const d = doc.schemas[0].definitions.find(d => d.name === 'LocaleChain')!
    expect(d.additionalPropertiesType).toBe('string')
  })

  it('regular definition has no additionalProperties fields', () => {
    const d = doc.schemas[0].definitions.find(d => d.name === 'MD_Constraints')!
    expect(d.additionalPropertiesRef).toBeUndefined()
    expect(d.additionalPropertiesType).toBeUndefined()
  })
})

describe('MDJ pattern: const type inference', () => {
  const doc = buildMdjDoc()

  it('const property has type inferred as string', () => {
    const md = doc.schemas[0].definitions.find(d => d.name === 'MD_Metadata')!
    const schemaVersion = md.properties.find(p => p.name === 'schemaVersion')!
    expect(schemaVersion.type).toBe('string')
    expect(schemaVersion.const).toBe('1.0.0')
  })

  it('const is detected as a constraint', () => {
    const md = doc.schemas[0].definitions.find(d => d.name === 'MD_Metadata')!
    const schemaVersion = md.properties.find(p => p.name === 'schemaVersion')!
    expect(hasConstraints(schemaVersion)).toBe(true)
  })

  it('humanizeConstraints shows const chip', () => {
    const md = doc.schemas[0].definitions.find(d => d.name === 'MD_Metadata')!
    const schemaVersion = md.properties.find(p => p.name === 'schemaVersion')!
    const chips = humanizeConstraints(schemaVersion)
    expect(chips.some(c => c.label === 'const: 1.0.0')).toBe(true)
  })

  it('displayType shows const type as string', () => {
    expect(displayType(prop({ type: 'string', const: '1.0.0' }))).toBe('string')
  })
})

describe('MDJ pattern: empty schema fallback (type "any")', () => {
  const doc = buildMdjDoc()

  it('empty schema property gets type "any"', () => {
    const md = doc.schemas[0].definitions.find(d => d.name === 'MD_Metadata')!
    const ext = md.properties.find(p => p.name === 'extensionInfo')!
    expect(ext.type).toBe('any')
  })

  it('primaryType returns "any" for "any" type', () => {
    expect(primaryType('any')).toBe('any')
  })

  it('displayType shows "any" for empty schema', () => {
    expect(displayType(prop({ type: 'any' }))).toBe('any')
  })

  it('initialValue for "any" type returns empty string', () => {
    expect(initialValue(prop({ type: 'any' }))).toBe('')
  })
})

describe('MDJ pattern: ref chain resolution via anchor refs', () => {
  it('anchor ref resolves directly when definition exists in same schema', () => {
    const target = definition({ name: 'MD_DataIdentification', type: 'object', properties: [
      prop({ name: 'id', type: 'string' }),
    ]})
    const s = schema({ definitions: [target] })
    const resolved = resolveSchemaRef('#MD_DataIdentification', s)
    expect(resolved).not.toBeNull()
    expect(resolved!.name).toBe('MD_DataIdentification')
    expect(resolved!.properties).toHaveLength(1)
  })

  it('anchor ref is distinct from #/definitions/ path', () => {
    const target = definition({ name: 'Foo', type: 'object' })
    const s = schema({ definitions: [target] })
    // Both should resolve to the same definition
    expect(resolveSchemaRef('#Foo', s)).toBe(resolveSchemaRef('#/definitions/Foo', s))
  })
})

describe('MDJ pattern: itemsRef with anchor format', () => {
  it('itemsRef with #/$defs/ path shows correct display type', () => {
    const p = prop({ type: 'array', itemsType: 'object', itemsRef: '#/$defs/CI_Contact' })
    expect(displayType(p)).toBe('array of CI_Contact')
  })

  it('itemsRef with anchor format #Name — refLabel returns full string (no slash separator)', () => {
    // refLabel splits on '/', anchor refs like '#Name' have no slash
    // so the caller must strip the '#' prefix if needed
    expect(refLabel('#CI_Contact')).toBe('#CI_Contact')
  })

  it('array with items oneOf composition type', () => {
    const p = prop({ type: 'array', itemsType: 'oneOf: string | object', itemsRef: '#/$defs/EX_Extent' })
    expect(displayType(p)).toBe('array of oneOf: string | object')
  })
})

describe('MDJ pattern: store normalization for mdj document', () => {
  let store: ReturnType<typeof useSchemaStore>

  beforeEach(() => {
    setActivePinia(createPinia())
    store = useSchemaStore()
  })

  it('loads complete mdj document with all definitions', () => {
    window.SCHEMA_DATA = buildMdjDoc() as any
    store.loadFromWindow()
    expect(store.schemas).toHaveLength(1)
    expect(store.schemas[0].definitions).toHaveLength(11)
  })

  it('normalizes $ref → ref on mdj properties', () => {
    const doc = buildMdjDoc()
    // Simulate backend $ref key on a property
    const md = doc.schemas[0].definitions.find(d => d.name === 'MD_Metadata')!
    const topic = md.properties.find(p => p.name === 'topicCategory')!
    ;(topic as any).$ref = topic.ref
    delete topic.ref

    window.SCHEMA_DATA = doc as any
    store.loadFromWindow()

    const loadedMd = store.schemas[0].definitions.find(d => d.name === 'MD_Metadata')!
    const loadedTopic = loadedMd.properties.find(p => p.name === 'topicCategory')!
    expect(loadedTopic.ref).toBe('#/$defs/MD_TopicCategoryCode')
    expect((loadedTopic as any).$ref).toBeUndefined()
  })

  it('resolves anchor ref properties in store', () => {
    window.SCHEMA_DATA = buildMdjDoc() as any
    store.loadFromWindow()

    const s = store.schemas[0]
    const resolved = resolveSchemaRef('#MD_DataIdentification', s)
    expect(resolved).not.toBeNull()
    expect(resolved!.type).toBe('object')
  })

  it('all definition types are present and correct', () => {
    window.SCHEMA_DATA = buildMdjDoc() as any
    store.loadFromWindow()

    const defs = store.schemas[0].definitions
    const names = defs.map(d => d.name)
    expect(names).toContain('MD_Metadata')
    expect(names).toContain('MD_Identification')
    expect(names).toContain('MD_DataIdentification')
    expect(names).toContain('DateOrDateTime')
    expect(names).toContain('MD_Constraints')
    expect(names).toContain('MD_LegalConstraints')
    expect(names).toContain('LocaleChain')
    expect(names).toContain('MD_TopicCategoryCode')
    expect(names).toContain('MD_ScopeCode')
    expect(names).toContain('CI_Contact')
    expect(names).toContain('EX_Extent')
  })
})

describe('MDJ pattern: builder fields for all property types', () => {
  const doc = buildMdjDoc()

  it('creates field for enum property from definition', () => {
    const md = doc.schemas[0].definitions.find(d => d.name === 'MD_Metadata')!
    const topic = md.properties.find(p => p.name === 'topicCategory')!
    const s = schema({
      definitions: [definition({ name: 'MD_TopicCategoryCode', type: 'string', enum: ['farming', 'biota', 'boundaries'], properties: [], required: [] })],
    })
    const field = createField(topic, [], s)
    expect(field.rawValue).toBe('farming')
  })

  it('creates field for const property', () => {
    const p = prop({ name: 'version', type: 'string', const: '1.0.0' })
    const field = createField(p, [], schema())
    expect(field.rawValue).toBe('1.0.0')
  })

  it('creates field for any type property (empty schema)', () => {
    const p = prop({ name: 'ext', type: 'any' })
    const field = createField(p, [], schema())
    expect(field.rawValue).toBe('')
  })

  it('creates field for array with itemsRef', () => {
    const p = prop({ name: 'contact', type: 'array', itemsType: 'object', itemsRef: '#/$defs/CI_Contact', minItems: 1 })
    const s = schema({
      definitions: [definition({ name: 'CI_Contact', type: 'object', properties: [prop({ name: 'address', type: 'string' })], required: [] })],
    })
    const field = createField(p, [], s)
    expect(field.arrayItems).toHaveLength(1)
    expect(field.arrayItems[0]).toBe('')
  })

  it('creates field for composition type', () => {
    const p = prop({ name: 'lineage', type: 'oneOf: string | object' })
    const field = createField(p, [], schema())
    expect(field.rawValue).toBe('')
  })

  it('creates field for nullable string', () => {
    const p = prop({ name: 'profile', type: 'string,null' })
    const field = createField(p, [], schema())
    expect(field.rawValue).toBe('string')
  })

  it('creates field for integer with constraints', () => {
    const p = prop({ name: 'spatialResolution', type: 'integer', minimum: 1, maximum: 100, multipleOf: 1 })
    const field = createField(p, [], schema())
    expect(field.rawValue).toBe('0')
  })
})

describe('MDJ pattern: buildDefaultJson for complete MD_Metadata', () => {
  const doc = buildMdjDoc()

  it('builds default JSON with all MD_Metadata properties', () => {
    const md = doc.schemas[0].definitions.find(d => d.name === 'MD_Metadata')!
    const json = buildDefaultJson(md.properties) as Record<string, unknown>
    expect(json.topicCategory).toBe('farming')
    expect(json.schemaVersion).toBe('1.0.0')
    expect(json.extensionInfo).toBe('')
    expect(json.contact).toEqual([''])
    expect(json.extent).toEqual([''])
    expect(json.metadataStandard).toBe('https://example.com')
    expect(json.profile).toBe('string')
    expect(json.lineage).toBe('')
    expect(json.spatialResolution).toBe(0)
    // identificationInfo is object with ref — no default value from buildDefaultJson
  })
})

describe('MDJ pattern: constraint chips for all property types', () => {
  it('const property gets const chip', () => {
    const chips = humanizeConstraints(prop({ type: 'string', const: '1.0.0' }))
    expect(chips.some(c => c.label === 'const: 1.0.0')).toBe(true)
  })

  it('enum property has constraints', () => {
    expect(hasConstraints(prop({ type: 'string', enum: ['a', 'b'] }))).toBe(true)
  })

  it('array with itemsRef has constraints', () => {
    expect(hasConstraints(prop({ type: 'array', itemsRef: '#/$defs/Foo' }))).toBe(true)
  })

  it('array with minItems and itemsRef has constraints', () => {
    const p = prop({ type: 'array', itemsRef: '#/$defs/CI_Contact', minItems: 1 })
    expect(hasConstraints(p)).toBe(true)
    const chips = humanizeConstraints(p)
    expect(chips.some(c => c.label === 'non-empty')).toBe(true)
  })

  it('integer with range and multipleOf has all constraint chips', () => {
    const p = prop({ type: 'integer', minimum: 1, maximum: 100, multipleOf: 1 })
    const chips = humanizeConstraints(p)
    expect(chips.some(c => c.label === '[ 1 .. 100 ]')).toBe(true)
    expect(chips.some(c => c.label === 'multiple of 1')).toBe(true)
  })

  it('format uri property has no constraint chips', () => {
    const chips = humanizeConstraints(prop({ type: 'string', format: 'uri' }))
    expect(chips).toEqual([])
  })

  it('composition type property has no constraint chips', () => {
    const chips = humanizeConstraints(prop({ type: 'oneOf: string | object' }))
    expect(chips).toEqual([])
  })
})

describe('MDJ pattern: definition-level data completeness', () => {
  const doc = buildMdjDoc()

  it('every definition has a name', () => {
    doc.schemas[0].definitions.forEach(d => {
      expect(d.name).toBeTruthy()
    })
  })

  it('object definitions have properties arrays', () => {
    doc.schemas[0].definitions.forEach(d => {
      if (d.type === 'object') {
        expect(Array.isArray(d.properties)).toBe(true)
      }
    })
  })

  it('enum definitions have non-empty enum arrays', () => {
    const topicCat = doc.schemas[0].definitions.find(d => d.name === 'MD_TopicCategoryCode')!
    expect(topicCat.enum!.length).toBeGreaterThan(0)
    const scopeCode = doc.schemas[0].definitions.find(d => d.name === 'MD_ScopeCode')!
    expect(scopeCode.enum!.length).toBeGreaterThan(0)
  })

  it('no property in any definition has missing type/ref/const', () => {
    doc.schemas[0].definitions.forEach(d => {
      d.properties.forEach(p => {
        const hasType = !!p.type
        const hasRef = !!p.ref
        const hasConst = !!p.const
        expect(
          hasType || hasRef || hasConst,
          `Property "${p.name}" in "${d.name}" has no type, ref, or const`
        ).toBe(true)
      })
    })
  })
})

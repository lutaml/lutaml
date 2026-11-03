/**
 * @vitest-environment jsdom
 */
import { describe, it, expect, beforeEach } from 'vitest'
import { createPinia, setActivePinia } from 'pinia'
import { useSchemaStore } from '../stores/schemaStore'
import {
  primaryType,
  displayType,
  refLabel,
  humanizeConstraints,
  hasConstraints,
  patternPropertyRows,
  conditionalSections,
  variantOptions,
  diffSections,
  enumRows,
} from '../composables/useSchemaTypes'
import { resolveSchemaRef } from '../composables/useDefinitionResolver'
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
 * Build a SpaDocument that mimics what the Ruby backend outputs
 * for a complex schema like ISO 19115-4 mdj.json.
 */
function buildComplexDoc(): SpaDocument {
  const mdIdentifier: SpaDefinition = {
    name: 'MD_Identifier',
    title: 'Identifier',
    type: 'object',
    properties: [
      prop({ name: 'code', type: 'string', required: true }),
      prop({ name: 'codeSpace', type: 'string', format: 'uri' }),
    ],
    required: ['code'],
  }

  const topicCategory: SpaDefinition = {
    name: 'MD_TopicCategoryCode',
    title: 'Topic Category',
    type: 'string',
    enum: ['farming', 'biota', 'boundaries', 'climatology', 'economy', 'elevation'],
    properties: [],
    required: [],
  }

  const obligationCode: SpaDefinition = {
    name: 'MD_ObligationCode',
    type: 'string',
    enum: ['mandatory', 'optional', 'conditional'],
    properties: [],
    required: [],
  }

  const ciTelephone: SpaDefinition = {
    name: 'CI_Telephone',
    type: 'object',
    properties: [
      prop({ name: 'number', type: 'string' }),
    ],
    required: [],
  }

  const durationType: SpaDefinition = {
    name: 'DurationType',
    type: 'string',
    format: 'duration',
    pattern: '^P.*$',
    properties: [],
    required: [],
  }

  const constraintUnion: SpaDefinition = {
    name: 'Abstract_ConstraintUnion',
    hasOneOf: true,
    properties: [],
    required: [],
  }

  const mdMetadata: SpaDefinition = {
    name: 'MD_Metadata',
    title: 'Metadata',
    type: 'object',
    description: 'Root metadata object',
    properties: [
      prop({ name: 'name', type: 'string', required: true }),
      prop({
        name: 'identifiers',
        type: 'array',
        itemsType: 'object',
        itemsRef: '#/$defs/MD_Identifier',
      }),
      prop({
        name: 'topicCategory',
        ref: '#/$defs/MD_TopicCategoryCode',
        type: 'string',
        enum: ['farming', 'biota', 'boundaries', 'climatology', 'economy', 'elevation'],
      }),
      prop({
        name: 'contacts',
        type: 'array',
        itemsType: 'object',
        itemsRef: '#/$defs/CI_Contact',
        minItems: 1,
      }),
    ],
    required: ['name'],
  }

  const ciContact: SpaDefinition = {
    name: 'CI_Contact',
    type: 'object',
    properties: [
      prop({
        name: 'phone',
        type: 'array',
        itemsType: 'object',
        itemsRef: '#/$defs/CI_Telephone',
      }),
    ],
    required: [],
  }

  return {
    metadata: { title: 'ISO 19115-4 Metadata' },
    schemas: [{
      name: 'mdj',
      title: 'ISO 19115-4',
      type: 'object',
      properties: [],
      definitions: [
        mdMetadata,
        mdIdentifier,
        topicCategory,
        obligationCode,
        ciContact,
        ciTelephone,
        durationType,
        constraintUnion,
      ],
      required: [],
      sourceJson: '{}',
    }],
    searchIndex: [],
  }
}

describe('SPA data completeness for complex schemas', () => {
  let store: ReturnType<typeof useSchemaStore>

  beforeEach(() => {
    setActivePinia(createPinia())
    store = useSchemaStore()
  })

  describe('backend data integrity', () => {
    const doc = buildComplexDoc()

    it('array properties have itemsRef resolved from items.$ref', () => {
      const mdMetadata = doc.schemas[0].definitions.find(d => d.name === 'MD_Metadata')!
      const identifiers = mdMetadata.properties.find(p => p.name === 'identifiers')!
      expect(identifiers.itemsRef).toBe('#/$defs/MD_Identifier')
      expect(identifiers.itemsType).toBe('object')
    })

    it('array properties with itemsRef show correct display type', () => {
      const mdMetadata = doc.schemas[0].definitions.find(d => d.name === 'MD_Metadata')!
      const identifiers = mdMetadata.properties.find(p => p.name === 'identifiers')!
      expect(displayType(identifiers)).toBe('array of MD_Identifier')
    })

    it('enum definitions carry their enum values', () => {
      const topicCat = doc.schemas[0].definitions.find(d => d.name === 'MD_TopicCategoryCode')!
      expect(topicCat.enum).toHaveLength(6)
      expect(topicCat.enum).toContain('farming')
      expect(topicCat.enum).toContain('elevation')
    })

    it('properties resolved from enum definitions carry enum values', () => {
      const mdMetadata = doc.schemas[0].definitions.find(d => d.name === 'MD_Metadata')!
      const topic = mdMetadata.properties.find(p => p.name === 'topicCategory')!
      expect(topic.enum).toHaveLength(6)
      expect(topic.ref).toBe('#/$defs/MD_TopicCategoryCode')
    })

    it('format and pattern on non-object definitions are preserved', () => {
      const duration = doc.schemas[0].definitions.find(d => d.name === 'DurationType')!
      expect(duration.format).toBe('duration')
      expect(duration.pattern).toBe('^P.*$')
    })

    it('minItems on array properties is preserved', () => {
      const mdMetadata = doc.schemas[0].definitions.find(d => d.name === 'MD_Metadata')!
      const contacts = mdMetadata.properties.find(p => p.name === 'contacts')!
      expect(contacts.minItems).toBe(1)
    })

    it('nested array itemsRef through definition chain', () => {
      const ciContact = doc.schemas[0].definitions.find(d => d.name === 'CI_Contact')!
      const phone = ciContact.properties.find(p => p.name === 'phone')!
      expect(phone.itemsRef).toBe('#/$defs/CI_Telephone')
    })

    it('hasOneOf flag on union definitions', () => {
      const constraint = doc.schemas[0].definitions.find(d => d.name === 'Abstract_ConstraintUnion')!
      expect(constraint.hasOneOf).toBe(true)
    })
  })

  describe('frontend rendering with store', () => {
    it('store loads complex document and resolves definitions', () => {
      window.SCHEMA_DATA = buildComplexDoc() as any
      store.loadFromWindow()

      const schemas = store.schemas
      expect(schemas).toHaveLength(1)
      expect(schemas[0].definitions).toHaveLength(8)
    })

    it('store normalizes $ref → ref on nested definition properties', () => {
      const doc = buildComplexDoc()
      // Simulate backend output where $ref is the JSON key
      const topicProp = doc.schemas[0].definitions[0].properties.find(p => p.name === 'topicCategory')!
      ;(topicProp as any).$ref = topicProp.ref
      delete topicProp.ref

      window.SCHEMA_DATA = doc as any
      store.loadFromWindow()

      const mdMetadata = store.schemas[0].definitions.find(d => d.name === 'MD_Metadata')!
      const topic = mdMetadata.properties.find(p => p.name === 'topicCategory')!
      expect(topic.ref).toBe('#/$defs/MD_TopicCategoryCode')
      expect((topic as any).$ref).toBeUndefined()
    })

    it('definition resolver finds enum definitions', () => {
      const s = schema({
        definitions: [
          definition({ name: 'MD_TopicCategoryCode', type: 'string', enum: ['farming', 'biota'] }),
        ],
      })
      const resolved = resolveSchemaRef('#/$defs/MD_TopicCategoryCode', s)
      expect(resolved).not.toBeNull()
      expect(resolved!.enum).toEqual(['farming', 'biota'])
    })
  })

  describe('type display for complex schema patterns', () => {
    it('refLabel extracts definition name from $defs path', () => {
      expect(refLabel('#/$defs/MD_Identifier')).toBe('MD_Identifier')
    })

    it('refLabel handles definitions path', () => {
      expect(refLabel('#/definitions/address')).toBe('address')
    })

    it('displayType for array with itemsRef', () => {
      expect(displayType(prop({ type: 'array', itemsRef: '#/$defs/MD_Identifier' }))).toBe('array of MD_Identifier')
    })

    it('prefers itemsRef label when itemsType is generic object', () => {
      expect(displayType(prop({ type: 'array', itemsType: 'object', itemsRef: '#/$defs/Foo' }))).toBe('array of Foo')
    })

    it('uses itemsType when it is a specific primitive type', () => {
      expect(displayType(prop({ type: 'array', itemsType: 'string', itemsRef: '#/$defs/Foo' }))).toBe('array of string')
    })

    it('displayType for array with itemsRef and constraints', () => {
      const p = prop({ type: 'array', itemsRef: '#/$defs/MD_Identifier', minItems: 1, maxItems: 10 })
      expect(displayType(p)).toBe('array of MD_Identifier [ 1 .. 10 ]')
    })

    it('displayType for nullable array with itemsRef', () => {
      expect(displayType(prop({ type: 'array,null', itemsRef: '#/$defs/Item' }))).toBe('array of Item | null')
    })

    it('displayType renders tuple items, preferring positions over itemsType', () => {
      const p = prop({ type: 'array', itemsType: 'any', itemsTuple: ['string', 'integer'], itemsClosed: true })
      expect(displayType(p)).toBe('array of [string, integer] (closed)')
    })

    it('displayType keeps an open tuple open', () => {
      const p = prop({ type: 'array', itemsTuple: ['string'] })
      expect(displayType(p)).toBe('array of [string]')
    })

    it('patternPropertyRows flattens a patternProperties map in order', () => {
      expect(patternPropertyRows({
        '^S_': { type: 'string' },
        '^I_': {},
      })).toEqual([
        { pattern: '^S_', type: 'string' },
        { pattern: '^I_', type: undefined },
      ])
    })

    it('patternPropertyRows tolerates an absent map', () => {
      expect(patternPropertyRows(undefined)).toEqual([])
    })

    it('conditionalSections builds If/Then/Else sections', () => {
      const schema = {
        name: 'demo',
        properties: [],
        definitions: [],
        required: [],
        ifSchema: prop({ properties: [prop({ name: 'kind', type: 'string' })] }),
        thenRequired: ['id'],
        thenProperties: [prop({ name: 'id', type: 'integer' })],
        elseProperties: [prop({ name: 'reason', type: 'string' })],
      } as SpaSchema

      expect(conditionalSections(schema)).toEqual([
        { label: 'If', rows: [{ name: 'kind', type: 'string' }], required: [] },
        { label: 'Then', rows: [{ name: 'id', type: 'integer' }], required: ['id'] },
        { label: 'Else', rows: [{ name: 'reason', type: 'string' }], required: [] },
      ])
    })

    it('conditionalSections is empty for unconditional schemas', () => {
      expect(conditionalSections({
        name: 'plain', properties: [], definitions: [], required: [],
      })).toEqual([])
    })

    it('variantOptions labels oneOf and anyOf members with their fields', () => {
      const options = variantOptions({
        oneOfVariants: [
          prop({ title: 'Date', type: 'string' }),
          prop({ type: 'integer' }),
        ],
        anyOfVariants: [
          prop({ title: 'Extended', properties: [prop({ name: 'id', type: 'string' })] }),
        ],
      })

      expect(options.map(o => [o.label, o.source])).toEqual([
        ['Date', 'oneOf'],
        ['integer', 'oneOf'],
        ['Extended', 'anyOf'],
      ])
      expect(options[2].fields).toEqual([{ name: 'id', type: 'string' }])
    })

    it('variantOptions is empty without variants', () => {
      expect(variantOptions(prop())).toEqual([])
    })

    it('variantOptions labels variants by discriminator mapping', () => {
      const options = variantOptions({
        oneOfVariants: [
          prop({ title: 'Cat title', type: 'object', ref: '#/$defs/Cat' }),
          prop({ type: 'object', ref: '#/$defs/Dog' }),
        ],
      }, { cat: '#/$defs/Cat', dog: '#/$defs/Dog' })

      expect(options.map(o => o.label)).toEqual(['cat', 'dog'])
    })

    it('diffSections groups changes by impact, most severe first', () => {
      const sections = diffSections([
        { schemaName: 's', pointer: '/properties/a', classification: 'cosmetic' },
        { schemaName: 's', pointer: '/properties/b', classification: 'breaking' },
        { schemaName: 's', pointer: '/properties/c', classification: 'additive' },
        { schemaName: 's', pointer: '/properties/d', classification: 'breaking' },
      ])

      expect(sections.map(s => s.label)).toEqual(['breaking', 'additive', 'cosmetic'])
      expect(sections[0].rows.map(r => r.pointer))
        .toEqual(['/properties/b', '/properties/d'])
    })

    it('enumRows pairs values with x-enumDescriptions entries', () => {
      expect(enumRows(['active', 'archived'], { active: 'Currently active' }))
        .toEqual([
          { value: 'active', description: 'Currently active' },
          { value: 'archived', description: undefined },
        ])
    })

    it('enumRows tolerates missing inputs', () => {
      expect(enumRows(undefined)).toEqual([])
    })

    it('displayType shows an open tuple tail', () => {
      const p = prop({ type: 'array', itemsTuple: ['string'], itemsTail: 'integer' })
      expect(displayType(p)).toBe('array of [string, *integer]')
    })
  })

  describe('builder field creation for complex properties', () => {
    it('creates field for array property with itemsRef', () => {
      const p = prop({ name: 'ids', type: 'array', itemsType: 'object', itemsRef: '#/$defs/MD_Identifier' })
      const s = schema({
        definitions: [definition({ name: 'MD_Identifier', type: 'object', properties: [prop({ name: 'code', type: 'string' })], required: [] })],
      })
      const field = createField(p, [], s)
      expect(field.arrayItems).toHaveLength(1)
      expect(field.resolvedDef).toBeNull()
    })

    it('creates field for property resolved from enum definition', () => {
      const p = prop({
        name: 'topic',
        ref: '#/$defs/MD_TopicCategoryCode',
        type: 'string',
        enum: ['farming', 'biota', 'boundaries'],
      })
      const s = schema({
        definitions: [definition({ name: 'MD_TopicCategoryCode', type: 'string', enum: ['farming', 'biota', 'boundaries'], properties: [], required: [] })],
      })
      const field = createField(p, [], s)
      // Enum property should have first enum as initial value
      expect(field.rawValue).toBe('farming')
    })

    it('buildDefaultJson handles array items with itemsRef', () => {
      const props = [
        prop({ name: 'tags', type: 'array', itemsType: 'string' }),
      ]
      const json = buildDefaultJson(props)
      expect(json.tags).toEqual([''])
    })
  })

  describe('constraint chips for complex definitions', () => {
    it('enum definition has constraints detected via property resolver', () => {
      const p = prop({
        name: 'topic',
        type: 'string',
        enum: ['farming', 'biota'],
        ref: '#/$defs/MD_TopicCategoryCode',
      })
      expect(hasConstraints(p)).toBe(true)
    })

    it('array with itemsRef and minItems has constraints', () => {
      const p = prop({ name: 'items', type: 'array', itemsRef: '#/$defs/X', minItems: 1 })
      expect(hasConstraints(p)).toBe(true)
    })
  })
})

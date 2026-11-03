import { describe, it, expect, beforeEach } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'
import { useSchemaStore } from '../schemaStore'
import type { SchemaData, Schema, Namespace } from '@/types'

const mockSchemaData: SchemaData = {
  metadata: {
    name: 'test-package',
    title: 'Test Package',
  },
  namespaces: [
    { prefix: 'tns', uri: '', schemas: ['biblio'] },
  ] as Namespace[],
  schemas: [
    {
      id: 'biblio',
      name: 'biblio',
      location: 'biblio.xsd',
      target_namespace: '',
      prefix: 'tns',
      namespace: '',
      is_entrypoint: true,
      elements: [
        { id: 'elem_uri', name: 'uri', type: 'TypedUri' },
        { id: 'elem_title', name: 'title', type: 'TypedTitleString' },
        { id: 'elem_date', name: 'date' },
      ] as any[],
      complex_types: [
        { id: 'ct_TypedUri', name: 'TypedUri', elements: [], attributes: [], choice: {} as any },
      ] as any[],
      simple_types: [] as any[],
      groups: [] as any[],
      attribute_groups: [] as any[],
      attributes: [] as any[],
      imports: [] as any[],
      includes: [] as any[],
    },
  ] as Schema[],
}

describe('schemaStore', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
  })

  it('loads schema data from window.SCHEMA_DATA', () => {
    ;(globalThis as any).window = {
      SCHEMA_DATA: mockSchemaData,
    }

    const store = useSchemaStore()
    store.loadFromWindow()

    expect(store.metadata?.name).toBe('test-package')
    expect(store.schemas.length).toBe(1)
    expect(store.namespaces.length).toBe(1)
  })

  it('contains uri element in the biblio schema', () => {
    ;(globalThis as any).window = {
      SCHEMA_DATA: mockSchemaData,
    }

    const store = useSchemaStore()
    store.loadFromWindow()

    const biblio = store.schemas.find(s => s.id === 'biblio')
    expect(biblio).toBeDefined()
    expect(biblio!.elements.length).toBe(3)

    const uri = biblio!.elements.find(e => e.name === 'uri')
    expect(uri).toBeDefined()
    expect(uri!.type).toBe('TypedUri')
  })

  it('computes schemaCounts with element count', () => {
    ;(globalThis as any).window = {
      SCHEMA_DATA: mockSchemaData,
    }

    const store = useSchemaStore()
    store.loadFromWindow()

    expect(store.schemaCounts.elements).toBe(3)
  })

  it('selects a type by id', () => {
    ;(globalThis as any).window = {
      SCHEMA_DATA: mockSchemaData,
    }

    const store = useSchemaStore()
    store.loadFromWindow()
    store.selectSchema('biblio')
    store.selectType('elem_uri')

    expect(store.selectedSchemaId).toBe('biblio')
    expect(store.selectedTypeId).toBe('elem_uri')

    const selected = store.selectedType
    expect(selected).not.toBeNull()
    expect(selected!.type).toBe('element')
    expect((selected!.data as any).name).toBe('uri')
  })
})

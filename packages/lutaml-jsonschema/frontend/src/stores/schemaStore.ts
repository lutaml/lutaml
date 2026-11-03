import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import type { SpaDocument, SpaSchema, SpaDefinition, SpaProperty } from '../types'

export type SelectedItem =
  | { kind: 'schema'; schema: SpaSchema }
  | { kind: 'definition'; schema: SpaSchema; definition: SpaDefinition }
  | { kind: 'property'; schema: SpaSchema; property: SpaProperty }

export const useSchemaStore = defineStore('schema', () => {
  const data = ref<SpaDocument | null>(null)
  const selectedSchemaName = ref<string | null>(null)
  const selectedItemKey = ref<string | null>(null)

  const metadata = computed(() => data.value?.metadata)
  const schemas = computed(() => data.value?.schemas ?? [])
  const searchIndex = computed(() => data.value?.searchIndex ?? [])
  const changes = computed(() => data.value?.diff ?? [])

  const selectedSchema = computed<SpaSchema | undefined>(() =>
    schemas.value.find(s => s.name === selectedSchemaName.value)
  )

  const selectedDefinitionName = computed<string | null>(() => {
    if (!selectedItemKey.value?.startsWith('def:')) return null
    return selectedItemKey.value.slice(4)
  })

  const selectedPropertyName = computed<string | null>(() => {
    if (!selectedItemKey.value?.startsWith('prop:')) return null
    return selectedItemKey.value.slice(5)
  })

  const selectedItem = computed<SelectedItem | null>(() => {
    const schema = selectedSchema.value
    if (!schema) return null
    if (!selectedItemKey.value) return { kind: 'schema', schema }

    if (selectedItemKey.value.startsWith('def:')) {
      const name = selectedItemKey.value.slice(4)
      const definition = schema.definitions.find(d => d.name === name)
      if (definition) return { kind: 'definition', schema, definition }
    }

    if (selectedItemKey.value.startsWith('prop:')) {
      const name = selectedItemKey.value.slice(5)
      const property = schema.properties.find(p => p.name === name)
      if (property) return { kind: 'property', schema, property }
    }

    return { kind: 'schema', schema }
  })

  const schemaCounts = computed(() => ({
    schemas: schemas.value.length,
    properties: schemas.value.reduce((acc, s) => acc + s.properties.length, 0),
    definitions: schemas.value.reduce((acc, s) => acc + s.definitions.length, 0),
  }))

  function loadFromWindow() {
    if (typeof window !== 'undefined' && window.SCHEMA_DATA) {
      const raw = window.SCHEMA_DATA
      // Normalize: ensure arrays are always arrays (backend may omit empty ones)
      for (const schema of raw.schemas) {
        schema.properties = schema.properties ?? []
        schema.definitions = schema.definitions ?? []
        schema.required = schema.required ?? []
        // Normalize: JSON key is "$ref" (Ruby maps it that way) but TypeScript uses "ref"
        for (const prop of schema.properties) {
          if (prop.$ref !== undefined) {
            prop.ref = prop.$ref
            delete prop.$ref
          }
        }
        for (const def of schema.definitions) {
          def.properties = def.properties ?? []
          def.required = def.required ?? []
          for (const prop of def.properties) {
            if (prop.$ref !== undefined) {
              prop.ref = prop.$ref
              delete prop.$ref
            }
          }
        }
      }
      raw.searchIndex = raw.searchIndex ?? []
      data.value = raw
    }
  }

  function selectSchema(name: string | null) {
    selectedSchemaName.value = name
    selectedItemKey.value = null
    updateHash()
  }

  function selectDefinition(name: string) {
    selectedItemKey.value = `def:${name}`
    updateHash()
  }

  function selectProperty(name: string) {
    selectedItemKey.value = `prop:${name}`
    updateHash()
  }

  function clearSelection() {
    selectedItemKey.value = null
  }

  function schemaByName(name: string): SpaSchema | undefined {
    return schemas.value.find(s => s.name === name)
  }

  function updateHash() {
    const schema = selectedSchemaName.value
    if (!schema) {
      history.replaceState(null, '', window.location.pathname)
      return
    }
    const key = selectedItemKey.value
    if (!key) {
      history.replaceState(null, '', `#${encodeURIComponent(schema)}`)
      return
    }
    let fragment = ''
    if (key.startsWith('def:')) {
      fragment = `def-${key.slice(4)}`
    } else if (key.startsWith('prop:')) {
      fragment = `prop-${key.slice(5)}`
    }
    history.replaceState(null, '', `#${encodeURIComponent(schema)}/${encodeURIComponent(fragment)}`)
  }

  return {
    data,
    selectedSchemaName,
    selectedItemKey,
    metadata,
    schemas,
    searchIndex,
    changes,
    selectedSchema,
    selectedDefinitionName,
    selectedPropertyName,
    selectedItem,
    schemaCounts,
    loadFromWindow,
    selectSchema,
    selectDefinition,
    selectProperty,
    clearSelection,
    schemaByName,
  }
})

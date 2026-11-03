import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import type { SchemaData, Schema, ComplexType, SimpleType, SchemaElement, GroupRef, AttributeGroup, SchemaAttribute, Namespace } from '@/types'

export const useSchemaStore = defineStore('schema', () => {
  // State
  const schemaData = ref<SchemaData | null>(null)
  const isLoading = ref(false)
  const error = ref<string | null>(null)
  const selectedSchemaId = ref<string | null>(null)
  const selectedTypeId = ref<string | null>(null)

  // Getters
  const schemas = computed(() => schemaData.value?.schemas ?? [])
  const namespaces = computed(() => schemaData.value?.namespaces ?? [])
  const metadata = computed(() => schemaData.value?.metadata)

  const selectedSchema = computed(() =>
    schemas.value.find(s => s.id === selectedSchemaId.value)
  )

  const selectedType = computed(() => {
    if (!selectedSchema.value || !selectedTypeId.value) return null
    const schema = selectedSchema.value

    const complex = schema.complex_types?.find(t => t.id === selectedTypeId.value)
    if (complex) return { type: 'complex' as const, data: complex, schema }

    const simple = schema.simple_types?.find(t => t.id === selectedTypeId.value)
    if (simple) return { type: 'simple' as const, data: simple, schema }

    const element = schema.elements?.find(t => t.id === selectedTypeId.value)
    if (element) return { type: 'element' as const, data: element, schema }

    const group = schema.groups?.find(t => t.id === selectedTypeId.value)
    if (group) return { type: 'group' as const, data: group, schema }

    const attrGroup = schema.attribute_groups?.find(t => t.id === selectedTypeId.value)
    if (attrGroup) return { type: 'attribute_group' as const, data: attrGroup, schema }

    const attr = schema.attributes?.find(t => t.id === selectedTypeId.value)
    if (attr) return { type: 'attribute' as const, data: attr, schema }

    return null
  })

  const schemaCounts = computed(() => ({
    total: schemas.value.length,
    types: schemas.value.reduce((acc, s) => acc + (s.complex_types?.length ?? 0) + (s.simple_types?.length ?? 0), 0),
    elements: schemas.value.reduce((acc, s) => acc + (s.elements?.length ?? 0), 0),
    groups: schemas.value.reduce((acc, s) => acc + (s.groups?.length ?? 0), 0),
    attributes: schemas.value.reduce((acc, s) => acc + (s.attributes?.length ?? 0), 0),
    attribute_groups: schemas.value.reduce((acc, s) => acc + (s.attribute_groups?.length ?? 0), 0)
  }))

  const allComplexTypes = computed(() =>
    schemas.value.flatMap(s =>
      (s.complex_types ?? []).map(t => ({ ...t, schemaName: s.name, schemaId: s.id }))
    )
  )

  const allSimpleTypes = computed(() =>
    schemas.value.flatMap(s =>
      (s.simple_types ?? []).map(t => ({ ...t, schemaName: s.name, schemaId: s.id }))
    )
  )

  const allElements = computed(() =>
    schemas.value.flatMap(s =>
      (s.elements ?? []).map(t => ({ ...t, schemaName: s.name, schemaId: s.id }))
    )
  )

  const allGroups = computed(() =>
    schemas.value.flatMap(s =>
      (s.groups ?? []).map(t => ({ ...t, schemaName: s.name, schemaId: s.id }))
    )
  )

  const allAttributeGroups = computed(() =>
    schemas.value.flatMap(s =>
      (s.attribute_groups ?? []).map(t => ({ ...t, schemaName: s.name, schemaId: s.id }))
    )
  )

  const allAttributes = computed(() =>
    schemas.value.flatMap(s =>
      (s.attributes ?? []).map(t => ({ ...t, schemaName: s.name, schemaId: s.id }))
    )
  )

  // Actions
  function loadFromWindow() {
    if (typeof window !== 'undefined' && window.SCHEMA_DATA) {
      schemaData.value = window.SCHEMA_DATA
      // No auto-select - show landing page by default
    }
  }

  function selectSchema(schemaId: string | null) {
    selectedSchemaId.value = schemaId
    selectedTypeId.value = null
  }

  function selectType(typeId: string) {
    selectedTypeId.value = typeId
  }

  function getSchemaById(id: string): Schema | undefined {
    return schemas.value.find(s => s.id === id)
  }

  function getNamespaceByPrefix(prefix: string): Namespace | undefined {
    return namespaces.value.find(n => n.prefix === prefix)
  }

  function getTypeById(typeId: string): { type: 'complex' | 'simple' | 'element' | 'group' | 'attribute_group' | 'attribute'; data: ComplexType | SimpleType | SchemaElement | GroupRef | AttributeGroup | SchemaAttribute; schema: Schema } | null {
    for (const schema of schemas.value) {
      const complex = schema.complex_types?.find(t => t.id === typeId)
      if (complex) return { type: 'complex', data: complex, schema }

      const simple = schema.simple_types?.find(t => t.id === typeId)
      if (simple) return { type: 'simple', data: simple, schema }

      const element = schema.elements?.find(t => t.id === typeId)
      if (element) return { type: 'element', data: element, schema }

      const group = schema.groups?.find(t => t.id === typeId)
      if (group) return { type: 'group', data: group, schema }

      const attrGroup = schema.attribute_groups?.find(t => t.id === typeId)
      if (attrGroup) return { type: 'attribute_group', data: attrGroup, schema }

      const attr = schema.attributes?.find(t => t.id === typeId)
      if (attr) return { type: 'attribute', data: attr, schema }
    }
    return null
  }

  // Search across all schemas by name (not id)
  function getTypeByName(name: string): { type: 'complex' | 'simple' | 'element' | 'group' | 'attribute_group' | 'attribute'; data: ComplexType | SimpleType | SchemaElement | GroupRef | AttributeGroup | SchemaAttribute; schema: Schema } | null {
    const cleanName = name.replace(/.*:/, '').replace(/\s/g, '')
    const lowerName = cleanName.toLowerCase()
    for (const schema of schemas.value) {
      const allTypes: { type: 'complex' | 'simple' | 'element' | 'group' | 'attribute_group' | 'attribute'; data: any; schema: Schema }[] = [
        ...(schema.complex_types || []).map(t => ({ type: 'complex' as const, data: t, schema })),
        ...(schema.simple_types || []).map(t => ({ type: 'simple' as const, data: t, schema })),
        ...(schema.elements || []).map(t => ({ type: 'element' as const, data: t, schema })),
        ...(schema.groups || []).map(t => ({ type: 'group' as const, data: t, schema })),
        ...(schema.attribute_groups || []).map(t => ({ type: 'attribute_group' as const, data: t, schema })),
      ]
      const found = allTypes.find(t => t.data.name?.toLowerCase() === lowerName)
      if (found) return found as any
    }
    return null
  }

  return {
    // State
    schemaData,
    isLoading,
    error,
    selectedSchemaId,
    selectedTypeId,
    // Getters
    schemas,
    namespaces,
    metadata,
    selectedSchema,
    selectedType,
    schemaCounts,
    allComplexTypes,
    allSimpleTypes,
    allElements,
    allGroups,
    allAttributeGroups,
    allAttributes,
    // Actions
    loadFromWindow,
    selectSchema,
    selectType,
    getSchemaById,
    getNamespaceByPrefix,
    getTypeById,
    getTypeByName
  }
})

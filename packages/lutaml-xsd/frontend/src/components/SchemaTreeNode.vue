<template>
  <div class="tree-node" :style="{ paddingLeft: `${depth * 16}px` }">
    <div
      class="tree-node-content"
      :class="{ selected: isSelected }"
      @click="handleClick"
    >
      <button
        v-if="hasChildren"
        class="tree-toggle"
        @click.stop="toggleExpanded"
      >
        <svg width="12" height="12" viewBox="0 0 12 12" fill="none" :class="{ expanded: isExpanded }">
          <path d="M4 3l3 3-3 3" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
        </svg>
      </button>
      <span v-else class="tree-toggle-placeholder"></span>

      <span class="tree-icon">
        <svg v-if="hasChildren" width="14" height="14" viewBox="0 0 14 14" fill="none">
          <rect x="2" y="2" width="10" height="10" rx="1.5" stroke="currentColor" stroke-width="1.2"/>
          <path d="M2 5h10" stroke="currentColor" stroke-width="1.2"/>
        </svg>
        <svg v-else width="14" height="14" viewBox="0 0 14 14" fill="none">
          <rect x="2" y="3" width="10" height="8" rx="1.5" stroke="currentColor" stroke-width="1.2"/>
          <path d="M5 3V2a2 2 0 014 0v1" stroke="currentColor" stroke-width="1.2"/>
        </svg>
      </span>

      <span class="tree-label" :title="schema.file_path || schema.name">{{ schema.name }}</span>

      <span class="tree-count" v-if="schema.complex_types?.length">
        {{ schema.complex_types.length }}
      </span>
    </div>

    <div v-if="isExpanded && hasChildren" class="tree-children">
      <!-- Types -->
      <div
        v-if="schema.complex_types?.length"
        class="tree-group"
      >
        <div class="tree-group-header" @click="toggleTypesExpanded">
          <svg width="12" height="12" viewBox="0 0 12 12" fill="none" :class="{ expanded: typesExpanded }">
            <path d="M4 3l3 3-3 3" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
          </svg>
          <span>Types</span>
          <span class="tree-count">{{ schema.complex_types.length + (schema.simple_types?.length || 0) }}</span>
        </div>
        <div v-if="typesExpanded" class="tree-group-items">
          <div
            v-for="type in schema.complex_types"
            :key="type.id"
            class="tree-item"
            :class="{ selected: schemaStore.selectedTypeId === type.id }"
            :ref="el => setTypeRef(type.id, el as HTMLElement)"
            @click="selectType(type.id)"
          >
            <span class="tree-item-icon">
              <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
                <rect x="1" y="1" width="10" height="10" rx="1.5" stroke="currentColor" stroke-width="1.2" stroke-dasharray="2 1"/>
              </svg>
            </span>
            <span class="badge badge-complex">C</span>
            <span class="tree-item-label">{{ type.name }}</span>
          </div>
          <div
            v-for="type in schema.simple_types"
            :key="type.id"
            class="tree-item"
            :class="{ selected: schemaStore.selectedTypeId === type.id }"
            :ref="el => setTypeRef(type.id, el as HTMLElement)"
            @click="selectType(type.id)"
          >
            <span class="tree-item-icon">
              <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
                <path d="M2 6h8M6 2v8" stroke="currentColor" stroke-width="1.2" stroke-linecap="round"/>
              </svg>
            </span>
            <span class="badge badge-simple">S</span>
            <span class="tree-item-label">{{ type.name }}</span>
          </div>
        </div>
      </div>

      <!-- Elements -->
      <div
        v-if="schema.elements?.length"
        class="tree-group"
      >
        <div class="tree-group-header" @click="toggleElementsExpanded">
          <svg width="12" height="12" viewBox="0 0 12 12" fill="none" :class="{ expanded: elementsExpanded }">
            <path d="M4 3l3 3-3 3" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
          </svg>
          <span>Elements</span>
          <span class="tree-count">{{ schema.elements.length }}</span>
        </div>
        <div v-if="elementsExpanded" class="tree-group-items">
          <div
            v-for="element in schema.elements"
            :key="element.id"
            class="tree-item"
            :class="{ selected: schemaStore.selectedTypeId === element.id }"
            :ref="el => setElementRef(element.id, el as HTMLElement)"
            @click="selectType(element.id)"
          >
            <span class="tree-item-icon">
              <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
                <path d="M3 2h6v8H3z" stroke="currentColor" stroke-width="1.2"/>
              </svg>
            </span>
            <span class="badge badge-element">E</span>
            <span class="tree-item-label">{{ element.name }}</span>
          </div>
        </div>
      </div>

      <!-- Groups -->
      <div
        v-if="schema.groups?.length"
        class="tree-group"
      >
        <div class="tree-group-header" @click="toggleGroupsExpanded">
          <svg width="12" height="12" viewBox="0 0 12 12" fill="none" :class="{ expanded: groupsExpanded }">
            <path d="M4 3l3 3-3 3" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
          </svg>
          <span>Groups</span>
          <span class="tree-count">{{ schema.groups.length }}</span>
        </div>
        <div v-if="groupsExpanded" class="tree-group-items">
          <div
            v-for="group in schema.groups"
            :key="group.id"
            class="tree-item"
            :class="{ selected: schemaStore.selectedTypeId === group.id }"
            :ref="el => setGroupRef(group.id, el as HTMLElement)"
            @click="selectType(group.id)"
          >
            <span class="tree-item-icon">
              <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
                <rect x="2" y="2" width="8" height="8" rx="1" stroke="currentColor" stroke-width="1.2"/>
                <path d="M5 5h2v2H5z" stroke="currentColor" stroke-width="0.8"/>
              </svg>
            </span>
            <span class="badge badge-group">G</span>
            <span class="tree-item-label">{{ group.name }}</span>
          </div>
        </div>
      </div>

      <!-- Attribute Groups -->
      <div
        v-if="schema.attribute_groups?.length"
        class="tree-group"
      >
        <div class="tree-group-header" @click="toggleAttrGroupsExpanded">
          <svg width="12" height="12" viewBox="0 0 12 12" fill="none" :class="{ expanded: attrGroupsExpanded }">
            <path d="M4 3l3 3-3 3" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
          </svg>
          <span>Attribute Groups</span>
          <span class="tree-count">{{ schema.attribute_groups.length }}</span>
        </div>
        <div v-if="attrGroupsExpanded" class="tree-group-items">
          <div
            v-for="ag in schema.attribute_groups"
            :key="ag.id"
            class="tree-item"
            :class="{ selected: schemaStore.selectedTypeId === ag.id }"
            :ref="el => setAttrGroupRef(ag.id, el as HTMLElement)"
            @click="selectType(ag.id)"
          >
            <span class="tree-item-icon">
              <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
                <rect x="2" y="2" width="8" height="8" rx="1" stroke="currentColor" stroke-width="1.2" stroke-dasharray="2 1"/>
              </svg>
            </span>
            <span class="badge badge-attrgroup">AG</span>
            <span class="tree-item-label">{{ ag.name }}</span>
          </div>
        </div>
      </div>

      <!-- Attributes -->
      <div
        v-if="schema.attributes?.length"
        class="tree-group"
      >
        <div class="tree-group-header" @click="toggleAttributesExpanded">
          <svg width="12" height="12" viewBox="0 0 12 12" fill="none" :class="{ expanded: attributesExpanded }">
            <path d="M4 3l3 3-3 3" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
          </svg>
          <span>Attributes</span>
          <span class="tree-count">{{ schema.attributes.length }}</span>
        </div>
        <div v-if="attributesExpanded" class="tree-group-items">
          <div
            v-for="attr in schema.attributes"
            :key="attr.id"
            class="tree-item"
            :class="{ selected: schemaStore.selectedTypeId === attr.id }"
            :ref="el => setAttributeRef(attr.id, el as HTMLElement)"
            @click="selectType(attr.id)"
          >
            <span class="tree-item-icon">
              <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
                <path d="M3 6h6" stroke="currentColor" stroke-width="1.2" stroke-linecap="round"/>
              </svg>
            </span>
            <span class="badge badge-attribute">A</span>
            <span class="tree-item-label">{{ attr.name }}</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch, nextTick } from 'vue'
import type { Schema } from '@/types'
import { useSchemaStore } from '@/stores/schemaStore'
import { useUiStore } from '@/stores/uiStore'

const props = defineProps<{
  schema: Schema
  depth: number
}>()

const schemaStore = useSchemaStore()
const uiStore = useUiStore()

const isExpanded = computed(() => uiStore.isSchemaExpanded(props.schema.id))
const typesExpanded = ref(false)
const elementsExpanded = ref(false)
const groupsExpanded = ref(false)
const attrGroupsExpanded = ref(false)
const attributesExpanded = ref(false)

// Refs for scrolling to selected items
const typeItemsRefs = ref<Record<string, HTMLElement | null>>({})
const elementItemsRefs = ref<Record<string, HTMLElement | null>>({})
const groupItemsRefs = ref<Record<string, HTMLElement | null>>({})
const attrGroupItemsRefs = ref<Record<string, HTMLElement | null>>({})
const attributeItemsRefs = ref<Record<string, HTMLElement | null>>({})

// Auto-expand the group containing the selected type when it changes
watch(() => schemaStore.selectedTypeId, (newTypeId) => {
  if (!newTypeId || schemaStore.selectedSchemaId !== props.schema.id) return

  // Check which group contains the selected type
  const allComplex = props.schema.complex_types || []
  const allSimple = props.schema.simple_types || []
  const allElements = props.schema.elements || []
  const allGroups = props.schema.groups || []
  const allAttrGroups = props.schema.attribute_groups || []
  const allAttributes = props.schema.attributes || []

  let targetGroup: 'types' | 'elements' | 'groups' | 'attrGroups' | 'attributes' | null = null
  let itemRefs: typeof typeItemsRefs | null = null
  let itemId: string | null = null

  if (allComplex.find(t => t.id === newTypeId) || allSimple.find(t => t.id === newTypeId)) {
    targetGroup = 'types'
    itemRefs = typeItemsRefs
    itemId = newTypeId
  } else if (allElements.find(e => e.id === newTypeId)) {
    targetGroup = 'elements'
    itemRefs = elementItemsRefs
    itemId = newTypeId
  } else if (allGroups.find(g => g.id === newTypeId)) {
    targetGroup = 'groups'
    itemRefs = groupItemsRefs
    itemId = newTypeId
  } else if (allAttrGroups.find(ag => ag.id === newTypeId)) {
    targetGroup = 'attrGroups'
    itemRefs = attrGroupItemsRefs
    itemId = newTypeId
  } else if (allAttributes.find(a => a.id === newTypeId)) {
    targetGroup = 'attributes'
    itemRefs = attributeItemsRefs
    itemId = newTypeId
  }

  if (targetGroup && itemRefs && itemId) {
    // Expand the schema tree first
    if (!isExpanded.value) {
      uiStore.toggleSchemaExpanded(props.schema.id)
    }
    // Expand the group
    switch (targetGroup) {
      case 'types': typesExpanded.value = true; break
      case 'elements': elementsExpanded.value = true; break
      case 'groups': groupsExpanded.value = true; break
      case 'attrGroups': attrGroupsExpanded.value = true; break
      case 'attributes': attributesExpanded.value = true; break
    }
    // Scroll to the item after DOM updates
    nextTick(() => {
      const el = itemRefs.value[itemId]
      if (el) {
        el.scrollIntoView({ behavior: 'smooth', block: 'nearest' })
      }
    })
  }
}, { immediate: true })

const hasChildren = computed(() =>
  (props.schema.complex_types?.length || 0) + (props.schema.simple_types?.length || 0) + (props.schema.elements?.length || 0) + (props.schema.groups?.length || 0) + (props.schema.attribute_groups?.length || 0) + (props.schema.attributes?.length || 0) > 0
)

const isSelected = computed(() => schemaStore.selectedSchemaId === props.schema.id)

function toggleExpanded() {
  uiStore.toggleSchemaExpanded(props.schema.id)
}

function toggleTypesExpanded() {
  typesExpanded.value = !typesExpanded.value
}

function toggleElementsExpanded() {
  elementsExpanded.value = !elementsExpanded.value
}

function toggleGroupsExpanded() {
  groupsExpanded.value = !groupsExpanded.value
}

function toggleAttrGroupsExpanded() {
  attrGroupsExpanded.value = !attrGroupsExpanded.value
}

function toggleAttributesExpanded() {
  attributesExpanded.value = !attributesExpanded.value
}

function handleClick() {
  schemaStore.selectSchema(props.schema.id)
  if (hasChildren.value) {
    uiStore.toggleSchemaExpanded(props.schema.id)
  }
  if (!hasChildren.value) {
    uiStore.openDetailPanel()
  }
}

function selectType(typeId: string) {
  schemaStore.selectSchema(props.schema.id)
  schemaStore.selectType(typeId)
  uiStore.openDetailPanel()
}

function setTypeRef(id: string, el: HTMLElement | null) {
  typeItemsRefs.value[id] = el
}

function setElementRef(id: string, el: HTMLElement | null) {
  elementItemsRefs.value[id] = el
}

function setGroupRef(id: string, el: HTMLElement | null) {
  groupItemsRefs.value[id] = el
}

function setAttrGroupRef(id: string, el: HTMLElement | null) {
  attrGroupItemsRefs.value[id] = el
}

function setAttributeRef(id: string, el: HTMLElement | null) {
  attributeItemsRefs.value[id] = el
}
</script>

<style scoped>
.tree-node {
  user-select: none;
}

.tree-node-content {
  display: flex;
  align-items: center;
  gap: var(--space-1);
  padding: var(--space-1) var(--space-2);
  border-radius: var(--radius-sm);
  cursor: pointer;
  transition: background var(--transition-fast);
}

.tree-node-content:hover {
  background: var(--bg-hover);
}

.tree-node-content.selected {
  background: var(--color-primary-alpha);
  color: var(--color-primary);
}

.tree-toggle {
  width: 16px;
  height: 16px;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 0;
  color: var(--text-muted);
  transition: transform var(--transition-fast);
}

.tree-toggle svg.expanded {
  transform: rotate(90deg);
}

.tree-toggle-placeholder {
  width: 16px;
}

.tree-icon {
  color: var(--text-muted);
  display: flex;
  align-items: center;
}

.tree-label {
  flex: 1;
  font-size: var(--text-sm);
  font-weight: 500;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.tree-count {
  font-size: var(--text-xs);
  color: var(--text-muted);
  background: var(--bg-primary);
  padding: 1px 5px;
  border-radius: var(--radius-sm);
}

.tree-children {
  margin-top: var(--space-1);
  padding-left: var(--space-4);
}

.tree-group {
  margin-bottom: var(--space-1);
}

.tree-group-header {
  display: flex;
  align-items: center;
  gap: var(--space-1);
  padding: var(--space-1) var(--space-2);
  font-size: var(--text-xs);
  font-weight: 500;
  color: var(--text-muted);
  cursor: pointer;
  transition: color var(--transition-fast);
}

.tree-group-header:hover {
  color: var(--text-secondary);
}

.tree-group-header svg {
  transition: transform var(--transition-fast);
}

.tree-group-header svg.expanded {
  transform: rotate(90deg);
}

.tree-group-items {
  margin-top: var(--space-1);
}

.tree-item {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  padding: var(--space-1) var(--space-2);
  padding-left: calc(var(--space-2) + 24px);
  border-radius: var(--radius-sm);
  cursor: pointer;
  transition: background var(--transition-fast);
}

.tree-item:hover {
  background: var(--bg-hover);
}

.tree-item.selected {
  background: var(--color-primary-alpha);
}

.tree-item-icon {
  color: var(--text-muted);
  display: flex;
  align-items: center;
}

.tree-item-label {
  flex: 1;
  font-size: var(--text-sm);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.badge {
  font-size: 9px;
  padding: 1px 4px;
}

.badge-group {
  background: var(--color-warning-alpha, rgba(245, 158, 11, 0.15));
  color: var(--color-warning, #f59e0b);
}

.badge-attrgroup {
  background: var(--color-info-alpha, rgba(59, 130, 246, 0.15));
  color: var(--color-info, #3b82f6);
}

.badge-attribute {
  background: var(--color-success-alpha, rgba(16, 185, 129, 0.15));
  color: var(--color-success, #10b981);
}
</style>

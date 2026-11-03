<template>
  <div class="schema-view">
    <div v-if="schema" class="schema-content">
      <div class="schema-header">
        <h1>{{ schema.name }}</h1>
        <div class="schema-actions">
          <button class="btn btn-secondary" @click="uiStore.openDetailPanel">
            View Details
          </button>
        </div>
      </div>

      <div class="schema-tabs">
        <button
          v-for="tab in tabs"
          :key="tab.id"
          class="tab-btn"
          :class="{ active: activeTab === tab.id }"
          @click="activeTab = tab.id"
        >
          {{ tab.label }}
          <span class="tab-count">{{ tab.count }}</span>
        </button>
      </div>

      <div class="tab-content">
        <!-- Types Tab -->
        <div v-if="activeTab === 'types'" class="types-grid">
          <div
            v-for="type in allTypes"
            :key="type.id"
            class="type-card card"
            @click="selectType(type)"
          >
            <div class="type-card-header">
              <span :class="['badge', type.type === 'complex' ? 'badge-complex' : 'badge-simple']">
                {{ type.type === 'complex' ? 'Complex' : 'Simple' }}
              </span>
            </div>
            <h3 class="type-name">{{ type.name }}</h3>
            <p v-if="type.base" class="type-base">Base: {{ type.base }}</p>
          </div>
        </div>

        <!-- Elements Tab -->
        <div v-if="activeTab === 'elements'" class="elements-list">
          <div
            v-for="element in schema.elements"
            :key="element.id"
            class="element-row"
            @click="selectElement(element)"
          >
            <span class="badge badge-element">E</span>
            <span class="element-name">{{ element.name }}</span>
            <span class="element-type">{{ element.type || 'xs:anyType' }}</span>
          </div>
        </div>

        <!-- Attributes Tab -->
        <div v-if="activeTab === 'attributes'" class="elements-list">
          <div
            v-for="attr in schema.attributes"
            :key="attr.id"
            class="element-row"
            @click="selectElement(attr)"
          >
            <span class="badge badge-attribute">A</span>
            <span class="element-name">{{ attr.name }}</span>
            <span class="element-type">{{ attr.type || '' }}</span>
            <span v-if="attr.use" class="element-type">{{ attr.use }}</span>
          </div>
          <div v-if="!schema.attributes?.length" class="empty-state">No attributes</div>
        </div>
      </div>
    </div>

    <div v-else class="not-found">
      <h2>Schema Not Found</h2>
      <p>The requested schema could not be found.</p>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { useSchemaStore } from '@/stores/schemaStore'
import { useUiStore } from '@/stores/uiStore'
import type { ComplexType, SimpleType, SchemaElement } from '@/types'

const props = defineProps<{ id: string }>()

const schemaStore = useSchemaStore()
const uiStore = useUiStore()

const activeTab = ref<'types' | 'elements' | 'attributes'>('types')

const schema = computed(() => schemaStore.getSchemaById(props.id))

const tabs = computed(() => [
  { id: 'types' as const, label: 'Types', count: allTypes.value.length },
  { id: 'elements' as const, label: 'Elements', count: schema.value?.elements?.length || 0 },
  { id: 'attributes' as const, label: 'Attributes', count: schema.value?.attributes?.length || 0 }
])

const allTypes = computed(() => {
  if (!schema.value) return []
  const complex = (schema.value.complex_types || []).map(t => ({ ...t, type: 'complex' as const }))
  const simple = (schema.value.simple_types || []).map(t => ({ ...t, type: 'simple' as const }))
  return [...complex, ...simple]
})

function selectType(type: (ComplexType | SimpleType) & { type: 'complex' | 'simple' }) {
  schemaStore.selectSchema(props.id)
  schemaStore.selectType(type.id)
  uiStore.openDetailPanel()
}

function selectElement(element: SchemaElement) {
  schemaStore.selectSchema(props.id)
  schemaStore.selectType(element.id)
  uiStore.openDetailPanel()
}
</script>

<style scoped>
.schema-view {
  max-width: 1200px;
  margin: 0 auto;
}

.schema-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: var(--space-6);
}

.schema-header h1 {
  font-size: var(--text-2xl);
}

.schema-tabs {
  display: flex;
  gap: var(--space-1);
  margin-bottom: var(--space-4);
  border-bottom: 1px solid var(--border-light);
  padding-bottom: var(--space-2);
}

.tab-btn {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  padding: var(--space-2) var(--space-3);
  font-size: var(--text-sm);
  font-weight: 500;
  color: var(--text-muted);
  border-radius: var(--radius-md);
  transition: all var(--transition-fast);
}

.tab-btn:hover {
  color: var(--text-primary);
  background: var(--bg-hover);
}

.tab-btn.active {
  color: var(--color-primary);
  background: var(--color-primary-alpha);
}

.tab-count {
  font-size: var(--text-xs);
  background: var(--bg-secondary);
  padding: 1px 6px;
  border-radius: var(--radius-sm);
}

.types-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: var(--space-4);
}

.type-card {
  padding: var(--space-4);
  cursor: pointer;
  transition: all var(--transition-fast);
}

.type-card:hover {
  border-color: var(--color-primary);
  box-shadow: var(--shadow-md);
}

.type-card-header {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  margin-bottom: var(--space-2);
}

.type-name {
  font-size: var(--text-base);
  font-weight: 600;
  margin-bottom: var(--space-1);
}

.type-base {
  font-size: var(--text-sm);
  color: var(--text-muted);
}

.elements-list {
  display: flex;
  flex-direction: column;
  gap: var(--space-2);
}

.element-row {
  display: flex;
  align-items: center;
  gap: var(--space-3);
  padding: var(--space-3);
  background: var(--bg-elevated);
  border: 1px solid var(--border-light);
  border-radius: var(--radius-md);
  cursor: pointer;
  transition: all var(--transition-fast);
}

.element-row:hover {
  border-color: var(--color-primary);
  background: var(--color-primary-alpha);
}

.element-name {
  font-weight: 500;
  min-width: 150px;
}

.element-type {
  color: var(--color-primary);
  flex: 1;
}

.not-found {
  text-align: center;
  padding: var(--space-12);
  color: var(--text-muted);
}

.badge-attribute {
  background: rgba(16, 185, 129, 0.15);
  color: #10b981;
  font-size: 9px;
  padding: 1px 4px;
  border-radius: var(--radius-sm);
}

.empty-state {
  text-align: center;
  padding: var(--space-8);
  color: var(--text-muted);
}
</style>

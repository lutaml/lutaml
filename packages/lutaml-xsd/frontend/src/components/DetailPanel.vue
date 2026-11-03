<template>
  <div class="detail-panel-overlay" @click.self="uiStore.closeDetailPanel">
    <aside class="detail-panel">
      <div class="panel-header">
        <div class="panel-title">
          <h2 v-if="selectedType">{{ selectedType.data.name }}</h2>
          <h2 v-else-if="schemaStore.selectedSchema">{{ schemaStore.selectedSchema.name }}</h2>
        </div>
        <button class="btn btn-ghost" @click="uiStore.closeDetailPanel">
          <svg width="18" height="18" viewBox="0 0 18 18" fill="none">
            <path d="M5 5l8 8M13 5l-8 8" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>
          </svg>
        </button>
      </div>

      <div class="panel-tabs" v-if="selectedType">
        <button
          v-for="tab in typeTabs"
          :key="tab.id"
          class="panel-tab"
          :class="{ active: uiStore.activePanelTab === tab.id }"
          @click="uiStore.setPanelTab(tab.id)"
        >
          {{ tab.label }}
        </button>
      </div>

      <div class="panel-content">
        <template v-if="selectedType">
          <TypeOverview v-if="uiStore.activePanelTab === 'overview'" :type="selectedType" />
          <TypeDefinition v-else-if="uiStore.activePanelTab === 'definition'" :type="selectedType" />
          <SourceView v-else-if="uiStore.activePanelTab === 'source'" :type="selectedType" />
          <DiagramView v-else-if="uiStore.activePanelTab === 'diagram'" :svg="diagramSvg" />
        </template>
        <template v-else-if="schemaStore.selectedSchema">
          <SchemaOverview :schema="schemaStore.selectedSchema" />
        </template>
        <div v-else class="panel-empty">
          <p>Select a type to view details</p>
        </div>
      </div>
    </aside>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useSchemaStore } from '@/stores/schemaStore'
import { useUiStore } from '@/stores/uiStore'
import TypeOverview from '@/components/TypeOverview.vue'
import TypeDefinition from '@/components/TypeDefinition.vue'
import DiagramView from '@/components/DiagramView.vue'
import SchemaOverview from '@/components/SchemaOverview.vue'
import SourceView from '@/components/SourceView.vue'
import type { ComplexType, SimpleType, SchemaElement, GroupRef, AttributeGroup, SchemaAttribute } from '@/types'

const schemaStore = useSchemaStore()
const uiStore = useUiStore()

type TypeData = {
  type: 'complex' | 'simple' | 'element' | 'group' | 'attribute_group' | 'attribute'
  data: ComplexType | SimpleType | SchemaElement | GroupRef | AttributeGroup | SchemaAttribute
  schema: { id: string; name: string; prefix?: string }
}

const selectedType = computed<TypeData | null>(() => schemaStore.selectedType as TypeData | null)

const hasDiagram = computed(() => {
  if (!selectedType.value) return false
  return !!(selectedType.value.data as any).diagram_svg
})

const diagramSvg = computed(() => {
  if (!selectedType.value) return ''
  return (selectedType.value.data as any).diagram_svg || ''
})

type PanelTabId = 'overview' | 'definition' | 'source' | 'diagram'

const typeTabs = computed(() => {
  const tabs: { id: PanelTabId; label: string }[] = [
    { id: 'overview', label: 'Overview' },
    { id: 'definition', label: 'Definition' },
    { id: 'source', label: 'Source' }
  ]
  if (hasDiagram.value) {
    tabs.push({ id: 'diagram', label: 'Diagram' })
  }
  return tabs
})
</script>

<style scoped>
.detail-panel-overlay {
  position: fixed;
  inset: 0;
  background: var(--bg-overlay);
  display: flex;
  justify-content: flex-end;
  z-index: 100;
  animation: fadeIn var(--transition-fast);
}

.detail-panel {
  width: 100%;
  max-width: 640px;
  height: 100%;
  background: var(--bg-elevated);
  box-shadow: var(--shadow-lg);
  display: flex;
  flex-direction: column;
  animation: slideIn var(--transition-slow);
}

.panel-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: var(--space-4) var(--space-5);
  border-bottom: 1px solid var(--border-light);
  flex-shrink: 0;
}

.panel-title h2 {
  font-size: var(--text-lg);
  font-weight: 600;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.panel-tabs {
  display: flex;
  gap: var(--space-1);
  padding: var(--space-2) var(--space-5);
  border-bottom: 1px solid var(--border-light);
  flex-shrink: 0;
}

.panel-tab {
  padding: var(--space-2) var(--space-3);
  font-size: var(--text-sm);
  font-weight: 500;
  color: var(--text-muted);
  border-radius: var(--radius-md);
  transition: all var(--transition-fast);
}

.panel-tab:hover {
  color: var(--text-primary);
  background: var(--bg-hover);
}

.panel-tab.active {
  color: var(--color-primary);
  background: var(--color-primary-alpha);
}

.panel-content {
  flex: 1;
  overflow-y: auto;
  padding: var(--space-5);
}

.panel-empty {
  display: flex;
  align-items: center;
  justify-content: center;
  height: 100%;
  color: var(--text-muted);
  font-size: var(--text-sm);
}
</style>

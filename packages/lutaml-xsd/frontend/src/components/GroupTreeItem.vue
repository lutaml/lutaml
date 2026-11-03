<template>
  <div class="group-tree-item">
    <div class="group-node" :style="{ paddingLeft: `${depth * 16}px` }">
      <span v-if="hasNestedContent" class="expand-icon" @click="toggleExpanded">
        {{ isExpanded ? '▾' : '▸' }}
      </span>
      <span v-else class="expand-icon-placeholder"></span>
      
      <span v-if="group.ref" class="type-link" @click="navigateToGroup">
        {{ group.ref }}
      </span>
      <span v-else class="group-name">{{ group.name || 'anonymous' }}</span>
      
      <span v-if="group.occurs" class="group-occurs">
        {{ formatOccurs(group.occurs) }}
      </span>
      
      <span v-if="hasNestedContent" class="group-badge">
        {{ group.choice ? 'choice' : group.sequence ? 'sequence' : 'group' }}
      </span>
    </div>
    
    <div v-if="isExpanded && hasNestedContent" class="group-children">
      <!-- Render nested choice -->
      <template v-if="group.choice">
        <div class="nested-header" :style="{ paddingLeft: `${(depth + 1) * 16}px` }">
          <span class="nested-label">⟨choice⟩</span>
          <span v-if="group.choice.occurs" class="group-occurs">{{ formatOccurs(group.choice.occurs) }}</span>
        </div>
        <GroupTreeItem 
          v-for="(childGroup, idx) in (group.choice.groups || [])" 
          :key="`c-${idx}`"
          :group="childGroup"
          :depth="depth + 2"
        />
        <div v-if="group.choice.choices && group.choice.choices.length > 0" class="nested-header" :style="{ paddingLeft: `${(depth + 1) * 16}px` }">
          <span class="nested-label">⟨choice option⟩</span>
          <ul>
            <li v-for="(option, idx) in group.choice.choices" :key="`o-${idx}`">
              <span class="group-occurs">{{ formatOccurs(option.occurs) }}</span>
              <GroupTreeItem 
                v-for="(childGroup, cidx) in (option.groups || [])" 
                :key="`o-${idx}-g-${cidx}`"
                :group="childGroup"
                :depth="depth + 3"
              />
              <div class="group-tree-item">
                <div
                  class="group-node"
                  v-for="(childElement, eidx) in (option.elements || [])" 
                  :key="`o-${idx}-g-${eidx}`"
                  :group="childElement"
                  :depth="depth + 3"
                  :style="{ paddingLeft: `${(depth + 3) * 16}px` }">
                  <span class="expand-icon-placeholder"></span>
                  <span>{{ childElement.reference || childElement.name }}</span>
                    <span class="group-occurs">{{ formatOccurs(childElement.occurs) }}</span>
                </div>
              </div>
            </li>
          </ul>
        </div>
      </template>
      
      <!-- Render nested sequence -->
      <template v-if="group.sequence">
        <div class="nested-header" :style="{ paddingLeft: `${(depth + 1) * 16}px` }">
          <span class="nested-label">[sequence]</span>
          <span v-if="group.sequence.occurs" class="group-occurs">{{ formatOccurs(group.sequence.occurs) }}</span>
        </div>
        <GroupTreeItem 
          v-for="(childGroup, idx) in (group.sequence.groups || [])" 
          :key="`s-${idx}`"
          :group="childGroup"
          :depth="depth + 2"
        />
      </template>

      <!-- Render sequence elements -->
      <template v-if="group.sequence && group.sequence.elements.length > 0">
        <div class="nested-header" :style="{ paddingLeft: `${(depth + 1) * 16}px` }">
          <span class="nested-label">⟨elements⟩</span>
        </div>
        <ElementTreeItem 
          v-for="(childElement, idx) in group.sequence.elements" 
          :key="`e-${idx}`"
          :element="childElement"
          :depth="depth + 2"
        />
      </template>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import type { GroupRef } from '@/types'
import { useSchemaStore } from '@/stores/schemaStore'
import { useUiStore } from '@/stores/uiStore'
import ElementTreeItem from './ElementTreeItem.vue'

const props = withDefaults(defineProps<{
  group: GroupRef
  depth?: number
}>(), {
  depth: 0
})

const schemaStore = useSchemaStore()
const uiStore = useUiStore()

const isExpanded = ref(props.depth === 0)

const hasNestedContent = computed(() => {
  const g = props.group
  return !!(g.choice || g.sequence)
})

function toggleExpanded() {
  isExpanded.value = !isExpanded.value
}

function navigateToGroup() {
  if (!props.group.ref) return
  
  const found = schemaStore.getTypeByName(props.group.ref)
  if (found) {
    schemaStore.selectSchema(found.schema.id)
    schemaStore.selectType(found.data.id)
    uiStore.setPanelTab('overview')
    uiStore.openDetailPanel()
  }
}

function formatOccurs(occurs?: { min: number; max?: number | 'unbounded' }): string {
  if (!occurs) return ''
  if (occurs.max === undefined || occurs.max === 'unbounded') {
    return occurs.min === 0 ? '[0..*]' : `[${occurs.min}..*]`
  }
  if (occurs.min === occurs.max) return `[${occurs.min}..${occurs.max}]`
  return `[${occurs.min}..${occurs.max}]`
}
</script>

<style scoped>
.group-tree-item {
  font-size: var(--text-sm);
}

.group-node {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  padding: var(--space-1) var(--space-2);
  border-radius: var(--radius-sm);
  transition: background-color 0.15s;
}

.group-node:hover {
  background: var(--bg-secondary);
}

.expand-icon {
  width: 16px;
  cursor: pointer;
  color: var(--text-muted);
  font-size: 10px;
  user-select: none;
}

.expand-icon:hover {
  color: var(--color-primary);
}

.expand-icon-placeholder {
  width: 16px;
}

.type-link {
  color: var(--color-primary);
  cursor: pointer;
  font-weight: 500;
}

.type-link:hover {
  text-decoration: underline;
}

.group-name {
  font-style: italic;
  color: var(--text-secondary);
}

.group-occurs {
  font-size: var(--text-xs);
  color: var(--text-muted);
  font-family: var(--font-mono);
}

.group-badge {
  font-size: 10px;
  padding: 1px 6px;
  border-radius: var(--radius-sm);
  background: var(--bg-secondary);
  color: var(--text-muted);
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.group-children {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.nested-header {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  padding: var(--space-1) var(--space-2);
  color: var(--text-muted);
  font-size: var(--text-xs);
}
</style>

<template>
  <div class="element-tree-item">
    <div class="element-node" :style="{ paddingLeft: `${depth * 16}px` }">
      <span class="element-name">{{ props.element.name }}</span>
      <span v-if="props.element.occurs" class="element-occurs">
        {{ formatOccurs(props.element.occurs) }}
      </span>
    </div>
  </div>
</template>

<script setup lang="ts">
// import { computed } from 'vue'
import type { TypeElement } from '@/types'

const props = withDefaults(defineProps<{
  element: TypeElement
  depth?: number
}>(), {
  depth: 0
})

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
.element-tree-item {
  font-size: var(--text-sm);
}

.element-node {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  padding: var(--space-1) var(--space-2);
  border-radius: var(--radius-sm);
  transition: background-color 0.15s;
}

.element-node:hover {
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

.element-name {
  font-style: italic;
  color: var(--text-secondary);
}

.element-occurs {
  font-size: var(--text-xs);
  color: var(--text-muted);
  font-family: var(--font-mono);
}

.element-badge {
  font-size: 10px;
  padding: 1px 6px;
  border-radius: var(--radius-sm);
  background: var(--bg-secondary);
  color: var(--text-muted);
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.element-children {
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

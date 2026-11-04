<template>
  <div class="choice-tree-item">
    <div class="choice-node" :style="{ paddingLeft: `${depth * 16}px` }">
      <span class="choice-name">Choice</span>
      <span v-if="props.choice.occurs" class="choice-occurs">
        {{ formatOccurs(props.choice.occurs) }}
      </span>
      <div v-if="props.choice.groups && props.choice.groups.length > 0" class="group-tree">
        <GroupTreeItem 
          v-for="(g, index) in props.choice.groups" 
          :key="`group-${index}`" 
          :group="g"
          :depth="depth + 1"
        />
      </div>
      <div v-if="props.choice.choices && props.choice.choices.length > 0" class="choice-tree">
        <ChoiceTreeItem 
          v-for="(c, index) in props.choice.choices" 
          :key="`choice-${index}`" 
          :choice="c"
          :depth="depth + 1"
        />
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
// import { computed } from 'vue'
import type { ChoiceElement } from '@/types'
import GroupTreeItem from './GroupTreeItem.vue'

const props = withDefaults(defineProps<{
  choice: ChoiceElement
  depth?: number
}>(), {
  depth: 0
})

// const isExpanded = ref(props.depth === 0)

// const hasNestedContent = computed(() => {
//   const g = props.choice
//   return !!(g.choices?.length)
// })

// function toggleExpanded() {
//   isExpanded.value = !isExpanded.value
// }

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
.choice-tree-item {
  font-size: var(--text-sm);
}

.choice-node {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  padding: var(--space-1) var(--space-2);
  border-radius: var(--radius-sm);
  transition: background-color 0.15s;
}

.choice-node:hover {
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

.choice-name {
  font-style: italic;
  color: var(--text-secondary);
}

.choice-occurs {
  font-size: var(--text-xs);
  color: var(--text-muted);
  font-family: var(--font-mono);
}

.choice-badge {
  font-size: 10px;
  padding: 1px 6px;
  border-radius: var(--radius-sm);
  background: var(--bg-secondary);
  color: var(--text-muted);
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.choice-children {
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

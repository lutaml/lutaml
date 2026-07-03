<script setup lang="ts">
import { computed } from 'vue'
import { useDataStore } from '../stores/dataStore'
import { useUiStore } from '../stores/uiStore'
import type { SpaPackageTreeNode } from '../types'

const props = defineProps<{ node: SpaPackageTreeNode }>()
const data = useDataStore()
const ui = useUiStore()

const isExpanded = computed(() => ui.expandedNodes.has(props.node.id))
const isSelected = computed(() =>
  ui.currentView === 'package' && ui.currentPackageId === props.node.id,
)
const children = computed(() => props.node.children || [])
const nodeClasses = computed(() => props.node.classes || [])

function toggle() {
  ui.toggleNode(props.node.id)
}

function select() {
  ui.selectPackage(props.node.id, props.node.name)
}
</script>

<template>
  <div class="tree-node">
    <div class="tree-node-content" :class="{ selected: isSelected }">
      <button class="tree-toggle" v-if="children.length || nodeClasses.length" @click.stop="toggle">
        <svg width="12" height="12" viewBox="0 0 12 12" fill="none" :class="{ expanded: isExpanded }">
          <path d="M4 3l3 3-3 3" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
        </svg>
      </button>
      <span class="tree-toggle-placeholder" v-else></span>

      <span class="tree-icon" @click="select" style="cursor: pointer;">
        <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
          <path d="M2 6L8 2L14 6V13C14 13.5 13.5 14 13 14H3C2.5 14 2 13.5 2 13V6Z" stroke="currentColor" stroke-width="1.2" stroke-linecap="round" stroke-linejoin="round"/>
        </svg>
      </span>

      <span class="tree-label-group" @click="select">
        <span class="tree-stereotype" v-if="node.stereotypes && node.stereotypes.length">
          <span v-for="s in node.stereotypes" :key="s">&laquo;{{ s }}&raquo;</span>
        </span>
        <span class="tree-label">{{ node.name }}</span>
      </span>

      <span class="tree-count" v-if="node.classCount">{{ node.classCount }}</span>
    </div>

    <div class="tree-children" v-if="isExpanded">
      <PackageTreeNode v-for="child in children" :key="child.id" :node="child" />

      <div v-for="cls in nodeClasses" :key="cls.id"
           class="tree-item" :class="{ selected: ui.currentClassId === cls.id }"
           @click="ui.selectClass(cls.id, cls.name)">
        <span class="badge badge-class">{{ cls.stereotypes.length ? cls.stereotypes[0][0] : 'C' }}</span>
        <span class="tree-item-label">{{ cls.name }}</span>
      </div>
    </div>
  </div>
</template>

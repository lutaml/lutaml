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

function toggle() {
  ui.toggleNode(props.node.id)
}

function select() {
  ui.selectPackage(props.node.id, props.node.name)
}

function typeIcon(type: string): string {
  switch (type) {
    case 'Class': return 'C'
    case 'DataType': return 'DT'
    case 'Enum': return 'E'
    case 'Interface': return 'I'
    default: return 'C'
  }
}
</script>

<template>
  <div class="tree-node">
    <div class="node-content" :class="{ selected: isSelected }">
      <button class="toggle-btn" :class="{ expanded: isExpanded }"
              v-if="node.children.length || node.classes.length"
              @click.stop="toggle">
        &#9654;
      </button>
      <span class="toggle-placeholder" v-else></span>

      <span class="folder-icon" @click="select" style="cursor: pointer;">
        &#128193;
      </span>

      <span class="node-label" @click="select" style="cursor: pointer;">
        {{ node.name }}
      </span>

      <span class="node-stereotypes" v-if="node.stereotypes.length">
        <span v-for="s in node.stereotypes" :key="s" class="stereotype-tag">&laquo;{{ s }}&raquo;</span>
      </span>

      <span class="count-badge" v-if="node.classCount">
        {{ node.classCount }}
      </span>
    </div>

    <div class="node-children" v-if="isExpanded">
      <PackageTreeNode v-for="child in node.children" :key="child.id" :node="child" />

      <div v-for="cls in node.classes" :key="cls.id"
           class="tree-item" :class="{ selected: ui.currentClassId === cls.id }"
           @click="ui.selectClass(cls.id, cls.name)">
        <span class="type-badge" :class="cls.stereotypes.length ? '' : 'default'">
          {{ cls.stereotypes.length ? cls.stereotypes[0][0] : 'C' }}
        </span>
        <span class="item-label">{{ cls.name }}</span>
      </div>
    </div>
  </div>
</template>

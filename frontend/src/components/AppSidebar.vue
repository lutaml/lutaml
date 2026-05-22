<script setup lang="ts">
import { useDataStore } from '../stores/dataStore'
import { useUiStore } from '../stores/uiStore'
import PackageTreeNode from './PackageTreeNode.vue'

const data = useDataStore()
const ui = useUiStore()
</script>

<template>
  <aside class="sidebar" :class="{ collapsed: !ui.sidebarVisible }">
    <div class="sidebar-branding">
      <svg class="brand-icon" viewBox="0 0 32 32" width="32" height="32">
        <rect x="2" y="2" width="28" height="28" rx="6" fill="var(--color-primary)" />
        <text x="16" y="22" text-anchor="middle" fill="white" font-size="16" font-weight="bold">L</text>
      </svg>
      <div class="brand-text">
        <div class="brand-title">LutaML</div>
        <div class="brand-subtitle">UML Browser</div>
      </div>
    </div>

    <button class="overview-button" :class="{ active: ui.currentView === 'welcome' }"
            @click="ui.showWelcome()">
      <span class="icon">&#9776;</span>
      <span>Overview</span>
    </button>

    <div class="tree-controls">
      <button @click="ui.expandAll()" title="Expand All">Expand All</button>
      <button @click="ui.collapseAll()" title="Collapse All">Collapse All</button>
    </div>

    <div class="package-tree" v-if="data.packageTree">
      <PackageTreeNode :node="data.packageTree" />
    </div>
    <div v-else class="loading">Loading...</div>

    <div class="sidebar-stats" v-if="data.metadata">
      <div class="stat-item">
        <span class="stat-value">{{ data.metadata.statistics.packages }}</span>
        <span class="stat-label">Packages</span>
      </div>
      <div class="stat-item">
        <span class="stat-value">{{ data.metadata.statistics.classes }}</span>
        <span class="stat-label">Classes</span>
      </div>
      <div class="stat-item">
        <span class="stat-value">{{ data.metadata.statistics.associations }}</span>
        <span class="stat-label">Associations</span>
      </div>
    </div>
  </aside>
</template>

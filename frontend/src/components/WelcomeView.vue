<script setup lang="ts">
import { useDataStore } from '../stores/dataStore'
import { useUiStore } from '../stores/uiStore'

const data = useDataStore()
const ui = useUiStore()
</script>

<template>
  <div class="welcome-view">
    <div class="welcome-content">
      <h1 class="welcome-title">{{ data.metadata?.generator || 'UML Browser' }}</h1>
      <p class="welcome-subtitle">Explore UML model packages, classes, and associations</p>

      <div class="welcome-stats" v-if="data.metadata">
        <div class="stat-card">
          <div class="stat-value">{{ data.metadata.statistics.packages }}</div>
          <div class="stat-label">Packages</div>
        </div>
        <div class="stat-card">
          <div class="stat-value">{{ data.metadata.statistics.classes }}</div>
          <div class="stat-label">Classes</div>
        </div>
        <div class="stat-card">
          <div class="stat-value">{{ data.metadata.statistics.attributes }}</div>
          <div class="stat-label">Attributes</div>
        </div>
        <div class="stat-card">
          <div class="stat-value">{{ data.metadata.statistics.associations }}</div>
          <div class="stat-label">Associations</div>
        </div>
      </div>

      <p class="welcome-hint">Select a package from the sidebar or press <kbd>/</kbd> to search</p>
    </div>
  </div>
</template>

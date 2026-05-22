<script setup lang="ts">
import { useDataStore } from '../stores/dataStore'

const data = useDataStore()
</script>

<template>
  <div class="view-welcome">
    <div class="welcome-logo">
      <svg viewBox="0 0 48 48" width="48" height="48">
        <rect x="4" y="4" width="40" height="40" rx="8" fill="var(--color-primary)" />
        <text x="24" y="32" text-anchor="middle" fill="white" font-size="24" font-weight="bold">L</text>
      </svg>
    </div>
    <h1 class="welcome-title">{{ data.metadata?.generator || 'UML Browser' }}</h1>
    <p class="welcome-subtitle">Explore UML model packages, classes, and associations</p>

    <div class="welcome-stats" v-if="data.metadata">
      <div class="welcome-stat">
        <div class="welcome-stat-value">{{ data.metadata.statistics.packages }}</div>
        <div class="welcome-stat-label">Packages</div>
      </div>
      <div class="welcome-stat">
        <div class="welcome-stat-value">{{ data.metadata.statistics.classes }}</div>
        <div class="welcome-stat-label">Classes</div>
      </div>
      <div class="welcome-stat">
        <div class="welcome-stat-value">{{ data.metadata.statistics.attributes }}</div>
        <div class="welcome-stat-label">Attributes</div>
      </div>
      <div class="welcome-stat">
        <div class="welcome-stat-value">{{ data.metadata.statistics.associations }}</div>
        <div class="welcome-stat-label">Associations</div>
      </div>
    </div>

    <p class="welcome-actions">Select a package from the sidebar or press <kbd>/</kbd> to search</p>
  </div>
</template>

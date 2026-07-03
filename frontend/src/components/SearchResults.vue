<script setup lang="ts">
import { computed } from 'vue'
import { useDataStore } from '../stores/dataStore'
import { useUiStore } from '../stores/uiStore'

const data = useDataStore()
const ui = useUiStore()

const resultsByType = computed(() => {
  const groups: Record<string, typeof data.searchEntries> = {}
  for (const entry of data.searchEntries) {
    const type = entry.type
    ;(groups[type] ??= []).push(entry)
  }
  return groups
})
</script>

<template>
  <div class="detail-view">
    <div class="entity-header">
      <div class="entity-title">
        <h2 class="entity-name">Search Results</h2>
      </div>
    </div>
    <div v-for="(entries, type) in resultsByType" :key="type" class="section">
      <h3 class="section-title">{{ type }}s <span class="section-count">{{ entries.length }}</span></h3>
      <div class="table-wrapper">
        <table class="data-table">
          <thead>
            <tr><th>Name</th><th>Package</th><th>Type</th></tr>
          </thead>
          <tbody>
            <tr v-for="entry in entries" :key="entry.id" class="clickable-row"
                @click="entry.type === 'class' ? ui.selectClass(entry.entityId) : ui.selectPackage(entry.entityId)">
              <td>{{ entry.name }}</td>
              <td>{{ entry.package }}</td>
              <td><span class="entity-badge" :class="'badge-' + (entry.entityType || 'class').toLowerCase()">{{ entry.entityType }}</span></td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    <div class="empty-state" v-if="!data.searchEntries.length">
      <p>No results found.</p>
    </div>
  </div>
</template>

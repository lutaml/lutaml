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
    <h2>Search Results</h2>
    <div v-for="(entries, type) in resultsByType" :key="type" class="section">
      <h3>{{ type }}s ({{ entries.length }})</h3>
      <div class="table-wrapper">
        <table>
          <thead>
            <tr><th>Name</th><th>Package</th><th>Type</th></tr>
          </thead>
          <tbody>
            <tr v-for="entry in entries" :key="entry.id" class="clickable"
                @click="entry.type === 'class' ? ui.selectClass(entry.entityId) : ui.selectPackage(entry.entityId)">
              <td>{{ entry.name }}</td>
              <td>{{ entry.package }}</td>
              <td><span class="type-badge">{{ entry.entityType }}</span></td>
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

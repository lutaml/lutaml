<template>
  <div class="schema-overview">
    <!-- Schema Info -->
    <div class="overview-section">
      <h3 class="schema-name">{{ schema.name }}</h3>
      <div class="schema-meta">
        <span v-if="schema.prefix" class="meta-item">
          <span class="meta-label">Prefix:</span>
          <code>{{ schema.prefix }}</code>
        </span>
        <span class="meta-item">
          <span class="meta-label">Namespace:</span>
          <code class="truncate">{{ schema.target_namespace }}</code>
        </span>
      </div>
    </div>

    <!-- Documentation -->
    <div v-if="schema.documentation" class="overview-section">
      <h3 class="section-title">Documentation</h3>
      <p class="documentation">{{ schema.documentation }}</p>
    </div>

    <!-- Statistics -->
    <div class="overview-section">
      <h3 class="section-title">Statistics</h3>
      <div class="stats-grid">
        <div class="stat-card">
          <span class="stat-number">{{ schema.complex_types?.length || 0 }}</span>
          <span class="stat-label">Complex Types</span>
        </div>
        <div class="stat-card">
          <span class="stat-number">{{ schema.simple_types?.length || 0 }}</span>
          <span class="stat-label">Simple Types</span>
        </div>
        <div class="stat-card">
          <span class="stat-number">{{ schema.elements?.length || 0 }}</span>
          <span class="stat-label">Elements</span>
        </div>
        <div class="stat-card">
          <span class="stat-number">{{ schema.groups?.length || 0 }}</span>
          <span class="stat-label">Groups</span>
        </div>
        <div class="stat-card">
          <span class="stat-number">{{ schema.attribute_groups?.length || 0 }}</span>
          <span class="stat-label">Attribute Groups</span>
        </div>
      </div>
    </div>

    <!-- Imports -->
    <div v-if="schema.imports?.length" class="overview-section">
      <h3 class="section-title">Imports</h3>
      <ul class="import-list">
        <li v-for="imp in schema.imports" :key="imp.namespace" class="import-item">
          <code>{{ imp.namespace }}</code>
          <span v-if="imp.schema_location" class="import-location">{{ imp.schema_location }}</span>
        </li>
      </ul>
    </div>

    <!-- Includes -->
    <div v-if="schema.includes?.length" class="overview-section">
      <h3 class="section-title">Includes</h3>
      <ul class="import-list">
        <li v-for="inc in schema.includes" :key="inc.schema_location" class="import-item">
          <code>{{ inc.schema_location }}</code>
        </li>
      </ul>
    </div>

    <!-- Quick Access -->
    <div class="overview-section">
      <h3 class="section-title">Quick Access</h3>
      <div class="quick-access">
        <button
          v-if="schema.complex_types?.length"
          class="quick-btn"
          @click="goToTypes"
        >
          <span class="badge badge-complex">C</span>
          <span>View {{ schema.complex_types.length }} Complex Types</span>
          <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
            <path d="M5 3l5 4-5 4" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
          </svg>
        </button>
        <button
          v-if="schema.elements?.length"
          class="quick-btn"
          @click="goToElements"
        >
          <span class="badge badge-element">E</span>
          <span>View {{ schema.elements.length }} Elements</span>
          <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
            <path d="M5 3l5 4-5 4" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
          </svg>
        </button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import type { Schema } from '@/types'
import { useUiStore } from '@/stores/uiStore'

defineProps<{ schema: Schema }>()

const uiStore = useUiStore()

function goToTypes() {
  uiStore.setPanelTab('types')
}

function goToElements() {
  uiStore.setPanelTab('elements')
}
</script>

<style scoped>
.schema-overview {
  display: flex;
  flex-direction: column;
  gap: var(--space-5);
}

.schema-name {
  font-size: var(--text-xl);
  font-weight: 600;
}

.schema-meta {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-4);
  margin-top: var(--space-2);
}

.meta-item {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  font-size: var(--text-sm);
}

.meta-label {
  color: var(--text-muted);
}

.meta-item code {
  max-width: 200px;
}

.section-title {
  font-size: var(--text-xs);
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: var(--text-muted);
  margin-bottom: var(--space-2);
}

.documentation {
  font-size: var(--text-sm);
  color: var(--text-secondary);
  line-height: var(--leading-relaxed);
}

.stats-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: var(--space-3);
}

.stat-card {
  display: flex;
  flex-direction: column;
  gap: var(--space-1);
  padding: var(--space-3);
  background: var(--bg-secondary);
  border-radius: var(--radius-md);
}

.stat-number {
  font-size: var(--text-xl);
  font-weight: 600;
  color: var(--text-primary);
}

.stat-label {
  font-size: var(--text-xs);
  color: var(--text-muted);
}

.import-list {
  list-style: none;
  display: flex;
  flex-direction: column;
  gap: var(--space-2);
}

.import-item {
  display: flex;
  flex-direction: column;
  gap: var(--space-1);
  font-size: var(--text-sm);
}

.import-location {
  color: var(--text-muted);
  font-size: var(--text-xs);
}

.quick-access {
  display: flex;
  flex-direction: column;
  gap: var(--space-2);
}

.quick-btn {
  display: flex;
  align-items: center;
  gap: var(--space-3);
  padding: var(--space-3);
  background: var(--bg-secondary);
  border-radius: var(--radius-md);
  font-size: var(--text-sm);
  color: var(--text-primary);
  text-align: left;
  transition: background var(--transition-fast);
}

.quick-btn:hover {
  background: var(--bg-hover);
}

.quick-btn span:first-of-type {
  margin-right: var(--space-1);
}

.quick-btn svg {
  margin-left: auto;
  color: var(--text-muted);
}
</style>

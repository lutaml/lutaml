<template>
  <aside class="sidebar" :class="{ collapsed: uiStore.sidebarCollapsed }" :aria-label="`${schemaStore.metadata?.title || t('header.docsTitle')} ${t('sidebar.navigation')}`">
    <div class="sidebar-content">
      <!-- Branding -->
      <div class="sidebar-branding">
        <img
          v-if="schemaStore.metadata?.appearance?.logos?.square"
          :src="uiStore.isDark ? (schemaStore.metadata.appearance.logos.square.dark?.url || schemaStore.metadata.appearance.logos.square.dark?.path) : (schemaStore.metadata.appearance.logos.square.light?.url || schemaStore.metadata.appearance.logos.square.light?.path)"
          alt="Package logo"
          class="branding-logo"
        />
        <img
          v-else
          :src="uiStore.isDark ? 'https://raw.githubusercontent.com/lutaml/branding/refs/heads/main/svg/lutaml-logo_logo-icon-dark.svg' : 'https://raw.githubusercontent.com/lutaml/branding/refs/heads/main/svg/lutaml-logo_logo-icon-light.svg'"
          alt="LutaML"
          class="branding-logo"
        />
        <div class="branding-text">
          <span class="branding-title">{{ schemaStore.metadata?.title || 'JSON Schema Docs' }}</span>
          <span class="branding-subtitle">{{ schemaStore.metadata?.appearance?.subtitle || 'LutaML JSON Schema' }}</span>
        </div>
      </div>

      <!-- Overview -->
      <div class="sidebar-section overview-section">
        <button
          class="overview-btn"
          :class="{ active: !schemaStore.selectedSchema }"
          @click="goHome"
        >
          <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
            <path d="M2 7.5L8 2.5L14 7.5" stroke="currentColor" stroke-width="1.3" stroke-linecap="round" stroke-linejoin="round"/>
            <path d="M3 7.5V13.5C3 13.5 3 14 4 14H12C12 14 13 14 13 13.5V7.5" stroke="currentColor" stroke-width="1.3" stroke-linecap="round" stroke-linejoin="round"/>
          </svg>
          <span>Overview</span>
        </button>
      </div>

      <!-- Schema Tree -->
      <div class="sidebar-section flex-1 overflow-auto">
        <div class="section-header">
          <span class="section-title">{{ t('sidebar.schemas') }}</span>
        </div>
        <div class="search-box">
          <svg class="search-icon" width="14" height="14" viewBox="0 0 14 14" fill="none">
            <circle cx="5.5" cy="5.5" r="4.5" stroke="currentColor" stroke-width="1.3"/>
            <path d="M9 9l4 4" stroke="currentColor" stroke-width="1.3" stroke-linecap="round"/>
          </svg>
          <input
            v-model="searchQuery"
            type="text"
            class="search-input"
            :placeholder="t('sidebar.filterPlaceholder')"
            :aria-label="t('sidebar.filterAria')"
            @keydown="handleSearchKey"
          />
          <kbd v-if="!searchQuery" class="search-kbd" aria-hidden="true">/</kbd>
          <button v-if="searchQuery" class="search-clear" :aria-label="t('sidebar.clearSearch')" @click="searchQuery = ''">
            <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
              <path d="M3 3l6 6M9 3l-6 6" stroke="currentColor" stroke-width="1.2" stroke-linecap="round"/>
            </svg>
          </button>
        </div>
        <div v-if="debouncedQuery && searchResults.length" class="search-results">
          <button
            v-for="(result, idx) in searchResults"
            :key="`${result.type}:${result.name}@${result.schemaName}`"
            class="search-result-item"
            :class="{ active: idx === activeResultIdx }"
            @click="goToSearchResult(result)"
          >
            <div class="search-result-row">
              <span class="badge" :class="resultBadgeClass(result.type)">{{ resultTypeLabel(result.type) }}</span>
              <span class="search-result-name">{{ result.title || result.name }}</span>
              <span class="search-result-schema text-muted">{{ result.schemaName }}</span>
            </div>
            <div v-if="result.description" class="search-result-desc text-muted">{{ truncateDesc(result.description) }}</div>
          </button>
        </div>
        <div v-else-if="debouncedQuery && !searchResults.length && searchQuery" class="search-no-results text-muted">
          No results found
        </div>
        <div v-else class="schema-tree" ref="sidebarTreeRef" role="tree" :aria-label="t('sidebar.schemas')">
          <div
            v-for="schema in schemaStore.schemas"
            :key="schema.name"
            class="schema-node"
          >
            <div
              class="schema-node-header"
              :class="{ active: schema.name === schemaStore.selectedSchemaName }"
              role="treeitem"
              :aria-expanded="uiStore.isSchemaExpanded(schema.name)"
              tabindex="0"
              @click="toggleAndSelect(schema.name)"
              @keydown.enter="toggleAndSelect(schema.name)"
              @keydown.space.prevent="toggleAndSelect(schema.name)"
            >
              <svg width="12" height="12" viewBox="0 0 12 12" fill="none" :class="{ expanded: uiStore.isSchemaExpanded(schema.name) }">
                <path d="M4 3l3 3-3 3" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
              </svg>
              <span class="schema-name">{{ schema.title || schema.name }}</span>
              <span v-if="schema.$id" class="schema-id-hint" :title="schema.$id">{{ schema.$id }}</span>
              <span class="schema-badge-count">{{ schema.properties.length }}P</span>
              <span class="schema-badge-count">{{ schema.definitions.length }}D</span>
            </div>

            <div v-if="uiStore.isSchemaExpanded(schema.name)" class="schema-children" role="group">
              <div
                v-for="prop in schema.properties.slice(0, 10)"
                :key="`p-${prop.name}`"
                class="tree-item property-item"
                :class="{ active: schema.name === schemaStore.selectedSchemaName && prop.name === schemaStore.selectedPropertyName }"
                role="treeitem"
                tabindex="0"
                @click.stop="selectProperty(schema.name, prop.name)"
                @keydown.enter="selectProperty(schema.name, prop.name)"
                @keydown.space.prevent="selectProperty(schema.name, prop.name)"
              >
                <span class="badge badge-property-sm">P</span>
                <span class="tree-bullet" aria-hidden="true"></span>
                <span class="tree-item-name">{{ prop.name }}</span>
                <span class="tree-item-type" :class="treeTypeClass(prop.type)">{{ prop.type || 'any' }}</span>
              </div>
              <div v-if="schema.properties.length > 10" class="tree-more text-muted">
                +{{ schema.properties.length - 10 }} {{ t('sidebar.more') }}
              </div>
              <div
                v-for="def in schema.definitions"
                :key="`d-${def.name}`"
                class="tree-item definition-item"
                :class="{ active: schema.name === schemaStore.selectedSchemaName && def.name === schemaStore.selectedDefinitionName }"
                role="treeitem"
                tabindex="0"
                @click.stop="selectDefinition(schema.name, def.name)"
                @keydown.enter="selectDefinition(schema.name, def.name)"
                @keydown.space.prevent="selectDefinition(schema.name, def.name)"
              >
                <span class="badge badge-definition-sm">D</span>
                <span class="tree-bullet" aria-hidden="true"></span>
                <span class="tree-item-name">{{ def.title || def.name }}</span>
                <span class="tree-item-count">{{ def.properties.length }}</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Quick Stats -->
      <div class="sidebar-section stats-section">
        <div class="stats-grid">
          <div class="stat-item">
            <span class="stat-value">{{ schemaStore.schemaCounts.schemas }}</span>
            <span class="stat-label">{{ t('sidebar.statsSchemas') }}</span>
          </div>
          <div class="stat-item">
            <span class="stat-value">{{ schemaStore.schemaCounts.properties }}</span>
            <span class="stat-label">{{ t('sidebar.statsProperties') }}</span>
          </div>
          <div class="stat-item">
            <span class="stat-value">{{ schemaStore.schemaCounts.definitions }}</span>
            <span class="stat-label">{{ t('sidebar.statsDefinitions') }}</span>
          </div>
        </div>
      </div>

      <!-- Footer -->
      <div class="sidebar-footer">
        <a href="https://www.lutaml.org" target="_blank" rel="noopener" class="footer-brand" title="LutaML">
          <img
            :src="uiStore.isDark ? 'https://raw.githubusercontent.com/lutaml/branding/refs/heads/main/svg/lutaml-logo_logo-full-dark.svg' : 'https://raw.githubusercontent.com/lutaml/branding/refs/heads/main/svg/lutaml-logo_logo-full-light.svg'"
            alt="LutaML"
            class="lutaml-logo"
          />
        </a>
        <div class="footer-text-group">
          <span class="footer-text">
            Generated with
            <a href="https://github.com/lutaml/lutaml-jsonschema" target="_blank" rel="noopener">LutaML JSON Schema</a>
          </span>
          <span v-if="schemaStore.metadata?.version" class="footer-text">{{ schemaStore.metadata.version }}</span>
        </div>
      </div>
    </div>
  </aside>
</template>

<script setup lang="ts">
import { ref, computed, watch, nextTick } from 'vue'
import { useSchemaStore } from '../stores/schemaStore'
import { useUiStore } from '../stores/uiStore'
import type { SpaSearchEntry } from '../types'
import { t } from '../i18n'

const schemaStore = useSchemaStore()
const uiStore = useUiStore()
const sidebarTreeRef = ref<HTMLElement | null>(null)

const searchQuery = ref('')
const debouncedQuery = ref('')
const activeResultIdx = ref(-1)

let debounceTimer: ReturnType<typeof setTimeout> | null = null

watch(searchQuery, (q) => {
  if (debounceTimer) clearTimeout(debounceTimer)
  if (!q.trim()) {
    debouncedQuery.value = ''
    activeResultIdx.value = -1
    return
  }
  debounceTimer = setTimeout(() => { debouncedQuery.value = q }, 300)
})

const searchResults = computed(() => {
  const q = debouncedQuery.value.trim().toLowerCase()
  if (!q) return []
  const scored = schemaStore.searchIndex
    .map(entry => {
      let score = 0
      const nameLower = entry.name.toLowerCase()
      const titleLower = (entry.title || '').toLowerCase()
      const descLower = (entry.description || '').toLowerCase()
      const schemaLower = entry.schemaName.toLowerCase()
      if (nameLower === q) score += 100
      else if (nameLower.startsWith(q)) score += 50
      else if (nameLower.includes(q)) score += 30
      if (titleLower === q) score += 80
      else if (titleLower.startsWith(q)) score += 40
      else if (titleLower.includes(q)) score += 20
      if (descLower.includes(q)) score += 10
      if (schemaLower.includes(q)) score += 5
      return { entry, score }
    })
    .filter(r => r.score > 0)
    .sort((a, b) => b.score - a.score)
    .slice(0, 15)
    .map(r => r.entry)
  return scored
})

watch(searchResults, () => { activeResultIdx.value = -1 })

watch(() => schemaStore.selectedSchemaName, () => {
  nextTick(() => {
    const container = sidebarTreeRef.value
    if (!container) return
    const active = container.querySelector('.schema-node-header.active') as HTMLElement | null
    if (active) active.scrollIntoView({ block: 'nearest', behavior: 'smooth' })
  })
})

function handleSearchKey(event: KeyboardEvent) {
  if (event.key === 'ArrowDown') {
    activeResultIdx.value = Math.min(activeResultIdx.value + 1, searchResults.value.length - 1)
    event.preventDefault()
  } else if (event.key === 'ArrowUp') {
    activeResultIdx.value = Math.max(0, activeResultIdx.value - 1)
    event.preventDefault()
  } else if (event.key === 'Enter') {
    const result = searchResults.value[activeResultIdx.value]
    if (result) goToSearchResult(result)
    activeResultIdx.value = -1
  } else if (event.key === 'Escape') {
    searchQuery.value = ''
    activeResultIdx.value = -1
  }
}

function goToSearchResult(result: SpaSearchEntry) {
  schemaStore.selectSchema(result.schemaName)
  if (!uiStore.isSchemaExpanded(result.schemaName)) {
    uiStore.toggleSchemaExpanded(result.schemaName)
  }
  if (result.type === 'definition') {
    schemaStore.selectDefinition(result.name)
  } else if (result.type === 'property') {
    schemaStore.selectProperty(result.name)
  }
  searchQuery.value = ''
  debouncedQuery.value = ''
  uiStore.closeDetailPanel()
}

function resultTypeLabel(type: string): string {
  switch (type) {
    case 'schema': return 'S'
    case 'definition': return 'D'
    case 'property': return 'P'
    default: return '?'
  }
}

function resultBadgeClass(type: string): string {
  switch (type) {
    case 'schema': return 'badge-schema-sm'
    case 'definition': return 'badge-definition-sm'
    case 'property': return 'badge-property-sm'
    default: return ''
  }
}

function goHome() {
  schemaStore.selectSchema(null)
  uiStore.closeDetailPanel()
}

function toggleAndSelect(name: string) {
  schemaStore.selectSchema(name)
  uiStore.toggleSchemaExpanded(name)
}

function selectDefinition(schemaName: string, defName: string) {
  schemaStore.selectSchema(schemaName)
  schemaStore.selectDefinition(defName)
  uiStore.closeDetailPanel()
}

function selectProperty(schemaName: string, propName: string) {
  schemaStore.selectSchema(schemaName)
  schemaStore.selectProperty(propName)
  uiStore.openDetailPanel()
}

function treeTypeClass(type?: string): string {
  const t = (type || 'any').split(',')[0].trim()
  switch (t) {
    case 'string': return 'ttype-string'
    case 'number': return 'ttype-number'
    case 'integer': return 'ttype-integer'
    case 'boolean': return 'ttype-boolean'
    case 'object': return 'ttype-object'
    case 'array': return 'ttype-array'
    default: return ''
  }
}

function truncateDesc(desc: string): string {
  if (desc.length <= 80) return desc
  return desc.slice(0, 77) + '...'
}
</script>

<style scoped>
.sidebar {
  width: 280px;
  flex-shrink: 0;
  background: var(--bg-secondary);
  border-inline-end: 1px solid var(--border-light);
  display: flex;
  flex-direction: column;
  transition: width var(--transition-slow);
  overflow: hidden;
}

.sidebar.collapsed {
  width: 0;
}

.sidebar-content {
  flex: 1;
  display: flex;
  flex-direction: column;
  overflow: hidden;
  min-width: 280px;
}

.sidebar-branding {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  padding: var(--space-4);
  border-bottom: 1px solid var(--border-light);
}

.branding-logo {
  width: 28px;
  height: 28px;
  flex-shrink: 0;
}

.branding-text {
  display: flex;
  flex-direction: column;
  line-height: 1.2;
  min-width: 0;
}

.branding-title {
  font-size: var(--text-sm);
  font-weight: 600;
  color: var(--text-primary);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.branding-subtitle {
  font-size: var(--text-xs);
  color: var(--text-muted);
  font-weight: 400;
}

.overview-section {
  padding: var(--space-2) var(--space-3);
  border-bottom: 1px solid var(--border-light);
}

.overview-btn {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  width: 100%;
  padding: var(--space-2) var(--space-3);
  font-size: var(--text-sm);
  font-weight: 500;
  color: var(--text-secondary);
  border-radius: var(--radius-md);
  cursor: pointer;
  transition: all var(--transition-fast);
}

.overview-btn:hover {
  background: var(--bg-hover);
  color: var(--text-primary);
}

.overview-btn.active {
  background: var(--color-primary-alpha);
  color: var(--text-accent);
}

.sidebar-section {
  padding: var(--space-4);
  border-bottom: 1px solid var(--border-light);
}

.sidebar-section.flex-1 {
  flex: 1;
  overflow: auto;
}

.section-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: var(--space-3);
}

.section-title {
  font-size: var(--text-xs);
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: var(--text-muted);
}

.schema-tree {
  display: flex;
  flex-direction: column;
  gap: var(--space-1);
}

.schema-node-header {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  padding: var(--space-1) var(--space-2);
  cursor: pointer;
  transition: background var(--transition-fast);
  font-size: var(--text-sm);
  border-radius: var(--radius-sm);
}

.schema-node-header:hover {
  background: var(--bg-hover);
}

.schema-node-header.active {
  background: var(--color-primary-alpha);
}

.schema-node-header.active .schema-name {
  color: var(--color-primary);
}

.schema-node-header.active svg {
  color: var(--color-primary);
}

.schema-node-header svg {
  color: var(--text-muted);
  transition: transform var(--transition-fast);
  flex-shrink: 0;
}

.schema-node-header svg.expanded {
  transform: rotate(90deg);
}

.schema-name {
  flex: 1;
  font-weight: 500;
  color: var(--text-primary);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.schema-id-hint {
  font-size: 9px;
  font-family: var(--font-mono);
  color: var(--text-muted);
  max-width: 80px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  flex-shrink: 0;
}

.schema-badge-count {
  font-size: 10px;
  font-weight: 500;
  color: var(--text-accent);
  background: var(--color-primary-alpha);
  padding: 1px 5px;
  border-radius: 10px;
}

.schema-children {
  margin-inline-start: var(--space-4);
  padding-inline-start: var(--space-2);
  border-inline-start: 1px solid var(--schema-lines);
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.tree-item {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  padding: 3px var(--space-2);
  font-size: var(--text-xs);
  cursor: pointer;
  border-radius: var(--radius-sm);
  transition: background var(--transition-fast);
}

.tree-item:hover {
  background: var(--bg-hover);
}

.tree-item.active {
  background: var(--color-primary-alpha);
}

.tree-item.active .tree-item-name {
  color: var(--color-primary);
}

.tree-item-name {
  flex: 1;
  color: var(--text-secondary);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.tree-item-count {
  font-size: 10px;
  font-weight: 500;
  color: var(--color-primary);
  background: var(--color-primary-alpha);
  padding: 0px 4px;
  border-radius: 10px;
  flex-shrink: 0;
}

.tree-bullet {
  display: inline-block;
  width: 6px;
  height: 1px;
  background: var(--schema-lines);
  flex-shrink: 0;
}

.tree-item-type {
  font-size: 9px;
  font-family: var(--font-mono);
  flex-shrink: 0;
  color: var(--text-muted);
}

.tree-item-type.ttype-string { color: var(--type-string); }
.tree-item-type.ttype-number { color: var(--type-number); }
.tree-item-type.ttype-integer { color: var(--type-integer); }
.tree-item-type.ttype-boolean { color: var(--type-boolean); }
.tree-item-type.ttype-object { color: var(--type-object); }
.tree-item-type.ttype-array { color: var(--type-array); }

.tree-more {
  font-size: 10px;
  padding: 2px var(--space-2) 2px 24px;
  font-style: italic;
}

.badge-definition-sm {
  background: var(--badge-definition-bg);
  color: var(--badge-definition);
  font-size: 9px;
  padding: 1px 4px;
  border-radius: 2px;
  font-weight: 600;
  flex-shrink: 0;
}

.badge-schema-sm {
  background: var(--badge-schema-bg);
  color: var(--badge-schema);
  font-size: 9px;
  padding: 1px 4px;
  border-radius: 2px;
  font-weight: 600;
  flex-shrink: 0;
}

.badge-property-sm {
  background: var(--bg-secondary);
  color: var(--text-muted);
  font-size: 9px;
  padding: 1px 4px;
  border-radius: 2px;
  font-weight: 600;
  flex-shrink: 0;
}

/* Search */
.search-box {
  position: relative;
  margin-bottom: var(--space-2);
}

.search-icon {
  position: absolute;
  inset-inline-start: 8px;
  top: 50%;
  transform: translateY(-50%);
  color: var(--text-muted);
  pointer-events: none;
}

.search-input {
  width: 100%;
  padding: 6px 28px 6px 28px;
  font-size: var(--text-sm);
  background: var(--bg-primary);
  border: 1px solid var(--border-light);
  border-radius: var(--radius-md);
  color: var(--text-primary);
  font-family: var(--font-sans);
}

.search-input::placeholder {
  color: var(--text-muted);
}

.search-input:focus {
  outline: none;
  border-color: var(--color-primary);
}

.search-clear {
  position: absolute;
  inset-inline-end: 6px;
  top: 50%;
  transform: translateY(-50%);
  color: var(--text-muted);
  background: none;
  border: none;
  cursor: pointer;
  padding: 2px;
  display: flex;
  align-items: center;
}

.search-clear:hover {
  color: var(--text-primary);
}

.search-kbd {
  position: absolute;
  inset-inline-end: 8px;
  top: 50%;
  transform: translateY(-50%);
  font-family: var(--font-mono);
  font-size: 10px;
  color: var(--text-muted);
  background: var(--bg-secondary);
  border: 1px solid var(--border-light);
  border-radius: 3px;
  padding: 1px 5px;
  pointer-events: none;
  line-height: 1.4;
}

.search-results {
  display: flex;
  flex-direction: column;
  gap: 1px;
  margin-bottom: var(--space-2);
  max-height: 250px;
  overflow-y: auto;
}

.search-result-item {
  display: flex;
  flex-direction: column;
  gap: 2px;
  padding: 4px 6px;
  font-size: var(--text-xs);
  text-align: start;
  background: var(--bg-primary);
  border: none;
  border-radius: var(--radius-sm);
  cursor: pointer;
  width: 100%;
  transition: background var(--transition-fast);
}

.search-result-row {
  display: flex;
  align-items: center;
  gap: var(--space-2);
}

.search-result-item:hover,
.search-result-item.active {
  background: var(--bg-hover);
}

.search-no-results {
  padding: var(--space-3) var(--space-2);
  font-size: var(--text-xs);
  text-align: center;
}

.search-result-name {
  flex: 1;
  color: var(--text-primary);
  font-weight: 500;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.search-result-schema {
  font-size: 10px;
  white-space: nowrap;
  flex-shrink: 0;
}

.search-result-desc {
  font-size: 10px;
  line-height: 1.3;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  padding-inline-start: 30px;
}

.stats-section {
  background: var(--bg-primary);
}

.stats-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: var(--space-2);
  text-align: center;
}

.stat-item {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.stat-value {
  font-size: var(--text-lg);
  font-weight: 600;
  color: var(--text-primary);
}

.stat-label {
  font-size: var(--text-xs);
  color: var(--text-muted);
}

.sidebar-footer {
  padding: var(--space-3) var(--space-4);
  border-top: 1px solid var(--border-light);
  display: flex;
  align-items: center;
  gap: var(--space-3);
}

.footer-brand {
  display: flex;
  align-items: center;
  flex-shrink: 0;
}

.lutaml-logo {
  height: 18px;
  flex-shrink: 0;
  opacity: 0.7;
}

.footer-text-group {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.footer-text {
  font-size: var(--text-xs);
  color: var(--text-muted);
}

.footer-text a {
  /* the primary blue fails AA at --text-xs; the audit-approved accent
     token (PR #68) carries small links */
  color: var(--text-accent);
  text-decoration: none;
}

.footer-text a:hover {
  text-decoration: underline;
}

@media (max-width: 768px) {
  .sidebar {
    position: fixed;
    top: 0;
    inset-inline-start: 0;
    bottom: 0;
    z-index: 40;
    box-shadow: var(--shadow-lg);
  }
  .sidebar.collapsed {
    transform: translateX(-100%);
    width: 280px;
  }
  :root[dir="rtl"] .sidebar.collapsed {
    transform: translateX(100%);
  }
}
</style>

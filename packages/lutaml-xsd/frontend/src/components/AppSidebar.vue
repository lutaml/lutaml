<template>
  <aside class="sidebar" :class="{ collapsed: uiStore.sidebarCollapsed }">
    <div class="sidebar-content">
      <!-- Branding Header -->
      <div class="sidebar-branding">
        <img
          v-if="schemaStore.metadata?.appearance?.logos?.square && !squareLogoFailed"
          :src="logoSrc(schemaStore.metadata.appearance.logos.square)"
          alt="Package logo"
          class="branding-logo"
          @error="squareLogoFailed = true"
        />
        <img
          v-else
          :src="uiStore.isDark ? 'https://raw.githubusercontent.com/lutaml/branding/refs/heads/main/svg/lutaml-logo_logo-icon-dark.svg' : 'https://raw.githubusercontent.com/lutaml/branding/refs/heads/main/svg/lutaml-logo_logo-icon-light.svg'"
          alt="LutaML"
          class="branding-logo"
        />
        <div class="branding-text">
          <span class="branding-title">{{ schemaStore.metadata?.title || schemaStore.metadata?.name || 'XSD Docs' }}</span>
          <span class="branding-subtitle">{{ schemaStore.metadata?.appearance?.subtitle || 'LXR Package' }}</span>
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

      <!-- Namespace Tree -->
      <div class="sidebar-section flex-1 overflow-auto">
        <div class="section-header">
          <span class="section-title">Namespaces</span>
        </div>
        <div class="namespace-tree">
          <div
            v-for="ns in userNamespaces"
            :key="ns.prefix"
            class="namespace-node"
          >
            <div class="namespace-node-header" :class="{ active: ns.prefix === selectedNamespacePrefix }" @click="toggleNamespaceExpanded(ns.prefix)">
              <svg width="12" height="12" viewBox="0 0 12 12" fill="none" :class="{ expanded: expandedNamespaces.has(ns.prefix) }">
                <path d="M4 3l3 3-3 3" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
              </svg>
              <span class="namespace-prefix">{{ ns.prefix }}</span>
              <span class="namespace-schema-count">{{ ns.schemas.length }}</span>
            </div>
            <div v-if="expandedNamespaces.has(ns.prefix)" class="namespace-details">
              <span class="namespace-uri" :title="ns.uri">{{ truncateUri(ns.uri) }}</span>
            </div>
            <div v-if="expandedNamespaces.has(ns.prefix)" class="namespace-schemas">
              <SchemaTreeNode
                v-for="schemaId in ns.schemas"
                :key="schemaId"
                :schema="getSchemaById(schemaId)"
                :depth="1"
              />
            </div>
          </div>
          <!-- Schemas without namespace -->
          <div v-if="orphanSchemas.length" class="namespace-node">
            <div class="namespace-node-header" :class="{ active: '__default__' === selectedNamespacePrefix }" @click="toggleNamespaceExpanded('__default__')">
              <svg width="12" height="12" viewBox="0 0 12 12" fill="none" :class="{ expanded: expandedNamespaces.has('__default__') }">
                <path d="M4 3l3 3-3 3" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
              </svg>
              <span class="namespace-prefix">(default)</span>
              <span class="namespace-schema-count">{{ orphanSchemas.length }}</span>
            </div>
            <div v-if="expandedNamespaces.has('__default__')" class="namespace-schemas">
              <SchemaTreeNode
                v-for="schema in orphanSchemas"
                :key="schema.id"
                :schema="schema"
                :depth="1"
              />
            </div>
          </div>
        </div>

        <!-- W3C Namespaces -->
        <div v-if="w3cNamespaces.length" class="section-header w3c-section-header">
          <span class="section-title">W3C Namespaces</span>
        </div>
        <div v-if="w3cNamespaces.length" class="namespace-tree">
          <div
            v-for="ns in w3cNamespaces"
            :key="ns.prefix"
            class="namespace-node"
          >
            <div class="namespace-node-header" :class="{ active: ns.prefix === selectedNamespacePrefix }" @click="toggleNamespaceExpanded(ns.prefix)">
              <svg width="12" height="12" viewBox="0 0 12 12" fill="none" :class="{ expanded: expandedNamespaces.has(ns.prefix) }">
                <path d="M4 3l3 3-3 3" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
              </svg>
              <span class="namespace-prefix">{{ ns.prefix }}</span>
              <span class="namespace-schema-count">{{ ns.schemas.length }}</span>
            </div>
            <div v-if="expandedNamespaces.has(ns.prefix)" class="namespace-details">
              <span class="namespace-uri" :title="ns.uri">{{ truncateUri(ns.uri) }}</span>
            </div>
            <div v-if="expandedNamespaces.has(ns.prefix)" class="namespace-schemas">
              <SchemaTreeNode
                v-for="schemaId in ns.schemas"
                :key="schemaId"
                :schema="getSchemaById(schemaId)"
                :depth="1"
              />
            </div>
          </div>
        </div>
      </div>

      <!-- Quick Stats -->
      <div class="sidebar-section stats-section">
        <div class="stats-grid">
          <div class="stat-item">
            <span class="stat-value">{{ schemaStore.schemaCounts.total }}</span>
            <span class="stat-label">Schemas</span>
          </div>
          <div class="stat-item">
            <span class="stat-value">{{ schemaStore.schemaCounts.types }}</span>
            <span class="stat-label">Types</span>
          </div>
          <div class="stat-item">
            <span class="stat-value">{{ schemaStore.schemaCounts.elements }}</span>
            <span class="stat-label">Elements</span>
          </div>
          <div class="stat-item">
            <span class="stat-value">{{ schemaStore.schemaCounts.groups }}</span>
            <span class="stat-label">Groups</span>
          </div>
          <div class="stat-item">
            <span class="stat-value">{{ schemaStore.schemaCounts.attributes }}</span>
            <span class="stat-label">Attrs</span>
          </div>
          <div class="stat-item">
            <span class="stat-value">{{ schemaStore.schemaCounts.attribute_groups }}</span>
            <span class="stat-label">Attr Groups</span>
          </div>
        </div>
      </div>
      <!-- Generator Footer -->
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
            Generated on {{ formatDate(schemaStore.metadata?.generated) }} with
            <a href="https://github.com/lutaml/lutaml-xsd" target="_blank" rel="noopener">LutaML XSD</a>
            v{{ schemaStore.metadata?.generator?.replace('lutaml-xsd v', '') || '?' }}
          </span>
        </div>
      </div>
    </div>
  </aside>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { useSchemaStore } from '@/stores/schemaStore'
import { useUiStore } from '@/stores/uiStore'
import SchemaTreeNode from '@/components/SchemaTreeNode.vue'
import type { Schema } from '@/types'

const schemaStore = useSchemaStore()
const uiStore = useUiStore()

const expandedNamespaces = ref(new Set<string>())
const squareLogoFailed = ref(false)

function logoSrc(logo: { light?: { path?: string; url?: string }; dark?: { path?: string; url?: string } }): string {
  const variant = uiStore.isDark ? logo.dark : logo.light
  return variant?.path || variant?.url || ''
}

// Find the namespace prefix containing the currently selected schema
const selectedNamespacePrefix = computed(() => {
  const selectedId = schemaStore.selectedSchemaId
  if (!selectedId) return null
  for (const ns of schemaStore.namespaces) {
    if (ns.schemas.includes(selectedId)) {
      return ns.prefix
    }
  }
  // Check orphan schemas
  const orphanNs = schemaStore.schemas.filter(s => {
    for (const ns of schemaStore.namespaces) {
      if (ns.schemas.includes(s.id)) return false
    }
    return true
  })
  if (orphanNs.find(s => s.id === selectedId)) return '__default__'
  return null
})

// Auto-expand the namespace when selection changes (but don't auto-collapse)
watch(() => schemaStore.selectedSchemaId, (newId) => {
  if (newId) {
    for (const ns of schemaStore.namespaces) {
      if (ns.schemas.includes(newId)) {
        expandedNamespaces.value.add(ns.prefix)
        break
      }
    }
    // Check orphan schemas
    const isOrphan = !schemaStore.namespaces.some(ns => ns.schemas.includes(newId))
    if (isOrphan) {
      expandedNamespaces.value.add('__default__')
    }
  }
}, { immediate: false })

function toggleNamespaceExpanded(prefix: string) {
  if (expandedNamespaces.value.has(prefix)) {
    expandedNamespaces.value.delete(prefix)
  } else {
    expandedNamespaces.value.add(prefix)
  }
}

function getSchemaById(schemaId: string): Schema {
  return schemaStore.schemas.find(s => s.id === schemaId) as Schema
}

function goHome() {
  schemaStore.selectSchema(null)
  uiStore.closeDetailPanel()
}

const schemasInNamespaces = computed(() => {
  const nsSchemas = new Set<string>()
  for (const ns of schemaStore.namespaces) {
    for (const sId of ns.schemas) {
      nsSchemas.add(sId)
    }
  }
  return nsSchemas
})

const orphanSchemas = computed(() =>
  schemaStore.schemas.filter(s => !schemasInNamespaces.value.has(s.id))
)

// W3C namespace prefixes that should be separated out
const w3cPrefixes = new Set(['xs', 'xsd', 'xlink', 'xml', 'xmlns'])

// Check if a namespace URI is a W3C namespace
function isW3cNamespace(ns: { prefix: string; uri: string }): boolean {
  if (w3cPrefixes.has(ns.prefix)) return true
  if (ns.uri.includes('w3.org')) return true
  return false
}

// Non-W3C namespaces (user namespaces) with entrypoint schemas first
const userNamespaces = computed(() => {
  const nonW3c = schemaStore.namespaces.filter(ns => !isW3cNamespace(ns))
  // Sort: entrypoint schemas first
  return [...nonW3c].sort((a, b) => {
    const aHasEntrypoint = a.schemas.some(id => {
      const schema = schemaStore.schemas.find(s => s.id === id)
      return schema?.is_entrypoint
    })
    const bHasEntrypoint = b.schemas.some(id => {
      const schema = schemaStore.schemas.find(s => s.id === id)
      return schema?.is_entrypoint
    })
    if (aHasEntrypoint && !bHasEntrypoint) return -1
    if (!aHasEntrypoint && bHasEntrypoint) return 1
    return 0
  })
})

// W3C namespaces
const w3cNamespaces = computed(() =>
  schemaStore.namespaces.filter(ns => isW3cNamespace(ns))
)

function truncateUri(uri: string): string {
  if (!uri) return ''
  if (uri.length <= 50) return uri
  return uri.slice(0, 47) + '...'
}

function formatDate(isoString?: string): string {
  if (!isoString) return ''
  try {
    const date = new Date(isoString)
    return date.toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' })
  } catch {
    return isoString
  }
}
</script>

<style scoped>
.sidebar {
  width: 280px;
  flex-shrink: 0;
  background: var(--bg-secondary);
  border-right: 1px solid var(--border-light);
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
  color: var(--color-primary);
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

.w3c-section-header {
  margin-top: var(--space-5);
  padding-top: var(--space-4);
  border-top: 1px solid var(--border-light);
}

.namespace-tree {
  display: flex;
  flex-direction: column;
  gap: var(--space-1);
}

.namespace-node {
  border-radius: var(--radius-sm);
}

.namespace-node-header {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  padding: var(--space-1) var(--space-2);
  cursor: pointer;
  transition: background var(--transition-fast);
  font-size: var(--text-sm);
}

.namespace-node-header:hover {
  background: var(--bg-hover);
}

.namespace-node-header.active {
  background: var(--color-primary-alpha);
}

.namespace-node-header.active .namespace-prefix {
  color: var(--color-primary);
}

.namespace-node-header.active svg {
  color: var(--color-primary);
}

.namespace-node-header svg {
  color: var(--text-muted);
  transition: transform var(--transition-fast);
  flex-shrink: 0;
}

.namespace-node-header svg.expanded {
  transform: rotate(90deg);
}

.namespace-prefix {
  flex: 1;
  font-weight: 500;
  color: var(--text-primary);
}

.namespace-schema-count {
  font-size: var(--text-xs);
  color: var(--text-muted);
  background: var(--bg-primary);
  padding: 1px 5px;
  border-radius: var(--radius-sm);
}

.namespace-details {
  padding: 0 var(--space-2) var(--space-1);
  padding-left: calc(var(--space-2) + 16px);
}

.namespace-uri {
  font-size: var(--text-xs);
  color: var(--text-muted);
  font-family: var(--font-mono, monospace);
  word-break: break-all;
  line-height: 1.4;
}

.namespace-schemas {
  margin-left: var(--space-4);
}

.schema-tree {
  display: flex;
  flex-direction: column;
  gap: var(--space-1);
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
  flex-direction: row;
  align-items: center;
  gap: var(--space-3);
}

.footer-text-group {
  display: flex;
  flex-direction: column;
  gap: 2px;
  text-align: left;
}

.lutaml-logo {
  height: 18px;
  flex-shrink: 0;
  opacity: 0.7;
}

.footer-text {
  font-size: var(--text-xs);
  color: var(--text-muted);
}

.footer-text a {
  color: var(--color-primary);
  text-decoration: none;
}

.footer-text a:hover {
  text-decoration: underline;
}

.footer-date {
  font-size: var(--text-xs);
  color: var(--text-muted);
}

.footer-brand {
  display: flex;
  align-items: center;
  flex-shrink: 0;
}

.footer-meta {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--space-2);
  margin-left: auto;
  padding-left: var(--space-3);
  border-left: 1px solid var(--border-light);
}

.meta-link {
  font-size: var(--text-xs);
  color: var(--color-primary);
  text-decoration: none;
}

.meta-link:hover {
  text-decoration: underline;
}

.meta-author {
  font-size: var(--text-xs);
  color: var(--text-muted);
}

.meta-badge {
  font-size: 10px;
  padding: 1px 4px;
  background: var(--bg-secondary);
  color: var(--text-muted);
  border-radius: var(--radius-sm);
}

.meta-tag {
  font-size: 10px;
  padding: 1px 4px;
  background: var(--color-primary-alpha);
  color: var(--color-primary);
  border-radius: var(--radius-sm);
}
</style>

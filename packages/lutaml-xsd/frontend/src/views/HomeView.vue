<template>
  <div class="home-view">
    <div v-if="schemaStore.selectedSchema" class="selected-schema">
      <div class="schema-header">
        <h1>{{ schemaStore.selectedSchema.name }}</h1>
        <div class="schema-actions">
          <button class="btn btn-secondary" @click="uiStore.openDetailPanel">
            View Details
          </button>
        </div>
      </div>

      <div class="schema-tabs">
        <button
          v-for="tab in tabs"
          :key="tab.id"
          class="tab-btn"
          :class="{ active: activeTab === tab.id }"
          @click="activeTab = tab.id"
        >
          {{ tab.label }}
          <span class="tab-count">{{ tab.count }}</span>
        </button>
      </div>

      <div class="tab-content">
        <!-- Types Tab -->
        <div v-if="activeTab === 'types'" class="types-grid">
          <div
            v-for="type in allTypes"
            :key="type.id"
            class="type-card card"
            @click="selectType(type)"
          >
            <div class="type-card-header">
              <span :class="['badge', type.type === 'complex' ? 'badge-complex' : 'badge-simple']">
                {{ type.type === 'complex' ? 'Complex' : 'Simple' }}
              </span>
              <span v-if="type.deprecated" class="badge" style="background: var(--color-accent-alpha); color: var(--color-accent)">deprecated</span>
            </div>
            <h3 class="type-name">{{ type.name }}</h3>
            <p v-if="type.base" class="type-base">Base: {{ type.base }}</p>
            <div class="type-stats">
              <span v-if="getTypeElements(type) > 0">{{ getTypeElements(type) }} elements</span>
              <span v-if="getTypeAttributes(type) > 0">{{ getTypeAttributes(type) }} attributes</span>
            </div>
          </div>
        </div>

        <!-- Elements Tab -->
        <div v-if="activeTab === 'elements'" class="elements-list">
          <div
            v-for="element in schemaStore.selectedSchema.elements"
            :key="element.id"
            class="element-row"
            @click="selectElement(element)"
          >
            <span class="badge badge-element">E</span>
            <span class="element-name">{{ element.name }}</span>
            <span class="element-type">{{ element.type || 'xs:anyType' }}</span>
            <span v-if="element.occurs" class="element-occurs">{{ formatOccurs(element.occurs) }}</span>
          </div>
        </div>

        <!-- Attributes Tab -->
        <div v-if="activeTab === 'attributes'" class="attributes-list">
          <div
            v-for="attr in schemaStore.selectedSchema.attributes"
            :key="attr.id"
            class="attribute-row"
            @click="selectAttr(attr)"
          >
            <span class="badge badge-attribute">A</span>
            <span class="attribute-name">{{ attr.name }}</span>
            <span class="attribute-type">{{ attr.type || 'xs:string' }}</span>
            <span v-if="attr.use" :class="['attribute-use', attr.use]">{{ attr.use }}</span>
          </div>
        </div>

        <!-- Groups Tab -->
        <div v-if="activeTab === 'groups'" class="groups-list">
          <div
            v-for="group in schemaStore.selectedSchema.groups"
            :key="group.id"
            class="group-row"
            @click="selectGroup(group)"
          >
            <span class="badge badge-group">G</span>
            <span class="group-name">{{ group.name }}</span>
            <!-- <span v-if="group.elements?.length" class="group-count">{{ group.elements.length }} elements</span> -->
          </div>
        </div>

        <!-- Attribute Groups Tab -->
        <div v-if="activeTab === 'attrgroups'" class="attrgroups-list">
          <div
            v-for="ag in schemaStore.selectedSchema.attribute_groups"
            :key="ag.id"
            class="attrgroup-row"
            @click="selectAttrGroup(ag)"
          >
            <span class="badge badge-attrgroup">AG</span>
            <span class="attrgroup-name">{{ ag.name }}</span>
            <span v-if="ag.attributes?.length" class="attrgroup-count">{{ ag.attributes.length }} attributes</span>
          </div>
        </div>
      </div>
    </div>

    <div v-else class="landing-page">
      <!-- Long Logo and Header -->
      <div class="landing-header">
        <img
          v-if="schemaStore.metadata?.appearance?.logos?.long && !longLogoFailed"
          :src="logoSrc(schemaStore.metadata.appearance.logos.long)"
          alt="Package logo"
          class="landing-logo"
          @error="longLogoFailed = true"
        />
        <div class="landing-badges">
          <span v-if="schemaStore.metadata?.license" class="badge badge-license">
            <a v-if="schemaStore.metadata?.license_url" :href="schemaStore.metadata.license_url" target="_blank" rel="noopener" class="license-link">
              {{ schemaStore.metadata.license }}
            </a>
            <span v-else>{{ schemaStore.metadata.license }}</span>
          </span>
          <span v-for="tag in (schemaStore.metadata?.tags || []).slice(0, 4)" :key="tag" class="badge badge-tag">{{ tag }}</span>
        </div>
        <h1>{{ schemaStore.metadata?.title || schemaStore.metadata?.name || 'XSD Schema Documentation' }}</h1>
        <p v-if="schemaStore.metadata?.description" class="landing-description">{{ schemaStore.metadata.description }}</p>
        <div class="landing-subtitle">
          <span>{{ schemaStore.schemaCounts.total }} schemas</span>
          <span class="separator">·</span>
          <span>{{ schemaStore.schemaCounts.types }} types</span>
          <span class="separator">·</span>
          <span>{{ schemaStore.schemaCounts.elements }} elements</span>
        </div>
        <div v-if="schemaStore.metadata?.authors?.length" class="landing-authors">
          <span v-for="(author, i) in schemaStore.metadata.authors" :key="i" class="author">
            {{ author.name }}<span v-if="author.email"> &lt;{{ author.email }}&gt;</span>
          </span>
        </div>
        <div v-if="hasLinks" class="landing-links">
          <a v-for="link in schemaStore.metadata?.links" :key="link.name" :href="link.url" target="_blank" rel="noopener" class="btn btn-secondary">
            {{ link.name }}
          </a>
        </div>
      </div>
      <div class="schema-grid">
        <div
          v-for="schema in schemaStore.schemas"
          :key="schema.id"
          class="schema-card card"
          @click="selectSchema(schema.id)"
        >
          <div class="schema-card-icon">
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
              <rect x="3" y="3" width="18" height="18" rx="2" stroke="currentColor" stroke-width="1.5"/>
              <path d="M7 8h10M7 12h6M7 16h8" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>
            </svg>
          </div>
          <div class="schema-card-content">
            <h3>{{ schema.name }}</h3>
            <p v-if="schema.namespace" class="schema-ns">{{ schema.namespace }}</p>
            <div class="schema-card-stats">
              <span>{{ (schema.complex_types?.length || 0) + (schema.simple_types?.length || 0) }} types</span>
              <span>{{ schema.elements?.length || 0 }} elements</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { useSchemaStore } from '@/stores/schemaStore'
import { useUiStore } from '@/stores/uiStore'
import type { ComplexType, SimpleType, SchemaElement, GroupRef, AttributeGroup, SchemaAttribute } from '@/types'

type DisplayType = (ComplexType & { type: 'complex' }) | (SimpleType & { type: 'simple' })

type TabId = 'types' | 'elements' | 'attributes' | 'groups' | 'attrgroups'

const schemaStore = useSchemaStore()
const uiStore = useUiStore()

const activeTab = ref<TabId>('types')
const longLogoFailed = ref(false)

function logoSrc(logo: { light?: { path?: string; url?: string }; dark?: { path?: string; url?: string } }): string {
  const variant = uiStore.isDark ? logo.dark : logo.light
  return variant?.path || variant?.url || ''
}

const tabs = computed(() => {
  type Tab = { id: TabId; label: string; count: number }
  const t: Tab[] = [
    { id: 'types', label: 'Types', count: allTypes.value.length },
    { id: 'elements', label: 'Elements', count: schemaStore.selectedSchema?.elements?.length || 0 },
    { id: 'attributes', label: 'Attributes', count: schemaStore.selectedSchema?.attributes?.length || 0 },
  ]
  if ((schemaStore.selectedSchema?.groups?.length || 0) > 0) {
    t.push({ id: 'groups', label: 'Groups', count: schemaStore.selectedSchema?.groups?.length || 0 })
  }
  if ((schemaStore.selectedSchema?.attribute_groups?.length || 0) > 0) {
    t.push({ id: 'attrgroups', label: 'Attr. Groups', count: schemaStore.selectedSchema?.attribute_groups?.length || 0 })
  }
  return t
})

const allTypes = computed<DisplayType[]>(() => {
  if (!schemaStore.selectedSchema) return []
  const complex = (schemaStore.selectedSchema.complex_types || []).map(t => ({ ...t, type: 'complex' as const }))
  const simple = (schemaStore.selectedSchema.simple_types || []).map(t => ({ ...t, type: 'simple' as const }))
  return [...complex, ...simple] as DisplayType[]
})

function selectType(type: DisplayType) {
  schemaStore.selectType(type.id)
  uiStore.openDetailPanel()
}

function selectSchema(schemaId: string) {
  schemaStore.selectSchema(schemaId)
}

function selectElement(element: SchemaElement) {
  schemaStore.selectType(element.id)
  uiStore.openDetailPanel()
}

function selectGroup(group: GroupRef) {
  schemaStore.selectType(group.id)
  uiStore.openDetailPanel()
}

function selectAttrGroup(ag: AttributeGroup) {
  schemaStore.selectType(ag.id)
  uiStore.openDetailPanel()
}

function selectAttr(attr: SchemaAttribute) {
  schemaStore.selectType(attr.id)
  uiStore.openDetailPanel()
}

function formatOccurs(occurs?: { min: number; max?: number | 'unbounded' }): string {
  if (!occurs) return '[1..1]'
  if (occurs.max === undefined || occurs.max === 'unbounded') {
    return occurs.min === 0 ? '[0..*]' : `[${occurs.min}..*]`
  }
  if (occurs.min === occurs.max) return `[${occurs.min}..${occurs.max}]`
  return `[${occurs.min}..${occurs.max}]`
}

function getTypeElements(type: DisplayType) {
  return type.type === 'complex' ? type.elements?.length || 0 : 0
}

function getTypeAttributes(type: DisplayType) {
  return type.type === 'complex' ? type.attributes?.length || 0 : 0
}

const hasLinks = computed(() => {
  return !!(schemaStore.metadata?.links?.length)
})
</script>

<style scoped>
.home-view {
  max-width: 1200px;
  margin: 0 auto;
}

.schema-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: var(--space-6);
}

.schema-header h1 {
  font-size: var(--text-2xl);
}

.schema-tabs {
  display: flex;
  gap: var(--space-1);
  margin-bottom: var(--space-4);
  border-bottom: 1px solid var(--border-light);
  padding-bottom: var(--space-2);
}

.tab-btn {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  padding: var(--space-2) var(--space-3);
  font-size: var(--text-sm);
  font-weight: 500;
  color: var(--text-muted);
  border-radius: var(--radius-md);
  transition: all var(--transition-fast);
}

.tab-btn:hover {
  color: var(--text-primary);
  background: var(--bg-hover);
}

.tab-btn.active {
  color: var(--color-primary);
  background: var(--color-primary-alpha);
}

.tab-count {
  font-size: var(--text-xs);
  background: var(--bg-secondary);
  padding: 1px 6px;
  border-radius: var(--radius-sm);
}

.types-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: var(--space-4);
}

.type-card {
  padding: var(--space-4);
  cursor: pointer;
  transition: all var(--transition-fast);
}

.type-card:hover {
  border-color: var(--color-primary);
  box-shadow: var(--shadow-md);
}

.type-card-header {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  margin-bottom: var(--space-2);
}

.type-name {
  font-size: var(--text-base);
  font-weight: 600;
  margin-bottom: var(--space-1);
}

.type-base {
  font-size: var(--text-sm);
  color: var(--text-muted);
}

.type-stats {
  display: flex;
  gap: var(--space-3);
  margin-top: var(--space-2);
  font-size: var(--text-xs);
  color: var(--text-muted);
}

.elements-list,
.attributes-list {
  display: flex;
  flex-direction: column;
  gap: var(--space-2);
}

.element-row,
.attribute-row {
  display: flex;
  align-items: center;
  gap: var(--space-3);
  padding: var(--space-3);
  background: var(--bg-elevated);
  border: 1px solid var(--border-light);
  border-radius: var(--radius-md);
  cursor: pointer;
  transition: all var(--transition-fast);
}

.element-row:hover,
.attribute-row:hover {
  border-color: var(--color-primary);
  background: var(--color-primary-alpha);
}

.element-name,
.attribute-name {
  font-weight: 500;
  min-width: 150px;
}

.element-type,
.attribute-type {
  color: var(--color-primary);
  flex: 1;
}

.element-occurs,
.attribute-use {
  font-size: var(--text-sm);
  color: var(--text-muted);
}

.attribute-use.required {
  color: var(--color-primary);
  font-weight: 500;
}

.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: var(--space-12);
  text-align: center;
  color: var(--text-muted);
}

.empty-state svg {
  margin-bottom: var(--space-4);
  color: var(--border-medium);
}

.empty-state h2 {
  font-size: var(--text-lg);
  color: var(--text-secondary);
  margin-bottom: var(--space-2);
}

.empty-state p {
  font-size: var(--text-sm);
  max-width: 300px;
}

.landing-page {
  padding: var(--space-6);
  max-width: 1200px;
  margin: 0 auto;
}

.landing-header {
  margin-bottom: var(--space-8);
}

.landing-header {
  margin-bottom: var(--space-8);
}

.landing-logo {
  height: 64px;
  width: auto;
  margin-bottom: var(--space-4);
}

.landing-header h1 {
  font-size: var(--text-2xl);
  margin-bottom: var(--space-2);
}

.landing-badges {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-2);
  margin-bottom: var(--space-3);
}

.badge-license {
  background: var(--color-primary-alpha);
  color: var(--color-primary);
}

.license-link {
  color: inherit;
  text-decoration: none;
}

.license-link:hover {
  text-decoration: underline;
}

.badge-tag {
  background: var(--bg-secondary);
  color: var(--text-secondary);
}

.landing-description {
  font-size: var(--text-base);
  color: var(--text-secondary);
  line-height: var(--leading-relaxed);
  margin-bottom: var(--space-3);
  max-width: 700px;
}

.landing-subtitle {
  color: var(--text-muted);
  font-size: var(--text-sm);
  margin-bottom: var(--space-3);
}

.landing-authors {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-3);
  font-size: var(--text-sm);
  color: var(--text-secondary);
  margin-bottom: var(--space-4);
}

.author {
  display: flex;
  align-items: center;
  gap: var(--space-1);
}

.author span {
  color: var(--text-muted);
  font-size: var(--text-xs);
}

.landing-links {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-2);
}

.schema-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: var(--space-4);
}

.schema-card {
  display: flex;
  align-items: flex-start;
  gap: var(--space-3);
  padding: var(--space-4);
  cursor: pointer;
  transition: all var(--transition-fast);
}

.schema-card:hover {
  border-color: var(--color-primary);
  box-shadow: var(--shadow-md);
}

.schema-card-icon {
  color: var(--color-primary);
  flex-shrink: 0;
  margin-top: 2px;
}

.schema-card-content {
  flex: 1;
  min-width: 0;
}

.schema-card-content h3 {
  font-size: var(--text-base);
  font-weight: 600;
  margin-bottom: var(--space-1);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.schema-ns {
  font-size: var(--text-xs);
  color: var(--text-muted);
  font-family: var(--font-mono);
  margin-bottom: var(--space-2);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.schema-card-stats {
  display: flex;
  gap: var(--space-3);
  font-size: var(--text-xs);
  color: var(--text-muted);
}

.groups-list,
.attrgroups-list {
  display: flex;
  flex-direction: column;
  gap: var(--space-2);
}

.group-row,
.attrgroup-row {
  display: flex;
  align-items: center;
  gap: var(--space-3);
  padding: var(--space-3);
  background: var(--bg-elevated);
  border: 1px solid var(--border-light);
  border-radius: var(--radius-md);
  cursor: pointer;
  transition: all var(--transition-fast);
}

.group-row:hover,
.attrgroup-row:hover {
  border-color: var(--color-primary);
  background: var(--color-primary-alpha);
}

.group-name,
.attrgroup-name {
  font-weight: 500;
  min-width: 150px;
}

.group-count,
.attrgroup-count {
  font-size: var(--text-sm);
  color: var(--text-muted);
  flex: 1;
}
</style>

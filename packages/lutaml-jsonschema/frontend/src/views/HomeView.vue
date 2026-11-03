<template>
  <div class="home-view">
    <!-- Schema Detail Mode -->
    <div v-if="schemaStore.selectedSchema" class="selected-schema">
      <div class="schema-header">
        <div v-if="schemaStore.selectedDefinitionName" class="schema-breadcrumb">
          <button class="breadcrumb-link" @click="schemaStore.clearSelection()">{{ schemaStore.selectedSchema?.title || schemaStore.selectedSchema?.name }}</button>
          <span class="breadcrumb-sep">/</span>
          <span class="breadcrumb-current">{{ selectedDefinitionTitle }}</span>
        </div>
        <div class="schema-header-info">
          <div class="schema-title-row">
            <h1 class="heading-with-anchor" @mouseenter="hoveredHeading = 'schema'" @mouseleave="hoveredHeading = ''">
              {{ schemaStore.selectedSchema.title || schemaStore.selectedSchema.name }}
              <button v-show="hoveredHeading === 'schema'" class="heading-anchor" @click.stop="copyCurrentLink" title="Copy link to this schema" aria-label="Copy link">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none"><path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>
              </button>
            </h1>
            <div class="schema-actions">
              <div class="view-toggle">
                <button class="toggle-btn" :class="{ active: viewMode === 'builder' }" @click="viewMode = 'builder'">Builder</button>
                <button class="toggle-btn" :class="{ active: viewMode === 'source' }" @click="viewMode = 'source'">Source</button>
              </div>
              <button
                class="btn btn-outline btn-sm copy-btn-wrap"
                @click="copyCurrentLink"
              >
                Copy Link
                <span v-if="linkCopied" class="copy-tooltip">Copied!</span>
              </button>
              <button
                v-if="schemaStore.selectedSchema.sourceJson"
                class="btn btn-outline btn-sm"
                @click="downloadSchema(schemaStore.selectedSchema)"
              >
                Download JSON
              </button>
            </div>
          </div>
          <span v-if="schemaStore.selectedSchema.title && schemaStore.selectedSchema.title !== schemaStore.selectedSchema.name" class="schema-name-hint font-mono text-muted">{{ schemaStore.selectedSchema.name }}</span>
          <SeeMore v-if="schemaStore.selectedSchema.description" max-height="4.8em">
            <p class="schema-desc text-secondary md-content" v-html="renderInlineMarkdown(schemaStore.selectedSchema.description)"></p>
          </SeeMore>
          <div class="schema-meta-row">
            <span class="badge badge-type">{{ schemaStore.selectedSchema.type || 'any' }}</span>
            <span class="meta-count">{{ schemaStore.selectedSchema.properties.length }} properties</span>
            <span v-if="schemaStore.selectedSchema.required.length" class="meta-count meta-count-req">{{ schemaStore.selectedSchema.required.length }} required</span>
            <span v-if="schemaStore.selectedSchema.definitions.length" class="meta-count">{{ schemaStore.selectedSchema.definitions.length }} definitions</span>
            <span v-if="schemaStore.selectedSchema.additionalProperties === false" class="badge badge-locked">no additional properties</span>
            <span v-if="schemaStore.selectedSchema.hasAllOf" class="badge badge-composition">allOf</span>
            <span v-if="schemaStore.selectedSchema.hasAnyOf" class="badge badge-composition">anyOf</span>
            <span v-if="schemaStore.selectedSchema.hasOneOf" class="badge badge-composition">oneOf</span>
            <span v-if="schemaPropsRange" class="badge badge-range">{{ schemaPropsRange }}</span>
          </div>
          <div v-if="schemaStore.selectedSchema.$schema || schemaStore.selectedSchema.$id" class="schema-id-row">
            <span v-if="schemaStore.selectedSchema.$schema" class="meta-id-chip font-mono text-muted" title="JSON Schema version">
              <a v-if="isUrl(schemaStore.selectedSchema.$schema)" :href="schemaStore.selectedSchema.$schema" target="_blank" rel="noopener">{{ schemaStore.selectedSchema.$schema }}</a>
              <template v-else>{{ schemaStore.selectedSchema.$schema }}</template>
            </span>
            <span v-if="schemaStore.selectedSchema.$id" class="meta-id-chip font-mono text-muted" title="Schema $id">
              <a v-if="isUrl(schemaStore.selectedSchema.$id)" :href="schemaStore.selectedSchema.$id" target="_blank" rel="noopener">{{ schemaStore.selectedSchema.$id }}</a>
              <template v-else>{{ schemaStore.selectedSchema.$id }}</template>
            </span>
          </div>
          <div v-if="schemaStore.selectedSchema.required.length" class="schema-required">
            <span class="required-label text-muted">Required:</span>
            <div class="required-tags">
              <span v-for="r in schemaStore.selectedSchema.required" :key="r" class="required-tag">{{ r }}</span>
            </div>
          </div>
          <details v-if="schemaStore.selectedSchema.examples?.length" class="schema-examples-details">
            <summary class="examples-summary text-muted">Examples ({{ schemaStore.selectedSchema.examples.length }})</summary>
            <pre class="examples-pre jv-viewer" v-html="renderExamplesJson(schemaStore.selectedSchema.examples)"></pre>
          </details>
        </div>
      </div>

      <!-- Builder View -->
      <template v-if="viewMode === 'builder'">
      <!-- Properties -->
      <div class="schema-section">
        <div class="section-heading">
          Properties
          <span class="toolbar-field-count text-muted">{{ schemaStore.selectedSchema.properties.length }}</span>
        </div>
        <SchemaBuilder
          :properties="schemaStore.selectedSchema.properties"
          :required="schemaStore.selectedSchema.required"
          :schema="schemaStore.selectedSchema"
          :all-schemas="schemaStore.schemas"
        />
      </div>

      <!-- Definitions -->
      <div v-if="schemaStore.selectedSchema.definitions.length" class="schema-section">
        <div class="section-heading-row">
          <h2 class="section-heading">Definitions <span class="toolbar-field-count text-muted">{{ schemaStore.selectedSchema.definitions.length }}</span></h2>
          <div class="section-actions">
            <button class="btn btn-ghost btn-sm" @click="expandAllDefs">Expand All</button>
            <button class="btn btn-ghost btn-sm" @click="collapseAllDefs">Collapse All</button>
          </div>
        </div>
        <div class="def-list">
          <div
            v-for="def in schemaStore.selectedSchema.definitions"
            :key="def.name"
            :id="`def-${def.name}`"
            class="def-card card"
            :class="{ 'def-card-highlighted': def.name === schemaStore.selectedDefinitionName }"
          >
            <div class="def-card-header" role="button" tabindex="0" @click="toggleDef(def.name)" @keydown.enter="toggleDef(def.name)" @keydown.space.prevent="toggleDef(def.name)">
              <span class="def-chevron" :class="{ expanded: expandedDefs.has(def.name) }">&#9654;</span>
              <span class="def-card-title heading-with-anchor" @mouseenter="hoveredHeading = `def-${def.name}`" @mouseleave="hoveredHeading = ''">{{ def.title || def.name }}<button v-show="hoveredHeading === `def-${def.name}`" class="heading-anchor" @click.stop="copyDefLink(def.name)" title="Copy link" aria-label="Copy link to definition"><svg width="12" height="12" viewBox="0 0 24 24" fill="none"><path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg></button></span>
              <span v-if="def.title && def.title !== def.name" class="def-card-name font-mono text-muted">{{ def.name }}</span>
              <span v-if="def.type" class="def-type-badge">{{ def.type }}</span>
              <span class="def-header-pill">{{ def.properties.length }} props</span>
              <span v-if="def.required?.length" class="def-header-pill def-header-pill-req">{{ def.required.length }} req</span>
              <span v-if="def.examples?.length" class="def-header-pill">{{ def.examples.length }} examples</span>
              <span v-if="defPropsRange(def)" class="badge badge-range">{{ defPropsRange(def) }}</span>
              <span v-if="def.additionalProperties === false" class="badge badge-locked">no additional</span>
              <span v-if="def.hasAllOf" class="badge badge-composition">allOf</span>
              <span v-if="def.hasAnyOf" class="badge badge-composition">anyOf</span>
              <span v-if="def.hasOneOf" class="badge badge-composition">oneOf</span>
            </div>
            <div class="def-card-info">
              <p v-if="def.description" class="def-card-desc text-secondary md-content" :class="{ 'desc-truncated': !expandedDefs.has(def.name) }" v-html="renderInlineMarkdown(def.description)"></p>
              <div v-if="def.required?.length" class="def-card-required">
                <span v-for="r in def.required" :key="r" class="required-tag-sm">{{ r }}</span>
              </div>
              <details v-if="def.examples?.length" class="def-card-examples">
                <summary class="text-muted">Examples</summary>
                <pre class="def-examples-pre jv-viewer" v-html="renderExamplesJson(def.examples)"></pre>
              </details>
              <div v-if="!expandedDefs.has(def.name) && def.properties.length" class="def-mini-table">
                <div v-for="prop in miniTableProps(def.properties)" :key="prop.name" class="def-mini-row def-mini-row-clickable" :title="prop.description ? truncateMiniDesc(prop.description) : undefined" @click.stop="openPropertyDetail(prop.name)">
                  <span class="def-mini-bullet" aria-hidden="true"></span>
                  <span class="def-mini-name font-mono" :class="{ 'def-mini-deprecated': prop.deprecated, 'def-mini-required': prop.required }">{{ prop.name }}</span>
                  <span v-if="prop.ref" class="def-mini-ref" @click.stop="navigateToDefRef(prop.ref)">→ {{ defRefName(prop.ref) }}</span>
                  <template v-else>
                    <span class="def-mini-type" :class="miniTypeClass(prop.type)">{{ prop.type || 'any' }}</span>
                    <span v-if="prop.format" class="def-mini-format">&lt;{{ prop.format }}&gt;</span>
                    <span v-if="prop.itemsType" class="def-mini-items">[{{ prop.itemsType }}]</span>
                  </template>
                  <span v-if="prop.enum?.length" class="def-mini-enum">{{ prop.enum.length }} enum</span>
                  <span v-if="prop.uniqueItems" class="def-mini-unique">unique</span>
                  <span v-if="prop.compositionSource" class="def-mini-comp">{{ prop.compositionSource }}</span>
                  <span v-if="prop.const != null" class="def-mini-const">const: {{ prop.const }}</span>
                  <span v-else-if="prop.default != null" class="def-mini-default">default: {{ prop.default }}</span>
                  <span v-if="prop.deprecated" class="def-mini-dep">dep</span>
                </div>
                <div v-if="def.properties.length > 8" class="def-mini-more text-muted">
                  +{{ def.properties.length - 5 }} more properties
                </div>
              </div>
            </div>
            <Transition name="def-expand">
            <div v-if="expandedDefs.has(def.name)" class="def-card-body">
              <div class="def-body-header">
                <h3 class="def-body-title">{{ def.title || def.name }}</h3>
                <div class="def-body-meta">
                  <span v-if="def.type" class="def-type-badge">{{ def.type }}</span>
                  <span class="text-muted">{{ def.properties.length }} properties</span>
                  <span v-if="def.required?.length" class="text-muted">&middot; {{ def.required.length }} required</span>
                  <span v-if="def.hasAllOf" class="badge badge-composition">allOf</span>
                  <span v-if="def.hasAnyOf" class="badge badge-composition">anyOf</span>
                  <span v-if="def.hasOneOf" class="badge badge-composition">oneOf</span>
                  <span v-if="def.additionalProperties === false" class="badge badge-locked">no additional</span>
                  <span v-if="def.examples?.length" class="text-muted">&middot; {{ def.examples.length }} examples</span>
                </div>
                <div v-if="def.required?.length" class="def-body-required">
                  <span class="required-label text-muted">Required:</span>
                  <span v-for="r in def.required" :key="r" class="required-tag-sm">{{ r }}</span>
                </div>
              </div>
              <SeeMore v-if="def.description" max-height="4.8em">
                <div class="def-body-desc text-secondary md-content" v-html="renderInlineMarkdown(def.description)"></div>
              </SeeMore>
              <details v-if="def.examples?.length" class="def-card-examples def-body-examples">
                <summary class="text-muted">Examples ({{ def.examples.length }})</summary>
                <pre class="def-examples-pre jv-viewer" v-html="renderExamplesJson(def.examples)"></pre>
              </details>
              <SchemaBuilder
                :properties="def.properties"
                :required="def.required"
                :schema="schemaStore.selectedSchema"
                :all-schemas="schemaStore.schemas"
              />
            </div>
            </Transition>
          </div>
        </div>
      </div>
      </template>

      <!-- Source JSON View -->
      <div v-if="viewMode === 'source'" class="schema-section">
        <div v-if="schemaStore.selectedSchema.sourceJson" class="source-viewer">
          <div class="source-toolbar">
            <span class="text-muted">Source JSON Schema</span>
            <span class="toolbar-field-count text-muted">{{ sourceLineCount }} lines</span>
            <div class="source-toolbar-actions">
              <button class="btn btn-ghost btn-sm copy-btn-wrap" @click="copySource">
                Copy
                <span v-if="sourceCopied" class="copy-tooltip">Copied!</span>
              </button>
              <button class="btn btn-ghost btn-sm" @click="expandSourceAll">Expand all</button>
              <button class="btn btn-ghost btn-sm" @click="collapseSourceAll">Collapse all</button>
            </div>
          </div>
          <div class="source-code-wrapper">
            <pre ref="sourcePreRef" class="source-pre jv-viewer" @click="handleSourceClick" @keydown="handleSourceKey" @dblclick="selectSourceBlock"><code v-html="highlightedSource"></code></pre>
          </div>
        </div>
        <div v-else class="source-empty">
          <p class="text-muted">Source JSON Schema not available for this schema.</p>
        </div>
      </div>
    </div>

    <!-- Landing Page -->
    <main v-else class="landing-page">
      <div class="landing-header">
        <div>
          <div class="landing-title-row">
            <h1>{{ schemaStore.metadata?.title || 'JSON Schema Documentation' }}</h1>
            <span v-if="schemaStore.metadata?.version" class="version-badge">v{{ schemaStore.metadata.version }}</span>
          </div>
          <p v-if="schemaStore.metadata?.description" class="landing-description">{{ schemaStore.metadata.description }}</p>
          <div class="landing-subtitle">
            <span>{{ schemaStore.schemaCounts.schemas }} schemas</span>
            <span class="separator">&middot;</span>
            <span>{{ schemaStore.schemaCounts.properties }} properties</span>
            <span class="separator">&middot;</span>
            <span>{{ schemaStore.schemaCounts.definitions }} definitions</span>
            <template v-if="schemaStore.metadata?.baseUrl">
              <span class="separator">&middot;</span>
              <a :href="schemaStore.metadata.baseUrl" target="_blank" rel="noopener" class="landing-base-url">{{ schemaStore.metadata.baseUrl }}</a>
            </template>
          </div>
          <div v-if="schemaStore.schemas.length > 3" class="landing-search">
            <input
              v-model="landingSearch"
              type="text"
              class="landing-search-input"
              :placeholder="`Search ${schemaStore.schemas.length} schemas...`"
              aria-label="Search schemas"
            />
            <button v-if="landingSearch" class="landing-search-clear" aria-label="Clear search" @click="landingSearch = ''">
              <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
                <path d="M3 3l6 6M9 3l-6 6" stroke="currentColor" stroke-width="1.2" stroke-linecap="round"/>
              </svg>
            </button>
          </div>
        </div>
        <button
          v-if="hasSourceJson"
          class="btn btn-outline btn-sm"
          @click="downloadAllSchemas"
        >
          Download All Schemas
        </button>
      </div>

      <div class="schema-grid">
        <div
          v-for="schema in filteredSchemas"
          :key="schema.name"
          class="schema-card card"
          role="button"
          tabindex="0"
          @click="selectSchema(schema.name)"
          @keydown.enter="selectSchema(schema.name)"
          @keydown.space.prevent="selectSchema(schema.name)"
        >
          <div class="schema-card-icon">
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
              <rect x="3" y="3" width="18" height="18" rx="2" stroke="currentColor" stroke-width="1.5"/>
              <path d="M7 8h10M7 12h6M7 16h8" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>
            </svg>
          </div>
          <div class="schema-card-content">
            <h2>{{ schema.title || schema.name }}</h2>
            <span v-if="schema.title && schema.title !== schema.name" class="schema-card-name font-mono text-muted">{{ schema.name }}</span>
            <p v-if="schema.description" class="schema-card-desc text-secondary md-content" v-html="renderInlineMarkdown(schema.description)"></p>
            <div class="schema-card-meta">
              <span class="badge badge-type-sm">{{ schema.type || 'any' }}</span>
              <span v-if="schema.hasAllOf" class="badge badge-comp-sm">allOf</span>
              <span v-if="schema.hasAnyOf" class="badge badge-comp-sm">anyOf</span>
              <span v-if="schema.hasOneOf" class="badge badge-comp-sm">oneOf</span>
              <span v-if="schema.additionalProperties === false" class="badge badge-locked-sm">closed</span>
            </div>
            <div class="schema-card-stats">
              <span class="stat-pill">{{ schema.properties.length }} props</span>
              <span class="stat-pill">{{ schema.definitions.length }} defs</span>
              <span v-if="schema.required.length" class="stat-pill stat-required">{{ schema.required.length }} required</span>
              <span v-if="schema.examples?.length" class="stat-pill">{{ schema.examples.length }} examples</span>
              <span v-if="schema.minProperties != null" class="stat-pill">{{ schema.minProperties }} min</span>
              <span v-if="schema.maxProperties != null" class="stat-pill">{{ schema.maxProperties }} max</span>
            </div>
          </div>
        </div>
        <div v-if="!filteredSchemas.length && landingSearch" class="empty-state">
          <p class="text-muted">No schemas match "{{ landingSearch }}"</p>
          <button class="btn btn-ghost btn-sm" @click="landingSearch = ''">Clear search</button>
        </div>
      </div>
    </main>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, watch, nextTick } from 'vue'
import { useSchemaStore } from '../stores/schemaStore'
import { useUiStore } from '../stores/uiStore'
import SchemaBuilder from '../components/SchemaBuilder.vue'
import SeeMore from '../components/SeeMore.vue'
import { downloadFile } from '../composables/useDownload'
import { renderInlineMarkdown } from '../composables/useMarkdownLite'
import { jsonToCollapsibleHtml } from '../composables/useJsonViewer'
import { copyToClipboard } from '../composables/useClipboard'
import type { SpaSchema, SpaProperty, SpaDefinition } from '../types'

const schemaStore = useSchemaStore()
const uiStore = useUiStore()
const expandedDefs = reactive(new Set<string>())
const viewMode = ref<'builder' | 'source'>('builder')
const sourceCopied = ref(false)
const activeSourceLine = ref(-1)
const landingSearch = ref('')
const linkCopied = ref(false)
const hoveredHeading = ref('')
const sourcePreRef = ref<HTMLElement | null>(null)

const selectedDefinitionTitle = computed(() => {
  const name = schemaStore.selectedDefinitionName
  if (!name) return ''
  const def = schemaStore.selectedSchema?.definitions.find(d => d.name === name)
  return def?.title || name
})

const schemaPropsRange = computed(() => {
  const s = schemaStore.selectedSchema
  if (!s) return ''
  const min = s.minProperties
  const max = s.maxProperties
  if (min != null && max != null) return `[ ${min} .. ${max} ] properties`
  if (min != null) return min === 1 ? 'non-empty object' : `>= ${min} properties`
  if (max != null) return `<= ${max} properties`
  return ''
})

function defPropsRange(def: SpaDefinition): string {
  const min = def.minProperties
  const max = def.maxProperties
  if (min != null && max != null) return `[ ${min} .. ${max} ]`
  if (min != null) return `>= ${min} props`
  if (max != null) return `<= ${max} props`
  return ''
}

const filteredSchemas = computed(() => {
  const q = landingSearch.value.trim().toLowerCase()
  if (!q) return schemaStore.schemas
  return schemaStore.schemas.filter(s =>
    s.name.toLowerCase().includes(q) ||
    (s.title || '').toLowerCase().includes(q) ||
    (s.description || '').toLowerCase().includes(q) ||
    (s.type || '').toLowerCase().includes(q)
  )
})

function expandAllDefs() {
  for (const def of schemaStore.selectedSchema?.definitions ?? []) {
    expandedDefs.add(def.name)
  }
}

function collapseAllDefs() {
  expandedDefs.clear()
}

const highlightedSource = computed(() => {
  const src = schemaStore.selectedSchema?.sourceJson
  if (!src) return ''
  try {
    return jsonToCollapsibleHtml(JSON.parse(src), 2)
  } catch {
    return syntaxHighlight(src)
  }
})

const sourceLineCount = computed(() => {
  const src = schemaStore.selectedSchema?.sourceJson
  if (!src) return 0
  return src.split('\n').length
})

function copySource() {
  const src = schemaStore.selectedSchema?.sourceJson
  if (!src) return
  copyToClipboard(src).then(ok => {
    if (ok) {
      sourceCopied.value = true
      setTimeout(() => { sourceCopied.value = false }, 2000)
    }
  })
}

function syntaxHighlight(json: string): string {
  return json.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/("(\\u[\da-fA-F]{4}|\\[^u]|[^\\"])*"(\s*:)?|\b(true|false|null)\b|-?\d+(?:\.\d*)?(?:[eE][+-]?\d+)?)/g, (match) => {
      let cls = 'json-number'
      if (/^"/.test(match)) {
        cls = /:$/.test(match) ? 'json-key' : 'json-string'
      } else if (/true|false/.test(match)) {
        cls = 'json-boolean'
      } else if (/null/.test(match)) {
        cls = 'json-null'
      }
      // Detect URLs in string values and make them clickable
      if (cls === 'json-string') {
        const inner = match.slice(1, -1)
        if (/^https?:\/\/[^\s]+$/.test(inner)) {
          const href = inner.replace(/&amp;/g, '&')
          return `<span class="json-string">"</span><a class="json-url" href="${href}" target="_blank" rel="noopener">${match.slice(1)}</a>`
        }
      }
      return `<span class="${cls}">${match}</span>`
    })
}

function selectSourceBlock() {
  const el = sourcePreRef.value
  if (!el) return
  const range = document.createRange()
  range.selectNodeContents(el)
  const selection = window.getSelection()
  if (selection) {
    selection.removeAllRanges()
    selection.addRange(range)
  }
}

function handleSourceClick(event: MouseEvent) {
  const target = event.target as HTMLElement
  if (!target.classList.contains('jv-toggle')) return
  toggleSourceNode(target)
}

function handleSourceKey(event: KeyboardEvent) {
  const target = event.target as HTMLElement
  if (!target.classList.contains('jv-toggle')) return
  if (event.key === 'Enter' || event.key === ' ') {
    event.preventDefault()
    toggleSourceNode(target)
  }
}

function toggleSourceNode(target: HTMLElement) {
  const parent = target.parentElement
  if (!parent) return
  const children = parent.querySelector('.jv-children')
  if (!children) return
  const isCollapsed = children.classList.contains('jv-collapsed')
  if (isCollapsed) {
    children.classList.remove('jv-collapsed')
    target.setAttribute('aria-label', 'collapse')
  } else {
    children.classList.add('jv-collapsed')
    target.setAttribute('aria-label', 'expand')
  }
}

function expandSourceAll() {
  const container = sourcePreRef.value
  if (!container) return
  container.querySelectorAll('.jv-collapsed').forEach(el => el.classList.remove('jv-collapsed'))
  container.querySelectorAll('.jv-toggle').forEach(btn => btn.setAttribute('aria-label', 'collapse'))
}

function collapseSourceAll() {
  const container = sourcePreRef.value
  if (!container) return
  const children = container.querySelectorAll('.jv-children')
  children.forEach((el, i) => {
    if (i === 0) return
    el.classList.add('jv-collapsed')
  })
  container.querySelectorAll('.jv-toggle').forEach((btn, i) => {
    if (i === 0) return
    btn.setAttribute('aria-label', 'expand')
  })
}

function selectSchema(name: string) {
  schemaStore.selectSchema(name)
}

function toggleDef(name: string) {
  if (expandedDefs.has(name)) {
    expandedDefs.delete(name)
  } else {
    expandedDefs.add(name)
  }
}

function downloadSchema(schema: SpaSchema) {
  if (!schema.sourceJson) return
  downloadFile(`${schema.name}.json`, schema.sourceJson)
}

const hasSourceJson = computed(() =>
  schemaStore.schemas.some(s => s.sourceJson),
)

function formatJson(value: unknown): string {
  return JSON.stringify(value, null, 2)
}

function renderExamplesJson(examples: string[]): string {
  try {
    const parsed = examples.map(e => { try { return JSON.parse(e) } catch { return e } })
    return jsonToCollapsibleHtml(parsed.length === 1 ? parsed[0] : parsed, 2)
  } catch {
    return formatJson(examples)
  }
}

function isUrl(str: string): boolean {
  return /^https?:\/\//.test(str)
}

function defRefName(ref: string): string {
  const match = ref.match(/^#\/(?:definitions|\$defs)\/([^/]+)$/)
  return match ? match[1] : ref
}

function navigateToDefRef(ref: string) {
  const match = ref.match(/^#\/(?:definitions|\$defs)\/([^/]+)$/)
  if (match) {
    schemaStore.selectDefinition(match[1])
  }
}

function openPropertyDetail(propName: string) {
  schemaStore.selectProperty(propName)
  uiStore.openDetailPanel()
}

function miniTypeClass(type?: string): string {
  const t = (type || 'any').split(',')[0].trim()
  switch (t) {
    case 'string': return 'mini-type-string'
    case 'number': return 'mini-type-number'
    case 'integer': return 'mini-type-integer'
    case 'boolean': return 'mini-type-boolean'
    case 'object': return 'mini-type-object'
    case 'array': return 'mini-type-array'
    default: return ''
  }
}

function truncateMiniDesc(desc: string): string {
  return desc.length <= 120 ? desc : desc.slice(0, 117) + '...'
}

function miniTableProps(props: SpaProperty[]): SpaProperty[] {
  if (props.length <= 8) return props
  return props.slice(0, 5)
}

function downloadAllSchemas() {
  const bundle: Record<string, unknown> = {}
  for (const s of schemaStore.schemas) {
    if (s.sourceJson) {
      bundle[`${s.name}.json`] = JSON.parse(s.sourceJson)
    }
  }
  const name = schemaStore.metadata?.title || 'schemas'
  downloadFile(`${name.replace(/\s+/g, '-')}-bundle.json`, JSON.stringify(bundle, null, 2))
}

async function copyCurrentLink() {
  await copyToClipboard(window.location.href)
  linkCopied.value = true
  setTimeout(() => { linkCopied.value = false }, 2000)
}

async function copyDefLink(defName: string) {
  const url = `${window.location.origin}${window.location.pathname}#${encodeURIComponent(schemaStore.selectedSchema?.name || '')}/${encodeURIComponent(`def-${defName}`)}`
  await copyToClipboard(url)
  linkCopied.value = true
  setTimeout(() => { linkCopied.value = false }, 2000)
}

watch(() => schemaStore.selectedDefinitionName, (name) => {
  if (!name) return
  expandedDefs.add(name)
  nextTick(() => {
    const el = document.getElementById(`def-${name}`)
    if (el) {
      el.scrollIntoView({ behavior: 'smooth', block: 'center' })
    }
  })
})

watch(() => schemaStore.selectedItemKey, (key) => {
  if (!key) return
  nextTick(() => {
    let el: HTMLElement | null = null
    if (key.startsWith('def:')) {
      el = document.getElementById(`def-${key.slice(4)}`)
    } else if (key.startsWith('prop:')) {
      el = document.getElementById(`prop-${key.slice(5)}`)
    }
    if (el) {
      el.scrollIntoView({ behavior: 'smooth', block: 'center' })
    }
  })
})
</script>

<style scoped>
.home-view {
  max-width: 1400px;
  margin: 0 auto;
}

.schema-header {
  margin-bottom: var(--space-6);
  padding-bottom: var(--space-4);
  border-bottom: 1px solid var(--border-light);
}

.schema-breadcrumb {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  margin-bottom: var(--space-3);
  font-size: var(--text-sm);
}

.breadcrumb-link {
  background: none;
  border: none;
  color: var(--color-primary);
  cursor: pointer;
  padding: 0;
  font-size: var(--text-sm);
  font-weight: 500;
}

.breadcrumb-link:hover {
  text-decoration: underline;
}

.breadcrumb-sep {
  color: var(--text-muted);
}

.breadcrumb-current {
  color: var(--text-secondary);
  font-weight: 500;
}

.schema-header-info {
  width: 100%;
}

.schema-title-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-4);
  margin-bottom: var(--space-1);
}

.schema-title-row h1 {
  font-size: var(--text-2xl);
  margin: 0;
}

/* Redoc ShareLink pattern — hover-reveal anchor on headings */
.heading-with-anchor {
  position: relative;
  display: inline-flex;
  align-items: center;
  gap: var(--space-1);
}

.heading-anchor {
  background: none;
  border: none;
  color: var(--text-muted);
  cursor: pointer;
  padding: 2px;
  display: inline-flex;
  align-items: center;
  opacity: 0.5;
  transition: opacity var(--transition-fast);
}

.heading-anchor:hover {
  opacity: 1;
  color: var(--color-primary);
}

.def-card-title .heading-anchor {
  vertical-align: middle;
}

.schema-actions {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  flex-shrink: 0;
}

.view-toggle {
  display: flex;
  border: 1px solid var(--border-medium);
  border-radius: var(--radius-md);
  overflow: hidden;
}

.toggle-btn {
  padding: var(--space-1) var(--space-3);
  font-size: var(--text-xs);
  font-weight: 500;
  color: var(--text-muted);
  background: transparent;
  transition: all var(--transition-fast);
  border: none;
}

.toggle-btn:not(:last-child) {
  border-inline-end: 1px solid var(--border-medium);
}

.toggle-btn.active {
  background: var(--color-primary-alpha);
  color: var(--color-primary);
}

.toggle-btn:hover:not(.active) {
  background: var(--bg-hover);
  color: var(--text-primary);
}

.schema-name-hint {
  font-size: var(--text-xs);
  display: block;
  margin-bottom: var(--space-1);
}

.schema-desc {
  font-size: var(--text-base);
  margin-bottom: var(--space-2);
  line-height: var(--leading-relaxed);
}

.schema-meta-row {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  margin-top: var(--space-2);
  flex-wrap: wrap;
}

.schema-id-row {
  display: flex;
  gap: var(--space-2);
  margin-top: var(--space-2);
  flex-wrap: wrap;
}

.meta-id-chip {
  font-size: 10px;
  background: var(--bg-secondary);
  padding: 2px 6px;
  border-radius: var(--radius-sm);
  max-width: 400px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.meta-id-chip a {
  color: var(--color-primary);
  text-decoration: none;
}

.meta-id-chip a:hover {
  text-decoration: underline;
}

.badge-locked {
  font-size: 10px;
  color: var(--color-orange);
  background: var(--color-orange-alpha);
  padding: 2px 6px;
  border-radius: var(--radius-sm);
  font-weight: 500;
}

.badge-composition {
  font-size: 10px;
  color: var(--color-teal);
  background: var(--color-teal-alpha);
  padding: 2px 6px;
  border-radius: var(--radius-sm);
  font-weight: 500;
  font-family: var(--font-mono);
}

.badge-range {
  font-size: 10px;
  color: var(--text-secondary);
  background: var(--bg-secondary);
  padding: 2px 6px;
  border-radius: var(--radius-sm);
  font-family: var(--font-mono);
  font-weight: 500;
}

.meta-count {
  font-size: 11px;
  font-weight: 500;
  color: var(--color-primary);
  background: var(--color-primary-alpha);
  padding: 2px 8px;
  border-radius: 12px;
}

.meta-count-req {
  color: var(--schema-require-label);
  background: var(--schema-require-bg);
  font-weight: 500;
  border-radius: 12px;
}

.schema-required {
  display: flex;
  align-items: flex-start;
  gap: var(--space-2);
  margin-top: var(--space-3);
  flex-wrap: wrap;
}

.required-label {
  font-size: var(--text-xs);
  font-weight: 500;
  white-space: nowrap;
  padding-top: 2px;
}

.required-tags {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-1);
}

.required-tag {
  font-size: 11px;
  font-family: var(--font-mono);
  background: var(--schema-require-bg);
  color: var(--schema-require-label);
  padding: 2px 6px;
  border-radius: var(--radius-sm);
  font-weight: 500;
}

.required-tag-sm {
  font-size: 10px;
  font-family: var(--font-mono);
  background: var(--schema-require-bg);
  color: var(--schema-require-label);
  padding: 1px 4px;
  border-radius: 2px;
  font-weight: 500;
}

.schema-examples-details {
  margin-top: var(--space-3);
}

.examples-summary {
  font-size: var(--text-xs);
  font-weight: 500;
  cursor: pointer;
  padding: var(--space-1) 0;
}

.examples-summary:hover {
  color: var(--text-primary);
}

.examples-pre {
  background: var(--bg-secondary);
  border: 1px solid var(--border-light);
  border-radius: var(--radius-md);
  padding: var(--space-3);
  font-size: var(--text-sm);
  line-height: var(--leading-relaxed);
  overflow-x: auto;
  margin-top: var(--space-2);
  max-height: 300px;
  overflow-y: auto;
}

.examples-pre code {
  font-family: var(--font-mono);
  color: var(--text-primary);
}

.schema-section {
  margin-bottom: var(--space-6);
}

.section-heading {
  font-size: var(--text-lg);
  font-weight: 600;
  margin-bottom: var(--space-4);
  color: var(--text-primary);
  padding-bottom: var(--space-2);
  border-bottom: 1px solid var(--border-light);
  position: relative;
}

.section-heading::after {
  content: '';
  position: absolute;
  bottom: -1px;
  inset-inline-start: 0;
  width: 40px;
  height: 2px;
  background: var(--color-primary);
  border-radius: 1px;
}

.section-heading-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: var(--space-4);
  padding-bottom: var(--space-2);
  border-bottom: 1px solid var(--border-light);
  position: relative;
}

.section-heading-row::after {
  content: '';
  position: absolute;
  bottom: -1px;
  inset-inline-start: 0;
  width: 40px;
  height: 2px;
  background: var(--color-primary);
  border-radius: 1px;
}

.section-actions {
  display: flex;
  gap: var(--space-2);
}

/* Source viewer */
.source-viewer {
  border-radius: var(--radius-lg);
  overflow: hidden;
  border: 1px solid var(--border-light);
}

.source-toolbar {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  padding: var(--space-2) var(--space-3);
  background: var(--bg-secondary);
  border-bottom: 1px solid var(--border-light);
  font-size: var(--text-xs);
}

.source-toolbar-actions {
  display: flex;
  gap: var(--space-2);
}

/* Copy button tooltip */
.copy-btn-wrap {
  position: relative;
}

.copy-tooltip {
  position: absolute;
  bottom: calc(100% + 8px);
  left: 50%;
  transform: translateX(-50%);
  background: var(--bg-elevated);
  color: var(--text-primary);
  font-size: var(--text-xs);
  padding: 3px 8px;
  border-radius: var(--radius-sm);
  border: 1px solid var(--border-light);
  box-shadow: var(--shadow-md);
  white-space: nowrap;
  pointer-events: none;
  animation: tooltipFade var(--transition-slow);
}

.copy-tooltip::after {
  content: '';
  position: absolute;
  top: 100%;
  left: 50%;
  margin-left: -4px;
  border: 4px solid transparent;
  border-top-color: var(--bg-elevated);
}

@keyframes tooltipFade {
  from { opacity: 0; transform: translateX(-50%) translateY(2px); }
  to { opacity: 1; transform: translateX(-50%) translateY(0); }
}

.source-code-wrapper {
  max-height: 70vh;
  overflow: auto;
}

.source-pre :deep(.json-key) { color: var(--color-primary-dark); }
.source-pre :deep(.json-string) { color: var(--color-green); }
.source-pre :deep(.json-number) { color: var(--color-orange); }
.source-pre :deep(.json-boolean) { color: var(--color-accent); }
.source-pre :deep(.json-null) { color: var(--text-muted); }

.source-pre :deep(.json-url) {
  color: var(--color-green);
  text-decoration: underline;
  text-decoration-style: dotted;
}
.source-pre :deep(.json-url:hover) {
  text-decoration-style: solid;
}

:root[data-theme="dark"] .source-code-wrapper {
  background: var(--panel-dark-bg);
}
:root[data-theme="dark"] .source-pre {
  color: var(--panel-dark-text);
}
:root[data-theme="dark"] .source-toolbar {
  background: rgba(0, 0, 0, 0.15);
  border-bottom-color: rgba(255, 255, 255, 0.08);
  color: var(--panel-dark-muted);
}

.source-empty {
  padding: var(--space-8);
  text-align: center;
}

/* Definitions */
.def-list {
  display: flex;
  flex-direction: column;
  gap: var(--space-3);
}

.def-card {
  padding: 0;
  overflow: hidden;
}

.def-card-header {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  padding: var(--space-3) var(--space-4);
  cursor: pointer;
  transition: background var(--transition-fast);
}

.def-card-header:hover {
  background: var(--bg-hover);
}

.def-chevron {
  font-size: var(--schema-arrow-size);
  color: var(--schema-arrow-color);
  transition: transform var(--transition-fast);
  flex-shrink: 0;
}

.def-chevron.expanded {
  transform: rotate(90deg);
}

.def-card-title {
  font-weight: 600;
  font-size: var(--text-sm);
}

.def-card-name {
  font-size: var(--text-xs);
}

.def-header-req {
  font-size: 9px;
  font-family: var(--font-mono);
  color: var(--schema-require-label);
  background: var(--schema-require-bg);
  padding: 1px 4px;
  border-radius: 2px;
}

.def-header-pill {
  font-size: 10px;
  font-weight: 500;
  color: var(--text-muted);
  background: var(--bg-secondary);
  padding: 1px 6px;
  border-radius: 8px;
  flex-shrink: 0;
}

.def-header-pill-req {
  color: var(--schema-require-label);
  background: var(--schema-require-bg);
}

.def-type-badge {
  font-size: 11px;
  font-family: var(--font-mono);
  background: var(--badge-schema-bg);
  color: var(--badge-schema);
  padding: 1px 5px;
  border-radius: var(--radius-sm);
}

.def-card-desc {
  font-size: var(--text-sm);
  margin-bottom: var(--space-2);
}

.def-card-desc.desc-truncated {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.def-card-info {
  padding: 0 var(--space-4) var(--space-3);
  margin-top: calc(var(--space-1) * -1);
}

.def-card-required {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-1);
  margin-bottom: var(--space-2);
}

/* Mini property table */
.def-mini-table {
  margin-top: var(--space-2);
  border: 1px solid var(--border-light);
  border-radius: var(--radius-md);
  overflow: hidden;
  font-size: var(--text-xs);
}

.def-mini-row {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  padding: 3px var(--space-3);
  border-bottom: 1px solid var(--border-light);
  transition: background var(--transition-fast);
}

.def-mini-row:hover {
  background: var(--bg-hover);
}

.def-mini-row-clickable {
  cursor: pointer;
}

.def-mini-row:last-child {
  border-bottom: none;
}

.def-mini-row:nth-child(odd) {
  background: var(--bg-secondary);
}

.def-mini-bullet {
  display: inline-flex;
  align-items: center;
  color: var(--schema-lines);
  flex-shrink: 0;
}

.def-mini-bullet::before {
  content: '';
  display: inline-block;
  width: 6px;
  height: 1px;
  background: var(--schema-lines);
}

.def-mini-bullet::after {
  content: '';
  display: inline-block;
  width: 1px;
  height: 5px;
  background: var(--schema-lines);
}

.def-mini-name {
  font-weight: 500;
  color: var(--text-primary);
  flex: 1;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.def-mini-type {
  padding: 1px 5px;
  border-radius: var(--radius-sm);
  font-size: 10px;
  font-weight: 500;
  flex-shrink: 0;
  background: var(--badge-schema-bg);
  color: var(--badge-schema);
}

.def-mini-type.mini-type-string { background: var(--type-string-bg); color: var(--type-string); }
.def-mini-type.mini-type-number { background: var(--type-number-bg); color: var(--type-number); }
.def-mini-type.mini-type-integer { background: var(--type-integer-bg); color: var(--type-integer); }
.def-mini-type.mini-type-boolean { background: var(--type-boolean-bg); color: var(--type-boolean); }
.def-mini-type.mini-type-object { background: var(--type-object-bg); color: var(--type-object); }
.def-mini-type.mini-type-array { background: var(--type-array-bg); color: var(--type-array); }

.def-mini-req {
  color: var(--schema-require-label);
  font-weight: 700;
  font-size: 10px;
  flex-shrink: 0;
}

.def-mini-dep {
  color: var(--color-orange);
  background: var(--color-orange-alpha);
  padding: 1px 4px;
  border-radius: 2px;
  font-size: 9px;
  font-weight: 600;
  flex-shrink: 0;
}

.def-mini-format {
  font-size: 9px;
  color: var(--color-accent);
  font-family: var(--font-mono);
  flex-shrink: 0;
}

.def-mini-enum {
  font-size: 9px;
  color: var(--color-teal);
  background: var(--color-teal-alpha);
  padding: 0px 3px;
  border-radius: 2px;
  flex-shrink: 0;
}

.def-mini-comp {
  font-size: 8px;
  color: var(--color-teal);
  background: var(--color-teal-alpha);
  padding: 0px 3px;
  border-radius: 2px;
  font-family: var(--font-mono);
  flex-shrink: 0;
}

.def-mini-ref {
  font-size: 9px;
  color: var(--color-primary);
  font-family: var(--font-mono);
  cursor: pointer;
  flex-shrink: 0;
}

.def-mini-ref:hover {
  text-decoration: underline;
}

.def-mini-const {
  font-size: 9px;
  color: var(--color-primary);
  background: var(--color-primary-alpha);
  padding: 0px 3px;
  border-radius: 2px;
  flex-shrink: 0;
  max-width: 120px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-family: var(--font-mono);
}

.def-mini-default {
  font-size: 9px;
  color: var(--text-secondary);
  background: var(--bg-secondary);
  padding: 0px 3px;
  border-radius: 2px;
  flex-shrink: 0;
  max-width: 120px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-family: var(--font-mono);
}

.def-mini-deprecated {
  text-decoration: line-through;
  opacity: 0.6;
}

.def-mini-required {
  font-weight: 700;
}

.def-mini-required::after {
  content: ' *';
  color: var(--badge-required);
}

.def-mini-items {
  font-size: 9px;
  color: var(--text-muted);
  font-family: var(--font-mono);
  flex-shrink: 0;
}

.def-mini-unique {
  font-size: 9px;
  color: var(--color-teal);
  background: var(--color-teal-alpha);
  padding: 0px 3px;
  border-radius: 2px;
  flex-shrink: 0;
  font-weight: 500;
}

.def-mini-more {
  padding: 3px var(--space-3);
  font-size: var(--text-xs);
  border-top: 1px solid var(--border-light);
  text-align: center;
  font-style: italic;
}

.def-card-examples {
  margin-top: var(--space-2);
}

.def-card-examples summary {
  font-size: var(--text-xs);
  cursor: pointer;
}

.def-examples-pre {
  background: var(--bg-primary);
  border: 1px solid var(--border-light);
  border-radius: var(--radius-sm);
  padding: var(--space-2);
  font-size: var(--text-xs);
  overflow-x: auto;
  margin-top: var(--space-1);
  max-height: 200px;
  overflow-y: auto;
}

.def-examples-pre code {
  font-family: var(--font-mono);
  color: var(--text-primary);
}

.def-card-body {
  border-top: 1px solid var(--border-light);
  padding: var(--space-4);
  background: var(--bg-primary);
}

.def-body-header {
  margin-bottom: var(--space-3);
}

.def-body-title {
  font-size: var(--text-base);
  font-weight: 600;
  margin-bottom: var(--space-1);
  padding-bottom: var(--space-1);
  border-bottom: 1px solid var(--border-light);
  position: relative;
}

.def-body-title::after {
  content: '';
  position: absolute;
  bottom: -1px;
  inset-inline-start: 0;
  width: 32px;
  height: 2px;
  background: var(--color-primary);
  border-radius: 1px;
}

.def-body-meta {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  flex-wrap: wrap;
}

.def-body-meta .text-muted {
  font-size: 11px;
  font-weight: 500;
  color: var(--color-primary);
  background: var(--color-primary-alpha);
  padding: 1px 6px;
  border-radius: 10px;
}

.def-body-required {
  display: flex;
  align-items: center;
  gap: var(--space-1);
  margin-top: var(--space-1);
  flex-wrap: wrap;
}

.def-body-examples {
  margin-bottom: var(--space-3);
}

.def-body-desc {
  font-size: var(--text-sm);
  line-height: var(--leading-relaxed);
  margin-bottom: var(--space-4);
  padding-bottom: var(--space-3);
  border-bottom: 1px solid var(--border-light);
}

.def-card-highlighted {
  border-color: var(--color-primary);
  box-shadow: 0 0 0 2px var(--color-primary-alpha);
}

.badge-type {
  background: var(--badge-schema-bg);
  color: var(--badge-schema);
}

.badge-type-sm {
  background: var(--bg-secondary);
  color: var(--text-secondary);
  font-size: 10px;
}

.badge-comp-sm {
  font-size: 10px;
  color: var(--color-teal);
  background: var(--color-teal-alpha);
  padding: 1px 5px;
  border-radius: var(--radius-sm);
  font-weight: 500;
  font-family: var(--font-mono);
}

.badge-locked-sm {
  font-size: 10px;
  color: var(--color-orange);
  background: var(--color-orange-alpha);
  padding: 1px 5px;
  border-radius: var(--radius-sm);
  font-weight: 500;
}

/* Landing page */
.landing-page {
  padding: var(--space-6);
  max-width: 1200px;
  margin: 0 auto;
}

.landing-header {
  margin-bottom: var(--space-8);
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: var(--space-4);
}

.landing-header h1 {
  font-size: var(--text-2xl);
  margin-bottom: var(--space-2);
}

.landing-title-row {
  display: flex;
  align-items: center;
  gap: var(--space-3);
}

.landing-title-row h1 {
  margin-bottom: 0;
}

.version-badge {
  font-size: var(--text-sm);
  font-weight: 500;
  color: var(--text-muted);
  background: var(--bg-secondary);
  padding: 2px 8px;
  border-radius: var(--radius-md);
  border: 1px solid var(--border-light);
  font-family: var(--font-mono);
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

.landing-search {
  position: relative;
  max-width: 400px;
  margin-top: var(--space-3);
}

.landing-search-input {
  width: 100%;
  padding: 6px 28px 6px 10px;
  font-size: var(--text-sm);
  font-family: var(--font-sans);
  background: var(--bg-primary);
  border: 1px solid var(--border-light);
  border-radius: var(--radius-md);
  color: var(--text-primary);
}

.landing-search-input::placeholder {
  color: var(--text-muted);
}

.landing-search-input:focus {
  outline: none;
  border-color: var(--color-primary);
}

.landing-search-clear {
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

.landing-search-clear:hover {
  color: var(--text-primary);
}

.separator {
  margin: 0 var(--space-1);
}

.landing-base-url {
  color: var(--color-primary);
  text-decoration: none;
  font-size: var(--text-sm);
  font-family: var(--font-mono);
}

.landing-base-url:hover {
  text-decoration: underline;
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
  transform: translateY(-1px);
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
  margin-bottom: 2px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.schema-card-name {
  font-size: var(--text-xs);
  display: block;
  margin-bottom: var(--space-1);
}

.schema-card-desc {
  font-size: var(--text-sm);
  margin-bottom: var(--space-2);
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.schema-card-desc :deep(.md-pre) {
  display: none;
}

.schema-card-meta {
  margin-bottom: var(--space-2);
}

.schema-card-stats {
  display: flex;
  gap: var(--space-2);
  font-size: var(--text-xs);
  flex-wrap: wrap;
}

.stat-pill {
  color: var(--text-muted);
  background: var(--bg-secondary);
  padding: 1px 6px;
  border-radius: 8px;
  font-weight: 500;
  font-size: 10px;
}

.stat-required {
  color: var(--schema-require-label);
  background: var(--schema-require-bg);
}

.empty-state {
  padding: var(--space-8);
  text-align: center;
}

/* Definition card expand transition */
.def-expand-enter-active {
  transition: max-height 0.35s ease-out, opacity 0.25s ease-out;
  overflow: hidden;
}
.def-expand-leave-active {
  transition: max-height 0.25s ease-in, opacity 0.15s ease-in;
  overflow: hidden;
}
.def-expand-enter-from,
.def-expand-leave-to {
  opacity: 0;
  max-height: 0;
  padding-top: 0;
  padding-bottom: 0;
}
.def-expand-enter-to,
.def-expand-leave-from {
  opacity: 1;
  max-height: 5000px;
}

/* Schema card focus-visible */
.schema-card:focus-visible {
  outline: 2px solid var(--color-primary);
  outline-offset: 2px;
}

/* Responsive */
@media (max-width: 768px) {
  .schema-title-row {
    flex-direction: column;
    align-items: flex-start;
  }
  .schema-actions {
    width: 100%;
    justify-content: flex-start;
  }
  .schema-grid {
    grid-template-columns: 1fr;
  }
}
</style>

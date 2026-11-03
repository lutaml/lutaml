<template>
  <div class="builder-layout">
    <div class="builder-fields">
      <div class="builder-toolbar" :class="{ 'toolbar-with-filter': properties.length > 8 }">
        <div v-if="properties.length > 8" class="builder-filter">
          <input
            v-model="filterQuery"
            type="text"
            class="filter-input"
            :placeholder="t('builder.filterPlaceholder')"
            :aria-label="t('builder.filterProperties')"
          />
          <button v-if="filterQuery" class="filter-clear" :aria-label="t('builder.clearFilter')" @click="filterQuery = ''">
            <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
              <path d="M3 3l6 6M9 3l-6 6" stroke="currentColor" stroke-width="1.2" stroke-linecap="round"/>
            </svg>
          </button>
        </div>
        <div class="toolbar-actions">
          <button class="toolbar-btn" :class="{ active: sortAlpha }" :title="sortAlpha ? t('builder.sortedAlpha') : t('builder.sortedRequired')" @click="sortAlpha = !sortAlpha">
            <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
              <path d="M3 2v10M3 12l-2-2M3 12l2-2M11 2v10M11 12l-2-2M11 12l2-2" stroke="currentColor" stroke-width="1.2" stroke-linecap="round" stroke-linejoin="round"/>
            </svg>
            {{ sortAlpha ? 'A-Z' : 'Req' }}
          </button>
          <button v-if="hasExpandableFields" class="toolbar-btn" :title="t('builder.expandAllTitle')" @click="expandAllFields">
            <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
              <path d="M2 6h8M6 2v8" stroke="currentColor" stroke-width="1.2" stroke-linecap="round"/>
            </svg>
          </button>
          <button v-if="hasExpandedFields" class="toolbar-btn" :title="t('builder.collapseAllTitle')" @click="collapseAllFields">
            <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
              <path d="M2 6h8" stroke="currentColor" stroke-width="1.2" stroke-linecap="round"/>
            </svg>
          </button>
          <span class="toolbar-field-count text-muted">{{ includedCount }}/{{ fields.length }}</span>
        </div>
      </div>
      <div v-for="(field, idx) in sortedFields" :key="field.prop.name" :id="`prop-${field.prop.name}`" class="field-row" :class="{ 'field-row-alt': idx % 2 === 1, 'field-row-last': idx === sortedFields.length - 1, [`depth-${depth % 3}`]: depth > 0 }">
        <div class="field-main">
          <input
            type="checkbox"
            :checked="field.included"
            :disabled="field.isRequired"
            class="field-check"
            :aria-label="`Include ${field.prop.name}`"
            @change="toggleField(field, ($event.target as HTMLInputElement).checked)"
          />
          <span class="field-bullet" aria-hidden="true"></span>
          <button class="field-name" :class="{ dimmed: !field.included, deprecated: field.prop.deprecated, expandable: !!field.resolvedDef }" :aria-label="field.resolvedDef ? `${field.expanded ? t('builder.collapse') : t('builder.expand')} ${field.prop.name}` : tf('builder.viewDetails', { name: field.prop.name })" @click="field.resolvedDef && field.included ? (field.expanded = !field.expanded) : openPropertyDetail(field.prop)">
            <span v-if="field.prop.title && field.prop.title !== field.prop.name" class="field-human-title">{{ field.prop.title }}</span>
            <span class="font-mono">{{ field.prop.name }}</span>
            <span v-if="field.resolvedDef" class="field-expand-icon" :class="{ expanded: field.expanded }">&#9654;</span>
          </button>
          <span class="field-type-badge" :class="typeBadgeClass(field.prop)">{{ displayType(field.prop, field.resolvedDef?.title || field.resolvedDef?.name) }}</span>
          <span v-if="field.prop.title && field.prop.title !== field.prop.name" class="field-title-badge">{{ field.prop.title }}</span>
          <span v-if="field.prop.format" class="field-format-badge">&lt;{{ field.prop.format }}&gt;</span>
          <span v-if="isArrayWithArrayConstraints(field.prop)" class="array-item-constraints">[ items <template v-for="(chip, i) in arrayItemChips(field.prop)" :key="i"><span class="constraint-chip" :class="chip.class">{{ chip.label }}</span> </template>]</span>
          <span v-if="field.prop.contentMediaType" class="field-format-badge">content-type: {{ field.prop.contentMediaType }}</span>
          <span v-if="field.prop.contentEncoding" class="field-format-badge">encoding: {{ field.prop.contentEncoding }}</span>
          <span v-if="field.prop.const != null" class="const-badge font-mono">const: {{ field.prop.const }}</span>
          <span v-else-if="field.prop.default != null" class="default-badge font-mono">default: {{ field.prop.default }}</span>
          <span v-if="field.isRequired" class="req-badge">{{ t('builder.required') }}</span>
          <span v-if="field.prop.deprecated" class="deprecated-badge">{{ t('builder.deprecated') }}</span>
          <span v-if="field.prop.readOnly" class="readonly-badge">{{ t('builder.readOnly') }}</span>
          <span v-if="field.prop.writeOnly" class="writeonly-badge">{{ t('builder.writeOnly') }}</span>
          <span v-if="isNullableType(field.prop.type)" class="nullable-badge">{{ t('builder.nullable') }}</span>
          <span v-if="field.prop.compositionSource" class="composition-badge">{{ field.prop.compositionSource }}</span>

          <div class="field-control">
            <!-- Resolved $ref: expand button (works for object, array, and union types) -->
            <button
              v-if="field.resolvedDef"
              class="btn btn-ghost ctrl-expand"
              :disabled="!field.included"
              :aria-expanded="field.expanded"
              :aria-label="`${field.expanded ? t('builder.collapse') : t('builder.expand')} ${field.resolvedDef.title || field.resolvedDef.name}`"
              @click="field.expanded = !field.expanded"
            >
              <span class="chevron" :class="{ expanded: field.expanded }" aria-hidden="true">&#9654;</span>
              {{ field.resolvedDef.title || field.resolvedDef.name }}
              <span class="text-muted">{{ field.resolvedDef.properties.length }} props</span>
            </button>

            <!-- Composition types (anyOf/oneOf/not) — static label -->
            <span v-else-if="isCompositionType(primaryType(field.prop.type))" class="ctrl-static ctrl-composition">
              {{ field.prop.description || 'Multiple variants accepted' }}
            </span>

            <!-- Enum -->
            <select
              v-else-if="field.prop.enum?.length"
              v-model="field.rawValue"
              class="ctrl-select"
              :disabled="!field.included"
            >
              <option v-for="e in field.prop.enum" :key="e" :value="e">{{ e }}</option>
            </select>

            <!-- Boolean -->
            <label v-else-if="primaryType(field.prop.type) === 'boolean'" class="ctrl-toggle">
              <input type="checkbox" :checked="field.rawValue === 'true'" :disabled="!field.included"
                @change="field.rawValue = ($event.target as HTMLInputElement).checked ? 'true' : 'false'" />
              <span class="toggle-label">{{ field.rawValue }}</span>
            </label>

            <!-- Integer -->
            <input
              v-else-if="primaryType(field.prop.type) === 'integer'"
              type="number" step="1"
              :value="field.rawValue"
              :disabled="!field.included"
              class="ctrl-number"
              :class="{ 'ctrl-error': fieldError(field.prop.name) }"
              @input="field.rawValue = ($event.target as HTMLInputElement).value"
              @blur="validate(field.prop.name, field.rawValue, field.prop)"
            />

            <!-- Number -->
            <input
              v-else-if="primaryType(field.prop.type) === 'number'"
              type="number" step="any"
              :value="field.rawValue"
              :disabled="!field.included"
              class="ctrl-number"
              :class="{ 'ctrl-error': fieldError(field.prop.name) }"
              @input="field.rawValue = ($event.target as HTMLInputElement).value"
              @blur="validate(field.prop.name, field.rawValue, field.prop)"
            />

            <!-- Object without $ref: editable JSON textarea -->
            <textarea
              v-else-if="isObjectProperty(field.prop)"
              v-model="field.rawValue"
              :disabled="!field.included"
              class="ctrl-textarea"
              :class="{ 'ctrl-error': fieldError(field.prop.name) }"
              rows="2"
              placeholder='{"key": "value"}'
              @blur="validate(field.prop.name, field.rawValue, field.prop)"
            />

            <!-- Array with itemsType -->
            <div v-else-if="primaryType(field.prop.type) === 'array'" class="ctrl-array">
              <div v-for="(item, idx) in field.arrayItems" :key="idx" class="array-item-row">
                <input
                  :type="arrayItemInputType(field.prop.itemsType)"
                  v-model="field.arrayItems[idx]"
                  class="ctrl-text"
                  :disabled="!field.included"
                />
                <button
                  v-if="field.arrayItems.length > 1"
                  class="btn btn-ghost btn-xs"
                  :disabled="!field.included"
                  @click="field.arrayItems.splice(idx, 1)"
                  :title="t('builder.remove')"
                >x</button>
              </div>
              <button
                class="btn btn-ghost btn-xs"
                :disabled="!field.included"
                @click="field.arrayItems.push(arrayDefaultValue(field.prop.itemsType))"
              >{{ t('builder.add') }}</button>
            </div>

            <!-- String (default) -->
            <input
              v-else
              :type="formatInputType(field.prop.format)"
              :value="field.rawValue"
              :disabled="!field.included"
              class="ctrl-text"
              :class="{ 'ctrl-error': fieldError(field.prop.name) }"
              @input="field.rawValue = ($event.target as HTMLInputElement).value"
              @blur="validate(field.prop.name, field.rawValue, field.prop)"
            />
          </div>
        </div>

        <div v-if="fieldError(field.prop.name)" class="field-error-hint">
          {{ fieldError(field.prop.name) }}
        </div>

        <div v-if="field.prop.description" class="field-desc-wrap">
          <SeeMore max-height="3.6em">
            <div class="field-desc text-secondary" v-html="renderInlineMarkdown(field.prop.description)"></div>
          </SeeMore>
        </div>

        <div v-if="hasConstraints(field.prop) || field.prop.ref || field.prop.enum?.length" class="field-constraints">
          <span v-if="field.prop.ref" class="constraint-chip chip-ref" role="button" tabindex="0" @click.stop="navigateToRef(field.prop.ref)" @keydown.enter.stop="navigateToRef(field.prop.ref)">ref → {{ field.resolvedDef?.title || field.resolvedDef?.name || field.prop.ref }}</span>
          <template v-if="field.prop.enum?.length && !isObjectProperty(field.prop)">
            <span v-for="e in visibleEnums(field.prop.name, field.prop.enum)" :key="e" class="enum-chip" :class="{ 'enum-chip-active': field.rawValue === e }">{{ e }}</span>
            <button v-if="field.prop.enum.length > MAX_ENUM_SHOW && !enumExpanded.has(field.prop.name)" class="btn-see-more" @click.stop="toggleEnum(field.prop.name)">+{{ field.prop.enum.length - MAX_ENUM_SHOW }} {{ t('panel.more') }}</button>
          </template>
          <span v-else-if="field.prop.enum?.length && isObjectProperty(field.prop)" class="constraint-chip">enum: {{ field.prop.enum.join(' | ') }}</span>
          <span v-for="(chip, idx) in humanizeConstraints(field.prop)" :key="idx" class="constraint-chip" :class="chip.class">
            <template v-if="chip.class === 'chip-pattern'">
              /{{ truncatedPattern(chip.label).text }}/
              <button v-if="truncatedPattern(chip.label).truncated" class="btn-toggle-pattern" @click.stop="togglePattern(chip.label)">
                {{ expandedPatterns.has(chip.label) ? 'Hide' : 'Show' }}
              </button>
            </template>
            <template v-else>{{ chip.label }}</template>
          </span>
          <span v-if="field.prop.additionalProperties === false" class="constraint-chip chip-locked">{{ t('builder.noAdditional') }}</span>
          <template v-if="field.prop.examples?.length">
            <span class="constraint-chip chip-example">{{ t('builder.example') }}</span>
            <span v-for="(ex, exi) in field.prop.examples" :key="exi" class="example-chip">{{ typeof ex === 'object' ? JSON.stringify(ex) : ex }}</span>
          </template>
        </div>

        <!-- Nested object builder -->
        <Transition name="expand">
        <div v-if="field.expanded && field.included && field.resolvedDef && !isCircular(field, visited)" class="nested-section">
          <div class="nested-header">
            <span class="nested-path text-muted" v-if="depth > 0">{{ parentPath }}.</span>
            <span class="nested-title">{{ field.resolvedDef.title || field.resolvedDef.name }}</span>
            <span class="nested-meta text-muted">
              {{ field.resolvedDef.type || 'object' }}
              <span v-if="field.resolvedDef.properties.length">{{ field.resolvedDef.properties.length }} properties</span>
              <span v-if="field.resolvedDef.required?.length">{{ field.resolvedDef.required.length }} required</span>
            </span>
          </div>
          <SchemaBuilder
            :properties="field.resolvedDef.properties"
            :required="field.resolvedDef.required"
            :schema="schema"
            :all-schemas="allSchemas"
            :visited="new Set([...visited, field.resolvedDef.name])"
            :depth="depth + 1"
            :parent-path="parentPath ? `${parentPath}.${field.prop.name}` : field.prop.name"
            @update:json="(v: Record<string, unknown>) => { field.nestedJson = v }"
          />
        </div>
        </Transition>

        <!-- Circular reference label -->
        <div v-if="field.expanded && field.included && field.resolvedDef && isCircular(field, visited)" class="circular-ref-label">
          <span class="circular-badge">{{ t('builder.recursive') }}</span>
          <span class="circular-type">{{ field.resolvedDef?.type || 'object' }}</span>
          <span class="circular-name font-mono">{{ field.resolvedDef?.name }}</span>
          <span class="circular-hint text-muted">{{ t('builder.recursiveHint') }}</span>
        </div>
      </div>

      <div v-if="!sortedFields.length" class="empty-hint">
        <p class="text-muted">{{ t('builder.noProperties') }}</p>
      </div>
    </div>

    <div class="builder-preview">
      <div class="preview-inner">
        <div class="preview-toolbar">
          <span class="toolbar-label">{{ t('builder.jsonPreview') }}</span>
          <div class="toolbar-actions">
            <button class="btn btn-sm btn-dark-panel" @click="expandAllJson">{{ t('builder.expandAll') }}</button>
            <button class="btn btn-sm btn-dark-panel" @click="collapseAllJson">{{ t('builder.collapseAll') }}</button>
            <button class="btn btn-sm btn-dark-panel copy-btn-wrap" @click="copyJson">
              Copy
              <span v-if="copied" class="copy-tooltip">{{ t('builder.copied') }}</span>
            </button>
          </div>
        </div>
        <pre ref="jsonBlockRef" class="json-block" @click="handleJsonClick" @keydown="handleJsonKey" @dblclick="selectJsonBlock" v-html="highlightedJson"></pre>
        <div v-if="!hasIncludedFields" class="json-empty-hint">
          <span class="text-muted">{{ t('builder.checkFields') }}</span>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import type { SpaProperty, SpaSchema } from '../types'
import { useSchemaStore } from '../stores/schemaStore'
import { useUiStore } from '../stores/uiStore'
import { t, tf } from '../i18n'
import {
  primaryType,
  displayType,
  formatInputType,
  arrayItemInputType,
  arrayDefaultValue,
  isObjectProperty,
  isCompositionType,
  isNullableType,
  hasConstraints,
  humanizeConstraints,
  validateFieldValue,
} from '../composables/useSchemaTypes'
import {
  createField,
  isCircular,
  parseFieldValue,
} from '../composables/useBuilderField'
import { renderInlineMarkdown } from '../composables/useMarkdownLite'
import { jsonToCollapsibleHtml } from '../composables/useJsonViewer'
import type { BuilderField } from '../composables/useBuilderField'
import { copyToClipboard } from '../composables/useClipboard'
import SeeMore from './SeeMore.vue'

const schemaStore = useSchemaStore()
const uiStore = useUiStore()

function openPropertyDetail(prop: SpaProperty) {
  schemaStore.selectProperty(prop.name)
  uiStore.openDetailPanel()
}

function navigateToRef(ref: string | undefined) {
  if (!ref) return
  const match = ref.match(/^#\/(?:definitions|\$defs)\/([^/]+)$/)
  if (match) {
    schemaStore.selectDefinition(match[1])
  }
}

const props = withDefaults(defineProps<{
  properties: SpaProperty[]
  required: string[]
  schema: SpaSchema
  allSchemas?: SpaSchema[]
  visited?: Set<string>
  depth?: number
  parentPath?: string
}>(), {
  visited: () => new Set<string>(),
  depth: 0,
  parentPath: '',
})

const emit = defineEmits<{
  'update:json': [value: Record<string, unknown>]
}>()

const copied = ref(false)
const filterQuery = ref('')
const sortAlpha = ref(false)
const expandedPatterns = ref(new Set<string>())
const jsonBlockRef = ref<HTMLElement | null>(null)
const enumExpanded = ref(new Set<string>())

const MAX_ENUM_SHOW = 8
const validationErrors = ref<Map<string, string>>(new Map())

function visibleEnums(name: string, enums: string[]): string[] {
  if (enumExpanded.value.has(name) || enums.length <= MAX_ENUM_SHOW) return enums
  return enums.slice(0, MAX_ENUM_SHOW)
}

function toggleEnum(name: string) {
  const s = new Set(enumExpanded.value)
  if (s.has(name)) s.delete(name)
  else s.add(name)
  enumExpanded.value = s
}

function fieldError(name: string): string | undefined {
  return validationErrors.value.get(name)
}

function validate(name: string, rawValue: string, prop: SpaProperty) {
  const err = validateFieldValue(rawValue, prop)
  const m = new Map(validationErrors.value)
  if (err) m.set(name, err)
  else m.delete(name)
  validationErrors.value = m
}

const fields = ref<BuilderField[]>(props.properties.map(p => createField(p, props.required, props.schema, props.allSchemas, depth)))

const sortedFields = computed(() => {
  const q = filterQuery.value.trim().toLowerCase()
  let result = [...fields.value]
  if (q) {
    result = result.filter(f =>
      f.prop.name.toLowerCase().includes(q) ||
      (f.prop.title || '').toLowerCase().includes(q) ||
      (f.prop.description || '').toLowerCase().includes(q) ||
      (f.prop.type || '').toLowerCase().includes(q)
    )
  }
  if (sortAlpha.value) {
    return result.sort((a, b) => a.prop.name.localeCompare(b.prop.name))
  }
  return result.sort((a, b) => {
    if (a.isRequired && !b.isRequired) return -1
    if (!a.isRequired && b.isRequired) return 1
    return 0
  })
})

function toggleField(field: BuilderField, checked: boolean) {
  field.included = checked
  if (!checked) field.expanded = false
}

const hasExpandableFields = computed(() => fields.value.some(f => f.resolvedDef && f.included && !f.expanded))
const hasExpandedFields = computed(() => fields.value.some(f => f.expanded))
const includedCount = computed(() => fields.value.filter(f => f.included).length)

function expandAllFields() {
  for (const f of fields.value) {
    if (f.resolvedDef && f.included) f.expanded = true
  }
}

function collapseAllFields() {
  for (const f of fields.value) {
    f.expanded = false
  }
}

const outputJson = computed(() => {
  const obj: Record<string, unknown> = {}
  for (const field of fields.value) {
    if (!field.included) continue
    if (field.resolvedDef) {
      obj[field.prop.name] = field.nestedJson
    } else {
      obj[field.prop.name] = parseFieldValue(field)
    }
  }
  return JSON.stringify(obj, null, 2)
})

const hasIncludedFields = computed(() => fields.value.some(f => f.included))

const outputObj = computed(() => {
  try { return JSON.parse(outputJson.value) } catch { return {} }
})

watch(outputObj, (v) => { emit('update:json', v) }, { immediate: true, deep: true })

const highlightedJson = computed(() => {
  try {
    return jsonToCollapsibleHtml(JSON.parse(outputJson.value), 2)
  } catch {
    return outputJson.value
  }
})

function expandAllJson() {
  const container = jsonBlockRef.value
  if (!container) return
  container.querySelectorAll('.jv-collapsed').forEach(el => el.classList.remove('jv-collapsed'))
  container.querySelectorAll('.jv-toggle').forEach(btn => btn.setAttribute('aria-label', 'collapse'))
}

function collapseAllJson() {
  const container = jsonBlockRef.value
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

function handleJsonClick(event: MouseEvent) {
  const target = event.target as HTMLElement
  if (!target.classList.contains('jv-toggle')) return
  toggleJsonNode(target)
}

function handleJsonKey(event: KeyboardEvent) {
  const target = event.target as HTMLElement
  if (!target.classList.contains('jv-toggle')) return
  if (event.key === 'Enter' || event.key === ' ') {
    event.preventDefault()
    toggleJsonNode(target)
  }
}

function toggleJsonNode(target: HTMLElement) {
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

function selectJsonBlock() {
  const el = jsonBlockRef.value
  if (!el) return
  const range = document.createRange()
  range.selectNodeContents(el)
  const selection = window.getSelection()
  if (selection) {
    selection.removeAllRanges()
    selection.addRange(range)
  }
}

const MAX_PATTERN_LEN = 45

function typeBadgeClass(prop: SpaProperty): string {
  const t = primaryType(prop.type)
  if (isCompositionType(t)) return 'type-composition'
  switch (t) {
    case 'string': return 'type-string'
    case 'number': return 'type-number'
    case 'integer': return 'type-integer'
    case 'boolean': return 'type-boolean'
    case 'object': return 'type-object'
    case 'array': return 'type-array'
    case 'null': return 'type-null'
    default: return ''
  }
}

function isArrayWithArrayConstraints(prop: SpaProperty): boolean {
  if (primaryType(prop.type) !== 'array') return false
  return !!(prop.minItems != null || prop.maxItems != null || prop.uniqueItems)
}

interface ArrayItemChip {
  label: string
  class?: string
}

function arrayItemChips(prop: SpaProperty): ArrayItemChip[] {
  const chips: ArrayItemChip[] = []
  if (prop.minItems != null && prop.maxItems != null) {
    chips.push({ label: `[ ${prop.minItems} .. ${prop.maxItems} ]` })
  } else if (prop.minItems != null) {
    chips.push({ label: `>= ${prop.minItems}` })
  } else if (prop.maxItems != null) {
    chips.push({ label: `<= ${prop.maxItems}` })
  }
  if (prop.uniqueItems) chips.push({ label: 'unique', class: 'chip-unique' })
  return chips
}

function truncatedPattern(pattern: string): { text: string; truncated: boolean } {
  if (pattern.length <= MAX_PATTERN_LEN) return { text: pattern, truncated: false }
  if (expandedPatterns.value.has(pattern)) return { text: pattern, truncated: true }
  return { text: pattern.slice(0, MAX_PATTERN_LEN) + '…', truncated: true }
}

function togglePattern(pattern: string) {
  const s = new Set(expandedPatterns.value)
  if (s.has(pattern)) s.delete(pattern)
  else s.add(pattern)
  expandedPatterns.value = s
}

async function copyJson() {
  const ok = await copyToClipboard(outputJson.value)
  if (ok) {
    copied.value = true
    setTimeout(() => { copied.value = false }, 2000)
  }
}
</script>

<style scoped>
.builder-layout {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: var(--space-4);
  align-items: start;
}

.builder-fields {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.builder-toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-2);
  margin-bottom: var(--space-2);
}

.builder-toolbar:not(.toolbar-with-filter) {
  justify-content: flex-end;
}

.toolbar-actions {
  display: flex;
  align-items: center;
  gap: var(--space-1);
}

.toolbar-btn {
  display: flex;
  align-items: center;
  gap: 3px;
  padding: 4px 8px;
  font-size: 10px;
  font-weight: 600;
  color: var(--text-muted);
  background: var(--bg-secondary);
  border: 1px solid var(--border-light);
  border-radius: var(--radius-sm);
  cursor: pointer;
  white-space: nowrap;
  flex-shrink: 0;
  transition: all var(--transition-fast);
}

.toolbar-btn:hover {
  color: var(--text-primary);
  border-color: var(--border-medium);
}

.toolbar-btn.active {
  color: var(--color-primary);
  background: var(--color-primary-alpha);
  border-color: var(--color-primary);
}

.toolbar-field-count {
  flex-shrink: 0;
}

.builder-filter {
  position: relative;
  margin-bottom: var(--space-2);
}

.filter-input {
  width: 100%;
  padding: 5px 28px 5px 10px;
  font-size: var(--text-sm);
  font-family: var(--font-sans);
  background: var(--bg-primary);
  border: 1px solid var(--border-light);
  border-radius: var(--radius-md);
  color: var(--text-primary);
}

.filter-input::placeholder {
  color: var(--text-muted);
}

.filter-input:focus {
  outline: none;
  border-color: var(--color-primary);
}

.filter-clear {
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

.filter-clear:hover {
  color: var(--text-primary);
}

.field-row {
  padding: var(--space-2) var(--space-3);
  border-radius: var(--radius-md);
  border-inline-start: 2px solid transparent;
  transition: all var(--transition-fast);
}

.field-row:hover {
  background: var(--bg-hover);
  border-inline-start-color: var(--schema-lines);
}

.field-row-alt {
  background: var(--bg-secondary);
}

.field-row-alt:hover {
  background: var(--bg-hover);
  border-inline-start-color: var(--schema-lines);
}

.field-row-last {
  border-bottom: 1px solid var(--border-light);
  border-radius: var(--radius-md) var(--radius-md) 0 0;
}

.field-main {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  flex-wrap: wrap;
}

.field-check {
  accent-color: var(--color-primary);
  flex-shrink: 0;
  cursor: pointer;
}

.field-check:disabled {
  cursor: default;
}

.field-bullet {
  color: var(--schema-lines);
  font-family: var(--font-mono);
  margin-inline-end: 6px;
  flex-shrink: 0;
  display: inline-flex;
  align-items: center;
}

.field-bullet::before {
  content: '';
  display: inline-block;
  vertical-align: middle;
  width: 10px;
  height: 1px;
  background: var(--schema-lines);
}

.field-bullet::after {
  content: '';
  display: inline-block;
  vertical-align: middle;
  width: 1px;
  background: var(--schema-lines);
  height: 7px;
}

.field-bullet + .field-name.dimmed {
  opacity: 0.35;
}

.field-bullet + .field-name.dimmed + .field-bullet {
  opacity: 0.35;
}

.field-name {
  font-weight: 600;
  font-size: 13px;
  font-family: var(--font-mono);
  min-width: 100px;
  display: flex;
  flex-direction: column;
  gap: 0;
  line-height: 20px;
  text-align: start;
  cursor: pointer;
  padding: 0;
  border: none;
  background: none;
  color: var(--text-primary);
}

.field-name:focus .font-mono {
  font-weight: 700;
}

.field-name:hover .font-mono {
  color: var(--color-primary);
}

.field-human-title {
  font-size: var(--text-xs);
  font-weight: 400;
  font-style: italic;
  color: var(--text-secondary);
  font-family: var(--font-sans);
}

.field-name.dimmed {
  opacity: 0.35;
}

.field-name.deprecated {
  text-decoration: line-through;
  opacity: 0.7;
}

.field-name.expandable .font-mono:hover {
  color: var(--color-primary);
}

.field-expand-icon {
  font-size: var(--schema-arrow-size);
  color: var(--schema-arrow-color);
  transition: transform var(--transition-fast);
  margin-inline-start: 2px;
}

.field-expand-icon.expanded {
  transform: rotate(90deg);
}

.field-type-badge {
  font-size: 11px;
  font-weight: 500;
  background: var(--badge-schema-bg);
  color: var(--badge-schema);
  padding: 1px 6px;
  border-radius: var(--radius-sm);
  flex-shrink: 0;
  transition: background var(--transition-fast), color var(--transition-fast);
}

.field-type-badge.type-string { background: var(--type-string-bg); color: var(--type-string); }
.field-type-badge.type-number { background: var(--type-number-bg); color: var(--type-number); }
.field-type-badge.type-integer { background: var(--type-integer-bg); color: var(--type-integer); }
.field-type-badge.type-boolean { background: var(--type-boolean-bg); color: var(--type-boolean); }
.field-type-badge.type-object { background: var(--type-object-bg); color: var(--type-object); }
.field-type-badge.type-array { background: var(--type-array-bg); color: var(--type-array); }
.field-type-badge.type-null { background: var(--type-null-bg); color: var(--type-null); }
.field-type-badge.type-composition { background: var(--color-teal-alpha); color: var(--color-teal); font-family: var(--font-mono); font-size: 10px; }

.req-badge {
  font-size: var(--schema-labels-size);
  font-weight: 600;
  text-transform: uppercase;
  color: var(--schema-require-label);
  background: var(--schema-require-bg);
  padding: 1px 5px;
  border-radius: 2px;
  flex-shrink: 0;
  margin-inline-start: 20px;
}

.field-format-badge {
  font-size: 10px;
  color: var(--color-accent);
  background: var(--color-accent-alpha);
  padding: 1px 5px;
  border-radius: var(--radius-sm);
  font-family: var(--font-mono);
  font-weight: 500;
}

/* Array item constraints (Redoc ArrayItemDetails pattern) */
.array-item-constraints {
  font-size: 11px;
  font-family: var(--font-mono);
  color: var(--schema-type-name);
  margin: 0 5px;
  vertical-align: text-top;
  line-height: 20px;
}

.field-title-badge {
  font-size: 10px;
  font-style: italic;
  color: var(--text-secondary);
  flex-shrink: 0;
}

.deprecated-badge {
  font-size: 10px;
  font-weight: 600;
  text-transform: uppercase;
  color: var(--color-orange);
  background: var(--color-orange-alpha);
  padding: 1px 5px;
  border-radius: 2px;
  flex-shrink: 0;
}

.readonly-badge,
.writeonly-badge {
  font-size: 10px;
  font-weight: 600;
  text-transform: uppercase;
  padding: 1px 5px;
  border-radius: 2px;
  flex-shrink: 0;
}

.readonly-badge {
  color: var(--color-teal);
  background: var(--color-teal-alpha);
}

.writeonly-badge {
  color: var(--color-orange);
  background: var(--color-orange-alpha);
}

.nullable-badge {
  font-size: 10px;
  font-weight: 600;
  text-transform: uppercase;
  color: var(--text-muted);
  background: var(--bg-secondary);
  border: 1px dashed var(--border-medium);
  padding: 1px 5px;
  border-radius: 2px;
  flex-shrink: 0;
}

.composition-badge {
  font-size: 10px;
  font-weight: 600;
  text-transform: none;
  color: var(--color-teal);
  background: var(--color-teal-alpha);
  padding: 1px 5px;
  border-radius: 2px;
  flex-shrink: 0;
  font-family: var(--font-mono);
}

.const-badge,
.default-badge {
  font-size: 10px;
  font-weight: 500;
  padding: 1px 5px;
  border-radius: 2px;
  flex-shrink: 0;
  max-width: 160px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.const-badge {
  color: var(--color-primary);
  background: var(--color-primary-alpha);
}

.default-badge {
  color: var(--text-secondary);
  background: var(--bg-secondary);
  border: 1px solid var(--border-light);
}

.field-control {
  flex: 1;
  min-width: 120px;
  max-width: 240px;
}

.ctrl-text,
.ctrl-number,
.ctrl-select {
  width: 100%;
  padding: 3px 8px;
  font-size: var(--text-sm);
  font-family: var(--font-mono);
  background: var(--bg-primary);
  border: 1px solid var(--border-light);
  border-radius: var(--radius-sm);
  color: var(--text-primary);
}

.ctrl-text:disabled,
.ctrl-number:disabled,
.ctrl-select:disabled {
  opacity: 0.35;
}

.ctrl-text:focus,
.ctrl-number:focus,
.ctrl-select:focus {
  outline: none;
  border-color: var(--color-primary);
}

.ctrl-error {
  border-color: var(--color-red) !important;
}

.ctrl-error:focus {
  box-shadow: 0 0 0 2px var(--color-red-alpha);
}

.field-error-hint {
  font-size: var(--text-xs);
  color: var(--color-red);
  margin-top: 2px;
  margin-inline-start: 22px;
}

.ctrl-toggle {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  font-size: var(--text-sm);
  cursor: pointer;
}

.ctrl-toggle input {
  accent-color: var(--color-primary);
}

.toggle-label {
  font-family: var(--font-mono);
  color: var(--text-secondary);
}

.ctrl-expand {
  display: flex;
  align-items: center;
  gap: var(--space-1);
  font-size: var(--text-xs);
  color: var(--color-primary);
}

.ctrl-static {
  font-size: var(--text-sm);
  font-family: var(--font-mono);
  color: var(--text-muted);
}

.ctrl-composition {
  font-family: var(--font-sans);
  font-style: italic;
  font-size: var(--text-xs);
  color: var(--text-secondary);
}

.ctrl-textarea {
  width: 100%;
  padding: 3px 8px;
  font-size: var(--text-sm);
  font-family: var(--font-mono);
  background: var(--bg-primary);
  border: 1px solid var(--border-light);
  border-radius: var(--radius-sm);
  color: var(--text-primary);
  resize: vertical;
  min-height: 2em;
}

.ctrl-textarea:disabled {
  opacity: 0.35;
}

.ctrl-textarea:focus {
  outline: none;
  border-color: var(--color-primary);
}

.chevron {
  font-size: 10px;
  transition: transform var(--transition-fast);
}

.chevron.expanded {
  transform: rotate(90deg);
}

.field-desc-wrap {
  margin-top: var(--space-1);
  margin-inline-start: 22px;
}

.field-desc {
  font-size: var(--text-xs);
  line-height: var(--leading-normal);
}

.field-desc :deep(.md-code) {
  font-family: var(--font-mono);
  font-size: inherit;
  background: var(--bg-secondary);
  padding: 1px 4px;
  border-radius: 2px;
  border: 1px solid var(--border-light);
}

.field-desc :deep(.md-link) {
  color: var(--color-primary);
  text-decoration: none;
}

.field-desc :deep(.md-link:hover) {
  text-decoration: underline;
}

.field-desc :deep(.md-heading) {
  font-weight: 600;
  margin: var(--space-2) 0 var(--space-1);
  color: var(--text-primary);
  font-size: inherit;
}

.field-desc :deep(.md-list) {
  margin: var(--space-1) 0;
  padding-inline-start: var(--space-5);
  font-size: inherit;
}

.field-desc :deep(.md-list li) {
  margin-bottom: 2px;
}

.field-desc :deep(.md-pre) {
  background: var(--bg-secondary);
  border: 1px solid var(--border-light);
  border-radius: var(--radius-sm);
  padding: var(--space-2);
  margin: var(--space-2) 0;
  overflow-x: auto;
  font-size: var(--text-xs);
}

.field-desc :deep(.md-pre code) {
  font-family: var(--font-mono);
  font-size: inherit;
}

.field-constraints {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-1);
  margin-top: var(--space-1);
  margin-inline-start: 22px;
}

.constraint-chip {
  font-size: 11px;
  font-family: var(--font-mono);
  color: var(--color-primary);
  background: var(--color-primary-alpha);
  padding: 1px 5px;
  border-radius: 2px;
  border: 1px solid var(--border-light);
  margin: 0 2px;
  vertical-align: middle;
  line-height: 20px;
}

.constraint-chip.chip-pattern {
  font-family: var(--font-mono);
  color: var(--color-teal);
  background: var(--color-teal-alpha);
  border: 1px solid rgba(14, 124, 134, 0.15);
}

.btn-toggle-pattern {
  background: none;
  border: none;
  color: var(--color-primary);
  font-size: 10px;
  cursor: pointer;
  padding: 0 2px;
  margin-inline-start: 4px;
  text-decoration: underline;
}

.btn-toggle-pattern:hover {
  opacity: 0.8;
}

.constraint-chip.chip-ref {
  cursor: pointer;
}

.constraint-chip.chip-ref:hover {
  opacity: 0.8;
  border-color: var(--color-primary);
}

.constraint-chip.chip-locked {
  color: var(--color-orange);
  background: var(--color-orange-alpha);
  border-color: rgba(234, 86, 36, 0.2);
  font-weight: 500;
}

.constraint-chip.chip-default {
  color: var(--text-secondary);
  background: var(--bg-secondary);
  border-color: var(--border-light);
}

.constraint-chip.chip-const {
  color: var(--color-primary);
  background: var(--color-primary-alpha);
  border-color: var(--color-primary-alpha);
}

.constraint-chip.chip-unique {
  color: var(--color-teal);
  background: var(--color-teal-alpha);
  border-color: rgba(96, 195, 167, 0.2);
}

.constraint-chip.chip-example {
  font-style: italic;
  color: var(--text-secondary);
  background: transparent;
  padding: 0;
  border: none;
  margin-inline-end: 0;
}

.example-chip {
  font-size: 10px;
  font-family: var(--font-mono);
  color: var(--text-primary);
  background: var(--bg-hover);
  padding: 1px 5px;
  border-radius: var(--radius-sm);
  border: 1px solid var(--border-light);
  max-width: 200px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

:root[data-theme="dark"] .example-chip {
  background: rgba(255, 255, 255, 0.06);
  border-color: var(--border-medium);
}

/* Enum chips */
.enum-chip {
  font-size: 10px;
  font-family: var(--font-mono);
  color: var(--text-muted);
  background: var(--bg-secondary);
  padding: 1px 5px;
  border-radius: var(--radius-sm);
  border: 1px solid var(--border-light);
  transition: all var(--transition-fast);
}

.enum-chip-active {
  color: var(--color-primary);
  background: var(--color-primary-alpha);
  border-color: var(--color-primary);
  font-weight: 500;
}

.btn-see-more {
  background: none;
  border: none;
  color: var(--color-primary);
  font-size: 10px;
  cursor: pointer;
  padding: 0 2px;
  text-decoration: underline;
}

.btn-see-more:hover {
  opacity: 0.8;
}

.nested-section {
  margin-inline-start: 22px;
  margin-top: var(--space-2);
  padding: var(--space-3);
  border: 1px solid var(--border-light);
  border-radius: var(--radius-md);
  background: var(--schema-nested-bg);
  position: relative;
}

/* Tree line connector: vertical line from parent to nested section */
.nested-section::before {
  content: '';
  position: absolute;
  inset-inline-start: -11px;
  top: 0;
  bottom: 0;
  width: 1px;
  background: var(--schema-lines);
}

.nested-section::after {
  content: '';
  position: absolute;
  inset-inline-start: -11px;
  top: 14px;
  width: 10px;
  height: 1px;
  background: var(--schema-lines);
}

/* Depth-aware alternating backgrounds (Redoc pattern: alternate every 2 levels) */
:root[data-theme="light"] .depth-0,
:root[data-theme="light"] .depth-1 { background: var(--schema-nested-bg); }
:root[data-theme="light"] .depth-2 { background: transparent; }
:root[data-theme="dark"] .depth-0,
:root[data-theme="dark"] .depth-1 { background: var(--schema-nested-bg); }
:root[data-theme="dark"] .depth-2 { background: transparent; }

.nested-header {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  margin-bottom: var(--space-3);
  padding-bottom: var(--space-2);
  border-bottom: 1px solid var(--border-light);
}

.nested-title {
  font-weight: 600;
  font-size: var(--text-sm);
  color: var(--color-primary);
}

.nested-path {
  font-size: var(--text-xs);
  font-family: var(--font-mono);
  color: var(--text-muted);
}

.nested-meta {
  font-size: var(--text-xs);
}

.builder-preview {
  position: sticky;
  top: var(--space-4);
  z-index: 0;
}

.builder-preview::before {
  content: '';
  position: absolute;
  inset: 0;
  background: var(--panel-dark-bg);
  border-radius: var(--radius-md);
  z-index: -1;
}

.preview-inner {
  display: flex;
  flex-direction: column;
  gap: var(--space-2);
}

.preview-toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  color: var(--panel-dark-muted);
}

.toolbar-label {
  font-size: var(--text-xs);
}

.btn-sm {
  font-size: var(--text-xs);
  padding: var(--space-1) var(--space-2);
}

.btn-dark-panel {
  color: var(--panel-dark-muted);
}

.btn-dark-panel:hover {
  color: var(--panel-dark-text);
  background: rgba(255, 255, 255, 0.08);
}

.json-block {
  background: var(--panel-dark-bg);
  border: 1px solid var(--panel-dark-bg);
  border-radius: var(--radius-md);
  padding: var(--space-4);
  overflow-x: auto;
  font-size: var(--text-sm);
  line-height: var(--leading-relaxed);
  margin: 0;
  max-height: 70vh;
  overflow-y: auto;
  font-family: var(--font-mono);
  color: var(--panel-dark-text);
}

.json-block :deep(ul) {
  list-style: none;
  padding-inline-start: var(--space-4);
  margin: 0;
}

.json-block :deep(li) {
  margin: 0;
}

.json-block :deep(.jv-toggle) {
  background: none;
  border: 1px solid var(--panel-dark-muted);
  border-radius: 2px;
  cursor: pointer;
  width: 14px;
  height: 14px;
  font-size: 9px;
  line-height: 1;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  color: var(--text-muted);
  padding: 0;
  margin-inline-end: 4px;
  vertical-align: middle;
  transition: background var(--transition-fast);
}

.json-block :deep(.jv-toggle:hover) {
  background: var(--bg-hover);
}

.json-block :deep(.jv-toggle[aria-label="expand"])::after { content: '+'; }
.json-block :deep(.jv-toggle[aria-label="collapse"])::after { content: '−'; }

.json-block :deep(.jv-ellipsis) {
  display: none;
  color: var(--panel-dark-muted);
  font-size: var(--text-xs);
  font-style: italic;
  margin-inline-start: 4px;
}

.json-block :deep(.jv-children.jv-collapsed) {
  display: none;
}

.json-block :deep(.jv-children.jv-collapsed + .jv-ellipsis) {
  display: inline;
}

.json-block :deep(.jv-key) {
  color: var(--panel-dark-key);
}

.json-block :deep(.jv-punct) {
  color: var(--panel-dark-muted);
}

.json-block :deep(.jv-string) {
  color: var(--panel-dark-string);
}

.json-block :deep(.jv-number) {
  color: var(--panel-dark-number);
}

.json-block :deep(.jv-boolean) {
  color: var(--panel-dark-boolean);
}

.json-block :deep(.jv-null) {
  color: var(--panel-dark-null);
  font-style: italic;
}

.json-block :deep(.jv-link) {
  color: var(--panel-dark-string);
  text-decoration: underline;
}

.json-block :deep(.jv-row:hover) {
  background: rgba(255, 255, 255, 0.06);
  border-radius: 2px;
}

.toolbar-actions {
  display: flex;
  gap: var(--space-1);
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

.empty-hint {
  padding: var(--space-8);
  text-align: center;
}

.json-empty-hint {
  text-align: center;
  padding: var(--space-8) var(--space-4);
  font-size: var(--text-sm);
  color: var(--panel-dark-muted);
}

/* Editable arrays */
.ctrl-array {
  display: flex;
  flex-direction: column;
  gap: var(--space-1);
}

.array-item-row {
  display: flex;
  align-items: center;
  gap: var(--space-1);
}

.array-item-row input {
  flex: 1;
}

.btn-xs {
  font-size: 11px;
  padding: 2px 6px;
  border: none;
  background: transparent;
  color: var(--text-muted);
  cursor: pointer;
}

.btn-xs:hover:not(:disabled) {
  color: var(--text-primary);
}

.btn-xs:disabled {
  opacity: 0.35;
  cursor: default;
}

/* Circular reference */
.circular-ref-label {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  font-size: var(--text-sm);
  color: var(--text-muted);
  padding: var(--space-2) var(--space-3);
  margin-inline-start: 22px;
}

.circular-badge {
  font-size: 10px;
  font-weight: 600;
  text-transform: uppercase;
  color: var(--color-orange);
  background: var(--color-orange-alpha);
  padding: 1px 5px;
  border-radius: 2px;
}

.circular-type {
  font-size: 11px;
  background: var(--type-object-bg);
  color: var(--type-object);
  padding: 1px 5px;
  border-radius: var(--radius-sm);
}

.circular-name {
  font-size: var(--text-xs);
}

.circular-hint {
  font-size: var(--text-xs);
  font-style: italic;
}

/* Responsive */
@media (max-width: 768px) {
  .builder-layout {
    grid-template-columns: 1fr;
  }
  .builder-preview {
    position: static;
    order: -1;
  }
}

/* Expand/collapse transition */
.expand-enter-active {
  transition: max-height 0.3s ease-out, opacity 0.2s ease-out;
  overflow: hidden;
}
.expand-leave-active {
  transition: max-height 0.2s ease-in, opacity 0.15s ease-in;
  overflow: hidden;
}
.expand-enter-from,
.expand-leave-to {
  opacity: 0;
  max-height: 0;
  margin-top: 0;
  margin-bottom: 0;
  padding-top: 0;
  padding-bottom: 0;
}
.expand-enter-to,
.expand-leave-from {
  opacity: 1;
  max-height: 5000px;
}
</style>

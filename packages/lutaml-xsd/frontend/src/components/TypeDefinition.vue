<template>
  <div class="type-definition">
    <div class="definition-header">
      <span class="def-tag">&lt;</span>
      <span class="def-name">{{ type.data.name }}</span>
      <template v-if="type.type === 'complex' && (type.data as ComplexType).base">
        <span class="def-keyword">extends</span>
        <span class="def-type-link" @click="navigateToType((type.data as ComplexType).base || '')">{{ (type.data as ComplexType).base }}</span>
      </template>
      <template v-if="type.type === 'simple' && (type.data as SimpleType).restriction?.base">
        <span class="def-keyword">restriction</span>
        <span class="def-type-link" @click="navigateToType((type.data as SimpleType).restriction?.base || '')">{{ (type.data as SimpleType).restriction?.base }}</span>
      </template>
      <template v-if="type.type === 'simple' && (type.data as SimpleType).base">
        <span class="def-keyword">base</span>
        <span class="def-type-link" @click="navigateToType((type.data as SimpleType).base || '')">{{ (type.data as SimpleType).base }}</span>
      </template>
      <span class="def-tag">&gt;</span>
    </div>

    <!-- Complex Type Content -->
    <template v-if="type.type === 'complex'">
      <!-- Attributes section -->
      <div v-if="complexData.attributes?.length" class="def-section">
        <div class="def-section-title">// Attributes</div>
        <div class="def-content">
          <div v-for="attr in complexData.attributes" :key="attr.name" class="def-item def-xml-comment">
            <span class="def-comment">@attribute</span>
            <span class="def-item-name">{{ attr.name }}</span>
            <span class="def-type-link" @click="navigateToType(attr.type || 'xs:string')">{{ attr.type || 'xs:string' }}</span>
            <span v-if="attr.use" class="def-item-use" :class="attr.use">{{ attr.use }}</span>
          </div>
        </div>
      </div>

      <!-- Elements section -->
      <div v-if="complexData.elements?.length" class="def-section">
        <div class="def-section-title">// Child Elements</div>
        <div class="def-content">
          <div v-for="el in complexData.elements" :key="el.name" class="def-item def-xml-comment">
            <span class="def-comment">@element</span>
            <span class="def-item-name">{{ el.name }}</span>
            <span class="def-type-link" @click="navigateToType(el.type || 'xs:anyType')">{{ el.type || 'xs:anyType' }}</span>
            <span class="def-item-occurs">{{ formatOccurs(el.occurs) }}</span>
          </div>
        </div>
      </div>

      <!-- Attribute Group References section -->
      <div v-if="complexData.attribute_groups?.length" class="def-section">
        <div class="def-section-title">// Attribute Groups</div>
        <div class="def-content">
          <div v-for="ag in complexData.attribute_groups" :key="ag.ref" class="def-item def-xml-comment">
            <span class="def-comment">@attrgroup</span>
            <span class="def-type-link" @click="navigateToType(ag.ref)">{{ ag.ref }}</span>
            <!-- Inline attributes from the referenced attribute group -->
            <div v-if="ag.attributes?.length" class="def-group-attributes">
              <div v-for="attr in ag.attributes" :key="attr.name" class="def-item def-xml-comment def-indent">
                <span class="def-comment">@attribute</span>
                <span class="def-item-name">{{ attr.name }}</span>
                <span class="def-type-link" @click="navigateToType(attr.type || 'xs:string')">{{ attr.type || 'xs:string' }}</span>
                <span v-if="attr.use" class="def-item-use" :class="attr.use">{{ attr.use }}</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </template>

    <!-- Simple Type Content -->
    <template v-if="type.type === 'simple'">
      <div v-if="simpleData.restriction?.enumeration?.length" class="def-section">
        <div class="def-section-title">Enumeration</div>
        <div class="def-content">
          <div v-for="enumVal in simpleData.restriction?.enumeration" :key="enumVal.value" class="def-item">
            <code>{{ enumVal.value }}</code>
            <span v-if="enumVal.documentation" class="def-item-doc">{{ enumVal.documentation }}</span>
          </div>
        </div>
      </div>

      <div v-if="simpleData.restriction?.pattern" class="def-section">
        <div class="def-section-title">Pattern</div>
        <div class="def-content">
          <code>{{ simpleData.restriction.pattern }}</code>
        </div>
      </div>

      <div v-if="simpleData.union?.length" class="def-section">
        <div class="def-section-title">// Union</div>
        <div class="def-content">
          <span v-for="(member, i) in simpleData.union" :key="member">
            <span class="def-type-link" @click="navigateToType(member)">{{ member }}</span>
            <span v-if="i < simpleData.union.length - 1"> | </span>
          </span>
        </div>
      </div>

      <div v-if="simpleData.list" class="def-section">
        <div class="def-section-title">// List of</div>
        <div class="def-content">
          <span class="def-type-link" @click="navigateToType(simpleData.list)">{{ simpleData.list }}</span>
        </div>
      </div>
    </template>

    <!-- Element Content -->
    <template v-if="type.type === 'element'">
      <div v-if="elementData.type" class="def-section">
        <div class="def-section-title">// Type</div>
        <div class="def-content">
          <span class="def-type-link" @click="navigateToType(elementData.type || 'xs:anyType')">{{ elementData.type || 'xs:anyType' }}</span>
        </div>
      </div>
      <!--
      <div v-if="elementData.occurs" class="def-section">
        <div class="def-section-title">// Occurs</div>
        <div class="def-content">
          <span>{{ formatOccurs(elementData.occurs) }}</span>
        </div>
      </div>
      -->
      <div v-if="elementData.substitution_group" class="def-section">
        <div class="def-section-title">// Substitution Group</div>
        <div class="def-content">
          <span class="def-type-link" @click="navigateToType(elementData.substitution_group)">{{ elementData.substitution_group }}</span>
        </div>
      </div>
    </template>

    <div class="definition-footer">
      <span class="def-tag">&lt;/</span>
      <span class="def-name">{{ type.data.name }}</span>
      <span class="def-tag">&gt;</span>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import type { ComplexType, SimpleType, SchemaElement, GroupRef, AttributeGroup, TypeAttribute } from '@/types'
import { useSchemaStore } from '@/stores/schemaStore'
import { useUiStore } from '@/stores/uiStore'

type TypeData = {
  type: 'complex' | 'simple' | 'element' | 'group' | 'attribute_group' | 'attribute'
  data: ComplexType | SimpleType | SchemaElement | GroupRef | AttributeGroup | TypeAttribute
  schema: { id: string; name: string; prefix?: string }
}

const props = defineProps<{ type: TypeData }>()

const schemaStore = useSchemaStore()
const uiStore = useUiStore()

const complexData = computed(() => props.type.data as ComplexType)
const simpleData = computed(() => props.type.data as SimpleType)
const elementData = computed(() => props.type.data as SchemaElement)

function navigateToType(typeRef: string) {
  const found = schemaStore.getTypeByName(typeRef)
  if (found) {
    schemaStore.selectSchema(found.schema.id)
    schemaStore.selectType(found.data.id)
    uiStore.setPanelTab('definition')
    uiStore.openDetailPanel()
  }
}

function formatOccurs(occurs?: { min: number; max?: number | 'unbounded' }): string {
  if (!occurs) return '[1..1]'
  if (occurs.max === undefined || occurs.max === 'unbounded') {
    return occurs.min === 0 ? '[0..*]' : `[${occurs.min}..*]`
  }
  if (occurs.min === occurs.max) return `[${occurs.min}..${occurs.max}]`
  return `[${occurs.min}..${occurs.max}]`
}
</script>

<style scoped>
.type-definition {
  font-family: var(--font-mono);
  font-size: var(--text-sm);
}

.definition-header,
.definition-footer {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  padding: var(--space-3);
  background: var(--bg-secondary);
  border-radius: var(--radius-md);
  margin-bottom: var(--space-3);
}

.def-tag {
  color: var(--color-primary);
}

.def-name {
  font-weight: 600;
  color: var(--text-primary);
}

.def-keyword {
  color: var(--color-accent);
  font-style: italic;
}

.def-type {
  color: var(--color-primary);
}

.def-type-link {
  color: var(--color-primary);
  cursor: pointer;
  text-decoration: underline;
  text-decoration-style: dotted;
  text-underline-offset: 2px;
}

.def-type-link:hover {
  color: var(--color-primary-light);
  text-decoration-style: solid;
}

.def-xml-comment .def-comment {
  color: var(--text-muted);
  font-style: italic;
  min-width: 90px;
}

.def-section {
  margin-bottom: var(--space-4);
}

.def-section-title {
  font-size: var(--text-xs);
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: var(--text-muted);
  margin-bottom: var(--space-2);
}

.def-content {
  display: flex;
  flex-direction: column;
  gap: var(--space-1);
  padding-left: var(--space-4);
}

.def-item {
  display: flex;
  align-items: center;
  gap: var(--space-3);
  padding: var(--space-1) 0;
}

.def-item-name {
  color: var(--text-primary);
  min-width: 120px;
}

.def-item-type {
  color: var(--color-primary);
}

.def-item-occurs {
  color: var(--text-muted);
  font-size: var(--text-xs);
}

.def-item-use {
  font-size: var(--text-xs);
  padding: 1px 4px;
  border-radius: var(--radius-sm);
}

.def-item-use.required {
  background: var(--badge-complex-bg);
  color: var(--badge-complex);
}

.def-item-use.optional {
  background: var(--bg-secondary);
  color: var(--text-muted);
}

.def-item-doc {
  color: var(--text-muted);
  font-family: var(--font-sans);
  font-size: var(--text-xs);
}

code {
  background: var(--bg-secondary);
  padding: 2px 6px;
  border-radius: var(--radius-sm);
  color: var(--text-secondary);
}

.def-group-attributes {
  margin-left: var(--space-6);
  margin-top: var(--space-1);
}

.def-indent {
  padding-left: var(--space-4);
}
</style>

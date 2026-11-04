<template>
  <div class="detail-panel-overlay" @click.self="uiStore.closeDetailPanel">
    <aside class="detail-panel" ref="panelRef">
      <div class="panel-header">
        <div class="panel-title">
          <h2 v-if="item">{{ itemTitle }}</h2>
        </div>
        <button ref="closeBtnRef" class="btn btn-ghost" @click="uiStore.closeDetailPanel" aria-label="Close panel">
          <svg width="18" height="18" viewBox="0 0 18 18" fill="none">
            <path d="M5 5l8 8M13 5l-8 8" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>
          </svg>
        </button>
      </div>

      <div v-if="item" class="panel-tabs" role="tablist">
        <button
          v-for="tab in currentTabs"
          :key="tab.id"
          class="panel-tab"
          role="tab"
          :aria-selected="uiStore.activePanelTab === tab.id"
          :class="{ active: uiStore.activePanelTab === tab.id }"
          @click="uiStore.setPanelTab(tab.id)"
        >
          {{ tab.label }}
        </button>
      </div>

      <div class="panel-content">
        <template v-if="item">
          <!-- Overview tab -->
          <template v-if="uiStore.activePanelTab === 'overview'">
            <div class="detail-section">
              <div class="detail-meta">
                <div v-if="item.kind === 'schema' || item.kind === 'definition'" class="meta-row">
                  <span class="meta-label">{{ t('panel.type') }}</span>
                  <span class="badge badge-type">{{ itemType }}</span>
                </div>
                <div v-if="propertyItem?.format" class="meta-row">
                  <span class="meta-label">{{ t('panel.format') }}</span>
                  <span class="badge badge-format">{{ propertyItem.format }}</span>
                </div>
                <div v-if="itemDescription" class="meta-row">
                  <span class="meta-label">{{ t('panel.description') }}</span>
                  <span class="text-secondary md-content" v-html="renderInlineMarkdown(itemDescription)"></span>
                </div>
                <div v-if="propertyItem" class="meta-row">
                  <span class="meta-label">{{ t('panel.required') }}</span>
                  <span :class="['badge', propertyItem.required ? 'badge-required' : 'badge-optional']">
                    {{ propertyItem.required ? t('panel.requiredYesBadge') : t('panel.requiredNoBadge') }}
                  </span>
                </div>
                <div v-if="propertyItem?.deprecated" class="meta-row">
                  <span class="meta-label">{{ t('panel.status') }}</span>
                  <span class="badge badge-deprecated">{{ t('panel.deprecated') }}</span>
                </div>
                <div v-if="propertyItem?.readOnly" class="meta-row">
                  <span class="meta-label">{{ t('panel.access') }}</span>
                  <span class="badge badge-readonly-detail">{{ t('panel.readOnly') }}</span>
                </div>
                <div v-if="propertyItem?.writeOnly" class="meta-row">
                  <span class="meta-label">{{ t('panel.access') }}</span>
                  <span class="badge badge-writeonly-detail">{{ t('panel.writeOnly') }}</span>
                </div>
                <div v-if="propertyItem?.ref" class="meta-row">
                  <span class="meta-label">{{ t('panel.reference') }}</span>
                  <span class="ref-link font-mono" role="button" tabindex="0" @click="navigateToRef(propertyItem.ref)" @keydown.enter="navigateToRef(propertyItem.ref)">{{ propertyItem.ref }}</span>
                </div>
                <div v-if="propertyItem?.compositionSource" class="meta-row">
                  <span class="meta-label">{{ t('panel.source') }}</span>
                  <span class="badge badge-composition-detail">{{ propertyItem.compositionSource }}</span>
                </div>
                <div v-if="propertyItem?.default" class="meta-row">
                  <span class="meta-label">{{ t('panel.default') }}</span>
                  <span class="font-mono">{{ propertyItem.default }}</span>
                </div>
                <div v-if="item.kind === 'schema' && schemaItemsLabel" class="meta-row">
                  <span class="meta-label">{{ t('panel.items') }}</span>
                  <span class="font-mono text-secondary">{{ schemaItemsLabel }}</span>
                </div>
                <div v-if="item.kind === 'schema' && schema.required.length" class="meta-row">
                  <span class="meta-label">{{ t('panel.required') }}</span>
                  <div class="meta-tags">
                    <span v-for="r in schema.required" :key="r" class="badge badge-required-sm">{{ r }}</span>
                  </div>
                </div>
                <div v-if="item.kind === 'schema'" class="meta-row">
                  <span class="meta-label">{{ t('panel.properties') }}</span>
                  <span class="text-secondary">{{ schema.properties.length }}</span>
                </div>
                <div v-if="item.kind === 'schema' && schema.definitions.length" class="meta-row">
                  <span class="meta-label">{{ t('panel.definitions') }}</span>
                  <span class="text-secondary">{{ schema.definitions.length }}</span>
                </div>
                <div v-if="item.kind === 'schema' && schema.$schema" class="meta-row">
                  <span class="meta-label">{{ t('panel.jsonSchema') }}</span>
                  <span class="font-mono text-secondary" style="font-size: var(--text-xs); word-break: break-all;">{{ schema.$schema }}</span>
                </div>
                <div v-if="item.kind === 'schema' && schema.$id" class="meta-row">
                  <span class="meta-label">$id</span>
                  <span class="font-mono text-secondary" style="font-size: var(--text-xs); word-break: break-all;">{{ schema.$id }}</span>
                </div>
                <div v-if="item.kind === 'schema' && schema.externalDocs?.url" class="meta-row">
                  <span class="meta-label">{{ t('panel.docs') }}</span>
                  <a :href="schema.externalDocs.url" target="_blank" rel="noopener" class="font-mono text-secondary" style="font-size: var(--text-xs); word-break: break-all;">{{ schema.externalDocs.description || schema.externalDocs.url }}</a>
                </div>
                <div v-if="item.kind === 'schema' && (schema.hasAllOf || schema.hasAnyOf || schema.hasOneOf)" class="meta-row">
                  <span class="meta-label">{{ t('panel.composition') }}</span>
                  <div class="meta-tags">
                    <span v-if="schema.hasAllOf" class="badge badge-composition-detail">allOf</span>
                    <span v-if="schema.hasAnyOf" class="badge badge-composition-detail">anyOf</span>
                    <span v-if="schema.hasOneOf" class="badge badge-composition-detail">oneOf</span>
                  </div>
                </div>
                <div v-if="item.kind === 'schema' && (schema.minProperties != null || schema.maxProperties != null)" class="meta-row">
                  <span class="meta-label">{{ t('panel.properties') }}</span>
                  <span class="text-secondary">
                    <template v-if="schema.minProperties != null && schema.maxProperties != null">{{ schema.minProperties }}..{{ schema.maxProperties }}</template>
                    <template v-else-if="schema.minProperties != null">&ge; {{ schema.minProperties }}</template>
                    <template v-else>&le; {{ schema.maxProperties }}</template>
                  </span>
                </div>
                <div v-if="item.kind === 'schema' && schema.additionalProperties === false" class="meta-row">
                  <span class="meta-label">{{ t('panel.additional') }}</span>
                  <span class="badge badge-locked-detail">{{ t('panel.additionalDenied') }}</span>
                </div>
                <div v-for="section in conditionalSections" :key="section.label" class="meta-row">
                  <span class="meta-label">{{ section.label }}</span>
                  <div class="meta-tags">
                    <span v-for="row in section.rows" :key="row.name" class="badge badge-type">
                      {{ row.name }}<template v-if="row.type">: {{ row.type }}</template>
                    </span>
                    <span v-for="name in section.required" :key="'required-' + name" class="badge badge-required-sm">{{ name }}</span>
                  </div>
                </div>
                <div v-if="discriminatorMeta" class="meta-row">
                  <span class="meta-label">{{ t('panel.discriminator') }}</span>
                  <div class="meta-tags">
                    <span v-if="discriminatorMeta.propertyName" class="badge badge-type">{{ discriminatorMeta.propertyName }}</span>
                    <span v-for="(ref, value) in discriminatorMeta.mapping" :key="value" class="enum-value-chip">{{ value }} → {{ refLabel(ref) }}</span>
                  </div>
                </div>
                <template v-if="variantOptions.length">
                  <div class="meta-row">
                    <span class="meta-label">{{ t('panel.variants') }}</span>
                    <div class="meta-tags variant-tabs">
                      <button v-for="(variant, index) in variantOptions" :key="variant.source + index" type="button" class="variant-tab" :class="{ active: activeVariant === index }" :aria-pressed="activeVariant === index" @click="activeVariant = index">{{ variant.label }}</button>
                    </div>
                  </div>
                  <div v-if="activeVariantOption" class="meta-row">
                    <span class="meta-label">{{ activeVariantOption.source }}</span>
                    <div>
                      <span v-if="activeVariantOption.type" class="prop-type-badge" :class="propTypeClass(activeVariantOption.type)">{{ activeVariantOption.type }}</span>
                      <span v-if="activeVariantOption.format" class="prop-format">&lt;{{ activeVariantOption.format }}&gt;</span>
                      <span v-for="value in activeVariantOption.enum ?? []" :key="value" class="enum-value-chip">{{ value }}</span>
                      <div v-if="activeVariantOption.description" class="text-secondary md-content" v-html="renderInlineMarkdown(activeVariantOption.description)"></div>
                      <div v-if="activeVariantOption.fields.length" class="meta-tags">
                        <span v-for="field in activeVariantOption.fields" :key="field.name" class="badge badge-type">{{ field.name }}<template v-if="field.type">: {{ field.type }}</template></span>
                      </div>
                    </div>
                  </div>
                </template>
                <div v-if="definitionItem && definitionItem.required?.length" class="meta-row">
                  <span class="meta-label">{{ t('panel.required') }}</span>
                  <div class="meta-tags">
                    <span v-for="r in definitionItem.required" :key="r" class="badge badge-required-sm">{{ r }}</span>
                  </div>
                </div>
                <div v-if="definitionItem && (definitionItem.hasAllOf || definitionItem.hasAnyOf || definitionItem.hasOneOf)" class="meta-row">
                  <span class="meta-label">{{ t('panel.composition') }}</span>
                  <div class="meta-tags">
                    <span v-if="definitionItem.hasAllOf" class="badge badge-composition-detail">allOf</span>
                    <span v-if="definitionItem.hasAnyOf" class="badge badge-composition-detail">anyOf</span>
                    <span v-if="definitionItem.hasOneOf" class="badge badge-composition-detail">oneOf</span>
                  </div>
                </div>
                <div v-if="definitionItem?.compositionVariants?.length" class="meta-row">
                  <span class="meta-label">{{ t('panel.variants') }}</span>
                  <div class="meta-tags">
                    <span v-for="v in definitionItem.compositionVariants" :key="v" class="badge badge-composition-detail">{{ v }}</span>
                  </div>
                </div>
                <div v-if="definitionItem?.additionalPropertiesRef" class="meta-row">
                  <span class="meta-label">{{ t('panel.additional') }}</span>
                  <span class="ref-link font-mono" role="button" tabindex="0" @click="navigateToRef(definitionItem.additionalPropertiesRef)" @keydown.enter="navigateToRef(definitionItem.additionalPropertiesRef)">{{ refName(definitionItem.additionalPropertiesRef) }}</span>
                </div>
                <div v-else-if="definitionItem?.additionalPropertiesType" class="meta-row">
                  <span class="meta-label">{{ t('panel.additional') }}</span>
                  <span class="text-secondary">{{ definitionItem.additionalPropertiesType }}</span>
                </div>
                <div v-if="definitionItem && (definitionItem.minProperties != null || definitionItem.maxProperties != null)" class="meta-row">
                  <span class="meta-label">{{ t('panel.properties') }}</span>
                  <span class="text-secondary">
                    <template v-if="definitionItem.minProperties != null && definitionItem.maxProperties != null">{{ definitionItem.minProperties }}..{{ definitionItem.maxProperties }}</template>
                    <template v-else-if="definitionItem.minProperties != null">&ge; {{ definitionItem.minProperties }}</template>
                    <template v-else>&le; {{ definitionItem.maxProperties }}</template>
                  </span>
                </div>
                <div v-if="definitionItem && definitionItem.additionalProperties === false" class="meta-row">
                  <span class="meta-label">{{ t('panel.additional') }}</span>
                  <span class="badge badge-locked-detail">{{ t('panel.additionalDenied') }}</span>
                </div>
                <div v-if="definitionItem?.format" class="meta-row">
                  <span class="meta-label">{{ t('panel.format') }}</span>
                  <span class="badge badge-format">{{ definitionItem.format }}</span>
                </div>
                <div v-if="definitionItem?.pattern" class="meta-row">
                  <span class="meta-label">Pattern</span>
                  <span class="font-mono constraint-pattern">{{ definitionItem.pattern }}</span>
                </div>
                <div v-if="definitionItem?.default" class="meta-row">
                  <span class="meta-label">{{ t('panel.default') }}</span>
                  <span class="font-mono">{{ definitionItem.default }}</span>
                </div>
                <div v-if="definitionItem?.minLength != null || definitionItem?.maxLength != null" class="meta-row">
                  <span class="meta-label">{{ t('panel.length') }}</span>
                  <span class="text-secondary">{{ defStringRange }}</span>
                </div>
                <div v-if="definitionItem?.minimum != null || definitionItem?.maximum != null || definitionItem?.exclusiveMinimum != null || definitionItem?.exclusiveMaximum != null" class="meta-row">
                  <span class="meta-label">{{ t('panel.range') }}</span>
                  <span class="text-secondary">{{ defNumberRange }}</span>
                </div>
                <div v-if="definitionItem?.multipleOf != null" class="meta-row">
                  <span class="meta-label">Multiple Of</span>
                  <span class="text-secondary">{{ definitionItem.multipleOf }}</span>
                </div>
              </div>
            </div>

            <!-- Constraints for property -->
            <div v-if="propertyItem && hasConstraints" class="detail-section">
              <h3 class="detail-heading">{{ t('panel.constraints') }}</h3>
              <table class="table constraint-table">
                <tbody>
                  <tr v-if="propertyItem.minimum != null || propertyItem.maximum != null || propertyItem.exclusiveMinimum != null || propertyItem.exclusiveMaximum != null">
                    <td class="constraint-key">{{ t('panel.range') }}</td>
                    <td class="constraint-value">{{ numberRangeLabel }}</td>
                  </tr>
                  <tr v-if="propertyItem.minLength != null || propertyItem.maxLength != null">
                    <td class="constraint-key">{{ t('panel.length') }}</td>
                    <td class="constraint-value">{{ stringRangeLabel }}</td>
                  </tr>
                  <tr v-if="propertyItem.minItems != null || propertyItem.maxItems != null">
                    <td class="constraint-key">Items</td>
                    <td class="constraint-value">{{ itemsRangeLabel }}</td>
                  </tr>
                  <tr v-if="propertyItem.pattern">
                    <td class="constraint-key">{{ t('panel.pattern') }}</td>
                    <td class="constraint-value font-mono constraint-pattern">{{ propertyItem.pattern }}</td>
                  </tr>
                  <tr v-if="propertyItem.enum?.length">
                    <td class="constraint-key">{{ t('panel.enum') }}</td>
                    <td>
                      <table v-if="enumRowsFor(propertyItem).some(row => row.description)" class="table enum-table">
                        <thead>
                          <tr><th>{{ t('panel.value') }}</th><th>{{ t('panel.description') }}</th></tr>
                        </thead>
                        <tbody>
                          <tr v-for="row in enumRowsFor(propertyItem)" :key="row.value">
                            <td class="font-mono">{{ row.value }}</td>
                            <td class="text-secondary">{{ row.description || '—' }}</td>
                          </tr>
                        </tbody>
                      </table>
                      <div v-else class="enum-values-list">
                        <span v-for="e in visibleEnumValues(propertyItem.name, propertyItem.enum)" :key="e" class="enum-value-chip">{{ e }}</span>
                        <button v-if="propertyItem.enum.length > 8 && !detailEnumExpanded.has(propertyItem.name)" class="enum-more-btn" @click="toggleDetailEnum(propertyItem.name)">+{{ propertyItem.enum.length - 8 }} {{ t('panel.more') }}</button>
                      </div>
                    </td>
                  </tr>
                  <tr v-if="propertyItem.itemsType || propertyItem.itemsRef">
                    <td class="constraint-key">{{ t('panel.itemsTypeLabel') }}</td>
                    <td class="constraint-value">
                      {{ propertyItem.itemsType || 'object' }}
                      <span v-if="propertyItem.itemsRef" class="prop-ref-link" role="button" tabindex="0" @click.stop="navigateToRef(propertyItem.itemsRef)" @keydown.enter="navigateToRef(propertyItem.itemsRef)"> → {{ refName(propertyItem.itemsRef) }}</span>
                    </td>
                  </tr>
                  <tr v-if="propertyItem.itemsTuple?.length">
                    <td class="constraint-key">{{ t('panel.tupleItems') }}</td>
                    <td class="constraint-value">
                      <div class="enum-values-list">
                        <span v-for="(label, index) in propertyItem.itemsTuple" :key="index" class="enum-value-chip">{{ index }}: {{ label }}</span>
                        <span v-if="propertyItem.itemsTail" class="enum-value-chip">{{ t('panel.rest') }} {{ propertyItem.itemsTail }}</span>
                      </div>
                    </td>
                  </tr>
                  <tr v-if="propertyItem.itemsClosed">
                    <td class="constraint-key">{{ t('panel.additionalItems') }}</td>
                    <td class="constraint-value">{{ t('panel.additionalNotAllowed') }}</td>
                  </tr>
                  <tr v-if="propertyItem.uniqueItems">
                    <td class="constraint-key">{{ t('panel.uniqueItems') }}</td>
                    <td class="constraint-value"><span class="constraint-yes">{{ t('panel.uniqueYes') }}</span></td>
                  </tr>
                  <tr v-if="propertyItem.multipleOf != null">
                    <td class="constraint-key">{{ t('panel.multipleOf') }}</td>
                    <td class="constraint-value">{{ propertyItem.multipleOf }}</td>
                  </tr>
                  <tr v-if="propertyItem.const != null">
                    <td class="constraint-key">{{ t('panel.const') }}</td>
                    <td class="constraint-value font-mono">{{ propertyItem.const }}</td>
                  </tr>
                  <tr v-if="propertyItem.contentMediaType">
                    <td class="constraint-key">{{ t('panel.contentType') }}</td>
                    <td class="constraint-value">{{ propertyItem.contentMediaType }}</td>
                  </tr>
                  <tr v-if="propertyItem.contentEncoding">
                    <td class="constraint-key">{{ t('panel.contentEncoding') }}</td>
                    <td class="constraint-value">{{ propertyItem.contentEncoding }}</td>
                  </tr>
                  <tr v-if="propertyItem.additionalProperties === false">
                    <td class="constraint-key">{{ t('panel.additionalProps') }}</td>
                    <td class="constraint-value"><span class="constraint-denied">Denied</span></td>
                  </tr>
                </tbody>
              </table>
            </div>

            <!-- Constraints for definition (enum, pattern, etc.) -->
            <div v-if="definitionItem && hasDefConstraints" class="detail-section">
              <h3 class="detail-heading">{{ t('panel.constraints') }}</h3>
              <table class="table constraint-table">
                <tbody>
                  <tr v-if="definitionItem.enum?.length">
                    <td class="constraint-key">{{ t('panel.enum') }}</td>
                    <td>
                      <table v-if="enumRowsFor(definitionItem).some(row => row.description)" class="table enum-table">
                        <thead>
                          <tr><th>{{ t('panel.value') }}</th><th>{{ t('panel.description') }}</th></tr>
                        </thead>
                        <tbody>
                          <tr v-for="row in enumRowsFor(definitionItem)" :key="row.value">
                            <td class="font-mono">{{ row.value }}</td>
                            <td class="text-secondary">{{ row.description || '—' }}</td>
                          </tr>
                        </tbody>
                      </table>
                      <div v-else class="enum-values-list">
                        <span v-for="e in visibleEnumValues(definitionItem.name, definitionItem.enum)" :key="e" class="enum-value-chip">{{ e }}</span>
                        <button v-if="definitionItem.enum.length > 8 && !detailEnumExpanded.has(definitionItem.name)" class="enum-more-btn" @click="toggleDetailEnum(definitionItem.name)">+{{ definitionItem.enum.length - 8 }} {{ t('panel.more') }}</button>
                      </div>
                    </td>
                  </tr>
                  <tr v-if="definitionItem.const">
                    <td class="constraint-key">{{ t('panel.const') }}</td>
                    <td class="constraint-value font-mono">{{ definitionItem.const }}</td>
                  </tr>
                  <tr v-if="definitionItem.pattern">
                    <td class="constraint-key">{{ t('panel.pattern') }}</td>
                    <td class="constraint-value font-mono constraint-pattern">{{ definitionItem.pattern }}</td>
                  </tr>
                  <tr v-if="definitionItem.minimum != null || definitionItem.maximum != null || definitionItem.exclusiveMinimum != null || definitionItem.exclusiveMaximum != null">
                    <td class="constraint-key">{{ t('panel.range') }}</td>
                    <td class="constraint-value">{{ defNumberRange }}</td>
                  </tr>
                  <tr v-if="definitionItem.minLength != null || definitionItem.maxLength != null">
                    <td class="constraint-key">{{ t('panel.length') }}</td>
                    <td class="constraint-value">{{ defStringRange }}</td>
                  </tr>
                  <tr v-if="definitionItem.multipleOf != null">
                    <td class="constraint-key">{{ t('panel.multipleOf') }}</td>
                    <td class="constraint-value">{{ definitionItem.multipleOf }}</td>
                  </tr>
                  <tr v-if="definitionItem.contentMediaType">
                    <td class="constraint-key">{{ t('panel.contentType') }}</td>
                    <td class="constraint-value">{{ definitionItem.contentMediaType }}</td>
                  </tr>
                  <tr v-if="definitionItem.contentEncoding">
                    <td class="constraint-key">{{ t('panel.contentEncoding') }}</td>
                    <td class="constraint-value">{{ definitionItem.contentEncoding }}</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </template>

          <!-- Properties/Definition tab -->
          <template v-if="uiStore.activePanelTab === 'properties'">
            <div class="detail-section">
              <table v-if="properties.length || patternPropertyRows.length || additionalPropertyRow" class="table">
                <thead>
                  <tr>
                    <th>{{ t('panel.name') }}</th>
                    <th>{{ t('panel.type') }}</th>
                    <th>{{ t('panel.required') }}</th>
                    <th>{{ t('panel.description') }}</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="prop in properties" :key="prop.name" class="prop-row" :role="navigableProperty(prop.name) ? 'link' : undefined" :tabindex="navigableProperty(prop.name) ? 0 : undefined" @click="navigateToProperty(prop.name)" @keydown.enter="navigateToProperty(prop.name)" @keydown.space.prevent="navigateToProperty(prop.name)">
                    <td>
                      <span class="font-mono">{{ prop.name }}</span>
                      <span v-if="prop.title && prop.title !== prop.name" class="prop-title">({{ prop.title }})</span>
                      <span v-if="prop.deprecated" class="badge badge-deprecated-sm">deprecated</span>
                    </td>
                    <td>
                      <span v-if="prop.ref" class="prop-ref-link" role="button" tabindex="0" @click.stop="navigateToRef(prop.ref)">{{ prop.type || t('panel.object') }} → {{ refName(prop.ref) }}</span>
                      <template v-else>
                        <span class="prop-type-badge" :class="propTypeClass(prop.type)">{{ prop.type || t('panel.any') }}</span>
                        <span v-if="prop.format" class="prop-format">&lt;{{ prop.format }}&gt;</span>
                        <span v-if="prop.itemsType" class="prop-format">[{{ prop.itemsType }}]</span>
                        <span v-if="prop.itemsRef" class="prop-format">[<span class="prop-ref-link" role="button" tabindex="0" @click.stop="navigateToRef(prop.itemsRef)" @keydown.enter="navigateToRef(prop.itemsRef)">{{ refName(prop.itemsRef) }}</span>]</span>
                        <span v-if="prop.itemsTuple?.length" class="prop-format">[{{ prop.itemsTuple.join(', ') }}{{ prop.itemsTail ? `, *${prop.itemsTail}` : '' }}]</span>
                        <span v-if="prop.itemsClosed" class="prop-format">{{ t('panel.itemsClosed') }}</span>
                      </template>
                      <span v-if="prop.default != null" class="prop-default">default: {{ prop.default }}</span>
                      <span v-if="prop.enum?.length" class="prop-enum">{{ prop.enum.length }} values</span>
                      <span v-if="prop.refSiblingsIgnored || prop.refSiblingsApply" class="prop-dialect-note">
                        {{ prop.refSiblingsIgnored ? t('panel.refSiblingsIgnored') : t('panel.refSiblingsApply') }}
                      </span>
                      <span v-if="prop.format" class="prop-dialect-note">
                        {{ prop.formatAssertion ? t('panel.formatAsserts') : t('panel.formatAnnotates') }}
                      </span>
                    </td>
                    <td>
                      <span v-if="prop.required" class="badge badge-required-sm">{{ t('panel.requiredYesBadge') }}</span>
                      <span v-else class="text-muted">{{ t('panel.requiredNoBadge') }}</span>
                    </td>
                    <td>
                      <span v-if="prop.description" class="text-secondary md-content" v-html="renderInlineMarkdown(prop.description)"></span>
                      <span v-else class="text-muted">—</span>
                      <div v-if="prop.examples?.length" class="prop-examples">
                        <span class="prop-examples-label">{{ t('panel.examplesLabel') }}</span>
                        <span v-for="(ex, i) in prop.examples.slice(0, 3)" :key="i" class="prop-example-chip">{{ typeof ex === 'object' ? JSON.stringify(ex) : ex }}</span>
                        <span v-if="prop.examples.length > 3" class="text-muted">+{{ prop.examples.length - 3 }} more</span>
                      </div>
                    </td>
                  </tr>
                  <tr v-for="row in patternPropertyRows" :key="'pattern-' + row.pattern" class="prop-row">
                    <td>
                      <span class="font-mono">{{ row.pattern }}</span>
                      <span class="text-muted"> {{ t('panel.patternSuffix') }}</span>
                    </td>
                    <td>
                      <span class="prop-type-badge" :class="propTypeClass(row.type)">{{ row.type || t('panel.any') }}</span>
                    </td>
                    <td class="text-muted">—</td>
                    <td class="text-muted">{{ t('panel.patternMatches') }}</td>
                  </tr>
                  <tr v-if="additionalPropertyRow" class="prop-row">
                    <td><span class="font-mono">*</span> <span class="text-muted">{{ t('panel.additionalSuffix') }}</span></td>
                    <td>
                      <span v-if="additionalPropertyRow.ref" class="prop-ref-link" role="button" tabindex="0" @click.stop="navigateToRef(additionalPropertyRow.ref)">{{ additionalPropertyRow.type || 'object' }} → {{ refName(additionalPropertyRow.ref) }}</span>
                      <span v-else class="prop-type-badge" :class="propTypeClass(additionalPropertyRow.type)">{{ additionalPropertyRow.type || t('panel.any') }}</span>
                    </td>
                    <td class="text-muted">—</td>
                    <td class="text-muted">{{ t('panel.additionalMatches') }}</td>
                  </tr>
                </tbody>
              </table>
              <p v-else class="text-muted">{{ t('panel.noProperties') }}</p>
            </div>
          </template>

          <!-- Examples tab -->
          <template v-if="uiStore.activePanelTab === 'examples'">
            <div class="detail-section">
              <div v-if="examples.length" class="example-group">
                <h4 class="example-label">{{ t('panel.providedExamples') }}</h4>
                <div v-for="(ex, idx) in examples" :key="idx" class="example-block">
                  <div v-if="isComplexExample(ex)" class="example-collapsible" @click="toggleExampleCollapse($event)" @keydown="handleExampleKey($event)">
                    <pre class="example-pre jv-viewer" v-html="renderExampleHtml(ex)"></pre>
                  </div>
                  <pre v-else class="example-pre"><code>{{ formatExample(ex) }}</code></pre>
                </div>
              </div>
              <div v-if="generatedExample" class="example-group">
                <h4 class="example-label">{{ t('panel.generatedExample') }}</h4>
                <pre class="example-pre example-generated jv-viewer" v-html="renderExampleHtml(generatedExample)"></pre>
              </div>
              <p v-if="!examples.length && !generatedExample" class="text-muted">{{ t('panel.noExamples') }}</p>
            </div>
          </template>

          <!-- Changes tab (schema selected, baseline provided) -->
          <template v-if="uiStore.activePanelTab === 'changes'">
            <div class="detail-section">
              <div v-for="section in diffSectionsForItem" :key="section.label">
                <h4 class="example-label">{{ section.label }}</h4>
                <table class="table">
                  <thead>
                    <tr>
                      <th>{{ t('panel.location') }}</th>
                      <th>{{ t('panel.change') }}</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr v-for="row in section.rows" :key="row.pointer + (row.detail || '')">
                      <td class="font-mono">{{ row.pointer || '/' }}</td>
                      <td class="text-secondary">{{ row.detail || row.classification }}</td>
                    </tr>
                  </tbody>
                </table>
              </div>
              <p v-if="!diffSectionsForItem.length" class="text-muted">{{ t('panel.noChanges') }}</p>
            </div>
          </template>
        </template>

        <div v-else class="panel-empty">
          <p>{{ t('panel.empty') }}</p>
        </div>
      </div>
    </aside>
  </div>
</template>

<script setup lang="ts">
import { computed, ref, reactive, onMounted, onUnmounted, watch } from 'vue'
import { useSchemaStore, type SelectedItem } from '../stores/schemaStore'
import { useUiStore } from '../stores/uiStore'
import { renderInlineMarkdown } from '../composables/useMarkdownLite'
import { jsonToCollapsibleHtml } from '../composables/useJsonViewer'
import { numberRange, stringRange, itemsRange, refLabel, patternPropertyRows as toPatternPropertyRows, conditionalSections as toConditionalSections, variantOptions as toVariantOptions, diffSections as toDiffSections, enumRows as toEnumRows } from '../composables/useSchemaTypes'
import { t, tf } from '../i18n'
import type { SpaProperty } from '../types'

const schemaStore = useSchemaStore()
const uiStore = useUiStore()

const panelRef = ref<HTMLElement | null>(null)
const closeBtnRef = ref<HTMLButtonElement | null>(null)
const detailEnumExpanded = reactive(new Set<string>())

function visibleEnumValues(name: string, enums: string[]): string[] {
  if (detailEnumExpanded.has(name) || enums.length <= 8) return enums
  return enums.slice(0, 8)
}

function enumRowsFor(holder: {
  enum?: string[]
  enumDescriptions?: Record<string, string>
}) {
  return toEnumRows(holder.enum, holder.enumDescriptions)
}

function toggleDetailEnum(name: string) {
  if (detailEnumExpanded.has(name)) detailEnumExpanded.delete(name)
  else detailEnumExpanded.add(name)
}

onMounted(() => {
  closeBtnRef.value?.focus()
  document.addEventListener('keydown', trapFocus)
})

onUnmounted(() => {
  document.removeEventListener('keydown', trapFocus)
})

function trapFocus(e: KeyboardEvent) {
  if (e.key !== 'Tab' || !panelRef.value) return
  const focusable = panelRef.value.querySelectorAll<HTMLElement>(
    'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])',
  )
  if (!focusable.length) return
  const first = focusable[0]
  const last = focusable[focusable.length - 1]
  if (e.shiftKey) {
    if (document.activeElement === first) { e.preventDefault(); last.focus() }
  } else {
    if (document.activeElement === last) { e.preventDefault(); first.focus() }
  }
}

const item = computed<SelectedItem | null>(() => schemaStore.selectedItem)
const schema = computed(() => schemaStore.selectedSchema)

const itemTitle = computed(() => {
  if (!item.value) return ''
  switch (item.value.kind) {
    case 'schema': return item.value.schema.title || item.value.schema.name
    case 'definition': return item.value.definition.title || item.value.definition.name
    case 'property': return item.value.property.name
  }
})

const itemType = computed(() => {
  if (!item.value) return ''
  switch (item.value.kind) {
    case 'schema': return item.value.schema.type || 'any'
    case 'definition': return item.value.definition.type || 'any'
    case 'property': return item.value.property.type || 'any'
  }
})

const itemDescription = computed(() => {
  if (!item.value) return ''
  switch (item.value.kind) {
    case 'schema': return item.value.schema.description
    case 'definition': return item.value.definition.description
    case 'property': return item.value.property.description
  }
})

const schemaItemsLabel = computed(() => {
  if (item.value?.kind !== 'schema') return ''
  const s = item.value.schema
  if (s.itemsTuple?.length) {
    const tail = s.itemsTail ? `, *${s.itemsTail}` : ''
    return `[${s.itemsTuple.join(', ')}${tail}]${s.itemsClosed ? ' (closed)' : ''}`
  }
  if (s.itemsRef) return refLabel(s.itemsRef)
  if (s.itemsType) return s.itemsType
  if (s.itemsClosed) return '(closed)'
  return ''
})

const properties = computed<SpaProperty[]>(() => {
  if (!item.value) return []
  switch (item.value.kind) {
    case 'schema': return item.value.schema.properties
    case 'definition': return item.value.definition.properties
    case 'property': return item.value.property.properties ?? []
  }
})

const itemChanges = computed(() => {
  const current = item.value
  if (current?.kind !== 'schema') return []
  return schemaStore.changes.filter(change => change.schemaName === current.schema.name)
})

const diffSectionsForItem = computed(() => toDiffSections(itemChanges.value))

function formatExample(value: unknown): string {
  if (typeof value === 'string') {
    try { return JSON.stringify(JSON.parse(value), null, 2) } catch { return value }
  }
  return JSON.stringify(value, null, 2)
}

const hasConstraints = computed(() => {
  const p = propertyItem.value
  if (!p) return false
  return p.minimum != null || p.maximum != null ||
    p.minLength != null || p.maxLength != null ||
    p.pattern || p.enum?.length || p.itemsType || p.itemsRef ||
    p.exclusiveMinimum != null || p.exclusiveMaximum != null ||
    p.minItems != null || p.maxItems != null || p.uniqueItems ||
    p.multipleOf != null || p.const != null ||
    p.contentMediaType || p.contentEncoding ||
    p.additionalProperties === false
})

const hasDefConstraints = computed(() => {
  const d = definitionItem.value
  if (!d) return false
  return d.enum?.length > 0 || !!d.const || !!d.pattern ||
    d.minimum != null || d.maximum != null ||
    d.exclusiveMinimum != null || d.exclusiveMaximum != null ||
    d.minLength != null || d.maxLength != null ||
    d.multipleOf != null || !!d.contentMediaType || !!d.contentEncoding
})

const numberRangeLabel = computed(() => {
  const p = propertyItem.value
  return p ? numberRange(p) ?? '' : ''
})

const stringRangeLabel = computed(() => {
  const p = propertyItem.value
  return p ? stringRange(p) ?? '' : ''
})

const itemsRangeLabel = computed(() => {
  const p = propertyItem.value
  return p ? itemsRange(p) ?? '' : ''
})

const defNumberRange = computed(() => {
  const d = definitionItem.value
  if (!d) return ''
  return numberRange(d as any) ?? ''
})

const defStringRange = computed(() => {
  const d = definitionItem.value
  if (!d) return ''
  return stringRange(d as any) ?? ''
})

type TabId = 'overview' | 'properties' | 'examples' | 'changes'

const examples = computed(() => {
  if (!item.value) return []
  switch (item.value.kind) {
    case 'schema': return item.value.schema.examples ?? []
    case 'definition': return item.value.definition.examples ?? []
    case 'property': return item.value.property.examples ?? []
  }
})

const generatedExample = computed(() => {
  if (!item.value) return null
  if (item.value.kind === 'property') {
    const p = item.value.property
    if (p.default != null) return p.default
    if (p.const != null) return p.const
    if (p.enum?.length) return p.enum[0]
    if (p.examples?.length) return p.examples[0]
    const t = p.type?.split(',')[0]?.trim() || 'any'
    switch (t) {
      case 'string': return p.format === 'email' ? 'user@example.com' : p.format === 'uri' ? 'https://example.com' : '"string"'
      case 'integer': return '0'
      case 'number': return '0.0'
      case 'boolean': return 'false'
      case 'array': return '[]'
      case 'object': return '{}'
      default: return null
    }
  }
  if (item.value.kind === 'schema' || item.value.kind === 'definition') {
    const props = item.value.kind === 'schema' ? item.value.schema.properties : item.value.definition.properties
    const req = item.value.kind === 'schema' ? item.value.schema.required : item.value.definition.required
    const obj: Record<string, unknown> = {}
    for (const prop of props) {
      if (prop.default != null) { obj[prop.name] = prop.default; continue }
      if (prop.const != null) { obj[prop.name] = prop.const; continue }
      if (prop.enum?.length) { obj[prop.name] = prop.enum[0]; continue }
      if (prop.examples?.length) { obj[prop.name] = prop.examples[0]; continue }
      const t = prop.type?.split(',')[0]?.trim() || 'any'
      switch (t) {
        case 'string': obj[prop.name] = prop.format === 'email' ? 'user@example.com' : prop.format === 'uri' ? 'https://example.com' : 'string'; break
        case 'integer': obj[prop.name] = 0; break
        case 'number': obj[prop.name] = 0; break
        case 'boolean': obj[prop.name] = false; break
        case 'array': obj[prop.name] = []; break
        default: obj[prop.name] = null
      }
    }
    return JSON.stringify(obj, null, 2)
  }
  return null
})

const currentTabs = computed<{ id: TabId; label: string }[]>(() => {
  const tabs: { id: TabId; label: string }[] = [
    { id: 'overview', label: t('panel.tabs.overview') },
  ]
  if (properties.value.length > 0) {
    tabs.push({ id: 'properties', label: tf('panel.tabs.propertiesCount', { count: properties.value.length }) })
  }
  if (examples.value.length > 0 || generatedExample.value) {
    const count = examples.value.length || 1
    tabs.push({ id: 'examples', label: tf('panel.tabs.examplesCount', { count }) })
  }
  if (itemChanges.value.length > 0) {
    tabs.push({ id: 'changes', label: tf('panel.tabs.changesCount', { count: itemChanges.value.length }) })
  }
  return tabs
})

const propertyItem = computed<SpaProperty | null>(() => {
  if (item.value?.kind !== 'property') return null
  return item.value.property
})

const definitionItem = computed(() => {
  if (item.value?.kind !== 'definition') return null
  return item.value.definition
})

const patternPropertyRows = computed(() => {
  if (!item.value) return []
  const map = item.value.kind === 'schema'
    ? item.value.schema.patternProperties
    : item.value.kind === 'definition'
      ? item.value.definition.patternProperties
      : item.value.property.patternProperties
  return toPatternPropertyRows(map)
})

const additionalPropertyRow = computed<{ type?: string; ref?: string } | null>(() => {
  const current = item.value
  if (!current) return null
  const holder = current.kind === 'definition'
    ? current.definition
    : current.kind === 'property'
      ? current.property
      : null
  if (!holder?.additionalPropertiesType && !holder?.additionalPropertiesRef) return null
  return {
    type: holder.additionalPropertiesType,
    ref: holder.additionalPropertiesRef,
  }
})

const conditionalSections = computed(() => {
  if (item.value?.kind !== 'schema') return []
  return toConditionalSections(item.value.schema)
})

const activeVariant = ref(0)

const discriminatorMeta = computed(() => {
  if (!item.value) return null
  if (item.value.kind === 'property') return item.value.property.discriminator ?? null
  if (item.value.kind === 'definition') return item.value.definition.discriminator ?? null
  if (item.value.kind === 'schema') return item.value.schema.discriminator ?? null
  return null
})

const variantOptions = computed(() => {
  if (!item.value) return []
  const holder = item.value.kind === 'property'
    ? item.value.property
    : item.value.kind === 'definition'
      ? item.value.definition
      : null
  return holder ? toVariantOptions(holder, holder.discriminator?.mapping) : []
})

const activeVariantOption = computed(() => variantOptions.value[activeVariant.value])

watch(item, () => {
  activeVariant.value = 0
  if (!currentTabs.value.some(tab => tab.id === uiStore.activePanelTab)) {
    uiStore.setPanelTab('overview')
  }
})

function navigateToRef(ref: string | undefined) {
  if (!ref) return
  const match = ref.match(/^#\/(?:definitions|\$defs)\/([^/]+)$/) ||
    ref.match(/^#([^/]+)$/)
  if (match) {
    uiStore.closeDetailPanel()
    schemaStore.selectDefinition(match[1])
  }
}

function refName(ref: string): string {
  const match = ref.match(/^#\/(?:definitions|\$defs)\/([^/]+)$/) ||
    ref.match(/^#([^/]+)$/)
  return match ? match[1] : ref
}

function navigableProperty(name: string): boolean {
  if (item.value?.kind !== 'schema') return false
  return item.value.schema.properties.some(prop => prop.name === name)
}

function navigateToProperty(name: string) {
  if (!navigableProperty(name)) return
  uiStore.closeDetailPanel()
  schemaStore.selectProperty(name)
}

function isComplexExample(value: unknown): boolean {
  if (typeof value === 'string') {
    try { return typeof JSON.parse(value) === 'object' } catch { return false }
  }
  return typeof value === 'object' && value !== null
}

function renderExampleHtml(value: unknown): string {
  let parsed: unknown
  if (typeof value === 'string') {
    try { parsed = JSON.parse(value) } catch { return escapeHtml(value) }
  } else {
    parsed = value
  }
  try {
    return jsonToCollapsibleHtml(parsed, 3)
  } catch {
    return escapeHtml(typeof parsed === 'string' ? parsed : JSON.stringify(parsed, null, 2))
  }
}

function propTypeClass(type?: string): string {
  const t = (type || 'any').split(',')[0].trim()
  switch (t) {
    case 'string': return 'ptype-string'
    case 'number': return 'ptype-number'
    case 'integer': return 'ptype-integer'
    case 'boolean': return 'ptype-boolean'
    case 'object': return 'ptype-object'
    case 'array': return 'ptype-array'
    case 'null': return 'ptype-null'
    default: return ''
  }
}

function escapeHtml(t: string): string {
  return t.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
}

function toggleExampleCollapse(event: MouseEvent) {
  const target = event.target as HTMLElement
  if (!target.classList.contains('jv-toggle')) return
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

function handleExampleKey(event: KeyboardEvent) {
  if (event.key !== 'Enter' && event.key !== ' ') return
  const target = event.target as HTMLElement
  if (!target.classList.contains('jv-toggle')) return
  event.preventDefault()
  toggleExampleCollapse(event as unknown as MouseEvent)
}
</script>

<style scoped>
.detail-panel-overlay {
  position: fixed;
  inset: 0;
  background: var(--bg-overlay);
  display: flex;
  justify-content: flex-end;
  z-index: 100;
  animation: fadeIn var(--transition-fast);
}

.detail-panel {
  width: 100%;
  max-width: 640px;
  height: 100%;
  background: var(--bg-elevated);
  box-shadow: var(--shadow-lg);
  display: flex;
  flex-direction: column;
  animation: slideIn var(--transition-slow);
}

.panel-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: var(--space-4) var(--space-5);
  border-bottom: 1px solid var(--border-light);
  flex-shrink: 0;
}

.panel-title h2 {
  font-size: var(--text-lg);
  font-weight: 600;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.panel-tabs {
  display: flex;
  gap: var(--space-1);
  padding: var(--space-2) var(--space-5);
  border-bottom: 1px solid var(--border-light);
  flex-shrink: 0;
}

.panel-tab {
  padding: var(--space-2) var(--space-3);
  font-size: var(--text-sm);
  font-weight: 500;
  color: var(--text-muted);
  border-radius: var(--radius-md);
  transition: all var(--transition-fast);
}

.panel-tab:hover {
  color: var(--text-primary);
  background: var(--bg-hover);
}

.panel-tab.active {
  color: var(--color-primary);
  background: var(--color-primary-alpha);
}

.panel-content {
  flex: 1;
  overflow-y: auto;
  padding: var(--space-5);
}

.panel-empty {
  display: flex;
  align-items: center;
  justify-content: center;
  height: 100%;
  color: var(--text-muted);
  font-size: var(--text-sm);
}

.detail-section {
  margin-bottom: var(--space-6);
}

.detail-heading {
  font-size: var(--text-sm);
  font-weight: 500;
  text-transform: uppercase;
  letter-spacing: 0.03em;
  margin-bottom: var(--space-3);
  color: var(--text-secondary);
  padding-bottom: var(--space-2);
  border-bottom: 1px solid var(--border-light);
  position: relative;
}

.detail-heading::after {
  content: '';
  position: absolute;
  bottom: -1px;
  inset-inline-start: 0;
  width: 32px;
  height: 2px;
  background: var(--color-primary);
  border-radius: 1px;
}

.detail-meta {
  display: flex;
  flex-direction: column;
  gap: var(--space-3);
}

.meta-row {
  display: flex;
  align-items: flex-start;
  gap: var(--space-3);
}

.meta-label {
  font-size: var(--text-sm);
  font-weight: 500;
  color: var(--text-muted);
  min-width: 80px;
  flex-shrink: 0;
}

.meta-tags {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-1);
}

.prop-type-badge {
  font-size: 11px;
  font-weight: 500;
  font-family: var(--font-mono);
  padding: 1px 5px;
  border-radius: var(--radius-sm);
  background: var(--badge-schema-bg);
  color: var(--badge-schema);
}

.prop-type-badge.ptype-string { background: var(--type-string-bg); color: var(--type-string); }
.prop-type-badge.ptype-number { background: var(--type-number-bg); color: var(--type-number); }
.prop-type-badge.ptype-integer { background: var(--type-integer-bg); color: var(--type-integer); }
.prop-type-badge.ptype-boolean { background: var(--type-boolean-bg); color: var(--type-boolean); }
.prop-type-badge.ptype-object { background: var(--type-object-bg); color: var(--type-object); }
.prop-type-badge.ptype-array { background: var(--type-array-bg); color: var(--type-array); }
.prop-type-badge.ptype-null { background: var(--type-null-bg); color: var(--type-null); }

.prop-format {
  font-size: var(--text-xs);
  color: var(--color-accent);
  margin-inline-start: var(--space-1);
  font-family: var(--font-mono);
}

.prop-row {
  cursor: pointer;
  transition: background var(--transition-fast);
}

.prop-row:hover {
  background: var(--bg-hover);
}

.prop-ref-link {
  color: var(--color-primary);
  cursor: pointer;
  font-family: var(--font-mono);
  font-size: var(--text-xs);
}

.prop-ref-link:hover {
  text-decoration: underline;
}

.prop-title {
  display: block;
  font-size: var(--text-xs);
  color: var(--text-secondary);
  font-style: italic;
}

.prop-dialect-note {
  font-size: 10px;
  color: var(--text-accent);
}

.prop-default {
  display: block;
  font-size: 10px;
  color: var(--text-muted);
  font-family: var(--font-mono);
}

.prop-enum {
  display: block;
  font-size: 10px;
  color: var(--color-teal);
  background: var(--color-teal-alpha);
  padding: 1px 4px;
  border-radius: 2px;
  display: inline-block;
  margin-top: 2px;
}

.prop-examples {
  margin-top: var(--space-1);
  display: flex;
  flex-wrap: wrap;
  gap: 4px;
  align-items: center;
}

.prop-examples-label {
  font-size: 10px;
  color: var(--text-muted);
  font-weight: 500;
}

.prop-example-chip {
  font-size: 10px;
  font-family: var(--font-mono);
  background: var(--bg-hover);
  padding: 1px 5px;
  border-radius: 2px;
  border: 1px solid var(--border-light);
  color: var(--text-secondary);
  word-break: break-word;
}

:root[data-theme="dark"] .prop-example-chip {
  background: rgba(255, 255, 255, 0.06);
  border-color: rgba(255, 255, 255, 0.1);
}

.badge-type {
  background: var(--badge-schema-bg);
  color: var(--badge-schema);
  font-family: var(--font-mono);
  font-size: var(--schema-labels-size);
}

.badge-format {
  background: var(--bg-secondary);
  color: var(--text-secondary);
}

.badge-required {
  background: var(--schema-require-bg);
  color: var(--schema-require-label);
}

.badge-optional {
  background: var(--bg-secondary);
  color: var(--text-muted);
}

.badge-deprecated {
  background: var(--color-orange-alpha);
  color: var(--color-orange);
  font-size: var(--text-xs);
  padding: 2px 6px;
  border-radius: var(--radius-sm);
  font-weight: 500;
}

.badge-required-sm {
  background: var(--schema-require-bg);
  color: var(--schema-require-label);
  font-size: 10px;
  padding: 1px 4px;
  border-radius: 2px;
}

.badge-deprecated-sm {
  background: var(--badge-deprecated-bg);
  color: var(--badge-deprecated);
  font-size: 10px;
  padding: 1px 4px;
  border-radius: 2px;
  margin-inline-start: 4px;
}

.badge-composition-detail {
  font-size: 11px;
  color: var(--color-teal);
  background: var(--color-teal-alpha);
  padding: 1px 6px;
  border-radius: var(--radius-sm);
  font-family: var(--font-mono);
  font-weight: 500;
}

.badge-locked-detail {
  font-size: 11px;
  color: var(--color-orange);
  background: var(--color-orange-alpha);
  padding: 1px 6px;
  border-radius: var(--radius-sm);
  font-weight: 500;
}

.badge-readonly-detail {
  font-size: 11px;
  color: var(--color-teal);
  background: var(--color-teal-alpha);
  padding: 1px 6px;
  border-radius: var(--radius-sm);
  font-weight: 500;
}

.badge-writeonly-detail {
  font-size: 11px;
  color: var(--color-orange);
  background: var(--color-orange-alpha);
  padding: 1px 6px;
  border-radius: var(--radius-sm);
  font-weight: 500;
}

.ref-link {
  color: var(--color-primary);
  cursor: pointer;
  font-size: var(--text-xs);
  word-break: break-all;
}

.ref-link:hover {
  text-decoration: underline;
}

.enum-values-list {
  display: flex;
  flex-wrap: wrap;
  gap: 4px;
}

.enum-value-chip {
  font-size: 11px;
  font-family: var(--font-mono);
  background: var(--bg-hover);
  border: 1px solid var(--border-light);
  padding: 1px 5px;
  border-radius: 2px;
  color: var(--text-primary);
  word-break: break-word;
}

.enum-more-btn {
  font-size: 11px;
  color: var(--color-primary);
  background: none;
  border: none;
  cursor: pointer;
  padding: 1px 4px;
  font-family: var(--font-mono);
}

.enum-more-btn:hover {
  text-decoration: underline;
}

.constraint-table td:first-child {
  font-weight: 500;
  color: var(--text-secondary);
  width: 120px;
}

.constraint-key {
  white-space: nowrap;
}

.constraint-value {
  font-family: var(--font-mono);
  font-size: var(--text-sm);
}

.constraint-pattern {
  word-break: break-all;
  color: var(--color-teal);
  background: var(--color-teal-alpha);
  padding: 1px 4px;
  border-radius: var(--radius-sm);
}

.constraint-yes {
  color: var(--color-teal);
  background: var(--color-teal-alpha);
  padding: 1px 5px;
  border-radius: var(--radius-sm);
  font-size: var(--text-xs);
  font-weight: 500;
}

.constraint-denied {
  color: var(--color-orange);
  background: var(--color-orange-alpha);
  padding: 1px 5px;
  border-radius: var(--radius-sm);
  font-size: var(--text-xs);
  font-weight: 500;
}

/* Examples */
.example-group {
  margin-bottom: var(--space-4);
}

.example-label {
  font-size: var(--text-sm);
  font-weight: 500;
  color: var(--text-secondary);
  margin-bottom: var(--space-2);
}

.example-block {
  margin-bottom: var(--space-2);
}

.example-pre {
  background: var(--bg-secondary);
  border: 1px solid var(--border-light);
  border-radius: var(--radius-md);
  padding: var(--space-3);
  font-size: var(--text-sm);
  overflow-x: auto;
  margin: 0;
}

.example-pre code {
  font-family: var(--font-mono);
  color: var(--text-primary);
}

.example-generated {
  border-color: var(--color-primary-alpha);
  position: relative;
}

.example-group:has(.example-generated) .example-label::after {
  content: ' auto-generated';
  font-size: 10px;
  font-weight: 400;
  color: var(--text-muted);
  text-transform: none;
  font-style: italic;
}

.example-collapsible {
  cursor: default;
}

/* Dark mode overrides *//* Dark mode overrides */
:root[data-theme="dark"] .detail-panel {
  border-inline-start: 1px solid rgba(255, 255, 255, 0.08);
}

:root[data-theme="dark"] .enum-value-chip {
  background: rgba(255, 255, 255, 0.06);
  border-color: rgba(255, 255, 255, 0.12);
}

:root[data-theme="dark"] .example-pre {
  background: rgba(0, 0, 0, 0.15);
  border-color: rgba(255, 255, 255, 0.08);
}
</style>

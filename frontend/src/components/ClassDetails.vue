<script setup lang="ts">
import { computed } from 'vue'
import { useDataStore } from '../stores/dataStore'
import { useUiStore } from '../stores/uiStore'

const data = useDataStore()
const ui = useUiStore()

const cls = computed(() =>
  ui.currentClassId ? data.getClassById(ui.currentClassId) : null,
)

function formatCardinality(c: any): string {
  if (!c) return ''
  return `${c.min || '0'}..${c.max || '*'}`
}

function resolveType(typeName: string): { isBasic: boolean; classId: string | null } {
  const basicTypes = new Set([
    'String', 'Integer', 'Boolean', 'Real', 'UnlimitedNatural',
    'DateTime', 'URI', 'Any', 'Object',
  ])
  if (basicTypes.has(typeName)) return { isBasic: true, classId: null }
  const found = data.findClassByName(typeName)
  return { isBasic: false, classId: found ? found.id : null }
}

function associationTarget(assoc: any): any {
  if (!cls.value) return null
  if (assoc.source?.class !== cls.value.xmiId) return assoc.source
  return assoc.target
}

function badgeType(c: any): string {
  if (c.literals && c.literals.length > 0) return 'ENUMERATION'
  return c.type?.toUpperCase() || 'CLASS'
}
</script>

<template>
  <div class="detail-view" v-if="cls">
    <div class="entity-header">
      <div class="entity-title">
        <h2 class="entity-name">{{ cls.qualifiedName }}</h2>
        <div class="entity-subtitle" v-if="cls.package">
          <a href="#" class="link-button" @click.prevent="ui.selectPackage(cls.package!, data.getPackageById(cls.package!)?.name)">
            {{ data.getPackageById(cls.package)?.name || cls.package }}
          </a>
        </div>
      </div>
      <span class="entity-badge" :class="'badge-' + badgeType(cls)">{{ badgeType(cls) }}</span>
      <span class="entity-badge badge-abstract" v-if="cls.isAbstract">abstract</span>
    </div>

    <div class="entity-metadata" v-if="cls.stereotypes.length">
      <div class="metadata-item">
        <span class="metadata-label">Stereotypes</span>
        <span class="metadata-value">
          <span v-for="s in cls.stereotypes" :key="s" class="stereotype-tag">&laquo;{{ s }}&raquo;</span>
        </span>
      </div>
    </div>

    <div class="entity-definition" v-if="cls.definition">
      <div class="definition-content">{{ cls.definition }}</div>
    </div>

    <!-- Inheritance -->
    <div class="section" v-if="cls.generalizations.length || cls.specializations.length">
      <h3 class="section-title">Inheritance</h3>
      <div v-if="cls.generalizations.length" class="inheritance-group">
        <div class="inheritance-header">&#8593; Extends</div>
        <div v-for="parentId in cls.generalizations" :key="parentId" class="list-item clickable-row"
             @click="ui.selectClass(parentId)">
          <span class="list-item-name">{{ data.getClassById(parentId)?.name || parentId }}</span>
        </div>
      </div>
      <div v-if="cls.specializations.length" class="inheritance-group">
        <div class="inheritance-header">&#8595; Extended by</div>
        <div v-for="childId in cls.specializations" :key="childId" class="list-item clickable-row"
             @click="ui.selectClass(childId)">
          <span class="list-item-name">{{ data.getClassById(childId)?.name || childId }}</span>
        </div>
      </div>
    </div>

    <!-- Attributes -->
    <div class="section" v-if="cls.attributes.length">
      <h3 class="section-title">Attributes <span class="section-count">{{ cls.attributes.length }}</span></h3>
      <div class="table-wrapper">
        <table class="data-table">
          <thead>
            <tr>
              <th>Name</th>
              <th>Type</th>
              <th>Visibility</th>
              <th>Cardinality</th>
              <th>Modifiers</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="attrId in cls.attributes" :key="attrId" class="clickable-row">
              <td>{{ data.getAttributeById(attrId)?.name }}</td>
              <td>
                <template v-if="data.getAttributeById(attrId)?.type">
                  <a v-if="resolveType(data.getAttributeById(attrId)!.type).classId"
                     href="#" class="type-link"
                     @click.prevent="ui.selectClass(resolveType(data.getAttributeById(attrId)!.type).classId!)">
                    {{ data.getAttributeById(attrId)?.type }}
                  </a>
                  <span v-else-if="resolveType(data.getAttributeById(attrId)!.type).isBasic"
                        class="uml-basic-type">
                    {{ data.getAttributeById(attrId)?.type }}
                  </span>
                  <span v-else class="type-unresolved">{{ data.getAttributeById(attrId)?.type }}</span>
                </template>
              </td>
              <td>
                <span v-if="data.getAttributeById(attrId)?.visibility"
                      class="visibility-badge"
                      :data-visibility="data.getAttributeById(attrId)?.visibility">
                  {{ data.getAttributeById(attrId)?.visibility }}
                </span>
              </td>
              <td>{{ formatCardinality(data.getAttributeById(attrId)?.cardinality) }}</td>
              <td>
                <span v-if="data.getAttributeById(attrId)?.isStatic" class="modifier-badge">static</span>
                <span v-if="data.getAttributeById(attrId)?.isReadOnly" class="modifier-badge">readonly</span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- Inherited Attributes -->
    <div class="section" v-if="cls.inheritedAttributes.length">
      <h3 class="section-title">Inherited Attributes</h3>
      <div v-for="ia in cls.inheritedAttributes" :key="ia.attributeId" class="inheritance-group">
        <div class="inheritance-header">From {{ ia.inheritedFromName }}</div>
        <div class="table-wrapper">
          <table class="data-table inherited-table">
            <thead>
              <tr><th>Name</th><th>Type</th><th>Cardinality</th></tr>
            </thead>
            <tbody>
              <tr>
                <td>{{ ia.attribute.name }}</td>
                <td>{{ ia.attribute.type }}</td>
                <td>{{ formatCardinality(ia.attribute.cardinality) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <!-- Operations -->
    <div class="section" v-if="cls.operations.length">
      <h3 class="section-title">Operations <span class="section-count">{{ cls.operations.length }}</span></h3>
      <div class="table-wrapper">
        <table class="data-table">
          <thead>
            <tr><th>Name</th><th>Return</th><th>Visibility</th><th>Modifiers</th></tr>
          </thead>
          <tbody>
            <tr v-for="opId in cls.operations" :key="opId" class="clickable-row">
              <td>
                {{ data.getOperationById(opId)?.name }}(
                <span v-if="data.getOperationById(opId)?.parameters.length">
                  {{ data.getOperationById(opId)?.parameters.map(p => `${p.name}: ${p.type || '?'}`).join(', ') }}
                </span>
                )
              </td>
              <td>{{ data.getOperationById(opId)?.returnType || 'void' }}</td>
              <td>
                <span v-if="data.getOperationById(opId)?.visibility"
                      class="visibility-badge"
                      :data-visibility="data.getOperationById(opId)?.visibility">
                  {{ data.getOperationById(opId)?.visibility }}
                </span>
              </td>
              <td>
                <span v-if="data.getOperationById(opId)?.isStatic" class="modifier-badge">static</span>
                <span v-if="data.getOperationById(opId)?.isAbstract" class="modifier-badge">abstract</span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- Associations -->
    <div class="section" v-if="cls.associations.length">
      <h3 class="section-title">Associations <span class="section-count">{{ cls.associations.length }}</span></h3>
      <div class="table-wrapper">
        <table class="data-table">
          <thead>
            <tr><th>Name</th><th>Target</th><th>Cardinality</th><th>Aggregation</th></tr>
          </thead>
          <tbody>
            <tr v-for="assocId in cls.associations" :key="assocId">
              <td>{{ data.getAssociationById(assocId)?.name }}</td>
              <td>
                <template v-if="associationTarget(data.getAssociationById(assocId))">
                  <a v-if="associationTarget(data.getAssociationById(assocId))?.className"
                     href="#" class="type-link"
                     @click.prevent="() => {
                       const found = data.findClassByName(associationTarget(data.getAssociationById(assocId))?.className || '')
                       if (found) ui.selectClass(found.id)
                     }">
                    {{ associationTarget(data.getAssociationById(assocId))?.className }}
                  </a>
                </template>
              </td>
              <td>{{ formatCardinality(associationTarget(data.getAssociationById(assocId))?.cardinality) }}</td>
              <td>{{ associationTarget(data.getAssociationById(assocId))?.aggregation }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- Inherited Associations -->
    <div class="section" v-if="cls.inheritedAssociations.length">
      <h3 class="section-title">Inherited Associations</h3>
      <div v-for="ia in cls.inheritedAssociations" :key="ia.associationId" class="inheritance-group">
        <div class="inheritance-header">From {{ ia.inheritedFromName }}</div>
        <div class="list-item">
          <span class="list-item-name">{{ data.getAssociationById(ia.associationId)?.name }}</span>
          <span class="list-item-meta">{{ ia.localRole }}</span>
        </div>
      </div>
    </div>

    <!-- Enum Literals -->
    <div class="section" v-if="cls.literals.length">
      <h3 class="section-title">Literals <span class="section-count">{{ cls.literals.length }}</span></h3>
      <div class="item-list">
        <div v-for="lit in cls.literals" :key="lit.name" class="list-item">
          <span class="list-item-name">{{ lit.name }}</span>
          <span v-if="lit.definition" class="list-item-meta">{{ lit.definition }}</span>
        </div>
      </div>
    </div>
  </div>
</template>

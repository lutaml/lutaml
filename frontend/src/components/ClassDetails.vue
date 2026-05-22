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
</script>

<template>
  <div class="detail-view" v-if="cls">
    <div class="entity-header">
      <h2>{{ cls.qualifiedName }}</h2>
      <span class="type-badge">{{ cls.type }}</span>
      <span class="abstract-badge" v-if="cls.isAbstract">abstract</span>
    </div>

    <div class="entity-metadata">
      <div v-if="cls.package" class="meta-row">
        <span class="meta-label">Package:</span>
        <a href="#" class="type-link" @click.prevent="ui.selectPackage(cls.package!)">
          {{ data.getPackageById(cls.package)?.name || cls.package }}
        </a>
      </div>
      <div v-if="cls.stereotypes.length" class="meta-row">
        <span class="meta-label">Stereotypes:</span>
        <span class="stereotype-tags">
          <span v-for="s in cls.stereotypes" :key="s" class="stereotype-tag">&laquo;{{ s }}&raquo;</span>
        </span>
      </div>
    </div>

    <div class="definition" v-if="cls.definition">
      <p>{{ cls.definition }}</p>
    </div>

    <!-- Inheritance -->
    <div class="section" v-if="cls.generalizations.length || cls.specializations.length">
      <h3>Inheritance</h3>
      <div v-if="cls.generalizations.length" class="inheritance-group">
        <h4>&#8593; Extends</h4>
        <div v-for="parentId in cls.generalizations" :key="parentId" class="list-item clickable"
             @click="ui.selectClass(parentId)">
          <span class="item-name">{{ data.getClassById(parentId)?.name || parentId }}</span>
        </div>
      </div>
      <div v-if="cls.specializations.length" class="inheritance-group">
        <h4>&#8595; Extended by</h4>
        <div v-for="childId in cls.specializations" :key="childId" class="list-item clickable"
             @click="ui.selectClass(childId)">
          <span class="item-name">{{ data.getClassById(childId)?.name || childId }}</span>
        </div>
      </div>
    </div>

    <!-- Attributes -->
    <div class="section" v-if="cls.attributes.length">
      <h3>Attributes</h3>
      <div class="table-wrapper">
        <table>
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
            <tr v-for="attrId in cls.attributes" :key="attrId">
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
                      :class="data.getAttributeById(attrId)?.visibility">
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
      <h3>Inherited Attributes</h3>
      <div v-for="ia in cls.inheritedAttributes" :key="ia.attributeId" class="inheritance-group">
        <h4>From {{ ia.inheritedFromName }}</h4>
        <div class="table-wrapper">
          <table>
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
      <h3>Operations</h3>
      <div class="table-wrapper">
        <table>
          <thead>
            <tr><th>Name</th><th>Return</th><th>Visibility</th><th>Modifiers</th></tr>
          </thead>
          <tbody>
            <tr v-for="opId in cls.operations" :key="opId">
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
                      :class="data.getOperationById(opId)?.visibility">
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
      <h3>Associations</h3>
      <div class="table-wrapper">
        <table>
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
      <h3>Inherited Associations</h3>
      <div v-for="ia in cls.inheritedAssociations" :key="ia.associationId" class="inheritance-group">
        <h4>From {{ ia.inheritedFromName }}</h4>
        <div class="list-item">
          <span class="item-name">{{ data.getAssociationById(ia.associationId)?.name }}</span>
          <span class="item-meta">{{ ia.localRole }}</span>
        </div>
      </div>
    </div>

    <!-- Enum Literals -->
    <div class="section" v-if="cls.literals.length">
      <h3>Literals</h3>
      <div class="item-list">
        <div v-for="lit in cls.literals" :key="lit.name" class="list-item">
          <span class="item-name">{{ lit.name }}</span>
          <span v-if="lit.definition" class="item-meta">{{ lit.definition }}</span>
        </div>
      </div>
    </div>
  </div>
</template>

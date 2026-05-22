<script setup lang="ts">
import { computed } from 'vue'
import { useDataStore } from '../stores/dataStore'
import { useUiStore } from '../stores/uiStore'

const data = useDataStore()
const ui = useUiStore()

const pkg = computed(() =>
  ui.currentPackageId ? data.getPackageById(ui.currentPackageId) : null,
)

function typeIcon(type: string): string {
  switch (type) {
    case 'Class': return 'C'
    case 'DataType': return 'DT'
    case 'Enum': return 'E'
    case 'Interface': return 'I'
    default: return 'C'
  }
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
</script>

<template>
  <div class="detail-view" v-if="pkg">
    <div class="entity-header">
      <h2>{{ pkg.name }}</h2>
      <span class="type-badge">Package</span>
    </div>

    <div class="entity-metadata" v-if="pkg.path || pkg.stereotypes.length">
      <div v-if="pkg.path" class="meta-row">
        <span class="meta-label">Path:</span>
        <span>{{ pkg.path }}</span>
      </div>
      <div v-if="pkg.stereotypes.length" class="meta-row">
        <span class="meta-label">Stereotypes:</span>
        <span class="stereotype-tags">
          <span v-for="s in pkg.stereotypes" :key="s" class="stereotype-tag">&laquo;{{ s }}&raquo;</span>
        </span>
      </div>
    </div>

    <div class="definition" v-if="pkg.definition">
      <p>{{ pkg.definition }}</p>
    </div>

    <div class="section" v-if="pkg.diagrams.length">
      <h3>Diagrams</h3>
      <div class="item-list">
        <div v-for="diagId in pkg.diagrams" :key="diagId"
             class="list-item clickable" @click="ui.selectDiagram(diagId)">
          <span class="item-icon">&#128202;</span>
          <span class="item-name">{{ data.getDiagramById(diagId)?.name || diagId }}</span>
        </div>
      </div>
    </div>

    <div class="section" v-if="pkg.subPackages.length">
      <h3>Sub-Packages</h3>
      <div class="item-list">
        <div v-for="subId in pkg.subPackages" :key="subId"
             class="list-item clickable" @click="ui.selectPackage(subId)">
          <span class="item-icon">&#128193;</span>
          <span class="item-name">{{ data.getPackageById(subId)?.name || subId }}</span>
          <span class="count-badge">{{ data.getPackageById(subId)?.classes.length || 0 }}</span>
        </div>
      </div>
    </div>

    <div class="section" v-if="pkg.classes.length">
      <h3>Classes</h3>
      <div class="table-wrapper">
        <table>
          <thead>
            <tr>
              <th>Name</th>
              <th>Type</th>
              <th>Stereotypes</th>
              <th>Attrs</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="clsId in pkg.classes" :key="clsId" class="clickable"
                @click="ui.selectClass(clsId)">
              <td>{{ data.getClassById(clsId)?.name }}</td>
              <td><span class="type-badge">{{ data.getClassById(clsId)?.type }}</span></td>
              <td>
                <span v-for="s in (data.getClassById(clsId)?.stereotypes || [])" :key="s"
                      class="stereotype-tag">&laquo;{{ s }}&raquo;</span>
              </td>
              <td>{{ data.getClassById(clsId)?.attributes.length || 0 }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <div class="empty-state" v-if="!pkg.classes.length && !pkg.subPackages.length && !pkg.diagrams.length">
      <p>This package is empty.</p>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useDataStore } from '../stores/dataStore'
import { useUiStore } from '../stores/uiStore'

const data = useDataStore()
const ui = useUiStore()

const pkg = computed(() =>
  ui.currentPackageId ? data.getPackageById(ui.currentPackageId) : null,
)
</script>

<template>
  <div class="detail-view" v-if="pkg">
    <div class="entity-header">
      <div class="entity-title">
        <h2 class="entity-name">{{ pkg.name }}</h2>
        <div class="entity-subtitle" v-if="pkg.path">{{ pkg.path }}</div>
      </div>
      <span class="entity-badge badge-package">Package</span>
    </div>

    <div class="entity-metadata" v-if="pkg.stereotypes.length">
      <div class="metadata-item">
        <span class="metadata-label">Stereotypes</span>
        <span class="metadata-value">
          <span v-for="s in pkg.stereotypes" :key="s" class="stereotype-tag">&laquo;{{ s }}&raquo;</span>
        </span>
      </div>
    </div>

    <div class="entity-definition" v-if="pkg.definition">
      <div class="definition-content">{{ pkg.definition }}</div>
    </div>

    <div class="section" v-if="pkg.diagrams.length">
      <h3 class="section-title">Diagrams <span class="section-count">{{ pkg.diagrams.length }}</span></h3>
      <div class="item-list">
        <div v-for="diagId in pkg.diagrams" :key="diagId"
             class="list-item clickable-row" @click="ui.selectDiagram(diagId)">
          <span class="list-item-icon">&#128202;</span>
          <span class="list-item-name">{{ data.getDiagramById(diagId)?.name || diagId }}</span>
        </div>
      </div>
    </div>

    <div class="section" v-if="pkg.subPackages.length">
      <h3 class="section-title">Sub-Packages <span class="section-count">{{ pkg.subPackages.length }}</span></h3>
      <div class="item-list">
        <div v-for="subId in pkg.subPackages" :key="subId"
             class="list-item clickable-row" @click="ui.selectPackage(subId)">
          <span class="list-item-icon">&#128193;</span>
          <span class="list-item-name">{{ data.getPackageById(subId)?.name || subId }}</span>
          <span class="tree-count">{{ data.getPackageById(subId)?.classes.length || 0 }}</span>
        </div>
      </div>
    </div>

    <div class="section" v-if="pkg.classes.length">
      <h3 class="section-title">Classes <span class="section-count">{{ pkg.classes.length }}</span></h3>
      <div class="table-wrapper">
        <table class="data-table">
          <thead>
            <tr>
              <th>Name</th>
              <th>Type</th>
              <th>Stereotypes</th>
              <th>Attrs</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="clsId in pkg.classes" :key="clsId" class="clickable-row"
                @click="ui.selectClass(clsId)">
              <td>{{ data.getClassById(clsId)?.name }}</td>
              <td><span class="entity-badge" :class="'badge-' + (data.getClassById(clsId)?.type || 'class').toLowerCase()">{{ data.getClassById(clsId)?.type }}</span></td>
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

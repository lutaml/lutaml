<script setup lang="ts">
import { computed, ref } from 'vue'
import { useDataStore } from '../stores/dataStore'
import { useUiStore } from '../stores/uiStore'

const data = useDataStore()
const ui = useUiStore()

const diagram = computed(() =>
  ui.currentDiagramId ? data.getDiagramById(ui.currentDiagramId) : null,
)

const zoom = ref(1)
const panX = ref(0)
const panY = ref(0)

function zoomIn() { zoom.value = Math.min(zoom.value * 1.2, 5) }
function zoomOut() { zoom.value = Math.max(zoom.value / 1.2, 0.1) }
function resetView() { zoom.value = 1; panX.value = 0; panY.value = 0 }

function onWheel(e: WheelEvent) {
  e.preventDefault()
  if (e.deltaY < 0) zoomIn()
  else zoomOut()
}

function downloadSvg() {
  if (!diagram.value?.svg) return
  const blob = new Blob([diagram.value.svg], { type: 'image/svg+xml' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `${diagram.value.name || 'diagram'}.svg`
  a.click()
  URL.revokeObjectURL(url)
}

const svgTransform = computed(() =>
  `translate(${panX.value}px, ${panY.value}px) scale(${zoom.value})`
)
</script>

<template>
  <div class="detail-view" v-if="diagram">
    <div class="entity-header">
      <div class="entity-title">
        <h2 class="entity-name">{{ diagram.name }}</h2>
      </div>
      <span class="entity-badge badge-diagram">Diagram</span>
    </div>

    <div class="entity-metadata">
      <div class="metadata-item" v-if="diagram.type">
        <span class="metadata-label">Type</span>
        <span class="metadata-value">{{ diagram.type }}</span>
      </div>
      <div class="metadata-item">
        <span class="metadata-label">Elements</span>
        <span class="metadata-value">{{ diagram.objectCount }}</span>
      </div>
      <div class="metadata-item">
        <span class="metadata-label">Connectors</span>
        <span class="metadata-value">{{ diagram.linkCount }}</span>
      </div>
    </div>

    <div class="diagram-toolbar" v-if="diagram.svg">
      <button class="btn-sm" @click="zoomIn">Zoom In</button>
      <button class="btn-sm" @click="zoomOut">Zoom Out</button>
      <button class="btn-sm" @click="resetView">Reset</button>
      <button class="btn-sm" @click="downloadSvg">Download SVG</button>
    </div>

    <div class="diagram-svg-container" v-if="diagram.svg" @wheel="onWheel">
      <div class="diagram-svg" :style="{ transform: svgTransform }"
           v-html="diagram.svg" />
    </div>
  </div>
</template>

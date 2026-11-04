<template>
  <div ref="containerRef" class="diagram-view" v-html="sanitizedSvg" @click="handleClick"></div>
</template>

<script setup lang="ts">
import { computed, onUpdated, ref } from 'vue'
import { useSchemaStore } from '@/stores/schemaStore'
import { useUiStore } from '@/stores/uiStore'

const props = defineProps<{
  svg: string
}>()

const containerRef = ref<HTMLElement>()

const schemaStore = useSchemaStore()
const uiStore = useUiStore()

const sanitizedSvg = computed(() => {
  if (!props.svg) return ''
  return props.svg
})

// After the SVG is injected, compute a viewBox and explicit dimensions
// from the actual content so the diagram renders at full size
// instead of the default 300x150.
onUpdated(() => {
  const el = containerRef.value
  if (!el) return
  const svg = el.querySelector('svg')
  if (!svg) return

  const bbox = (svg as SVGSVGElement).getBBox()
  if (bbox.width <= 0 || bbox.height <= 0) return

  const pad = 10
  const w = bbox.width + pad * 2
  const h = bbox.height + pad * 2

  svg.setAttribute('viewBox', `${bbox.x - pad} ${bbox.y - pad} ${w} ${h}`)
  svg.setAttribute('width', String(w))
  svg.setAttribute('height', String(h))
})

function handleClick(event: MouseEvent) {
  const target = event.target as HTMLElement
  const link = target.closest('a')
  if (!link) return

  event.preventDefault()
  const href = link.getAttribute('href') || link.getAttribute('xlink:href')
  if (!href) return

  // Parse href like "schemas/xlinks/types/gml-abstract-gml-type"
  // or just navigate to the type by name from the URL
  const parts = href.split('/').filter(Boolean)
  if (parts.length >= 2) {
    const schemaId = parts[1] // e.g., "xlinks"
    const typeSegment = parts[parts.length - 1] // e.g., "gml-abstract-gml-type"

    // Convert slug to name: "gml-abstract-gml-type" -> "gml:AbstractGMLType"
    const typeName = slugToTypeName(typeSegment)

    // First try to find by exact schema + name
    const found = schemaStore.getTypeByName(typeName)
    if (found) {
      schemaStore.selectSchema(found.schema.id)
      schemaStore.selectType(found.data.id)
      uiStore.setPanelTab('diagram')
      uiStore.openDetailPanel()
    } else {
      // Fallback: try selecting by schema id directly
      schemaStore.selectSchema(schemaId)
      // Try to find type in selected schema by name
      const schema = schemaStore.getSchemaById(schemaId)
      if (schema) {
        for (const t of [...(schema.complex_types || []), ...(schema.simple_types || []), ...(schema.elements || [])]) {
          if (t.name?.toLowerCase().replace(/[^a-z0-9]/g, '-') === typeSegment) {
            schemaStore.selectType(t.id)
            uiStore.setPanelTab('diagram')
            uiStore.openDetailPanel()
            break
          }
        }
      }
    }
  }
}

function slugToTypeName(slug: string): string {
  // Convert "gml-abstract-gml-type" to "gml:AbstractGMLType"
  // The slug format is prefix-name-where-name-is-CamelCase
  const parts = slug.split('-')
  if (parts.length < 2) return slug

  // First part is the prefix (e.g., "gml")
  const prefix = parts[0]

  // Rest is the name parts joined together (e.g., ["AbstractGMLType"] or ["Abstract", "GML", "Type"])
  // We need to figure out where the prefix ends and the name begins
  // Since prefix is always before first colon, we can reconstruct
  const namePart = parts.slice(1).join('')
  return `${prefix}:${namePart}`
}
</script>

<style scoped>
.diagram-view {
  padding: var(--space-4);
  height: 100%;
  overflow: auto;
}

.diagram-view :deep(svg) {
  width: 100%;
  display: block;
  min-width: 900px;
  min-height: 1500px;
}

.diagram-view :deep(svg text) {
  fill: var(--text-primary);
  font-family: var(--font-sans);
}

.diagram-view :deep(svg .edge path),
.diagram-view :deep(svg .edge polygon) {
  stroke: var(--text-muted);
  fill: none;
}

.diagram-view :deep(svg .edge polygon) {
  fill: var(--text-muted);
}
</style>

import { ref, computed, watch } from 'vue'
import { useSchemaStore } from '../stores/schemaStore'
import { useUiStore } from '../stores/uiStore'

export interface SearchResult {
  id: string
  type: 'schema' | 'property' | 'definition'
  name: string
  rawName: string
  schemaName: string
  description?: string
  score: number
}

export function scoreResult(entry: SearchResult, q: string): number {
  const nameLower = entry.name.toLowerCase()
  const rawLower = entry.rawName.toLowerCase()
  const schemaLower = entry.schemaName.toLowerCase()
  const descLower = (entry.description || '').toLowerCase()

  if (rawLower === q || nameLower === q) return 100
  if (rawLower.startsWith(q) || nameLower.startsWith(q)) return 80
  if (schemaLower === q) return 70
  if (rawLower.includes(q) || nameLower.includes(q)) return 60
  if (schemaLower.startsWith(q)) return 50
  if (schemaLower.includes(q)) return 40
  if (descLower.includes(q)) return 20
  return 0
}

export function useSearch() {
  const schemaStore = useSchemaStore()
  const uiStore = useUiStore()

  const query = ref('')
  const results = ref<SearchResult[]>([])
  const isSearching = ref(false)
  let debounceTimer: ReturnType<typeof setTimeout> | null = null

  function buildSearchEntries(): SearchResult[] {
    return schemaStore.searchIndex.map(entry => ({
      id: `${entry.type}:${entry.schemaName}:${entry.name}`,
      type: entry.type as SearchResult['type'],
      name: entry.title || entry.name,
      rawName: entry.name,
      schemaName: entry.schemaName,
      description: entry.description,
      score: 0,
    }))
  }

  function search() {
    if (!query.value.trim()) {
      results.value = []
      return
    }

    isSearching.value = true
    const q = query.value.toLowerCase().trim()
    const entries = buildSearchEntries()

    results.value = entries
      .map(e => ({ ...e, score: scoreResult(e, q) }))
      .filter(e => e.score > 0)
      .sort((a, b) => b.score - a.score)
      .slice(0, 50)

    isSearching.value = false
  }

  function debouncedSearch() {
    if (debounceTimer) clearTimeout(debounceTimer)
    debounceTimer = setTimeout(search, 150)
  }

  watch(query, debouncedSearch)

  const hasResults = computed(() => results.value.length > 0)

  function selectResult(result: SearchResult) {
    schemaStore.selectSchema(result.schemaName)
    if (!uiStore.isSchemaExpanded(result.schemaName)) {
      uiStore.toggleSchemaExpanded(result.schemaName)
    }
    if (result.type === 'definition') {
      schemaStore.selectDefinition(result.rawName)
    } else {
      schemaStore.clearSelection()
    }
    uiStore.closeDetailPanel()
    closeSearch()
  }

  function closeSearch() {
    uiStore.closeSearch()
    query.value = ''
    results.value = []
  }

  return {
    query,
    results,
    isSearching,
    hasResults,
    selectResult,
    closeSearch,
  }
}

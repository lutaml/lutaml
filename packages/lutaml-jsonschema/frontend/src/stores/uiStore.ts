import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

export type Theme = 'light' | 'dark' | 'system'

export const useUiStore = defineStore('ui', () => {
  const theme = ref<Theme>('system')
  const resolvedTheme = ref<'light' | 'dark'>('light')
  const sidebarCollapsed = ref(false)
  const detailPanelOpen = ref(false)
  const activePanelTab = ref<'overview' | 'properties' | 'examples' | 'changes'>('overview')
  const searchOpen = ref(false)
  const expandedSchemaNames = ref<Set<string>>(new Set())

  const isDark = computed(() => resolvedTheme.value === 'dark')

  function initTheme() {
    const stored = localStorage.getItem('lutaml-jsonschema-theme') as Theme | null
    if (stored) theme.value = stored
    updateResolvedTheme()
  }

  function updateResolvedTheme() {
    if (theme.value === 'system') {
      resolvedTheme.value = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'
    } else {
      resolvedTheme.value = theme.value
    }
    applyTheme()
  }

  function applyTheme() {
    if (resolvedTheme.value === 'dark') {
      document.documentElement.setAttribute('data-theme', 'dark')
    } else {
      document.documentElement.removeAttribute('data-theme')
    }
  }

  function toggleTheme() {
    const next = resolvedTheme.value === 'light' ? 'dark' : 'light'
    theme.value = next
    localStorage.setItem('lutaml-jsonschema-theme', next)
    updateResolvedTheme()
  }

  function toggleSidebar() { sidebarCollapsed.value = !sidebarCollapsed.value }
  function openDetailPanel() { detailPanelOpen.value = true }
  function closeDetailPanel() { detailPanelOpen.value = false }
  function setPanelTab(tab: 'overview' | 'properties' | 'examples' | 'changes') { activePanelTab.value = tab }
  function openSearch() { searchOpen.value = true }
  function closeSearch() { searchOpen.value = false }

  function toggleSchemaExpanded(name: string) {
    if (expandedSchemaNames.value.has(name)) {
      expandedSchemaNames.value.delete(name)
    } else {
      expandedSchemaNames.value.add(name)
    }
  }

  function isSchemaExpanded(name: string): boolean {
    return expandedSchemaNames.value.has(name)
  }

  if (typeof window !== 'undefined') {
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', () => {
      if (theme.value === 'system') updateResolvedTheme()
    })
  }

  return {
    theme, resolvedTheme, sidebarCollapsed, detailPanelOpen, activePanelTab,
    searchOpen, expandedSchemaNames, isDark,
    initTheme, toggleTheme, toggleSidebar, openDetailPanel, closeDetailPanel,
    setPanelTab, openSearch, closeSearch, toggleSchemaExpanded, isSchemaExpanded,
  }
})

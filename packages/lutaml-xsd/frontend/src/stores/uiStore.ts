import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

export type Theme = 'light' | 'dark' | 'system'
export type PanelTab = 'overview' | 'types' | 'elements' | 'attributes' | 'definition' | 'source' | 'diagram'

export const useUiStore = defineStore('ui', () => {
  // State
  const theme = ref<Theme>('system')
  const resolvedTheme = ref<'light' | 'dark'>('light')
  const sidebarCollapsed = ref(false)
  const detailPanelOpen = ref(false)
  const activePanelTab = ref<PanelTab>('overview')
  const searchQuery = ref('')
  const searchOpen = ref(false)
  const aboutModalOpen = ref(false)
  const helpModalOpen = ref(false)
  const expandedSchemaIds = ref<Set<string>>(new Set())
  const expandedGroupIds = ref<Set<string>>(new Set())

  // Namespace filter state
  const enabledNamespaces = ref<Set<string>>(new Set())

  // Getters
  const isDark = computed(() => resolvedTheme.value === 'dark')

  // Actions
  function initTheme() {
    const stored = localStorage.getItem('lutaml-xsd-theme') as Theme | null
    if (stored) {
      theme.value = stored
    }
    updateResolvedTheme()
  }

  function setTheme(newTheme: Theme) {
    theme.value = newTheme
    localStorage.setItem('lutaml-xsd-theme', newTheme)
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
    setTheme(resolvedTheme.value === 'light' ? 'dark' : 'light')
  }

  function toggleSidebar() {
    sidebarCollapsed.value = !sidebarCollapsed.value
  }

  function openDetailPanel() {
    detailPanelOpen.value = true
  }

  function closeDetailPanel() {
    detailPanelOpen.value = false
  }

  function setPanelTab(tab: PanelTab) {
    activePanelTab.value = tab
  }

  function openSearch() {
    searchOpen.value = true
  }

  function closeSearch() {
    searchOpen.value = false
    searchQuery.value = ''
  }

  function toggleAboutModal() {
    aboutModalOpen.value = !aboutModalOpen.value
  }

  function toggleHelpModal() {
    helpModalOpen.value = !helpModalOpen.value
  }

  function toggleSchemaExpanded(schemaId: string) {
    if (expandedSchemaIds.value.has(schemaId)) {
      expandedSchemaIds.value.delete(schemaId)
    } else {
      expandedSchemaIds.value.add(schemaId)
    }
  }

  function toggleGroupExpanded(groupId: string) {
    if (expandedGroupIds.value.has(groupId)) {
      expandedGroupIds.value.delete(groupId)
    } else {
      expandedGroupIds.value.add(groupId)
    }
  }

  function isSchemaExpanded(schemaId: string): boolean {
    return expandedSchemaIds.value.has(schemaId)
  }

  function isGroupExpanded(groupId: string): boolean {
    return expandedGroupIds.value.has(groupId)
  }

  function setNamespacesEnabled(prefixes: string[]) {
    enabledNamespaces.value = new Set(prefixes)
  }

  function toggleNamespace(prefix: string) {
    if (enabledNamespaces.value.has(prefix)) {
      enabledNamespaces.value.delete(prefix)
    } else {
      enabledNamespaces.value.add(prefix)
    }
  }

  function isNamespaceEnabled(prefix: string): boolean {
    return enabledNamespaces.value.size === 0 || enabledNamespaces.value.has(prefix)
  }

  // Watch for system theme changes
  if (typeof window !== 'undefined') {
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', () => {
      if (theme.value === 'system') {
        updateResolvedTheme()
      }
    })
  }

  return {
    // State
    theme,
    resolvedTheme,
    sidebarCollapsed,
    detailPanelOpen,
    activePanelTab,
    searchQuery,
    searchOpen,
    aboutModalOpen,
    expandedSchemaIds,
    expandedGroupIds,
    enabledNamespaces,
    // Getters
    isDark,
    // Actions
    initTheme,
    setTheme,
    toggleTheme,
    toggleSidebar,
    openDetailPanel,
    closeDetailPanel,
    setPanelTab,
    openSearch,
    closeSearch,
    helpModalOpen,
    toggleAboutModal,
    toggleHelpModal,
    toggleSchemaExpanded,
    toggleGroupExpanded,
    isSchemaExpanded,
    isGroupExpanded,
    setNamespacesEnabled,
    toggleNamespace,
    isNamespaceEnabled
  }
})

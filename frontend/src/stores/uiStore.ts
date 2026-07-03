import { defineStore } from 'pinia'
import { useDataStore } from './dataStore'

export type ViewName = 'welcome' | 'package' | 'class' | 'search' | 'diagram'

interface Breadcrumb {
  label: string
  id?: string
  type?: string
}

export const useUiStore = defineStore('ui', {
  state: () => ({
    currentView: 'welcome' as ViewName,
    currentPackageId: null as string | null,
    currentPackageLabel: null as string | null,
    currentClassId: null as string | null,
    currentClassLabel: null as string | null,
    currentDiagramId: null as string | null,
    currentDiagramLabel: null as string | null,
    sidebarVisible: true,
    darkMode: false,
    expandedNodes: new Set<string>(),
    breadcrumbs: [] as Breadcrumb[],
    searchQuery: '',
  }),

  actions: {
    showWelcome() {
      this.currentView = 'welcome'
      this.currentPackageId = null
      this.currentClassId = null
      this.currentDiagramId = null
      this.breadcrumbs = []
      this.updateHash()
    },

    selectPackage(id: string, label?: string) {
      this.currentView = 'package'
      this.currentPackageId = id
      this.currentPackageLabel = label || null
      this.currentClassId = null
      this.currentDiagramId = null
      this.breadcrumbs = [{ label: label || 'Package', id, type: 'package' }]
      this.expandToNode(id)
      this.updateHash()
    },

    selectClass(id: string, label?: string) {
      this.currentView = 'class'
      this.currentClassId = id
      this.currentClassLabel = label || null
      this.currentDiagramId = null
      this.breadcrumbs = [
        ...(this.currentPackageId && this.currentPackageLabel
          ? [
              {
                label: this.currentPackageLabel,
                id: this.currentPackageId,
                type: 'package',
              },
            ]
          : []),
        { label: label || 'Class', id, type: 'class' },
      ]
      this.updateHash()
    },

    selectDiagram(id: string, label?: string) {
      this.currentView = 'diagram'
      this.currentDiagramId = id
      this.currentDiagramLabel = label || null
      this.breadcrumbs = [
        ...(this.currentPackageId && this.currentPackageLabel
          ? [
              {
                label: this.currentPackageLabel,
                id: this.currentPackageId,
                type: 'package',
              },
            ]
          : []),
        { label: label || 'Diagram', id, type: 'diagram' },
      ]
      this.updateHash()
    },

    showSearch(query: string) {
      this.currentView = 'search'
      this.searchQuery = query
      this.updateHash()
    },

    toggleNode(nodeId: string) {
      if (this.expandedNodes.has(nodeId)) {
        this.expandedNodes.delete(nodeId)
      } else {
        this.expandedNodes.add(nodeId)
      }
    },

    expandToNode(nodeId: string) {
      this.expandedNodes.add(nodeId)
    },

    expandAll() {
      const addAll = (nodes: any[]) => {
        for (const n of nodes) {
          this.expandedNodes.add(n.id)
          if (n.children) addAll(n.children)
        }
      }
    },

    collapseAll() {
      this.expandedNodes.clear()
    },

    toggleSidebar() {
      this.sidebarVisible = !this.sidebarVisible
    },

    toggleDarkMode() {
      this.darkMode = !this.darkMode
    },

    navigateToHash() {
      const hash = window.location.hash.slice(1)
      if (!hash) return

      const data = useDataStore()

      if (hash.startsWith('/package/')) {
        const id = hash.slice('/package/'.length)
        const pkg = data.getPackageById(id)
        this.selectPackage(id, pkg?.name)
      } else if (hash.startsWith('/class/')) {
        const id = hash.slice('/class/'.length)
        const cls = data.getClassById(id)
        this.selectClass(id, cls?.name)
      } else if (hash.startsWith('/diagram/')) {
        const id = hash.slice('/diagram/'.length)
        const diag = data.getDiagramById(id)
        this.selectDiagram(id, diag?.name)
      }
    },

    updateHash() {
      let hash = ''
      switch (this.currentView) {
        case 'package':
          hash = `/package/${this.currentPackageId}`
          break
        case 'class':
          hash = `/class/${this.currentClassId}`
          break
        case 'diagram':
          hash = `/diagram/${this.currentDiagramId}`
          break
        case 'search':
          hash = `/search?q=${encodeURIComponent(this.searchQuery)}`
          break
      }
      window.location.hash = hash
    },
  },
})

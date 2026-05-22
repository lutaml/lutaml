import { defineStore } from 'pinia'

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
    currentClassId: null as string | null,
    currentDiagramId: null as string | null,
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
      this.currentClassId = null
      this.currentDiagramId = null
      this.breadcrumbs = [{ label: label || 'Package', id, type: 'package' }]
      this.expandToNode(id)
      this.updateHash()
    },

    selectClass(id: string, label?: string) {
      this.currentView = 'class'
      this.currentClassId = id
      this.currentDiagramId = null
      this.breadcrumbs = [
        ...(this.currentPackageId
          ? [
              {
                label: 'Package',
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
      this.breadcrumbs = [
        ...(this.currentPackageId
          ? [
              {
                label: 'Package',
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

      if (hash.startsWith('/package/')) {
        this.selectPackage(hash.slice('/package/'.length))
      } else if (hash.startsWith('/class/')) {
        this.selectClass(hash.slice('/class/'.length))
      } else if (hash.startsWith('/diagram/')) {
        this.selectDiagram(hash.slice('/diagram/'.length))
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

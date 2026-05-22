import { defineStore } from 'pinia'
import type {
  SpaData,
  SpaDocument,
  SpaSearchIndex,
  SpaSearchEntry,
  SpaClass,
  SpaPackage,
  SpaAttribute,
  SpaAssociation,
  SpaOperation,
  SpaDiagram,
} from '../types'

export const useDataStore = defineStore('data', {
  state: () => ({
    metadata: null as SpaDocument['metadata'] | null,
    packageTree: null as SpaDocument['packageTree'] | null,
    packages: {} as Record<string, SpaPackage>,
    classes: {} as Record<string, SpaClass>,
    attributes: {} as Record<string, SpaAttribute>,
    associations: {} as Record<string, SpaAssociation>,
    operations: {} as Record<string, SpaOperation>,
    diagrams: {} as Record<string, SpaDiagram>,
    searchEntries: [] as SpaSearchEntry[],
    loaded: false,
  }),

  getters: {
    getClassById: (state) => (id: string) => state.classes[id],
    getPackageById: (state) => (id: string) => state.packages[id],
    getAttributeById: (state) => (id: string) => state.attributes[id],
    getAssociationById: (state) => (id: string) => state.associations[id],
    getOperationById: (state) => (id: string) => state.operations[id],
    getDiagramById: (state) => (id: string) => state.diagrams[id],

    classCount: (state) => Object.keys(state.classes).length,
    packageCount: (state) => Object.keys(state.packages).length,
    associationCount: (state) => Object.keys(state.associations).length,
    attributeCount: (state) => Object.keys(state.attributes).length,
  },

  actions: {
    loadFromEmbedded() {
      const win = window as any
      if (!win.__SPA_DATA__) {
        throw new Error('No embedded SPA data found in window.__SPA_DATA__')
      }
      this.loadData(win.__SPA_DATA__)
    },

    async loadFromUrl(dataUrl: string, searchUrl: string) {
      const [dataRes, searchRes] = await Promise.all([
        fetch(dataUrl),
        fetch(searchUrl),
      ])
      const data = await dataRes.json()
      const searchIndex = await searchRes.json()
      this.loadData({ ...data, searchIndex })
    },

    loadData(raw: SpaData) {
      this.metadata = raw.metadata
      this.packageTree = raw.packageTree
      this.packages = raw.packages || {}
      this.classes = raw.classes || {}
      this.attributes = raw.attributes || {}
      this.associations = raw.associations || {}
      this.operations = raw.operations || {}
      this.diagrams = raw.diagrams || {}
      this.searchEntries = raw.searchIndex?.documentStore || []
      this.loaded = true
    },

    findClassByName(name: string): SpaClass | undefined {
      return Object.values(this.classes).find((c) => c.name === name)
    },
  },
})

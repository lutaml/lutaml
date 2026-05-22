<script setup lang="ts">
import { onMounted, watch } from 'vue'
import { useDataStore } from './stores/dataStore'
import { useUiStore } from './stores/uiStore'
import AppSidebar from './components/AppSidebar.vue'
import AppHeader from './components/AppHeader.vue'
import WelcomeView from './components/WelcomeView.vue'
import PackageDetails from './components/PackageDetails.vue'
import ClassDetails from './components/ClassDetails.vue'
import DiagramView from './components/DiagramView.vue'
import SearchResults from './components/SearchResults.vue'

const data = useDataStore()
const ui = useUiStore()

onMounted(async () => {
  const win = window as any
  if (win.__SPA_DATA__) {
    data.loadFromEmbedded()
  } else if (win.__SPA_DATA_URL__) {
    await data.loadFromUrl(win.__SPA_DATA_URL__, win.__SPA_SEARCH_URL__)
  }

  ui.navigateToHash()
  window.addEventListener('hashchange', () => ui.navigateToHash())

  const saved = localStorage.getItem('uml-browser-preferences')
  if (saved) {
    try {
      const prefs = JSON.parse(saved)
      if (prefs.darkMode !== undefined) ui.darkMode = prefs.darkMode
      if (prefs.sidebarVisible !== undefined) ui.sidebarVisible = prefs.sidebarVisible
    } catch {}
  }
})

watch(() => [ui.darkMode, ui.sidebarVisible], () => {
  localStorage.setItem(
    'uml-browser-preferences',
    JSON.stringify({ darkMode: ui.darkMode, sidebarVisible: ui.sidebarVisible }),
  )
})
</script>

<template>
  <div class="app-layout" :data-theme="ui.darkMode ? 'dark' : 'light'">
    <AppSidebar />
    <div class="main-content">
      <AppHeader />
      <div class="content-area">
        <WelcomeView v-if="ui.currentView === 'welcome'" />
        <PackageDetails v-else-if="ui.currentView === 'package'" />
        <ClassDetails v-else-if="ui.currentView === 'class'" />
        <DiagramView v-else-if="ui.currentView === 'diagram'" />
        <SearchResults v-else-if="ui.currentView === 'search'" />
      </div>
    </div>
  </div>
</template>

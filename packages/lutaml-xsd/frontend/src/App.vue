<template>
  <div class="app-layout">
    <AppSidebar />
    <div class="main-content">
      <AppHeader />
      <div class="content-area">
        <RouterView />
      </div>
    </div>
    <DetailPanel v-if="uiStore.detailPanelOpen" />
    <SearchModal v-if="uiStore.searchOpen" />
    <AboutModal v-if="uiStore.aboutModalOpen" />
    <HelpModal v-if="uiStore.helpModalOpen" />
  </div>
</template>

<script setup lang="ts">
import { onMounted } from 'vue'
import { RouterView } from 'vue-router'
import { useSchemaStore } from '@/stores/schemaStore'
import { useUiStore } from '@/stores/uiStore'
import AppHeader from '@/components/AppHeader.vue'
import AppSidebar from '@/components/AppSidebar.vue'
import DetailPanel from '@/components/DetailPanel.vue'
import SearchModal from '@/components/SearchModal.vue'
import AboutModal from '@/components/AboutModal.vue'
import HelpModal from '@/components/HelpModal.vue'

const schemaStore = useSchemaStore()
const uiStore = useUiStore()

onMounted(() => {
  uiStore.initTheme()
  schemaStore.loadFromWindow()

  // Set initial namespaces enabled
  const allPrefixes = schemaStore.namespaces.map(n => n.prefix)
  uiStore.setNamespacesEnabled(allPrefixes)

  // Global keyboard shortcuts
  document.addEventListener('keydown', handleKeydown)
})

function handleKeydown(e: KeyboardEvent) {
  // '/' to focus search
  if (e.key === '/' && !isInputFocused()) {
    e.preventDefault()
    uiStore.openSearch()
  }
  // Escape to close panels
  if (e.key === 'Escape') {
    if (uiStore.searchOpen) {
      uiStore.closeSearch()
    } else if (uiStore.detailPanelOpen) {
      uiStore.closeDetailPanel()
    } else if (uiStore.helpModalOpen) {
      uiStore.toggleHelpModal()
    } else if (uiStore.aboutModalOpen) {
      uiStore.toggleAboutModal()
    }
  }
  // '?' for help, 'i' for about
  if (e.key === '?' && !isInputFocused()) {
    e.preventDefault()
    uiStore.toggleHelpModal()
  }
  if (e.key === 'i' && !isInputFocused()) {
    e.preventDefault()
    uiStore.toggleAboutModal()
  }
}

function isInputFocused(): boolean {
  const active = document.activeElement
  return active instanceof HTMLInputElement || active instanceof HTMLTextAreaElement
}
</script>

<style scoped>
.app-layout {
  display: flex;
  height: 100vh;
  overflow: hidden;
}

.main-content {
  flex: 1;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.content-area {
  flex: 1;
  overflow: auto;
  padding: var(--space-6);
  background: var(--bg-primary);
}
</style>

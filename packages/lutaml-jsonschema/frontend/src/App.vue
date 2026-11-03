<template>
  <div class="app-layout">
    <AppSidebar />
    <div v-if="!uiStore.sidebarCollapsed" class="sidebar-overlay" @click="uiStore.toggleSidebar"></div>
    <div class="main-content">
      <AppHeader />
      <div class="content-area" ref="contentAreaRef" @scroll="handleScroll">
        <HomeView />
      </div>
    </div>
    <DetailPanel v-if="uiStore.detailPanelOpen" />
    <SearchModal v-if="uiStore.searchOpen" />
    <button v-if="showBackToTop" class="back-to-top" @click="scrollToTop" :title="t('app.backToTop')" :aria-label="t('app.backToTopAria')">
      <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
        <path d="M8 13V3M4 7l4-4 4 4" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
      </svg>
    </button>
  </div>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useSchemaStore } from './stores/schemaStore'
import { useUiStore } from './stores/uiStore'
import AppHeader from './components/AppHeader.vue'
import { t, initLocaleFromUrl } from './i18n'
import AppSidebar from './components/AppSidebar.vue'
import DetailPanel from './components/DetailPanel.vue'
import SearchModal from './components/SearchModal.vue'
import HomeView from './views/HomeView.vue'

const schemaStore = useSchemaStore()
const uiStore = useUiStore()
const contentAreaRef = ref<HTMLElement | null>(null)
const showBackToTop = ref(false)

function handleScroll() {
  const el = contentAreaRef.value
  if (!el) return
  showBackToTop.value = el.scrollTop > 300
}

function scrollToTop() {
  contentAreaRef.value?.scrollTo({ top: 0, behavior: 'smooth' })
}

onMounted(() => {
  initLocaleFromUrl()
  uiStore.initTheme()
  schemaStore.loadFromWindow()

  if (schemaStore.metadata?.theme) {
    uiStore.theme = schemaStore.metadata.theme as 'light' | 'dark'
    uiStore.updateResolvedTheme()
  }

  handleHashNavigation()

  document.addEventListener('keydown', handleKeydown)
  window.addEventListener('hashchange', handleHashNavigation)
})

function handleHashNavigation() {
  const hash = window.location.hash.slice(1)
  if (!hash) return

  const parts = hash.split('/')
  if (parts.length >= 1 && schemaStore.schemas.length > 0) {
    const schemaName = decodeURIComponent(parts[0])
    schemaStore.selectSchema(schemaName)

    if (!uiStore.isSchemaExpanded(schemaName)) {
      uiStore.toggleSchemaExpanded(schemaName)
    }

    if (parts.length >= 2) {
      const target = decodeURIComponent(parts[1])
      if (target.startsWith('def-')) {
        schemaStore.selectDefinition(target.slice(4))
      } else if (target.startsWith('prop-')) {
        schemaStore.selectProperty(target.slice(5))
      }
    }
  }
}

function handleKeydown(e: KeyboardEvent) {
  if (e.key === '/' && !isInputFocused()) {
    e.preventDefault()
    uiStore.openSearch()
  }
  if (e.key === 'Escape') {
    if (uiStore.searchOpen) {
      uiStore.closeSearch()
    } else if (uiStore.detailPanelOpen) {
      uiStore.closeDetailPanel()
    }
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

/* Mobile sidebar overlay — hidden on desktop, shown on mobile when sidebar open */
.sidebar-overlay {
  display: none;
}

.back-to-top {
  position: fixed;
  bottom: 24px;
  inset-inline-end: 24px;
  width: 36px;
  height: 36px;
  border-radius: 50%;
  background: var(--bg-elevated);
  border: 1px solid var(--border-medium);
  box-shadow: var(--shadow-md);
  color: var(--text-secondary);
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 50;
  transition: all var(--transition-normal);
}

.back-to-top:hover {
  background: var(--color-primary);
  border-color: var(--color-primary);
  color: white;
  box-shadow: var(--shadow-lg);
  transform: translateY(-2px);
}

:root[data-theme="dark"] .back-to-top {
  background: var(--bg-elevated);
  border-color: var(--border-medium);
}

@media (max-width: 768px) {
  .sidebar-overlay {
    display: block;
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.4);
    z-index: 39;
  }

  .back-to-top {
    bottom: 16px;
    inset-inline-end: 16px;
  }
}
</style>

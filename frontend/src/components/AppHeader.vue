<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'
import { useUiStore } from '../stores/uiStore'

const ui = useUiStore()
const searchInput = ref<HTMLInputElement | null>(null)
const showSearchModal = ref(false)
const searchQuery = ref('')
const searchResults = ref<any[]>([])
const selectedIndex = ref(0)

function openSearch() {
  showSearchModal.value = true
  setTimeout(() => searchInput.value?.focus(), 50)
}

function closeSearch() {
  showSearchModal.value = false
  searchQuery.value = ''
  searchResults.value = []
}

function handleKeydown(e: KeyboardEvent) {
  if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
    e.preventDefault()
    openSearch()
  }
  if (e.key === '/' && !showSearchModal.value) {
    const target = e.target as HTMLElement
    if (target.tagName !== 'INPUT' && target.tagName !== 'TEXTAREA') {
      e.preventDefault()
      openSearch()
    }
  }
}

function navigateTo(id: string, type: string) {
  if (type === 'class') ui.selectClass(id)
  else if (type === 'package') ui.selectPackage(id)
  closeSearch()
}

onMounted(() => window.addEventListener('keydown', handleKeydown))
onUnmounted(() => window.removeEventListener('keydown', handleKeydown))
</script>

<template>
  <header class="header">
    <div class="header-left">
      <button class="btn btn-ghost sidebar-toggle" @click="ui.toggleSidebar()" title="Toggle sidebar">
        <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
          <path d="M3 5h14M3 10h14M3 15h14" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>
        </svg>
      </button>
      <button class="btn btn-ghost home-btn" @click="ui.showWelcome()" title="Overview">
        <svg width="18" height="18" viewBox="0 0 18 18" fill="none">
          <path d="M3 8.5L9 3.5L15 8.5" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round"/>
          <path d="M4 8.5V14.5C4 14.5 4 15.5 5 15.5H13C13 15.5 14 15.5 14 14.5V8.5" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round"/>
        </svg>
      </button>
      <span class="header-breadcrumb" v-if="ui.breadcrumbs.length">
        <template v-for="(crumb, i) in ui.breadcrumbs" :key="i">
          <span v-if="i > 0" class="breadcrumb-sep">/</span>
          <a v-if="crumb.id" href="#" @click.prevent="navigateTo(crumb.id, crumb.type || '')">{{ crumb.label }}</a>
          <span v-else>{{ crumb.label }}</span>
        </template>
      </span>
    </div>

    <div class="header-center">
      <button class="search-trigger" @click="openSearch">
        <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
          <circle cx="7" cy="7" r="5" stroke="currentColor" stroke-width="1.5"/>
          <path d="M11 11l3 3" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>
        </svg>
        <span class="search-placeholder">Search classes, packages...</span>
        <kbd class="search-kbd">/</kbd>
      </button>
    </div>

    <div class="header-right">
      <button class="btn btn-ghost theme-btn" @click="ui.toggleDarkMode()" :title="ui.darkMode ? 'Light mode' : 'Dark mode'">
        <svg v-if="ui.darkMode" width="18" height="18" viewBox="0 0 18 18" fill="none">
          <path d="M9 3V2M9 16v-1M3 9H2M16 9h-1M4.22 4.22l-.7-.7M14.48 14.48l-.7-.7M4.22 13.78l-.7.7M14.48 3.52l-.7.7" stroke="currentColor" stroke-width="1.3" stroke-linecap="round"/>
          <circle cx="9" cy="9" r="3.5" stroke="currentColor" stroke-width="1.3"/>
        </svg>
        <svg v-else width="18" height="18" viewBox="0 0 18 18" fill="none">
          <circle cx="9" cy="9" r="4" stroke="currentColor" stroke-width="1.4"/>
          <path d="M9 2v1.5M9 14.5V16M2 9h1.5M14.5 9H16M4.22 4.22l1.06 1.06M12.72 12.72l1.06 1.06M4.22 13.78l1.06-1.06M12.72 5.28l1.06-1.06" stroke="currentColor" stroke-width="1.4" stroke-linecap="round"/>
        </svg>
      </button>
    </div>
  </header>

  <Teleport to="body">
    <div class="search-modal-overlay" v-if="showSearchModal" @click.self="closeSearch">
      <div class="search-modal">
        <div class="search-input-wrapper">
          <input ref="searchInput" v-model="searchQuery" placeholder="Search classes, packages, attributes..."
                 @keydown.escape="closeSearch" autofocus />
        </div>
        <div class="search-results" v-if="searchResults.length">
          <div v-for="(result, i) in searchResults" :key="result.id"
               class="search-result" :class="{ focused: i === selectedIndex }"
               @click="navigateTo(result.entityId, result.type)">
            <span class="result-icon">
              <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
                <circle cx="8" cy="8" r="6" stroke="currentColor" stroke-width="1.2"/>
              </svg>
            </span>
            <div class="result-content">
              <span class="result-name">{{ result.name }}</span>
              <span class="result-path">{{ result.entityType }}</span>
            </div>
          </div>
        </div>
        <div class="search-footer">
          <span class="search-hints">
            <span><kbd>↑↓</kbd> navigate</span>
            <span><kbd>Enter</kbd> select</span>
            <span><kbd>Esc</kbd> close</span>
          </span>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'
import { useUiStore } from '../stores/uiStore'

const ui = useUiStore()
const searchInput = ref<HTMLInputElement | null>(null)
const showSearchModal = ref(false)
const searchQuery = ref('')
const searchResults = ref<any[]>([])
const selectedIndex = ref(0)

const UML_BASIC_TYPES = new Set([
  'String', 'Integer', 'Boolean', 'Real', 'UnlimitedNatural',
  'DateTime', 'URI', 'Any', 'Object', 'int', 'long', 'double',
  'float', 'boolean', 'string', 'dateTime', 'anyType', 'anySimpleType',
])

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
  <header class="app-header">
    <div class="header-left">
      <button class="sidebar-toggle" @click="ui.toggleSidebar()" title="Toggle sidebar">
        &#9776;
      </button>
      <button class="home-button" @click="ui.showWelcome()" title="Home">
        &#8962;
      </button>
      <span class="breadcrumb" v-if="ui.breadcrumbs.length">
        <template v-for="(crumb, i) in ui.breadcrumbs" :key="i">
          <span v-if="i > 0" class="breadcrumb-sep">/</span>
          <a v-if="crumb.id" href="#" @click.prevent="navigateTo(crumb.id, crumb.type || '')">{{ crumb.label }}</a>
          <span v-else>{{ crumb.label }}</span>
        </template>
      </span>
    </div>

    <div class="header-center">
      <button class="search-trigger" @click="openSearch">
        <span class="search-icon">&#128269;</span>
        <span>Search...</span>
        <kbd>/</kbd>
      </button>
    </div>

    <div class="header-right">
      <button class="theme-toggle" @click="ui.toggleDarkMode()" title="Toggle theme">
        {{ ui.darkMode ? '&#9728;' : '&#9790;' }}
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
               class="search-result-item" :class="{ selected: i === selectedIndex }"
               @click="navigateTo(result.entityId, result.type)">
            <span class="result-type">{{ result.entityType }}</span>
            <span class="result-name">{{ result.name }}</span>
          </div>
        </div>
        <div class="search-footer">
          <kbd>↑↓</kbd> navigate <kbd>Enter</kbd> select <kbd>Esc</kbd> close
        </div>
      </div>
    </div>
  </Teleport>
</template>

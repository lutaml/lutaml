<template>
  <header class="header">
    <div class="header-left">
      <button class="btn btn-ghost sidebar-toggle" @click="uiStore.toggleSidebar" :title="t('header.toggleSidebar')">
        <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
          <path d="M3 5h14M3 10h14M3 15h14" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>
        </svg>
      </button>
      <button class="btn btn-ghost home-btn" @click="goHome" :title="t('header.overview')">
        <svg width="18" height="18" viewBox="0 0 18 18" fill="none">
          <path d="M3 8.5L9 3.5L15 8.5" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round"/>
          <path d="M4 8.5V14.5C4 14.5 4 15.5 5 15.5H13C13 15.5 14 15.5 14 14.5V8.5" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round"/>
        </svg>
      </button>
      <span v-if="schemaStore.metadata" class="header-breadcrumb">
        <button class="breadcrumb-segment" @click="goHome">{{ schemaStore.metadata.title || t('header.docsTitle') }}</button>
        <template v-if="schemaStore.selectedSchema">
          <span class="breadcrumb-sep">/</span>
          <button class="breadcrumb-segment" @click="goSchema">{{ schemaStore.selectedSchema.title || schemaStore.selectedSchema.name }}</button>
        </template>
        <template v-if="schemaStore.selectedDefinitionName && activeDef">
          <span class="breadcrumb-sep">/</span>
          <span class="breadcrumb-segment breadcrumb-current">{{ activeDef.title || activeDef.name }}</span>
        </template>
      </span>
    </div>

    <div class="header-center">
      <button class="search-trigger" @click="uiStore.openSearch">
        <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
          <circle cx="7" cy="7" r="5" stroke="currentColor" stroke-width="1.5"/>
          <path d="M11 11l3 3" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>
        </svg>
        <span class="search-placeholder">{{ t('header.searchPlaceholder') }}</span>
        <kbd class="search-kbd">/</kbd>
      </button>
    </div>

    <div class="header-right">
      <button class="btn btn-ghost locale-btn" @click="switchLocale" :title="t('app.switchLocale')">
        {{ localeLabel(nextLocale()) }}
      </button>
      <button class="btn btn-ghost theme-btn" @click="uiStore.toggleTheme" :title="uiStore.isDark ? t('header.lightMode') : t('header.darkMode')">
        <svg v-if="uiStore.isDark" width="18" height="18" viewBox="0 0 18 18" fill="none">
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
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useSchemaStore } from '../stores/schemaStore'
import { useUiStore } from '../stores/uiStore'
import { localeLabel, nextLocale, setLocale } from '../i18n'

const schemaStore = useSchemaStore()
const uiStore = useUiStore()

const activeDef = computed(() => {
  if (!schemaStore.selectedDefinitionName || !schemaStore.selectedSchema) return null
  return schemaStore.selectedSchema.definitions.find(d => d.name === schemaStore.selectedDefinitionName)
})

function switchLocale() {
  setLocale(nextLocale())
}

function goHome() {
  schemaStore.selectSchema(null)
  uiStore.closeDetailPanel()
}

function goSchema() {
  schemaStore.clearSelection()
  uiStore.closeDetailPanel()
}
</script>

<style scoped>
.header {
  height: 56px;
  flex-shrink: 0;
  display: flex;
  align-items: center;
  padding: 0 var(--space-4);
  background: var(--bg-elevated);
  border-bottom: 1px solid var(--border-light);
  gap: var(--space-4);
}

.header-left {
  display: flex;
  align-items: center;
  gap: var(--space-3);
}

.sidebar-toggle {
  padding: var(--space-2);
}

.header-breadcrumb {
  display: flex;
  align-items: center;
  font-size: var(--text-sm);
  color: var(--text-muted);
}

.breadcrumb-item {
  color: var(--text-secondary);
}

.breadcrumb-segment {
  background: none;
  border: none;
  font-size: var(--text-sm);
  color: var(--text-secondary);
  cursor: pointer;
  padding: 0;
  font-family: inherit;
}

.breadcrumb-segment:hover {
  color: var(--color-primary);
  text-decoration: underline;
}

.breadcrumb-current {
  color: var(--text-primary);
  font-weight: 600;
  cursor: default;
}

.breadcrumb-current:hover {
  color: var(--text-primary);
  text-decoration: none;
}

.breadcrumb-sep {
  color: var(--text-muted);
  margin: 0 var(--space-1);
}

.home-btn {
  width: 32px;
  height: 32px;
  padding: 0;
  color: var(--text-secondary);
}

.header-center {
  flex: 1;
  display: flex;
  justify-content: center;
  max-width: 480px;
  margin: 0 auto;
}

.search-trigger {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  width: 100%;
  padding: var(--space-2) var(--space-3);
  background: var(--bg-secondary);
  border: 1px solid var(--border-light);
  border-radius: var(--radius-md);
  color: var(--text-muted);
  font-size: var(--text-sm);
  cursor: pointer;
  transition: all var(--transition-fast);
}

.search-trigger:hover {
  background: var(--bg-hover);
  border-color: var(--border-medium);
}

.search-placeholder {
  flex: 1;
  text-align: start;
}

.search-kbd {
  padding: 2px 6px;
  font-size: var(--text-xs);
  font-family: var(--font-mono);
  background: var(--bg-elevated);
  border: 1px solid var(--border-medium);
  border-radius: var(--radius-sm);
}

.header-right {
  display: flex;
  align-items: center;
  gap: var(--space-1);
}

.theme-btn {
  width: 32px;
  height: 32px;
  padding: 0;
}

.locale-btn {
  height: 32px;
  padding: 0 var(--space-2);
  font-size: var(--text-xs);
  font-weight: 600;
  color: var(--text-secondary);
}
</style>

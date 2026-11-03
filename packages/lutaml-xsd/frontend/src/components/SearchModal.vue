<template>
  <div class="search-modal-overlay" @click.self="closeSearch">
    <div class="search-modal">
      <div class="search-input-wrapper">
        <svg width="18" height="18" viewBox="0 0 18 18" fill="none" class="search-icon">
          <circle cx="8" cy="8" r="5.5" stroke="currentColor" stroke-width="1.5"/>
          <path d="M12 12l4 4" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>
        </svg>
        <input
          ref="inputRef"
          v-model="search.query.value"
          type="text"
          class="search-input"
          placeholder="Search types, elements, attributes..."
          @keydown="handleKeydown"
        />
        <button v-if="search.query.value" class="clear-btn" @click="search.query.value = ''">
          <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
            <path d="M4 4l6 6M10 4l-6 6" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>
          </svg>
        </button>
      </div>

      <div class="search-results" v-if="search.query.value">
        <div v-if="search.isSearching.value" class="search-loading">
          Searching...
        </div>
        <div v-else-if="!search.hasResults.value" class="search-empty">
          No results found for "{{ search.query.value }}"
        </div>
        <div v-else class="search-results-list">
          <div
            v-for="(result, index) in search.results.value"
            :key="result.id"
            class="search-result"
            :class="{ focused: focusedIndex === index }"
            @click="search.selectResult(result)"
            @mouseenter="focusedIndex = index"
          >
            <span class="result-icon">
              <svg v-if="result.type === 'complex'" width="16" height="16" viewBox="0 0 16 16" fill="none">
                <rect x="2" y="2" width="12" height="12" rx="2" stroke="currentColor" stroke-width="1.3" stroke-dasharray="3 2"/>
              </svg>
              <svg v-else-if="result.type === 'simple'" width="16" height="16" viewBox="0 0 16 16" fill="none">
                <circle cx="8" cy="8" r="5" stroke="currentColor" stroke-width="1.3"/>
                <path d="M5 8h6M8 5v6" stroke="currentColor" stroke-width="1.3" stroke-linecap="round"/>
              </svg>
              <svg v-else width="16" height="16" viewBox="0 0 16 16" fill="none">
                <rect x="3" y="3" width="10" height="10" rx="1.5" stroke="currentColor" stroke-width="1.3"/>
              </svg>
            </span>
            <div class="result-content">
              <span class="result-name" v-html="highlightMatch(result.name)"></span>
              <span class="result-schema">{{ result.schemaName }}</span>
            </div>
            <span :class="['badge', `badge-${result.type}`]">{{ result.type }}</span>
          </div>
        </div>
      </div>

      <div class="search-footer">
        <div class="search-hints">
          <span><kbd>↑</kbd><kbd>↓</kbd> Navigate</span>
          <span><kbd>↵</kbd> Select</span>
          <span><kbd>Esc</kbd> Close</span>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, nextTick } from 'vue'
import { useSearch } from '@/composables/useSearch'

const search = useSearch()
const inputRef = ref<HTMLInputElement | null>(null)
const focusedIndex = ref(0)

onMounted(() => {
  nextTick(() => inputRef.value?.focus())
})

function handleKeydown(e: KeyboardEvent) {
  if (e.key === 'ArrowDown') {
    e.preventDefault()
    focusedIndex.value = Math.min(focusedIndex.value + 1, search.results.value.length - 1)
  } else if (e.key === 'ArrowUp') {
    e.preventDefault()
    focusedIndex.value = Math.max(focusedIndex.value - 1, 0)
  } else if (e.key === 'Enter' && search.results.value[focusedIndex.value]) {
    e.preventDefault()
    search.selectResult(search.results.value[focusedIndex.value])
  } else if (e.key === 'Escape') {
    search.closeSearch()
  }
}

function closeSearch() {
  search.closeSearch()
}

function highlightMatch(text: string): string {
  const query = search.query.value
  if (!query) return text
  const regex = new RegExp(`(${query.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')})`, 'gi')
  return text.replace(regex, '<mark>$1</mark>')
}
</script>

<style scoped>
.search-modal-overlay {
  position: fixed;
  inset: 0;
  background: var(--bg-overlay);
  display: flex;
  align-items: flex-start;
  justify-content: center;
  padding-top: 10vh;
  z-index: 1000;
  animation: fadeIn var(--transition-fast);
}

.search-modal {
  width: 100%;
  max-width: 560px;
  background: var(--bg-elevated);
  border-radius: var(--radius-xl);
  box-shadow: var(--shadow-lg);
  overflow: hidden;
  animation: slideIn var(--transition-slow);
}

.search-input-wrapper {
  display: flex;
  align-items: center;
  gap: var(--space-3);
  padding: var(--space-4);
  border-bottom: 1px solid var(--border-light);
}

.search-icon {
  color: var(--text-muted);
  flex-shrink: 0;
}

.search-input {
  flex: 1;
  border: none;
  background: none;
  font-size: var(--text-base);
  color: var(--text-primary);
  outline: none;
}

.search-input::placeholder {
  color: var(--text-muted);
}

.clear-btn {
  padding: var(--space-1);
  color: var(--text-muted);
  border-radius: var(--radius-sm);
  transition: all var(--transition-fast);
}

.clear-btn:hover {
  background: var(--bg-hover);
  color: var(--text-primary);
}

.search-results {
  max-height: 400px;
  overflow-y: auto;
}

.search-loading,
.search-empty {
  padding: var(--space-8);
  text-align: center;
  color: var(--text-muted);
}

.search-results-list {
  padding: var(--space-2);
}

.search-result {
  display: flex;
  align-items: center;
  gap: var(--space-3);
  padding: var(--space-2) var(--space-3);
  border-radius: var(--radius-md);
  cursor: pointer;
  transition: background var(--transition-fast);
}

.search-result:hover,
.search-result.focused {
  background: var(--bg-hover);
}

.result-icon {
  color: var(--text-muted);
  display: flex;
  align-items: center;
}

.result-content {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 2px;
  min-width: 0;
}

.result-name {
  font-size: var(--text-sm);
  font-weight: 500;
  color: var(--text-primary);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.result-name :deep(mark) {
  background: var(--color-accent-alpha);
  color: var(--color-accent);
  padding: 0 2px;
  border-radius: 2px;
}

.result-schema {
  font-size: var(--text-xs);
  color: var(--text-muted);
}

.search-footer {
  padding: var(--space-3) var(--space-4);
  border-top: 1px solid var(--border-light);
  background: var(--bg-secondary);
}

.search-hints {
  display: flex;
  gap: var(--space-4);
  font-size: var(--text-xs);
  color: var(--text-muted);
}

.search-hints kbd {
  padding: 2px 5px;
  font-family: var(--font-mono);
  font-size: 10px;
  background: var(--bg-elevated);
  border: 1px solid var(--border-medium);
  border-radius: var(--radius-sm);
  margin-right: 2px;
}
</style>

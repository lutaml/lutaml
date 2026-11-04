<template>
  <div class="help-modal-overlay" @click.self="toggleAboutModal">
    <div class="help-modal">
      <div class="help-header">
        <h2>Keyboard Shortcuts</h2>
        <button class="btn btn-ghost" @click="toggleAboutModal">
          <svg width="18" height="18" viewBox="0 0 18 18" fill="none">
            <path d="M5 5l8 8M13 5l-8 8" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>
          </svg>
        </button>
      </div>

      <div class="help-content">
        <div class="shortcut-group">
          <h3>Navigation</h3>
          <div class="shortcut-list">
            <div class="shortcut-item">
              <kbd>/</kbd>
              <span>Focus search</span>
            </div>
            <div class="shortcut-item">
              <kbd>Esc</kbd>
              <span>Close panel / Clear search</span>
            </div>
            <div class="shortcut-item">
              <kbd>?</kbd>
              <span>Show keyboard shortcuts</span>
            </div>
            <div class="shortcut-item">
              <kbd>i</kbd>
              <span>Show About</span>
            </div>
          </div>
        </div>

        <div class="shortcut-group">
          <h3>Search</h3>
          <div class="shortcut-list">
            <div class="shortcut-item">
              <kbd>↑</kbd><kbd>↓</kbd>
              <span>Navigate results</span>
            </div>
            <div class="shortcut-item">
              <kbd>Enter</kbd>
              <span>Select result</span>
            </div>
          </div>
        </div>

        <div class="shortcut-group">
          <h3>Tree Navigation</h3>
          <div class="shortcut-list">
            <div class="shortcut-item">
              <kbd>→</kbd>
              <span>Expand node</span>
            </div>
            <div class="shortcut-item">
              <kbd>←</kbd>
              <span>Collapse node</span>
            </div>
            <div class="shortcut-item">
              <kbd>Enter</kbd>
              <span>Select / Go to detail</span>
            </div>
          </div>
        </div>

        <div class="shortcut-group">
          <h3>Theme</h3>
          <div class="shortcut-item">
            <div class="theme-icons">
              <svg width="16" height="16" viewBox="0 0 18 18" fill="none">
                <circle cx="9" cy="9" r="4" stroke="currentColor" stroke-width="1.4"/>
                <path d="M9 2v1.5M9 14.5V16M2 9h1.5M14.5 9H16M4.22 4.22l1.06 1.06M12.72 12.72l1.06 1.06M4.22 13.78l1.06-1.06M12.72 5.28l1.06-1.06" stroke="currentColor" stroke-width="1.4" stroke-linecap="round"/>
              </svg>
              <svg width="16" height="16" viewBox="0 0 18 18" fill="none">
                <path d="M9 3V2M9 16v-1M3 9H2M16 9h-1M4.22 4.22l-.7-.7M14.48 14.48l-.7-.7M4.22 13.78l-.7.7M14.48 3.52l-.7.7" stroke="currentColor" stroke-width="1.3" stroke-linecap="round"/>
                <circle cx="9" cy="9" r="3.5" stroke="currentColor" stroke-width="1.3"/>
              </svg>
            </div>
            <span>Toggle light/dark mode via header button</span>
          </div>
        </div>
      </div>

      <div class="help-footer">
        <p>Lutaml-XSD Documentation Browser</p>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { useUiStore } from '@/stores/uiStore'

const uiStore = useUiStore()

function toggleAboutModal() {
  uiStore.toggleAboutModal()
}
</script>

<style scoped>
.help-modal-overlay {
  position: fixed;
  inset: 0;
  background: var(--bg-overlay);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
  animation: fadeIn var(--transition-fast);
}

.help-modal {
  width: 100%;
  max-width: 480px;
  background: var(--bg-elevated);
  border-radius: var(--radius-xl);
  box-shadow: var(--shadow-lg);
  overflow: hidden;
  animation: slideIn var(--transition-slow);
}

.help-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: var(--space-4) var(--space-5);
  border-bottom: 1px solid var(--border-light);
}

.help-header h2 {
  font-size: var(--text-lg);
  font-weight: 600;
}

.help-content {
  padding: var(--space-5);
  display: flex;
  flex-direction: column;
  gap: var(--space-5);
}

.shortcut-group h3 {
  font-size: var(--text-xs);
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: var(--text-muted);
  margin-bottom: var(--space-2);
}

.shortcut-list {
  display: flex;
  flex-direction: column;
  gap: var(--space-2);
}

.shortcut-item {
  display: flex;
  align-items: center;
  gap: var(--space-3);
  font-size: var(--text-sm);
  color: var(--text-secondary);
}

.shortcut-item kbd {
  min-width: 60px;
  padding: var(--space-1) var(--space-2);
  font-family: var(--font-mono);
  font-size: var(--text-xs);
  text-align: center;
  background: var(--bg-secondary);
  border: 1px solid var(--border-medium);
  border-radius: var(--radius-sm);
  color: var(--text-primary);
}

.shortcut-item span {
  flex: 1;
}

.theme-icons {
  display: flex;
  align-items: center;
  gap: 2px;
  min-width: 60px;
}

.help-footer {
  padding: var(--space-3) var(--space-5);
  border-top: 1px solid var(--border-light);
  background: var(--bg-secondary);
  text-align: center;
}

.help-footer p {
  font-size: var(--text-xs);
  color: var(--text-muted);
}
</style>

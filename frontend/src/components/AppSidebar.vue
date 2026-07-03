<script setup lang="ts">
import { computed } from 'vue'
import { useDataStore } from '../stores/dataStore'
import { useUiStore } from '../stores/uiStore'
import PackageTreeNode from './PackageTreeNode.vue'

const data = useDataStore()
const ui = useUiStore()

const LUTAML_LOGO_LIGHT = 'https://raw.githubusercontent.com/lutaml/branding/refs/heads/main/svg/lutaml-logo_logo-icon-light.svg'
const LUTAML_LOGO_DARK = 'https://raw.githubusercontent.com/lutaml/branding/refs/heads/main/svg/lutaml-logo_logo-icon-dark.svg'
const LUTAML_FULL_LIGHT = 'https://raw.githubusercontent.com/lutaml/branding/refs/heads/main/svg/lutaml-logo_logo-full-light.svg'
const LUTAML_FULL_DARK = 'https://raw.githubusercontent.com/lutaml/branding/refs/heads/main/svg/lutaml-logo_logo-full-dark.svg'

const brandingLogo = computed(() => {
  const logos = data.metadata?.appearance?.logos
  if (logos?.square) {
    const variant = ui.darkMode ? logos.square.dark : logos.square.light
    return variant?.url || variant?.path || (ui.darkMode ? LUTAML_LOGO_DARK : LUTAML_LOGO_LIGHT)
  }
  return ui.darkMode ? LUTAML_LOGO_DARK : LUTAML_LOGO_LIGHT
})

const footerLogo = computed(() => {
  return ui.darkMode ? LUTAML_FULL_DARK : LUTAML_FULL_LIGHT
})

function formatDate(isoString?: string): string {
  if (!isoString) return ''
  try {
    const date = new Date(isoString)
    return date.toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' })
  } catch {
    return isoString
  }
}
</script>

<template>
  <aside class="sidebar" :class="{ collapsed: !ui.sidebarVisible }">
    <div class="sidebar-content">
      <!-- Branding -->
      <div class="sidebar-branding">
        <img :src="brandingLogo" alt="Logo" class="branding-logo" />
        <div class="branding-text">
          <span class="branding-title">{{ data.metadata?.title || 'LutaML' }}</span>
          <span class="branding-subtitle">UML Browser</span>
        </div>
      </div>

      <!-- Overview -->
      <div class="sidebar-section overview-section">
        <button class="overview-btn" :class="{ active: ui.currentView === 'welcome' }"
                @click="ui.showWelcome()">
          <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
            <path d="M2 7.5L8 2.5L14 7.5" stroke="currentColor" stroke-width="1.3" stroke-linecap="round" stroke-linejoin="round"/>
            <path d="M3 7.5V13.5C3 13.5 3 14 4 14H12C12 14 13 14 13 13.5V7.5" stroke="currentColor" stroke-width="1.3" stroke-linecap="round" stroke-linejoin="round"/>
          </svg>
          <span>Overview</span>
        </button>
      </div>

      <!-- Package Tree -->
      <div class="sidebar-section tree-section">
        <div class="section-header">
          <span class="section-title">Packages</span>
          <div class="tree-controls">
            <button class="btn btn-ghost" @click="ui.expandAll()" title="Expand All">
              <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
                <path d="M2 5l5 5 5-5" stroke="currentColor" stroke-width="1.3" stroke-linecap="round" stroke-linejoin="round"/>
              </svg>
            </button>
            <button class="btn btn-ghost" @click="ui.collapseAll()" title="Collapse All">
              <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
                <path d="M2 9l5-5 5 5" stroke="currentColor" stroke-width="1.3" stroke-linecap="round" stroke-linejoin="round"/>
              </svg>
            </button>
          </div>
        </div>
        <div class="package-tree" v-if="data.packageTree">
          <PackageTreeNode :node="data.packageTree" />
        </div>
        <div v-else class="loading">Loading...</div>
      </div>

      <!-- Stats -->
      <div class="sidebar-section stats-section" v-if="data.metadata">
        <div class="stats-grid">
          <div class="stat-item">
            <span class="stat-value">{{ data.metadata.statistics.packages }}</span>
            <span class="stat-label">Packages</span>
          </div>
          <div class="stat-item">
            <span class="stat-value">{{ data.metadata.statistics.classes }}</span>
            <span class="stat-label">Classes</span>
          </div>
          <div class="stat-item">
            <span class="stat-value">{{ data.metadata.statistics.associations }}</span>
            <span class="stat-label">Associations</span>
          </div>
        </div>
      </div>

      <!-- Footer -->
      <div class="sidebar-footer">
        <a href="https://www.lutaml.org" target="_blank" rel="noopener" class="footer-brand" title="LutaML">
          <img :src="footerLogo" alt="LutaML" class="lutaml-logo" />
        </a>
        <div class="footer-text-group">
          <span class="footer-text" v-if="data.metadata?.generated">
            Generated {{ formatDate(data.metadata.generated) }} with
            <a href="https://github.com/lutaml/lutaml" target="_blank" rel="noopener">LutaML</a>
            v{{ data.metadata.version || '?' }}
          </span>
        </div>
      </div>
    </div>
  </aside>
</template>

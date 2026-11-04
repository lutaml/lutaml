<template>
  <div class="about-modal-overlay" @click.self="uiStore.toggleAboutModal">
    <div class="about-modal">
      <div class="about-header">
        <h2>About This Package</h2>
        <button class="btn btn-ghost" @click="uiStore.toggleAboutModal">
          <svg width="18" height="18" viewBox="0 0 18 18" fill="none">
            <path d="M5 5l8 8M13 5l-8 8" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>
          </svg>
        </button>
      </div>

      <div class="about-content">
        <!-- Package Identity -->
        <div class="about-section">
          <div class="package-identity">
            <img
              v-if="schemaStore.metadata?.appearance?.logos?.long"
              :src="logoSrc(schemaStore.metadata.appearance.logos.long)"
              alt="Package logo"
              class="package-logo"
              @error="longLogoFailed = true"
            />
            <div class="package-title-block">
              <h3 class="package-title">{{ schemaStore.metadata?.title || schemaStore.metadata?.name || 'XSD Schema Package' }}</h3>
              <div class="package-meta-line">
                <span v-if="schemaStore.metadata?.version" class="package-version">v{{ schemaStore.metadata.version }}</span>
                <span v-if="schemaStore.metadata?.license" class="package-license">
                  <a v-if="schemaStore.metadata?.license_url" :href="schemaStore.metadata.license_url" target="_blank" rel="noopener" class="license-link">
                    {{ schemaStore.metadata.license }}
                  </a>
                  <span v-else>{{ schemaStore.metadata.license }}</span>
                </span>
              </div>
            </div>
          </div>
        </div>

        <!-- Description -->
        <div v-if="schemaStore.metadata?.description" class="about-section">
          <p class="package-description">{{ schemaStore.metadata.description }}</p>
        </div>

        <!-- Authors -->
        <div v-if="schemaStore.metadata?.authors?.length" class="about-section">
          <h4 class="section-label">Authors</h4>
          <ul class="authors-list">
            <li v-for="(author, i) in schemaStore.metadata.authors" :key="i" class="author-item">
              <span class="author-name">{{ author.name }}</span>
              <a v-if="author.email" :href="'mailto:' + author.email" class="author-email">{{ author.email }}</a>
            </li>
          </ul>
        </div>

        <!-- Tags -->
        <div v-if="schemaStore.metadata?.tags?.length" class="about-section">
          <h4 class="section-label">Tags</h4>
          <div class="tags-list">
            <span v-for="tag in schemaStore.metadata.tags" :key="tag" class="tag-badge">{{ tag }}</span>
          </div>
        </div>

        <!-- Links -->
        <div v-if="schemaStore.metadata?.links?.length" class="about-section">
          <h4 class="section-label">Links</h4>
          <ul class="links-list">
            <li v-for="link in schemaStore.metadata.links" :key="link.name" class="link-item">
              <a :href="link.url" target="_blank" rel="noopener" class="link-a">
                {{ link.name }}
                <svg width="12" height="12" viewBox="0 0 12 12" fill="none" class="external-icon">
                  <path d="M5 2H2.5A.5.5 0 002 2.5v7a.5.5 0 00.5.5h7a.5.5 0 00.5-.5V7M7 2h3m0 0v3m0-3L5.5 6.5" stroke="currentColor" stroke-width="1.2" stroke-linecap="round" stroke-linejoin="round"/>
                </svg>
              </a>
            </li>
          </ul>
        </div>

        <!-- Additional Links -->
        <div v-if="hasAdditionalLinks" class="about-section">
          <h4 class="section-label">Resources</h4>
          <ul class="links-list">
            <li v-if="schemaStore.metadata?.homepage" class="link-item">
              <a :href="schemaStore.metadata.homepage" target="_blank" rel="noopener" class="link-a">
                Homepage
                <svg width="12" height="12" viewBox="0 0 12 12" fill="none" class="external-icon">
                  <path d="M5 2H2.5A.5.5 0 002 2.5v7a.5.5 0 00.5.5h7a.5.5 0 00.5-.5V7M7 2h3m0 0v3m0-3L5.5 6.5" stroke="currentColor" stroke-width="1.2" stroke-linecap="round" stroke-linejoin="round"/>
                </svg>
              </a>
            </li>
            <li v-if="schemaStore.metadata?.repository" class="link-item">
              <a :href="schemaStore.metadata.repository" target="_blank" rel="noopener" class="link-a">
                Repository
                <svg width="12" height="12" viewBox="0 0 12 12" fill="none" class="external-icon">
                  <path d="M5 2H2.5A.5.5 0 002 2.5v7a.5.5 0 00.5.5h7a.5.5 0 00.5-.5V7M7 2h3m0 0v3m0-3L5.5 6.5" stroke="currentColor" stroke-width="1.2" stroke-linecap="round" stroke-linejoin="round"/>
                </svg>
              </a>
            </li>
            <li v-if="schemaStore.metadata?.documentation" class="link-item">
              <a :href="schemaStore.metadata.documentation" target="_blank" rel="noopener" class="link-a">
                Documentation
                <svg width="12" height="12" viewBox="0 0 12 12" fill="none" class="external-icon">
                  <path d="M5 2H2.5A.5.5 0 002 2.5v7a.5.5 0 00.5.5h7a.5.5 0 00.5-.5V7M7 2h3m0 0v3m0-3L5.5 6.5" stroke="currentColor" stroke-width="1.2" stroke-linecap="round" stroke-linejoin="round"/>
                </svg>
              </a>
            </li>
          </ul>
        </div>

        <!-- Schema Stats -->
        <div class="about-section stats-section">
          <div class="stats-row">
            <div class="stat">
              <span class="stat-value">{{ schemaStore.schemaCounts.total }}</span>
              <span class="stat-label">Schemas</span>
            </div>
            <div class="stat">
              <span class="stat-value">{{ schemaStore.schemaCounts.types }}</span>
              <span class="stat-label">Types</span>
            </div>
            <div class="stat">
              <span class="stat-value">{{ schemaStore.schemaCounts.elements }}</span>
              <span class="stat-label">Elements</span>
            </div>
            <div class="stat">
              <span class="stat-value">{{ schemaStore.metadata?.generated ? formatDate(schemaStore.metadata.generated) : '—' }}</span>
              <span class="stat-label">Generated</span>
            </div>
          </div>
        </div>
      </div>

      <div class="about-footer">
        <span>Generated with <a href="https://github.com/lutaml/lutaml-xsd" target="_blank" rel="noopener">LutaML XSD</a></span>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import { useSchemaStore } from '@/stores/schemaStore'
import { useUiStore } from '@/stores/uiStore'

const schemaStore = useSchemaStore()
const uiStore = useUiStore()

const longLogoFailed = ref(false)

function logoSrc(logo: { light?: { path?: string; url?: string }; dark?: { path?: string; url?: string } }): string {
  const variant = uiStore.isDark ? logo.dark : logo.light
  return variant?.path || variant?.url || ''
}

const hasAdditionalLinks = computed(() => {
  const m = schemaStore.metadata
  return !!(m?.homepage || m?.repository || m?.documentation)
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

<style scoped>
.about-modal-overlay {
  position: fixed;
  inset: 0;
  background: var(--bg-overlay);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
  animation: fadeIn var(--transition-fast);
}

.about-modal {
  width: 100%;
  max-width: 540px;
  max-height: 85vh;
  background: var(--bg-elevated);
  border-radius: var(--radius-xl);
  box-shadow: var(--shadow-lg);
  overflow: hidden;
  display: flex;
  flex-direction: column;
  animation: slideIn var(--transition-slow);
}

.about-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: var(--space-4) var(--space-5);
  border-bottom: 1px solid var(--border-light);
  flex-shrink: 0;
}

.about-header h2 {
  font-size: var(--text-lg);
  font-weight: 600;
}

.about-content {
  padding: var(--space-5);
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: var(--space-5);
}

.about-section {
  display: flex;
  flex-direction: column;
  gap: var(--space-2);
}

.section-label {
  font-size: var(--text-xs);
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: var(--text-muted);
}

.package-identity {
  display: flex;
  align-items: center;
  gap: var(--space-4);
}

.package-logo {
  height: 48px;
  width: auto;
  flex-shrink: 0;
}

.package-title-block {
  display: flex;
  flex-direction: column;
  gap: var(--space-1);
}

.package-title {
  font-size: var(--text-lg);
  font-weight: 600;
  color: var(--text-primary);
}

.package-meta-line {
  display: flex;
  align-items: center;
  gap: var(--space-3);
  font-size: var(--text-sm);
  color: var(--text-muted);
}

.package-version {
  font-family: var(--font-mono);
}

.package-license {
  font-size: var(--text-xs);
}

.license-link {
  color: var(--color-primary);
  text-decoration: none;
}

.license-link:hover {
  text-decoration: underline;
}

.package-description {
  font-size: var(--text-sm);
  color: var(--text-secondary);
  line-height: 1.6;
}

.authors-list {
  list-style: none;
  padding: 0;
  margin: 0;
  display: flex;
  flex-direction: column;
  gap: var(--space-2);
}

.author-item {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  font-size: var(--text-sm);
}

.author-name {
  color: var(--text-primary);
  font-weight: 500;
}

.author-email {
  color: var(--color-primary);
  font-size: var(--text-xs);
  text-decoration: none;
}

.author-email:hover {
  text-decoration: underline;
}

.tags-list {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-2);
}

.tag-badge {
  font-size: var(--text-xs);
  padding: 2px 8px;
  background: var(--color-primary-alpha);
  color: var(--color-primary);
  border-radius: var(--radius-sm);
}

.links-list {
  list-style: none;
  padding: 0;
  margin: 0;
  display: flex;
  flex-direction: column;
  gap: var(--space-2);
}

.link-item {
  font-size: var(--text-sm);
}

.link-a {
  display: inline-flex;
  align-items: center;
  gap: var(--space-1);
  color: var(--color-primary);
  text-decoration: none;
}

.link-a:hover {
  text-decoration: underline;
}

.external-icon {
  opacity: 0.6;
}

.stats-section {
  padding-top: var(--space-3);
  border-top: 1px solid var(--border-light);
}

.stats-row {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: var(--space-3);
  text-align: center;
}

.stat {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.stat-value {
  font-size: var(--text-base);
  font-weight: 600;
  color: var(--text-primary);
}

.stat-label {
  font-size: var(--text-xs);
  color: var(--text-muted);
}

.about-footer {
  padding: var(--space-3) var(--space-5);
  border-top: 1px solid var(--border-light);
  background: var(--bg-secondary);
  text-align: center;
  font-size: var(--text-xs);
  color: var(--text-muted);
  flex-shrink: 0;
}

.about-footer a {
  color: var(--color-primary);
  text-decoration: none;
}

.about-footer a:hover {
  text-decoration: underline;
}
</style>

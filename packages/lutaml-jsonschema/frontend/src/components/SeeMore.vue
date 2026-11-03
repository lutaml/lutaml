<template>
  <div class="see-more-wrap">
    <div
      ref="contentRef"
      class="see-more-content"
      :class="{ collapsed: !expanded }"
    >
      <slot />
    </div>
    <button
      v-if="overflowing"
      class="see-more-toggle"
      @click="expanded = !expanded"
    >
      {{ expanded ? t('seeMore.showLess') : t('seeMore.showMore') }}
    </button>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'
import { t } from '../i18n'

const TOLERANCE_PX = 20
const MAX_HEIGHT = '3.6em'

const props = withDefaults(defineProps<{
  maxHeight?: string
}>(), {
  maxHeight: MAX_HEIGHT,
})

const contentRef = ref<HTMLElement | null>(null)
const expanded = ref(false)
const overflowing = ref(false)

let observer: ResizeObserver | null = null

function checkOverflow() {
  const el = contentRef.value
  if (!el) return
  overflowing.value = el.scrollHeight > el.clientHeight + TOLERANCE_PX
}

onMounted(() => {
  checkOverflow()
  if (contentRef.value) {
    observer = new ResizeObserver(checkOverflow)
    observer.observe(contentRef.value)
  }
})

onUnmounted(() => {
  observer?.disconnect()
})
</script>

<style scoped>
.see-more-content {
  transition: max-height var(--transition-slow);
}

.see-more-content.collapsed {
  max-height: v-bind(maxHeight);
  overflow: hidden;
  -webkit-mask-image: linear-gradient(to bottom, black 60%, transparent 100%);
  mask-image: linear-gradient(to bottom, black 60%, transparent 100%);
}

.see-more-toggle {
  display: block;
  font-size: var(--text-xs);
  color: var(--color-primary);
  background: none;
  border: none;
  cursor: pointer;
  padding: 2px 0;
  margin-top: 2px;
}

.see-more-toggle:hover {
  text-decoration: underline;
}
</style>

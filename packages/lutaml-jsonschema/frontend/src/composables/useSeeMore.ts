import { ref, computed } from 'vue'

export function useSeeMore(maxItems: number) {
  const expanded = ref(false)
  const toggle = () => { expanded.value = !expanded.value }
  const isExpanded = computed(() => expanded.value)
  function visibleItems<T>(items: T[]): T[] {
    if (expanded.value || items.length <= maxItems) return items
    return items.slice(0, maxItems)
  }
  function hasMore<T>(items: T[]): boolean {
    return items.length > maxItems && !expanded.value
  }
  return { isExpanded, toggle, visibleItems, hasMore }
}

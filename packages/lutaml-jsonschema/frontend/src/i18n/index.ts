import { ref } from 'vue'
import { messages, type Locale, type MessageKey } from './messages'

// The locale rides a Vue ref so every rendered string is a reactive
// dependency: flipping the locale re-renders exactly the components
// that showed translated text.
const activeLocale = ref<Locale>('en')

/** Native names, shown on the switch button for the TARGET locale. */
const LOCALE_LABELS: Record<Locale, string> = {
  en: 'English',
  ar: 'العربية',
}

/** Writing direction per locale — RTL locales must mirror the layout. */
const RTL_LOCALES: readonly string[] = ['ar', 'he', 'fa', 'ur']

export function locale(): Locale {
  return activeLocale.value
}

export function locales(): Locale[] {
  return Object.keys(messages) as Locale[]
}

export function localeLabel(id: Locale): string {
  return LOCALE_LABELS[id]
}

export function isLocale(value: unknown): value is Locale {
  return typeof value === 'string' && locales().includes(value as Locale)
}

/** The locale the switch button would move to (single-step cycle). */
export function nextLocale(): Locale {
  const all = locales()
  return all[(all.indexOf(activeLocale.value) + 1) % all.length]
}

export function directionFor(id: Locale): 'ltr' | 'rtl' {
  return RTL_LOCALES.includes(id) ? 'rtl' : 'ltr'
}

/** Mirror <html lang/dir> so layout, fonts and scrollbars follow the locale. */
export function applyDocumentLocale(id: Locale = activeLocale.value): void {
  if (typeof document === 'undefined') return
  document.documentElement.lang = id
  document.documentElement.dir = directionFor(id)
}

/** Boot-time locale: an explicit `?locale=` wins, else the default. */
export function initLocaleFromUrl(
  search: string = typeof window === 'undefined' ? '' : window.location.search,
): void {
  const requested = new URLSearchParams(search).get('locale')
  if (isLocale(requested)) {
    setLocale(requested)
  } else {
    applyDocumentLocale()
  }
}

export function setLocale(next: Locale): void {
  activeLocale.value = next
  applyDocumentLocale(next)
}

/** Look up a UI string in the active locale, falling back to English. */
export function t(key: MessageKey): string {
  const table = messages[activeLocale.value] as Record<string, string>
  const english = messages.en as Record<string, string>
  return table[key] ?? english[key] ?? key
}

/** Interpolated variant: t('search.noResultsFor', { query: 'foo' }) */
export function tf(
  key: MessageKey,
  params: Record<string, string | number>,
): string {
  return Object.entries(params).reduce(
    (text, [name, value]) => text.replaceAll(`{${name}}`, String(value)),
    t(key),
  )
}

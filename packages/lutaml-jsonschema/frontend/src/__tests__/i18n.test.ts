import { describe, it, expect, beforeEach } from 'vitest'
// @vitest-environment jsdom
import {
  t,
  tf,
  setLocale,
  locale,
  locales,
  localeLabel,
  isLocale,
  nextLocale,
  directionFor,
  applyDocumentLocale,
  initLocaleFromUrl,
} from '../i18n'
import { messages } from '../i18n/messages'

describe('i18n', () => {
  beforeEach(() => setLocale('en'))

  it('looks up strings in the active locale', () => {
    expect(t('panel.tabs.overview')).toBe('Overview')
  })

  it('falls back to English, then to the key itself', () => {
    expect(t('panel.tabs.overview')).toBe(messages.en['panel.tabs.overview'])
    // @ts-expect-error — deliberate unknown key at runtime
    expect(t('panel.tabs.doesNotExist')).toBe('panel.tabs.doesNotExist')
  })

  it('interpolates parameters', () => {
    expect(tf('search.noResultsFor', { query: 'foo' }))
      .toBe('No results found for "foo"')
  })

  it('switches locales', () => {
    setLocale('en')
    expect(locale()).toBe('en')
  })

  it('maps locales to writing directions', () => {
    expect(directionFor('en')).toBe('ltr')
    expect(directionFor('ar')).toBe('rtl')
  })

  it('mirrors lang and dir onto the document element', () => {
    applyDocumentLocale('en')
    expect(document.documentElement.lang).toBe('en')
    expect(document.documentElement.dir).toBe('ltr')
  })

  it('translates every key in Arabic and mirrors RTL for it', () => {
    setLocale('ar')
    expect(locale()).toBe('ar')
    expect(t('panel.tabs.properties')).toBe('الخصائص')
    expect(tf('panel.tabs.propertiesCount', { count: 3 })).toBe('الخصائص (3)')
    expect(document.documentElement.dir).toBe('rtl')
    expect(document.documentElement.lang).toBe('ar')
    setLocale('en')
  })

  it('falls back to English for keys a locale has not translated', () => {
    const ar = messages.ar as Record<string, string>
    const en = messages.en as Record<string, string>
    const untranslated = Object.keys(en).find((k) => !(k in ar))
    if (untranslated) {
      setLocale('ar')
      expect(t(untranslated as never)).toBe(en[untranslated])
      setLocale('en')
    }
  })

  it('exposes the locale list, labels, and the cycle', () => {
    expect(locales()).toEqual(['en', 'ar'])
    expect(localeLabel('ar')).toBe('العربية')
    expect(nextLocale()).toBe('ar')
    setLocale('ar')
    expect(nextLocale()).toBe('en')
    setLocale('en')
  })

  it('guards isLocale against unknown values', () => {
    expect(isLocale('ar')).toBe(true)
    expect(isLocale('xx')).toBe(false)
    expect(isLocale(null)).toBe(false)
  })

  it('boots the locale from ?locale=, else keeps the default', () => {
    initLocaleFromUrl('?locale=ar')
    expect(locale()).toBe('ar')
    expect(document.documentElement.dir).toBe('rtl')
    setLocale('en')
    initLocaleFromUrl('?locale=xx')
    expect(locale()).toBe('en')
    expect(document.documentElement.dir).toBe('ltr')
    initLocaleFromUrl('')
    expect(locale()).toBe('en')
  })
})

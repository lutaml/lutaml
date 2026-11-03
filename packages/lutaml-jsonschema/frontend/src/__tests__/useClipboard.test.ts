/**
 * @vitest-environment jsdom
 */
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { copyToClipboard } from '../composables/useClipboard'

describe('copyToClipboard', () => {
  let originalClipboard: unknown

  beforeEach(() => {
    originalClipboard = navigator.clipboard
    // jsdom doesn't implement execCommand — add a stub
    document.execCommand = vi.fn().mockReturnValue(false)
  })

  afterEach(() => {
    Object.defineProperty(navigator, 'clipboard', {
      value: originalClipboard,
      writable: true,
      configurable: true,
    })
  })

  it('returns true when clipboard API succeeds', async () => {
    Object.defineProperty(navigator, 'clipboard', {
      value: { writeText: vi.fn().mockResolvedValue(undefined) },
      writable: true,
      configurable: true,
    })
    const result = await copyToClipboard('hello')
    expect(result).toBe(true)
    expect(navigator.clipboard.writeText).toHaveBeenCalledWith('hello')
  })

  it('falls back to execCommand when clipboard API throws', async () => {
    Object.defineProperty(navigator, 'clipboard', {
      value: { writeText: vi.fn().mockRejectedValue(new Error('denied')) },
      writable: true,
      configurable: true,
    })
    ;(document.execCommand as ReturnType<typeof vi.fn>).mockReturnValue(true)
    const result = await copyToClipboard('hello')
    expect(result).toBe(true)
    expect(document.execCommand).toHaveBeenCalledWith('copy')
  })

  it('returns false when both clipboard and execCommand fail', async () => {
    Object.defineProperty(navigator, 'clipboard', {
      value: { writeText: vi.fn().mockRejectedValue(new Error('denied')) },
      writable: true,
      configurable: true,
    })
    ;(document.execCommand as ReturnType<typeof vi.fn>).mockReturnValue(false)
    const result = await copyToClipboard('hello')
    expect(result).toBe(false)
  })

  it('uses execCommand fallback when clipboard is undefined', async () => {
    Object.defineProperty(navigator, 'clipboard', {
      value: undefined,
      writable: true,
      configurable: true,
    })
    ;(document.execCommand as ReturnType<typeof vi.fn>).mockReturnValue(true)
    const result = await copyToClipboard('hello')
    expect(result).toBe(true)
  })
})

import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import puppeteer, { type Browser, type Page } from 'puppeteer'
import path from 'path'
import fs from 'fs'

const NEW_HTML = '/tmp/lutaml_test_new.html'
const SCREENSHOT_DIR = path.join(__dirname, '__screenshots__')

describe('Lutaml SPA rendering', () => {
  let browser: Browser
  let page: Page
  const consoleErrors: string[] = []

  beforeAll(async () => {
    fs.mkdirSync(SCREENSHOT_DIR, { recursive: true })

    browser = await puppeteer.launch({
      headless: true,
      args: ['--no-sandbox', '--disable-setuid-sandbox'],
    })
    page = await browser.newPage()
    await page.setViewport({ width: 1280, height: 800 })

    page.on('pageerror', (err) => {
      consoleErrors.push(`PageError: ${err.message}`)
    })
    page.on('console', (msg) => {
      if (msg.type() === 'error') {
        consoleErrors.push(`ConsoleError: ${msg.text()}`)
      }
    })
  })

  afterAll(async () => {
    await browser.close()
  })

  it('loads without JS errors', async () => {
    await page.goto(`file://${NEW_HTML}`, { waitUntil: 'networkidle0', timeout: 10000 })

    // Wait for Vue to mount
    await page.waitForSelector('#app', { timeout: 5000 })
    await new Promise((r) => setTimeout(r, 500))

    const criticalErrors = consoleErrors.filter(
      (e) =>
        !e.includes('favicon') &&
        !e.includes('fonts.googleapis.com') &&
        !e.includes('Download the React DevTools')
    )
    expect(criticalErrors).toEqual([])
  })

  it('renders the sidebar', async () => {
    const sidebar = await page.$('.sidebar')
    expect(sidebar).not.toBeNull()

    const branding = await page.$('.sidebar-branding')
    expect(branding).not.toBeNull()

    const overviewBtn = await page.$('.overview-btn')
    expect(overviewBtn).not.toBeNull()
  })

  it('renders the header', async () => {
    const header = await page.$('.header')
    expect(header).not.toBeNull()

    const searchTrigger = await page.$('.search-trigger')
    expect(searchTrigger).not.toBeNull()

    const themeBtn = await page.$('.theme-btn')
    expect(themeBtn).not.toBeNull()
  })

  it('renders the package tree', async () => {
    const treeNodes = await page.$$('.tree-node')
    expect(treeNodes.length).toBeGreaterThan(0)
  })

  it('renders the welcome view by default', async () => {
    const welcome = await page.$('.view-welcome')
    expect(welcome).not.toBeNull()

    const stats = await page.$$('.welcome-stat')
    expect(stats.length).toBeGreaterThan(0)
  })

  it('takes a screenshot of the welcome page', async () => {
    await page.screenshot({
      path: path.join(SCREENSHOT_DIR, 'new-welcome.png'),
      fullPage: false,
    })
  })

  it('toggles dark mode', async () => {
    // Check initial theme
    const initialTheme = await page.evaluate(() => {
      return document.querySelector('.app-layout')?.getAttribute('data-theme')
    })
    expect(initialTheme).toBe('light')

    // Click theme toggle
    await page.click('.theme-btn')
    await new Promise((r) => setTimeout(r, 200))

    const darkTheme = await page.evaluate(() => {
      return document.querySelector('.app-layout')?.getAttribute('data-theme')
    })
    expect(darkTheme).toBe('dark')

    await page.screenshot({
      path: path.join(SCREENSHOT_DIR, 'new-dark-mode.png'),
      fullPage: false,
    })

    // Toggle back
    await page.click('.theme-btn')
    await new Promise((r) => setTimeout(r, 200))
  })

  it('collapses and expands sidebar', async () => {
    // Sidebar should be visible initially
    const sidebarClass = await page.evaluate(() => {
      return document.querySelector('.sidebar')?.className
    })
    expect(sidebarClass).not.toContain('collapsed')

    // Click sidebar toggle
    await page.click('.sidebar-toggle')
    await new Promise((r) => setTimeout(r, 300))

    const collapsedClass = await page.evaluate(() => {
      return document.querySelector('.sidebar')?.className
    })
    expect(collapsedClass).toContain('collapsed')

    await page.screenshot({
      path: path.join(SCREENSHOT_DIR, 'new-sidebar-collapsed.png'),
      fullPage: false,
    })

    // Expand again
    await page.click('.sidebar-toggle')
    await new Promise((r) => setTimeout(r, 300))
  })

  it('opens search modal with / key', async () => {
    await page.keyboard.press('/')
    await new Promise((r) => setTimeout(r, 200))

    const modal = await page.$('.search-modal-overlay')
    expect(modal).not.toBeNull()

    await page.screenshot({
      path: path.join(SCREENSHOT_DIR, 'new-search-modal.png'),
      fullPage: false,
    })

    // Close
    await page.keyboard.press('Escape')
    await new Promise((r) => setTimeout(r, 200))
  })

  it('clicks a package in the tree and shows details', async () => {
    // Click the first package label in the tree
    const clicked = await page.evaluate(() => {
      const label = document.querySelector('.tree-label') as HTMLElement
      if (label) {
        label.click()
        return true
      }
      return false
    })
    expect(clicked).toBe(true)

    await new Promise((r) => setTimeout(r, 300))

    // Should show package details or class details
    const detailView = await page.$('.detail-view')
    expect(detailView).not.toBeNull()

    await page.screenshot({
      path: path.join(SCREENSHOT_DIR, 'new-package-details.png'),
      fullPage: false,
    })
  })
})

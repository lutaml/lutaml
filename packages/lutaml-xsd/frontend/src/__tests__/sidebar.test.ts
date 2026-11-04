import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import puppeteer from 'puppeteer'
import { createServer, type Server } from 'http'
import { readFileSync, existsSync, writeFileSync, mkdirSync } from 'fs'
import { resolve } from 'path'

const TEST_DIR = resolve(__dirname, '../../.test-tmp')
const TEST_HTML_PATH = resolve(TEST_DIR, 'test-sidebar.html')

const mockSchemaData = {
  metadata: {
    name: 'test-package',
    title: 'Test Package',
    generated: '2025-01-01T00:00:00Z',
    generator: 'vitest',
    schema_count: 1,
  },
  namespaces: [
    { prefix: 'tns', uri: '', schemas: ['biblio'] },
  ],
  schemas: [
    {
      id: 'biblio',
      name: 'biblio',
      location: 'biblio.xsd',
      target_namespace: '',
      prefix: 'tns',
      namespace: '',
      is_entrypoint: true,
      file_path: 'biblio.xsd',
      elements: [
        { id: 'elem_uri', name: 'uri', type: 'TypedUri', occurs: { min: 1, max: 1 } },
        { id: 'elem_title', name: 'title', type: 'TypedTitleString', occurs: { min: 1, max: 1 } },
      ],
      complex_types: [
        { id: 'ct_TypedUri', name: 'TypedUri', content_model: 'simple_content', elements: [], attributes: [{ name: 'role', type: 'string', use: 'optional' }], choice: {} },
      ],
      simple_types: [],
      groups: [],
      attribute_groups: [],
      attributes: [],
      imports: [],
      includes: [],
    },
  ],
}

function buildTestHtml(): string {
  const appJsPath = resolve(__dirname, '../../dist/app.iife.js')
  const styleCssPath = resolve(__dirname, '../../dist/style.css')
  if (!existsSync(appJsPath) || !existsSync(styleCssPath)) {
    throw new Error('Frontend not built. Run `npm run build` in frontend/ first.')
  }

  const appJsContent = readFileSync(appJsPath, 'utf-8')
  const styleCssContent = readFileSync(styleCssPath, 'utf-8')

  const schemaDataJson = JSON.stringify(mockSchemaData).replace(/<\//g, '<\\/')

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Test Sidebar</title>
  <style>${styleCssContent}</style>
</head>
<body>
  <div id="app"></div>
  <script>
    window.SCHEMA_DATA = ${schemaDataJson};
  </script>
  <script>${appJsContent}</script>
</body>
</html>`
}

let server: Server
let browser: puppeteer.Browser
const PORT = 8765

function startServer(port: number): Promise<Server> {
  return new Promise((resolve, reject) => {
    const srv = createServer((_req, res) => {
      try {
        const content = readFileSync(TEST_HTML_PATH)
        res.writeHead(200, { 'Content-Type': 'text/html' })
        res.end(content)
      } catch {
        res.writeHead(404)
        res.end('Not found')
      }
    })
    srv.listen(port, () => resolve(srv))
    srv.on('error', reject)
  })
}

describe('Sidebar rendering (puppeteer)', () => {
  beforeAll(async () => {
    if (!existsSync(TEST_DIR)) mkdirSync(TEST_DIR, { recursive: true })
    const html = buildTestHtml()
    writeFileSync(TEST_HTML_PATH, html)
    server = await startServer(PORT)
    browser = await puppeteer.launch({
      headless: true,
      args: ['--no-sandbox', '--disable-setuid-sandbox'],
    })
  }, 30000)

  afterAll(async () => {
    if (browser) await browser.close()
    if (server) server.close()
  })

  it('renders the sidebar with namespace "tns"', async () => {
    const page = await browser.newPage()

    const response = await page.goto(`http://localhost:${PORT}/`, { waitUntil: 'networkidle0', timeout: 20000 })
    expect(response?.status()).toBe(200)

    await new Promise(r => setTimeout(r, 2000))

    const hasApp = await page.evaluate(() => !!document.querySelector('#app'))
    expect(hasApp).toBe(true)

    const sidebar = await page.$('.sidebar')
    expect(sidebar).not.toBeNull()
  }, 25000)
})

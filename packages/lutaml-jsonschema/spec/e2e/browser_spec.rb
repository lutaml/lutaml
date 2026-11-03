# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "open3"

# Browser verification and the print/PDF path (TODO.sota/09): the SPA must
# boot in a real engine and print to a usable PDF. Skips when no Chrome
# binary or no built frontend is available (e.g. CI without a browser).
RSpec.describe "Headless-browser render and PDF output", :browser do
  let(:chrome) do
    candidates = [
      ENV.fetch("CHROME_BIN", nil),
      "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
      "/usr/bin/chromium",
      "/usr/bin/chromium-browser",
      "/usr/bin/google-chrome",
    ].compact
    candidates.find { |path| File.executable?(path) }
  end

  let(:frontend_dist) do
    Lutaml::Jsonschema::Spa::VueInlinedStrategy::FRONTEND_DIST
  end

  let(:fixtures) { fixture_path("heroku.json") }

  def generate_site(dir)
    schema_set = Lutaml::Jsonschema::SchemaSet.load_from_files(fixtures)
    meta = Lutaml::Jsonschema::Spa::Metadata.new
    Lutaml::Jsonschema::Spa::Generator.new(schema_set, dir,
                                           metadata: meta).generate
    File.join(dir, "index.html")
  end

  def run_chrome(*flags)
    Open3.capture3(chrome, "--headless=new", "--disable-gpu",
                   "--no-first-run", *flags)
  end

  before do
    skip "no Chrome binary available" unless chrome
    skip "frontend/dist not built; run `rake frontend:build`" unless
      File.exist?(File.join(frontend_dist, "app.iife.js"))
  end

  it "boots the SPA and renders schema content from the embedded data" do
    Dir.mktmpdir do |dir|
      page = generate_site(dir)
      dom, _err, status = run_chrome(
        "--virtual-time-budget=15000", "--dump-dom", "file://#{page}"
      )

      expect(status.success?).to be(true)
      # The app mirrors the locale onto the document element (TODO.sota/09:
      # layout direction follows the locale), and the Vue app mounted —
      # sidebar tree and rendered property names exist, not just the raw
      # embedded JSON.
      expect(dom).to match(/<html[^>]*lang="en"[^>]*dir="ltr"/m)
      expect(dom).to include("schema-node")
      expect(dom).to include("dyno")
      expect(dom).to include("Heroku")
    end
  end

  it "prints the heroku site to a usable PDF" do
    Dir.mktmpdir do |dir|
      page = generate_site(dir)
      pdf = File.join(dir, "heroku.pdf")
      _out, _err, status = run_chrome(
        "--virtual-time-budget=8000", "--print-to-pdf=#{pdf}", "file://#{page}"
      )

      expect(status.success?).to be(true)
      expect(File.exist?(pdf)).to be(true)
      expect(File.size(pdf)).to be > 10_000
      expect(File.binread(pdf, 5)).to start_with("%PDF")
    end
  end

  it "renders mirrored and overflow-free under RTL (?locale=ar)" do
    Dir.mktmpdir do |dir|
      page = generate_site(dir)
      probe = <<~SCRIPT
        <script>
          window.addEventListener('load', () => setTimeout(() => {
            const sidebar = document.querySelector('.sidebar').getBoundingClientRect();
            document.body.setAttribute('data-rtl-probe', JSON.stringify({
              dir: document.documentElement.dir,
              lang: document.documentElement.lang,
              overflow: document.documentElement.scrollWidth > window.innerWidth + 2,
              sidebarOnRight: sidebar.left > window.innerWidth / 2,
              arabic: document.body.textContent.includes('\\u0627\\u0644\\u062E\\u0635\\u0627\\u0626\\u0635'),
            }));
            document.title = 'RTL-DONE';
          }, 3000));
        </script>
      SCRIPT
      File.write(File.join(dir, "rtl.html"),
                 File.read(page).sub("</body>", "#{probe}\n</body>"))
      dom, _err, status = run_chrome(
        "--virtual-time-budget=15000", "--dump-dom",
        "file://#{File.join(dir, 'rtl.html')}?locale=ar"
      )

      expect(status.success?).to be(true)
      raw = dom[/data-rtl-probe="([^"]*)"/, 1]
      expect(raw).not_to be_nil
      result = JSON.parse(raw.gsub("&quot;", '"'))
      # the Arabic locale took over the document, the layout mirrored
      # (the flex-first sidebar sits on the right), nothing overflows
      # horizontally, and UI strings render in Arabic
      expect(result["dir"]).to eq("rtl")
      expect(result["lang"]).to eq("ar")
      expect(result["overflow"]).to be(false)
      expect(result["sidebarOnRight"]).to be(true)
      expect(result["arabic"]).to be(true)
    end
  end
end

# LutaML UML Browser - Modern SPA Architecture

## Executive Summary

This document outlines the architecture for a modern, static Single-Page Application (SPA) that provides an interactive browser for LUR (LutaML UML Repository) files. The system generates a fully self-contained or multi-file static site using only Ruby-ecosystem tools, with no Node.js or external build dependencies.

## 1. Architecture Overview

### 1.1 Design Principles

- **Zero Build Dependencies**: Pure Ruby toolchain, no Node.js required
- **Progressive Enhancement**: Works without JavaScript, enhanced with JS
- **Mobile-First Responsive**: Modern CSS Grid/Flexbox layout
- **Accessibility**: WCAG 2.1 AA compliant, semantic HTML5
- **Performance**: Lazy loading, virtualized lists for large datasets
- **Modularity**: Component-based architecture with clear separation

### 1.2 System Components

```
┌─────────────────────────────────────────────────────────────┐
│                    LutaML CLI Tool                          │
│                  (Entry Point: lutaml xmi build-spa)        │
└────────────┬────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│              Static Site Generator (Ruby)                   │
│  ┌──────────────┐  ┌──────────────┐  ┌─────────────────┐   │
│  │ LUR Parser   │─►│ Data         │─►│ Liquid Template │   │
│  │              │  │ Transformer  │  │ Renderer        │   │
│  └──────────────┘  └──────────────┘  └─────────────────┘   │
└────────────┬────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│                   Output Formats                            │
│  ┌─────────────────────┐      ┌──────────────────────────┐  │
│  │ Single-File SPA     │  OR  │ Multi-File Static Site   │  │
│  │ (index.html)        │      │ (index.html + assets/)   │  │
│  │ - Embedded JSON     │      │ - External data.json     │  │
│  │ - Embedded CSS      │      │ - External styles.css    │  │
│  │ - Embedded JS       │      │ - External app.js        │  │
│  └─────────────────────┘      └──────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## 2. Data Model & JSON Structure

### 2.1 JSON Data Schema

The UML model is transformed into a hierarchical JSON structure optimized for client-side navigation and search.

```json
{
  "metadata": {
    "generated": "2024-11-01T00:00:00Z",
    "source": "plateau_all_packages.lur",
    "version": "1.0",
    "statistics": {
      "packages": 150,
      "classes": 3247,
      "associations": 1523,
      "attributes": 12483
    }
  },
  "packageTree": {
    "id": "root",
    "name": "Model",
    "path": "",
    "children": [
      {
        "id": "pkg_001",
        "name": "i-UR",
        "path": "i-UR",
        "classCount": 45,
        "children": [...],
        "classes": ["cls_001", "cls_002"]
      }
    ]
  },
  "packages": {
    "pkg_001": {
      "id": "pkg_001",
      "name": "i-UR",
      "path": "i-UR",
      "definition": "Package description from EA notes",
      "stereotypes": [],
      "classes": ["cls_001", "cls_002"],
      "subPackages": ["pkg_002"],
      "diagrams": ["diag_001"]
    }
  },
  "classes": {
    "cls_001": {
      "id": "cls_001",
      "name": "Building",
      "qualifiedName": "i-UR::Building",
      "type": "Class",
      "package": "pkg_001",
      "stereotypes": ["ApplicationSchema"],
      "definition": "EA notes content",
      "attributes": ["attr_001", "attr_002"],
      "operations": ["op_001"],
      "associations": ["assoc_001"],
      "generalizations": ["cls_002"],
      "specializations": ["cls_003"]
    }
  },
  "attributes": {
    "attr_001": {
      "id": "attr_001",
      "name": "buildingID",
      "type": "CharacterString",
      "visibility": "public",
      "owner": "cls_001",
      "cardinality": {"min": 1, "max": 1},
      "definition": "Unique identifier for building",
      "stereotypes": []
    }
  },
  "associations": {
    "assoc_001": {
      "id": "assoc_001",
      "name": "contains",
      "type": "Association",
      "source": {
        "class": "cls_001",
        "role": "building",
        "cardinality": {"min": 1, "max": 1},
        "navigable": true,
        "aggregation": "composite"
      },
      "target": {
        "class": "cls_004",
        "role": "rooms",
        "cardinality": {"min": 0, "max": "*"},
        "navigable": true,
        "aggregation": "none"
      }
    }
  },
  "searchIndex": {
    "docs": [
      {
        "id": "cls_001",
        "type": "class",
        "name": "Building",
        "qualifiedName": "i-UR::Building",
        "package": "i-UR",
        "content": "Building i-UR ApplicationSchema buildingID..."
      }
    ],
    "index": {
      "version": "1.0.0",
      "fields": ["name", "qualifiedName", "content"],
      "ref": "id"
    }
  }
}
```

### 2.2 Data Normalization Strategy

- **Normalized Structure**: All entities (packages, classes, attributes, associations) stored in flat maps indexed by ID
- **Reference by ID**: Tree structures and relationships use ID references
- **Denormalization for Search**: Search index contains flattened, optimized data
- **Lazy Loading**: Large models can split data into chunks loaded on-demand

## 3. Template System (Liquid)

### 3.1 Template Architecture

```
templates/
├── layouts/
│   ├── base.liquid          # Base HTML5 structure
│   ├── single_file.liquid   # Single-file SPA layout
│   └── multi_file.liquid    # Multi-file site layout
├── components/
│   ├── header.liquid        # App header with search
│   ├── sidebar.liquid       # Navigation sidebar
│   ├── breadcrumb.liquid    # Breadcrumb navigation
│   ├── package_view.liquid  # Package details component
│   ├── class_view.liquid    # Class details component
│   └── search_results.liquid # Search results component
└── partials/
    ├── data_script.liquid   # Embedded JSON data
    ├── styles.liquid        # Embedded CSS
    └── app_script.liquid    # Embedded JavaScript
```

### 3.2 Liquid Context

```ruby
{
  config: {
    title: "UML Model Browser",
    description: "Browse UML model documentation",
    mode: "single_file" | "multi_file",
    theme: {
      primaryColor: "#2c3e50",
      accentColor: "#3498db"
    }
  },
  data: {
    # Full JSON data structure
  },
  build_info: {
    timestamp: Time.now,
    generator: "LutaML SPA Builder v1.0"
  }
}
```

## 4. UI/UX Architecture

### 4.1 Layout Structure

```
┌─────────────────────────────────────────────────────────────┐
│                      Header                                 │
│  [Logo] [Title]              [Search Box] [Theme Toggle]   │
└─────────────────────────────────────────────────────────────┘
┌──────────────┬──────────────────────────────────────────────┐
│              │                                              │
│   Sidebar    │            Content Area                      │
│   (25%)      │            (75%)                             │
│              │                                              │
│  ┌────────┐  │  ┌────────────────────────────────────────┐ │
│  │Package │  │  │ Breadcrumb: Home > i-UR > Building    │ │
│  │Tree    │  │  └────────────────────────────────────────┘ │
│  │        │  │                                              │
│  │[▼] i-UR│  │  ┌────────────────────────────────────────┐ │
│  │ [▶] Core│ │  │                                        │ │
│  │   Class1│ │  │   Details Panel                        │ │
│  │   Class2│ │  │   (Package/Class/Attribute details)    │ │
│  │[▶] Ext  │  │  │                                        │ │
│  │        │  │  │   - Name, Properties                   │ │
│  │        │  │  │   - EA Notes (formatted)               │ │
│  │        │  │  │   - Attributes Table                   │ │
│  │        │  │  │   - Associations with types            │ │
│  │        │  │  │   - Inheritance hierarchy              │ │
│  │        │  │  │                                        │ │
│  └────────┘  │  └────────────────────────────────────────┘ │
│              │                                              │
└──────────────┴──────────────────────────────────────────────┘
```

### 4.2 Responsive Breakpoints

```css
/* Mobile First Approach */
--breakpoint-sm: 640px;   /* Small devices */
--breakpoint-md: 768px;   /* Tablets */
--breakpoint-lg: 1024px;  /* Desktops */
--breakpoint-xl: 1280px;  /* Large desktops */
```

**Mobile (< 768px)**:
- Sidebar collapses to hamburger menu
- Single column layout
- Touch-optimized controls

**Tablet (768px - 1024px)**:
- Collapsible sidebar (overlay on demand)
- Adjusted typography
- Optimized touch targets

**Desktop (> 1024px)**:
- Permanent sidebar with resizable splitter
- Multi-column layouts where appropriate
- Mouse-optimized interactions

### 4.3 CSS Architecture

```
styles/
├── 00-settings/
│   ├── _variables.css       # CSS custom properties
│   └── _mixins.css          # Reusable patterns (as comments)
├── 01-base/
│   ├── _reset.css           # Modern CSS reset
│   ├── _typography.css      # Font setup
│   └── _utilities.css       # Utility classes
├── 02-layout/
│   ├── _grid.css            # Grid system
│   ├── _container.css       # Container layouts
│   └── _sidebar.css         # Sidebar layout
├── 03-components/
│   ├── _header.css          # Header component
│   ├── _navigation.css      # Tree navigation
│   ├── _breadcrumb.css      # Breadcrumb
│   ├── _card.css            # Card components
│   ├── _table.css           # Table styles
│   ├── _button.css          # Button styles
│   └── _modal.css           # Modal/overlay
├── 04-views/
│   ├── _package-view.css    # Package details
│   ├── _class-view.css      # Class details
│   └── _search-view.css     # Search results
└── 05-themes/
    ├── _light.css           # Light theme
    └── _dark.css            # Dark theme
```

**Modern CSS Features Used**:
- CSS Grid for main layout
- CSS Flexbox for components
- CSS Custom Properties for theming
- CSS Container Queries (where supported)
- CSS Logical Properties
- CSS Nesting (PostCSS fallback)

## 5. JavaScript Architecture

### 5.1 Module Structure

```javascript
// Core modules (vanilla ES6+)
app/
├── core/
│   ├── app.js               // Main application controller
│   ├── router.js            // Hash-based routing
│   ├── state.js             // Application state management
│   └── events.js            // Event bus
├── data/
│   ├── loader.js            // Data loading (embedded/external)
│   ├── cache.js             // Client-side caching
│   └── transformer.js       // Data transformation
├── search/
│   ├── index.js             // Search index builder
│   ├── query.js             // Query engine
│   └── highlighter.js       // Results highlighting
├── ui/
│   ├── sidebar.js           // Sidebar controller
│   ├── details.js           // Details pane
│   ├── breadcrumb.js        // Breadcrumb navigation
│   └── theme.js             // Theme switcher
└── utils/
    ├── dom.js               // DOM utilities
    ├── formatters.js        // Data formatters
    └── debounce.js          // Performance utilities
```

### 5.2 State Management

```javascript
const AppState = {
  current: {
    view: 'welcome',      // 'welcome' | 'package' | 'class' | 'search'
    selected: null,       // Current selected entity ID
    path: [],             // Breadcrumb path
    expandedNodes: [],    // Expanded tree nodes
    searchQuery: '',      // Current search
    theme: 'light'        // Theme preference
  },
  data: {
    packages: {},
    classes: {},
    attributes: {},
    associations: {},
    searchIndex: null
  },
  ui: {
    sidebarVisible: true,
    loading: false
  }
};
```

### 5.3 Routing Strategy

Hash-based routing for SPA navigation without server:

```
#/                          → Welcome screen
#/package/i-UR              → Package view
#/class/i-UR::Building      → Class view
#/search?q=building         → Search results
#/attribute/attr_001        → Attribute detail (in class context)
```

## 6. Search Implementation

### 6.1 Search Index Structure

Uses a lightweight, lunr.js-inspired approach:

```javascript
{
  index: {
    // Inverted index: term → document IDs
    building: [doc1, doc5, doc22],
    application: [doc3, doc7],
    schema: [doc3, doc4, doc9]
  },
  documents: [
    {
      id: 'cls_001',
      type: 'class',
      name: 'Building',
      qualifiedName: 'i-UR::Building',
      content: 'building class urban...',
      boost: 1.5  // Classes boosted over attributes
    }
  ],
  config: {
    fields: ['name', 'qualifiedName', 'content'],
    boost: { name: 3, qualifiedName: 2, content: 1 },
    stemming: true,
    stopWords: ['the', 'a', 'an', 'and', 'or']
  }
}
```

### 6.2 Search Features

- **Fuzzy Matching**: Levenshtein distance for typo tolerance
- **Field Boosting**: Names weighted higher than content
- **Type Filtering**: Filter by class, attribute, association
- **Package Scoping**: Limit search to package subtree
- **Highlighting**: Matched terms highlighted in results
- **Keyboard Navigation**: Arrow keys, Enter to select
- **Search-as-you-type**: Debounced, incremental results

### 6.3 just-the-docs Style Search

Implements similar UX to just-the-docs Jekyll theme:

- Overlay search modal (accessible via `/` or Ctrl+K)
- Real-time results with keyboard navigation
- Hierarchical result display (package > class > attribute)
- Score-based ranking with visual relevance indicator
- Preview snippets with context

## 7. Build Pipeline (Ruby Only)

### 7.1 Generator Architecture

```ruby
module Lutaml
  module Xmi
    module StaticSite
      class Generator
        # Main builder
        def initialize(lur_path, options = {})
          @repository = load_repository(lur_path)
          @options = default_options.merge(options)
          @liquid = setup_liquid_environment
        end

        def generate
          data = transform_repository_to_json

          case @options[:mode]
          when :single_file
            generate_single_file(data)
          when :multi_file
            generate_multi_file_site(data)
          end
        end

        private

        def transform_repository_to_json
          DataTransformer.new(@repository).to_json_structure
        end

        def generate_single_file(data)
          template = @liquid.parse(File.read('templates/layouts/single_file.liquid'))
          html = template.render({
            'config' => @options,
            'data' => data,
            'build_info' => build_metadata
          })

          write_file(@options[:output_path], html)
        end

        def generate_multi_file_site(data)
          # Generate index.html
          # Generate data.json
          # Generate styles.css
          # Generate app.js
          # Copy assets
        end
      end
    end
  end
end
```

### 7.2 Data Transformation Pipeline

```ruby
class DataTransformer
  def initialize(repository)
    @repository = repository
    @id_generator = IDGenerator.new
  end

  def to_json_structure
    {
      metadata: build_metadata,
      packageTree: build_package_tree,
      packages: build_packages_map,
      classes: build_classes_map,
      attributes: build_attributes_map,
      associations: build_associations_map,
      searchIndex: build_search_index
    }
  end

  private

  def build_package_tree
    # Recursive tree builder
    PackageTreeBuilder.new(@repository).build
  end

  def build_search_index
    SearchIndexBuilder.new(@repository).build
  end
end
```

### 7.3 CLI Integration

```bash
# Single-file output (default)
lutaml xmi build-spa plateau.lur -o browser.html

# Multi-file output
lutaml xmi build-spa plateau.lur -o dist/ --multi-file

# With custom template
lutaml xmi build-spa plateau.lur -o dist/ --template custom-theme/

# With options
lutaml xmi build-spa plateau.lur \
  --title "PLATEAU UML Browser" \
  --theme dark \
  --enable-collapse-all \
  --max-tree-depth 3
```

## 8. Feature Specification

### 8.1 Sidebar Navigation

**Package Tree**:
- Hierarchical tree view with expand/collapse icons (▶/▼)
- Lazy loading for deep hierarchies (virtualized)
- Class count badges
- Keyboard navigation (arrows, Enter, Space)
- Filter/search within tree
- "Collapse All" / "Expand All" buttons
- Persist expand/collapse state in localStorage
- Highlight current location

**Class List** (within package):
- Grouped by type (Class, DataType, Enum, etc.)
- Sortable (name, type)
- Icons for stereotypes
- Attribute count indicator

### 8.2 Details Pane

**Package Details**:
- Package name and qualified path
- EA notes/description (formatted markdown)
- Sub-packages list with links
- Classes table (name, type, stereotypes, attribute count)
- Diagrams list (if available)
- Statistics (class count, attribute count)

**Class Details**:
- Class name, type, qualifiedName
- Breadcrumb navigation
- Package link
- Stereotypes badges
- EA notes/description (formatted markdown)
- **Attributes Table**:
  - Name, Type, Visibility, Cardinality
  - Sortable columns
  - Type as clickable link (if class)
  - Definition tooltips
- **Operations Table**:
  - Name, Return Type, Visibility, Parameters
- **Associations Table**:
  - Name, Target (linked), Cardinality, Navigability, Aggregation type
  - Visual indicators (◆ composite, ◇ aggregation, → navigable)
- **Inheritance**:
  - Parent class (with link)
  - Child classes list (with links)
  - Inheritance hierarchy diagram (if feasible)

**Attribute Details** (modal or inline):
- Name, Type, Owner class
- Full definition
- Cardinality, Visibility
- Constraints (if any)

### 8.3 Search

**Search Input**:
- Prominent search box in header
- Placeholder: "Search classes, attributes, associations..."
- Keyboard shortcut: `/` or `Ctrl+K` to focus
- Clear button (×)

**Search Results**:
- Real-time, debounced search (300ms)
- Grouped by type (Classes, Attributes, Associations)
- Result item shows:
  - Icon/badge for type
  - Name (highlighted matched terms)
  - Qualified name / package path
  - Relevance score (visual indicator)
  - Brief context snippet
- Click to navigate
- Keyboard navigation (↑↓ to select, Enter to open, Esc to close)
- "No results" message with suggestions

### 8.4 Progressive Enhancement

**Without JavaScript**:
- All content rendered in HTML
- Package/class navigation via anchor links
- Accordion-style navigation
- Server-side search (if multi-file with server)

**With JavaScript**:
- SPA navigation (no page reloads)
- Client-side search
- Dynamic tree expansion
- Smooth transitions
- Keyboard shortcuts

## 9. Technology Stack

### 9.1 Ruby Dependencies

```ruby
# Gemfile additions
gem 'liquid', '~> 5.0'      # Template engine
gem 'json', '~> 2.0'        # JSON generation
gem 'redcarpet', '~> 3.0'   # Markdown for EA notes (optional)
gem 'rouge', '~> 4.0'       # Syntax highlighting (optional)
```

### 9.2 Client-Side Libraries (CDN)

```html
<!-- Optional: Alpine.js for reactive components (5KB gzipped) -->
<script defer src="https://cdn.jsdelivr.net/npm/alpinejs@3/dist/cdn.min.js"></script>

<!-- Or: Pure vanilla JS (included, no CDN needed) -->

<!-- Icons: Feather Icons (optional, ~14KB) -->
<script src="https://unpkg.com/feather-icons"></script>
```

**No Build Required**: All modern browser features used are widely supported (ES6+, CSS Grid, Flexbox). Optional polyfills for IE11 if needed.

### 9.3 Browser Support

- Chrome/Edge: Last 2 versions
- Firefox: Last 2 versions
- Safari: Last 2 versions
- Mobile Safari: iOS 12+
- Chrome Mobile: Last 2 versions

## 10. Performance Optimization

### 10.1 Loading Performance

- **Code Splitting**: Lazy load data chunks for large models
- **Compression**: Gzip/Brotli for static assets
- **Minification**: CSS/JS minification (using Ruby tools)
- **Caching**: Aggressive browser caching headers
- **Critical CSS**: Inline critical CSS for first paint

### 10.2 Runtime Performance

- **Virtual Scrolling**: For large trees/tables (>1000 items)
- **Debouncing**: Search input, resize handlers
- **RAF**: Animations via requestAnimationFrame
- **Event Delegation**: Single event listener for trees
- **Lazy Rendering**: Render details only when visible

### 10.3 Data Size Management

For very large models (>10MB JSON):

- **Chunked Loading**: Split data by package into separate JSON files
- **On-Demand Loading**: Load package details when expanded
- **Search Index Optimization**: Separate search index file
- **Progressive Enhancement**: Basic HTML fallback, enhanced with JS

## 11. Accessibility

### 11.1 WCAG 2.1 AA Compliance

- **Keyboard Navigation**: All interactive elements keyboard accessible
- **ARIA Labels**: Proper roles, labels, live regions
- **Focus Management**: Visible focus indicators, logical tab order
- **Color Contrast**: 4.5:1 minimum for text
- **Screen Reader Support**: Descriptive text, landmarks
- **Skip Links**: Skip to main content, navigation

### 11.2 Semantic HTML

```html
<header role="banner">
<nav role="navigation" aria-label="Package navigation">
<main role="main" aria-label="Content">
<search role="search" aria-label="Search UML model">
<aside role="complementary" aria-label="Related information">
```

## 12. Extensibility & Customization

### 12.1 Theme System

CSS custom properties for easy theming:

```css
:root {
  --color-primary: #2c3e50;
  --color-accent: #3498db;
  --color-success: #27ae60;
  --color-warning: #f39c12;
  --color-error: #e74c3c;

  --font-family-base: -apple-system, BlinkMacSystemFont, "Segoe UI", ...;
  --font-family-mono: "SF Mono", Monaco, "Cascadia Code", ...;

  --space-unit: 0.5rem;
  --border-radius: 4px;
  --shadow-sm: 0 1px 2px rgba(0,0,0,0.1);
}
```

### 12.2 Plugin Architecture

```ruby
# Custom transformers
Lutaml::Xmi::StaticSite.register_transformer(:custom_notes) do |content|
  # Transform EA notes with custom formatting
end

# Custom Liquid filters
Lutaml::Xmi::StaticSite.register_filter(:custom_format) do |input|
  # Custom formatting logic
end

# Custom templates
Lutaml::Xmi::StaticSite.template_path = "path/to/custom/templates"
```

### 12.3 Configuration File

```yaml
# .lutaml-spa.yml
title: "My UML Model Browser"
description: "Interactive browser for UML models"
theme:
  primary_color: "#2c3e50"
  accent_color: "#3498db"
  font_family: "Inter, system-ui, sans-serif"

features:
  search: true
  dark_mode: true
  breadcrumbs: true
  collapse_all: true

output:
  mode: multi_file  # single_file | multi_file
  path: dist/
  minify: true
  compression: gzip

navigation:
  max_tree_depth: 3
  auto_expand_first: true
  show_class_count: true

details:
  show_stereotypes: true
  show_operations: true
  format_markdown: true
  syntax_highlighting: true
```

## 13. Implementation Roadmap

### Phase 1: Foundation (Week 1-2)
- [ ] Set up Liquid template environment
- [ ] Implement data transformer (Repository → JSON)
- [ ] Create base templates (layouts, components)
- [ ] Build basic CSS architecture
- [ ] Implement single-file generator

### Phase 2: Core Features (Week 3-4)
- [ ] Sidebar navigation (tree view)
- [ ] Details pane (package/class views)
- [ ] Routing system
- [ ] State management
- [ ] Breadcrumb navigation

### Phase 3: Search (Week 5)
- [ ] Search index builder
- [ ] Client-side search engine
- [ ] Search UI component
- [ ] Keyboard shortcuts
- [ ] Results highlighting

### Phase 4: Polish (Week 6)
- [ ] Responsive design
- [ ] Dark theme
- [ ] Performance optimization
- [ ] Accessibility audit
- [ ] Documentation

### Phase 5: Advanced Features (Week 7-8)
- [ ] Multi-file output mode
- [ ] Chunked data loading
- [ ] Virtual scrolling
- [ ] Export/print functionality
- [ ] Diagram rendering (optional)

## 14. Testing Strategy

- **Unit Tests**: Ruby data transformers, search indexer
- **Integration Tests**: Template rendering, full generation
- **E2E Tests**: Browser automation (Capybara/Selenium)
- **Visual Regression**: Percy or similar
- **Performance Tests**: Lighthouse CI
- **Accessibility Tests**: axe-core

## 15. Documentation

- **User Guide**: How to use the generated browser
- **Developer Guide**: How to customize/extend
- **API Reference**: Ruby classes and methods
- **Template Reference**: Available Liquid tags/filters
- **Examples**: Sample configurations

---

## Appendix A: File Structure

```
lib/lutaml/xmi/static_site/
├── generator.rb              # Main generator
├── data_transformer.rb       # Repository → JSON
├── search_index_builder.rb   # Search index
├── template_renderer.rb      # Liquid rendering
├── asset_bundler.rb          # CSS/JS bundling
└── cli.rb                    # CLI integration

templates/
├── layouts/
│   ├── base.liquid
│   ├── single_file.liquid
│   └── multi_file.liquid
├── components/
│   ├── header.liquid
│   ├── sidebar.liquid
│   ├── package_details.liquid
│   ├── class_details.liquid
│   └── search.liquid
└── assets/
    ├── styles/
    │   └── (CSS modules as above)
    └── scripts/
        └── (JS modules as above)

spec/lutaml/xmi/static_site/
├── generator_spec.rb
├── data_transformer_spec.rb
├── search_index_builder_spec.rb
└── integration/
    └── full_generation_spec.rb
```

## Appendix B: Example Output

**Single-File Mode** (~500KB for medium model):
```
browser.html              # Self-contained SPA
```

**Multi-File Mode**:
```
dist/
├── index.html           # Main HTML (5KB)
├── data/
│   ├── model.json       # Full data (400KB)
│   └── search.json      # Search index (100KB)
├── assets/
│   ├── styles.css       # Compiled CSS (15KB)
│   ├── app.js           # Application JS (30KB)
│   └── icons/           # Icon assets
└── README.md            # Usage instructions
```

---

**Version**: 1.0 Draft
**Last Updated**: 2024-11-01
**Author**: LutaML Team
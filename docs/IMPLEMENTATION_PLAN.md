# LutaML UML Browser SPA - Implementation Plan

## Executive Summary

**Target**: Modern, rich SPA for browsing LUR files with Alpine.js, lunr.js-style search, both single-file and multi-file output modes.

**Strategy**: Build fresh SPA architecture, then refactor existing Sinatra web UI to serve the SPA with JSON API endpoints.

**Timeline**: 8 weeks for full implementation
**Tech Stack**: Ruby + Liquid + Alpine.js + Custom Search Engine

---

## 1. Implementation Priorities

### Phase 1: Foundation & Data Layer (Weeks 1-2)
**Goal**: Robust data transformation and JSON generation

#### 1.1 Data Transformer
**File**: `lib/lutaml/xmi/static_site/data_transformer.rb`

```ruby
module Lutaml
  module Xmi
    module StaticSite
      class DataTransformer
        # Transform UmlRepository → Normalized JSON structure

        def initialize(repository, options = {})
          @repository = repository
          @options = default_options.merge(options)
          @id_generator = IDGenerator.new
        end

        def transform
          {
            metadata: build_metadata,
            config: build_config,
            packageTree: build_package_tree,
            packages: build_packages_map,
            classes: build_classes_map,
            attributes: build_attributes_map,
            associations: build_associations_map,
            operations: build_operations_map,
            diagrams: build_diagrams_map
          }
        end

        private

        # Build normalized maps with stable IDs
        def build_packages_map
          packages = {}
          @repository.packages_index.each do |package|
            id = @id_generator.package_id(package)
            packages[id] = serialize_package(package, id)
          end
          packages
        end

        def serialize_package(package, id)
          {
            id: id,
            xmi_id: package.xmi_id,
            name: package.name,
            path: package_path(package),
            definition: format_definition(package.definition),
            stereotypes: package.stereotypes || [],
            classes: package.classes.map { |c| @id_generator.class_id(c) },
            subPackages: package.packages.map { |p| @id_generator.package_id(p) },
            diagrams: package_diagrams(package).map { |d| @id_generator.diagram_id(d) },
            parent: package.parent ? @id_generator.package_id(package.parent) : nil
          }
        end

        # Similar for classes, attributes, associations...
      end
    end
  end
end
```

#### 1.2 Search Index Builder
**File**: `lib/lutaml/xmi/static_site/search_index_builder.rb`

**Lunr.js-compatible index structure**:

```ruby
class SearchIndexBuilder
  def initialize(repository, options = {})
    @repository = repository
    @options = options
    @stemmer = Porter2Stemmer.new  # Ruby port of Porter2
  end

  def build
    {
      version: "1.0.0",
      fields: field_definitions,
      ref: "id",
      documentStore: build_document_store,
      invertedIndex: build_inverted_index,
      fieldVectors: build_field_vectors,
      pipeline: ["stemmer", "stopWordFilter"]
    }
  end

  private

  def field_definitions
    [
      { name: "name", boost: 10, searchable: true },
      { name: "qualifiedName", boost: 5, searchable: true },
      { name: "type", boost: 3, searchable: true },
      { name: "package", boost: 2, searchable: true },
      { name: "content", boost: 1, searchable: true }
    ]
  end

  def build_document_store
    documents = {}

    # Index classes
    @repository.classes_index.each do |klass|
      id = generate_doc_id("class", klass.xmi_id)
      documents[id] = {
        id: id,
        type: "class",
        entityId: klass.xmi_id,
        name: klass.name,
        qualifiedName: qualified_name(klass),
        package: package_path(klass),
        content: build_content_for_class(klass),
        boost: 1.5  # Classes are more important
      }
    end

    # Index attributes
    @repository.attributes_index.each do |attr, owner|
      id = generate_doc_id("attribute", attr.xmi_id)
      documents[id] = {
        id: id,
        type: "attribute",
        entityId: attr.xmi_id,
        name: attr.name,
        qualifiedName: "#{qualified_name(owner)}::#{attr.name}",
        package: package_path(owner),
        ownerName: owner.name,
        ownerQualifiedName: qualified_name(owner),
        content: build_content_for_attribute(attr, owner),
        boost: 1.0
      }
    end

    # Index associations
    @repository.associations_index.each do |assoc|
      id = generate_doc_id("association", assoc.xmi_id)
      documents[id] = {
        id: id,
        type: "association",
        entityId: assoc.xmi_id,
        name: assoc.name || "unnamed",
        content: build_content_for_association(assoc),
        boost: 0.8
      }
    end

    documents
  end

  def build_inverted_index
    inverted = {}

    build_document_store.each do |doc_id, doc|
      # Tokenize and stem each field
      field_definitions.each do |field_def|
        next unless field_def[:searchable]

        field_name = field_def[:name]
        text = doc[field_name.to_sym] || ""
        tokens = tokenize_and_stem(text)

        tokens.each do |token|
          inverted[token] ||= {}
          inverted[token][field_name] ||= {}
          inverted[token][field_name][doc_id] ||= 0
          inverted[token][field_name][doc_id] += 1
        end
      end
    end

    inverted
  end

  def build_field_vectors
    # TF-IDF vectors for each document and field
    vectors = {}

    build_document_store.each do |doc_id, doc|
      vectors[doc_id] = {}

      field_definitions.each do |field_def|
        field_name = field_def[:name]
        text = doc[field_name.to_sym] || ""
        tokens = tokenize_and_stem(text)

        # Calculate term frequencies
        tf = {}
        tokens.each do |token|
          tf[token] ||= 0
          tf[token] += 1
        end

        # Normalize by document length
        max_freq = tf.values.max || 1
        normalized_tf = tf.transform_values { |freq| freq.to_f / max_freq }

        vectors[doc_id][field_name] = normalized_tf
      end
    end

    vectors
  end

  def tokenize_and_stem(text)
    # 1. Lowercase
    # 2. Split on non-word characters
    # 3. Remove stop words
    # 4. Stem

    tokens = text.downcase
                 .scan(/\w+/)
                 .reject { |t| STOP_WORDS.include?(t) }
                 .map { |t| @stemmer.stem(t) }

    tokens
  end

  def build_content_for_class(klass)
    parts = [
      klass.name,
      qualified_name(klass),
      klass.stereotypes&.join(" "),
      klass.definition,
      klass.attributes&.map(&:name)&.join(" "),
      klass.operations&.map(&:name)&.join(" ")
    ].compact

    parts.join(" ")
  end

  STOP_WORDS = %w[
    the a an and or but in on at to for of with from by
    is are was were be been being have has had
    this that these those
  ].freeze
end
```

#### 1.3 ID Generation Strategy

```ruby
class IDGenerator
  def initialize
    @counters = Hash.new(0)
    @cache = {}
  end

  def package_id(package)
    cache_key = [:package, package.xmi_id]
    @cache[cache_key] ||= generate_id("pkg", package.xmi_id)
  end

  def class_id(klass)
    cache_key = [:class, klass.xmi_id]
    @cache[cache_key] ||= generate_id("cls", klass.xmi_id)
  end

  # Similar for attributes, associations, etc.

  private

  def generate_id(prefix, xmi_id)
    # Use hash of XMI ID for stable, short IDs
    hash = Digest::MD5.hexdigest(xmi_id.to_s)[0..7]
    "#{prefix}_#{hash}"
  end
end
```

---

### Phase 2: Template System (Week 3)
**Goal**: Liquid templates with Alpine.js components

#### 2.1 Base Layout Structure

**File**: `templates/layouts/base.liquid`

```liquid
<!DOCTYPE html>
<html lang="en" x-data="app" :class="{ 'dark': darkMode }">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{{ config.title | default: "UML Model Browser" }}</title>
  <meta name="description" content="{{ config.description }}">

  <!-- Styles -->
  {% if config.mode == "single_file" %}
    <style>{% include "styles_inline" %}</style>
  {% else %}
    <link rel="stylesheet" href="assets/styles.css">
  {% endif %}

  <!-- Alpine.js -->
  <script defer src="https://cdn.jsdelivr.net/npm/alpinejs@3.x.x/dist/cdn.min.js"></script>
</head>
<body>
  <div class="app-container">
    {% include "components/header" %}

    <div class="main-layout">
      {% include "components/sidebar" %}
      {% include "components/content" %}
    </div>
  </div>

  <!-- Data -->
  {% if config.mode == "single_file" %}
    <script>
      window.UML_DATA = {{ data | json }};
      window.SEARCH_INDEX = {{ search_index | json }};
    </script>
  {% else %}
    <script>
      window.UML_DATA_URL = "data/model.json";
      window.SEARCH_INDEX_URL = "data/search.json";
    </script>
  {% endif %}

  <!-- Application -->
  {% if config.mode == "single_file" %}
    <script>{% include "app_inline" %}</script>
  {% else %}
    <script src="assets/app.js"></script>
  {% endif %}
</body>
</html>
```

#### 2.2 Alpine.js Component: Sidebar

**File**: `templates/components/sidebar.liquid`

```liquid
<aside
  class="sidebar"
  x-show="sidebarVisible"
  x-transition
  :aria-hidden="!sidebarVisible"
>
  <div class="sidebar-header">
    <h2>Packages</h2>
    <div class="sidebar-actions">
      <button @click="expandAll()" title="Expand All">
        <svg><!-- expand icon --></svg>
      </button>
      <button @click="collapseAll()" title="Collapse All">
        <svg><!-- collapse icon --></svg>
      </button>
    </div>
  </div>

  <div class="sidebar-content">
    <!-- Package Tree Component -->
    <div x-data="packageTree">
      <template x-for="node in rootNodes" :key="node.id">
        <div x-data="treeNode(node)">
          {% include "components/tree_node" %}
        </div>
      </template>
    </div>
  </div>
</aside>
```

#### 2.3 Alpine.js Component: Tree Node (Recursive)

**File**: `templates/components/tree_node.liquid`

```liquid
<div class="tree-node" :class="{ 'selected': isSelected }">
  <div class="node-header" @click="toggle()">
    <!-- Expand/Collapse Icon -->
    <span
      class="expand-icon"
      x-show="hasChildren"
      :class="{ 'expanded': expanded }"
    >
      <svg><!-- chevron icon --></svg>
    </span>
    <span class="no-icon" x-show="!hasChildren"></span>

    <!-- Package Icon -->
    <svg class="package-icon"><!-- package icon --></svg>

    <!-- Package Name -->
    <span
      class="node-label"
      @click.stop="selectPackage(node.id)"
      :class="{ 'active': isSelected }"
    >
      <span x-text="node.name"></span>
    </span>

    <!-- Class Count Badge -->
    <span
      class="count-badge"
      x-show="node.classCount > 0"
      x-text="node.classCount"
    ></span>
  </div>

  <!-- Children (recursive) -->
  <div
    class="node-children"
    x-show="expanded"
    x-transition:enter="transition ease-out duration-200"
    x-transition:enter-start="opacity-0 transform scale-95"
    x-transition:enter-end="opacity-100 transform scale-100"
  >
    <template x-for="child in node.children" :key="child.id">
      <div x-data="treeNode(child)">
        {% include "components/tree_node" %}
      </div>
    </template>

    <!-- Classes in Package -->
    <template x-for="classId in node.classes" :key="classId">
      <div
        class="class-node"
        @click="selectClass(classId)"
        :class="{ 'selected': currentClass === classId }"
      >
        <span class="class-icon">
          <svg><!-- class icon --></svg>
        </span>
        <span x-text="getClass(classId).name"></span>
        <span
          class="class-type-badge"
          x-text="getClass(classId).type"
        ></span>
      </div>
    </template>
  </div>
</div>
```

#### 2.4 Alpine.js Component: Content Area

**File**: `templates/components/content.liquid`

```liquid
<main class="content-area">
  <!-- Breadcrumb -->
  <nav class="breadcrumb" aria-label="Breadcrumb">
    <template x-for="(crumb, index) in breadcrumbs" :key="index">
      <span>
        <a
          href="#"
          @click.prevent="navigateToCrumb(crumb)"
          x-text="crumb.name"
        ></a>
        <span x-show="index < breadcrumbs.length - 1" class="separator">/</span>
      </span>
    </template>
  </nav>

  <!-- Content Pane -->
  <div class="content-pane">
    <!-- Welcome Screen -->
    <div x-show="currentView === 'welcome'" x-transition>
      {% include "views/welcome" %}
    </div>

    <!-- Package Details -->
    <div x-show="currentView === 'package'" x-transition>
      {% include "views/package_details" %}
    </div>

    <!-- Class Details -->
    <div x-show="currentView === 'class'" x-transition>
      {% include "views/class_details" %}
    </div>

    <!-- Search Results -->
    <div x-show="currentView === 'search'" x-transition>
      {% include "views/search_results" %}
    </div>
  </div>
</main>
```

---

### Phase 3: Client-Side Search Engine (Week 4)
**Goal**: Lunr.js-style search with fuzzy matching and ranking

#### 3.1 Search Engine Architecture

**File**: `assets/scripts/search/engine.js`

```javascript
class SearchEngine {
  constructor(index, documents) {
    this.index = index;           // Inverted index from Ruby
    this.documents = documents;   // Document store
    this.fieldVectors = index.fieldVectors;
    this.idfCache = this.calculateIDF();
  }

  search(query, options = {}) {
    const {
      fuzzy = true,
      boost = {},
      filters = {},
      limit = 50
    } = options;

    // 1. Tokenize and stem query
    const tokens = this.tokenize(query);

    // 2. Find matching documents
    let results = [];

    if (fuzzy) {
      results = this.fuzzySearch(tokens);
    } else {
      results = this.exactSearch(tokens);
    }

    // 3. Calculate scores using TF-IDF
    results = results.map(result => ({
      ...result,
      score: this.calculateScore(result, tokens, boost)
    }));

    // 4. Apply filters
    if (filters.type) {
      results = results.filter(r => r.type === filters.type);
    }
    if (filters.package) {
      results = results.filter(r =>
        r.package && r.package.startsWith(filters.package)
      );
    }

    // 5. Sort by score (descending)
    results.sort((a, b) => b.score - a.score);

    // 6. Limit results
    return results.slice(0, limit);
  }

  fuzzySearch(tokens) {
    const results = new Map();

    tokens.forEach(token => {
      // Exact match
      if (this.index.invertedIndex[token]) {
        this.addResults(results, token, this.index.invertedIndex[token], 1.0);
      }

      // Fuzzy matches (edit distance ≤ 2)
      Object.keys(this.index.invertedIndex).forEach(indexToken => {
        const distance = this.levenshtein(token, indexToken);
        if (distance > 0 && distance <= 2) {
          const penalty = 1 / (1 + distance);
          this.addResults(
            results,
            indexToken,
            this.index.invertedIndex[indexToken],
            penalty
          );
        }
      });
    });

    return Array.from(results.values());
  }

  exactSearch(tokens) {
    const results = new Map();

    tokens.forEach(token => {
      if (this.index.invertedIndex[token]) {
        this.addResults(results, token, this.index.invertedIndex[token], 1.0);
      }
    });

    return Array.from(results.values());
  }

  addResults(resultsMap, token, fieldMatches, fuzzyBoost) {
    Object.entries(fieldMatches).forEach(([field, docMatches]) => {
      Object.entries(docMatches).forEach(([docId, termFreq]) => {
        if (!resultsMap.has(docId)) {
          resultsMap.set(docId, {
            ...this.documents[docId],
            matches: {},
            fuzzyBoost: 1.0
          });
        }

        const result = resultsMap.get(docId);
        result.matches[field] = result.matches[field] || {};
        result.matches[field][token] = (result.matches[field][token] || 0) + termFreq;
        result.fuzzyBoost = Math.min(result.fuzzyBoost, fuzzyBoost);
      });
    });
  }

  calculateScore(result, queryTokens, boost = {}) {
    let score = 0;

    // TF-IDF scoring for each field
    Object.entries(result.matches).forEach(([field, termFreqs]) => {
      const fieldBoost = boost[field] || this.index.fields.find(f => f.name === field)?.boost || 1;

      Object.entries(termFreqs).forEach(([term, tf]) => {
        const idf = this.idfCache[term] || 0;
        score += tf * idf * fieldBoost;
      });
    });

    // Apply fuzzy matching penalty
    score *= result.fuzzyBoost;

    // Apply document-level boost (e.g., classes > attributes)
    score *= result.boost || 1.0;

    return score;
  }

  calculateIDF() {
    const documentCount = Object.keys(this.documents).length;
    const idf = {};

    Object.keys(this.index.invertedIndex).forEach(term => {
      const field Match = this.index.invertedIndex[term];
      const docsWithTerm = new Set();

      Object.values(fieldMatch).forEach(docMatches => {
        Object.keys(docMatches).forEach(docId => docsWithTerm.add(docId));
      });

      idf[term] = Math.log(documentCount / docsWithTerm.size);
    });

    return idf;
  }

  tokenize(text) {
    return text
      .toLowerCase()
      .replace(/[^\w\s]/g, ' ')
      .split(/\s+/)
      .filter(t => t.length > 0)
      .filter(t => !STOP_WORDS.includes(t))
      .map(t => this.stem(t));
  }

  stem(word) {
    // Porter stemmer implementation
    // (Can use a lightweight JS port)
    return PorterStemmer.stem(word);
  }

  levenshtein(a, b) {
    // Levenshtein distance for fuzzy matching
    const matrix = [];

    for (let i = 0; i <= b.length; i++) {
      matrix[i] = [i];
    }

    for (let j = 0; j <= a.length; j++) {
      matrix[0][j] = j;
    }

    for (let i = 1; i <= b.length; i++) {
      for (let j = 1; j <= a.length; j++) {
        if (b.charAt(i - 1) === a.charAt(j - 1)) {
          matrix[i][j] = matrix[i - 1][j - 1];
        } else {
          matrix[i][j] = Math.min(
            matrix[i - 1][j - 1] + 1, // substitution
            matrix[i][j - 1] + 1,     // insertion
            matrix[i - 1][j] + 1      // deletion
          );
        }
      }
    }

    return matrix[b.length][a.length];
  }
}

const STOP_WORDS = [
  'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for',
  'of', 'with', 'from', 'by', 'is', 'are', 'was', 'were', 'be', 'been',
  'being', 'have', 'has', 'had', 'this', 'that', 'these', 'those'
];
```

#### 3.2 Search UI Component

**File**: `templates/components/search.liquid`

```liquid
<div
  x-data="searchComponent"
  class="search-container"
  @keydown.escape.window="closeSearch()"
  @keydown.meta.k.window.prevent="openSearch()"
  @keydown.ctrl.k.window.prevent="openSearch()"
  @keydown./.window="handleSlashKey($event)"
>
  <!-- Search Input -->
  <div class="search-input-wrapper">
    <svg class="search-icon"><!-- search icon --></svg>
    <input
      type="search"
      x-model="query"
      @input.debounce.300ms="performSearch()"
      @keydown.arrow-down.prevent="selectNext()"
      @keydown.arrow-up.prevent="selectPrevious()"
      @keydown.enter.prevent="openSelected()"
      placeholder="Search classes, attributes, associations... (Press / or Ctrl+K)"
      class="search-input"
      x-ref="searchInput"
    >
    <button
      x-show="query.length > 0"
      @click="clearSearch()"
      class="search-clear"
    >
      <svg><!-- close icon --></svg>
    </button>
  </div>

  <!-- Search Results Overlay -->
  <div
    x-show="showResults && results.length > 0"
    x-transition
    class="search-results-overlay"
  >
    <div class="search-results-header">
      <span x-text="`${results.length} results`"></span>
      <span class="search-hint">Use ↑↓ to navigate, Enter to open</span>
    </div>

    <div class="search-results-list">
      <template x-for="(result, index) in results" :key="result.id">
        <div
          @click="openResult(result)"
          @mouseenter="selectedIndex = index"
          :class="{ 'selected': selectedIndex === index }"
          class="search-result-item"
        >
          <!-- Result Type Icon -->
          <div class="result-icon" :data-type="result.type">
            <svg x-html="getIcon(result.type)"></svg>
          </div>

          <!-- Result Info -->
          <div class="result-info">
            <div class="result-name">
              <span x-html="highlightMatches(result.name, query)"></span>
              <span class="result-type-badge" x-text="result.type"></span>
            </div>
            <div class="result-path" x-text="result.qualifiedName || result.package"></div>
          </div>

          <!-- Relevance Score -->
          <div class="result-score">
            <div class="score-bar" :style="`width: ${(result.score / maxScore) * 100}%`"></div>
          </div>
        </div>
      </template>
    </div>
  </div>

  <!-- No Results -->
  <div
    x-show="showResults && results.length === 0 && query.length > 0"
    x-transition
    class="search-no-results"
  >
    <p>No results found for "<span x-text="query"></span>"</p>
    <p class="search-suggestion">Try different keywords or check spelling</p>
  </div>
</div>
```

---

### Phase 4: Alpine.js Application State (Week 5)
**Goal**: Centralized state management with Alpine.js

```javascript
// Main Alpine.js application
document.addEventListener('alpine:init', () => {
  Alpine.store('app', {
    // Data
    data: null,
    searchIndex: null,

    // State
    currentView: 'welcome',
    currentPackage: null,
    currentClass: null,
    breadcrumbs: [],
    expandedNodes: new Set(),
    sidebarVisible: true,
    darkMode: false,

    // Initialization
    async init() {
      await this.loadData();
      this.initializeRouter();
      this.restorePreferences();
    },

    async loadData() {
      if (window.UML_DATA) {
        // Single-file mode: data embedded
        this.data = window.UML_DATA;
        this.searchIndex = window.SEARCH_INDEX;
      } else {
        // Multi-file mode: load from JSON
        const [dataResp, indexResp] = await Promise.all([
          fetch(window.UML_DATA_URL),
          fetch(window.SEARCH_INDEX_URL)
        ]);
        this.data = await dataResp.json();
        this.searchIndex = await indexResp.json();
      }
    },

    // Navigation
    selectPackage(packageId) {
      this.currentPackage = packageId;
      this.currentClass = null;
      this.currentView = 'package';
      this.updateBreadcrumbs();
      this.pushState();
    },

    selectClass(classId) {
      this.currentClass = classId;
      this.currentPackage = this.data.classes[classId].package;
      this.currentView = 'class';
      this.updateBreadcrumbs();
      this.pushState();
    },

    // Tree expansion
    toggleNode(nodeId) {
      if (this.expandedNodes.has(nodeId)) {
        this.expandedNodes.delete(nodeId);
      } else {
        this.expandedNodes.add(nodeId);
      }
      this.savePreferences();
    },

    expandAll() {
      Object.keys(this.data.packages).forEach(id => {
        this.expandedNodes.add(id);
      });
    },

    collapseAll() {
      this.expandedNodes.clear();
    },

    // Theme
    toggleTheme() {
      this.darkMode = !this.darkMode;
      this.savePreferences();
    },

    // Persistence
    savePreferences() {
      localStorage.setItem('uml-browser-prefs', JSON.stringify({
        expandedNodes: Array.from(this.expandedNodes),
        darkMode: this.darkMode,
        sidebarVisible: this.sidebarVisible
      }));
    },

    restorePreferences() {
      const prefs = JSON.parse(localStorage.getItem('uml-browser-prefs') || '{}');
      this.expandedNodes = new Set(prefs.expandedNodes || []);
      this.darkMode = prefs.darkMode || false;
      this.sidebarVisible = prefs.sidebarVisible !== false;
    },

    // Router
    initializeRouter() {
      window.addEventListener('hashchange', () => this.handleRoute());
      this.handleRoute();
    },

    handleRoute() {
      const hash = window.location.hash.slice(1);
      if (!hash) {
        this.currentView = 'welcome';
        return;
      }

      const [path, query] = hash.split('?');
      const parts = path.split('/');

      if (parts[0] === 'package') {
        this.selectPackage(parts[1]);
      } else if (parts[0] === 'class') {
        this.selectClass(parts[1]);
      } else if (parts[0] === 'search') {
        const params = new URLSearchParams(query);
        this.performSearch(params.get('q'));
      }
    },

    pushState() {
      let hash = '';
      if (this.currentView === 'package') {
        hash = `#/package/${this.currentPackage}`;
      } else if (this.currentView === 'class') {
        hash = `#/class/${this.currentClass}`;
      }
      window.location.hash = hash;
    }
  });

  // Component: Package Tree
  Alpine.data('packageTree', () => ({
    get rootNodes() {
      const tree = this.$store.app.data?.packageTree;
      return tree ? [tree] : [];
    }
  }));

  // Component: Tree Node
  Alpine.data('treeNode', (node) => ({
    node,
    get expanded() {
      return this.$store.app.expandedNodes.has(this.node.id);
    },
    get hasChildren() {
      return (this.node.children && this.node.children.length > 0) ||
             (this.node.classes && this.node.classes.length > 0);
    },
    get isSelected() {
      return this.$store.app.currentPackage === this.node.id;
    },
    toggle() {
      this.$store.app.toggleNode(this.node.id);
    },
    selectPackage(id) {
      this.$store.app.selectPackage(id);
    },
    selectClass(id) {
      this.$store.app.selectClass(id);
    },
    getClass(id) {
      return this.$store.app.data.classes[id];
    }
  }));

  // Component: Search
  Alpine.data('searchComponent', () => ({
    query: '',
    results: [],
    selectedIndex: 0,
    showResults: false,
    searchEngine: null,

    init() {
      // Initialize search engine when data is loaded
      this.$watch('$store.app.searchIndex', (index) => {
        if (index) {
          this.searchEngine = new SearchEngine(
            index,
            this.$store.app.searchIndex.documentStore
          );
        }
      });
    },

    performSearch() {
      if (!this.query || this.query.length < 2) {
        this.results = [];
        this.showResults = false;
        return;
      }

      this.results = this.searchEngine.search(this.query, {
        fuzzy: true,
        limit: 50
      });
      this.selectedIndex = 0;
      this.showResults = true;
    },

    openResult(result) {
      if (result.type === 'class') {
        this.$store.app.selectClass(result.entityId);
      } else if (result.type === 'attribute') {
        this.$store.app.selectClass(result.owner);
      } else if (result.type === 'package') {
        this.$store.app.selectPackage(result.entityId);
      }
      this.closeSearch();
    },

    selectNext() {
      this.selectedIndex = Math.min(this.selectedIndex + 1, this.results.length - 1);
    },

    selectPrevious() {
      this.selectedIndex = Math.max(this.selectedIndex - 1, 0);
    },

    openSelected() {
      if (this.results[this.selectedIndex]) {
        this.openResult(this.results[this.selectedIndex]);
      }
    },

    closeSearch() {
      this.showResults = false;
      this.query = '';
      this.results = [];
    },

    clearSearch() {
      this.query = '';
      this.results = [];
      this.$refs.searchInput.focus();
    },

    openSearch() {
      this.$refs.searchInput.focus();
    },

    handleSlashKey(event) {
      // Only trigger if not in an input
      if (event.target.tagName !== 'INPUT' && event.target.tagName !== 'TEXTAREA') {
        event.preventDefault();
        this.openSearch();
      }
    },

    highlightMatches(text, query) {
      if (!query) return text;

      const tokens = query.toLowerCase().split(/\s+/);
      let highlighted = text;

      tokens.forEach(token => {
        const regex = new RegExp(`(${token})`, 'gi');
        highlighted = highlighted.replace(regex, '<mark>$1</mark>');
      });

      return highlighted;
    },

    get maxScore() {
      return Math.max(...this.results.map(r => r.score), 1);
    }
  }));
});
```

---

### Phase 5: Sinatra Refactoring (Week 6)
**Goal**: Refactor existing Sinatra app to serve the SPA with JSON endpoints

#### 5.1 New Sinatra Architecture

**File**: `lib/lutaml/xmi/web_ui/app_refactored.rb`

```ruby
module Lutaml
  module Xmi
    module WebUi
      class App < Sinatra::Base
        set :public_folder, File.join(__dir__, "public")

        # Serve the SPA (index.html)
        get "/" do
          # Use the same templates as static generator
          # but in "live" mode with JSON endpoints
          template_renderer = StaticSite::TemplateRenderer.new
          template_renderer.render_layout("base", {
            config: {
              mode: "multi_file",
              title: "UML Repository Explorer (Live)",
              api_mode: true  # Flag to use API endpoints instead of static JSON
            }
          })
        end

        # API: Full data model as JSON
        get "/api/data" do
          content_type :json

          transformer = StaticSite::DataTransformer.new(repository)
          transformer.transform.to_json
        end

        # API: Search index
        get "/api/search/index" do
          content_type :json

          builder = StaticSite::SearchIndexBuilder.new(repository)
          builder.build.to_json
        end

        # API: Package details (on-demand)
        get "/api/packages/:id" do
          content_type :json
          package = repository.find_package_by_id(params[:id])
          halt 404 unless package

          SerializePackage.new(package).to_json
        end

        # API: Class details (on-demand)
        get "/api/classes/:id" do
          content_type :json
          klass = repository.find_class_by_id(params[:id])
          halt 404 unless klass

          SerializeClass.new(klass).to_json
        end

        # Keep existing live search endpoint for fallback
        get "/api/search" do
          content_type :json
          query = params[:q]

          # Can use live search or use the search index
          results = repository.search(query)
          format_search_results(results).to_json
        end

        private

        def repository
          settings.repository
        end
      end
    end
  end
end
```

#### 5.2 Dual-Mode JavaScript

```javascript
// assets/scripts/data-loader.js
class DataLoader {
  constructor(config) {
    this.config = config;
    this.cache = new Map();
  }

  async loadData() {
    if (this.config.api_mode) {
      // Live mode: fetch from Sinatra API
      const response = await fetch('/api/data');
      return await response.json();
    } else if (window.UML_DATA) {
      // Single-file mode: embedded data
      return window.UML_DATA;
    } else {
      // Multi-file mode: static JSON
      const response = await fetch(window.UML_DATA_URL);
      return await response.json();
    }
  }

  async loadSearchIndex() {
    if (this.config.api_mode) {
      const response = await fetch('/api/search/index');
      return await response.json();
    } else if (window.SEARCH_INDEX) {
      return window.SEARCH_INDEX;
    } else {
      const response = await fetch(window.SEARCH_INDEX_URL);
      return await response.json();
    }
  }

  async loadPackage(packageId) {
    if (this.cache.has(packageId)) {
      return this.cache.get(packageId);
    }

    if (this.config.api_mode) {
      // On-demand loading from API
      const response = await fetch(`/api/packages/${packageId}`);
      const data = await response.json();
      this.cache.set(packageId, data);
      return data;
    } else {
      // Already in full data model
      return this.data.packages[packageId];
    }
  }
}
```

---

### Phase 6: CSS Implementation (Week 7)
**Goal**: Modern, responsive CSS with dark theme

See detailed CSS architecture in main SPA_ARCHITECTURE.md document. Key highlights:

- **CSS Grid** for main layout
- **CSS Flexbox** for components
- **CSS Custom Properties** for theming
- **Mobile-first responsive** design
- **Dark mode** via CSS custom properties
- **Smooth transitions** and animations

---

### Phase 7-8: Polish & Documentation (Week 8)
**Goal**: Production-ready release

- [ ] Accessibility audit (WCAG 2.1 AA)
- [ ] Performance optimization
- [ ] Browser testing
- [ ] Documentation (user guide, developer guide)
- [ ] Examples and demos
- [ ] CLI polish

---

## 2. Milestones & Deliverables

### Milestone 1: Foundation (End of Week 2)
**Deliverables**:
- ✅ Data transformer (Repository → JSON)
- ✅ Search index builder (Ruby)
- ✅ ID generation strategy
- ✅ Basic test suite
- ✅ CLI command structure

### Milestone 2: Templates (End of Week 3)
**Deliverables**:
- ✅ Liquid template system
- ✅ Base layout
- ✅ Component templates
- ✅ Single-file output working
- ✅ Multi-file output working

### Milestone 3: Search (End of Week 4)
**Deliverables**:
- ✅ Client-side search engine
- ✅ Fuzzy matching
- ✅ TF-IDF ranking
- ✅ Search UI component
- ✅ Keyboard navigation

### Milestone 4: Alpine.js Integration (End of Week 5)
**Deliverables**:
- ✅ Alpine.js app store
- ✅ Reactive components
- ✅ Router with hash nav
- ✅ State persistence
- ✅ Full interactivity

### Milestone 5: Sinatra Refactoring (End of Week 6)
**Deliverables**:
- ✅ Refactored Sinatra app
- ✅ JSON API endpoints
- ✅ Dual-mode data loader
- ✅ Live updates
- ✅ Backward compatibility

### Milestone 6: Styling (End of Week 7)
**Deliverables**:
- ✅ Complete CSS implementation
- ✅ Responsive design
- ✅ Dark theme
- ✅ Icons and assets
- ✅ Animations

### Milestone 7: Production Release (End of Week 8)
**Deliverables**:
- ✅ Accessibility compliance
- ✅ Performance optimization
- ✅ Browser testing
- ✅ Complete documentation
- ✅ Examples and tutorials
- ✅ Release v1.0

---

## 3. Technical Dependencies

### Ruby Gems
```ruby
# Gemfile
gem 'liquid', '~> 5.0'           # Template engine
gem 'json', '~> 2.0'              # JSON generation
gem 'redcarpet', '~> 3.0'         # Markdown rendering (for EA notes)
gem 'rouge', '~> 4.0'             # Syntax highlighting
gem 'fast-stemmer', '~> 1.0'     # Porter stemmer for search
```

### Client-Side (CDN)
```html
<!-- Alpine.js -->
<script defer src="https://cdn.jsdelivr.net/npm/alpinejs@3.13.3/dist/cdn.min.js"></script>

<!-- Feather Icons (optional) -->
<script src="https://cdn.jsdelivr.net/npm/feather-icons/dist/feather.min.js"></script>
```

### Development Tools
- RSpec for testing
- RuboCop for linting
- Rake for build tasks

---

## 4. Testing Strategy

### Ruby Tests
```ruby
# spec/lutaml/xmi/static_site/data_transformer_spec.rb
RSpec.describe Lutaml::Xmi::StaticSite::DataTransformer do
  it "transforms repository to JSON structure"
  it "generates stable IDs"
  it "handles nested packages"
  it "serializes all element types"
end

# spec/lutaml/xmi/static_site/search_index_builder_spec.rb
RSpec.describe Lutaml::Xmi::StaticSite::SearchIndexBuilder do
  it "builds inverted index"
  it "calculates TF-IDF vectors"
  it "stems and tokenizes text"
  it "handles special characters"
end
```

### JavaScript Tests
- Use browser-based testing (no Node.js required)
- Selenium/Capybara for E2E
- Manual testing with real browser

### Integration Tests
```ruby
RSpec.describe "Full SPA Generation" do
  it "generates single-file SPA"
  it "generates multi-file site"
  it "includes search index"
  it "all links work"
  it "search returns results"
end
```

---

##  5. CLI Integration

```bash
# Generate single-file SPA
lutaml xmi build-spa plateau_all_packages.lur -o browser.html

# Generate multi-file site
lutaml xmi build-spa plateau_all_packages.lur -o dist/ --multi-file

# With custom config
lutaml xmi build-spa plateau_all_packages.lur -o dist/ --config spa-config.yml

# Start live server (refactored Sinatra)
lutaml xmi serve plateau_all_packages.lur --port 3000

# Build with options
lutaml xmi build-spa plateau_all_packages.lur \
  --output dist/ \
  --title "PLATEAU UML Browser" \
  --theme dark \
  --enable-search \
  --max-tree-depth 3 \
  --minify
```

---

## 6. Success Criteria

✅ **Functional Requirements**:
- Both single-file and multi-file output work
- Sidebar navigation with collapsible tree
- Package and class detail views
- Full-text search with fuzzy matching
- Keyboard navigation
- Responsive design
- Dark/light themes

✅ **Non-Functional Requirements**:
- No Node.js build required
- WCAG 2.1 AA compliant
- Works in modern browsers (last 2 versions)
- Fast load time (< 3s for 10MB model)
- Smooth interactions (60 FPS)

✅ **Integration Requirements**:
- Refactored Sinatra uses same SPA code
- CLI integrates seamlessly
- Backward compatible with existing workflow

---

**Version**: 1.0 Draft
**Last Updated**: 2024-11-01
**Status**: Ready for Implementation
**Next Step**: Begin Phase 1 - Foundation & Data Layer
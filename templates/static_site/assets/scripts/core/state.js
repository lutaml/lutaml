// Alpine.js Application State
// Main state store for the UML Browser SPA

document.addEventListener('alpine:init', () => {
  Alpine.store('app', {
    // Data
    data: null,
    searchIndex: null,
    searchEngine: null,
    config: window.APP_CONFIG || {},

    // Current State
    currentView: 'welcome',  // 'welcome' | 'package' | 'class' | 'search'
    currentPackage: null,
    currentClass: null,
    searchQuery: '',
    searchResults: [],

    // UI State
    sidebarVisible: true,
    darkMode: false,
    expandedNodes: new Set(),
    breadcrumbs: [],

    // Initialization
    async init() {
      await this.loadData();
      this.initRouter();
      this.restorePreferences();
      this.initKeyboardShortcuts();
    },

    // Data Loading
    async loadData() {
      try {
        if (window.UML_DATA && window.SEARCH_INDEX) {
          // Single-file mode: embedded data
          this.data = window.UML_DATA;
          this.searchIndex = window.SEARCH_INDEX;
        } else if (window.UML_DATA_URL && window.SEARCH_INDEX_URL) {
          // Multi-file mode: fetch from JSON or API
          const [dataResp, indexResp] = await Promise.all([
            fetch(window.UML_DATA_URL),
            fetch(window.SEARCH_INDEX_URL)
          ]);

          this.data = await dataResp.json();
          this.searchIndex = await indexResp.json();
        } else {
          console.error('No data source configured');
          return;
        }

        // Initialize search engine once data is loaded
        if (this.searchIndex && typeof lunr !== 'undefined') {
          this.initSearchEngine();
        }
      } catch (error) {
        console.error('Failed to load data:', error);
      }
    },

    // Initialize lunr.js search engine
    initSearchEngine() {
      const docs = this.searchIndex.documentStore;

      this.searchEngine = lunr(function() {
        this.ref('id');

        // Add fields with boost values
        this.field('name', { boost: 10 });
        this.field('qualifiedName', { boost: 5 });
        this.field('type', { boost: 3 });
        this.field('package', { boost: 2 });
        this.field('content', { boost: 1 });

        // Add documents
        docs.forEach(doc => {
          this.add(doc);
        });
      });
    },

    // Navigation Methods
    showWelcome() {
      this.currentView = 'welcome';
      this.currentPackage = null;
      this.currentClass = null;
      this.breadcrumbs = [];
      this.pushState();
    },

    selectPackage(packageId) {
      this.currentPackage = packageId;
      this.currentClass = null;
      this.currentView = 'package';
      this.updateBreadcrumbs();
      this.pushState();
    },

    selectClass(classId) {
      const cls = this.data.classes[classId];
      if (!cls) return;

      this.currentClass = classId;
      this.currentPackage = cls.package;
      this.currentView = 'class';
      this.updateBreadcrumbs();
      this.pushState();
    },

    performSearch(query) {
      if (!query || query.length < 2) {
        this.searchResults = [];
        return [];
      }

      this.searchQuery = query;

      if (!this.searchEngine) {
        console.warn('Search engine not initialized');
        return [];
      }

      try {
        // Perform search with lunr.js
        const lunrResults = this.searchEngine.search(query);

        // Map results back to documents
        const docs = this.searchIndex.documentStore;
        this.searchResults = lunrResults.map(result => {
          const doc = docs.find(d => d.id === result.ref);
          return {
            ...doc,
            score: result.score,
            matchData: result.matchData
          };
        });

        return this.searchResults;
      } catch (error) {
        console.error('Search error:', error);
        return [];
      }
    },

    showSearchResults(query) {
      this.searchQuery = query;
      this.currentView = 'search';
      this.updateBreadcrumbs();
      this.pushState();
    },

    // Tree Management
    toggleNode(nodeId) {
      if (this.expandedNodes.has(nodeId)) {
        this.expandedNodes.delete(nodeId);
      } else {
        this.expandedNodes.add(nodeId);
      }
      this.savePreferences();
    },

    isNodeExpanded(nodeId) {
      return this.expandedNodes.has(nodeId);
    },

    expandAll() {
      if (!this.data) return;

      Object.keys(this.data.packages).forEach(id => {
        this.expandedNodes.add(id);
      });
      this.savePreferences();
    },

    collapseAll() {
      this.expandedNodes.clear();
      this.savePreferences();
    },

    // Breadcrumb Management
    updateBreadcrumbs() {
      this.breadcrumbs = [];

      if (this.currentView === 'package' && this.currentPackage) {
        this.breadcrumbs = this.buildPackageBreadcrumbs(this.currentPackage);
      } else if (this.currentView === 'class' && this.currentClass) {
        this.breadcrumbs = this.buildClassBreadcrumbs(this.currentClass);
      } else if (this.currentView === 'search') {
        this.breadcrumbs = [{ name: `Search: ${this.searchQuery}`, type: 'search' }];
      }
    },

    buildPackageBreadcrumbs(packageId) {
      const breadcrumbs = [];
      let currentPkg = this.data.packages[packageId];

      while (currentPkg) {
        breadcrumbs.unshift({
          type: 'package',
          id: currentPkg.id,
          name: currentPkg.name
        });

        if (currentPkg.parent) {
          currentPkg = this.data.packages[currentPkg.parent];
        } else {
          break;
        }
      }

      return breadcrumbs;
    },

    buildClassBreadcrumbs(classId) {
      const cls = this.data.classes[classId];
      const breadcrumbs = [];

      // Add package breadcrumbs
      if (cls.package) {
        breadcrumbs.push(...this.buildPackageBreadcrumbs(cls.package));
      }

      // Add class itself
      breadcrumbs.push({
        type: 'class',
        id: cls.id,
        name: cls.name
      });

      return breadcrumbs;
    },

    navigateToCrumb(crumb) {
      if (crumb.type === 'package') {
        this.selectPackage(crumb.id);
      } else if (crumb.type === 'class') {
        this.selectClass(crumb.id);
      }
    },

    // Theme Management
    toggleTheme() {
      this.darkMode = !this.darkMode;
      this.savePreferences();
    },

    // Router (Hash-based)
    initRouter() {
      window.addEventListener('hashchange', () => this.handleRoute());
      this.handleRoute();
    },

    handleRoute() {
      const hash = window.location.hash.slice(1);

      if (!hash || hash === '/') {
        this.showWelcome();
        return;
      }

      const [path, queryString] = hash.split('?');
      const parts = path.split('/').filter(p => p);

      if (parts[0] === 'package' && parts[1]) {
        this.selectPackage(decodeURIComponent(parts[1]));
      } else if (parts[0] === 'class' && parts[1]) {
        this.selectClass(decodeURIComponent(parts[1]));
      } else if (parts[0] === 'search') {
        const params = new URLSearchParams(queryString);
        const query = params.get('q');
        if (query) {
          const results = this.performSearch(query);
          if (results.length > 0) {
            this.showSearchResults(query);
          }
        }
      }
    },

    pushState() {
      let hash = '#/';

      if (this.currentView === 'package' && this.currentPackage) {
        hash = `#/package/${encodeURIComponent(this.currentPackage)}`;
      } else if (this.currentView === 'class' && this.currentClass) {
        hash = `#/class/${encodeURIComponent(this.currentClass)}`;
      } else if (this.currentView === 'search' && this.searchQuery) {
        hash = `#/search?q=${encodeURIComponent(this.searchQuery)}`;
      }

      if (window.location.hash !== hash) {
        window.location.hash = hash;
      }
    },

    // Keyboard Shortcuts
    initKeyboardShortcuts() {
      window.addEventListener('keydown', (e) => {
        // Ctrl/Cmd + K: Focus search
        if ((e.ctrlKey || e.metaKey) && e.key === 'k') {
          e.preventDefault();
          const searchInput = document.querySelector('.search-input');
          if (searchInput) searchInput.focus();
        }

        // / : Focus search (if not in input)
        if (e.key === '/' && !['INPUT', 'TEXTAREA'].includes(e.target.tagName)) {
          e.preventDefault();
          const searchInput = document.querySelector('.search-input');
          if (searchInput) searchInput.focus();
        }

        // Escape: Clear search
        if (e.key === 'Escape') {
          const searchInput = document.querySelector('.search-input');
          if (searchInput === document.activeElement) {
            searchInput.blur();
          }
        }
      });
    },

    // Preferences Persistence
    savePreferences() {
      const prefs = {
        expandedNodes: Array.from(this.expandedNodes),
        darkMode: this.darkMode,
        sidebarVisible: this.sidebarVisible
      };

      localStorage.setItem('uml-browser-preferences', JSON.stringify(prefs));
    },

    restorePreferences() {
      try {
        const stored = localStorage.getItem('uml-browser-preferences');
        if (!stored) return;

        const prefs = JSON.parse(stored);
        this.expandedNodes = new Set(prefs.expandedNodes || []);
        this.darkMode = prefs.darkMode || false;
        this.sidebarVisible = prefs.sidebarVisible !== false;
      } catch (error) {
        console.error('Failed to restore preferences:', error);
      }
    },

    // Utility: Check if mobile
    get isMobile() {
      return window.innerWidth < 1024;
    }
  });
});
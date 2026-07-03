// Alpine.js Component for Search

document.addEventListener('alpine:init', () => {
  Alpine.data('searchComponent', () => ({
    query: '',
    results: [],
    selectedIndex: 0,
    showResults: false,

    init() {
      // Watch for search index initialization
      this.$watch('$store.app.searchEngine', (engine) => {
        if (engine && this.query) {
          this.performSearch();
        }
      });
    },

    performSearch() {
      if (!this.query || this.query.length < 2) {
        this.results = [];
        this.showResults = false;
        return;
      }

      const searchResults = this.$store.app.performSearch(this.query);
      this.results = searchResults;
      this.selectedIndex = 0;
      this.showResults = true;
    },

    openResult(result) {
      if (result.type === 'class') {
        this.$store.app.selectClass(result.entityId);
      } else if (result.type === 'attribute') {
        // Open the owner class
        this.$store.app.selectClass(result.ownerId);
      } else if (result.type === 'package') {
        this.$store.app.selectPackage(result.entityId);
      } else if (result.type === 'association') {
        // Could show association details or related classes
        // For now, just close search
      }

      this.closeSearch();
    },

    selectNext() {
      if (this.results.length > 0) {
        this.selectedIndex = Math.min(this.selectedIndex + 1, this.results.length - 1);
      }
    },

    selectPrevious() {
      if (this.results.length > 0) {
        this.selectedIndex = Math.max(this.selectedIndex - 1, 0);
      }
    },

    openSelected() {
      if (this.results[this.selectedIndex]) {
        this.openResult(this.results[this.selectedIndex]);
      }
    },

    closeSearch() {
      this.showResults = false;
    },

    clearSearch() {
      this.query = '';
      this.results = [];
      this.showResults = false;
      this.$refs.searchInput?.focus();
    },

    getTypeIcon(type) {
      const icons = {
        class: 'C',
        attribute: 'A',
        association: '╱',
        package: '📦'
      };
      return icons[type] || '?';
    },

    highlightMatches(text, query) {
      if (!query || !text) return text;

      // Split query into tokens
      const tokens = query.toLowerCase().split(/\s+/);
      let highlighted = text;

      // Highlight each token
      tokens.forEach(token => {
        if (token.length < 2) return;

        const regex = new RegExp(`(${this.escapeRegex(token)})`, 'gi');
        highlighted = highlighted.replace(regex, '<mark>$1</mark>');
      });

      return highlighted;
    },

    escapeRegex(str) {
      return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    },

    get maxScore() {
      if (this.results.length === 0) return 1;
      return Math.max(...this.results.map(r => r.score));
    }
  }));

  // Search Results View Component
  Alpine.data('searchResultsView', () => ({
    get searchQuery() {
      return this.$store.app.searchQuery;
    },

    get searchResults() {
      return this.$store.app.searchResults;
    },

    get groupedResults() {
      const grouped = {};

      this.searchResults.forEach(result => {
        const type = result.type;
        if (!grouped[type]) {
          grouped[type] = {
            type: this.capitalizeType(type),
            items: []
          };
        }
        grouped[type].items.push(result);
      });

      return Object.values(grouped);
    },

    capitalizeType(type) {
      return type.charAt(0).toUpperCase() + type.slice(1);
    },

    openResult(result) {
      if (result.type === 'class') {
        this.$store.app.selectClass(result.entityId);
      } else if (result.type === 'attribute') {
        this.$store.app.selectClass(result.ownerId);
      } else if (result.type === 'package') {
        this.$store.app.selectPackage(result.entityId);
      }
    },

    highlightMatches(text, query) {
      if (!query || !text) return text;

      const tokens = query.toLowerCase().split(/\s+/);
      let highlighted = text;

      tokens.forEach(token => {
        if (token.length < 2) return;
        const regex = new RegExp(`(${this.escapeRegex(token)})`, 'gi');
        highlighted = highlighted.replace(regex, '<mark>$1</mark>');
      });

      return highlighted;
    },

    escapeRegex(str) {
      return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    },

    getScoreClass(score) {
      const normalized = score / this.maxScore;
      if (normalized > 0.7) return 'score-high';
      if (normalized > 0.4) return 'score-medium';
      return 'score-low';
    },

    get maxScore() {
      if (this.searchResults.length === 0) return 1;
      return Math.max(...this.searchResults.map(r => r.score));
    }
  }));
});
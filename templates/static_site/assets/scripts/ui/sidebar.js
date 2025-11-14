// Alpine.js Components for Sidebar

document.addEventListener('alpine:init', () => {
  // Package Tree Component
  Alpine.data('packageTree', () => ({
    get data() {
      return this.$store.app.data;
    },

    get rootNodes() {
      if (!this.data || !this.data.packageTree) return [];

      // Return as array for iteration
      return [this.data.packageTree];
    }
  }));

  // Tree Node Component (Recursive)
  Alpine.data('treeNode', (node) => ({
    node,

    get expanded() {
      return this.$store.app.isNodeExpanded(this.node.id);
    },

    get hasChildren() {
      return (this.node.children && this.node.children.length > 0) ||
             (this.node.classes && this.node.classes.length > 0);
    },

    get isSelected() {
      return this.$store.app.currentPackage === this.node.id;
    },

    get currentClass() {
      return this.$store.app.currentClass;
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

    getClass(classId) {
      return this.$store.app.data?.classes[classId];
    }
  }));

  // Sidebar Actions
  Alpine.data('sidebarActions', () => ({
    expandAll() {
      this.$store.app.expandAll();
    },

    collapseAll() {
      this.$store.app.collapseAll();
    }
  }));
});
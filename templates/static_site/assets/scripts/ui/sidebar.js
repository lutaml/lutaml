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

  // Recursive tree rendering component with full reactivity
  Alpine.data('renderTree', (rootNode) => ({
    treeHtml: '',

    init() {
      this.rebuildTree();

      // Watch for state changes and rebuild tree
      this.$watch('$store.app.expandedNodes', () => {
        this.rebuildTree();
      });

      this.$watch('$store.app.currentPackage', () => {
        this.rebuildTree();
      });

      this.$watch('$store.app.currentClass', () => {
        this.rebuildTree();
      });
    },

    rebuildTree() {
      this.treeHtml = this.buildTreeNode(rootNode);
    },

    buildTreeNode(node) {
      const store = Alpine.store('app');
      const expanded = store.isNodeExpanded(node.id);
      const isSelected = store.currentPackage === node.id;
      const hasChildren = (node.children && node.children.length > 0) ||
                          (node.classes && node.classes.length > 0);

      let html = `<div class="tree-node${isSelected ? ' selected' : ''}">`;
      html += '<div class="node-header">';

      // Expand/collapse button
      if (hasChildren) {
        html += `<button onclick="Alpine.store('app').toggleNode('${node.id}')" class="expand-icon${expanded ? ' expanded' : ''}">`;
        html += '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">';
        html += '<polyline points="9 18 15 12 9 6"></polyline></svg></button>';
      } else {
        html += '<span class="no-icon"></span>';
      }

      // Package icon and label
      html += '<svg class="package-icon" xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">';
      html += '<path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"></path></svg>';

      html += `<button onclick="Alpine.store('app').selectPackage('${node.id}')" class="node-label${isSelected ? ' active' : ''}" title="${node.path || ''}">`;
      html += `<span>${this.escapeHtml(node.name)}</span></button>`;

      // Class count badge
      if (node.classCount > 0) {
        html += `<span class="count-badge" title="${node.classCount} class${node.classCount !== 1 ? 'es' : ''}">${node.classCount}</span>`;
      }

      html += '</div>'; // node-header

      // Children (packages and classes)
      if (hasChildren && expanded) {
        html += '<div class="node-children">';

        // Render child packages
        if (node.children && node.children.length > 0) {
          node.children.forEach(child => {
            html += this.buildTreeNode(child);
          });
        }

        // Render classes
        if (node.classes && node.classes.length > 0) {
          node.classes.forEach(classId => {
            html += this.buildClassNode(classId);
          });
        }

        html += '</div>';
      }

      html += '</div>'; // tree-node
      return html;
    },

    buildClassNode(classId) {
      const store = Alpine.store('app');
      const cls = store.data?.classes[classId];
      if (!cls) return '';

      const isSelected = store.currentClass === classId;

      let html = `<div class="tree-node class-node${isSelected ? ' selected' : ''}">`;
      html += '<div class="node-header">';
      html += '<span class="no-icon"></span>';

      // Class icon
      html += '<svg class="class-icon" xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">';
      html += '<rect x="3" y="3" width="18" height="18" rx="2" ry="2"></rect>';
      html += '<line x1="3" y1="9" x2="21" y2="9"></line>';
      html += '<line x1="9" y1="21" x2="9" y2="9"></line>';
      html += '</svg>';

      html += `<button onclick="Alpine.store('app').selectClass('${classId}')" class="node-label${isSelected ? ' active' : ''}" title="${this.escapeHtml(cls.qualifiedName || cls.name)}">`;
      html += `<span>${this.escapeHtml(cls.name)}</span></button>`;

      html += '</div>'; // node-header
      html += '</div>'; // tree-node

      return html;
    },

    escapeHtml(text) {
      const map = {
        '&': '&amp;',
        '<': '&lt;',
        '>': '&gt;',
        '"': '&quot;',
        "'": '&#039;'
      };
      return String(text).replace(/[&<>"']/g, m => map[m]);
    }
  }));
});

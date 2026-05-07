// Sidebar Tree — LutaML Branded
// Compact, clean tree matching lutaml-xsd SchemaTreeNode

document.addEventListener('alpine:init', () => {
  Alpine.data('packageTree', () => ({
    get data() {
      return this.$store.app.data;
    },

    get rootNodes() {
      if (!this.data || !this.data.packageTree) return [];
      return [this.data.packageTree];
    }
  }));

  Alpine.data('renderTree', (rootNode) => ({
    treeHtml: '',
    rootNode,

    init() {
      this.rebuildTree();
      window.addEventListener('tree-rebuild', () => this.rebuildTree());
      this.$watch('$store.app.expandedNodes.size', () => this.rebuildTree());
      this.$watch('$store.app.currentPackage', () => this.rebuildTree());
      this.$watch('$store.app.currentClass', () => this.rebuildTree());
    },

    rebuildTree() {
      if (!this.rootNode) { this.treeHtml = ''; return; }
      this.treeHtml = this.buildPackageNode(this.rootNode);
    },

    buildPackageNode(node) {
      const store = Alpine.store('app');
      const expanded = store.isNodeExpanded(node.id);
      const selected = store.currentPackage === node.id;
      const hasChildren = (node.children && node.children.length > 0) ||
                          (node.classes && node.classes.length > 0);
      const pkg = store.data?.packages[node.id];
      const stereotypes = pkg?.stereotypes || node.stereotypes || [];

      let h = '<div class="tree-node">';
      h += '<div class="tree-node-content' + (selected ? ' selected' : '') + '">';

      // Expand toggle
      if (hasChildren) {
        h += '<button onclick="Alpine.store(\'app\').toggleNode(\'' + node.id + '\'); window.dispatchEvent(new CustomEvent(\'tree-rebuild\'));" class="tree-toggle">';
        h += '<svg width="12" height="12" viewBox="0 0 12 12" fill="none"' + (expanded ? ' class="expanded"' : '') + '>';
        h += '<path d="M4 3l3 3-3 3" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>';
        h += '</svg></button>';
      } else {
        h += '<span class="tree-toggle-placeholder"></span>';
      }

      // Folder icon
      h += '<span class="tree-icon">';
      h += '<svg width="14" height="14" viewBox="0 0 14 14" fill="none">';
      h += '<path d="M2 5a2 2 0 012-2h2.5L8 4.5h2a2 2 0 012 2v2.5a2 2 0 01-2 2H4a2 2 0 01-2-2V5z" stroke="currentColor" stroke-width="1.1"/>';
      h += '</svg></span>';

      // Label
      h += '<button onclick="Alpine.store(\'app\').selectPackage(\'' + node.id + '\')" class="tree-label" title="' + this.esc(node.path || node.name) + '">';
      if (stereotypes.length > 0) {
        h += '<span class="tree-stereotype">«' + this.esc(stereotypes[0]) + '» </span>';
      }
      h += this.esc(node.name) + '</button>';

      // Count badge
      if (node.classCount > 0) {
        h += '<span class="tree-count">' + node.classCount + '</span>';
      }

      h += '</div>'; // tree-node-content

      // Children
      if (hasChildren && expanded) {
        h += '<div class="tree-children">';

        if (node.classes && node.classes.length > 0) {
          h += '<div class="tree-group">';
          h += '<div class="tree-group-label">Classes <span class="tree-count">' + node.classes.length + '</span></div>';
          h += '<div class="tree-group-items">';
          node.classes.forEach(cd => {
            const classId = typeof cd === 'string' ? cd : cd.id;
            h += this.buildClassLeaf(classId);
          });
          h += '</div></div>';
        }

        if (node.children && node.children.length > 0) {
          node.children.forEach(child => {
            h += this.buildPackageNode(child);
          });
        }

        h += '</div>';
      }

      h += '</div>';
      return h;
    },

    buildClassLeaf(classId) {
      const store = Alpine.store('app');
      const cls = store.data?.classes[classId];
      if (!cls) return '';

      const selected = store.currentClass === classId;
      const typeKey = (cls.type === 'Enumeration' ? 'enum' : cls.type === 'DataType' ? 'datatype' : cls.type === 'Interface' ? 'interface' : 'class');

      let h = '<div class="tree-item' + (selected ? ' selected' : '') + '" onclick="Alpine.store(\'app\').selectClass(\'' + classId + '\')">';
      h += '<span class="badge badge-' + typeKey + '">' + (cls.type === 'Enumeration' ? 'E' : cls.type === 'DataType' ? 'DT' : cls.type === 'Interface' ? 'I' : 'C') + '</span>';
      h += '<span class="tree-item-label" title="' + this.esc(cls.qualifiedName || cls.name) + '">' + this.esc(cls.name) + '</span>';
      h += '</div>';
      return h;
    },

    esc(text) {
      const m = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#039;' };
      return String(text).replace(/[&<>"']/g, c => m[c]);
    }
  }));
});

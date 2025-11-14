// Alpine.js Components for Details Pane

document.addEventListener('alpine:init', () => {
  // Main content area with view management
  Alpine.data('contentArea', () => ({
    get currentView() {
      return this.$store.app.currentView;
    },

    get breadcrumbs() {
      return this.$store.app.breadcrumbs;
    },

    navigateToCrumb(crumb) {
      this.$store.app.navigateToCrumb(crumb);
    },

    showWelcome() {
      this.$store.app.showWelcome();
    }
  }));

  // Package Details Component
  Alpine.data('packageDetails', () => ({
    get currentPackage() {
      return this.$store.app.currentPackage;
    },

    get data() {
      return this.$store.app.data;
    },

    selectPackage(id) {
      this.$store.app.selectPackage(id);
    },

    selectClass(id) {
      this.$store.app.selectClass(id);
    }
  }));

  // Class Details Component
  Alpine.data('classDetails', () => ({
    get currentClass() {
      return this.$store.app.currentClass;
    },

    get data() {
      return this.$store.app.data;
    },

    selectPackage(id) {
      this.$store.app.selectPackage(id);
    },

    selectClass(id) {
      this.$store.app.selectClass(id);
    },

    getAssociationTarget(association, currentClassId) {
      if (!association) return null;

      // Determine which end is the target (not the current class)
      if (association.source && association.source.class === currentClassId) {
        return association.target;
      } else if (association.target && association.target.class === currentClassId) {
        return association.source;
      }

      // Default to target
      return association.target;
    }
  }));
});
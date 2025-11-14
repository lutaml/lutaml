// Main Application Entry Point
// Initializes the UML Browser SPA

(function() {
  'use strict';

  // Wait for DOM to be ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initApp);
  } else {
    initApp();
  }

  function initApp() {
    console.log('🚀 UML Browser SPA initialized');

    // Check required dependencies
    if (typeof Alpine === 'undefined') {
      console.error('Alpine.js not loaded');
      return;
    }

    if (typeof lunr === 'undefined') {
      console.error('lunr.js not loaded');
      return;
    }

    // Application is initialized by Alpine.js
    // See core/state.js for main app store
    console.log('✓ Alpine.js loaded');
    console.log('✓ lunr.js loaded');
    console.log('✓ All components registered');
  }

  // Handle unhandled errors
  window.addEventListener('error', (event) => {
    console.error('Application error:', event.error);
  });

  // Handle unhandled promise rejections
  window.addEventListener('unhandledrejection', (event) => {
    console.error('Unhandled promise rejection:', event.reason);
  });

})();
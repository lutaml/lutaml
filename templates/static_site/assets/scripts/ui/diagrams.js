/**
 * Diagram Viewer Module
 * Handles loading and displaying UML diagrams
 */
(function(window) {
  'use strict';

  /**
   * DiagramViewer class
   * Manages diagram loading, rendering, and interactivity
   */
  class DiagramViewer {
    constructor() {
      this.currentDiagram = null;
      this.scale = 1.0;
      this.panX = 0;
      this.panY = 0;
      this.isPanning = false;
      this.startX = 0;
      this.startY = 0;
      this.container = null;
      this.svgElement = null;
    }

    /**
     * Initialize diagram viewer
     * @param {string} containerId - ID of container element
     */
    initialize(containerId) {
      this.container = document.getElementById(containerId);
      if (!this.container) {
        console.error('Diagram container not found:', containerId);
        return;
      }

      this.setupEventListeners();
    }

    /**
     * Load and display a diagram
     * @param {string} diagramId - ID of diagram to load
     */
    loadDiagram(diagramId) {
      if (!window.modelData || !window.modelData.diagrams) {
        console.error('Model data not available');
        return;
      }

      const diagram = window.modelData.diagrams[diagramId];
      if (!diagram) {
        console.error('Diagram not found:', diagramId);
        return;
      }

      this.currentDiagram = diagram;

      // Fetch SVG content
      fetch(diagram.svgPath)
        .then(response => {
          if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
          }
          return response.text();
        })
        .then(svg => this.renderDiagram(svg, diagram))
        .catch(error => this.handleError(error, diagram));
    }

    /**
     * Render SVG diagram in container
     * @param {string} svgContent - SVG markup
     * @param {Object} metadata - Diagram metadata
     */
    renderDiagram(svgContent, metadata) {
      if (!this.container) return;

      // Clear container
      this.container.innerHTML = '';

      // Create diagram wrapper
      const wrapper = document.createElement('div');
      wrapper.className = 'diagram-wrapper';
      wrapper.innerHTML = svgContent;

      // Get SVG element
      this.svgElement = wrapper.querySelector('svg');
      if (!this.svgElement) {
        this.handleError(new Error('Invalid SVG content'), metadata);
        return;
      }

      // Reset transform
      this.resetTransform();

      // Add to container
      this.container.appendChild(wrapper);

      // Update metadata display
      this.updateMetadata(metadata);

      // Enable interactivity if SVG is loaded
      this.enableInteractivity();

      // Dispatch event
      this.dispatchEvent('diagramLoaded', { diagram: metadata });
    }

    /**
     * Update metadata display
     * @param {Object} metadata - Diagram metadata
     */
    updateMetadata(metadata) {
      const metadataEl = document.getElementById('diagram-metadata');
      if (!metadataEl) return;

      metadataEl.innerHTML = `
        <div class="metadata-item">
          <span class="metadata-label">Type:</span>
          <span class="metadata-value">${this.escapeHtml(metadata.type || 'Unknown')}</span>
        </div>
        <div class="metadata-item">
          <span class="metadata-label">Objects:</span>
          <span class="metadata-value">${metadata.objects || 0}</span>
        </div>
        <div class="metadata-item">
          <span class="metadata-label">Connectors:</span>
          <span class="metadata-value">${metadata.links || 0}</span>
        </div>
      `;
    }

    /**
     * Handle diagram loading errors
     * @param {Error} error - Error object
     * @param {Object} metadata - Diagram metadata
     */
    handleError(error, metadata) {
      console.error('Error loading diagram:', error);

      if (!this.container) return;

      this.container.innerHTML = `
        <div class="diagram-error">
          <h3>Failed to load diagram</h3>
          <p>${this.escapeHtml(metadata?.name || 'Unknown diagram')}</p>
          <p class="error-message">${this.escapeHtml(error.message)}</p>
          <button onclick="diagramViewer.loadDiagram('${metadata?.id}')">Retry</button>
        </div>
      `;
    }

    /**
     * Enable interactive features
     */
    enableInteractivity() {
      if (!this.svgElement) return;

      // Zoom with mouse wheel
      this.container.addEventListener('wheel', (e) => {
        e.preventDefault();
        const delta = e.deltaY > 0 ? 0.9 : 1.1;
        this.zoom(delta);
      });

      // Pan with mouse drag
      this.container.addEventListener('mousedown', (e) => {
        if (e.button === 0) { // Left button
          this.startPan(e);
        }
      });

      document.addEventListener('mousemove', (e) => {
        if (this.isPanning) {
          this.pan(e);
        }
      });

      document.addEventListener('mouseup', () => {
        this.endPan();
      });
    }

    /**
     * Setup event listeners for controls
     */
    setupEventListeners() {
      // Zoom in button
      const zoomInBtn = document.getElementById('diagram-zoom-in');
      if (zoomInBtn) {
        zoomInBtn.addEventListener('click', () => this.zoom(1.2));
      }

      // Zoom out button
      const zoomOutBtn = document.getElementById('diagram-zoom-out');
      if (zoomOutBtn) {
        zoomOutBtn.addEventListener('click', () => this.zoom(0.8));
      }

      // Reset button
      const resetBtn = document.getElementById('diagram-reset');
      if (resetBtn) {
        resetBtn.addEventListener('click', () => this.reset());
      }

      // Download button
      const downloadBtn = document.getElementById('diagram-download');
      if (downloadBtn) {
        downloadBtn.addEventListener('click', () => this.download());
      }
    }

    /**
     * Zoom diagram
     * @param {number} factor - Zoom factor
     */
    zoom(factor) {
      this.scale *= factor;
      this.scale = Math.max(0.1, Math.min(5.0, this.scale)); // Clamp between 0.1 and 5.0
      this.applyTransform();
    }

    /**
     * Start panning
     * @param {MouseEvent} e - Mouse event
     */
    startPan(e) {
      this.isPanning = true;
      this.startX = e.clientX - this.panX;
      this.startY = e.clientY - this.panY;
      this.container.style.cursor = 'grabbing';
    }

    /**
     * Pan diagram
     * @param {MouseEvent} e - Mouse event
     */
    pan(e) {
      if (!this.isPanning) return;
      this.panX = e.clientX - this.startX;
      this.panY = e.clientY - this.startY;
      this.applyTransform();
    }

    /**
     * End panning
     */
    endPan() {
      this.isPanning = false;
      this.container.style.cursor = 'grab';
    }

    /**
     * Apply transform to SVG
     */
    applyTransform() {
      if (!this.svgElement) return;

      const wrapper = this.svgElement.parentElement;
      if (!wrapper) return;

      wrapper.style.transform = `translate(${this.panX}px, ${this.panY}px) scale(${this.scale})`;
      wrapper.style.transformOrigin = 'center';
    }

    /**
     * Reset transform
     */
    resetTransform() {
      this.scale = 1.0;
      this.panX = 0;
      this.panY = 0;
      this.applyTransform();
    }

    /**
     * Reset view
     */
    reset() {
      this.resetTransform();
    }

    /**
     * Download current diagram
     */
    download() {
      if (!this.currentDiagram || !this.svgElement) return;

      const svgData = new XMLSerializer().serializeToString(this.svgElement);
      const blob = new Blob([svgData], { type: 'image/svg+xml' });
      const url = URL.createObjectURL(blob);

      const link = document.createElement('a');
      link.href = url;
      link.download = `${this.sanitizeFilename(this.currentDiagram.name)}.svg`;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);

      URL.revokeObjectURL(url);
    }

    /**
     * Sanitize filename
     * @param {string} name - Original name
     * @returns {string} Sanitized filename
     */
    sanitizeFilename(name) {
      return name.replace(/[^a-zA-Z0-9_-]/g, '_');
    }

    /**
     * Escape HTML
     * @param {string} str - String to escape
     * @returns {string} Escaped string
     */
    escapeHtml(str) {
      const div = document.createElement('div');
      div.textContent = str;
      return div.innerHTML;
    }

    /**
     * Dispatch custom event
     * @param {string} eventName - Event name
     * @param {Object} detail - Event detail
     */
    dispatchEvent(eventName, detail) {
      const event = new CustomEvent(eventName, { detail });
      window.dispatchEvent(event);
    }
  }

  // Create global instance
  window.diagramViewer = new DiagramViewer();

  // Initialize when DOM is ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
      window.diagramViewer.initialize('diagram-container');
    });
  } else {
    window.diagramViewer.initialize('diagram-container');
  }

})(window);
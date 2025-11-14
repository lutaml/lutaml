// Utility Functions

// Debounce function for search input
function debounce(func, wait) {
  let timeout;
  return function executedFunction(...args) {
    const later = () => {
      clearTimeout(timeout);
      func(...args);
    };
    clearTimeout(timeout);
    timeout = setTimeout(later, wait);
  };
}

// Format cardinality for display
function formatCardinality(cardinality) {
  if (!cardinality) return '';

  const min = cardinality.min !== undefined ? cardinality.min : '0';
  const max = cardinality.max !== undefined ? cardinality.max : '*';

  return `${min}..${max}`;
}

// Escape HTML to prevent XSS
function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

// Truncate text with ellipsis
function truncate(text, maxLength) {
  if (!text || text.length <= maxLength) return text;
  return text.slice(0, maxLength) + '...';
}

// Deep clone object
function deepClone(obj) {
  return JSON.parse(JSON.stringify(obj));
}

// Check if element is in viewport
function isInViewport(element) {
  const rect = element.getBoundingClientRect();
  return (
    rect.top >= 0 &&
    rect.left >= 0 &&
    rect.bottom <= (window.innerHeight || document.documentElement.clientHeight) &&
    rect.right <= (window.innerWidth || document.documentElement.clientWidth)
  );
}

// Smooth scroll to element
function scrollToElement(element, offset = 0) {
  const elementPosition = element.getBoundingClientRect().top;
  const offsetPosition = elementPosition + window.pageYOffset - offset;

  window.scrollTo({
    top: offsetPosition,
    behavior: 'smooth'
  });
}

// Format file size
function formatBytes(bytes, decimals = 2) {
  if (bytes === 0) return '0 Bytes';

  const k = 1024;
  const dm = decimals < 0 ? 0 : decimals;
  const sizes = ['Bytes', 'KB', 'MB', 'GB'];

  const i = Math.floor(Math.log(bytes) / Math.log(k));

  return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + ' ' + sizes[i];
}

// Get icon for element type
function getTypeIcon(type) {
  const icons = {
    class: 'C',
    datatype: 'D',
    enum: 'E',
    interface: 'I',
    attribute: 'A',
    association: '╱',
    package: '📦',
    operation: 'M'
  };
  return icons[type.toLowerCase()] || '?';
}

// Export utilities
window.UMLUtils = {
  debounce,
  formatCardinality,
  escapeHtml,
  truncate,
  deepClone,
  isInViewport,
  scrollToElement,
  formatBytes,
  getTypeIcon
};
// UML Repository Explorer - Client-side JavaScript

// State management
const state = {
  currentPackage: null,
  currentClass: null,
  packageTree: null,
  statistics: null
};

// Initialize the application
document.addEventListener('DOMContentLoaded', () => {
  loadStatistics();
  loadPackageTree();
  setupEventListeners();
});

// Setup event listeners
function setupEventListeners() {
  const searchBtn = document.getElementById('search-btn');
  const searchInput = document.getElementById('search-input');

  searchBtn.addEventListener('click', performSearch);
  searchInput.addEventListener('keypress', (e) => {
    if (e.key === 'Enter') performSearch();
  });
}

// Load statistics
async function loadStatistics() {
  try {
    const response = await fetch('/api/statistics');
    const stats = await response.json();
    state.statistics = stats;
    displayStatistics(stats);
  } catch (error) {
    console.error('Failed to load statistics:', error);
  }
}

// Display statistics
function displayStatistics(stats) {
  const container = document.getElementById('stats-container');
  container.innerHTML = `
    <div class="stats-grid">
      <div class="stat-card">
        <h3>${stats.total_packages || 0}</h3>
        <p>Packages</p>
      </div>
      <div class="stat-card">
        <h3>${stats.total_classes || 0}</h3>
        <p>Classes</p>
      </div>
      <div class="stat-card">
        <h3>${stats.total_associations || 0}</h3>
        <p>Associations</p>
      </div>
      <div class="stat-card">
        <h3>${stats.total_diagrams || 0}</h3>
        <p>Diagrams</p>
      </div>
    </div>
  `;
}

// Load package tree
async function loadPackageTree() {
  try {
    const response = await fetch('/api/packages/tree');
    const data = await response.json();
    state.packageTree = data.tree;
    displayPackageTree(data.tree);
  } catch (error) {
    console.error('Failed to load package tree:', error);
  }
}

// Display package tree
function displayPackageTree(tree) {
  const container = document.getElementById('package-tree');
  if (!tree) {
    container.innerHTML = '<p class="error">Failed to load package tree</p>';
    return;
  }
  container.innerHTML = renderTreeNode(tree);
}

// Render tree node recursively
function renderTreeNode(node, depth = 0) {
  const hasChildren = node.children && node.children.length > 0;
  const indent = depth * 15;

  let html = `
    <div class="tree-node" style="margin-left: ${indent}px">
      ${hasChildren ? '<span class="expand-icon" onclick="toggleNode(this)">▶</span>' : '<span class="no-icon"></span>'}
      <span class="package-link" onclick="loadPackage('${node.path}')">${node.name}</span>
      ${node.classes_count > 0 ? `<span class="count">(${node.classes_count})</span>` : ''}
    </div>
  `;

  if (hasChildren) {
    html += '<div class="tree-children" style="display: none;">';
    node.children.forEach(child => {
      html += renderTreeNode(child, depth + 1);
    });
    html += '</div>';
  }

  return html;
}

// Toggle tree node
function toggleNode(icon) {
  const children = icon.parentElement.nextElementSibling;
  if (children && children.classList.contains('tree-children')) {
    const isExpanded = children.style.display !== 'none';
    children.style.display = isExpanded ? 'none' : 'block';
    icon.textContent = isExpanded ? '▶' : '▼';
  }
}

// Load package details
async function loadPackage(path) {
  try {
    const encodedPath = encodePath(path);
    const response = await fetch(`/api/packages/${encodedPath}`);
    const packageData = await response.json();

    state.currentPackage = packageData;
    state.currentClass = null;

    updateBreadcrumb(path);
    displayPackageDetails(packageData);
  } catch (error) {
    console.error('Failed to load package:', error);
    showError('Failed to load package details');
  }
}

// Load class details
async function loadClass(qname) {
  try {
    const encodedQname = encodePath(qname);
    const response = await fetch(`/api/classes/${encodedQname}`);
    const classData = await response.json();

    state.currentClass = classData;

    updateBreadcrumb(qname);
    displayClassDetails(classData);
  } catch (error) {
    console.error('Failed to load class:', error);
    showError('Failed to load class details');
  }
}

// Display package details
function displayPackageDetails(pkg) {
  const detailsPane = document.getElementById('details-pane');

  let html = `
    <div class="package-details">
      <h2>Package: ${pkg.name}</h2>
      <p class="qualified-path"><strong>Path:</strong> <code>${pkg.path}</code></p>
      ${pkg.definition ? `<div class="description">${pkg.definition}</div>` : ''}

      ${renderSubPackages(pkg.packages)}
      ${renderPackageClasses(pkg.classes)}
      ${renderPackageDiagrams(pkg.diagrams)}
    </div>
  `;

  detailsPane.innerHTML = html;
}

// Render sub-packages
function renderSubPackages(packages) {
  if (!packages || packages.length === 0) return '';

  let html = '<h3>Sub-packages</h3><ul class="package-list">';
  packages.forEach(pkg => {
    html += `<li><a href="#" onclick="loadPackage('${pkg.path}'); return false;">${pkg.name}</a></li>`;
  });
  html += '</ul>';
  return html;
}

// Render package classes
function renderPackageClasses(classes) {
  if (!classes || classes.length === 0) return '<p>No classes in this package.</p>';

  let html = '<h3>Classes</h3><table class="classes-table">';
  html += '<thead><tr><th>Name</th><th>Type</th><th>Stereotypes</th><th>Attributes</th></tr></thead><tbody>';

  classes.forEach(klass => {
    html += `
      <tr>
        <td><a href="#" onclick="loadClass('${klass.qualified_name}'); return false;">${klass.name}</a></td>
        <td>${klass.type}</td>
        <td>${klass.stereotypes.join(', ')}</td>
        <td>${klass.attributes_count}</td>
      </tr>
    `;
  });

  html += '</tbody></table>';
  return html;
}

// Render package diagrams
function renderPackageDiagrams(diagrams) {
  if (!diagrams || diagrams.length === 0) return '';

  let html = '<h3>Diagrams</h3><ul class="diagram-list">';
  diagrams.forEach(diagram => {
    html += `<li><strong>${diagram.name}</strong> (${diagram.type})</li>`;
  });
  html += '</ul>';
  return html;
}

// Display class details
function displayClassDetails(klass) {
  const detailsPane = document.getElementById('details-pane');

  let html = `
    <div class="class-details">
      <h2>${klass.type}: ${klass.name}</h2>
      <p class="qualified-path"><strong>Qualified Name:</strong> <code>${klass.qualified_name}</code></p>
      <p><strong>Package:</strong> <a href="#" onclick="loadPackage('${klass.package}'); return false;">${klass.package}</a></p>
      ${klass.stereotypes.length > 0 ? `<p><strong>Stereotypes:</strong> ${klass.stereotypes.map(s => `<code>${s}</code>`).join(', ')}</p>` : ''}
      ${klass.definition ? `<div class="description">${klass.definition}</div>` : ''}

      ${renderInheritance(klass)}
      ${renderAttributes(klass.attributes)}
      ${renderOperations(klass.operations)}
      ${renderAssociations(klass.associations)}
      ${renderLiterals(klass.literals)}
    </div>
  `;

  detailsPane.innerHTML = html;
}

// Render inheritance information
function renderInheritance(klass) {
  if (!klass.parent && (!klass.children || klass.children.length === 0)) return '';

  let html = '<h3>Inheritance</h3>';

  if (klass.parent) {
    html += `<p><strong>Extends:</strong> <a href="#" onclick="loadClass('${klass.parent.qualified_name}'); return false;">${klass.parent.name}</a></p>`;
  }

  if (klass.children && klass.children.length > 0) {
    html += '<p><strong>Extended by:</strong></p><ul>';
    klass.children.forEach(child => {
      html += `<li><a href="#" onclick="loadClass('${child.qualified_name}'); return false;">${child.name}</a></li>`;
    });
    html += '</ul>';
  }

  return html;
}

// Render attributes
function renderAttributes(attributes) {
  if (!attributes || attributes.length === 0) return '';

  let html = '<h3>Attributes</h3><table class="attributes-table">';
  html += '<thead><tr><th>Name</th><th>Type</th><th>Visibility</th><th>Cardinality</th></tr></thead><tbody>';

  attributes.forEach(attr => {
    const cardinality = attr.cardinality ? `${attr.cardinality.min}..${attr.cardinality.max}` : '';
    html += `
      <tr>
        <td>${attr.name}</td>
        <td><code>${attr.type || ''}</code></td>
        <td>${attr.visibility || ''}</td>
        <td>${cardinality}</td>
      </tr>
    `;
  });

  html += '</tbody></table>';
  return html;
}

// Render operations
function renderOperations(operations) {
  if (!operations || operations.length === 0) return '';

  let html = '<h3>Operations</h3><table class="operations-table">';
  html += '<thead><tr><th>Name</th><th>Return Type</th><th>Visibility</th></tr></thead><tbody>';

  operations.forEach(op => {
    html += `
      <tr>
        <td>${op.name}</td>
        <td><code>${op.return_type || 'void'}</code></td>
        <td>${op.visibility || ''}</td>
      </tr>
    `;
  });

  html += '</tbody></table>';
  return html;
}

// Render associations
function renderAssociations(associations) {
  if (!associations || associations.length === 0) return '';

  let html = '<h3>Associations</h3><table class="associations-table">';
  html += '<thead><tr><th>Name</th><th>Target</th><th>Cardinality</th><th>Navigable</th><th>Aggregation</th></tr></thead><tbody>';

  associations.forEach(assoc => {
    if (!assoc || !assoc.target) return;
    const cardinality = assoc.cardinality ? `${assoc.cardinality.min}..${assoc.cardinality.max}` : '';
    html += `
      <tr>
        <td>${assoc.name || ''}</td>
        <td><a href="#" onclick="loadClass('${assoc.target.qualified_name}'); return false;">${assoc.target.name}</a></td>
        <td>${cardinality}</td>
        <td>${assoc.navigable ? 'Yes' : 'No'}</td>
        <td>${assoc.aggregation || ''}</td>
      </tr>
    `;
  });

  html += '</tbody></table>';
  return html;
}

// Render enum literals
function renderLiterals(literals) {
  if (!literals || literals.length === 0) return '';

  let html = '<h3>Literals</h3><ul class="literals-list">';
  literals.forEach(literal => {
    html += `<li><code>${literal.name}</code>${literal.definition ? `: ${literal.definition}` : ''}</li>`;
  });
  html += '</ul>';
  return html;
}

// Update breadcrumb navigation
function updateBreadcrumb(path) {
  const breadcrumb = document.getElementById('breadcrumb');
  const parts = path.split('::');

  let html = '<a href="#" onclick="showWelcome(); return false;">Home</a>';
  let currentPath = '';

  parts.forEach((part, index) => {
    currentPath += (currentPath ? '::' : '') + part;
    if (index === parts.length - 1) {
      html += ` / <span>${part}</span>`;
    } else {
      html += ` / <a href="#" onclick="loadPackage('${currentPath}'); return false;">${part}</a>`;
    }
  });

  breadcrumb.innerHTML = html;
}

// Show welcome screen
function showWelcome() {
  const detailsPane = document.getElementById('details-pane');
  detailsPane.innerHTML = `
    <div class="welcome">
      <h2>Welcome to UML Repository Explorer</h2>
      <p>Select a package or class from the sidebar to view details.</p>
      <div id="stats-container"></div>
    </div>
  `;
  displayStatistics(state.statistics);
  document.getElementById('breadcrumb').innerHTML = '';
}

// Perform search
async function performSearch() {
  const query = document.getElementById('search-input').value.trim();
  if (!query) return;

  try {
    const response = await fetch(`/api/search?q=${encodeURIComponent(query)}`);
    const data = await response.json();
    displaySearchResults(data);
  } catch (error) {
    console.error('Search failed:', error);
    showError('Search failed');
  }
}

// Display search results
function displaySearchResults(data) {
  const detailsPane = document.getElementById('details-pane');
  const breadcrumb = document.getElementById('breadcrumb');

  breadcrumb.innerHTML = `<span>Search results for "${data.query}"</span>`;

  let html = `<div class="search-results"><h2>Search Results for "${data.query}"</h2>`;

  const results = data.results;
  let totalResults = 0;

  if (results.class && results.class.length > 0) {
    totalResults += results.class.length;
    html += '<h3>Classes</h3><ul>';
    results.class.forEach(item => {
      html += `<li><a href="#" onclick="loadClass('${item.qualified_name}'); return false;">${item.name}</a> <span class="type">(${item.class_type})</span></li>`;
    });
    html += '</ul>';
  }

  if (results.attribute && results.attribute.length > 0) {
    totalResults += results.attribute.length;
    html += '<h3>Attributes</h3><ul>';
    results.attribute.forEach(item => {
      html += `<li><code>${item.name}</code> in <a href="#" onclick="loadClass('${item.owner_qualified_name}'); return false;">${item.owner_name}</a></li>`;
    });
    html += '</ul>';
  }

  if (results.association && results.association.length > 0) {
    totalResults += results.association.length;
    html += '<h3>Associations</h3><ul>';
    results.association.forEach(item => {
      html += `<li>${item.name || 'Unnamed'}</li>`;
    });
    html += '</ul>';
  }

  if (totalResults === 0) {
    html += '<p>No results found.</p>';
  }

  html += '</div>';
  detailsPane.innerHTML = html;
}

// Show error message
function showError(message) {
  const detailsPane = document.getElementById('details-pane');
  detailsPane.innerHTML = `<div class="error"><p>${message}</p></div>`;
}

// Encode path for URL
function encodePath(path) {
  return encodeURIComponent(path.replace(/::/g, '_'));
}
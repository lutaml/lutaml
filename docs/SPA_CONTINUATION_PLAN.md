# SPA Template/UI Continuation Plan

## Current Status
- ✅ QEA Parser: 100% complete (16/16 issues fixed)
- ✅ SPA Data Layer: Complete (stereotypes, diagrams, tree structure)
- 🔄 SPA Template/UI: 70% complete (templates updated, interactivity needs work)

## Remaining Work

### High Priority

#### 1. Fix Navigation Expand/Collapse Reactivity
**Issue**: Tree expand icons not responsive to clicks
**Location**: `templates/static_site/assets/scripts/ui/sidebar.js`
**Solution**: The renderTree component needs proper reactivity. Current onclick calls `rebuildTree()` but Alpine's watcher needs to detect the change.

**Fix**:
```javascript
// In sidebar.js line 105, change:
html += `<button onclick="Alpine.store('app').toggleNode('${node.id}'); this.closest('[x-data]').__x.$data.rebuildTree();" ...`

// To use a custom event:
html += `<button onclick="window.dispatchEvent(new CustomEvent('tree-toggle', {detail: '${node.id}'}));" ...`

// Then in init():
window.addEventListener('tree-toggle', (e) => {
  Alpine.store('app').toggleNode(e.detail);
  this.rebuildTree();
});
```

#### 2. Make Type Column Actually Clickable
**Issue**: Templates have conditional logic but functions not in scope
**Location**: `templates/static_site/components/class_details.liquid` line 101

**Current**:
```liquid
<td x-data="{ 
  isBasic: isUmlBasicType(attr.type),
  classId: findClassByName(attr.type)
}">
```

**Fix**: Functions need to be called with `this.` or moved to computed properties:
```liquid
<td x-data="{ 
  isBasic: $root.isUmlBasicType(attr.type),
  classId: $root.findClassByName(attr.type)
}">
```

Or add to app() component in state.js as methods.

#### 3. Handle Unnamed Classes
**Issue**: 位置図 has 1 unnamed class (empty name), shows as "1" in nav
**Solution**: 
- Filter out unnamed classes from classCount in tree
- Or show diagram list when clicking on diagram-only packages

**Fix in**: `data_transformer.rb` line 121:
```ruby
classCount: package.classes&.reject { |c| c.name.nil? || c.name.empty? }&.size || 0
```

### Medium Priority

#### 4. Add Package Name to Class Details
**Location**: `templates/static_site/components/class_details.liquid`

**Add after line 12 (before stereotypes)**:
```liquid
<dt>Package</dt>
<dd>
  <button
    class="link-button"
    @click="selectPackage(cls.package)"
    x-text="data.packages[cls.package] && data.packages[cls.package].name"
  ></button>
</dd>
```

#### 5. Auto-Expand to Selected Class
**Location**: `templates/static_site/assets/scripts/core/state.js`

**Add to selectClass method**:
```javascript
selectClass(classId) {
  const cls = this.data.classes[classId];
  if (!cls) return;
  
  // Auto-expand package hierarchy
  this.expandPackageHierarchy(cls.package);
  
  this.currentClass = classId;
  // ... rest of method
},

expandPackageHierarchy(packageId) {
  if (!packageId) return;
  
  let pkg = this.data.packages[packageId];
  while (pkg) {
    this.expandedNodes.add(pkg.id);
    pkg = pkg.parent ? this.data.packages[pkg.parent] : null;
  }
}
```

#### 6. Entity Type Icons
**Location**: `templates/static_site/assets/scripts/ui/sidebar.js`

**In buildClassNode**, replace the generic class icon with type-specific:
```javascript
const iconMap = {
  'Class': '<rect x="3" y="3" width="18" height="18" rx="2" ry="2"></rect>',
  'DataType': `<circle cx="12" cy="12" r="9"></circle>`,
  'Enum': '<polygon points="12 2 2 7 2 17 12 22 22 17 22 7"></polygon>',
  'Interface': '<circle cx="12" cy="12" r="9"></circle><circle cx="12" cy="12" r="5"></circle>'
};
const icon = iconMap[cls.type] || iconMap['Class'];
html += `<svg class="class-icon" ...>${icon}</svg>`;
```

### Low Priority

#### 7. Fix Search Box Disappearing
**Investigation needed**: Check `templates/static_site/assets/scripts/ui/search.js`
- Ensure search overlay doesn't interfere with search input
- Verify click-outside handler doesn't hide search when it shouldn't

#### 8. Show Diagram List for Diagram-Only Packages
**When clicking on package with 0 classes but N diagrams**:
- Show "This package contains N diagrams:" message
- List diagram names (non-clickable for now, or add diagram detail view)

#### 9. Breadcrumb Full Qualified Path
**Location**: `templates/static_site/assets/scripts/core/state.js`

**Currently**: Shows last segment only
**Fix**: Show full path with `::` separators in breadcrumb display

## Testing Checklist

### After Each Fix
1. Regenerate SPA: `bundle exec lutaml uml build-spa *.lur -o test.html`
2. Open in browser
3. Test specific functionality:
   - [ ] Navigation expand/collapse works
   - [ ] Type columns are clickable
   - [ ] Clicking type navigates to class
   - [ ] UML basic types show in blue
   - [ ] Unresolved types show red triangle
   - [ ] Search box stays visible
   - [ ] Classes shown in nav tree
   - [ ] Diagrams listed in packages

### Full Integration Test
1. Parse QEA: `bundle exec ruby test_qea_fixes.rb` → All passing
2. Build LUR: `bundle exec lutaml uml build *.qea -o *.lur`
3. Build SPA: `bundle exec lutaml uml build-spa *.lur -o *.html`
4. Open in browser and test all features

## Priority Order

1. **P0 (Critical)**: Navigation expand/collapse
2. **P0 (Critical)**: Type clickability
3. **P1 (High)**: Unnamed class handling
4. **P1 (High)**: Package name in class details
5. **P2 (Medium)**: Auto-expand to selected
6. **P2 (Medium)**: Entity type icons
7. **P3 (Low)**: Search box, breadcrumb polish

## Success Criteria

- [ ] All P0-P1 items complete
- [ ] Browser testing confirms interactivity
- [ ] No console errors
- [ ] Navigation fully functional
- [ ] Type resolution working
- [ ] All data displayed correctly

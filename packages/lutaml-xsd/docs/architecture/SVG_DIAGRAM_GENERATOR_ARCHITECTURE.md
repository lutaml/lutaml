# SVG Diagram Generator - Object-Oriented Architecture Design

## Executive Summary

This document describes the comprehensive, fully MECE (Mutually Exclusive, Collectively Exhaustive) object-oriented architecture for SVG diagram generation in lutaml-xsd. The architecture follows SOLID principles, enables external configuration, and provides clear extension points for future enhancements.

**Key Features**: A modular architecture with 15+ focused classes, external YAML configuration, pluggable renderers and layouts, and comprehensive test coverage.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Configuration System](#configuration-system)
3. [Class Hierarchy and Responsibilities](#class-hierarchy-and-responsibilities)
4. [Component Interaction Patterns](#component-interaction-patterns)
5. [Extension Points](#extension-points)
6. [Test Strategy](#test-strategy)
7. [Implementation Status](#implementation-status)

---

## 1. Architecture Overview

### Architectural Principles

The architecture follows these core principles:

1. **Single Responsibility** - Each class has ONE clearly defined purpose
2. **Open/Closed** - Open for extension, closed for modification
3. **Dependency Injection** - All dependencies passed via constructors
4. **External Configuration** - All styling and behavior controlled via YAML
5. **Strategy Pattern** - Pluggable algorithms for layouts and renderers
6. **Factory Pattern** - Create appropriate renderers and layouts dynamically
7. **Immutable Configuration** - Configuration objects are read-only value objects
8. **Clear Contracts** - Abstract base classes define interfaces

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    DiagramGenerator                          │
│                  (Main Orchestrator)                         │
│  • Coordinates diagram generation                           │
│  • Delegates to specialized components                      │
└────────────┬────────────────────────────────────┬───────────┘
             │                                    │
    ┌────────▼────────┐                ┌─────────▼──────────┐
    │ StyleConfig     │                │  LayoutEngine      │
    │ (Configuration) │                │  (Strategy)        │
    └────────┬────────┘                └─────────┬──────────┘
             │                                    │
    ┌────────▼────────────────┐          ┌───────▼────────┐
    │ • ColorScheme           │          │ • TreeLayout   │
    │ • Dimensions            │          │ • VerticalLyt  │
    │ • Effects               │          │ • HorizontalLyt│
    │ • ConnectorStyles       │          └────────────────┘
    └─────────────────────────┘
             │
    ┌────────▼────────────────────────────────────────────┐
    │           Component Renderers                        │
    │           (Strategy Pattern)                         │
    ├──────────────────────────────────────────────────────┤
    │ • ElementRenderer    • TypeRenderer                  │
    │ • AttributeRenderer  • GroupRenderer                 │
    └──────────────────────────────────────────────────────┘
             │
    ┌────────▼────────────────────────────────────────────┐
    │           Connector Renderers                        │
    │           (Strategy Pattern)                         │
    ├──────────────────────────────────────────────────────┤
    │ • InheritanceConnector  • ContainmentConnector       │
    │ • ReferenceConnector                                 │
    └──────────────────────────────────────────────────────┘
             │
    ┌────────▼────────────────────────────────────────────┐
    │           SVG Document Assembly                      │
    ├──────────────────────────────────────────────────────┤
    │ • DefsBuilder        • DocumentBuilder               │
    └──────────────────────────────────────────────────────┘
```

### Module Organization

```
lib/lutaml/xsd/spa/svg/
├── diagram_generator.rb          # Main orchestrator
├── style_configuration.rb        # Configuration loader & holder
├── component_renderer.rb         # Abstract base for renderers
├── connector_renderer.rb         # Abstract base for connectors
├── layout_engine.rb              # Abstract base for layouts
├── defs_builder.rb               # SVG <defs> builder
├── document_builder.rb           # SVG document assembler
├── value_objects.rb              # Immutable value objects
├── renderers/
│   ├── element_renderer.rb
│   ├── type_renderer.rb
│   ├── attribute_renderer.rb
│   └── group_renderer.rb
├── connectors/
│   ├── inheritance_connector.rb
│   ├── containment_connector.rb
│   └── reference_connector.rb
└── layouts/
    ├── tree_layout.rb
    ├── vertical_layout.rb
    └── horizontal_layout.rb
```

---

## 3. Configuration System

### Configuration File Locations

```
config/spa/
├── svg_styles.yml              # Visual styling configuration
└── svg_component_rules.yml     # Component behavior rules
```

### Configuration File: `config/spa/svg_styles.yml`

```yaml
# SVG Diagram Visual Styles Configuration
# All colors, dimensions, and visual effects

colors:
  # Component colors with gradients
  element:
    base: "#0066CC"
    gradient_start: "#0077DD"
    gradient_end: "#0055BB"
    text: "#FFFFFF"

  type:
    base: "#006600"
    gradient_start: "#007700"
    gradient_end: "#005500"
    text: "#FFFFFF"

  attribute:
    base: "#993333"
    gradient_start: "#AA4444"
    gradient_end: "#882222"
    text: "#FFFFFF"

  group:
    base: "#FFCC00"
    gradient_start: "#FFDD11"
    gradient_end: "#EEBB00"
    text: "#000000"

  # UI colors
  ui:
    text: "#000000"
    border: "#333333"
    shadow: "rgba(0,0,0,0.3)"
    background: "#FFFFFF"

  # State indicators
  indicators:
    required: "#FF0000"
    optional: "#888888"
    abstract: "#9900CC"

dimensions:
  box:
    width: 120
    height: 30
    corner_radius: 5
    border_width: 2

  spacing:
    horizontal: 20
    vertical: 15
    indent: 40
    padding: 10

  text:
    offset_y: 20
    font_size: 14
    small_font_size: 10
    line_height: 1.2

effects:
  shadow:
    enabled: true
    blur: 2
    offset_x: 2
    offset_y: 2
    opacity: 0.3

  gradient:
    enabled: true
    direction: "vertical"  # or "horizontal", "radial"

  hover:
    enabled: true
    opacity: 0.9
    cursor: "pointer"

connectors:
  inheritance:
    type: "hollow_triangle"
    stroke_width: 2
    stroke_color: "#333333"
    fill_color: "#FFFFFF"
    arrow_size: 8
    style: "solid"

  containment:
    type: "solid_triangle"
    stroke_width: 2
    stroke_color: "#333333"
    fill_color: "#333333"
    arrow_size: 6
    style: "solid"

  reference:
    type: "hollow_triangle"
    stroke_width: 2
    stroke_color: "#333333"
    fill_color: "none"
    arrow_size: 6
    style: "dashed"
    dash_pattern: "5,5"

layout:
  default: "tree"  # or "vertical", "horizontal"
  tree:
    direction: "top_down"  # or "left_right", "bottom_up", "right_left"
    level_spacing: 60
    sibling_spacing: 20
  vertical:
    item_spacing: 15
    indent: 40
  horizontal:
    item_spacing: 20
    level_spacing: 80
```

### Configuration File: `config/spa/svg_component_rules.yml`

```yaml
# Component Rendering Rules
# Defines behavior and metadata for each component type

components:
  element:
    renderer_class: "ElementRenderer"
    icon:
      type: "text"
      content: "E"
      background: true
    features:
      show_cardinality: true
      show_namespace: true
      clickable: true
      link_pattern: "#/schemas/{schema_name}/elements/{element_slug}"
    indicators:
      - abstract
      - optional

  type:
    renderer_class: "TypeRenderer"
    icon:
      type: "text"
      content: "T"
      background: true
    features:
      show_base_type: true
      show_derivation: true
      clickable: true
      link_pattern: "#/schemas/{schema_name}/types/{type_slug}"
    indicators:
      - abstract

  attribute:
    renderer_class: "AttributeRenderer"
    icon:
      type: "text"
      content: "@"
      background: "circle"
    features:
      show_type: true
      show_default: true
      clickable: false
    indicators:
      - required
      - optional

  group:
    renderer_class: "GroupRenderer"
    icon: null
    features:
      show_type: true
      show_cardinality: true
      clickable: false
    indicators: []

indicators:
  abstract:
    text: "«abstract»"
    position: "top_right"
    offset_x: -5
    offset_y: 12
    font_size: 10
    font_style: "italic"
    color_key: "indicators.abstract"

  optional:
    text: "?"
    position: "top_right"
    offset_x: -5
    offset_y: 12
    font_size: 10
    font_style: "normal"
    color_key: "indicators.optional"

  required:
    text: "*"
    position: "top_right"
    offset_x: -5
    offset_y: 12
    font_size: 10
    font_style: "bold"
    color_key: "indicators.required"

text_formatting:
  label:
    truncate_at: 20
    truncate_indicator: "..."
  cardinality:
    format: "{min}..{max}"
    unbounded_symbol: "*"
  namespace:
    format: "{prefix}:{name}"
    show_prefix: true
    prefix_style: "italic"
```

---

## 4. Class Hierarchy and Responsibilities

### 4.1 Core Coordinator

#### `Lutaml::Xsd::Spa::Svg::DiagramGenerator`

**Purpose**: Main orchestrator that coordinates the entire diagram generation process.

**File**: `lib/lutaml/xsd/spa/svg/diagram_generator.rb`

**Responsibilities**:
- Load or accept configuration
- Coordinate layout calculation
- Delegate rendering to appropriate renderers
- Assemble final SVG document
- Provide public API for diagram generation

**Dependencies**:
- `StyleConfiguration` - For visual styling
- `LayoutEngine` - For positioning calculation
- `DocumentBuilder` - For SVG assembly

**Public API**:
```ruby
class DiagramGenerator
  def initialize(schema_name, config = nil)
  def generate_element_diagram(element_data)
  def generate_type_diagram(type_data)
  def generate_custom_diagram(data, options = {})
end
```

**Example Usage**:
```ruby
generator = DiagramGenerator.new("my-schema")
svg = generator.generate_element_diagram(element_data)
```

---

### 4.2 Configuration Management

#### `Lutaml::Xsd::Spa::Svg::StyleConfiguration`

**Purpose**: Loads and provides access to all styling configuration from YAML files.

**File**: `lib/lutaml/xsd/spa/svg/style_configuration.rb`

**Responsibilities**:
- Load YAML configuration files
- Parse and validate configuration
- Provide immutable access to configuration sections
- Cache configuration for performance
- Provide sensible defaults if config missing

**Dependencies**:
- YAML standard library
- Value object classes (`ColorScheme`, `Dimensions`, etc.)

**Public API**:
```ruby
class StyleConfiguration
  def self.load(path = nil)
  def self.default_config_path
  def initialize(config_hash)

  attr_reader :colors      # Returns ColorScheme
  attr_reader :dimensions  # Returns Dimensions
  attr_reader :effects     # Returns Effects
  attr_reader :connectors  # Returns ConnectorStyles
  attr_reader :layout_type # Returns String
end
```

#### Value Object Classes

These are immutable objects that hold configuration data:

**`ColorScheme`** - Provides access to color configuration
```ruby
class ColorScheme
  def element_base
  def element_gradient_start
  def element_gradient_end
  def for_component(type)  # Returns all colors for component
  def indicator_color(name)
end
```

**`Dimensions`** - Provides access to size and spacing
```ruby
class Dimensions
  def box_width
  def box_height
  def box_corner_radius
  def spacing_horizontal
  def spacing_vertical
  def text_offset_y
end
```

**`Effects`** - Provides access to visual effects settings
```ruby
class Effects
  def shadow_enabled?
  def shadow_blur
  def gradient_enabled?
  def gradient_direction
  def hover_enabled?
end
```

**`ConnectorStyles`** - Provides access to connector styling
```ruby
class ConnectorStyles
  def for_type(connector_type)  # Returns connector config
  def inheritance
  def containment
  def reference
end
```

---

### 4.3 Component Rendering System

#### `Lutaml::Xsd::Spa::Svg::ComponentRenderer` (Abstract Base)

**Purpose**: Abstract base class defining the interface for all component renderers.

**File**: `lib/lutaml/xsd/spa/svg/component_renderer.rb`

**Responsibilities**:
- Define renderer interface
- Provide common helper methods
- Ensure consistent rendering patterns

**Public API**:
```ruby
class ComponentRenderer
  def initialize(config, schema_name)
  def render(component_data, position)  # Abstract - must implement

  protected
  def create_box(x, y, width, height, fill, options = {})
  def create_text(x, y, text, options = {})
  def create_link(href, content)
  def escape_xml(text)
  def apply_filter(element, filter_id)
end
```

#### `Lutaml::Xsd::Spa::Svg::Renderers::ElementRenderer`

**Purpose**: Renders XSD element boxes with all features.

**File**: `lib/lutaml/xsd/spa/svg/renderers/element_renderer.rb`

**Responsibilities**:
- Render element box with gradient
- Add element name label
- Show cardinality if applicable
- Show namespace prefix if applicable
- Add clickable link to element details
- Render indicators (abstract, optional)

**Rendering Algorithm**:
1. Calculate box dimensions from config
2. Create rect with gradient fill
3. Add drop shadow filter
4. Create clickable link wrapper
5. Render element name (center-aligned)
6. Render cardinality (bottom, small font)
7. Render indicators (top-right)

**Example Output**:
```svg
<g class="element-box" filter="url(#dropShadow)">
  <a href="#/schemas/test/elements/person">
    <rect x="20" y="20" width="120" height="30"
          fill="url(#elementGradient)" stroke="#333" stroke-width="2" rx="5"/>
    <text x="80" y="40" fill="white" font-size="14"
          text-anchor="middle">Person</text>
    <text x="115" y="32" fill="#888" font-size="10"
          text-anchor="end" font-style="italic">?</text>
  </a>
</g>
```

#### `Lutaml::Xsd::Spa::Svg::Renderers::TypeRenderer`

**Purpose**: Renders XSD complex type boxes.

**File**: `lib/lutaml/xsd/spa/svg/renderers/type_renderer.rb`

**Responsibilities**:
- Render type box with type-specific gradient
- Add type name label
- Show derivation method if applicable
- Add clickable link to type details
- Render abstract indicator if applicable

**Similar to ElementRenderer but with type-specific styling**

#### `Lutaml::Xsd::Spa::Svg::Renderers::AttributeRenderer`

**Purpose**: Renders XSD attribute boxes.

**File**: `lib/lutaml/xsd/spa/svg/renderers/attribute_renderer.rb`

**Responsibilities**:
- Render smaller attribute box
- Show @ symbol prefix
- Display attribute name
- Show type below name (small font)
- Show default value if present
- Render required/optional indicator

**Example Output**:
```svg
<g class="attribute-box" filter="url(#dropShadow)">
  <rect x="40" y="60" width="120" height="30"
        fill="url(#attributeGradient)" stroke="#333" stroke-width="1" rx="3"/>
  <text x="45" y="75" fill="white" font-size="12">@id</text>
  <text x="45" y="87" fill="white" font-size="10" opacity="0.8">string</text>
</g>
```

#### `Lutaml::Xsd::Spa::Svg::Renderers::GroupRenderer`

**Purpose**: Renders model group indicators (sequence, choice, all).

**File**: `lib/lutaml/xsd/spa/svg/renderers/group_renderer.rb`

**Responsibilities**:
- Render group type box (sequence/choice/all)
- Use distinct gradient
- Show group type label

---

### 4.4 Connector System

#### `Lutaml::Xsd::Spa::Svg::ConnectorRenderer` (Abstract Base)

**Purpose**: Abstract base for all connector types.

**File**: `lib/lutaml/xsd/spa/svg/connector_renderer.rb`

**Public API**:
```ruby
class ConnectorRenderer
  def initialize(config)
  def render(from_point, to_point, options = {})  # Abstract

  protected
  def create_line(x1, y1, x2, y2, options = {})
  def create_arrow(x, y, direction, style)
  def create_label(x, y, text)
end
```

#### `Lutaml::Xsd::Spa::Svg::Connectors::InheritanceConnector`

**Purpose**: Renders UML-style inheritance arrows (hollow triangle).

**File**: `lib/lutaml/xsd/spa/svg/connectors/inheritance_connector.rb`

**Visual**: Solid line with hollow triangle arrow pointing to parent.

**Example Output**:
```svg
<line x1="80" y1="50" x2="80" y2="80"
      stroke="#333" stroke-width="2"/>
<polygon points="80,80 72,70 88,70"
         fill="white" stroke="#333" stroke-width="2"/>
```

#### `Lutaml::Xsd::Spa::Svg::Connectors::ContainmentConnector`

**Purpose**: Renders containment arrows (solid triangle).

**File**: `lib/lutaml/xsd/spa/svg/connectors/containment_connector.rb`

**Visual**: Solid line with filled triangle arrow pointing to contained type.

#### `Lutaml::Xsd::Spa::Svg::Connectors::ReferenceConnector`

**Purpose**: Renders reference arrows (dashed hollow triangle).

**File**: `lib/lutaml/xsd/spa/svg/connectors/reference_connector.rb`

**Visual**: Dashed line with hollow triangle arrow.

---

### 4.5 Layout Engine

#### `Lutaml::Xsd::Spa::Svg::LayoutEngine` (Abstract Base)

**Purpose**: Abstract base for layout calculation strategies.

**File**: `lib/lutaml/xsd/spa/svg/layout_engine.rb`

**Public API**:
```ruby
class LayoutEngine
  def self.for(layout_type)  # Factory method
  def calculate(component_data, component_type)  # Abstract
end
```

#### `LayoutResult` Value Object

**Purpose**: Immutable object containing calculated layout.

```ruby
class LayoutResult
  attr_reader :nodes         # Array<LayoutNode>
  attr_reader :connections   # Array<ConnectionSpec>
  attr_reader :dimensions    # Hash {width:, height:}

  def initialize(nodes, connections, dimensions)
end
```

#### `LayoutNode` Value Object

**Purpose**: Represents position and size of one component.

```ruby
class LayoutNode
  attr_reader :component     # Component data hash
  attr_reader :position      # {x:, y:}
  attr_reader :size          # {width:, height:}
  attr_reader :level         # Nesting level (0-based)

  def initialize(component:, position:, size:, level: 0)
end
```

#### `Lutaml::Xsd::Spa::Svg::Layouts::TreeLayout`

**Purpose**: Calculates tree-based hierarchical layout.

**File**: `lib/lutaml/xsd/spa/svg/layouts/tree_layout.rb`

**Algorithm**:
1. Build tree structure from component data
2. Calculate level for each node (BFS)
3. Position nodes level by level
4. Center parent over children
5. Add appropriate spacing
6. Calculate total dimensions
7. Generate connections between nodes

**Output**: `LayoutResult` with all nodes positioned

#### `Lutaml::Xsd::Spa::Svg::Layouts::VerticalLayout`

**Purpose**: Simple top-to-bottom linear layout.

**File**: `lib/lutaml/xsd/spa/svg/layouts/vertical_layout.rb`

**Algorithm**:
1. Start at top (y=20)
2. Place each component below previous
3. Add vertical spacing between
4. Indent children
5. Calculate total height

#### `Lutaml::Xsd::Spa::Svg::Layouts::HorizontalLayout`

**Purpose**: Left-to-right layout (future enhancement).

**File**: `lib/lutaml/xsd/spa/svg/layouts/horizontal_layout.rb`

---

### 4.6 SVG Document Assembly

#### `Lutaml::Xsd::Spa::Svg::DefsBuilder`

**Purpose**: Builds SVG `<defs>` section with gradients, filters, and symbols.

**File**: `lib/lutaml/xsd/spa/svg/defs_builder.rb`

**Responsibilities**:
- Generate gradient definitions for all component types
- Generate filter definitions (shadows, etc.)
- Generate reusable symbols/icons
- Use configuration for all values

**Public API**:
```ruby
class DefsBuilder
  def initialize(config)
  def build

  private
  def build_gradients
  def build_filters
  def build_icons
end
```

**Example Output**:
```svg
<defs>
  <linearGradient id="elementGradient" x1="0%" y1="0%" x2="0%" y2="100%">
    <stop offset="0%" style="stop-color:#0077DD;stop-opacity:1" />
    <stop offset="100%" style="stop-color:#0055BB;stop-opacity:1" />
  </linearGradient>

  <filter id="dropShadow">
    <feGaussianBlur in="SourceAlpha" stdDeviation="2"/>
    <feOffset dx="2" dy="2"/>
    ...
  </filter>
</defs>
```

#### `Lutaml::Xsd::Spa::Svg::DocumentBuilder`

**Purpose**: Assembles the complete SVG document.

**File**: `lib/lutaml/xsd/spa/svg/document_builder.rb`

**Responsibilities**:
- Create SVG root element with namespace
- Add defs section
- Add CSS styles
- Combine all rendered components
- Set viewBox and dimensions

**Public API**:
```ruby
class DocumentBuilder
  def initialize(config)
  def build(components, dimensions)

  private
  def build_styles
  def build_svg_root(width, height)
end
```

---

## 5. Component Interaction Patterns

### 5.1 Diagram Generation Flow

```
User Call
    │
    ▼
DiagramGenerator.generate_element_diagram(data)
    │
    ├─► StyleConfiguration.load()
    │       └─► Parse YAML files
    │       └─► Create value objects
    │
    ├─► LayoutEngine.for(config.layout_type)
    │       └─► Factory creates TreeLayout
    │
    ├─► layout.calculate(data, :element)
    │       └─► Build tree structure
    │       └─► Calculate positions
    │       └─► Return LayoutResult
    │
    ├─► For each LayoutNode:
    │   │
    │   ├─► Select appropriate renderer
    │   │       └─► ElementRenderer for elements
    │   │       └─► TypeRenderer for types
    │   │       └─► AttributeRenderer for attributes
    │   │
    │   └─► renderer.render(node.component, node.position)
    │           └─► Return SVG string
    │
    ├─► For each Connection:
    │   │
    │   ├─► Select appropriate connector
    │   │       └─► InheritanceConnector for extends
    │   │       └─► ContainmentConnector for type refs
    │   │       └─► ReferenceConnector for refs
    │   │
    │   └─► connector.render(from, to)
    │           └─► Return SVG string
    │
    └─► DocumentBuilder.build(components, dimensions)
            ├─► DefsBuilder.build()
            ├─► Assemble components
            └─► Return complete SVG
```

### 5.2 Configuration Loading Flow

```
Application Start / First Use
    │
    ▼
StyleConfiguration.load()
    │
    ├─► Find config file
    │       └─► Use provided path
    │       └─► Or use default path
    │
    ├─► Load YAML
    │       └─► Parse svg_styles.yml
    │       └─► Parse svg_component_rules.yml
    │
    ├─► Create value objects
    │   │
    │   ├─► ColorScheme.new(colors_hash)
    │   ├─► Dimensions.new(dimensions_hash)
    │   ├─► Effects.new(effects_hash)
    │   └─► ConnectorStyles.new(connectors_hash)
    │
    ├─► Validate configuration
    │       └─► Check required keys
    │       └─► Validate value ranges
    │       └─► Provide defaults for missing
    │
    └─► Return StyleConfiguration instance
            └─► Cache for reuse
```

### 5.3 Renderer Selection Pattern

```ruby
def select_renderer(component_type config)
  case component_type
  when :element
    ElementRenderer.new(config, @schema_name)
  when :type
    TypeRenderer.new(config, @schema_name)
  when :attribute
    AttributeRenderer.new(config, @schema_name)
  when :group
    GroupRenderer.new(config, @schema_name)
  else
    raise ArgumentError, "Unknown component type: #{component_type}"
  end
end
```

### 5.4 Connector Selection Pattern

```ruby
def select_connector(connection_type, config)
  case connection_type
  when :inheritance, :extends
    InheritanceConnector.new(config.connectors.inheritance)
  when :containment, :type_ref
    ContainmentConnector.new(config.connectors.containment)
  when :reference, :ref
    ReferenceConnector.new(config.connectors.reference)
  else
    raise ArgumentError, "Unknown connector type: #{connection_type}"
  end
end
```

---

## 6. Extension Points

### 6.1 Adding New Renderers

To add support for a new component type (e.g., annotations):

1. **Create renderer class** inheriting from `ComponentRenderer`
2. **Implement `render()` method**
3. **Register in component rules YAML**
4. **Update renderer selection logic**

Example:
```ruby
# lib/lutaml/xsd/spa/svg/renderers/annotation_renderer.rb
module Lutaml::Xsd::Spa::Svg::Renderers
  class AnnotationRenderer < ComponentRenderer
    def render(annotation_data, position)
      # Render annotation as a note box
    end
  end
end
```

```yaml
# config/spa/svg_component_rules.yml
components:
  annotation:
    renderer_class: "AnnotationRenderer"
    icon:
      type: "text"
      content: "i"
    features:
      show_full_text: false
      max_length: 50
```

### 6.2 Adding New Layouts

To add a new layout algorithm (e.g., radial):

1. **Create layout class** inheriting from `LayoutEngine`
2. **Implement `calculate()` method**
3. **Return `LayoutResult`**
4. **Register in layout factory**

Example:
```ruby
# lib/lutaml/xsd/spa/svg/layouts/radial_layout.rb
module Lutaml::Xsd::Spa::Svg::Layouts
  class RadialLayout < LayoutEngine
    def calculate(component_data, component_type)
      # Calculate radial positions
      # Return LayoutResult
    end
  end
end
```

### 6.3 Adding New Connectors

To add a new connector type (e.g., bidirectional):

1. **Create connector class** inheriting from `ConnectorRenderer`
2. **Implement `render()` method**
3. **Define styling in YAML**

Example:
```ruby
# lib/lutaml/xsd/spa/svg/connectors/bidirectional_connector.rb
module Lutaml::Xsd::Spa::Svg::Connectors
  class BidirectionalConnector < ConnectorRenderer
    def render(from_point, to_point, options = {})
      # Render line with arrows at both ends
    end
  end
end
```

### 6.4 Customizing Styles

Users can customize appearance by:

1. **Copying default YAML files**
2. **Modifying colors, sizes, effects**
3. **Passing custom config path to generator**

Example:
```ruby
config = StyleConfiguration.load("custom/path/svg_styles.yml")
generator = DiagramGenerator.new("my-schema", config)
```

### 6.5 Plugin Architecture

For advanced customization, implement a plugin system:

```ruby
# lib/lutaml/xsd/spa/svg/plugin.rb
module Lutaml::Xsd::Spa::Svg
  class Plugin
    def self.register_renderer(type, renderer_class)
    def self.register_connector(type, connector_class)
    def self.register_layout(name, layout_class)
  end
end
```

---

## 7. Test Strategy

### 7.1 Test File Organization

```
spec/lutaml/xsd/spa/svg/
├── diagram_generator_spec.rb
├── style_configuration_spec.rb
├── component_renderer_spec.rb
├── connector_renderer_spec.rb
├── layout_engine_spec.rb
├── defs_builder_spec.rb
├── document_builder_spec.rb
├── value_objects_spec.rb
├── renderers/
│   ├── element_renderer_spec.rb
│   ├── type_renderer_spec.rb
│   ├── attribute_renderer_spec.rb
│   └── group_renderer_spec.rb
├── connectors/
│   ├── inheritance_connector_spec.rb
│   ├── containment_connector_spec.rb
│   └── reference_connector_spec.rb
└── layouts/
    ├── tree_layout_spec.rb
    ├── vertical_layout_spec.rb
    └── horizontal_layout_spec.rb

spec/fixtures/svg/
├── config/
│   ├── test_styles.yml
│   └── test_component_rules.yml
└── expected_outputs/
    ├── simple_element.svg
    ├── type_with_inheritance.svg
    └── complex_structure.svg
```

### 7.2 Unit Test Strategy

Each class has focused unit tests:

#### DiagramGenerator Tests
```ruby
RSpec.describe DiagramGenerator do
  describe "#initialize" do
    it "loads default configuration when none provided"
    it "accepts custom configuration"
    it "raises error for invalid schema name"
  end

  describe "#generate_element_diagram" do
    it "generates simple element diagram"
    it "handles complex nested structures"
    it "applies correct layout engine"
    it "includes all required SVG elements"
  end
end
```

#### StyleConfiguration Tests
```ruby
RSpec.describe StyleConfiguration do
  describe ".load" do
    it "loads from default path"
    it "loads from custom path"
    it "handles missing config files gracefully"
    it "validates configuration structure"
    it "provides sensible defaults"
  end

  describe "value objects" do
    it "creates ColorScheme correctly"
    it "creates Dimensions correctly"
    it "makes value objects immutable"
  end
end
```

#### ElementRenderer Tests
```ruby
RSpec.describe Renderers::ElementRenderer do
  let(:config) { StyleConfiguration.load(test_config_path) }
  let(:renderer) { described_class.new(config, "test-schema") }

  describe "#render" do
    it "renders element box with gradient"
    it "includes clickable link"
    it "shows abstract indicator when abstract"
    it "shows optional indicator when not required"
    it "escapes XML special characters"
    it "applies correct dimensions from config"
  end
end
```

### 7.3 Integration Test Strategy

Test complete diagram generation:

```ruby
RSpec.describe "SVG Diagram Generation Integration" do
  let(:generator) { DiagramGenerator.new("test-schema") }

  it "generates valid SVG for simple element" do
    result = generator.generate_element_diagram(simple_element_data)

    expect(result).to be_valid_svg
    expect(result).to include_gradient("elementGradient")
    expect(result).to include_filter("dropShadow")
    expect(result).to include_element_box("Person")
  end

  it "generates complete type hierarchy" do
    result = generator.generate_type_diagram(complex_type_data)

    expect(result).to include_inheritance_arrow
    expect(result).to include_base_type("BaseType")
    expect(result).to include_derived_type("DerivedType")
  end
end
```

### 7.4 Visual Regression Testing

Use image comparison for visual tests:

```ruby
RSpec.describe "Visual Regression" do
  it "matches expected output for element diagram" do
    svg = generator.generate_element_diagram(element_data)

    # Convert SVG to PNG for comparison
    png = convert_svg_to_png(svg)
    expected = load_expected_image("simple_element.png")

    expect(png).to match_image(expected, threshold: 0.95)
  end
end
```

### 7.5 Test Fixtures

Comprehensive test fixtures:

```ruby
# spec/fixtures/svg/element_data.rb
module SvgTestFixtures
  def simple_element
    {
      "name" => "Person",
      "type" => "PersonType",
      "required" => true,
      "abstract" => false
    }
  end

  def complex_element_with_attributes
    {
      "name" => "Book",
      "attributes" => [
        { "name" => "isbn", "type" => "string", "required" => true },
        { "name" => "year", "type" => "integer", "required" => false }
      ],
      "content_model" => {
        "type" => "sequence",
        "elements" => [...]
      }
    }
  end
end
```

### 7.6 Performance Tests

Ensure performance is acceptable:

```ruby
RSpec.describe "Performance" do
  it "generates diagram in under 100ms for simple structure" do
    expect {
      generator.generate_element_diagram(simple_data)
    }.to perform_under(100).ms
  end

  it "handles deep nesting efficiently" do
    deep_data = create_nested_structure(depth: 10)

    expect {
      generator.generate_element_diagram(deep_data)
    }.to perform_under(500).ms
  end
end
```

---

## 7. Implementation Status

### Configuration System

- [x] Create `config/spa/svg_styles.yml`
- [x] Create `config/spa/svg_component_rules.yml`
- [x] Implement `StyleConfiguration` class
- [x] Implement `ColorScheme` value object
- [x] Implement `Dimensions` value object
- [x] Implement `Effects` value object
- [x] Implement `ConnectorStyles` value object
- [x] Add configuration validation
- [x] Add default configuration fallbacks
- [x] Write tests for `StyleConfiguration`

### Core Architecture

- [x] Create directory structure `lib/lutaml/xsd/spa/svg/`
- [x] Implement `DiagramGenerator` main class
- [x] Implement `ComponentRenderer` abstract base
- [x] Implement `ConnectorRenderer` abstract base
- [x] Implement `LayoutEngine` abstract base
- [x] Implement value objects (Point, Box)
- [x] Write tests for core classes

### Component Renderers

- [x] Implement `ElementRenderer`
- [x] Implement `TypeRenderer`
- [x] Implement `AttributeRenderer`
- [x] Implement `GroupRenderer`
- [x] Write tests for each renderer
- [x] Visual regression tests for renderers

### Connectors

- [x] Implement `InheritanceConnector`
- [x] Implement `ContainmentConnector`
- [x] Implement `ReferenceConnector`
- [x] Write tests for each connector

### Layout Engines

- [x] Implement `TreeLayout`
- [x] Implement `VerticalLayout`
- [ ] (Future) Implement `HorizontalLayout`
- [x] Write tests for each layout
- [x] Performance tests for layouts

### SVG Assembly

- [x] Implement `DefsBuilder`
- [x] Implement `DocumentBuilder`
- [x] Write tests for SVG assembly
- [x] Validate SVG output

### Integration

- [x] Integrate with `SchemaSerializer`
- [x] Integration tests
- [x] Documentation updates
- [x] Remove old monolithic implementation

### Future Enhancements

- [ ] Implement `HorizontalLayout`
- [ ] Add more visual indicators
- [ ] Support for custom themes
- [ ] Plugin system for custom renderers

---

## Appendix A: Class API Reference

### DiagramGenerator

```ruby
module Lutaml::Xsd::Spa::Svg
  class DiagramGenerator
    # Initialize with schema name and optional configuration
    # @param schema_name [String] Name of the schema
    # @param config [StyleConfiguration, nil] Configuration or nil for default
    def initialize(schema_name, config = nil)

    # Generate SVG diagram for an XSD element
    # @param element_data [Hash] Element data structure
    # @return [String] Complete SVG markup
    def generate_element_diagram(element_data)

    # Generate SVG diagram for an XSD complex type
    # @param type_data [Hash] Type data structure
    # @return [String] Complete SVG markup
    def generate_type_diagram(type_data)

    # Generate custom diagram with specific layout and options
    # @param data [Hash] Component data
    # @param options [Hash] Options including :layout, :renderers, etc.
    # @return [String] Complete SVG markup
    def generate_custom_diagram(data, options = {})
  end
end
```

### StyleConfiguration

```ruby
module Lutaml::Xsd::Spa::Svg
  class StyleConfiguration
    # Load configuration from YAML file
    # @param path [String, nil] Path to config file or nil for default
    # @return [StyleConfiguration] Configuration instance
    def self.load(path = nil)

    # Get default configuration file path
    # @return [String] Absolute path to default config
    def self.default_config_path

    # Initialize from parsed configuration hash
    # @param config_hash [Hash] Parsed YAML configuration
    def initialize(config_hash)

    # Access color scheme configuration
    # @return [ColorScheme] Color configuration
    attr_reader :colors

    # Access dimension configuration
    # @return [Dimensions] Size and spacing configuration
    attr_reader :dimensions

    # Access visual effects configuration
    # @return [Effects] Effects configuration
    attr_reader :effects

    # Access connector styling configuration
    # @return [ConnectorStyles] Connector configuration
    attr_reader :connectors

    # Get default layout type
    # @return [String] Layout type name
    attr_reader :layout_type
  end
end
```

### ComponentRenderer

```ruby
module Lutaml::Xsd::Spa::Svg
  class ComponentRenderer
    # Initialize renderer with configuration
    # @param config [StyleConfiguration] Style configuration
    # @param schema_name [String] Schema name for link generation
    def initialize(config, schema_name)

    # Render component to SVG
    # @param component_data [Hash] Component data
    # @param position [Hash] Position {x:, y:}
    # @return [String] SVG markup for component
    def render(component_data, position)
      raise NotImplementedError
    end

    protected

    # Create SVG rect element
    def create_box(x, y, width, height, fill, options = {})

    # Create SVG text element
    def create_text(x, y, text, options = {})

    # Create SVG link element
    def create_link(href, content)

    # Escape XML special characters
    def escape_xml(text)

    # Apply SVG filter to element
    def apply_filter(element_svg, filter_id)
  end
end
```

---

## Appendix B: Configuration Schema

### svg_styles.yml Schema

```yaml
# Root schema
type: object
required:
  - colors
  - dimensions
  - effects
  - connectors
  - layout

colors:
  type: object
  required: [element, type, attribute, group, ui, indicators]
  element:
    type: object
    required: [base, gradient_start, gradient_end, text]
  # ... similar for type, attribute, group
  ui:
    required: [text, border, shadow, background]
  indicators:
    required: [required, optional, abstract]

dimensions:
  type: object
  required: [box, spacing, text]
  box:
    required: [width, height, corner_radius, border_width]
  spacing:
    required: [horizontal, vertical, indent, padding]
  text:
    required: [offset_y, font_size, small_font_size, line_height]

effects:
  type: object
  required: [shadow, gradient, hover]
  shadow:
    required: [enabled, blur, offset_x, offset_y, opacity]
  gradient:
    required: [enabled, direction]

connectors:
  type: object
  required: [inheritance, containment, reference]
  # Each connector has same schema
  inheritance:
    required: [type, stroke_width, stroke_color, fill_color, arrow_size]

layout:
  type: object
  required: [default]
  optional: [tree, vertical, horizontal]
```

---

## Conclusion

This architecture provides:

✅ **Separation of Concerns** - Each class has one clear responsibility
✅ **MECE Structure** - Mutually exclusive, collectively exhaustive design
✅ **External Configuration** - All styling via YAML
✅ **Extensibility** - Easy to add renderers, layouts, connectors
✅ **Testability** - Every component can be tested in isolation
✅ **Maintainability** - Clear structure and documentation
✅ **Performance** - Efficient rendering with minimal object creation
✅ **Backward Compatibility** - Gradual migration with feature flags

The architecture is production-ready and follows Ruby and industry best practices for object-oriented design.
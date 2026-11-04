export {}

declare global {
  interface Window {
    SCHEMA_DATA: SchemaData
  }
}

export interface SchemaData {
  metadata: PackageMetadata
  schemas: Schema[]
  namespaces: Namespace[]
}

export interface PackageMetadata {
  name?: string
  version?: string
  title?: string
  description?: string
  license?: string
  license_url?: string
  authors?: { name: string; email?: string }[]
  homepage?: string
  repository?: string
  documentation?: string
  tags?: string[]
  generator?: string
  generated?: string
  schema_count?: number
  appearance?: {
    logos?: {
      square?: {
        light: { path?: string; url?: string }
        dark: { path?: string; url?: string }
      }
      long?: {
        light: { path?: string; url?: string }
        dark: { path?: string; url?: string }
      }
      icon?: {
        light: { path?: string; url?: string }
        dark: { path?: string; url?: string }
      }
      lutaml_logo?: {
        light: { path?: string; url?: string }
        dark: { path?: string; url?: string }
      }
    }
    favicon?: {
      type: string
      sizes?: string
      path?: string
      url?: string
    }[]
    colors?: {
      primary?: string
      primary_light?: string
      primary_dark?: string
      secondary?: string
      accent?: string
      background_primary?: string
      background_secondary?: string
      text_primary?: string
      text_secondary?: string
      text_muted?: string
      dark?: {
        primary?: string
        primary_light?: string
        background_primary?: string
        background_secondary?: string
        text_primary?: string
        text_secondary?: string
      }
    }
    typography?: {
      font_family?: string
      mono_font_family?: string
      font_size_base?: string
      font_weight_bold?: string
    }
    custom_css?: string
    stylesheets?: { path?: string; url?: string }[]
    layout?: {
      header_height?: string
      sidebar_width?: string
      content_padding?: string
    }
    border_radius?: {
      default?: string
      lg?: string
      xl?: string
      full?: string
    }
    shadows?: {
      sm?: string
      default?: string
      md?: string
      lg?: string
    }
    subtitle?: string
  }
  links?: {
    name: string
    url: string
  }[]
  entrypoint_files?: string[]
}

export interface Schema {
  id: string
  name: string
  location: string
  target_namespace: string
  prefix?: string
  namespace?: string
  file_path?: string
  is_entrypoint?: boolean
  complex_types: ComplexType[]
  simple_types: SimpleType[]
  elements: SchemaElement[]
  groups: GroupRef[]
  attribute_groups: AttributeGroup[]
  attributes: SchemaAttribute[]
  imports: Import[]
  includes: Include[]
  documentation?: string
}

export interface ComplexType {
  id: string
  name: string
  base?: string
  content_model?: 'sequence' | 'choice' | 'all' | 'complex_content' | 'simple_content' | 'empty'
  abstract?: boolean
  mixed?: boolean
  elements: TypeElement[]
  attributes: TypeAttribute[]
  choice: ChoiceElement
  sequence?: SequenceElement
  group?: GroupRef
  attribute_groups?: AttributeGroupRef[]
  extension_attributes?: TypeAttribute[]
  documentation?: string
  deprecated?: boolean
  used_by?: UsedByRef[]
  diagram_svg?: string
  source?: string
  instance_xml?: string
}

export interface SimpleType {
  id: string
  name: string
  base?: string
  restriction?: Restriction
  union?: string[]
  list?: string
  documentation?: string
  deprecated?: boolean
  diagram_svg?: string
  source?: string
  instance_xml?: string
}

export interface Restriction {
  base?: string
  enumeration?: { value: string; documentation?: string }[]
  pattern?: string
  min_length?: number
  max_length?: number
  min_inclusive?: number | string
  max_inclusive?: number | string
  length?: number
}

export interface SchemaElement {
  id: string
  name: string
  type?: string
  type_local?: boolean
  reference?: string
  abstract?: boolean
  substitution_group?: string
  nillable?: boolean
  default?: string
  fixed?: string
  occurs?: Occurs
  documentation?: string
  deprecated?: boolean
  diagram_svg?: string
  used_by?: UsedByRef[]
  source?: string
  instance_xml?: string
}

export interface TypeElement {
  name: string
  type?: string
  complex_type?: ComplexType
  type_local?: boolean
  reference?: string
  occurs?: Occurs
  documentation?: string
}

export interface Occurs {
  min: number
  max?: number
}

export interface TypeAttribute {
  name: string
  ref?: string
  type?: string
  use?: 'required' | 'optional' | 'prohibited'
  default?: string
  fixed?: string
  documentation?: string
  instance_xml?: string
}

export interface SchemaAttribute {
  id: string
  name: string
  type?: string
  use?: 'required' | 'optional'
  default?: string
  documentation?: string
  used_by?: UsedByRef[]
}

// export interface Group {
//   id: string
//   name: string
//   elements: TypeElement[]
//   attributes: TypeAttribute[]
//   choice: ChoiceElement
//   documentation?: string
//   used_by?: UsedByRef[]
// }

export interface AttributeGroup {
  id: string
  name: string
  attributes: TypeAttribute[]
  documentation?: string
  used_by?: UsedByRef[]
  source?: string
  instance_xml?: string
}

export interface ChoiceElement {
  id?: string
  elements: TypeElement[]
  occurs?: Occurs
  groups?: GroupRef[]
  sequences?: SequenceElement[]
  choices?: ChoiceElement[]
  documentation?: string
}

export interface SequenceElement {
  id?: string
  elements: TypeElement[]
  occurs?: Occurs
  groups?: GroupRef[]
  sequences?: SequenceElement[]
  choices?: ChoiceElement[]
  documentation?: string
}

export interface GroupRef {
  id: string
  ref: string
  name?: string
  occurs?: Occurs
  choice: ChoiceElement
  sequence?: SequenceElement
  documentation?: string
  instance_xml?: string
  source?: string
}

export interface AttributeGroupRef {
  ref: string
  attributes?: TypeAttribute[]
}

export interface UsedByRef {
  name: string
  type?: string
}

export interface Import {
  namespace: string
  schema_location?: string
}

export interface Include {
  schema_location: string
}

export interface Namespace {
  prefix: string
  uri: string
  schemas: string[]
}

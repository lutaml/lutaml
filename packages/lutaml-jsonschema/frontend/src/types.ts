export interface SpaMetadata {
  title?: string
  version?: string
  description?: string
  baseUrl?: string
  theme?: string
  appearance?: {
    logos?: {
      square?: {
        light: { path?: string; url?: string }
        dark: { path?: string; url?: string }
      }
    }
    subtitle?: string
  }
}

export interface SpaDiscriminator {
  propertyName?: string
  mapping?: Record<string, string>
}

export interface SpaProperty {
  name: string
  title?: string
  description?: string
  type?: string
  format?: string
  required?: boolean
  default?: string
  pattern?: string
  enum?: string[]
  enumDescriptions?: Record<string, string>
  /** Resolved $ref — normalized from backend's "$ref" key during loadFromWindow() */
  ref?: string
  /** Raw JSON Schema $ref — present in window.SCHEMA_DATA before normalization */
  $ref?: string
  minLength?: number
  maxLength?: number
  minimum?: number
  maximum?: number
  itemsType?: string
  itemsRef?: string
  /** Positional item labels for tuple-form arrays (`items` array / `prefixItems`) */
  itemsTuple?: string[]
  /** Label for items past the tuple positions */
  itemsTail?: string
  /** Whether items past the tuple positions are forbidden */
  itemsClosed?: boolean
  deprecated?: boolean
  readOnly?: boolean
  writeOnly?: boolean
  examples?: string[]
  minItems?: number
  maxItems?: number
  uniqueItems?: boolean
  multipleOf?: number
  const?: string
  exclusiveMinimum?: number
  exclusiveMaximum?: number
  additionalProperties?: boolean
  additionalPropertiesRef?: string
  additionalPropertiesType?: string
  contentMediaType?: string
  contentEncoding?: string
  compositionSource?: string
  patternProperties?: Record<string, { type?: string }>
  properties?: SpaProperty[]
  oneOfVariants?: SpaProperty[]
  anyOfVariants?: SpaProperty[]
  discriminator?: SpaDiscriminator
}

export interface SpaDefinition {
  name: string
  title?: string
  description?: string
  type?: string
  format?: string
  enum?: string[]
  enumDescriptions?: Record<string, string>
  const?: string
  pattern?: string
  default?: string
  minLength?: number
  maxLength?: number
  minimum?: number
  maximum?: number
  exclusiveMinimum?: number
  exclusiveMaximum?: number
  multipleOf?: number
  contentMediaType?: string
  contentEncoding?: string
  properties: SpaProperty[]
  required: string[]
  examples?: string[]
  minProperties?: number
  maxProperties?: number
  additionalProperties?: boolean
  additionalPropertiesRef?: string
  additionalPropertiesType?: string
  itemsType?: string
  itemsRef?: string
  itemsTuple?: string[]
  itemsTail?: string
  itemsClosed?: boolean
  hasAllOf?: boolean
  hasAnyOf?: boolean
  hasOneOf?: boolean
  compositionVariants?: string[]
  patternProperties?: Record<string, { type?: string }>
  oneOfVariants?: SpaProperty[]
  anyOfVariants?: SpaProperty[]
  discriminator?: SpaDiscriminator
}

export interface SpaSchema {
  name: string
  title?: string
  description?: string
  type?: string
  properties: SpaProperty[]
  definitions: SpaDefinition[]
  required: string[]
  examples?: string[]
  sourceJson?: string
  $schema?: string
  $id?: string
  externalDocs?: { url?: string; description?: string }
  additionalProperties?: boolean
  minProperties?: number
  maxProperties?: number
  hasAllOf?: boolean
  hasAnyOf?: boolean
  hasOneOf?: boolean
  itemsType?: string
  itemsRef?: string
  itemsTuple?: string[]
  itemsTail?: string
  itemsClosed?: boolean
  patternProperties?: Record<string, { type?: string }>
  ifSchema?: SpaProperty
  thenRequired?: string[]
  thenProperties?: SpaProperty[]
  elseProperties?: SpaProperty[]
  discriminator?: SpaDiscriminator
}

export interface SpaSearchEntry {
  name: string
  title?: string
  description?: string
  type: string
  schemaName: string
}

export interface SpaDiffEntry {
  schemaName: string
  pointer: string
  classification: 'breaking' | 'additive' | 'cosmetic'
  detail?: string
}

export interface SpaDocument {
  metadata: SpaMetadata
  schemas: SpaSchema[]
  searchIndex: SpaSearchEntry[]
  diff?: SpaDiffEntry[]
}

declare global {
  interface Window {
    SCHEMA_DATA: SpaDocument
  }
}

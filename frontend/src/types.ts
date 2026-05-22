export interface SpaCardinality {
  min?: string
  max?: string
}

export interface SpaAttribute {
  id: string
  name: string
  type: string
  visibility?: string
  owner: string
  ownerName: string
  cardinality?: SpaCardinality
  definition?: string
  stereotypes: string[]
  isStatic: boolean
  isReadOnly: boolean
  defaultValue?: string
}

export interface SpaAssociationEnd {
  class?: string
  className?: string
  role?: string
  cardinality?: SpaCardinality
  aggregation?: string
}

export interface SpaAssociation {
  id: string
  xmiId: string
  name: string
  type: string
  definition?: string
  source?: SpaAssociationEnd
  target?: SpaAssociationEnd
}

export interface SpaOperation {
  id: string
  name: string
  visibility?: string
  returnType?: string
  owner: string
  ownerName: string
  parameters: SpaParameter[]
  isStatic: boolean
  isAbstract: boolean
}

export interface SpaParameter {
  name: string
  type?: string
  direction?: string
}

export interface SpaLiteral {
  name: string
  definition?: string
}

export interface SpaInheritedAttribute {
  attributeId: string
  attribute: SpaAttribute
  inheritedFrom: string
  inheritedFromName: string
  parentOrder: number
}

export interface SpaInheritedAssociation {
  associationId: string
  inheritedFrom: string
  inheritedFromName: string
  parentOrder: number
  localRole: string
}

export interface SpaClass {
  id: string
  xmiId: string
  name: string
  qualifiedName: string
  type: string
  package?: string
  stereotypes: string[]
  definition?: string
  attributes: string[]
  operations: string[]
  associations: string[]
  generalizations: string[]
  specializations: string[]
  isAbstract: boolean
  literals: SpaLiteral[]
  inheritedAttributes: SpaInheritedAttribute[]
  inheritedAssociations: SpaInheritedAssociation[]
}

export interface SpaPackage {
  id: string
  xmiId: string
  name: string
  path: string
  definition?: string
  stereotypes: string[]
  classes: string[]
  subPackages: string[]
  diagrams: string[]
  parent?: string
}

export interface SpaTreeClassRef {
  id: string
  name: string
  stereotypes: string[]
}

export interface SpaPackageTreeNode {
  id: string
  name: string
  path: string
  stereotypes: string[]
  classCount: number
  classes: SpaTreeClassRef[]
  children: SpaPackageTreeNode[]
}

export interface SpaDiagram {
  id: string
  xmiId: string
  name: string
  type: string
  package?: string
  objectCount: number
  linkCount: number
  svg?: string
}

export interface SpaStatistics {
  packages: number
  classes: number
  associations: number
  attributes: number
  operations: number
}

export interface SpaLogoVariant {
  path?: string
  url?: string
}

export interface SpaLogoConfig {
  light: SpaLogoVariant
  dark: SpaLogoVariant
}

export interface SpaLogos {
  square?: SpaLogoConfig
  long?: SpaLogoConfig
}

export interface SpaAppearance {
  logos?: SpaLogos
}

export interface SpaMetadata {
  title?: string
  description?: string
  generated: string
  generator: string
  version: string
  homepage?: string
  repository?: string
  license?: string
  authors?: string
  tags?: string[]
  appearance?: SpaAppearance
  statistics: SpaStatistics
}

export interface SpaSearchEntry {
  id: string
  type: string
  entityType: string
  entityId: string
  name: string
  qualifiedName: string
  package: string
  content: string
  boost: number
}

export interface SpaSearchIndex {
  version: string
  fields: { name: string; boost: number }[]
  ref: string
  documentStore: SpaSearchEntry[]
  pipeline: string[]
}

export interface SpaDocument {
  metadata: SpaMetadata
  packageTree: SpaPackageTreeNode
  packages: Record<string, SpaPackage>
  classes: Record<string, SpaClass>
  attributes: Record<string, SpaAttribute>
  associations: Record<string, SpaAssociation>
  operations: Record<string, SpaOperation>
  diagrams: Record<string, SpaDiagram>
}

export interface SpaData {
  metadata: SpaMetadata
  packageTree: SpaPackageTreeNode
  packages: Record<string, SpaPackage>
  classes: Record<string, SpaClass>
  attributes: Record<string, SpaAttribute>
  associations: Record<string, SpaAssociation>
  operations: Record<string, SpaOperation>
  diagrams: Record<string, SpaDiagram>
  searchIndex: SpaSearchIndex
}

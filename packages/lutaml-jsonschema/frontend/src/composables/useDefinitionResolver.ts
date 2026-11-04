import type { SpaSchema, SpaDefinition } from '../types'

/**
 * Resolve a JSON Schema $ref string to its SpaDefinition.
 * Handles three patterns:
 *   1. #/definitions/NAME  — internal definition
 *   2. #/$defs/NAME        — internal $def
 *   3. FILENAME#/$defs/NAME — cross-file reference (searches all schemas)
 *   4. ./FILENAME          — cross-file root object reference
 * Returns null if the ref is empty, malformed, or not found.
 */
export function resolveSchemaRef(ref: string | undefined, schema: SpaSchema, allSchemas?: SpaSchema[]): SpaDefinition | null {
  if (!ref) return null

  // Pattern 1 & 2: internal ref (#/definitions/NAME or #/$defs/NAME)
  const internalMatch = ref.match(/^#\/(?:definitions|\$defs)\/([^/]+)$/)
  if (internalMatch) {
    return schema.definitions.find(d => d.name === internalMatch[1]) ?? null
  }

  // Pattern 2b: anchor ref (#NAME) — searches definitions by name
  const anchorMatch = ref.match(/^#([^/]+)$/)
  if (anchorMatch) {
    return schema.definitions.find(d => d.name === anchorMatch[1]) ?? null
  }

  // Pattern 3: cross-file ref (FILENAME#/$defs/NAME)
  const crossFileMatch = ref.match(/^(.+?)(?:\.json)?#\/\$defs\/([^/]+)$/)
  if (crossFileMatch && allSchemas) {
    const targetSchemaName = crossFileMatch[1].replace(/^\.\//, '')
    const targetDefName = crossFileMatch[2]
    const targetSchema = allSchemas.find(s => s.name === targetSchemaName)
    if (targetSchema) {
      return targetSchema.definitions.find(d => d.name === targetDefName) ?? null
    }
  }

  // Pattern 4: cross-file root ref (./FILENAME or FILENAME.json)
  const fileOnlyMatch = ref.match(/^(?:\.\/)?(.+?)(?:\.json)?$/)
  if (fileOnlyMatch && allSchemas && !ref.includes('#')) {
    const targetSchemaName = fileOnlyMatch[1]
    const targetSchema = allSchemas.find(s => s.name === targetSchemaName)
    if (targetSchema) {
      return {
        name: targetSchema.name,
        title: targetSchema.title,
        description: targetSchema.description,
        type: targetSchema.type,
        properties: targetSchema.properties,
        required: targetSchema.required,
      }
    }
  }

  return null
}

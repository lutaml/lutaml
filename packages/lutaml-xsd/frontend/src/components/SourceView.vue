<template>
  <div class="source-view">
    <div v-if="xmlSource" class="source-block">
      <pre><code class="language-xml" v-html="highlightedXml"></code></pre>
    </div>
    <div v-else class="source-empty">
      <p>No source available for this type.</p>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import type { ComplexType, SimpleType, SchemaElement, GroupRef, AttributeGroup, SchemaAttribute } from '@/types'

type TypeData = {
  type: 'complex' | 'simple' | 'element' | 'group' | 'attribute_group' | 'attribute'
  data: ComplexType | SimpleType | SchemaElement | GroupRef | AttributeGroup | SchemaAttribute
  schema: { id: string; name: string; prefix?: string }
}

const props = defineProps<{ type: TypeData }>()

const xmlSource = computed(() => generateXmlSource())

function generateXmlSource(): string {
  const prefix = props.type.schema?.prefix || 'xs'
  const name = props.type.data.name || ''

  if (props.type.type === 'element') {
    return ''
  } else if (props.type.type === 'complex') {
    return ''
  } else if (props.type.type === 'simple') {
    return generateSimpleTypeXml(name, prefix, props.type.data as SimpleType)
  } else if (props.type.type === 'group') {
    return generateGroupXml(name, prefix, props.type.data as GroupRef)
  } else if (props.type.type === 'attribute_group') {
    return ''
  } else if (props.type.type === 'attribute') {
    return ''
  }
  return ''
}

function generateSimpleTypeXml(name: string, prefix: string, st: SimpleType): string {
  let xml = `<${prefix}:simpleType name="${name}">\n`

  if (st.restriction?.base) {
    xml += `  <${prefix}:restriction base="${st.restriction.base}">\n`
    for (const enumVal of st.restriction.enumeration || []) {
      xml += `    <${prefix}:enumeration value="${enumVal.value}"`
      if (enumVal.documentation) xml += `><!-- ${enumVal.documentation} --></${prefix}:enumeration>`
      else xml += `/>`
      xml += `\n`
    }
    if (st.restriction.pattern) {
      xml += `    <${prefix}:pattern value="${st.restriction.pattern}"/>\n`
    }
    if (st.restriction.min_length !== undefined) {
      xml += `    <${prefix}:minLength value="${st.restriction.min_length}"/>\n`
    }
    if (st.restriction.max_length !== undefined) {
      xml += `    <${prefix}:maxLength value="${st.restriction.max_length}"/>\n`
    }
    if (st.restriction.min_inclusive !== undefined) {
      xml += `    <${prefix}:minInclusive value="${st.restriction.min_inclusive}"/>\n`
    }
    if (st.restriction.max_inclusive !== undefined) {
      xml += `    <${prefix}:maxInclusive value="${st.restriction.max_inclusive}"/>\n`
    }
    xml += `  </${prefix}:restriction>\n`
  } else if (st.union?.length) {
    xml += `  <${prefix}:union memberTypes="${st.union.join(' ')}"/>\n`
  } else if (st.list) {
    xml += `  <${prefix}:list itemType="${st.list}"/>\n`
  }

  if (st.documentation) {
    xml += `  <!-- ${st.documentation} -->\n`
  }

  xml += `</${prefix}:simpleType>`
  return xml
}

function generateGroupXml(name: string, prefix: string, g: any): string {
  let xml = `<${prefix}:group name="${name}">\n`
  xml += `  <${prefix}:sequence>\n`
  for (const el of g.elements || []) {
    xml += `    <${prefix}:element name="${el.name}"`
    if (el.type) xml += ` type="${el.type}"`
    if (el.reference) xml += ` ref="${el.reference}"`
    xml += `/>\n`
  }
  xml += `  </${prefix}:sequence>\n`
  if (g.documentation) {
    xml += `  <!-- ${g.documentation} -->\n`
  }
  xml += `</${prefix}:group>`
  return xml
}


// Tokenizer-based XML highlighter
function highlightXml(xml: string): string {
  const tokens: string[] = []
  let i = 0

  while (i < xml.length) {
    if (xml[i] === '<') {
      // Could be a tag or comment
      if (xml.slice(i, i + 4) === '<!--') {
        // Comment
        const end = xml.indexOf('-->', i + 4)
        if (end !== -1) {
          const comment = xml.slice(i, end + 3)
          tokens.push('<span class="hljs-comment">' + h(comment) + '</span>')
          i = end + 3
          continue
        }
      }
      // Tag
      const end = xml.indexOf('>', i)
      if (end !== -1) {
        const tag = xml.slice(i, end + 1)
        tokens.push(processTag(tag))
        i = end + 1
        continue
      }
    }
    // Text content
    let next = xml.indexOf('<', i)
    if (next === -1) next = xml.length
    if (next > i) {
      tokens.push(h(xml.slice(i, next)))
      i = next
    } else {
      tokens.push(h(xml[i]))
      i++
    }
  }

  return tokens.join('')
}

function h(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
}

function processTag(tag: string): string {
  const isClose = tag[1] === '/'
  const isSelfClose = tag.endsWith('/>')
  const innerStart = isClose ? 2 : 1
  const innerEnd = isSelfClose ? tag.length - 2 : tag.length - 1
  const inner = tag.slice(innerStart, innerEnd)

  // Split into tag name and attributes
  const parts = inner.split(/\s+/)
  const tagName = parts[0]
  const attrs = parts.slice(1).join(' ')

  let result = '<span class="hljs-bracket">&lt;</span>'
  if (isClose) result += '<span class="hljs-bracket">/</span>'
  result += '<span class="hljs-tag">' + h(tagName) + '</span>'

  if (attrs) {
    // Highlight attribute name="value" patterns
    const attrMatches = attrs.match(/([\w:.-]+)(="[^"]*")/g)
    if (attrMatches) {
      for (const attr of attrMatches) {
        const eqIdx = attr.indexOf('=')
        const name = attr.slice(0, eqIdx)
        const value = attr.slice(eqIdx)
        result += ' <span class="hljs-attr">' + h(name) + '</span>=' + h(value)
      }
    } else {
      result += ' ' + h(attrs)
    }
  }

  if (isSelfClose) {
    result += '<span class="hljs-bracket">/&gt;</span>'
  } else {
    result += '<span class="hljs-bracket">&gt;</span>'
  }

  return result
}

const highlightedXml = computed(() => {
  if (!xmlSource.value) return ''
  return highlightXml(xmlSource.value)
})
</script>

<style scoped>
.source-view {
  height: 100%;
}

.source-block {
  height: 100%;
  overflow: auto;
}

.source-block pre {
  margin: 0;
  padding: var(--space-4);
  background: var(--bg-secondary);
  border-radius: var(--radius-md);
  overflow-x: auto;
  font-size: var(--text-sm);
  font-family: var(--font-mono);
  line-height: 1.6;
}

.source-block code {
  font-family: var(--font-mono);
  color: var(--text-primary);
}

.hljs-tag {
  color: var(--color-primary);
}

.hljs-attr {
  color: var(--color-accent);
}

.hljs-string {
  color: var(--color-success, #10b981);
}

.hljs-comment {
  color: var(--text-muted);
  font-style: italic;
}

.source-empty {
  display: flex;
  align-items: center;
  justify-content: center;
  height: 100%;
  color: var(--text-muted);
  font-size: var(--text-sm);
}
</style>

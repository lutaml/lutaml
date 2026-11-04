import { describe, it, expect } from 'vitest'
import { scoreResult } from '../composables/useSearch'
import type { SearchResult } from '../composables/useSearch'

function result(overrides: Partial<SearchResult> = {}): SearchResult {
  return {
    id: 'schema:Test:Test',
    type: 'schema',
    name: 'Test',
    rawName: 'Test',
    schemaName: 'Test',
    score: 0,
    ...overrides,
  }
}

describe('scoreResult', () => {
  it('scores exact name match highest (100)', () => {
    expect(scoreResult(result({ name: 'Person', rawName: 'person' }), 'person')).toBe(100)
  })

  it('scores exact title match highest (100)', () => {
    expect(scoreResult(result({ name: 'Person', rawName: 'person' }), 'person')).toBe(100)
  })

  it('scores starts-with match at 80', () => {
    expect(scoreResult(result({ name: 'PersonRecord', rawName: 'person_record' }), 'person')).toBe(80)
  })

  it('scores exact schema name match at 70', () => {
    expect(scoreResult(result({ name: 'X', rawName: 'x', schemaName: 'person' }), 'person')).toBe(70)
  })

  it('scores contains match at 60', () => {
    expect(scoreResult(result({ name: 'MyPersonData', rawName: 'my_person_data' }), 'person')).toBe(60)
  })

  it('scores schema starts-with at 50', () => {
    expect(scoreResult(result({ name: 'X', rawName: 'x', schemaName: 'person_v2' }), 'person')).toBe(50)
  })

  it('scores schema contains at 40', () => {
    expect(scoreResult(result({ name: 'X', rawName: 'x', schemaName: 'my_person_data' }), 'person')).toBe(40)
  })

  it('scores description match at 20', () => {
    expect(scoreResult(result({ name: 'X', rawName: 'x', description: 'A person record' }), 'person')).toBe(20)
  })

  it('returns 0 for no match', () => {
    expect(scoreResult(result({ name: 'X', rawName: 'x', schemaName: 'other', description: 'no match' }), 'person')).toBe(0)
  })

  it('prefers name match over description match', () => {
    const nameMatch = scoreResult(result({ name: 'Person', rawName: 'person' }), 'person')
    const descMatch = scoreResult(result({ name: 'X', rawName: 'x', description: 'person data' }), 'person')
    expect(nameMatch).toBeGreaterThan(descMatch)
  })
})

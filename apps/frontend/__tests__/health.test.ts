import { describe, it, expect } from 'vitest'
import { GET } from '../app/api/health/route'

describe('Health Check Endpoint', () => {
  it('returns 200 status code', async () => {
    const response = await GET()
    expect(response.status).toBe(200)
  })

  it('returns healthy status in JSON', async () => {
    const response = await GET()
    const data = await response.json()

    expect(data).toHaveProperty('status', 'healthy')
    expect(data).toHaveProperty('service', 'cuddly-disco-frontend')
  })

  it('returns valid JSON response', async () => {
    const response = await GET()
    const data = await response.json()

    expect(data).toBeTypeOf('object')
    expect(data.status).toBe('healthy')
  })
})

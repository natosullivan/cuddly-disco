import { describe, it, expect, beforeEach, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import Home from '../app/page'

// Mock fetch globally for server component testing
global.fetch = vi.fn()

// Mock environment variables
const mockEnv = (location?: string, backendUrl?: string) => {
  process.env.LOCATION = location || 'Unknown'
  process.env.BACKEND_URL = backendUrl || 'http://localhost:5000'
}

describe('Home Page (Server Component)', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    mockEnv()
  })

  it('renders the main heading', async () => {
    ;(global.fetch as any).mockResolvedValue({
      ok: true,
      json: async () => ({ message: 'Test message' }),
    })

    const page = await Home()
    render(page)

    expect(screen.getByText('cuddly-disco.ai')).toBeInTheDocument()
  })

  it('displays location from environment variable', async () => {
    mockEnv('San Francisco')

    ;(global.fetch as any).mockResolvedValue({
      ok: true,
      json: async () => ({ message: 'Test message' }),
    })

    const page = await Home()
    render(page)

    expect(screen.getByText('San Francisco')).toBeInTheDocument()
    expect(screen.getByText(/For all the SRE\/DevOps\/Platform engineers out there, here are some kind words from/)).toBeInTheDocument()
  })

  it('displays message from backend API', async () => {
    const mockMessage = 'Your pipeline is green'

    ;(global.fetch as any).mockResolvedValue({
      ok: true,
      json: async () => ({ message: mockMessage }),
    })

    const page = await Home()
    render(page)

    expect(screen.getByText(new RegExp(mockMessage))).toBeInTheDocument()
  })

  it('displays error message when backend API fails', async () => {
    ;(global.fetch as any).mockRejectedValue(new Error('Network error'))

    const page = await Home()
    render(page)

    expect(screen.getByText(/Unable to connect to backend service/)).toBeInTheDocument()
  })

  it('displays error message when backend returns non-200 status', async () => {
    ;(global.fetch as any).mockResolvedValue({
      ok: false,
      status: 500,
    })

    const page = await Home()
    render(page)

    expect(screen.getByText(/Unable to connect to backend service/)).toBeInTheDocument()
  })

  it('applies error-message class when backend fails', async () => {
    ;(global.fetch as any).mockRejectedValue(new Error('Network error'))

    const page = await Home()
    render(page)

    const paragraph = screen.getByText(/Unable to connect to backend service/).closest('p')
    expect(paragraph).toHaveClass('error-message')
  })

  it('applies success-message class when backend succeeds', async () => {
    ;(global.fetch as any).mockResolvedValue({
      ok: true,
      json: async () => ({ message: 'Success message' }),
    })

    const page = await Home()
    render(page)

    const paragraph = screen.getByText(/Success message/).closest('p')
    expect(paragraph).toHaveClass('success-message')
  })

  it('uses BACKEND_URL environment variable for API call', async () => {
    mockEnv('Test Location', 'http://backend-service:5000')

    ;(global.fetch as any).mockResolvedValue({
      ok: true,
      json: async () => ({ message: 'Backend message' }),
    })

    await Home()

    expect(global.fetch).toHaveBeenCalledWith(
      'http://backend-service:5000/api/message',
      expect.objectContaining({
        cache: 'no-store',
      })
    )
  })

  it('defaults to localhost when BACKEND_URL is not set', async () => {
    mockEnv('Test Location', '')

    ;(global.fetch as any).mockResolvedValue({
      ok: true,
      json: async () => ({ message: 'Local message' }),
    })

    await Home()

    expect(global.fetch).toHaveBeenCalledWith(
      'http://localhost:5000/api/message',
      expect.objectContaining({
        cache: 'no-store',
      })
    )
  })

  it('defaults location to Unknown when not set', async () => {
    mockEnv('', 'http://localhost:5000')

    ;(global.fetch as any).mockResolvedValue({
      ok: true,
      json: async () => ({ message: 'Test message' }),
    })

    const page = await Home()
    render(page)

    expect(screen.getByText('Unknown')).toBeInTheDocument()
  })

  it('disables caching for backend API calls', async () => {
    ;(global.fetch as any).mockResolvedValue({
      ok: true,
      json: async () => ({ message: 'Test message' }),
    })

    await Home()

    expect(global.fetch).toHaveBeenCalledWith(
      expect.any(String),
      expect.objectContaining({
        cache: 'no-store',
      })
    )
  })

  it('handles slow backend responses with timeout', async () => {
    // Mock fetch to respect the abort signal and reject when aborted
    ;(global.fetch as any).mockImplementation((url: string, options: any) => {
      return new Promise((resolve, reject) => {
        const timeout = setTimeout(() => {
          resolve({
            ok: true,
            json: async () => ({ message: 'Slow response' }),
          })
        }, 3000) // Delay 3 seconds (longer than the 2 second timeout)

        // Listen to the abort signal
        if (options?.signal) {
          options.signal.addEventListener('abort', () => {
            clearTimeout(timeout)
            reject(new Error('The operation was aborted'))
          })
        }
      })
    })

    const page = await Home()
    render(page)

    // Should show error message due to timeout
    expect(screen.getByText(/Unable to connect to backend service/)).toBeInTheDocument()
  })

  it('handles fetch abortion gracefully', async () => {
    // Mock fetch to reject with abort error
    ;(global.fetch as any).mockRejectedValue(new Error('The operation was aborted'))

    const page = await Home()
    render(page)

    expect(screen.getByText(/Unable to connect to backend service/)).toBeInTheDocument()
  })

  it('passes AbortSignal to fetch call', async () => {
    ;(global.fetch as any).mockResolvedValue({
      ok: true,
      json: async () => ({ message: 'Test message' }),
    })

    await Home()

    // Verify that fetch was called with signal parameter
    expect(global.fetch).toHaveBeenCalledWith(
      expect.any(String),
      expect.objectContaining({
        cache: 'no-store',
        signal: expect.any(AbortSignal),
      })
    )
  })

  it('clears timeout when fetch succeeds quickly', async () => {
    const clearTimeoutSpy = vi.spyOn(global, 'clearTimeout')

    ;(global.fetch as any).mockResolvedValue({
      ok: true,
      json: async () => ({ message: 'Fast response' }),
    })

    await Home()

    // Verify clearTimeout was called (timeout was cleaned up)
    expect(clearTimeoutSpy).toHaveBeenCalled()

    clearTimeoutSpy.mockRestore()
  })
})

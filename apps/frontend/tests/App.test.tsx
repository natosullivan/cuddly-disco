import { describe, it, expect, beforeEach, vi } from 'vitest'
import { render, screen, waitFor } from '@testing-library/react'
import App from '../src/App'

// Mock fetch globally
global.fetch = vi.fn()

describe('App', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('renders the main heading', () => {
    ;(global.fetch as any).mockResolvedValue({
      ok: true,
      json: async () => ({ message: 'Test message' }),
    })

    render(<App />)
    expect(screen.getByText('cuddly-disco.ai')).toBeInTheDocument()
  })

  it('displays location from environment variable', async () => {
    import.meta.env.VITE_LOCATION = 'San Francisco'

    ;(global.fetch as any).mockResolvedValue({
      ok: true,
      json: async () => ({ message: 'Test message' }),
    })

    render(<App />)

    await waitFor(() => {
      expect(screen.getByText(/For all the SREs out there, here are some kind words from/)).toBeInTheDocument()
      expect(screen.getByText('San Francisco')).toBeInTheDocument()
    })
  })

  it('displays message from API when fetch succeeds', async () => {
    const mockMessage = 'Your pipeline is green'

    ;(global.fetch as any).mockResolvedValue({
      ok: true,
      json: async () => ({ message: mockMessage }),
    })

    render(<App />)

    await waitFor(() => {
      expect(screen.getByText(new RegExp(mockMessage))).toBeInTheDocument()
    })
  })

  it('displays error message when API call fails', async () => {
    ;(global.fetch as any).mockRejectedValue(new Error('Network error'))

    render(<App />)

    await waitFor(() => {
      expect(screen.getByText(/Unable to connect to backend service/)).toBeInTheDocument()
    })
  })

  it('displays loading state initially', () => {
    ;(global.fetch as any).mockImplementation(() => new Promise(() => {}))

    render(<App />)

    expect(screen.getByText(/Loading\.\.\./)).toBeInTheDocument()
  })

  it('applies error-message class when API fails', async () => {
    ;(global.fetch as any).mockRejectedValue(new Error('Network error'))

    render(<App />)

    await waitFor(() => {
      const paragraph = screen.getByText(/Unable to connect to backend service/).closest('p')
      expect(paragraph).toHaveClass('error-message')
    })
  })

  it('applies success-message class when API succeeds', async () => {
    ;(global.fetch as any).mockResolvedValue({
      ok: true,
      json: async () => ({ message: 'Success message' }),
    })

    render(<App />)

    await waitFor(() => {
      const paragraph = screen.getByText(/Success message/).closest('p')
      expect(paragraph).toHaveClass('success-message')
    })
  })
})

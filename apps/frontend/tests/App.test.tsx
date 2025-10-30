import { describe, it, expect, beforeEach, vi } from 'vitest'
import { render, screen, waitFor } from '@testing-library/react'
import App from '../src/App'

// Mock fetch globally
global.fetch = vi.fn()

describe('App', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    // Clear runtime config for each test
    delete (window as any).APP_CONFIG
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

  it('uses runtime config from window.APP_CONFIG when available', async () => {
    window.APP_CONFIG = {
      VITE_LOCATION: 'Kubernetes',
      VITE_BACKEND_URL: 'http://backend-service:5000'
    }

    ;(global.fetch as any).mockResolvedValue({
      ok: true,
      json: async () => ({ message: 'K8s message' }),
    })

    render(<App />)

    await waitFor(() => {
      expect(screen.getByText('Kubernetes')).toBeInTheDocument()
    })

    // Verify it called the runtime config URL
    expect(global.fetch).toHaveBeenCalledWith('http://backend-service:5000/api/message')
  })

  it('falls back to import.meta.env when window.APP_CONFIG is not available', async () => {
    import.meta.env.VITE_LOCATION = 'Local Dev'
    import.meta.env.VITE_BACKEND_URL = 'http://localhost:5000'

    ;(global.fetch as any).mockResolvedValue({
      ok: true,
      json: async () => ({ message: 'Local message' }),
    })

    render(<App />)

    await waitFor(() => {
      expect(screen.getByText('Local Dev')).toBeInTheDocument()
    })

    // Verify it called the build-time env URL
    expect(global.fetch).toHaveBeenCalledWith('http://localhost:5000/api/message')
  })
})

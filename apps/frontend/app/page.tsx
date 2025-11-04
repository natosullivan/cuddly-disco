interface ApiResponse {
  message: string
}

async function getBackendMessage(): Promise<{ message: string; error: boolean }> {
  try {
    // Use environment variable for backend URL
    // In K8s: http://backend-service.cuddly-disco-backend.svc.cluster.local:5000
    // In local dev: http://localhost:5000
    const backendUrl = process.env.BACKEND_URL || 'http://localhost:5000'
    const apiUrl = `${backendUrl}/api/message`

    // Create an AbortController to timeout the fetch after 2 seconds
    // This prevents the Next.js server from hanging if the backend is unavailable
    const controller = new AbortController()
    const timeoutId = setTimeout(() => controller.abort(), 2000)

    const response = await fetch(apiUrl, {
      // Disable caching to always get fresh messages
      cache: 'no-store',
      signal: controller.signal,
    })

    clearTimeout(timeoutId) // Clear timeout if fetch succeeds

    if (!response.ok) {
      throw new Error(`Backend responded with status: ${response.status}`)
    }

    const data: ApiResponse = await response.json()
    return { message: data.message, error: false }
  } catch (err) {
    console.error('Error fetching message from backend:', err)
    return {
      message: 'Unable to connect to backend service',
      error: true,
    }
  }
}

export default async function Home() {
  // Get location from environment variable
  const location = process.env.LOCATION || 'Unknown'

  // Fetch message from backend on the server
  const { message, error } = await getBackendMessage()

  return (
    <div className="App">
      <h1>cuddly-disco.ai</h1>
      <p className={error ? 'error-message' : 'success-message'}>
        For all the SRE/DevOps/Platform engineers out there, here are some kind words from <strong>{location}</strong>: {message}
      </p>
      <div className="advertisement">
        <p className="ad-title">🥛 Milk as a Service (MaaS)</p>
        <p className="ad-tagline">Cloud-native dairy delivered on demand</p>
        <p className="ad-features">✓ 99.9% uptime ✓ Auto-scaling freshness ✓ Enterprise support</p>
      </div>
    </div>
  )
}

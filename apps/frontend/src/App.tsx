import { useState, useEffect } from 'react'
import './App.css'

interface ApiResponse {
  message: string
}

function App() {
  const [apiMessage, setApiMessage] = useState<string>('Loading...')
  const [location, setLocation] = useState<string>('Unknown')
  const [error, setError] = useState<boolean>(false)

  useEffect(() => {
    // Get location from environment variable (injected at build/runtime)
    const envLocation = import.meta.env.VITE_LOCATION
    if (envLocation) {
      setLocation(envLocation)
    }

    // Fetch message from backend API
    const backendUrl = import.meta.env.VITE_BACKEND_URL || 'http://localhost:5000'

    fetch(`${backendUrl}/api/message`)
      .then(response => {
        if (!response.ok) {
          throw new Error('Network response was not ok')
        }
        return response.json()
      })
      .then((data: ApiResponse) => {
        setApiMessage(data.message)
        setError(false)
      })
      .catch(err => {
        console.error('Error fetching message:', err)
        setApiMessage('Unable to connect to backend service')
        setError(true)
      })
  }, [])

  return (
    <div className="App">
      <h1>cuddly-disco.ai</h1>
      <p className={error ? 'error-message' : 'success-message'}>
        For all the SREs out there, here are some kind words from <strong>{location}</strong>: {apiMessage}
      </p>
    </div>
  )
}

export default App

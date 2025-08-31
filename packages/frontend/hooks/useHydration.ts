import { useState, useEffect } from 'react'

export function useHydration() {
  const [isHydrated, setIsHydrated] = useState(false)

  useEffect(() => {
    // Ensure we're on the client
    if (typeof window !== 'undefined') {
      // Wait for next tick to ensure DOM is ready
      const timer = setTimeout(() => {
        setIsHydrated(true)
      }, 0)

      return () => clearTimeout(timer)
    }
  }, [])

  return isHydrated
}

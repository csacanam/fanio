"use client"

import { useEffect, useState } from 'react'

interface BodyWrapperProps {
  children: React.ReactNode
  className?: string
}

export function BodyWrapper({ children, className = '' }: BodyWrapperProps) {
  const [mounted, setMounted] = useState(false)

  useEffect(() => {
    setMounted(true)
    
    // Clean up any browser extension attributes that might cause hydration issues
    const body = document.body
    if (body) {
      // Remove problematic attributes that extensions might add
      const problematicAttrs = ['cz-shortcut-listen']
      problematicAttrs.forEach(attr => {
        if (body.hasAttribute(attr)) {
          body.removeAttribute(attr)
        }
      })
    }
  }, [])

  // Only render children after mounting to avoid hydration mismatch
  if (!mounted) {
    return <div className={className}>{children}</div>
  }

  return <div className={className}>{children}</div>
}

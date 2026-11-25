import { useCallback, useEffect, useRef, useState } from 'react'
import { errorMessage } from '../services/api'

export function useResource(load) {
  const [attempt, setAttempt] = useState(0)
  const [result, setResult] = useState(null)
  const reload = useCallback(() => setAttempt(value => value + 1), [])

  useEffect(() => {
    let active = true
    const settle = state => { if (active) setResult({ load, attempt, ...state }) }
    queueMicrotask(() => {
      if (active) void Promise.resolve().then(load).then(
        data => settle({ data, error: null }), error => settle({ data: null, error: errorMessage(error) }),
      )
    })
    return () => { active = false }
  }, [load, attempt])
  const current = result?.load === load && result.attempt === attempt
  return { pending: !current, data: current ? result.data : null, error: current ? result.error : null, reload }
}

export function useAction() {
  const lock = useRef(false)
  const [pending, setPending] = useState(false)
  const [error, setError] = useState(null)
  async function run(action) {
    if (lock.current) return
    lock.current = true
    setPending(true)
    setError(null)
    try {
      return await action()
    } catch (error) {
      setError(errorMessage(error, true))
    } finally {
      lock.current = false
      setPending(false)
    }
  }
  return { run, pending, error }
}

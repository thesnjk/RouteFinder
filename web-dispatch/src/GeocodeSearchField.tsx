import { useEffect, useRef, useState } from 'react'
import type { FleetApiClient } from './fleet/client'
import type { GeocodeSuggestion } from './fleet/types'

export interface GeocodedStop {
  label: string
  latitude: number
  longitude: number
}

interface GeocodeSearchFieldProps {
  label: string
  client: FleetApiClient
  value: GeocodedStop | null
  onChange: (stop: GeocodedStop | null) => void
  placeholder?: string
  disabled?: boolean
}

/** Debounced Pelias typeahead for fleet-proxy geocode search. */
export function GeocodeSearchField({
  label,
  client,
  value,
  onChange,
  placeholder,
  disabled,
}: GeocodeSearchFieldProps) {
  const [query, setQuery] = useState(value?.label ?? '')
  const [suggestions, setSuggestions] = useState<GeocodeSuggestion[]>([])
  const [open, setOpen] = useState(false)
  const [searching, setSearching] = useState(false)
  const [searchError, setSearchError] = useState<string | null>(null)
  const debounceRef = useRef<number | null>(null)
  const wrapRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    setQuery(value?.label ?? '')
  }, [value?.label])

  useEffect(() => {
    const onDocClick = (event: MouseEvent) => {
      if (!wrapRef.current?.contains(event.target as Node)) {
        setOpen(false)
      }
    }
    document.addEventListener('mousedown', onDocClick)
    return () => document.removeEventListener('mousedown', onDocClick)
  }, [])

  useEffect(() => {
    if (debounceRef.current != null) window.clearTimeout(debounceRef.current)
    const trimmed = query.trim()
    if (trimmed.length < 2) {
      setSuggestions([])
      setSearching(false)
      setSearchError(null)
      return
    }
    if (value && trimmed === value.label) {
      setSuggestions([])
      return
    }
    setSearching(true)
    debounceRef.current = window.setTimeout(() => {
      void (async () => {
        try {
          const results = await client.geocodeSearch(trimmed)
          setSuggestions(results)
          setOpen(results.length > 0)
          setSearchError(null)
        } catch (err) {
          setSuggestions([])
          setSearchError(err instanceof Error ? err.message : String(err))
        } finally {
          setSearching(false)
        }
      })()
    }, 300)
    return () => {
      if (debounceRef.current != null) window.clearTimeout(debounceRef.current)
    }
  }, [query, client, value])

  return (
    <div className="geocode-field" ref={wrapRef}>
      <label>
        {label}
        <input
          value={query}
          disabled={disabled}
          placeholder={placeholder}
          onChange={(e) => {
            setQuery(e.target.value)
            if (value) onChange(null)
          }}
          onFocus={() => {
            if (suggestions.length > 0) setOpen(true)
          }}
          autoComplete="off"
        />
      </label>
      {value ? (
        <p className="muted geocode-field__coords">
          {value.latitude.toFixed(5)}, {value.longitude.toFixed(5)}
        </p>
      ) : searching ? (
        <p className="muted">Searching…</p>
      ) : searchError ? (
        <p className="error geocode-field__error">{searchError}</p>
      ) : null}
      {open && suggestions.length > 0 ? (
        <ul className="geocode-field__suggestions">
          {suggestions.map((s) => (
            <li key={`${s.label}-${s.latitude}-${s.longitude}`}>
              <button
                type="button"
                onClick={() => {
                  onChange({
                    label: s.label,
                    latitude: s.latitude,
                    longitude: s.longitude,
                  })
                  setQuery(s.label)
                  setSuggestions([])
                  setOpen(false)
                }}
              >
                {s.label}
              </button>
            </li>
          ))}
        </ul>
      ) : null}
    </div>
  )
}

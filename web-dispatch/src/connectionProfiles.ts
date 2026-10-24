/** Named depot connection profiles for multi-org / hosted desk switching. */

export const LEGACY_CONNECTION_KEY = 'routefinder.webDispatch.connection'
export const PROFILES_STORAGE_KEY = 'routefinder.webDispatch.profiles'
export const DEFAULT_BASE_URL = '/fleet'

export interface DepotConnectionProfile {
  id: string
  name: string
  baseUrl: string
}

export interface ProfilesState {
  profiles: DepotConnectionProfile[]
  activeProfileId: string
}

function apiKeySessionKey(profileId: string): string {
  return `routefinder.webDispatch.apiKey.${profileId}`
}

function newId(): string {
  if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') {
    return crypto.randomUUID()
  }
  return `depot-${Date.now()}-${Math.random().toString(36).slice(2, 9)}`
}

function normalizeBaseUrl(raw: string | undefined): string {
  if (!raw) return DEFAULT_BASE_URL
  if (raw === 'http://127.0.0.1:8080' || raw === 'http://localhost:8080') {
    return DEFAULT_BASE_URL
  }
  return raw
}

/** Load profiles; migrates legacy single connection into “Default depot”. */
export function loadProfilesState(): ProfilesState {
  try {
    const raw = localStorage.getItem(PROFILES_STORAGE_KEY)
    if (raw) {
      const parsed = JSON.parse(raw) as ProfilesState
      if (
        Array.isArray(parsed.profiles) &&
        parsed.profiles.length > 0 &&
        typeof parsed.activeProfileId === 'string'
      ) {
        const active =
          parsed.profiles.find((p) => p.id === parsed.activeProfileId) ?? parsed.profiles[0]
        return {
          profiles: parsed.profiles.map((p) => ({
            ...p,
            baseUrl: normalizeBaseUrl(p.baseUrl),
          })),
          activeProfileId: active.id,
        }
      }
    }
  } catch {
    /* ignore */
  }

  let baseUrl = DEFAULT_BASE_URL
  let legacyApiKey = ''
  try {
    const legacy = localStorage.getItem(LEGACY_CONNECTION_KEY)
    if (legacy) {
      const parsed = JSON.parse(legacy) as { baseUrl?: string; apiKey?: string }
      baseUrl = normalizeBaseUrl(parsed.baseUrl)
      if (parsed.apiKey) legacyApiKey = parsed.apiKey
    }
  } catch {
    /* ignore */
  }
  try {
    const sessionRaw = sessionStorage.getItem(LEGACY_CONNECTION_KEY)
    if (sessionRaw) {
      const sessionParsed = JSON.parse(sessionRaw) as { apiKey?: string }
      if (sessionParsed.apiKey) legacyApiKey = sessionParsed.apiKey
    }
  } catch {
    /* ignore */
  }

  const id = newId()
  const state: ProfilesState = {
    profiles: [{ id, name: 'Default depot', baseUrl }],
    activeProfileId: id,
  }
  saveProfilesState(state)
  if (legacyApiKey) {
    setProfileApiKey(id, legacyApiKey)
  }
  try {
    localStorage.setItem(LEGACY_CONNECTION_KEY, JSON.stringify({ baseUrl }))
    sessionStorage.removeItem(LEGACY_CONNECTION_KEY)
  } catch {
    /* ignore */
  }
  return state
}

export function saveProfilesState(state: ProfilesState): void {
  localStorage.setItem(
    PROFILES_STORAGE_KEY,
    JSON.stringify({
      profiles: state.profiles,
      activeProfileId: state.activeProfileId,
    }),
  )
}

export function getProfileApiKey(profileId: string): string {
  try {
    return sessionStorage.getItem(apiKeySessionKey(profileId)) ?? ''
  } catch {
    return ''
  }
}

export function setProfileApiKey(profileId: string, apiKey: string): void {
  try {
    if (apiKey) {
      sessionStorage.setItem(apiKeySessionKey(profileId), apiKey)
    } else {
      sessionStorage.removeItem(apiKeySessionKey(profileId))
    }
  } catch {
    /* ignore */
  }
}

export function activeConnection(state: ProfilesState): {
  profile: DepotConnectionProfile
  apiKey: string
} {
  const profile =
    state.profiles.find((p) => p.id === state.activeProfileId) ?? state.profiles[0]
  return { profile, apiKey: getProfileApiKey(profile.id) }
}

export function upsertActiveProfile(
  state: ProfilesState,
  patch: { name?: string; baseUrl?: string },
): ProfilesState {
  const profiles = state.profiles.map((p) => {
    if (p.id !== state.activeProfileId) return p
    return {
      ...p,
      name: patch.name ?? p.name,
      baseUrl: patch.baseUrl != null ? normalizeBaseUrl(patch.baseUrl) : p.baseUrl,
    }
  })
  const next = { ...state, profiles }
  saveProfilesState(next)
  return next
}

export function addProfile(
  state: ProfilesState,
  name = 'New depot',
  baseUrl = DEFAULT_BASE_URL,
): ProfilesState {
  const id = newId()
  const next: ProfilesState = {
    profiles: [...state.profiles, { id, name, baseUrl: normalizeBaseUrl(baseUrl) }],
    activeProfileId: id,
  }
  saveProfilesState(next)
  return next
}

export function deleteProfile(state: ProfilesState, profileId: string): ProfilesState {
  if (state.profiles.length <= 1) return state
  const profiles = state.profiles.filter((p) => p.id !== profileId)
  const activeProfileId =
    state.activeProfileId === profileId ? profiles[0].id : state.activeProfileId
  try {
    sessionStorage.removeItem(apiKeySessionKey(profileId))
  } catch {
    /* ignore */
  }
  const next = { profiles, activeProfileId }
  saveProfilesState(next)
  return next
}

export function switchProfile(state: ProfilesState, profileId: string): ProfilesState {
  if (!state.profiles.some((p) => p.id === profileId)) return state
  const next = { ...state, activeProfileId: profileId }
  saveProfilesState(next)
  return next
}

/** Pure migrate helper for smoke tests (no storage). */
export function migrateLegacyConnection(
  legacy: { baseUrl?: string; apiKey?: string } | null,
): { profile: DepotConnectionProfile; apiKey: string } {
  const id = 'migrated-default'
  return {
    profile: {
      id,
      name: 'Default depot',
      baseUrl: normalizeBaseUrl(legacy?.baseUrl),
    },
    apiKey: legacy?.apiKey ?? '',
  }
}

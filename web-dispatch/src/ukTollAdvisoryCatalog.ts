/** Named UK toll / crossing advisory with optional static indicative £ (Swift parity). */
export interface UKTollAdvisory {
  id: string
  name: string
  latitude: number
  longitude: number
  approachRadiusMeters: number
  hint: string
  infoURL?: string | null
  indicativeCostGBP?: number | null
  indicativeCostNote?: string | null
}

/** Driver-facing “Indicative ~£X” line when a static £ is seeded. */
export function indicativeCostLabel(advisory: UKTollAdvisory): string | null {
  const amount = advisory.indicativeCostGBP
  if (amount == null) return null
  const formatted = `£${amount.toFixed(2)}`
  const note = advisory.indicativeCostNote?.trim()
  if (note) return `Indicative ~${formatted} (${note})`
  return `Indicative ~${formatted}`
}

/** Sum of non-nil indicative costs on matched advisories (planning total only). */
export function indicativeRouteTotalGBP(advisories: UKTollAdvisory[]): number | null {
  const amounts = advisories
    .map((a) => a.indicativeCostGBP)
    .filter((v): v is number => v != null)
  if (amounts.length === 0) return null
  return amounts.reduce((sum, v) => sum + v, 0)
}

/** Formatted route total, e.g. `Indicative tolls ~£18.00`. */
export function indicativeRouteTotalLabel(advisories: UKTollAdvisory[]): string | null {
  const total = indicativeRouteTotalGBP(advisories)
  if (total == null) return null
  return `Indicative tolls ~£${total.toFixed(2)}`
}

/**
 * Hand-authored UK toll / crossing points — mirrors Swift `UKTollAdvisoryCatalog.all`.
 * Indicative £ are static planning aids (not live tariffs).
 */
export const UK_TOLL_ADVISORY_CATALOG: UKTollAdvisory[] = [
  {
    id: 'm6-toll',
    name: 'M6 Toll',
    latitude: 52.65,
    longitude: -1.75,
    approachRadiusMeters: 4000,
    hint: 'Private motorway — class-based charges; tag or account.',
    infoURL: 'https://www.m6toll.co.uk/',
    indicativeCostGBP: 20.2,
    indicativeCostNote: 'indicative Class 4 2-axle HGV 3-zone day; check M6 Toll',
  },
  {
    id: 'dartford-crossing',
    name: 'Dartford Crossing',
    latitude: 51.464,
    longitude: 0.258,
    approachRadiusMeters: 3500,
    hint: 'Dart Charge — pay by midnight next day for most vehicles.',
    infoURL: 'https://www.gov.uk/dart-charge',
    indicativeCostGBP: 8.4,
    indicativeCostNote: 'indicative >2 axles day one-off; check GOV.UK',
  },
  {
    id: 'mersey-gateway',
    name: 'Mersey Gateway',
    latitude: 53.35,
    longitude: -2.73,
    approachRadiusMeters: 3000,
    hint: 'Merseyflow account or pay-as-you-go. Silver Jubilee Bridge free for most local traffic.',
    infoURL: 'https://www.merseyflow.co.uk/',
    indicativeCostGBP: 4.0,
    indicativeCostNote: 'indicative; check Merseyflow class',
  },
  {
    id: 'mersey-tunnels-queensway',
    name: 'Mersey Tunnel — Queensway',
    latitude: 53.392,
    longitude: -3.014,
    approachRadiusMeters: 2500,
    hint: 'Queensway (Birkenhead) A41 — both Mersey Tunnels charge; T-FLOW discounts available.',
    infoURL: 'https://www.merseytravel.gov.uk/tunnels/tolls-fees-and-charges/',
    indicativeCostGBP: 4.8,
    indicativeCostNote: 'indicative Class 2 2-axle HGV cash; check Merseytravel',
  },
  {
    id: 'mersey-tunnels-kingsway',
    name: 'Mersey Tunnel — Kingsway',
    latitude: 53.41,
    longitude: -3.02,
    approachRadiusMeters: 2500,
    hint: 'Kingsway (Wallasey) A59 — both Mersey Tunnels charge; T-FLOW discounts available.',
    infoURL: 'https://www.merseytravel.gov.uk/tunnels/tolls-fees-and-charges/',
    indicativeCostGBP: 4.8,
    indicativeCostNote: 'indicative Class 2 2-axle HGV cash; check Merseytravel',
  },
  {
    id: 'severn-crossings',
    name: 'Severn Bridge / Second Severn Crossing',
    latitude: 51.59,
    longitude: -2.7,
    approachRadiusMeters: 4000,
    hint: 'Severn Bridge tolls ended 2018 — free crossing. Historic entry retained for map context.',
    infoURL: 'https://www.gov.uk/government/news/severn-crossing-tolls-to-end',
  },
  {
    id: 'humber-bridge',
    name: 'Humber Bridge',
    latitude: 53.707,
    longitude: -0.45,
    approachRadiusMeters: 2500,
    hint: 'Tolled bridge — HGV class rates apply. Pay at plaza or check operator site.',
    infoURL: 'https://www.humberbridge.co.uk/',
    indicativeCostGBP: 5.0,
    indicativeCostNote: 'indicative; check Humber Bridge',
  },
  {
    id: 'tyne-tunnel',
    name: 'Tyne Tunnel',
    latitude: 54.986,
    longitude: -1.48,
    approachRadiusMeters: 2500,
    hint: 'TT2 account recommended for HGVs. Day rates vary by vehicle class.',
    infoURL: 'https://www.tt2.co.uk/',
    indicativeCostGBP: 5.2,
    indicativeCostNote: 'indicative Class 3 >3.5t one-way; check TT2',
  },
  {
    id: 'tamar-bridge',
    name: 'Tamar Bridge',
    latitude: 50.408,
    longitude: -4.204,
    approachRadiusMeters: 2000,
    hint: 'Toll westbound (into Cornwall). Check current HGV tariffs with the authority.',
    infoURL: 'https://www.tamarcrossings.org.uk/',
    indicativeCostGBP: 3.0,
    indicativeCostNote: 'westbound indicative; check authority',
  },
  {
    id: 'forth-road-bridge',
    name: 'Forth Road Bridge / Queensferry Crossing',
    latitude: 56.0,
    longitude: -3.4,
    approachRadiusMeters: 3500,
    hint: 'Queensferry Crossing is the main HGV route; Forth Road Bridge restricted. No toll on Queensferry.',
    infoURL: 'https://www.transport.gov.scot/',
  },
  {
    id: 'erksine-bridge',
    name: 'Erskine Bridge',
    latitude: 55.92,
    longitude: -4.46,
    approachRadiusMeters: 2000,
    hint: 'Scotland — free for most traffic; check any temporary restrictions.',
  },
  {
    id: 'clyde-tunnel',
    name: 'Clyde Tunnel',
    latitude: 55.86,
    longitude: -4.32,
    approachRadiusMeters: 1500,
    hint: 'Height/vehicle restrictions may apply — verify before routing HGV through tunnels.',
  },
  {
    id: 'blackwall-tunnel',
    name: 'Blackwall Tunnel',
    latitude: 51.503,
    longitude: 0.003,
    approachRadiusMeters: 2000,
    hint: 'Not a toll — height and HGV restrictions; Silvertown Tunnel may divert traffic.',
    infoURL: 'https://tfl.gov.uk/',
  },
  {
    id: 'silvertown-tunnel',
    name: 'Silvertown Tunnel',
    latitude: 51.502,
    longitude: 0.02,
    approachRadiusMeters: 2500,
    hint: 'User charge applies — check TfL for HGV rates and exemptions.',
    infoURL: 'https://tfl.gov.uk/modes/driving/silvertown-tunnel',
    indicativeCostGBP: 4.0,
    indicativeCostNote: 'indicative TfL user charge; check class',
  },
  {
    id: 'conwy-tunnel',
    name: 'Conwy Tunnel (A55)',
    latitude: 53.28,
    longitude: -3.83,
    approachRadiusMeters: 2000,
    hint: 'Free trunk road tunnel — height/ADR awareness; not a toll plaza.',
  },
  {
    id: 'durham-a1m',
    name: 'A1(M) Durham (historic toll context)',
    latitude: 54.78,
    longitude: -1.58,
    approachRadiusMeters: 3000,
    hint: 'No current toll on A1(M) Durham — catalog entry for corridor awareness only.',
  },
  {
    id: 'itchen-bridge',
    name: 'Itchen Bridge (Southampton)',
    latitude: 50.897,
    longitude: -1.385,
    approachRadiusMeters: 1500,
    hint: 'Local toll bridge — check Southampton City Council for current charges.',
    infoURL: 'https://www.southampton.gov.uk/',
    indicativeCostGBP: 1.0,
    indicativeCostNote: 'indicative local; check council',
  },
  {
    id: 'dunham-bridge',
    name: 'Dunham Bridge (A57)',
    latitude: 53.2611,
    longitude: -0.7729,
    approachRadiusMeters: 1500,
    hint: 'A57 Trent crossing — cash/card/prepay; free Christmas Day and Boxing Day.',
    infoURL: 'https://dunhambridge.co.uk/',
    indicativeCostGBP: 4.0,
    indicativeCostNote:
      'indicative 6+ wheel HGV inc VAT (SI 2026/806 £3.33 ex VAT from 1 Aug 2026); check operator',
  },
  {
    id: 'batheaston-bridge',
    name: 'Batheaston Bridge (Bathampton)',
    latitude: 51.4015,
    longitude: -2.3256,
    approachRadiusMeters: 1200,
    hint: 'GOV.UK A4 Batheaston/Bathampton toll — ≈4 t weight limit; unsuitable for many HGVs.',
    infoURL: 'https://www.gov.uk/uk-toll-roads',
  },
  {
    id: 'whitchurch-bridge',
    name: 'Whitchurch Bridge (Thames)',
    latitude: 51.487,
    longitude: -1.085,
    approachRadiusMeters: 1200,
    hint: 'Private toll bridge — weight limits; unsuitable for many HGVs.',
  },
]

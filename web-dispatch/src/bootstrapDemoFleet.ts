import type { FleetApiClient } from './fleet/client'
import type { FleetOrg, FleetVehicle } from './fleet/types'

/** Mac-parity demo org name (`DispatchViewModel.bootstrapDemoFleet`). */
export const DEMO_ORG_NAME = 'Demo Haulage Ltd'

/** Mac-parity demo vehicle label. */
export const DEMO_VEHICLE_LABEL = 'Artic 1'

/** Mac-parity demo registration plate. */
export const DEMO_VEHICLE_PLATE = 'AB12 CDE'

/** Prefer existing Demo Haulage Ltd org when present. */
export function pickDemoOrg(orgs: FleetOrg[]): FleetOrg | undefined {
  return orgs.find((o) => o.name === DEMO_ORG_NAME)
}

/** Prefer existing Artic 1 / AB12 CDE vehicle when present. */
export function pickDemoVehicle(vehicles: FleetVehicle[]): FleetVehicle | undefined {
  return vehicles.find(
    (v) =>
      v.label === DEMO_VEHICLE_LABEL ||
      (v.registrationPlate != null && v.registrationPlate === DEMO_VEHICLE_PLATE),
  )
}

export interface BootstrapDemoFleetResult {
  org: FleetOrg
  vehicle: FleetVehicle
}

/**
 * Idempotent Demo Haulage Ltd + Artic 1 bootstrap (Mac Dispatch parity).
 * Reuses existing org/vehicle when present; never deletes.
 */
export async function bootstrapDemoFleet(
  client: Pick<FleetApiClient, 'listOrgs' | 'createOrg' | 'listVehicles' | 'registerVehicle'>,
): Promise<BootstrapDemoFleetResult> {
  const orgs = await client.listOrgs()
  const org = pickDemoOrg(orgs) ?? (await client.createOrg(DEMO_ORG_NAME))
  const vehicles = await client.listVehicles(org.id)
  const existing = pickDemoVehicle(vehicles)
  const vehicle =
    existing ??
    (await client.registerVehicle({
      orgId: org.id,
      label: DEMO_VEHICLE_LABEL,
      registrationPlate: DEMO_VEHICLE_PLATE,
    }))
  return { org, vehicle }
}

#!/usr/bin/env bash
# Fleet LAN automated smoke — runs targeted Swift tests for HTTP, SSE, Bonjour, and E2E workflow.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ -z "${DEVELOPER_DIR:-}" ]]; then
  if [[ -d "/Users/admin/Downloads/Xcode-beta.app/Contents/Developer" ]]; then
    export DEVELOPER_DIR="/Users/admin/Downloads/Xcode-beta.app/Contents/Developer"
  elif [[ -d "/Applications/Xcode.app/Contents/Developer" ]]; then
    export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
  fi
fi

cd "${PACKAGE_DIR}"

TESTS=(
  httpFleetStoreSyncsTripsOverLANServer
  fleetStoreFactoryUsesDiskStoreByDefault
  fleetStoreFactoryUsesHTTPStoreWhenRemoteEnabled
  fleetSSEClientReceivesTripPushedEvent
  fleetSSEEndpointRejectsMissingAPIKeyWhenConfigured
  fleetSSEConnectionSurvivesHeartbeatInterval
  fleetBonjour
  createAndPushTripAssignsStopRoles
  fleetE2EWorkflowPushSnapshotAndSSE
  fleetCreateAndPushTripRoundTripsJobBrief
  fleetProxyStatusReportsORSConfigured
  fleetTelematicsIngestPersists
  fleetTelematicsIngestViaHTTP
  applySnapshotMergesDriverGPSOntoTrip
)

echo "RouteFinder fleet E2E smoke"
echo "Package: ${PACKAGE_DIR}"
if [[ -n "${DEVELOPER_DIR:-}" ]]; then
  echo "DEVELOPER_DIR: ${DEVELOPER_DIR}"
fi
echo ""

failed=0
passed=0

for test_name in "${TESTS[@]}"; do
  echo "▶ swift test --filter ${test_name}"
  if swift test --filter "${test_name}"; then
    passed=$((passed + 1))
  else
    echo "✗ FAILED: ${test_name}"
    failed=$((failed + 1))
  fi
  echo ""
done

echo "────────────────────────────────────"
echo "Passed filters: ${passed}/${#TESTS[@]}"
if [[ "${failed}" -gt 0 ]]; then
  echo "Fleet E2E smoke FAILED (${failed} filter group(s))"
  exit 1
fi
echo "Fleet E2E smoke PASSED"
exit 0

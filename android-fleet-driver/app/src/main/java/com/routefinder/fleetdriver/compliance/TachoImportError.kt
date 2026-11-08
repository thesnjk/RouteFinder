package com.routefinder.fleetdriver.compliance

/** Errors raised while importing driver-card exports. Mirrors iOS ``TachoImportError``. */
sealed class TachoImportError(message: String) : Exception(message) {
    /** Binary DDD was not recognized and no JSON sidecar / fixture was available. */
    data object UnrecognizedBinaryDDD : TachoImportError(
        "Full binary DDD parse requires partner SDK; drop a JSON export with remainingDriveSeconds",
    )

    /** Payload was not valid JSON for the advisory import schema. */
    data object InvalidJSON : TachoImportError(
        "Could not parse tachograph export as JSON.",
    )

    /** JSON was present but required remaining-time keys were missing. */
    data object MissingRequiredFields : TachoImportError(
        "Tachograph JSON is missing required remaining drive fields.",
    )

    /** Partner remote tacho integration has not been configured. */
    data object PartnerNotConfigured : TachoImportError(
        "Partner tachograph integration is not configured.",
    )
}

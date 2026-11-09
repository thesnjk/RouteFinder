package com.routefinder.fleetdriver.fleet

/**
 * RegCheck-first then DVLA VES fallback for plate → dims / weight.
 * Mirrors iOS ``VehicleRegistryCoordinator`` network chain (no heuristic synthesizer).
 */
object VehicleRegistrationResolver {
    enum class Source { REG_CHECK, DVLA }

    data class Result(
        val heightMeters: Double?,
        val weightTonnes: Double?,
        val widthMeters: Double?,
        val lengthMeters: Double?,
        val source: Source,
    )

    /**
     * Looks up [registration] via RegCheck when [regCheckUsername] is set,
     * then DVLA when [dvlaApiKey] is set and RegCheck missed or lacked weight/dims.
     */
    fun resolve(
        registration: String,
        regCheckUsername: String?,
        dvlaApiKey: String?,
        regCheckLookup: (String) -> RegCheckClient.Spec? = { plate ->
            val user = regCheckUsername?.trim().orEmpty()
            if (user.isEmpty()) null else RegCheckClient(user).lookup(plate)
        },
        dvlaLookup: (String) -> DvlaVehicleEnquiryClient.Spec? = { plate ->
            val key = dvlaApiKey?.trim().orEmpty()
            if (key.isEmpty()) null else DvlaVehicleEnquiryClient(key).lookup(plate)
        },
    ): Result? {
        val plate = registration.replace("\\s+".toRegex(), "").uppercase()
        if (plate.isEmpty()) return null

        val reg = if (!regCheckUsername.isNullOrBlank()) {
            runCatching { regCheckLookup(plate) }.getOrNull()
        } else {
            null
        }
        if (reg != null && hasUsableDims(reg.heightMeters, reg.weightTonnes, reg.widthMeters, reg.lengthMeters)) {
            return Result(
                heightMeters = reg.heightMeters,
                weightTonnes = reg.weightTonnes,
                widthMeters = reg.widthMeters,
                lengthMeters = reg.lengthMeters,
                source = Source.REG_CHECK,
            )
        }

        val dvla = if (!dvlaApiKey.isNullOrBlank()) {
            runCatching { dvlaLookup(plate) }.getOrNull()
        } else {
            null
        }
        if (dvla != null &&
            hasUsableDims(dvla.heightMeters, dvla.weightTonnes, dvla.widthMeters, dvla.lengthMeters)
        ) {
            return Result(
                heightMeters = dvla.heightMeters ?: reg?.heightMeters,
                weightTonnes = dvla.weightTonnes ?: reg?.weightTonnes,
                widthMeters = dvla.widthMeters ?: reg?.widthMeters,
                lengthMeters = dvla.lengthMeters ?: reg?.lengthMeters,
                source = Source.DVLA,
            )
        }

        // Partial RegCheck (e.g. weight-only) still useful.
        if (reg != null &&
            hasUsableDims(reg.heightMeters, reg.weightTonnes, reg.widthMeters, reg.lengthMeters)
        ) {
            return Result(
                heightMeters = reg.heightMeters,
                weightTonnes = reg.weightTonnes,
                widthMeters = reg.widthMeters,
                lengthMeters = reg.lengthMeters,
                source = Source.REG_CHECK,
            )
        }
        return null
    }

    private fun hasUsableDims(
        height: Double?,
        weight: Double?,
        width: Double?,
        length: Double?,
    ): Boolean =
        (height != null && height > 0) ||
            (weight != null && weight > 0) ||
            (width != null && width > 0) ||
            (length != null && length > 0)
}

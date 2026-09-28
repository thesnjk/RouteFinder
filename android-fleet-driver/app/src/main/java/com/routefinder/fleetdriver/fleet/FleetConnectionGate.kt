package com.routefinder.fleetdriver.fleet

/**
 * Shared Connected rule for wizard Test, C2 nav badge, and C1 home.
 * Requires public `/health` **and** a successful auth probe — never green on health alone
 * when the server uses `--api-key`.
 */
object FleetConnectionGate {
    /** Whether the UI may show Connected. */
    fun isConnected(healthOk: Boolean, authSucceeded: Boolean): Boolean =
        healthOk && authSucceeded

    /**
     * Operator-facing status string.
     *
     * @param authErrorMessage failure text from [FleetApi.verifyAuthenticatedAccess], if any
     */
    fun statusLabel(
        healthOk: Boolean,
        authSucceeded: Boolean,
        authErrorMessage: String? = null,
    ): String {
        if (isConnected(healthOk, authSucceeded)) return "Connected"
        if (healthOk && !authSucceeded) {
            val detail = authErrorMessage?.trim()?.takeIf { it.isNotEmpty() }
                ?: "Fleet API key rejected. Check the shared key with the operator."
            return "Auth failed · $detail"
        }
        return "Offline"
    }

    /**
     * C1 / C2 / wizard badge headline.
     *
     * Always prefer [statusLabel] so Auth failed is never collapsed to Offline.
     */
    fun badgeTitle(statusLabel: String): String = statusLabel
}

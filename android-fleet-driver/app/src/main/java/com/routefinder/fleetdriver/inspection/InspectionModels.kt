package com.routefinder.fleetdriver.inspection

import java.time.Instant

/** DVSA-style walkaround zone (mirrors iOS InspectionZone). */
enum class InspectionZone(val label: String) {
    LIGHTS("Lights"),
    TYRES("Tyres"),
    BRAKES("Brakes"),
    BODY("Body / trailer"),
    MIRRORS("Mirrors / glass"),
    FLUIDS("Fluids / leaks"),
    LOAD("Load security"),
}

enum class InspectionItemStatus {
    PASS,
    DEFECT,
    NOT_APPLICABLE,
}

data class InspectionChecklistItem(
    val zone: InspectionZone,
    val label: String,
    var status: InspectionItemStatus = InspectionItemStatus.NOT_APPLICABLE,
    var note: String = "",
    /** Optional JPEG/PNG base64 for defect evidence (size-budgeted on capture). */
    var photoBase64: String? = null,
)

data class InspectionSummary(
    val vehicleLabel: String,
    val registrationPlate: String?,
    val defectCount: Int,
    val completedAt: String,
    val photoCount: Int = 0,
)

object InspectionChecklistFactory {
    fun defaultItems(): List<InspectionChecklistItem> = listOf(
        InspectionChecklistItem(InspectionZone.LIGHTS, "Headlights / sidelights"),
        InspectionChecklistItem(InspectionZone.LIGHTS, "Indicators / hazards"),
        InspectionChecklistItem(InspectionZone.TYRES, "Tyre condition / pressure"),
        InspectionChecklistItem(InspectionZone.BRAKES, "Service brake feel"),
        InspectionChecklistItem(InspectionZone.BODY, "Bodywork / curtains"),
        InspectionChecklistItem(InspectionZone.MIRRORS, "Mirrors / windscreen"),
        InspectionChecklistItem(InspectionZone.FLUIDS, "Oil / coolant leaks"),
        InspectionChecklistItem(InspectionZone.LOAD, "Load security / straps"),
    )

    fun summary(
        items: List<InspectionChecklistItem>,
        vehicleLabel: String,
        registrationPlate: String?,
    ): InspectionSummary {
        val defects = items.count { it.status == InspectionItemStatus.DEFECT }
        val photos = items.count { !it.photoBase64.isNullOrBlank() }
        return InspectionSummary(
            vehicleLabel = vehicleLabel,
            registrationPlate = registrationPlate,
            defectCount = defects,
            completedAt = Instant.now().toString(),
            photoCount = photos,
        )
    }

    fun allZonesReviewed(items: List<InspectionChecklistItem>): Boolean =
        items.none { it.status == InspectionItemStatus.NOT_APPLICABLE }
}

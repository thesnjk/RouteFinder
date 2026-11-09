package com.routefinder.fleetdriver.nav

import android.app.Application
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.routefinder.fleetdriver.compliance.CanIDriveEvaluator
import com.routefinder.fleetdriver.compliance.CanIDriveStatus
import com.routefinder.fleetdriver.compliance.DddImporter
import com.routefinder.fleetdriver.compliance.FuelCardMatcher
import com.routefinder.fleetdriver.compliance.FuelCardProvider
import com.routefinder.fleetdriver.compliance.FuelPoiCatalogClient
import com.routefinder.fleetdriver.compliance.WeighStationAhead
import com.routefinder.fleetdriver.compliance.HosAdvisoryClock
import com.routefinder.fleetdriver.compliance.HosRestCandidate
import com.routefinder.fleetdriver.compliance.HosRestCandidateKind
import com.routefinder.fleetdriver.compliance.HosRestInsertionResult
import com.routefinder.fleetdriver.compliance.HosRestInserter
import com.routefinder.fleetdriver.compliance.LaybyAdvisoryEngine
import com.routefinder.fleetdriver.compliance.LaybyAlertFormatter
import com.routefinder.fleetdriver.compliance.LaybyCatalogClient
import com.routefinder.fleetdriver.compliance.LaybyOccupancyKind
import com.routefinder.fleetdriver.compliance.LaybyOccupancyStore
import com.routefinder.fleetdriver.compliance.LezAvoidPolicy
import com.routefinder.fleetdriver.compliance.PartnerTachoAdvisory
import com.routefinder.fleetdriver.compliance.ParkingAvailabilityTier
import com.routefinder.fleetdriver.compliance.ParkingBookPartner
import com.routefinder.fleetdriver.compliance.PendingParkingBookReturn
import com.routefinder.fleetdriver.compliance.TachoCardSummary
import com.routefinder.fleetdriver.compliance.TachoImportError
import com.routefinder.fleetdriver.compliance.TruckFuelPoi
import com.routefinder.fleetdriver.compliance.UkLezCatalog
import com.routefinder.fleetdriver.map.HazardOverlayBuilder
import com.routefinder.fleetdriver.map.ParkingMapMarker
import com.routefinder.fleetdriver.map.ParkingMapMarkerBuilder
import android.content.Context
import android.net.Uri
import android.provider.OpenableColumns
import java.io.File
import com.routefinder.fleetdriver.fleet.FleetApi
import com.routefinder.fleetdriver.fleet.FleetConnectionGate
import com.routefinder.fleetdriver.fleet.FleetPreferences
import com.routefinder.fleetdriver.fleet.FleetSseClient
import com.routefinder.fleetdriver.fleet.FleetTrip
import com.routefinder.fleetdriver.fleet.FleetVehicleProfile
import com.routefinder.fleetdriver.fleet.InspectionMediaBudget
import com.routefinder.fleetdriver.fleet.JobIntakeHandler
import com.routefinder.fleetdriver.fleet.TelematicsCSVImporter
import com.routefinder.fleetdriver.fleet.TelematicsCSVImporterError
import com.routefinder.fleetdriver.fleet.TelematicsImportBatch
import com.routefinder.fleetdriver.fleet.TelematicsProvider
import com.routefinder.fleetdriver.fleet.VehicleRegistrationResolver
import com.routefinder.fleetdriver.hazard.CrowdReport
import com.routefinder.fleetdriver.hazard.CrowdReportStillTherePrompt
import com.routefinder.fleetdriver.hazard.HazardAheadAnnouncement
import com.routefinder.fleetdriver.hazard.HazardAheadFormatter
import com.routefinder.fleetdriver.hazard.HazardEvent
import com.routefinder.fleetdriver.hazard.HazardEventType
import com.routefinder.fleetdriver.hazard.LocalCrowdEventStore
import com.routefinder.fleetdriver.physics.KineticGradientAnalyzer
import com.routefinder.fleetdriver.fleet.SseConnectionState
import com.routefinder.fleetdriver.fleet.formatTimeWindowLines
import com.routefinder.fleetdriver.fleet.needsRegistrationLookup
import com.routefinder.fleetdriver.fleet.toHgvVehicleProfile
import com.routefinder.fleetdriver.inspection.InspectionChecklistFactory
import com.routefinder.fleetdriver.inspection.InspectionChecklistItem
import com.routefinder.fleetdriver.inspection.InspectionReportPdfRenderer
import com.routefinder.fleetdriver.inspection.InspectionSummary
import com.routefinder.fleetdriver.physics.RouteRehearsalEngine
import com.routefinder.fleetdriver.routing.FleetOrsConfig
import com.routefinder.fleetdriver.routing.GeocodeSuggestion
import com.routefinder.fleetdriver.routing.HgvVehicleProfile
import com.routefinder.fleetdriver.routing.LatLon
import com.routefinder.fleetdriver.routing.OrsResponseParser
import com.routefinder.fleetdriver.routing.OrsRoutingClient
import com.routefinder.fleetdriver.routing.PeliasGeocoder
import com.routefinder.fleetdriver.routing.TollAdvisoryAlongRouteMatcher
import com.routefinder.fleetdriver.routing.UKTollAdvisory
import com.routefinder.fleetdriver.voice.DriverVoiceCommand
import com.routefinder.fleetdriver.voice.DriverVoiceCommandCoordinator
import com.routefinder.fleetdriver.voice.VoiceAssistResponseFormatter
import com.routefinder.fleetdriver.voice.VoiceGuidanceService
import java.time.Instant
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject

data class WaypointState(
    val label: String = "",
    val latitude: Double? = null,
    val longitude: Double? = null,
) {
    val isResolved: Boolean get() = latitude != null && longitude != null
}

/**
 * Orchestrates geocode, ORS HGV routing via fleet proxy, navigation, SSE trips, and rehearsal.
 */
class NavigationViewModel(application: Application) : AndroidViewModel(application) {
    val prefs = FleetPreferences(application)

    var origin by mutableStateOf(WaypointState())
    var destination by mutableStateOf(WaypointState())
    var originSuggestions by mutableStateOf<List<GeocodeSuggestion>>(emptyList())
    var destinationSuggestions by mutableStateOf<List<GeocodeSuggestion>>(emptyList())

    var isCalculating by mutableStateOf(false)
    var isRehearsing by mutableStateOf(false)
    var errorMessage by mutableStateOf<String?>(null)
    var toastMessage by mutableStateOf<String?>(null)
    var connected by mutableStateOf(false)
    var orsConfigured by mutableStateOf(false)
    var tomTomProxyConfigured by mutableStateOf(false)
    var openWeatherProxyConfigured by mutableStateOf(false)
    var sseLabel by mutableStateOf("SSE idle")
    var statusLabel by mutableStateOf("Idle")

    val session = NavigationSession()
    var routeCoordinates by mutableStateOf<List<LatLon>>(emptyList())
    var phase by mutableStateOf(NavigationPhase.IDLE)
    var progress by mutableStateOf<NavigationProgress?>(null)
    /** Active turn instruction (lane strip + TTS). */
    var currentInstruction by mutableStateOf<TurnInstruction?>(null)
    var distanceLabel by mutableStateOf<String?>(null)
    var etaLabel by mutableStateOf<String?>(null)
    var physicsEtaLabel by mutableStateOf<String?>(null)

    var activeTrip by mutableStateOf<FleetTrip?>(null)
    var followLat by mutableStateOf<Double?>(null)
    var followLon by mutableStateOf<Double?>(null)
    /** Override dims from RegCheck when trip profile is empty. */
    private var intakeVehicleProfile by mutableStateOf<FleetVehicleProfile?>(null)
    var primaryRiskAdvisory by mutableStateOf<PredictiveRiskEngine.Advisory?>(null)
    /** Read-only dispatch time window lines for the status card. */
    var timeWindowLines by mutableStateOf<List<String>>(emptyList())
    var showWalkaround by mutableStateOf(false)
    var walkaroundItems by mutableStateOf(InspectionChecklistFactory.defaultItems())
    var lastInspectionSummary by mutableStateOf<InspectionSummary?>(null)
    /** When true, Compose shows the local crowd hazard report sheet. */
    var presentHazardReportSheet by mutableStateOf(false)
    /** Waze-style still-there prompt ~45s after a crowd report (iOS parity). */
    var pendingStillTherePrompt by mutableStateOf<CrowdReportStillTherePrompt?>(null)
    /** GeoJSON FeatureCollection for MapLibre crowd hazard pins. */
    var hazardOverlayGeoJson by mutableStateOf(HazardOverlayBuilder.EMPTY_FEATURE_COLLECTION)
    private var lastKineticMessage: String? = null
    private var lastTrafficMessage: String? = null
    private var lastHazardMessage: String? = null
    private var lastHazardSevere: Boolean = false
    /** Real remaining meters for the active hazard (live TomTom or crawl fallback). */
    private var lastHazardDistanceMeters: Double? = null
    /** True when [lastHazardMessage] came from TomTom live sampling (Ph36). */
    private var liveTomTomHazardActive: Boolean = false
    private var lastTomTomHazardSampleMs: Long? = null
    private var liveTomTomHazardArcMeters: Double? = null
    private var crowdHazardMessage: String? = null
    private var crowdHazardDistanceMeters: Double? = null
    private var crowdHazardSevere: Boolean = false
    private var lastAnnouncedCrowdHazardId: String? = null
    private var crowdReports: List<CrowdReport> = emptyList()
    /** In-memory confirm pins from still-there answers (merged into overlay). */
    private var confirmedCrowdHazards: List<HazardEvent> = emptyList()
    private var stillTherePromptJob: Job? = null
    private var lastRoadworksMessage: String? = null
    private var lastRoadworksDistanceMeters: Double? = null
    /** Overpass construction sites projected onto the active route. */
    private var catalogRoadworkSites: List<RoadworkSite> = emptyList()
    private var lastWeatherMessage: String? = null
    private var cachedForecastItems: List<PredictiveRiskEngine.Advisory> = emptyList()
    private var cachedClearanceItems: List<PredictiveRiskEngine.Advisory> = emptyList()
    private var cachedOffRouteClearanceItems: List<PredictiveRiskEngine.Advisory> = emptyList()
    private var lastForecastRiskRefreshMs: Long? = null
    private var lastOffRouteClearanceMs: Long = 0L
    private var lastRiskRefreshMs: Long = 0L
    private var lastKnownBearingDegrees: Double? = null
    var regCheckUsernameDraft by mutableStateOf(prefs.regCheckUsername)
    /** Operator-supplied GOV.UK DVLA VES key (optional RegCheck fallback). */
    var dvlaApiKeyDraft by mutableStateOf(prefs.dvlaApiKey)
    var tomTomApiKeyDraft by mutableStateOf(prefs.tomTomApiKey)
    var openWeatherApiKeyDraft by mutableStateOf(prefs.openWeatherApiKey)
    var clearanceRadarEnabled by mutableStateOf(prefs.clearanceRadarEnabled)
    var lezAvoidEnabled by mutableStateOf(prefs.lezAvoidEnabled)
    /** When true, ORS directions request avoids tollways. */
    var avoidTolls by mutableStateOf(prefs.avoidTolls)
    /** Selected UK fuel card for OSM brand ahead matching (Ph32 parity). */
    var fuelCardProvider by mutableStateOf(FuelCardProvider.fromRaw(prefs.fuelCardProvider))
    /** Corridor truck POIs (fuel / weigh / parking) for the active route (OSM). */
    private var catalogTruckPois: List<TruckFuelPoi> = emptyList()
    /** Fuel subset of [catalogTruckPois] for card matching. */
    private val catalogFuelPois: List<TruckFuelPoi>
        get() = catalogTruckPois.filter { it.kind == TruckFuelPoi.Kind.HIGH_FLOW_DIESEL }
    /** Banner when ahead fuel stops match the selected card (OSM brand — not live prices). */
    var fuelCardBannerMessage by mutableStateOf<String?>(null)
        private set
    /** Banner when weighbridges are on the corridor (OSM — not DVSA / PrePass). */
    var weighStationBannerMessage by mutableStateOf<String?>(null)
        private set
    /** Last telematics CSV batch (local); upload pushes to fleet ingest. */
    var telematicsImportBatch by mutableStateOf<TelematicsImportBatch?>(null)
        private set
    /** Telematics import / upload status or error (read-only — not legal VU). */
    var telematicsStatusMessage by mutableStateOf<String?>(null)
        private set
    var emissionClassDraft by mutableStateOf(prefs.emissionClass)
    /** Trailer count draft for solo / override routing (0…3). */
    var trailerCountDraft by mutableStateOf(1)
    /** Overall bumper-to-bumper length draft (metres) for solo routing. */
    var lengthMetersDraft by mutableStateOf(16.5)
    var lezAdvisoryMessage by mutableStateOf<String?>(null)
    var laybyAdvisoryMessage by mutableStateOf<String?>(null)
    /** Structured layby ahead with parking availability tier. */
    var laybyAdvisory by mutableStateOf<LaybyAdvisoryEngine.Advisory?>(null)
    /** Colored parking / layby markers for the MapLibre canvas (crowd/prior — not live bays). */
    var parkingMapMarkers by mutableStateOf<List<ParkingMapMarker>>(emptyList())
        private set
    /** Pending TRAVIS/SNAP book redirect for app-side return-to-nav. */
    var pendingParkingBookReturn by mutableStateOf<PendingParkingBookReturn?>(null)
        private set
    /** When true, show the resume banner after returning from a partner book site. */
    var showParkingBookResumeBanner by mutableStateOf(false)
        private set
    /** Selected ahead parking marker for the map book sheet. */
    var selectedParkingBookStop by mutableStateOf<PendingParkingBookReturn?>(null)
        private set
    var hosAdvisoryMessage by mutableStateOf<String?>(null)
    /** Advisory HOS rest forecast summary for the active route (planning aid — not legal VU). */
    var hosForecastSummary by mutableStateOf<String?>(null)
        private set
    /** Last HOS rest forecast (for Break Now POI preference). */
    private var hosForecast: HosRestInsertionResult? = null
    /** Fused Can-I-drive status (partner → imported card → clock when fresh). */
    var canIDriveStatus by mutableStateOf<CanIDriveStatus?>(null)
    private var partnerTachoAdvisory by mutableStateOf<PartnerTachoAdvisory?>(null)
    /** Last local JSON / DDD-sidecar import (advisory; planning aid only). */
    var importedTachoSummary by mutableStateOf<TachoCardSummary?>(null)
        private set
    /** User-facing message when a tacho file import fails. */
    var tachoImportError by mutableStateOf<String?>(null)
        private set
    private val tachoImporter = DddImporter()
    /** Named UK toll advisories matched to the active route polyline. */
    var routeTollAdvisories by mutableStateOf<List<UKTollAdvisory>>(emptyList())
    /** Near-horizon toll banner (within ~5 km). */
    var activeTollAdvisory by mutableStateOf<UKTollAdvisory?>(null)
    var activeTollDistanceMeters by mutableStateOf<Double?>(null)
    /** Route-summary toll line (names + optional indicative total). */
    var tollSummaryMessage by mutableStateOf<String?>(null)
    var lastWalkaroundPdfBytes by mutableStateOf<ByteArray?>(null)
    /** True when turn-by-turn TTS is muted (voice assist still speaks confirmations). */
    var voiceGuidanceMuted by mutableStateOf(!prefs.voiceGuidanceEnabled)
    /** When true, proactive layby TTS fires inside ~5 km. */
    var laybyVoiceAlertsEnabled by mutableStateOf(prefs.laybyVoiceAlertsEnabled)
    /** True while push-to-talk listen window is active. */
    var voiceListening by mutableStateOf(false)
    private var continuousDriveSeconds = prefs.continuousDriveSeconds
    private var dailyDriveSeconds = prefs.dailyDriveSeconds
    private var lastDriveTickMs: Long = 0L
    /** ORS total duration for the active route (seconds) — used for HOS path split. */
    private var lastRouteDurationSeconds: Double = 0.0
    /** Skip count for “next layby” voice advances on the current route. */
    private var laybySkipCount = 0
    /** Overpass corridor sites for the active route; empty → seed fallback. */
    private var catalogLaybySites: List<LaybyAdvisoryEngine.Site> = emptyList()
    /** Last layby site id announced via proactive TTS (dedupe until site/route changes). */
    private var lastAnnouncedLaybyId: String? = null
    /** Signature of the last commit-time toll TTS (dedupe across compliance refreshes). */
    private var lastAnnouncedTollRouteSignature: String? = null

    private val voice = VoiceGuidanceService(application)
    private val voiceCommands = DriverVoiceCommandCoordinator(application)
    private val laybyOccupancyStore = LaybyOccupancyStore(
        application.getSharedPreferences("rf_layby_occupancy", Context.MODE_PRIVATE),
    )
    private val crowdEventStore = LocalCrowdEventStore(
        File(application.filesDir, "crowd-reports/reports.json"),
    )
    private var sseJob: Job? = null
    private var healthJob: Job? = null
    private var gpsJob: Job? = null
    private var searchJob: Job? = null
    private var voiceListenJob: Job? = null

    init {
        voice.enabled = prefs.voiceGuidanceEnabled
        voiceGuidanceMuted = !prefs.voiceGuidanceEnabled
        crowdReports = crowdEventStore.allReports()
        rebuildHazardOverlay()
        loadPersistedTachoSummary()
        refreshCanIDriveFromLocalSources()
        if (prefs.isPaired()) {
            startFleetLoops()
        }
    }

    /** Opens the on-device crowd hazard report sheet. */
    fun openHazardReportSheet() {
        presentHazardReportSheet = true
    }

    fun dismissHazardReportSheet() {
        presentHazardReportSheet = false
    }

    /** Submits a local crowd hazard at follow/route position (on-device only). */
    fun submitCrowdHazardReport(type: HazardEventType, note: String?) {
        val lat = followLat ?: routeCoordinates.firstOrNull()?.latitude ?: return
        val lon = followLon ?: routeCoordinates.firstOrNull()?.longitude ?: return
        val report = CrowdReport(
            latitude = lat,
            longitude = lon,
            type = type,
            reporterId = "local-driver",
            note = note,
        )
        crowdEventStore.submit(report)
        crowdReports = crowdEventStore.allReports()
        rebuildHazardOverlay()
        presentHazardReportSheet = false
        toastMessage = "Hazard reported on-device"
        val arc = progress?.traveledDistanceMeters ?: 0.0
        refreshCrowdHazardAhead(arc)
        refreshPredictiveRisk()
        scheduleStillTherePrompt(report)
    }

    /**
     * Confirms or dismisses a still-there crowd prompt.
     * Cleared only dismisses the dialog (does not delete the original report).
     */
    fun resolveStillTherePrompt(stillPresent: Boolean) {
        val prompt = pendingStillTherePrompt
        pendingStillTherePrompt = null
        if (!stillPresent || prompt == null) return
        val lat = followLat ?: routeCoordinates.firstOrNull()?.latitude ?: return
        val lon = followLon ?: routeCoordinates.firstOrNull()?.longitude ?: return
        val confirm = CrowdReportStillTherePrompt.confirmHazard(
            prompt = prompt,
            latitude = lat,
            longitude = lon,
        )
        confirmedCrowdHazards = confirmedCrowdHazards + confirm
        rebuildHazardOverlay()
    }

    private fun scheduleStillTherePrompt(report: CrowdReport) {
        stillTherePromptJob?.cancel()
        stillTherePromptJob = viewModelScope.launch {
            delay(CrowdReportStillTherePrompt.PROMPT_DELAY_MS)
            if (!isActive) return@launch
            if (routeCoordinates.size < 2) return@launch
            pendingStillTherePrompt = CrowdReportStillTherePrompt(
                id = report.id,
                reportType = report.type,
                message = CrowdReportStillTherePrompt.message(report.note, report.type),
            )
        }
    }

    private fun cancelStillTherePrompt() {
        stillTherePromptJob?.cancel()
        stillTherePromptJob = null
        pendingStillTherePrompt = null
        confirmedCrowdHazards = emptyList()
    }

    /** Imports a driver-card JSON / DDD file (sidecar JSON preferred for opaque binaries). */
    fun importTacho(uri: Uri) {
        viewModelScope.launch {
            tachoImportError = null
            val result = withContext(Dispatchers.IO) {
                runCatching {
                    val app = getApplication<Application>()
                    val name = displayNameFor(uri) ?: "import"
                    val bytes = app.contentResolver.openInputStream(uri)?.use { it.readBytes() }
                        ?: throw TachoImportError.InvalidJSON
                    tachoImporter.importDriverCard(data = bytes, sourceFileName = name)
                }
            }
            result.fold(
                onSuccess = { summary ->
                    importedTachoSummary = summary
                    persistTachoSummary(summary)
                    refreshCanIDriveFromLocalSources()
                    toastMessage = "Imported tacho: ${summary.sourceFileName}"
                },
                onFailure = { error ->
                    tachoImportError = error.message ?: "Could not import tachograph file."
                },
            )
        }
    }

    /** Clears the imported tachograph summary and refreshes Can-I-drive. */
    fun clearImportedTacho() {
        importedTachoSummary = null
        tachoImportError = null
        removePersistedTachoSummary()
        refreshCanIDriveFromLocalSources()
    }

    /** Parses a Geotab/Samsara-style telematics CSV (local only until upload). */
    fun importTelematicsCSV(uri: Uri) {
        viewModelScope.launch {
            telematicsStatusMessage = null
            val result = withContext(Dispatchers.IO) {
                runCatching {
                    val app = getApplication<Application>()
                    val name = displayNameFor(uri) ?: "export.csv"
                    val text = app.contentResolver.openInputStream(uri)?.use {
                        it.bufferedReader().readText()
                    } ?: throw TelematicsCSVImporterError.EmptyFile()
                    TelematicsCSVImporter.parseBatch(
                        text = text,
                        sourceFileName = name,
                        defaultProvider = TelematicsProvider.UNKNOWN,
                    )
                }
            }
            result.fold(
                onSuccess = { batch ->
                    telematicsImportBatch = batch
                    telematicsStatusMessage =
                        "Parsed ${batch.pings.size} ping(s) from ${batch.sourceFileName ?: "CSV"}"
                    toastMessage = telematicsStatusMessage
                },
                onFailure = { error ->
                    telematicsStatusMessage = error.message ?: "Could not import telematics CSV."
                },
            )
        }
    }

    /** POSTs the last CSV batch to fleet `POST /v1/telematics/ingest` (desk pins — not legal VU). */
    fun uploadTelematicsToFleet() {
        val batch = telematicsImportBatch
        if (batch == null || batch.pings.isEmpty()) {
            telematicsStatusMessage = "Import a telematics CSV first."
            return
        }
        viewModelScope.launch {
            val uploaded = withContext(Dispatchers.IO) {
                runCatching {
                    FleetApi(prefs.baseUrl, prefs.apiKey).ingestTelematicsBatch(batch.pings)
                }
            }
            uploaded.fold(
                onSuccess = { count ->
                    telematicsStatusMessage =
                        "Uploaded $count / ${batch.pings.size} ping(s) to fleet (read-only desk pins)."
                    toastMessage = telematicsStatusMessage
                },
                onFailure = { error ->
                    telematicsStatusMessage =
                        error.message ?: "Fleet telematics upload failed."
                },
            )
        }
    }

    /** Clears the local telematics CSV batch. */
    fun clearTelematicsImport() {
        telematicsImportBatch = null
        telematicsStatusMessage = null
    }

    /** Records that the driver opened a partner parking book link. */
    fun noteParkingBookOpened(
        id: String,
        label: String,
        latitude: Double,
        longitude: Double,
        partner: ParkingBookPartner,
        tier: ParkingAvailabilityTier? = null,
    ) {
        pendingParkingBookReturn = PendingParkingBookReturn(
            id = id,
            label = label,
            latitude = latitude,
            longitude = longitude,
            partner = partner,
            tier = tier,
        )
        showParkingBookResumeBanner = false
    }

    /** Evaluates whether to show the resume banner after returning from a partner site. */
    fun evaluateParkingBookResumeOnForeground() {
        val pending = pendingParkingBookReturn
        if (pending == null || !pending.isFresh()) {
            pendingParkingBookReturn = null
            showParkingBookResumeBanner = false
            return
        }
        showParkingBookResumeBanner = true
    }

    /** Dismisses the parking book resume banner and clears pending return. */
    fun dismissParkingBookReturn() {
        pendingParkingBookReturn = null
        showParkingBookResumeBanner = false
        selectedParkingBookStop = null
    }

    /** Keeps navigating after a partner book bounce. */
    fun keepNavigatingAfterParkingBook() {
        dismissParkingBookReturn()
    }

    /** Opens the map book sheet for an ahead parking marker. */
    fun selectParkingBookStop(marker: ParkingMapMarker) {
        selectedParkingBookStop = PendingParkingBookReturn(
            id = marker.id,
            label = marker.title,
            latitude = marker.latitude,
            longitude = marker.longitude,
            partner = ParkingBookPartner.TRAVIS,
            tier = marker.tier,
        )
    }

    fun clearSelectedParkingBookStop() {
        selectedParkingBookStop = null
    }

    fun setVoiceEnabled(enabled: Boolean) {
        prefs.voiceGuidanceEnabled = enabled
        voice.enabled = enabled
        voiceGuidanceMuted = !enabled
    }

    /** Enables or disables proactive layby voice alerts (~5 km window). */
    fun updateLaybyVoiceAlertsEnabled(enabled: Boolean) {
        prefs.laybyVoiceAlertsEnabled = enabled
        laybyVoiceAlertsEnabled = enabled
        if (!enabled) {
            lastAnnouncedLaybyId = null
        }
    }

    /** Starts a short push-to-talk listen window and handles the matched command. */
    fun startVoiceListen() {
        if (voiceListening) return
        voiceListenJob?.cancel()
        voiceListenJob = viewModelScope.launch {
            voiceListening = true
            toastMessage = "Listening…"
            val command = runCatching { voiceCommands.listen(durationSeconds = 4.0) }.getOrNull()
            voiceListening = false
            if (command == null) {
                toastMessage = VoiceAssistResponseFormatter.UNRECOGNIZED
                voice.speakAssist(VoiceAssistResponseFormatter.UNRECOGNIZED)
                return@launch
            }
            handleDriverVoiceCommand(command)
        }
    }

    /** Cancels an in-flight push-to-talk listen window. */
    fun cancelVoiceListen() {
        voiceListenJob?.cancel()
        voiceCommands.cancel()
        voiceListening = false
    }

    /** Ranks HOS-preferred or nearest layby ahead (Break Now) — shared by voice and HUD. */
    fun breakNow() {
        laybySkipCount = 0
        refreshHosForecast(routeCoordinates)
        val preferredId = hosForecast?.insertions?.firstOrNull()?.poiId
        val preferred = preferredId?.let { id ->
            LaybyAdvisoryEngine.advisoryForSite(
                siteId = id,
                route = routeCoordinates,
                currentArcLengthMeters = progress?.traveledDistanceMeters ?: 0.0,
                occupancyStore = laybyOccupancyStore,
                sites = activeLaybySites(),
            )
        }
        if (preferred != null) {
            applyLaybyAdvisory(preferred)
        } else {
            refreshComplianceAdvisories()
        }
        val spoken = VoiceAssistResponseFormatter.breakNow(laybyAdvisoryMessage)
        toastMessage = spoken
        voice.speakAssist(spoken)
    }

    /** Applies a domain voice command (Break Now / mute / etc.). */
    fun handleDriverVoiceCommand(command: DriverVoiceCommand) {
        when (command) {
            DriverVoiceCommand.BREAK_NOW -> breakNow()
            DriverVoiceCommand.NEXT_LAYBY -> {
                laybyAdvisory?.let { current ->
                    laybyOccupancyStore.record(current.site.id, LaybyOccupancyKind.FULL)
                }
                laybySkipCount += 1
                applyLaybyAdvisory(
                    LaybyAdvisoryEngine.nearestAhead(
                        route = routeCoordinates,
                        skipCount = laybySkipCount,
                        occupancyStore = laybyOccupancyStore,
                        sites = activeLaybySites(),
                    ),
                )
                val spoken = VoiceAssistResponseFormatter.nextLayby(laybyAdvisoryMessage)
                toastMessage = spoken
                voice.speakAssist(spoken)
            }
            DriverVoiceCommand.MUTE -> {
                setVoiceEnabled(false)
                toastMessage = VoiceAssistResponseFormatter.MUTED
            }
            DriverVoiceCommand.UNMUTE -> {
                setVoiceEnabled(true)
                toastMessage = VoiceAssistResponseFormatter.UNMUTED
                voice.speakAssist(VoiceAssistResponseFormatter.UNMUTED)
            }
            DriverVoiceCommand.WHERE_STOPPING -> {
                val spoken = VoiceAssistResponseFormatter.whereStopping(
                    advisoryMessage = laybyAdvisoryMessage,
                    destinationLabel = destination.label.ifBlank { null },
                )
                toastMessage = spoken
                voice.speakAssist(spoken)
            }
            DriverVoiceCommand.CAN_I_DRIVE -> {
                refreshCanIDriveFromLocalSources()
                val spoken = VoiceAssistResponseFormatter.canIDrive(canIDriveStatus)
                toastMessage = spoken
                voice.speakAssist(spoken)
            }
            DriverVoiceCommand.TOLL_AHEAD -> {
                val spoken = VoiceAssistResponseFormatter.tollAhead(
                    tollName = activeTollAdvisory?.name,
                    distanceMeters = activeTollDistanceMeters,
                    costLabel = activeTollAdvisory?.indicativeCostLabel,
                    routeSummary = tollSummaryMessage,
                )
                toastMessage = spoken
                voice.speakAssist(spoken)
            }
            DriverVoiceCommand.NEXT_LEZ -> {
                val spoken = VoiceAssistResponseFormatter.nextLez(
                    label = null,
                    message = lezAdvisoryMessage,
                )
                toastMessage = spoken
                voice.speakAssist(spoken)
            }
            DriverVoiceCommand.ETA -> {
                val remaining = progress?.remainingEtaSeconds
                    ?: session.physicsEtaSeconds
                    ?: session.geometry?.staticEtaSeconds
                val spoken = VoiceAssistResponseFormatter.eta(remaining)
                toastMessage = spoken
                voice.speakAssist(spoken)
            }
            DriverVoiceCommand.HAZARD_AHEAD -> {
                val (fusedHazard, fusedDist, _) = effectiveHazardForFuse()
                val spoken = VoiceAssistResponseFormatter.hazardAhead(
                    message = fusedHazard,
                    distanceMeters = fusedDist,
                )
                toastMessage = spoken
                voice.speakAssist(spoken)
            }
            DriverVoiceCommand.ROADWORKS_AHEAD -> {
                val spoken = VoiceAssistResponseFormatter.roadworksAhead(
                    message = lastRoadworksMessage,
                    distanceMeters = lastRoadworksDistanceMeters,
                )
                toastMessage = spoken
                voice.speakAssist(spoken)
            }
            DriverVoiceCommand.RISK_AHEAD -> {
                val spoken = VoiceAssistResponseFormatter.riskAhead(
                    primaryRiskAdvisory?.message,
                )
                toastMessage = spoken
                voice.speakAssist(spoken)
            }
        }
    }

    fun updateRegCheckUsername(value: String) {
        regCheckUsernameDraft = value
        prefs.regCheckUsername = value
    }

    fun updateDvlaApiKey(value: String) {
        dvlaApiKeyDraft = value
        prefs.dvlaApiKey = value
    }

    fun updateTomTomApiKey(value: String) {
        tomTomApiKeyDraft = value
        prefs.tomTomApiKey = value
    }

    fun updateOpenWeatherApiKey(value: String) {
        openWeatherApiKeyDraft = value
        prefs.openWeatherApiKey = value
    }

    fun updateClearanceRadarEnabled(enabled: Boolean) {
        clearanceRadarEnabled = enabled
        prefs.clearanceRadarEnabled = enabled
        if (!enabled) {
            cachedClearanceItems = emptyList()
            cachedOffRouteClearanceItems = emptyList()
            refreshPredictiveRisk()
        }
    }

    fun updateLezAvoidEnabled(enabled: Boolean) {
        lezAvoidEnabled = enabled
        prefs.lezAvoidEnabled = enabled
        refreshComplianceAdvisories()
    }

    /** Enables or disables ORS tollway avoidance and optionally replans. */
    fun updateAvoidTolls(enabled: Boolean, replan: Boolean = false) {
        avoidTolls = enabled
        prefs.avoidTolls = enabled
        if (replan) {
            findRoute()
        }
    }

    /** Updates the fuel card network used for ahead OSM brand matching. */
    fun updateFuelCardProvider(provider: FuelCardProvider) {
        fuelCardProvider = provider
        prefs.fuelCardProvider = provider.rawValue
        refreshFuelCardBanner()
    }

    /** Turns on toll avoidance and recalculates the active route. */
    fun avoidTollsAndReplan() {
        updateAvoidTolls(enabled = true, replan = true)
    }

    fun updateEmissionClass(value: String) {
        emissionClassDraft = value
        prefs.emissionClass = value
        refreshComplianceAdvisories()
    }

    /** Updates trailer count (0…3) and keeps intake profile in sync for ORS length mapping. */
    fun updateTrailerCount(raw: String) {
        val parsed = raw.trim().toIntOrNull()?.coerceIn(0, 3) ?: return
        trailerCountDraft = parsed
        if (parsed == 0 && lengthMetersDraft > 14.0) {
            lengthMetersDraft = HgvVehicleProfile.ukRigid.lengthMeters
        } else if (parsed >= 1 && lengthMetersDraft < 14.0) {
            lengthMetersDraft = HgvVehicleProfile.ukArtic.lengthMeters
        }
        syncIntakeTrailerAndLength()
    }

    /** Updates overall bumper-to-bumper length for solo / override routing. */
    fun updateLengthMeters(raw: String) {
        val parsed = raw.trim().toDoubleOrNull() ?: return
        if (parsed <= 0) return
        lengthMetersDraft = parsed
        syncIntakeTrailerAndLength()
    }

    private fun syncIntakeTrailerAndLength() {
        val base = intakeVehicleProfile
        intakeVehicleProfile = FleetVehicleProfile(
            height = base?.height,
            weight = base?.weight,
            width = base?.width,
            length = lengthMetersDraft,
            trailerCount = trailerCountDraft,
            axleWeight = base?.axleWeight,
        )
    }

    fun recordDrivingSeconds(deltaSeconds: Double) {
        continuousDriveSeconds += deltaSeconds
        dailyDriveSeconds += deltaSeconds
        prefs.continuousDriveSeconds = continuousDriveSeconds
        prefs.dailyDriveSeconds = dailyDriveSeconds
        refreshComplianceAdvisories()
        refreshPartnerTachoAdvisoryAsync()
    }

    fun resetHosBreak() {
        continuousDriveSeconds = 0.0
        prefs.continuousDriveSeconds = 0.0
        refreshComplianceAdvisories()
        refreshPartnerTachoAdvisoryAsync()
        toastMessage = "Break recorded — continuous clock reset"
    }

    fun startFleetLoops() {
        healthJob?.cancel()
        healthJob = viewModelScope.launch {
            while (isActive && prefs.isPaired()) {
                refreshHealth()
                delay(30_000)
            }
        }
        sseJob?.cancel()
        sseJob = viewModelScope.launch {
            if (!prefs.isPaired()) return@launch
            val api = FleetApi(prefs.baseUrl, prefs.apiKey)
            try {
                FleetSseClient(api).eventsWithReconnect(
                    vehicleId = prefs.vehicleId,
                    onState = { state ->
                        launch(Dispatchers.Main.immediate) {
                            sseLabel = when (state) {
                                is SseConnectionState.Listening -> "SSE listening"
                                is SseConnectionState.Reconnecting ->
                                    "Reconnecting in ${state.delaySeconds}s…"
                                is SseConnectionState.Stopped -> "SSE stopped"
                            }
                        }
                    },
                ).collect { event ->
                    statusLabel = "SSE ${event.kind}"
                    if (event.kind == "tripPushed" && event.tripId != null) {
                        val trip = withContext(Dispatchers.IO) { api.getTrip(event.tripId) }
                        applyFleetTrip(trip)
                    }
                }
            } catch (e: Exception) {
                errorMessage = e.message
                sseLabel = "SSE stopped"
            }
        }
    }

    suspend fun refreshHealth() {
        try {
            val api = FleetApi(prefs.baseUrl, prefs.apiKey)
            val health = withContext(Dispatchers.IO) { api.health() }
            val healthOk = health.optBoolean("ok")
            if (!healthOk) {
                connected = false
                statusLabel = FleetConnectionGate.statusLabel(healthOk = false, authSucceeded = false)
                orsConfigured = false
                tomTomProxyConfigured = false
                openWeatherProxyConfigured = false
                return
            }
            try {
                val proxyJson = withContext(Dispatchers.IO) { api.verifyAuthenticatedAccess() }
                connected = true
                statusLabel = FleetConnectionGate.statusLabel(healthOk = true, authSucceeded = true)
                orsConfigured = proxyJson.optBoolean(
                    "orsConfigured",
                    proxyJson.optBoolean("ors_configured", false),
                )
                tomTomProxyConfigured = proxyJson.optBoolean(
                    "tomTomConfigured",
                    proxyJson.optBoolean("tomtomConfigured", false),
                )
                openWeatherProxyConfigured = proxyJson.optBoolean(
                    "openWeatherConfigured",
                    proxyJson.optBoolean("openWeatherConfigured", false),
                )
                refreshPartnerTachoAdvisory(api)
            } catch (e: Exception) {
                connected = false
                statusLabel = FleetConnectionGate.statusLabel(
                    healthOk = true,
                    authSucceeded = false,
                    authErrorMessage = e.message,
                )
                orsConfigured = false
                tomTomProxyConfigured = false
                openWeatherProxyConfigured = false
                errorMessage = e.message
            }
        } catch (e: Exception) {
            connected = false
            statusLabel = FleetConnectionGate.statusLabel(healthOk = false, authSucceeded = false)
            orsConfigured = false
            tomTomProxyConfigured = false
            openWeatherProxyConfigured = false
            errorMessage = e.message
        }
    }

    fun searchOrigin(query: String) = search(query, isOrigin = true)
    fun searchDestination(query: String) = search(query, isOrigin = false)

    private fun search(query: String, isOrigin: Boolean) {
        if (isOrigin) origin = origin.copy(label = query, latitude = null, longitude = null)
        else destination = destination.copy(label = query, latitude = null, longitude = null)
        searchJob?.cancel()
        searchJob = viewModelScope.launch {
            delay(350)
            if (query.trim().length < 2) {
                if (isOrigin) originSuggestions = emptyList() else destinationSuggestions = emptyList()
                return@launch
            }
            try {
                val results = withContext(Dispatchers.IO) {
                    PeliasGeocoder(prefs.baseUrl, prefs.apiKey).search(query)
                }
                if (isOrigin) originSuggestions = results else destinationSuggestions = results
            } catch (e: Exception) {
                errorMessage = e.message
            }
        }
    }

    fun selectOrigin(suggestion: GeocodeSuggestion) {
        origin = WaypointState(suggestion.label, suggestion.latitude, suggestion.longitude)
        originSuggestions = emptyList()
    }

    fun selectDestination(suggestion: GeocodeSuggestion) {
        destination = WaypointState(suggestion.label, suggestion.latitude, suggestion.longitude)
        destinationSuggestions = emptyList()
    }

    fun findRoute() {
        viewModelScope.launch { findRouteInternal() }
    }

    private suspend fun findRouteInternal() {
        errorMessage = null
        val oLat = origin.latitude
        val oLon = origin.longitude
        val dLat = destination.latitude
        val dLon = destination.longitude
        if (oLat == null || oLon == null || dLat == null || dLon == null) {
            errorMessage = "Resolve origin and destination first"
            return
        }
        if (!FleetOrsConfig.usesFleetProxy(prefs.baseUrl)) {
            errorMessage = "Pair with fleet server (no driver ORS key required)"
            return
        }
        isCalculating = true
        lastAnnouncedTollRouteSignature = null
        cancelStillTherePrompt()
        try {
            val emission = runCatching {
                UkLezCatalog.EmissionClass.valueOf(emissionClassDraft.trim().uppercase())
            }.getOrNull()
            val avoidRings = LezAvoidPolicy.polygons(
                emissionClass = emission,
                avoidEnabled = lezAvoidEnabled,
                origin = LatLon(oLat, oLon),
                destination = LatLon(dLat, dLon),
            )
            val result = withContext(Dispatchers.IO) {
                OrsRoutingClient(prefs.baseUrl, prefs.apiKey).route(
                    originLon = oLon,
                    originLat = oLat,
                    destinationLon = dLon,
                    destinationLat = dLat,
                    vehicle = resolveHgvProfile(),
                    avoidTolls = avoidTolls,
                    avoidPolygons = avoidRings,
                )
            }
            val geometry = RouteGeometry(
                coordinates = result.coordinates,
                totalLengthMeters = result.distanceMeters,
                staticEtaSeconds = result.durationSeconds,
            )
            session.loadRoute(geometry, result.instructions)
            routeCoordinates = result.coordinates
            lastRouteDurationSeconds = result.durationSeconds
            laybySkipCount = 0
            catalogLaybySites = emptyList()
            catalogTruckPois = emptyList()
            fuelCardBannerMessage = null
            weighStationBannerMessage = null
            hosForecast = null
            hosForecastSummary = null
            parkingMapMarkers = emptyList()
            dismissParkingBookReturn()
            catalogRoadworkSites = emptyList()
            lastAnnouncedLaybyId = null
            lastRoadworksMessage = null
            lastRoadworksDistanceMeters = null
            phase = session.phase
            progress = session.progress
            currentInstruction = session.currentInstruction()
            distanceLabel = formatDistance(result.distanceMeters)
            etaLabel = formatDuration(result.durationSeconds)
            physicsEtaLabel = null
            voice.resetAnnouncements()
            statusLabel = "Route loaded"
            refreshComplianceAdvisories(result.coordinates)
            announceCommittedRouteTollSummaryIfNeeded()
            refreshClearanceAndForecastRisk(result.coordinates)
            enrichLaneGuidanceAsync(result.instructions, result.coordinates)
            refreshLaybyCatalogAsync(result.coordinates)
            refreshFuelPoiCatalogAsync(result.coordinates)
            refreshRoadworksCatalogAsync(result.coordinates)
            val tripForEta = activeTrip
            if (tripForEta != null) {
                try {
                    withContext(Dispatchers.IO) {
                        FleetApi(prefs.baseUrl, prefs.apiKey).publishSnapshot(
                            trip = tripForEta,
                            status = "optimized",
                            physicsETASeconds = result.durationSeconds,
                        )
                    }
                    activeTrip = tripForEta.copy(
                        status = "optimized",
                        physicsETASeconds = result.durationSeconds,
                    )
                } catch (_: Exception) {
                    // Desk ETA is best-effort; never block route UI.
                }
            }
        } catch (e: Exception) {
            errorMessage = e.message
        } finally {
            isCalculating = false
        }
    }

    fun startNavigation() {
        session.startNavigation()
        phase = session.phase
        progress = session.progress
        currentInstruction = session.currentInstruction()
        voice.resetAnnouncements()
        statusLabel = "Navigating"
        startGpsLoop()
    }

    fun stopNavigation() {
        session.stopNavigation()
        phase = session.phase
        progress = null
        currentInstruction = null
        gpsJob?.cancel()
        statusLabel = "Route loaded"
    }

    fun rehearseRoute() {
        val geo = session.geometry ?: return
        viewModelScope.launch {
            isRehearsing = true
            try {
                val kinetic = withContext(Dispatchers.Default) {
                    RouteRehearsalEngine.rehearse(geo.coordinates, geo.staticEtaSeconds)
                }
                session.physicsEtaSeconds = kinetic
                physicsEtaLabel = formatDuration(kinetic)
                lastKineticMessage = "Physics ETA ${formatDuration(kinetic)} — review grades before depart"
                refreshPredictiveRisk()
                statusLabel = "Rehearsed"
                val trip = activeTrip
                if (trip != null) {
                    try {
                        withContext(Dispatchers.IO) {
                            FleetApi(prefs.baseUrl, prefs.apiKey).publishSnapshot(
                                trip = trip,
                                status = trip.status,
                                physicsETASeconds = kinetic,
                            )
                        }
                        activeTrip = trip.copy(physicsETASeconds = kinetic)
                    } catch (e: Exception) {
                        errorMessage = e.message
                    }
                }
            } catch (e: Exception) {
                errorMessage = e.message
            } finally {
                isRehearsing = false
            }
        }
    }

    fun applyFleetTrip(trip: FleetTrip) {
        viewModelScope.launch {
            activeTrip = trip
            timeWindowLines = formatTimeWindowLines(trip)
            intakeVehicleProfile = trip.vehicleProfile
            trip.vehicleProfile?.trailerCount?.let { trailerCountDraft = it.coerceIn(0, 3) }
            trip.vehicleProfile?.length?.let { lengthMetersDraft = it }
            toastMessage = "Trip received"
            val ordered = JobIntakeHandler.orderedStops(trip)
            val first = ordered.firstOrNull()
            val last = ordered.lastOrNull()
            if (first != null) {
                origin = WaypointState(first.label, first.latitude, first.longitude)
            }
            if (last != null) {
                destination = WaypointState(last.label, last.latitude, last.longitude)
            }
            val canLookupPlate =
                prefs.regCheckUsername.isNotBlank() || prefs.dvlaApiKey.isNotBlank()
            if (needsRegistrationLookup(trip) && canLookupPlate) {
                try {
                    val plate = withContext(Dispatchers.IO) {
                        val api = FleetApi(prefs.baseUrl, prefs.apiKey)
                        api.vehiclesForOrg(trip.orgId)
                            .firstOrNull { it.id == trip.vehicleId }
                            ?.registrationPlate
                    }
                    if (!plate.isNullOrBlank()) {
                        val resolved = withContext(Dispatchers.IO) {
                            VehicleRegistrationResolver.resolve(
                                registration = plate,
                                regCheckUsername = prefs.regCheckUsername,
                                dvlaApiKey = prefs.dvlaApiKey,
                            )
                        }
                        if (resolved != null) {
                            intakeVehicleProfile = FleetVehicleProfile(
                                height = resolved.heightMeters ?: trip.vehicleProfile?.height,
                                weight = resolved.weightTonnes ?: trip.vehicleProfile?.weight,
                                width = resolved.widthMeters ?: trip.vehicleProfile?.width,
                                length = resolved.lengthMeters ?: trip.vehicleProfile?.length,
                                trailerCount = trip.vehicleProfile?.trailerCount ?: trailerCountDraft,
                                axleWeight = trip.vehicleProfile?.axleWeight,
                            )
                            intakeVehicleProfile?.length?.let { lengthMetersDraft = it }
                            toastMessage = when (resolved.source) {
                                VehicleRegistrationResolver.Source.REG_CHECK -> "RegCheck dims applied"
                                VehicleRegistrationResolver.Source.DVLA -> "DVLA weight applied"
                            }
                        }
                    }
                } catch (_: Exception) {
                    // Never block intake on RegCheck / DVLA failure.
                }
            }
            try {
                withContext(Dispatchers.IO) {
                    FleetApi(prefs.baseUrl, prefs.apiKey).publishSnapshot(
                        trip = trip,
                        status = "accepted",
                    )
                }
            } catch (_: Exception) {
            }
            if (JobIntakeHandler.shouldAutoFindRoute(trip) && origin.isResolved && destination.isResolved) {
                findRouteInternal()
                if (JobIntakeHandler.shouldAutoRehearse(trip) && routeCoordinates.isNotEmpty()) {
                    rehearseRoute()
                }
            }
            refreshPredictiveRisk()
        }
    }

    fun openWalkaround() {
        walkaroundItems = InspectionChecklistFactory.defaultItems()
        showWalkaround = true
    }

    fun updateWalkaroundItem(index: Int, item: InspectionChecklistItem) {
        walkaroundItems = walkaroundItems.toMutableList().also { it[index] = item }
    }

    fun completeWalkaround() {
        if (!InspectionChecklistFactory.allZonesReviewed(walkaroundItems)) {
            errorMessage = "Mark every walkaround item Pass or Defect"
            return
        }
        val trip = activeTrip
        showWalkaround = false
        if (trip == null) {
            val summary = InspectionChecklistFactory.summary(
                items = walkaroundItems,
                vehicleLabel = "Vehicle",
                registrationPlate = null,
            )
            lastInspectionSummary = summary
            lastWalkaroundPdfBytes = InspectionReportPdfRenderer.pdfBytes(summary, walkaroundItems)
            toastMessage = "Walkaround PDF saved locally (${summary.photoCount} photo(s))"
            return
        }
        viewModelScope.launch {
            try {
                val vehicle = withContext(Dispatchers.IO) {
                    runCatching {
                        FleetApi(prefs.baseUrl, prefs.apiKey).vehiclesForOrg(trip.orgId)
                            .firstOrNull { it.id == trip.vehicleId }
                    }.getOrNull()
                }
                val summary = InspectionChecklistFactory.summary(
                    items = walkaroundItems,
                    vehicleLabel = vehicle?.label?.takeIf { it.isNotBlank() }
                        ?: trip.vehicleId.take(8),
                    registrationPlate = vehicle?.registrationPlate,
                )
                lastInspectionSummary = summary
                val pdfBytes = InspectionReportPdfRenderer.pdfBytes(summary, walkaroundItems)
                lastWalkaroundPdfBytes = pdfBytes
                val pdfBase64 = InspectionMediaBudget.cappedPDFBase64(
                    android.util.Base64.encodeToString(pdfBytes, android.util.Base64.NO_WRAP),
                )
                val defects = JSONArray()
                walkaroundItems.filter { it.status.name == "DEFECT" }.forEach { item ->
                    defects.put(
                        JSONObject()
                            .put("zone", item.zone.label)
                            .put("label", item.label)
                            .put("note", item.note)
                            .put("hasPhoto", item.photoBase64 != null),
                    )
                }
                val payload = JSONObject()
                    .put("vehicleLabel", summary.vehicleLabel)
                    .put("registrationPlate", summary.registrationPlate ?: JSONObject.NULL)
                    .put("defectCount", summary.defectCount)
                    .put("photoCount", summary.photoCount)
                    .put("completedAt", summary.completedAt)
                    .put("defects", defects)
                withContext(Dispatchers.IO) {
                    FleetApi(prefs.baseUrl, prefs.apiKey).publishSnapshot(
                        trip = trip,
                        status = trip.status,
                        latestInspectionSummary = payload,
                        inspectionReportPDFBase64 = pdfBase64,
                    )
                }
                toastMessage = if (summary.defectCount > 0) {
                    "Walkaround: ${summary.defectCount} defect(s), ${summary.photoCount} photo(s) → dispatch + PDF"
                } else {
                    "Walkaround complete — PDF ready"
                }
            } catch (e: Exception) {
                errorMessage = e.message
            }
        }
    }

    private fun refreshComplianceAdvisories(
        route: List<LatLon> = routeCoordinates,
        currentArcLengthMeters: Double = progress?.traveledDistanceMeters ?: 0.0,
    ) {
        val emission = runCatching {
            UkLezCatalog.EmissionClass.valueOf(emissionClassDraft.trim().uppercase())
        }.getOrNull()
        lezAdvisoryMessage = UkLezCatalog.announcement(
            route = route,
            emissionClass = emission,
            avoidEnabled = lezAvoidEnabled,
        )
        applyLaybyAdvisory(
            LaybyAdvisoryEngine.nearestAhead(
                route = route,
                currentArcLengthMeters = currentArcLengthMeters,
                skipCount = laybySkipCount,
                occupancyStore = laybyOccupancyStore,
                sites = activeLaybySites(),
            ),
        )
        refreshParkingMapMarkers(route, currentArcLengthMeters)
        val clock = HosAdvisoryClock.snapshot(
            continuousDriveSeconds = continuousDriveSeconds,
            dailyDriveSeconds = dailyDriveSeconds,
        )
        hosAdvisoryMessage = clock.message
        canIDriveStatus = CanIDriveEvaluator.evaluate(
            partner = partnerTachoAdvisory?.asCardSummary(),
            imported = importedTachoSummary,
            clock = clock,
        )
        refreshHosForecast(route)
        refreshRouteTollAdvisories(route)
    }

    private fun activeLaybySites(): List<LaybyAdvisoryEngine.Site> =
        catalogLaybySites.ifEmpty { LaybyAdvisoryEngine.seedSites }

    /** Remaining continuous/daily drive: partner → imported card → advisory clock. */
    private fun remainingDriveBudgets(): Pair<Double, Double> {
        val partner = partnerTachoAdvisory?.asCardSummary()
        val imported = importedTachoSummary
        val now = java.time.Instant.now()
        if (partner != null &&
            now.epochSecond - partner.importedAt.epochSecond < CanIDriveEvaluator.FRESHNESS_LIMIT_SECONDS
        ) {
            return partner.remainingContinuousDriveSeconds to partner.remainingDailyDriveSeconds
        }
        if (imported != null &&
            now.epochSecond - imported.importedAt.epochSecond < CanIDriveEvaluator.FRESHNESS_LIMIT_SECONDS
        ) {
            return imported.remainingContinuousDriveSeconds to imported.remainingDailyDriveSeconds
        }
        val continuousLeft =
            HosAdvisoryClock.CONTINUOUS_DRIVE_LIMIT_SECONDS - continuousDriveSeconds
        val dailyLeft = HosAdvisoryClock.DAILY_DRIVE_LIMIT_SECONDS - dailyDriveSeconds
        return continuousLeft to dailyLeft
    }

    /**
     * Builds coarse per-segment durations from ORS total, proportional to haversine lengths.
     */
    private fun pathDurationsAndArcs(
        route: List<LatLon>,
        totalDurationSeconds: Double,
    ): Pair<List<Double>, List<Double>> {
        if (route.size < 2 || totalDurationSeconds <= 0) {
            return emptyList<Double>() to emptyList()
        }
        val segmentMeters = mutableListOf<Double>()
        var totalMeters = 0.0
        for (i in 0 until route.lastIndex) {
            val meters = OrsResponseParser.haversineMeters(route[i], route[i + 1])
            segmentMeters += meters
            totalMeters += meters
        }
        if (totalMeters <= 0) {
            val equal = totalDurationSeconds / segmentMeters.size.coerceAtLeast(1)
            val durations = List(segmentMeters.size) { equal }
            var cum = 0.0
            val equalArcs = segmentMeters.indices.map {
                cum += 1.0
                cum
            }
            return durations to equalArcs
        }
        val durations = segmentMeters.map { totalDurationSeconds * (it / totalMeters) }
        var cum = 0.0
        val arcs = segmentMeters.map {
            cum += it
            cum
        }
        return durations to arcs
    }

    private fun hosRestCandidates(route: List<LatLon>): List<HosRestCandidate> {
        val laybyProjected = LaybyCatalogClient.projectWithArcs(activeLaybySites(), route)
        val fromLayby = laybyProjected.map { (site, arc) ->
            HosRestCandidate(
                id = site.id,
                label = site.name,
                kind = HosRestCandidateKind.LAYBY,
                arcLengthAlongRouteMeters = arc,
            )
        }
        val truckSites = catalogTruckPois.mapNotNull { poi ->
            val kind = when (poi.kind) {
                TruckFuelPoi.Kind.OVERNIGHT_SECURE_PARKING ->
                    HosRestCandidateKind.OVERNIGHT_SECURE_PARKING
                TruckFuelPoi.Kind.HIGH_FLOW_DIESEL -> HosRestCandidateKind.HIGH_FLOW_DIESEL
                TruckFuelPoi.Kind.WEIGH_STATION, TruckFuelPoi.Kind.OTHER -> return@mapNotNull null
            }
            LaybyAdvisoryEngine.Site(poi.id, poi.label, LatLon(poi.latitude, poi.longitude)) to kind
        }
        val fromTruck = LaybyCatalogClient.projectWithArcs(
            sites = truckSites.map { it.first },
            route = route,
        ).mapNotNull { (site, arc) ->
            val kind = truckSites.firstOrNull { it.first.id == site.id }?.second
                ?: return@mapNotNull null
            HosRestCandidate(
                id = site.id,
                label = site.name,
                kind = kind,
                arcLengthAlongRouteMeters = arc,
            )
        }
        return (fromLayby + fromTruck).distinctBy { it.id }
    }

    private fun refreshHosForecast(route: List<LatLon>) {
        if (route.size < 2 || lastRouteDurationSeconds <= 0) {
            hosForecast = null
            hosForecastSummary = null
            return
        }
        val (continuousLeft, dailyLeft) = remainingDriveBudgets()
        val (durations, arcs) = pathDurationsAndArcs(route, lastRouteDurationSeconds)
        if (durations.isEmpty()) {
            hosForecast = null
            hosForecastSummary = null
            return
        }
        val weightTons = intakeVehicleProfile?.weight?.takeIf { it > 0 }
            ?: 40.0
        val stress = KineticGradientAnalyzer.alignToSegmentCount(
            KineticGradientAnalyzer.analyzeTopology(route, weightTons),
            durations.size,
        )
        val result = HosRestInserter.forecast(
            remainingContinuousDriveSeconds = continuousLeft,
            remainingDailyDriveSeconds = dailyLeft,
            pathDurationsSeconds = durations,
            pathArcLengthsMeters = arcs,
            upcomingCandidates = hosRestCandidates(route),
            kineticStress = stress,
        )
        hosForecast = result
        hosForecastSummary = if (result.insertions.isEmpty()) null else result.summary
    }

    /** Async Overpass corridor laybys via fleet proxy (seed fallback kept). */
    private fun refreshLaybyCatalogAsync(route: List<LatLon>) {
        viewModelScope.launch {
            val sites = withContext(Dispatchers.IO) {
                LaybyCatalogClient.laybysAlongRoute(
                    route = route,
                    fleetBaseUrl = prefs.baseUrl,
                    fleetApiKey = prefs.apiKey,
                )
            }
            if (sites.isNotEmpty()) {
                catalogLaybySites = sites
                refreshComplianceAdvisories(route)
            } else {
                refreshHosForecast(route)
            }
        }
    }

    /** Async Overpass corridor truck POIs (fuel + weigh + overnight parking). */
    private fun refreshFuelPoiCatalogAsync(route: List<LatLon>) {
        viewModelScope.launch {
            val pois = withContext(Dispatchers.IO) {
                FuelPoiCatalogClient.truckPoisAlongRoute(
                    route = route,
                    fleetBaseUrl = prefs.baseUrl,
                    fleetApiKey = prefs.apiKey,
                )
            }
            catalogTruckPois = pois
            refreshFuelCardBanner()
            refreshWeighStationBanner()
            refreshHosForecast(route)
        }
    }

    private fun refreshFuelCardBanner() {
        val matching = catalogFuelPois.count { FuelCardMatcher.accepts(fuelCardProvider, it) }
        fuelCardBannerMessage = FuelCardMatcher.aheadBannerMessage(fuelCardProvider, matching)
    }

    private fun refreshWeighStationBanner() {
        val weighCount = catalogTruckPois.count { it.kind == TruckFuelPoi.Kind.WEIGH_STATION }
        weighStationBannerMessage = WeighStationAhead.bannerMessage(weighCount)
    }

    /** Records “Looks full” and advances to the next layby candidate. */
    fun reportLaybyFull() {
        val current = laybyAdvisory
        if (current != null) {
            laybyOccupancyStore.record(current.site.id, LaybyOccupancyKind.FULL)
        }
        laybySkipCount += 1
        applyLaybyAdvisory(
            LaybyAdvisoryEngine.nearestAhead(
                route = routeCoordinates,
                skipCount = laybySkipCount,
                occupancyStore = laybyOccupancyStore,
                sites = activeLaybySites(),
            ),
        )
        toastMessage = laybyAdvisoryMessage ?: "No further laybys ahead."
    }

    /** Records “Spaces” for the current layby and refreshes its availability tier. */
    fun reportLaybySpaces() {
        val current = laybyAdvisory ?: return
        laybyOccupancyStore.record(current.site.id, LaybyOccupancyKind.SPACES_AVAILABLE)
        applyLaybyAdvisory(
            LaybyAdvisoryEngine.nearestAhead(
                route = routeCoordinates,
                skipCount = laybySkipCount,
                occupancyStore = laybyOccupancyStore,
                sites = activeLaybySites(),
            ),
        )
        toastMessage = "Marked spaces at ${current.site.name}"
    }

    /** Updates layby ahead + proactive TTS from live arc progress (nav GPS tick). */
    private fun refreshLaybyForProgress(currentArcLengthMeters: Double) {
        applyLaybyAdvisory(
            LaybyAdvisoryEngine.nearestAhead(
                route = routeCoordinates,
                currentArcLengthMeters = currentArcLengthMeters,
                skipCount = laybySkipCount,
                occupancyStore = laybyOccupancyStore,
                sites = activeLaybySites(),
            ),
        )
        refreshParkingMapMarkers(routeCoordinates, currentArcLengthMeters)
        refreshRoadworksForProgress(currentArcLengthMeters)
    }

    /** Async OSM construction sites via fleet Overpass → predictive fuse. */
    private fun refreshRoadworksCatalogAsync(route: List<LatLon>) {
        viewModelScope.launch {
            val sites = withContext(Dispatchers.IO) {
                RoadworksAlongRouteClient.queryAlongRoute(
                    route = route,
                    fleetBaseUrl = prefs.baseUrl,
                    fleetApiKey = prefs.apiKey,
                )
            }
            catalogRoadworkSites = sites
            refreshRoadworksForProgress(progress?.traveledDistanceMeters ?: 0.0)
        }
    }

    /** Nearest construction ahead → fuse message + real remaining distance. */
    private fun refreshRoadworksForProgress(currentArcLengthMeters: Double) {
        val ahead = RoadworksAheadFormatter.nearestAhead(
            sites = catalogRoadworkSites,
            currentArcLengthMeters = currentArcLengthMeters,
        )
        if (ahead == null) {
            if (lastRoadworksMessage != null || lastRoadworksDistanceMeters != null) {
                lastRoadworksMessage = null
                lastRoadworksDistanceMeters = null
                refreshPredictiveRisk()
            }
            return
        }
        val remaining = RoadworksAheadFormatter.remainingMeters(ahead, currentArcLengthMeters)
        val message = RoadworksAheadFormatter.bannerMessage(ahead, currentArcLengthMeters)
            ?: "Roadworks ahead: ${ahead.label}"
        if (message != lastRoadworksMessage || remaining != lastRoadworksDistanceMeters) {
            lastRoadworksMessage = message
            lastRoadworksDistanceMeters = remaining
            refreshPredictiveRisk()
        }
    }

    private fun applyLaybyAdvisory(advisory: LaybyAdvisoryEngine.Advisory?) {
        laybyAdvisory = advisory
        laybyAdvisoryMessage = advisory?.message
        processLaybyVoiceAlertIfNeeded(advisory)
    }

    /** Rebuilds CoPilot-style colored parking markers for ahead laybys. */
    private fun refreshParkingMapMarkers(
        route: List<LatLon> = routeCoordinates,
        currentArcLengthMeters: Double = progress?.traveledDistanceMeters ?: 0.0,
    ) {
        if (route.size < 2) {
            parkingMapMarkers = emptyList()
            return
        }
        val ranked = LaybyAdvisoryEngine.rankedAhead(
            route = route,
            currentArcLengthMeters = currentArcLengthMeters,
            occupancyStore = laybyOccupancyStore,
            sites = activeLaybySites(),
        )
        parkingMapMarkers = ParkingMapMarkerBuilder.markers(ranked)
    }

    /** Speaks once when a layby enters the ~5 km window (uses speakAssist — works while TBT muted). */
    private fun processLaybyVoiceAlertIfNeeded(advisory: LaybyAdvisoryEngine.Advisory?) {
        if (!laybyVoiceAlertsEnabled || advisory == null) return
        if (!LaybyAlertFormatter.shouldAnnounce(advisory, lastAnnouncedLaybyId)) return
        val speedMps = progress?.let { p ->
            if (p.remainingEtaSeconds > 0) p.remainingDistanceMeters / p.remainingEtaSeconds else null
        }
        val etaSeconds = if (speedMps != null && speedMps > 0.5) {
            advisory.remainingMeters / speedMps
        } else {
            null
        }
        val spoken = LaybyAlertFormatter.spokenPrompt(advisory, estimatedArrivalSeconds = etaSeconds)
        lastAnnouncedLaybyId = advisory.site.id
        toastMessage = spoken
        voice.speakAssist(spoken)
    }

    /** Fetches partner remaining-drive advisory when fleet is authenticated. */
    private suspend fun refreshPartnerTachoAdvisory(api: FleetApi) {
        val advisory = withContext(Dispatchers.IO) {
            runCatching { api.getTachoAdvisory() }.getOrNull()
        }
        partnerTachoAdvisory = advisory
        refreshCanIDriveFromLocalSources()
    }

    private fun refreshCanIDriveFromLocalSources() {
        val clock = HosAdvisoryClock.snapshot(
            continuousDriveSeconds = continuousDriveSeconds,
            dailyDriveSeconds = dailyDriveSeconds,
        )
        hosAdvisoryMessage = clock.message
        canIDriveStatus = CanIDriveEvaluator.evaluate(
            partner = partnerTachoAdvisory?.asCardSummary(),
            imported = importedTachoSummary,
            clock = clock,
        )
    }

    private fun tachoSummaryFile(): File {
        val dir = File(getApplication<Application>().filesDir, "tacho")
        if (!dir.exists()) dir.mkdirs()
        return File(dir, "imported_card.json")
    }

    private fun persistTachoSummary(summary: TachoCardSummary) {
        runCatching {
            tachoSummaryFile().writeText(summary.toJson().toString())
        }
    }

    private fun loadPersistedTachoSummary() {
        val file = tachoSummaryFile()
        if (!file.exists()) return
        runCatching {
            importedTachoSummary = TachoCardSummary.fromJson(JSONObject(file.readText()))
        }
    }

    private fun removePersistedTachoSummary() {
        runCatching { tachoSummaryFile().delete() }
    }

    private fun displayNameFor(uri: Uri): String? {
        val resolver = getApplication<Application>().contentResolver
        resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (index >= 0) return cursor.getString(index)
            }
        }
        return uri.lastPathSegment
    }

    private fun refreshPartnerTachoAdvisoryAsync() {
        if (!connected) return
        viewModelScope.launch {
            runCatching {
                val api = FleetApi(prefs.baseUrl, prefs.apiKey)
                refreshPartnerTachoAdvisory(api)
            }
        }
    }

    /** Matches UK toll catalog against the route and refreshes the near-horizon banner. */
    fun refreshRouteTollAdvisories(route: List<LatLon> = routeCoordinates) {
        routeTollAdvisories = TollAdvisoryAlongRouteMatcher.advisories(along = route)
        tollSummaryMessage = VoiceAssistResponseFormatter.committedRouteTollSummary(routeTollAdvisories)
        refreshActiveTollAdvisory()
    }

    /** Speaks indicative route toll total once per committed advisory set (silent when none). */
    private fun announceCommittedRouteTollSummaryIfNeeded() {
        val spoken = VoiceAssistResponseFormatter.committedRouteTollAnnouncement(routeTollAdvisories)
            ?: return
        val signature = VoiceAssistResponseFormatter.tollRouteSignature(routeTollAdvisories)
        if (signature == lastAnnouncedTollRouteSignature) return
        lastAnnouncedTollRouteSignature = signature
        voice.speakAssist(spoken)
    }

    /** Updates the near-horizon toll banner from follow location or route start. */
    fun refreshActiveTollAdvisory() {
        if (routeTollAdvisories.isEmpty() || routeCoordinates.isEmpty()) {
            activeTollAdvisory = null
            activeTollDistanceMeters = null
            return
        }
        val near = when {
            followLat != null && followLon != null -> LatLon(followLat!!, followLon!!)
            else -> routeCoordinates.first()
        }
        val next = TollAdvisoryAlongRouteMatcher.nextAdvisory(
            along = routeCoordinates,
            near = near,
            catalog = routeTollAdvisories,
        )
        if (next != null) {
            activeTollAdvisory = next.first
            activeTollDistanceMeters = next.second
        } else {
            activeTollAdvisory = null
            activeTollDistanceMeters = null
        }
    }

    fun dismissWalkaround() {
        showWalkaround = false
    }

    private fun resolveHgvProfile(): HgvVehicleProfile {
        val trip = activeTrip
        if (trip != null) {
            val merged = trip.copy(vehicleProfile = intakeVehicleProfile ?: trip.vehicleProfile)
            return merged.toHgvVehicleProfile()
        }
        val intake = intakeVehicleProfile
        if (intake != null) {
            return HgvVehicleProfile(
                lengthMeters = intake.length ?: lengthMetersDraft,
                widthMeters = intake.width ?: 2.55,
                heightMeters = intake.height ?: 4.0,
                weightTonnes = intake.weight ?: 40.0,
                axleLoadTonnes = intake.axleWeight ?: 11.5,
                trailerCount = HgvVehicleProfile.clampedTrailerCount(intake.trailerCount)
                    ?: trailerCountDraft,
            )
        }
        return HgvVehicleProfile(
            lengthMeters = lengthMetersDraft,
            trailerCount = trailerCountDraft,
        )
    }

    private fun refreshPredictiveRisk() {
        val trip = activeTrip
        val schedule = if (trip != null) {
            TimeWindowRiskEvaluator.advisory(
                windows = trip.jobBrief?.timeWindows.orEmpty(),
                stops = trip.stops,
                physicsEtaSeconds = trip.physicsETASeconds
                    ?: session.physicsEtaSeconds
                    ?: progress?.remainingEtaSeconds,
            )
        } else {
            null
        }
        val (hazardMessage, hazardDistance, hazardSevere) = effectiveHazardForFuse()
        val fused = PredictiveRiskEngine.fuse(
            PredictiveRiskEngine.Snapshot(
                kineticMessage = lastKineticMessage,
                kineticDistanceMeters = 1_500.0,
                weatherMessage = lastWeatherMessage,
                weatherDistanceMeters = if (lastWeatherMessage != null) 3_000.0 else null,
                hazardMessage = hazardMessage,
                hazardDistanceMeters = hazardDistance
                    ?: if (hazardMessage != null) 1_200.0 else null,
                hazardSevere = hazardSevere,
                roadworksMessage = lastRoadworksMessage,
                roadworksDistanceMeters = lastRoadworksDistanceMeters,
                trafficMessage = lastTrafficMessage,
                trafficDistanceMeters = if (lastTrafficMessage != null) 2_500.0 else null,
                scheduleLateMessage = schedule?.message,
                scheduleLateDistanceMeters = schedule?.distanceMeters,
                forecastItems = cachedForecastItems,
                clearanceItems = cachedClearanceItems + cachedOffRouteClearanceItems,
            ),
        )
        primaryRiskAdvisory = PredictiveRiskEngine.primaryAhead(fused)
    }

    /** Nearest-wins between on-device crowd promote and TomTom/crawl hazard. */
    private fun effectiveHazardForFuse(): Triple<String?, Double?, Boolean> {
        val crowdMsg = crowdHazardMessage
        val crowdDist = crowdHazardDistanceMeters
        if (crowdMsg != null && crowdDist != null) {
            val baseDist = lastHazardDistanceMeters
            if (baseDist == null || crowdDist < baseDist) {
                return Triple(crowdMsg, crowdDist, crowdHazardSevere)
            }
        }
        return Triple(lastHazardMessage, lastHazardDistanceMeters, lastHazardSevere)
    }

    private fun rebuildHazardOverlay() {
        val promoted = HazardAheadFormatter.promotedHazards(crowdReports)
        hazardOverlayGeoJson = HazardOverlayBuilder.geoJSON(promoted + confirmedCrowdHazards)
    }

    private fun refreshCrowdHazardAhead(currentArcLengthMeters: Double) {
        rebuildHazardOverlay()
        if (routeCoordinates.size < 2 || crowdReports.isEmpty()) {
            crowdHazardMessage = null
            crowdHazardDistanceMeters = null
            crowdHazardSevere = false
            return
        }
        val promoted = HazardAheadFormatter.promotedHazards(crowdReports)
        val ahead = HazardAheadFormatter.nearestAhead(
            hazards = promoted,
            crowdReports = crowdReports,
            route = routeCoordinates,
            currentArcLengthMeters = currentArcLengthMeters,
        )
        if (ahead == null) {
            crowdHazardMessage = null
            crowdHazardDistanceMeters = null
            crowdHazardSevere = false
            return
        }
        crowdHazardMessage = ahead.message
        crowdHazardDistanceMeters = ahead.distanceRemainingMeters
        crowdHazardSevere = ahead.type == HazardEventType.CLOSURE
        maybeAnnounceCrowdHazard(ahead)
    }

    private fun maybeAnnounceCrowdHazard(ahead: HazardAheadAnnouncement? = null) {
        val announcement = ahead ?: return
        if (!HazardAheadFormatter.shouldAnnounce(announcement, lastAnnouncedCrowdHazardId)) return
        lastAnnouncedCrowdHazardId = announcement.id
        voice.speakAssist(HazardAheadFormatter.spokenPrompt(announcement))
    }

    private suspend fun refreshClearanceAndForecastRisk(route: List<LatLon>) {
        val profile = resolveHgvProfile()
        cachedClearanceItems = if (clearanceRadarEnabled && route.size >= 2) {
            withContext(Dispatchers.IO) {
                ClearanceCorridorProbe.advisoriesAlongRoute(
                    route = route,
                    profile = profile,
                    currentArcLengthMeters = 0.0,
                    fleetBaseUrl = prefs.baseUrl,
                    fleetApiKey = prefs.apiKey,
                )
            }
        } else {
            emptyList()
        }
        cachedOffRouteClearanceItems = emptyList()
        lastForecastRiskRefreshMs = null
        refreshForecastRiskIfNeeded(force = true, route = route)
        refreshPredictiveRisk()
    }

    /** Async OSM turn:lanes enrich via fleet Overpass proxy (heuristic fallback kept). */
    private fun enrichLaneGuidanceAsync(
        instructions: List<TurnInstruction>,
        route: List<LatLon>,
    ) {
        viewModelScope.launch {
            val enriched = withContext(Dispatchers.IO) {
                OverpassLaneGuidanceClient.enrichInstructions(
                    instructions = instructions,
                    route = route,
                    fleetBaseUrl = prefs.baseUrl,
                    fleetApiKey = prefs.apiKey,
                )
            }
            if (enriched !== instructions && enriched != instructions) {
                val upgraded = LaneOsmUpgrade.upgradedManeuverIndices(instructions, enriched)
                for (index in upgraded) {
                    voice.invalidatePrepareForLaneUpgrade(index)
                }
                session.updateInstructions(enriched)
                currentInstruction = session.currentInstruction()
            }
        }
    }

    private suspend fun refreshForecastRiskIfNeeded(
        force: Boolean = false,
        route: List<LatLon> = routeCoordinates,
    ) {
        if (route.size < 2) return
        if (!force && !ForecastRiskSampler.shouldRefresh(lastForecastRiskRefreshMs)) return
        val tomTom = prefs.tomTomApiKey.takeIf { it.isNotBlank() }
        val openWeather = prefs.openWeatherApiKey.takeIf { it.isNotBlank() }
        if (tomTom == null && openWeather == null && !tomTomProxyConfigured && !openWeatherProxyConfigured) {
            cachedForecastItems = emptyList()
            return
        }
        cachedForecastItems = withContext(Dispatchers.IO) {
            ForecastRiskSampler.sampleHorizon(
                route = route,
                currentArcLengthMeters = 0.0,
                tomTomApiKey = tomTom,
                openWeatherApiKey = openWeather,
                fleetBaseUrl = prefs.baseUrl,
                fleetApiKey = prefs.apiKey,
                tomTomProxyConfigured = tomTomProxyConfigured,
                openWeatherProxyConfigured = openWeatherProxyConfigured,
            )
        }
        lastForecastRiskRefreshMs = System.currentTimeMillis()
    }

    private suspend fun refreshOffRouteClearanceIfNeeded(lat: Double, lon: Double, bearing: Double?) {
        if (!clearanceRadarEnabled || routeCoordinates.size < 2) {
            if (cachedOffRouteClearanceItems.isNotEmpty()) {
                cachedOffRouteClearanceItems = emptyList()
                refreshPredictiveRisk()
            }
            return
        }
        val point = LatLon(lat, lon)
        val (offRoute, _) = ClearanceCorridorProbe.isOffRoute(point, routeCoordinates)
        if (!offRoute) {
            if (cachedOffRouteClearanceItems.isNotEmpty()) {
                cachedOffRouteClearanceItems = emptyList()
                refreshPredictiveRisk()
            }
            return
        }
        val heading = bearing ?: lastKnownBearingDegrees ?: return
        val now = System.currentTimeMillis()
        if (now - lastOffRouteClearanceMs < ClearanceCorridorProbe.OFF_ROUTE_REFRESH_INTERVAL_MS) {
            return
        }
        lastOffRouteClearanceMs = now
        val profile = resolveHgvProfile()
        val items = withContext(Dispatchers.IO) {
            ClearanceCorridorProbe.advisoriesAlongHeading(
                from = point,
                bearingDegrees = heading,
                profile = profile,
                force = true,
                fleetBaseUrl = prefs.baseUrl,
                fleetApiKey = prefs.apiKey,
            )
        }
        if (items.isNotEmpty() || cachedOffRouteClearanceItems.isEmpty()) {
            cachedOffRouteClearanceItems = items
            refreshPredictiveRisk()
        }
    }

    /**
     * Derives traffic / hazard risk strings from live nav progress.
     * Slow implied speed → traffic caution; crawl near a turn → hazard-style alert
     * (fallback only when no live TomTom hazard is active).
     */
    private fun updateRiskFromProgress(progress: NavigationProgress) {
        val remainingM = progress.remainingDistanceMeters
        val remainingEta = progress.remainingEtaSeconds
        val toManeuver = progress.distanceToNextManeuverMeters
        if (remainingM > 200 && remainingEta > 30) {
            val impliedKmh = (remainingM / remainingEta) * 3.6
            lastTrafficMessage = when {
                impliedKmh < 15 -> "Heavy traffic on remaining corridor (~${impliedKmh.toInt()} km/h)"
                impliedKmh < 35 -> "Slow traffic ahead on corridor (~${impliedKmh.toInt()} km/h)"
                else -> null
            }
        } else {
            lastTrafficMessage = null
        }
        clearLiveTomTomHazardIfPassed(progress.traveledDistanceMeters)
        refreshCrowdHazardAhead(progress.traveledDistanceMeters)
        if (!liveTomTomHazardActive) {
            // Near-maneuver crawl: localized hazard when barely moving toward the turn.
            if (toManeuver in 80.0..1_500.0 && remainingM > 0 && remainingEta > 0) {
                val corridorKmh = (remainingM / remainingEta) * 3.6
                if (corridorKmh < 12) {
                    lastHazardMessage = "Congestion near next turn — ${formatDistance(toManeuver)}"
                    lastHazardSevere = corridorKmh < 6
                    lastHazardDistanceMeters = toManeuver
                } else {
                    clearCrawlHazard()
                }
            } else if (toManeuver < 80) {
                clearCrawlHazard()
            }
        }
        refreshPredictiveRisk()
    }

    private fun clearCrawlHazard() {
        lastHazardMessage = null
        lastHazardSevere = false
        lastHazardDistanceMeters = null
    }

    private fun clearLiveTomTomHazardIfPassed(currentArcLengthMeters: Double) {
        val arc = liveTomTomHazardArcMeters ?: return
        if (currentArcLengthMeters >= arc) {
            liveTomTomHazardActive = false
            liveTomTomHazardArcMeters = null
            lastHazardMessage = null
            lastHazardSevere = false
            lastHazardDistanceMeters = null
        } else if (liveTomTomHazardActive) {
            lastHazardDistanceMeters = maxOf(0.0, arc - currentArcLengthMeters)
        }
    }

    private fun tomTomLiveSamplingAvailable(): Boolean {
        val key = prefs.tomTomApiKey.trim()
        return tomTomProxyConfigured || key.isNotEmpty()
    }

    /** Live TomTom closure/standstill sampling (Ph36) — prefers over crawl heuristic. */
    private suspend fun refreshLiveTomTomHazardIfNeeded(
        currentArcLengthMeters: Double,
        route: List<LatLon> = routeCoordinates,
    ) {
        if (route.size < 2 || !tomTomLiveSamplingAvailable()) return
        if (!LiveTrafficHazardSampler.shouldPoll(lastTomTomHazardSampleMs)) return
        val useProxy = tomTomProxyConfigured && prefs.baseUrl.isNotBlank()
        val apiKey = prefs.tomTomApiKey.trim()
        val hit = withContext(Dispatchers.IO) {
            LiveTrafficHazardSampler.sampleAhead(
                route = route,
                currentArcLengthMeters = currentArcLengthMeters,
                apiKey = apiKey,
                fleetBaseUrl = if (useProxy) prefs.baseUrl else null,
                fleetApiKey = prefs.apiKey,
            )
        }
        lastTomTomHazardSampleMs = System.currentTimeMillis()
        if (hit != null) {
            liveTomTomHazardActive = true
            liveTomTomHazardArcMeters = hit.arcLengthAlongRouteMeters
            lastHazardMessage = hit.message
            lastHazardSevere = hit.severe
            lastHazardDistanceMeters = hit.remainingMeters
            refreshPredictiveRisk()
        } else if (liveTomTomHazardActive) {
            // Poll found nothing worthy — clear live hit so crawl fallback can resume.
            liveTomTomHazardActive = false
            liveTomTomHazardArcMeters = null
            clearCrawlHazard()
            refreshPredictiveRisk()
        }
    }

    fun ingestLocation(lat: Double, lon: Double, bearingDegrees: Double? = null) {
        followLat = lat
        followLon = lon
        if (bearingDegrees != null) {
            lastKnownBearingDegrees = bearingDegrees
        }
        session.ingestPosition(lat, lon)
        phase = session.phase
        progress = session.progress
        currentInstruction = session.currentInstruction()
        refreshActiveTollAdvisory()
        currentInstruction?.let { instruction ->
            val p = progress
            if (p != null) {
                voice.onProgress(instruction, p.currentManeuverIndex, p.distanceToNextManeuverMeters)
            }
        }
        progress?.let {
            distanceLabel = formatDistance(it.remainingDistanceMeters)
            etaLabel = formatDuration(it.remainingEtaSeconds)
            if (phase == NavigationPhase.NAVIGATING) {
                refreshLaybyForProgress(it.traveledDistanceMeters)
                val now = System.currentTimeMillis()
                if (now - lastRiskRefreshMs >= 5_000L) {
                    lastRiskRefreshMs = now
                    if (lastDriveTickMs > 0) {
                        val delta = (now - lastDriveTickMs) / 1_000.0
                        if (delta > 0 && delta < 120) {
                            recordDrivingSeconds(delta)
                        }
                    }
                    lastDriveTickMs = now
                    updateRiskFromProgress(it)
                    viewModelScope.launch {
                        refreshLiveTomTomHazardIfNeeded(it.traveledDistanceMeters)
                        refreshCrowdHazardAhead(it.traveledDistanceMeters)
                        refreshForecastRiskIfNeeded()
                        refreshOffRouteClearanceIfNeeded(lat, lon, bearingDegrees ?: lastKnownBearingDegrees)
                        refreshPredictiveRisk()
                    }
                }
            }
        }
    }

    private fun startGpsLoop() {
        gpsJob?.cancel()
        gpsJob = viewModelScope.launch {
            // Location injection is performed by the UI with FusedLocation; this loop publishes snapshots.
            while (isActive && session.phase == NavigationPhase.NAVIGATING) {
                val trip = activeTrip
                val lat = followLat
                val lon = followLon
                if (trip != null && lat != null && lon != null) {
                    try {
                        withContext(Dispatchers.IO) {
                            FleetApi(prefs.baseUrl, prefs.apiKey).publishSnapshot(
                                trip = trip,
                                status = trip.status,
                                driverLatitude = lat,
                                driverLongitude = lon,
                                driverLocationRecordedAt = Instant.now().toString(),
                            )
                        }
                    } catch (_: Exception) {
                    }
                }
                delay(20_000)
            }
        }
    }

    fun clearToast() {
        toastMessage = null
    }

    override fun onCleared() {
        sseJob?.cancel()
        healthJob?.cancel()
        gpsJob?.cancel()
        voice.shutdown()
        super.onCleared()
    }

    companion object {
        fun formatDistance(meters: Double): String =
            if (meters >= 1000) "%.1f km".format(meters / 1000.0) else "${meters.toInt()} m"

        fun formatDuration(seconds: Double): String {
            val minutes = (seconds / 60).toInt()
            return if (minutes < 60) "$minutes min" else "${minutes / 60}h ${minutes % 60}m"
        }
    }
}

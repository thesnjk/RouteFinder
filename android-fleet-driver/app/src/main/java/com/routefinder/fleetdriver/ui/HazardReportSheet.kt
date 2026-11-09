package com.routefinder.fleetdriver.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextField
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.routefinder.fleetdriver.hazard.HazardEventType

/** Waze-style sheet for submitting a local crowd hazard report (iOS HazardReportSheet parity). */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun HazardReportSheet(
    onSubmit: (HazardEventType, String?) -> Unit,
    onDismiss: () -> Unit,
) {
    var selectedType by remember { mutableStateOf(HazardEventType.TRAFFIC) }
    var note by remember { mutableStateOf("") }
    val reportable = listOf(
        HazardEventType.CLOSURE,
        HazardEventType.TRAFFIC,
        HazardEventType.CAMERA,
        HazardEventType.WEATHER,
        HazardEventType.OTHER,
    )

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Report hazard") },
        text = {
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                Text("What are you reporting?", style = MaterialTheme.typography.titleSmall)
                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    reportable.forEach { type ->
                        FilterChip(
                            selected = selectedType == type,
                            onClick = { selectedType = type },
                            label = { Text(labelFor(type)) },
                        )
                    }
                }
                TextField(
                    value = note,
                    onValueChange = { note = it },
                    modifier = Modifier.fillMaxWidth(),
                    label = { Text("Optional note") },
                    singleLine = false,
                    minLines = 2,
                    maxLines = 4,
                )
                Text(
                    "Saved on this device only — not uploaded to fleet. Planning aid.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.tertiary,
                )
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    val trimmed = note.trim()
                    onSubmit(selectedType, trimmed.ifEmpty { null })
                },
            ) {
                Text("Submit")
            }
        },
        dismissButton = {
            OutlinedButton(onClick = onDismiss) {
                Text("Cancel")
            }
        },
    )
}

private fun labelFor(type: HazardEventType): String = when (type) {
    HazardEventType.CLOSURE -> "Closure"
    HazardEventType.TRAFFIC -> "Traffic"
    HazardEventType.CAMERA -> "Camera"
    HazardEventType.WEATHER -> "Weather"
    HazardEventType.OTHER -> "Other"
}

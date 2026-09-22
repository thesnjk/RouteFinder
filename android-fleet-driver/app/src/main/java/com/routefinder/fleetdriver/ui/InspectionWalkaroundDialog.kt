package com.routefinder.fleetdriver.ui

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Base64
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextField
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.routefinder.fleetdriver.inspection.InspectionChecklistItem
import com.routefinder.fleetdriver.inspection.InspectionItemStatus
import java.io.ByteArrayOutputStream

@Composable
fun InspectionWalkaroundDialog(
    items: List<InspectionChecklistItem>,
    onUpdate: (Int, InspectionChecklistItem) -> Unit,
    onComplete: () -> Unit,
    onDismiss: () -> Unit,
) {
    val context = LocalContext.current
    var photoTargetIndex by remember { mutableIntStateOf(-1) }
    val photoLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.GetContent(),
    ) { uri ->
        val index = photoTargetIndex
        if (uri == null || index < 0 || index >= items.size) return@rememberLauncherForActivityResult
        val bytes = context.contentResolver.openInputStream(uri)?.use { it.readBytes() }
            ?: return@rememberLauncherForActivityResult
        val compressed = compressPhotoBudget(bytes)
        val item = items[index]
        onUpdate(index, item.copy(photoBase64 = compressed, status = InspectionItemStatus.DEFECT))
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("DVSA walkaround") },
        text = {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                Text(
                    "Mark every item Pass or Defect. Attach a photo on defects (size-budgeted).",
                    style = MaterialTheme.typography.bodySmall,
                )
                items.forEachIndexed { index, item ->
                    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text("${item.zone.label}: ${item.label}", style = MaterialTheme.typography.bodyMedium)
                        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            OutlinedButton(
                                onClick = {
                                    onUpdate(
                                        index,
                                        item.copy(
                                            status = InspectionItemStatus.PASS,
                                            note = "",
                                            photoBase64 = null,
                                        ),
                                    )
                                },
                            ) { Text("Pass") }
                            OutlinedButton(
                                onClick = {
                                    onUpdate(index, item.copy(status = InspectionItemStatus.DEFECT))
                                },
                            ) { Text("Defect") }
                        }
                        if (item.status == InspectionItemStatus.DEFECT) {
                            TextField(
                                value = item.note,
                                onValueChange = { onUpdate(index, item.copy(note = it)) },
                                modifier = Modifier.fillMaxWidth(),
                                label = { Text("Defect note") },
                                singleLine = true,
                            )
                            OutlinedButton(
                                onClick = {
                                    photoTargetIndex = index
                                    photoLauncher.launch("image/*")
                                },
                            ) {
                                Text(if (item.photoBase64 != null) "Photo attached" else "Add photo")
                            }
                        }
                    }
                }
            }
        },
        confirmButton = {
            Button(onClick = onComplete) { Text("Complete") }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Cancel") }
        },
    )
}

/** Compresses defect photos under ~180 KB for fleet snapshot budgets. */
internal fun compressPhotoBudget(raw: ByteArray, maxBytes: Int = 180_000): String {
    val bitmap = BitmapFactory.decodeByteArray(raw, 0, raw.size)
        ?: return Base64.encodeToString(raw, Base64.NO_WRAP)
    var quality = 85
    var out = ByteArrayOutputStream()
    bitmap.compress(Bitmap.CompressFormat.JPEG, quality, out)
    while (out.size() > maxBytes && quality > 40) {
        quality -= 15
        out = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.JPEG, quality, out)
    }
    if (out.size() > maxBytes) {
        val scaled = Bitmap.createScaledBitmap(
            bitmap,
            (bitmap.width * 0.5).toInt().coerceAtLeast(1),
            (bitmap.height * 0.5).toInt().coerceAtLeast(1),
            true,
        )
        out = ByteArrayOutputStream()
        scaled.compress(Bitmap.CompressFormat.JPEG, 60, out)
    }
    return Base64.encodeToString(out.toByteArray(), Base64.NO_WRAP)
}

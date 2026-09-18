package com.routefinder.fleetdriver.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.routefinder.fleetdriver.routing.GeocodeSuggestion

@Composable
fun GeocodeSearchField(
    label: String,
    value: String,
    suggestions: List<GeocodeSuggestion>,
    onValueChange: (String) -> Unit,
    onSelect: (GeocodeSuggestion) -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier.fillMaxWidth()) {
        OutlinedTextField(
            value = value,
            onValueChange = onValueChange,
            label = { Text(label) },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
        )
        suggestions.take(5).forEach { suggestion ->
            Text(
                text = suggestion.label,
                style = MaterialTheme.typography.bodyMedium,
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { onSelect(suggestion) }
                    .padding(horizontal = 12.dp, vertical = 10.dp),
            )
        }
    }
}

package co.munyati.providerstudio.presentation

import android.icu.text.MeasureFormat
import android.icu.util.Measure
import android.icu.util.MeasureUnit
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.clickable
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.outlined.AddPhotoAlternate
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import co.munyati.designsystem.theme.DS
import co.munyati.designsystem.theme.DSSpacing
import co.munyati.providerstudio.R
import co.munyati.shared.media.ImageCompressor
import co.munyati.shared.media.MediaUploading
import com.google.android.gms.maps.model.CameraPosition
import com.google.android.gms.maps.model.LatLng
import com.google.maps.android.compose.GoogleMap
import com.google.maps.android.compose.MapUiSettings
import com.google.maps.android.compose.rememberCameraPositionState
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.filter
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.Locale

/** Picks photos with the system photo picker, compresses and uploads them, reports the URLs. */
@Composable
internal fun PhotoUploadButton(uploader: MediaUploading, folder: String, maxCount: Int, onUploaded: (List<String>) -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var isUploading by remember { mutableStateOf(false) }
    var failed by remember { mutableStateOf(false) }

    fun upload(uris: List<android.net.Uri>) {
        if (uris.isEmpty()) return
        isUploading = true
        scope.launch {
            val urls = mutableListOf<String>()
            for (uri in uris) {
                val jpeg = withContext(Dispatchers.IO) { ImageCompressor.jpeg(context, uri) } ?: continue
                runCatching { uploader.uploadJpeg(jpeg, folder) }.onSuccess { urls += it }.onFailure { failed = true }
            }
            isUploading = false
            if (urls.isNotEmpty()) onUploaded(urls)
        }
    }

    val single = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { it?.let { uri -> upload(listOf(uri)) } }
    val multiple = rememberLauncherForActivityResult(ActivityResultContracts.PickMultipleVisualMedia(maxCount.coerceAtLeast(2))) { upload(it.take(maxCount)) }
    val request = PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)

    Row(
        Modifier.heightIn(min = 44.dp).clickable(enabled = !isUploading && maxCount >= 1, role = Role.Button) {
            if (maxCount == 1) single.launch(request) else multiple.launch(request)
        }.padding(horizontal = DSSpacing.xs),
        horizontalArrangement = Arrangement.spacedBy(DSSpacing.xs),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (isUploading) {
            CircularProgressIndicator(color = DS.colors.primary, strokeWidth = 2.dp, modifier = Modifier.size(20.dp))
        } else {
            Icon(Icons.Outlined.AddPhotoAlternate, contentDescription = null, tint = DS.colors.primary)
        }
        Text(stringResource(if (maxCount == 1) R.string.studio_photo_pickOne else R.string.studio_photo_pick), style = DS.type.body, color = DS.colors.primary)
    }

    if (failed) {
        AlertDialog(
            onDismissRequest = { failed = false },
            title = { Text(stringResource(R.string.studio_photo_failed)) },
            confirmButton = { TextButton(onClick = { failed = false }) { Text(stringResource(R.string.studio_common_ok)) } },
        )
    }
}

/** Map with a fixed centre pin: the provider moves the map under the pin to set a location. */
@Composable
internal fun LocationPicker(lat: Double?, lng: Double?, mapsAvailable: Boolean, onChange: (Double, Double) -> Unit) {
    if (!mapsAvailable) return
    val camera = rememberCameraPositionState { position = CameraPosition.fromLatLngZoom(LatLng(lat ?: 26.35, lng ?: 50.12), 13f) }
    LaunchedEffect(camera) {
        snapshotFlow { camera.isMoving }.filter { !it }.collect {
            camera.position.target.let { onChange(it.latitude, it.longitude) }
        }
    }
    val hint = stringResource(R.string.studio_location_hint)
    Box(Modifier.fillMaxWidth().height(220.dp).clip(RoundedCornerShape(16.dp)).semantics { contentDescription = hint }) {
        GoogleMap(cameraPositionState = camera, uiSettings = MapUiSettings(zoomControlsEnabled = false, mapToolbarEnabled = false))
        Icon(Icons.Filled.LocationOn, contentDescription = null, tint = DS.colors.primary, modifier = Modifier.align(Alignment.Center).offset(y = (-16).dp).size(40.dp))
    }
}

/** Multi-select list (categories, cities) in a dialog. */
@Composable
internal fun MultiSelectDialog(
    title: String,
    options: List<Pair<String, String>>,
    selection: Set<String>,
    onDone: (Set<String>) -> Unit,
) {
    var chosen by remember { mutableStateOf(selection) }
    AlertDialog(
        onDismissRequest = { onDone(chosen) },
        title = { Text(title) },
        text = {
            Column(Modifier.verticalScroll(rememberScrollState())) {
                options.forEach { (id, name) ->
                    Row(
                        Modifier.fillMaxWidth().heightIn(min = 48.dp).clickable(role = Role.Checkbox) {
                            chosen = if (id in chosen) chosen - id else chosen + id
                        },
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(name, style = DS.type.body, color = DS.colors.textPrimary, modifier = Modifier.weight(1f))
                        if (id in chosen) Icon(Icons.Filled.Check, contentDescription = null, tint = DS.colors.primary)
                    }
                }
            }
        },
        confirmButton = { TextButton(onClick = { onDone(chosen) }) { Text(stringResource(R.string.studio_common_ok)) } },
    )
}

/** "1 hr, 30 min" — short unit names in the current language (iOS `.short` style). */
internal fun durationLabel(minutes: Int, locale: Locale = Locale.getDefault()): String {
    val format = MeasureFormat.getInstance(locale, MeasureFormat.FormatWidth.SHORT)
    val hours = minutes / 60
    val rest = minutes % 60
    return when {
        hours == 0 -> format.formatMeasures(Measure(rest, MeasureUnit.MINUTE))
        rest == 0 -> format.formatMeasures(Measure(hours, MeasureUnit.HOUR))
        else -> format.formatMeasures(Measure(hours, MeasureUnit.HOUR), Measure(rest, MeasureUnit.MINUTE))
    }
}

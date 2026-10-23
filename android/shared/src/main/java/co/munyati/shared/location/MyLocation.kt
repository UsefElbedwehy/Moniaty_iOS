package co.munyati.shared.location

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.MyLocation
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import co.munyati.designsystem.theme.DS
import co.munyati.shared.R

/**
 * "Where am I" on a map, like iOS's `UserAnnotation` + `MapUserLocationButton`: the app asks for
 * location only when the user taps the button (approximate is enough), then shows the blue dot
 * and moves the map there. Nothing is stored or sent anywhere.
 */
class MyLocationState internal constructor(granted: Boolean) {
    /** Turn on the map's blue dot when true. */
    var granted by mutableStateOf(granted)
        internal set
}

@Composable
fun rememberMyLocationState(): MyLocationState {
    val context = LocalContext.current
    return remember { MyLocationState(hasLocationPermission(context)) }
}

/**
 * The round "my location" button. Asks for permission the first time; once allowed, calls
 * [onLocation] with the last known position (or nothing when the phone has none yet).
 */
@Composable
fun MyLocationButton(state: MyLocationState, modifier: Modifier = Modifier, onLocation: (lat: Double, lng: Double) -> Unit) {
    val context = LocalContext.current
    val request = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { result ->
        state.granted = result.values.any { it }
        if (state.granted) lastKnownLocation(context)?.let { onLocation(it.latitude, it.longitude) }
    }
    IconButton(
        onClick = {
            if (state.granted) {
                lastKnownLocation(context)?.let { onLocation(it.latitude, it.longitude) }
            } else {
                request.launch(arrayOf(Manifest.permission.ACCESS_COARSE_LOCATION, Manifest.permission.ACCESS_FINE_LOCATION))
            }
        },
        modifier = modifier.size(44.dp).shadow(3.dp, CircleShape).clip(CircleShape)
            .background(DS.colors.surface).border(1.dp, DS.colors.border, CircleShape),
    ) {
        Icon(Icons.Filled.MyLocation, stringResource(R.string.shared_location_mine), tint = DS.colors.primary)
    }
}

fun hasLocationPermission(context: Context): Boolean =
    listOf(Manifest.permission.ACCESS_COARSE_LOCATION, Manifest.permission.ACCESS_FINE_LOCATION).any {
        ContextCompat.checkSelfPermission(context, it) == PackageManager.PERMISSION_GRANTED
    }

/** The freshest position any provider already has; no GPS fix is started for this. */
@SuppressLint("MissingPermission")
fun lastKnownLocation(context: Context): Location? {
    if (!hasLocationPermission(context)) return null
    val manager = context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager ?: return null
    return runCatching {
        manager.getProviders(true).mapNotNull { manager.getLastKnownLocation(it) }.maxByOrNull { it.time }
    }.getOrNull()
}

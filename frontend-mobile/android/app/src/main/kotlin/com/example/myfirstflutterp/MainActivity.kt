package com.example.myfirstflutterp

import android.Manifest
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val timeout = Handler(Looper.getMainLooper())
    private val locationManager by lazy { getSystemService(LOCATION_SERVICE) as LocationManager }
    private var pendingLocation: MethodChannel.Result? = null
    private var listener: LocationListener? = null
    private val locationTimeout = Runnable { finishLocation(null) }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "campussave/location"
        ).setMethodCallHandler { call, result ->
            when {
                call.method != "currentPosition" -> result.notImplemented()
                pendingLocation != null -> result.success(null)
                else -> {
                    pendingLocation = result
                    if (hasLocationPermission()) {
                        requestFix()
                    } else {
                        requestPermissions(
                            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION),
                            RADAR_PERMISSION
                        )
                    }
                }
            }
        }
    }

    private fun hasLocationPermission(): Boolean =
        checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
            checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != RADAR_PERMISSION || pendingLocation == null) return
        if (hasLocationPermission()) requestFix() else finishLocation(null)
    }

    @Suppress("DEPRECATION", "MissingPermission")
    private fun requestFix() {
        val manager = locationManager
        val hasFine = checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        val providers = if (hasFine) {
            listOf(LocationManager.NETWORK_PROVIDER, LocationManager.GPS_PROVIDER)
        } else {
            listOf(LocationManager.NETWORK_PROVIDER)
        }
        val available = providers.filter(manager::isProviderEnabled)
        if (available.isEmpty()) {
            finishLocation(null)
            return
        }
        val callback = object : LocationListener {
            override fun onLocationChanged(location: Location) = finishLocation(location)
            override fun onProviderDisabled(provider: String) {}
            override fun onProviderEnabled(provider: String) {}
            override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
        }
        listener = callback
        try {
            timeout.postDelayed(locationTimeout, 12_000L)
            for (provider in available) {
                manager.requestSingleUpdate(provider, callback, Looper.getMainLooper())
            }
        } catch (_: SecurityException) {
            finishLocation(null)
        } catch (_: IllegalArgumentException) {
            finishLocation(null)
        }
    }

    private fun finishLocation(location: Location?) {
        timeout.removeCallbacks(locationTimeout)
        listener?.let(locationManager::removeUpdates)
        listener = null
        val result = pendingLocation
        pendingLocation = null
        result?.success(location?.let { listOf(it.latitude, it.longitude) })
    }

    override fun onDestroy() {
        finishLocation(null)
        super.onDestroy()
    }

    private companion object {
        const val RADAR_PERMISSION = 209
    }
}

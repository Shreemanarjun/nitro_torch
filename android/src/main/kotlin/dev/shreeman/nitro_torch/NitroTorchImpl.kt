package dev.shreeman.nitro_torch

import android.annotation.SuppressLint
import android.content.Context
import android.hardware.camera2.CameraAccessException
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.os.Build
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.launch
import nitro.nitro_torch_module.HybridNitroTorchSpec
import nitro.nitro_torch_module.TorchLevel
import nitro.nitro_torch_module.TorchState
import org.json.JSONObject

class NitroTorchImpl : HybridNitroTorchSpec {

    companion object {
        private const val TAG = "HybridTorch"
    }

    private var cameraId: String? = null
    private var isTorchOn: Boolean = false

    private val _onLevelChanged = MutableSharedFlow<TorchLevel>(extraBufferCapacity = 16)
    private val _onTorchStateChanged = MutableSharedFlow<TorchState>(extraBufferCapacity = 16)

    override val onLevelChanged: Flow<TorchLevel> = _onLevelChanged
    override val onTorchStateChanged: Flow<TorchState> = _onTorchStateChanged

    private val cameraManager: CameraManager? by lazy {
        try {
            applicationContext.getSystemService(Context.CAMERA_SERVICE) as? CameraManager
        } catch (e: Exception) {
            Log.e(TAG, "Error initializing CameraManager", e)
            null
        }
    }

    private val torchCallback = object : CameraManager.TorchCallback() {
        override fun onTorchModeChanged(camId: String, enabled: Boolean) {
            if (camId != cameraId) return
            isTorchOn = enabled
            val state = if (enabled) TorchState.ON else TorchState.OFF
            CoroutineScope(Dispatchers.Default).launch { _onTorchStateChanged.emit(state) }
        }

        @SuppressLint("NewApi")
        override fun onTorchStrengthLevelChanged(camId: String, newStrengthLevel: Int) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
            if (camId != cameraId) return
            val max = maxLevel()
            CoroutineScope(Dispatchers.Default).launch {
                _onLevelChanged.emit(TorchLevel(level = newStrengthLevel.toLong(), maxLevel = max))
            }
        }
    }

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    override fun onAttached() {
        ensureCameraId()
        cameraManager?.registerTorchCallback(torchCallback, null)
        Log.d(TAG, "Attached — camera: $cameraId, maxLevel: ${maxLevel()}")
    }

    override fun onDetached() {
        cameraManager?.unregisterTorchCallback(torchCallback)
        Log.d(TAG, "Detached")
    }

    // ── API ───────────────────────────────────────────────────────────────────

    override fun add(a: Double, b: Double): Double = a + b

    override suspend fun getGreeting(name: String): String = "Hello, $name!"

    override fun turnOn() {
        try {
            setTorchMode(true)
        } catch (e: TorchException) {
            handleTorchException(e)
        }
    }

    override fun turnOff() {
        try {
            setTorchMode(false)
        } catch (e: TorchException) {
            handleTorchException(e)
        }
    }

    override fun getStatus(): Boolean = isTorchOn

    override fun toggle() {
        try {
            setTorchMode(!isTorchOn)
        } catch (e: TorchException) {
            handleTorchException(e)
        }
    }

    override fun setLevel(level: Long) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            throw Error(
                createTorchErrorJson(
                    "BrightnessControlNotSupported",
                    "Torch brightness control requires Android 13 (API 33) or higher",
                )
            )
        }
        val manager = cameraManager ?: run {
            handleTorchException(TorchException.CameraServiceUnavailable())
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            handleTorchException(TorchException.ApiLevelTooLow())
        }
        ensureCameraId()
        val id = cameraId ?: handleTorchException(TorchException.NoFlashAvailable)
        try {
            @SuppressLint("NewApi")
            manager.turnOnTorchWithStrengthLevel(id, level.toInt())
        } catch (e: CameraAccessException) {
            handleTorchException(TorchException.AccessFailed(e))
        } catch (e: Exception) {
            handleTorchException(TorchException.AccessFailed(e))
        }
    }

    override fun maxLevel(): Long {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return 1L
        val manager = cameraManager ?: return 1L
        ensureCameraId()
        val id = cameraId ?: return 1L
        return try {
            val characteristics = manager.getCameraCharacteristics(id)
            @SuppressLint("NewApi")
            val max = characteristics.get(CameraCharacteristics.FLASH_INFO_STRENGTH_MAXIMUM_LEVEL)
            max?.toLong() ?: 1L
        } catch (e: Exception) {
            1L
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private fun setTorchMode(enable: Boolean) {
        val manager = cameraManager ?: throw TorchException.CameraServiceUnavailable()
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) throw TorchException.ApiLevelTooLow()
        ensureCameraId()
        val id = cameraId ?: throw TorchException.NoFlashAvailable
        if (isTorchOn == enable) return
        try {
            manager.setTorchMode(id, enable)
        } catch (e: CameraAccessException) {
            throw TorchException.AccessFailed(e)
        } catch (e: Exception) {
            throw TorchException.AccessFailed(e)
        }
    }

    private fun ensureCameraId() {
        if (cameraId != null) return
        val manager = cameraManager ?: return
        try {
            cameraId = manager.cameraIdList.firstOrNull { id ->
                val chars = manager.getCameraCharacteristics(id)
                val hasFlash = chars.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) ?: false
                val facing = chars.get(CameraCharacteristics.LENS_FACING)
                hasFlash && facing == CameraCharacteristics.LENS_FACING_BACK
            } ?: manager.cameraIdList.firstOrNull()
        } catch (e: CameraAccessException) {
            Log.e(TAG, "Cannot access camera list", e)
        }
    }

    private fun handleTorchException(e: TorchException): Nothing {
        val (code, message) = when (e) {
            is TorchException.ApiLevelTooLow -> "ApiLevelTooLow" to (e.message ?: "")
            is TorchException.CameraServiceUnavailable -> "CameraServiceUnavailable" to (e.message ?: "")
            is TorchException.NoFlashAvailable -> "NoFlashAvailable" to (e.message ?: "")
            is TorchException.BrightnessControlNotSupported -> "BrightnessControlNotSupported" to (e.message ?: "")
            is TorchException.AccessFailed -> "AccessFailed" to (e.message ?: "")
        }
        Log.e(TAG, "$code: $message")
        throw Error(createTorchErrorJson(code, message))
    }

    private fun createTorchErrorJson(code: String, message: String): String {
        val obj = JSONObject()
        obj.put("code", code)
        obj.put("message", message)
        return obj.toString()
    }
}

sealed class TorchException(message: String) : Exception(message) {
    class CameraServiceUnavailable : TorchException("Camera service not available")
    class ApiLevelTooLow : TorchException("Android API 23 or higher is required")
    object NoFlashAvailable : TorchException("No camera with flash available")
    object BrightnessControlNotSupported : TorchException("Device does not support torch brightness control")
    class AccessFailed(cause: Throwable) : TorchException("Failed to access torch: ${cause.message}")
}

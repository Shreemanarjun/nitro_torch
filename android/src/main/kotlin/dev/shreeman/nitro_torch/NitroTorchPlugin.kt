package dev.shreeman.nitro_torch

import io.flutter.embedding.engine.plugins.FlutterPlugin
import nitro.nitro_torch_module.NitroTorchJniBridge

class NitroTorchPlugin : FlutterPlugin {

    companion object {
        init { System.loadLibrary("nitro_torch") }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        NitroTorchJniBridge.register(
            NitroTorchImpl(binding.applicationContext)
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {}
}
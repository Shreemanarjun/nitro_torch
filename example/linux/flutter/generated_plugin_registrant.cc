//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <nitro_torch/nitro_torch_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) nitro_torch_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "NitroTorchPlugin");
  nitro_torch_plugin_register_with_registrar(nitro_torch_registrar);
}

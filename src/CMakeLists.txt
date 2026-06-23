cmake_minimum_required(VERSION 3.10)
project(nitro_torch_library VERSION 0.0.1 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(NITRO_NATIVE "${CMAKE_CURRENT_SOURCE_DIR}/native")
# NITRO_LINK_SPEC_CHECKSUM 309deccb21f6ec22
set(GENERATED_CPP "${CMAKE_CURRENT_SOURCE_DIR}/../lib/src/generated/cpp")

add_library(nitro_torch SHARED
  "nitro_torch.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/../lib/src/generated/cpp/nitro_torch.bridge.g.cpp"
  "dart_api_dl.c"
)

if(NOT ANDROID)
  target_sources(nitro_torch PRIVATE "HybridNitroTorch.cpp")
endif()
target_include_directories(nitro_torch PRIVATE
  "${CMAKE_CURRENT_SOURCE_DIR}"
  "${GENERATED_CPP}"
  "${NITRO_NATIVE}"
)

target_compile_definitions(nitro_torch PUBLIC DART_SHARED_LIB)

if(ANDROID)
  target_link_libraries(nitro_torch PRIVATE android log)
  target_link_options(nitro_torch PRIVATE "-Wl,-z,max-page-size=16384")
endif()

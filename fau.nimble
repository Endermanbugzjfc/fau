version       = "0.0.1"
author        = "Anuken"
description   = "WIP Nim game framework"
license       = "MIT"
srcDir        = "src"
bin           = @["fau/tools/faupack"]
binDir        = "build"

requires "nim >= 2.0.0"
requires "https://github.com/Anuken/staticglfw#28f27b2c4bff0e21084e820dae368addb6ea5236"
requires "https://github.com/Anuken/glfm#eac00f1d5df3b9f72d8bc00b8cb16190b0638dff"
requires "https://github.com/Anuken/nimsoloud#aa3070b314cf4d1a8675d4893f317875d4e701dc"
requires "https://github.com/Anuken/polymorph#170f1b22c1d13828ad9ef84237b9d4d408b77cc6"
requires "cligen == 1.6.17"
requires "chroma == 0.2.7"
requires "pixie == 5.0.6"
requires "vmath == 2.0.0"
requires "stbimage == 2.5"
requires "https://www.github.com/Anuken/jsony#b8c0edbac379b0507c1967c56725ecf442cfd6d7"

task imguiGen, "Generate imGUI bindings from source":
  exec("nim r src/fau/tools/imgui_gen.nim")

task imguiTest, "Run imGUI test apppplication":
  exec("nim -d:fauTests -d:debug r src/fau/test/test_imgui.nim")

task entityEditTest, "Run entity edit test apppplication":
  exec("nim -d:fauTests -d:debug r src/fau/test/test_entityedit.nim")

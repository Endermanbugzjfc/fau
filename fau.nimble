version       = "0.0.1"
author        = "Anuken"
description   = "WIP Nim game framework"
license       = "MIT"
srcDir        = "src"
bin           = @["fau/tools/faupack", "fau/tools/antialias", "fau/tools/fauproject", "fau/tools/bleed"]
binDir        = "build"

requires "nim >= 1.4.8"
requires "https://github.com/Anuken/staticglfw#d30a512379330550c3c2255f32727aa2e8edcd81"
requires "polymorph == 0.3.0"
requires "cligen == 1.5.19"
requires "chroma == 0.2.5"
# requires "pixie == 4.0.1"
# requires "vmath == 1.0.8"
# requires "stb_image == 2.5"

requires "vmath == 1.1.4"
requires "https://github.com/Endermanbugzjfc/pixie#2a7d897fa0b021523ea76f6b794a12e6a7c02c5c"
requires "https://github.com/define-private-public/stb_image-Nim#ba5f45286bfa9bed93d8d6b941949cd6218ec888"


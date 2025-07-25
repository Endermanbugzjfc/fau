import globals, batch, fmath, color, patch, mesh, shader, framebuffer, math, texture, lenientops, atlas, tables, screenbuffer
export batch #for aligns

## Drawing utilities based on global state.

#renders the fullscreen mesh with u_texture set to the specified buffer
proc blit*(buffer: Texture | Framebuffer, shader: Shader = fau.screenspace, params = meshParams()) =
  fau.quad.render(shader, params):
    texture = buffer.sampler

#renders the fullscreen mesh
template blit*(shader: Shader, params = meshParams(), body: untyped) =
  fau.quad.render(shader, params, body)

proc patch*(name: string): Patch {.inline.} = fau.atlas[name]

proc patch*(name: string, notFound: string): Patch {.inline.} = fau.atlas.patches.getOrDefault(name, fau.atlas[notFound])

proc patch9*(name: string): Patch9 {.inline.} = fau.atlas.patches9.getOrDefault(name, fau.atlas.error9)

proc drawFlush*() =
  fau.batch.flush()

proc drawSort*(sort: bool) =
  fau.batch.sort(sort)

proc drawMat*(mat: Mat) =
  fau.batch.mat(mat)

proc drawViewport*(rect = rect()) =
  fau.batch.viewport(rect)

#TODO should use a stack.
proc drawClip*(clipped = rect(), view = fau.cam.screenBounds): bool {.discardable.} =
  if clipped.w.int > 0 and clipped.h.int > 0:
    #transform clipped rectangle from world into screen space
    let
      topRight = project(fau.batch.mat, clipped.topRight, view)
      botLeft = project(fau.batch.mat, clipped.botLeft, view)

    fau.batch.clip(rect(botLeft, topRight - botLeft))
    return true
  else:
    fau.batch.clip(rect())
    return false

template drawClipped*(clip: Rect, body: untyped) =
  if drawClip(clip):
    body
    drawClip()

proc drawBuffer*(buffer: Framebuffer) =
  fau.batch.buffer(buffer)

proc drawBufferScreen*() =
  fau.batch.buffer(screen)

proc beginCache*(sort = true) =
  drawSort(sort)
  fau.batch.beginCache()

proc endCache*(): SpriteCache =
  result = fau.batch.endCache()
  drawSort(true)

proc screenMat*() =
  drawMat(ortho(vec2(), fau.size))

#Activates a camera.
proc use*(cam: Cam, size = cam.size, pos = cam.pos, screenBounds = rect(vec2(), fau.size)) =
  drawFlush()
  cam.update(screenBounds, size, pos)
  drawMat cam.mat

proc draw*(cache: SpriteCache) =
  ## Draws pre-cached sprite data.
  fau.batch.draw(cache)

#Draws something custom at a specific Z layer
proc draw*(z: float32, callback: proc()) =
  fau.batch.draw(z, callback)

#Custom handling of begin/end for a specific Z layer
proc drawLayer*(z: float32, layerBegin, layerEnd: proc(), spread: float32 = 1) =
  draw(z - spread, layerBegin)
  draw(z + spread, layerEnd)

proc draw*(
  region: Patch, pos: Vec2, 
  size = region.size * fau.pixelScl,
  z = 0f,
  scl = vec2(1f),
  origin = size * 0.5f * scl, 
  rotation = 0f, align = daCenter,
  color = colorWhite, mixColor = colorClear, 
  blend = blendNormal, shader: Shader = nil) {.inline.} =

  let 
    alignH = (-(asLeft in align).float32 + (asRight in align).float32 + 1f) / 2f
    alignV = (-(asBot in align).float32 + (asTop in align).float32 + 1f) / 2f

  fau.batch.draw(
    z, region, pos - size * vec2(alignH, alignV) * scl, 
    size * scl, origin,rotation, color, mixColor, blend, shader
  )

proc draw*(
  region: Patch, bounds: Rect,
  z = 0f,
  origin = bounds.center, 
  rotation = 0f, align = daCenter,
  color = colorWhite, mixColor = colorClear, 
  blend = blendNormal, shader: Shader = nil) {.inline.} = draw(region, bounds.xy, bounds.size, 0f, vec2(1f), origin, rotation, daBotLeft, color, mixColor, blend, shader)

#draws a region with rotated bits
proc drawv*(region: Patch, pos: Vec2, corners: array[4, Vec2], z = 0f, scl = vec2(1f), size = region.size * fau.pixelScl,
  origin = size * 0.5f * scl, rotation = 0f, align = daCenter,
  color = colorWhite, mixColor = colorClear,
  blend = blendNormal, shader: Shader = nil) =

  let
    alignH = (-(asLeft in align).float32 + (asRight in align).float32 + 1f) / 2f
    alignV = (-(asBot in align).float32 + (asTop in align).float32 + 1f) / 2f
    worldOriginX: float32 = pos.x + origin.x - size.x * scl.x * alignH
    worldOriginY: float32 = pos.y + origin.y - size.y * scl.y * alignV
    fx: float32 = -origin.x
    fy: float32 = -origin.y
    fx2: float32 = size.x * scl.x - origin.x
    fy2: float32 = size.y * scl.y - origin.y
    cos: float32 = cos(rotation.degToRad)
    sin: float32 = sin(rotation.degToRad)
    x1 = cos * fx - sin * fy + worldOriginX
    y1 = sin * fx + cos * fy + worldOriginY
    x2 = cos * fx - sin * fy2 + worldOriginX
    y2 = sin * fx + cos * fy2 + worldOriginY
    x3 = cos * fx2 - sin * fy2 + worldOriginX
    y3 = sin * fx2 + cos * fy2 + worldOriginY
    x4 = x1 + (x3 - x2)
    y4 = y3 - (y2 - y1)
    u = region.u
    v = region.v2
    u2 = region.u2
    v2 = region.v
    cor1 = corners[0] + vec2(x1, y1)
    cor2 = corners[1] + vec2(x2, y2)
    cor3 = corners[2] + vec2(x3, y3)
    cor4 = corners[3] + vec2(x4, y4)
    cf = color
    mf = mixColor

  fau.batch.draw(
    z,
    region.texture, 
    [vert2(cor1.x, cor1.y, u, v, cf, mf), vert2(cor2.x, cor2.y, u, v2, cf, mf), vert2(cor3.x, cor3.y, u2, v2, cf, mf), vert2(cor4.x, cor4.y, u2, v, cf, mf)], 
    blend, shader
  )

proc drawRect*(region: Patch, x, y, width, height: float32, originX = 0f, originY = 0f,
  rotation = 0f, color = colorWhite, mixColor = colorClear, z: float32 = 0.0,
  blend = blendNormal, shader: Shader = nil) {.inline.} =
  fau.batch.draw(z, region, vec2(x, y), vec2(width, height), vec2(originX, originY), rotation, color, mixColor, blend, shader)

proc drawRect*(region: Patch, rect: Rect, origin = vec2(),
  rotation = 0f, color = colorWhite, mixColor = colorClear, z: float32 = 0.0,
  blend = blendNormal, shader: Shader = nil) {.inline.} =

  drawRect(region, rect.x, rect.y, rect.w, rect.h, origin.x, origin.y, rotation, color, mixColor, z, blend, shader)

proc drawVert*(texture: Texture, vertices: array[4, Vert2], z: float32 = 0, blend = blendNormal, shader: Shader = nil) {.inline.} = 
  fau.batch.draw(z, texture, vertices, blend, shader)

proc draw*(p: Patch9, pos: Vec2, size: Vec2, z: float32 = 0f, color = colorWhite, mixColor = colorClear, scale = 1f, blend = blendNormal) =
  let
    x = pos.x
    y = pos.y
    width = size.x
    height = size.y

  #bot left
  drawRect(p.patches[0], x, y, p.left * scale, p.bot * scale, z = z, color = color, mixColor = mixColor, blend = blend)
  #bot
  drawRect(p.patches[1], x + p.left * scale, y, width - (p.right + p.left) * scale, p.bot * scale, z = z, color = color, mixColor = mixColor, blend = blend)
  #bot right
  drawRect(p.patches[2], x + p.left * scale + width - (p.right + p.left) * scale, y, p.right * scale, p.bot * scale, z = z, color = color, mixColor = mixColor, blend = blend)

  #mid left
  drawRect(p.patches[3], x, y + p.bot * scale, p.left * scale, height - (p.top + p.bot) * scale, z = z, color = color, mixColor = mixColor, blend = blend)
  #mid
  drawRect(p.patches[4], x + p.left * scale, y + p.bot * scale, width - (p.right + p.left) * scale, height - (p.top + p.bot) * scale, z = z, color = color, mixColor = mixColor, blend = blend)
  #mid right
  drawRect(p.patches[5], x + p.left * scale + width - (p.right + p.left) * scale, y + p.bot * scale, p.right * scale, height - (p.top + p.bot) * scale, z = z, color = color, mixColor = mixColor, blend = blend)

  #top left
  drawRect(p.patches[6], x, y + p.bot * scale + height - (p.top + p.bot) * scale, p.left * scale, p.top * scale, z = z, color = color, mixColor = mixColor, blend = blend)
  #top
  drawRect(p.patches[7], x + p.left * scale, y + p.bot * scale + height - (p.top + p.bot) * scale, width - (p.right + p.left) * scale, p.top * scale, z = z, color = color, mixColor = mixColor, blend = blend)
  #top right
  drawRect(p.patches[8], x + p.left * scale + width - (p.right + p.left) * scale, y + p.bot * scale + height - (p.top + p.bot) * scale, p.right * scale, p.top * scale, z = z, color = color, mixColor = mixColor, blend = blend)

proc draw*(p: Patch9, bounds: Rect, z: float32 = 0f, color = colorWhite, mixColor = colorClear, scale = 1f, blend = blendNormal) =
  draw(p, bounds.pos, bounds.size, z, color, mixColor, scale, blend = blend)

proc drawBlit*(buffer: Framebuffer, color = colorWhite, blend = blendNormal, z = 0f, shader: Shader = nil) =
  draw(buffer.texture, fau.cam.pos, fau.cam.size * vec2(1f, -1f), color = color, blend = blend, z = z, shader = shader)

#TODO does not support mid != 0
#TODO divs could just be a single float value, arrays unnecessary
proc drawBend*(p: Patch, pos: Vec2, divs: openArray[float32], mid = 0, rotation = 0f, z: float32 = 0f, size = p.size * fau.pixelScl, scl = vec2(1f, 1f), color = colorWhite, mixColor = colorClear) = 
  let 
    outs = size * scl
    v = p.v
    v2 = p.v2
    segSpace = outs.x / divs.len.float32

  var 
    cur = rotation
    cpos = pos

  template drawAt(i: int, sign: float32) =
    let
      mid1 = cpos
      top1 = vec2l(cur + 90f.rad, outs.y / 2f)
      top2 = vec2l(cur + 90f.rad + divs[i] * sign, outs.y / 2f)
      progress = i / (divs.len).float32 - (1f / divs.len) * -(sign < 0).float32
      u = lerp(p.u, p.u2, progress)
      u2 = lerp(p.u, p.u2, progress + 1f / divs.len * sign)
      
    cpos += vec2l(cur, segSpace) * sign

    let 
      mid2 = cpos
      p1 = mid1 + top1
      p2 = mid2 + top2
      p3 = mid2 - top2
      p4 = mid1 - top1
    
    drawVert(p.texture, [
      vert2(p1, vec2(u, v), color, mixColor),
      vert2(p2, vec2(u2, v), color, mixColor),
      vert2(p3, vec2(u2, v2), color, mixColor),
      vert2(p4, vec2(u, v2), color, mixColor)
    ], z = z)

    cur += divs[i] * sign

  for i in mid..<divs.len:
    drawAt(i, 1f)
  
  cur = rotation
  cpos = pos

  for i in countdown(mid - 1, 0):
    drawAt(i, -1f)

proc fillQuad*(texture: Texture,
    v1: Vec2, c1: Color, uv1: Vec2,
    v2: Vec2, c2: Color, uv2: Vec2,
    v3: Vec2, c3: Color, uv3: Vec2,
    v4: Vec2, c4: Color, uv4: Vec2,
    z: float32 = 0, blend = blendNormal, shader: Shader = nil
  ) =
  drawVert(texture, [vert2(v1, uv1, c1), vert2(v2, uv2, c2),  vert2(v3, uv3, c3), vert2(v4, uv4, c4)], z, blend = blend, shader = shader)

proc fillQuad*(v1: Vec2, c1: Color, v2: Vec2, c2: Color, v3: Vec2, c3: Color, v4: Vec2, c4: Color, z: float32 = 0, blend = blendNormal) =
  drawVert(fau.white.texture, [vert2(v1, fau.white.uv, c1), vert2(v2, fau.white.uv, c2),  vert2(v3, fau.white.uv, c3), vert2(v4, fau.white.uv, c4)], z, blend = blend)

proc fillQuad*(v1, v2, v3, v4: Vec2, color: Color, z = 0f, blend = blendNormal) =
  fillQuad(v1, color, v2, color, v3, color, v4, color, z, blend = blend)

proc fillRect*(x, y, w, h: float32, color = colorWhite, z = 0f, blend = blendNormal) =
  drawRect(fau.white, x, y, w, h, color = color, z = z, blend = blend)

proc fillSquare*(pos: Vec2, radius: float32, color = colorWhite, z = 0f, blend = blendNormal) =
  draw(fau.white, pos, size = vec2(radius * 2f), color = color, z = z, blend = blend)

proc fillRect*(rect: Rect, color = colorWhite, z = 0f, blend = blendNormal) =
  fillRect(rect.x, rect.y, rect.w, rect.h, color, z, blend = blend)

proc fillTri*(v1, v2, v3: Vec2, color: Color, z: float32 = 0, blend = blendNormal) =
  fillQuad(v1, color, v2, color, v3, color, v3, color, z, blend = blend)

proc fillTri*(v1, v2, v3: Vec2, c1, c2, c3: Color, z: float32 = 0, blend = blendNormal) =
  fillQuad(v1, c1, v2, c2, v3, c3, v3, c3, z, blend = blend)

proc fillCircle*(pos: Vec2, rad: float32, color: Color = colorWhite, z: float32 = 0, blend = blendNormal, scl = vec2(1f)) =
  draw(fau.circle, pos, size = vec2(rad*2f), scl = scl, color = color, z = z, blend = blend)

proc fillPoly*(pos: Vec2, sides: int, radius: float32, rotation = 0f, color = colorWhite, z: float32 = 0, scl = vec2(1f), blend = blendNormal) =
  if sides == 3:

    fillTri(
      pos + vec2l(0f + rotation, radius) * scl,
      pos + vec2l(120f.rad + rotation, radius) * scl,
      pos + vec2l(240f.rad + rotation, radius) * scl,
      color, z, blend
    )
  elif sides == 4:

    fillQuad(
      pos + vec2l(0f + rotation, radius) * scl,
      pos + vec2l(90f.rad + rotation, radius) * scl,
      pos + vec2l(180f.rad + rotation, radius) * scl,
      pos + vec2l(270f.rad + rotation, radius) * scl,
      color, z, blend
    )
  else:

    let space = PI*2 / sides.float32

    for i in countup(0, sides - 2, 2):
      fillQuad(
        pos,
        pos + vec2(cos(space * (i).float32 + rotation), sin(space * (i).float32 + rotation)) * radius * scl,
        pos + vec2(cos(space * (i + 1).float32 + rotation), sin(space * (i + 1).float32 + rotation)) * radius * scl,
        pos + vec2(cos(space * (i + 2).float32 + rotation), sin(space * (i + 2).float32 + rotation)) * radius * scl,
        color, z, blend
      )
    
    let md = sides mod 2

    if md != 0:
      let i = sides - 1
      fillTri(
        pos,
        pos + vec2(cos(space * i.float32 + rotation), sin(space * i.float32 + rotation)) * radius * scl,
        pos + vec2(cos(space * (i + 1).float32 + rotation), sin(space * (i + 1).float32 + rotation)) * radius * scl,
        color, z, blend
      )

proc fillDropShadow*(rect: Rect, blur: float32, color = colorBlack, z = 0f) =
  let 
    edge = color.withA(0f)
    ir = rect.grow(-blur)
  
  #center
  fillRect(ir, color = color, z = z)

  #bottom
  fillQuad(
    ir.xy, color,
    rect.xy, edge,
    rect.botRight, edge,
    ir.botRight, color,
    z = z
  )

  #right
  fillQuad(
    ir.botRight, color,
    rect.botRight, edge,
    rect.topRight, edge,
    ir.topRight, color,
    z = z
  )

  #top
  fillQuad(
    ir.topRight, color,
    rect.topRight, edge,
    rect.topLeft, edge,
    ir.topLeft, color,
    z = z
  )

  #left
  fillQuad(
    ir.topLeft, color,
    rect.topLeft, edge,
    rect.xy, edge,
    ir.xy, color,
    z = z
  )

proc fillLight*(pos: Vec2, radius: float32, sides = 20, centerColor = colorWhite, edgeColor = colorClearWhite, z: float32 = 0, scl = vec2(1f)) =
  let 
    sides = ceil(sides.float32 / 2.0).int * 2
    space = PI * 2.0 / sides.float32

  for i in countup(0, sides - 1, 2):
    fillQuad(
      pos, centerColor,
      pos + vec2(cos(space * i.float32), sin(space * i.float32)) * radius * scl,
      edgeColor,
      pos + vec2(cos(space * (i + 1).float32), sin(space * (i + 1).float32)) * radius * scl,
      edgeColor,
      pos + vec2(cos(space * (i + 2).float32), sin(space * (i + 2).float32)) * radius * scl,
      edgeColor,
      z
    )

proc line*(p1, p2: Vec2, stroke: float32 = 1.px, color = colorWhite, square = true, z: float32 = 0, blend = blendNormal) =
  let hstroke = stroke / 2.0
  let diff = (p2 - p1).nor * hstroke
  let side = vec2(-diff.y, diff.x)
  let 
    s1 = if square: p1 - diff else: p1
    s2 = if square: p2 + diff else: p2

  fillQuad(
    s1 + side,
    s2 + side,
    s2 - side,
    s1 - side,
    color, z,
    blend = blend
  )

proc lineAngle*(p: Vec2, angle, len: float32, stroke: float32 = 1.px, color = colorWhite, square = true, z = 0f, blend = blendNormal) =
  line(p, p + vec2l(angle, len), stroke, color, square, z, blend = blend)

proc lineAngleCenter*(p: Vec2, angle, len: float32, stroke: float32 = 1.px, color = colorWhite, square = true, z = 0f, blend = blendNormal) =
  let v = vec2l(angle, len)
  line(p - v/2f, p + v/2f, stroke, color, square, z, blend = blend)

proc lineRect*(bounds: Rect, stroke: float32 = 1.px, color = colorWhite, z: float32 = 0, margin = 0f) =
  
  let 
    rect = bounds.grow(margin)

    offset = 1.414213f * stroke/2f #sqrt 2

    in1 = rect.botLeft + vec2(offset)
    in2 = rect.botRight + vec2(-offset, offset)
    in3 = rect.topRight + vec2(-offset)
    in4 = rect.topLeft + vec2(offset, -offset)

    out1 = rect.botLeft + vec2(-offset)
    out2 = rect.botRight + vec2(offset, -offset)
    out3 = rect.topRight + vec2(offset)
    out4 = rect.topLeft + vec2(-offset, offset)

  fillQuad(in1, in2, out2, out1, z = z, color = color)
  fillQuad(in2, in3, out3, out2, z = z, color = color)
  fillQuad(in3, in4, out4, out3, z = z, color = color)
  fillQuad(in4, in1, out1, out4, z = z, color = color)

proc lineRect*(pos: Vec2, size: Vec2, stroke: float32 = 1.px, color = colorWhite, z: float32 = 0, margin = 0f) =
  lineRect(rect(pos, size), stroke, color, z, margin)

proc lineSquare*(pos: Vec2, rad: float32, stroke: float32 = 1f.px, color = colorWhite, z = 0f) =
  lineRect(pos - rad, vec2(rad * 2f), stroke, color, z)

proc spikes*(pos: Vec2, sides: int, radius: float32, len: float32, stroke = 1f.px, rotation = 0f, color = colorWhite, z = 0f) =
  for i in 0..<sides:
    let ang = i / sides * 360f.rad + rotation
    lineAngle(pos + vec2l(ang, radius), ang, len, stroke, color, z = z)

proc poly*(pos: Vec2, sides: int, radius: float32, rotation = 0f, stroke = 1f.px, color = colorWhite, z = 0f, scl = vec2(1f), blend = blendNormal) =
  let 
    space = PI*2 / sides.float32
    hstep = stroke / 2.0 / cos(space / 2.0)
    r1 = radius - hstep
    r2 = radius + hstep
  
  for i in 0..<sides:
    let 
      a = space * i.float32 + rotation
      cosf = cos(a)
      sinf = sin(a)
      cos2f = cos(a + space)
      sin2f = sin(a + space)

    fillQuad(
      pos + vec2(cosf, sinf) * r1 * scl,
      pos + vec2(cos2f, sin2f) * r1 * scl,
      pos + vec2(cos2f, sin2f) * r2 * scl,
      pos + vec2(cosf, sinf) * r2 * scl,
      color, z, blend
    )

proc poly*(points: openArray[Vec2], wrap = false, stroke = 1f.px, color = colorWhite, z = 0f, blend = blendNormal) =
  if points.len < 2: return

  if points.len == 2:
    line(points[0], points[1], stroke = stroke, color = color, z = z)
    return

  proc prepareFlatEndpoint(path, endpoint: Vec2, hstroke: float32): (Vec2, Vec2) =
    let v = (endpoint - path).setLen(hstroke)
    return (vec2(-v.y, v.x) + endpoint, vec2(v.y, -v.x) + endpoint)

  proc prepareStraightJoin(b: Vec2, ab: Vec2, hstroke: float32): (Vec2, Vec2) =
    let r = ab.setLen(hstroke)
    return (vec2(-r.y, r.x) + b, vec2(r.y, -r.x) + b)

  proc angleRef(v, reference: Vec2): float32 =
    arctan2(reference.x * v.y - reference.y * v.x, v.x * reference.x + v.y * reference.y).float32

  proc preparePointyJoin(a, b, c: Vec2, hstroke: float32): (Vec2, Vec2) =
    var 
      ab = b - a
      bc = c - b
      angle = ab.angleRef(bc)
    
    if angle.almostEqual(0f) or angle.almostEqual(pi2):
      return prepareStraightJoin(b, ab, hstroke)
      
    let 
      len = hstroke / sin(angle)
      bendsLeft = angle < 0
    
    ab.len = len
    bc.len = len

    let 
      p1 = b - ab + bc
      p2 = b + ab - bc
    
    return if bendsLeft: (p1, p2) else: (p2, p1)

  let hstroke = stroke * 0.5f

  var
    q1: Vec2
    q2: Vec2
    lq1: Vec2
    lq2: Vec2

  for i in 1..<(points.len - 1):
    let 
      a = points[i - 1]
      b = points[i]
      c = points[i + 1]
    
    let (q3, q4) = preparePointyJoin(a, b, c, hstroke)

    if i == 1:
      if wrap:
        (q2, q1) = preparePointyJoin(points[^1], a, b, hstroke)
        (lq1, lq2) = (q2, q1)
      else:
        (q2, q1) = prepareFlatEndpoint(points[1], points[0], hstroke)
    
    fillQuad(q1, q2, q3, q4, color = color, z = z, blend = blend)
    q1 = q4
    q2 = q3

  if wrap:
    let (q3, q4) = preparePointyJoin(points[^2], points[^1], points[0], hstroke)

    fillQuad(q1, q2, q3, q4, color = color, z = z, blend = blend)
    fillQuad(q3, q4, lq2, lq1, color = color, z = z, blend = blend)
  else:
    let (q4, q3) = prepareFlatEndpoint(points[^2], points[^1], hstroke)
    fillQuad(q1, q2, q3, q4, color = color, z = z, blend = blend)

proc arcRadius*(pos: Vec2, sides: int, angleFrom, angleTo: float32, radiusFrom, radiusTo: float32, rotation = 0f, color = colorWhite, z = 0f) =
  let 
    space = (angleTo - angleFrom) / sides.float32
    r1 = radiusFrom
    r2 = radiusTo
  
  for i in 0..<sides:
    let 
      a = space * i.float32 + rotation + angleFrom
      cosf = cos(a)
      sinf = sin(a)
      cos2f = cos(a + space)
      sin2f = sin(a + space)

    fillQuad(
      pos + vec2(cosf, sinf) * r1,
      pos + vec2(cos2f, sin2f) * r1,
      pos + vec2(cos2f, sin2f) * r2,
      pos + vec2(cosf, sinf) * r2,
      color, z
    )

proc arc*(pos: Vec2, sides: int, angleFrom, angleTo: float32, radius: float32, rotation = 0f, stroke = 1f.px, color = colorWhite, z = 0f) =
  let 
    space = (angleTo - angleFrom) / sides.float32
    hstep = stroke / 2.0 / cos(space / 2.0)
    r1 = radius - hstep
    r2 = radius + hstep
  
  arcRadius(pos, sides, angleFrom, angleTo, r1, r2, rotation, color, z)

proc crescent*(pos: Vec2, sides: int, angleFrom, angleTo: float32, radius: float32, rotation = 0f, stroke = 1f.px, color = colorWhite, z = 0f) =
  let 
    space = (angleTo - angleFrom) / sides.float32
  
  for i in 0..<sides:
    let 
      hstep = stroke / 2.0 / cos(space / 2.0) * (i / sides).slope
      r1 = radius - hstep
      r2 = radius + hstep

      a = space * i.float32 + rotation + angleFrom
      cosf = cos(a)
      sinf = sin(a)
      cos2f = cos(a + space)
      sin2f = sin(a + space)

    fillQuad(
      pos + vec2(cosf, sinf) * r1,
      pos + vec2(cos2f, sin2f) * r1,
      pos + vec2(cos2f, sin2f) * r2,
      pos + vec2(cosf, sinf) * r2,
      color, z
    )
class_name Art
extends RefCounted
## Procedural 2D artwork for the toolbar icons, drawn with CanvasItem
## primitives so it stays crisp at any size. (The 3D models live in models.gd.)

const SHADOW := Color(0.1, 0.2, 0.1, 0.18)
const WOOD := Color("a9743f")
const WOOD_D := Color("7d5230")
const CREAM := Color("fbf1d8")
const ASPHALT := Color("5d616b")
const LOT := Color("6f7480")
const TRAIL := Color("e2c48d")
const TRAIL_D := Color("b99560")


static func P(r: Rect2, u: float, v: float) -> Vector2:
	return r.position + Vector2(u * r.size.x, v * r.size.y)

static func box(ci: CanvasItem, r: Rect2, u0: float, v0: float, u1: float, v1: float, col: Color) -> void:
	ci.draw_rect(Rect2(P(r, u0, v0), Vector2((u1 - u0) * r.size.x, (v1 - v0) * r.size.y)), col)

static func poly(ci: CanvasItem, r: Rect2, uv: Array, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(0, uv.size(), 2):
		pts.append(P(r, uv[i], uv[i + 1]))
	ci.draw_colored_polygon(pts, col)

static func circ(ci: CanvasItem, r: Rect2, u: float, v: float, rad: float, col: Color) -> void:
	ci.draw_circle(P(r, u, v), rad * r.size.x, col)

static func line(ci: CanvasItem, r: Rect2, u0: float, v0: float, u1: float, v1: float, col: Color, wd: float) -> void:
	ci.draw_line(P(r, u0, v0), P(r, u1, v1), col, wd * r.size.x)

static func ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 14:
		var a := TAU * i / 14.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_colored_polygon(pts, col)

static func shadow(ci: CanvasItem, r: Rect2, u: float, v: float, ru: float, rv: float) -> void:
	ellipse(ci, P(r, u, v), ru * r.size.x, rv * r.size.y, SHADOW)


## Seasonal foliage colours: [dark, mid, highlight].
static func leaf_colors(season: int, h: float) -> Array:
	match season:
		0: return [Color("4fae58"), Color("72c96a"), Color("a6e38c") if h > 0.3 else Color("f7b6cf")]
		2:
			if h < 0.33: return [Color("c9622b"), Color("e88a3a"), Color("f7b85a")]
			if h < 0.66: return [Color("b8452c"), Color("d9603b"), Color("ee8d5c")]
			return [Color("c79a2a"), Color("e6bd3f"), Color("f6dc74")]
		3: return [Color("8c9a8a"), Color("b4c2b6"), Color("f4f8fb")]
	return [Color("3f9a4b"), Color("58b55e"), Color("84d37a")]


static func structure(ci: CanvasItem, kind, r: Rect2) -> void:
	if icon(ci, kind, r):
		return
	match kind:
		D.B.ROAD:
			box(ci, r, 0.0, 0.25, 1.0, 0.75, ASPHALT)
			for k in 3:
				box(ci, r, 0.1 + k * 0.32, 0.47, 0.26 + k * 0.32, 0.53, Color("f4d35e"))
		D.B.TRAIL:
			ci.draw_polyline(PackedVector2Array([P(r, 0.05, 0.8), P(r, 0.35, 0.55), P(r, 0.6, 0.6), P(r, 0.95, 0.2)]), TRAIL_D, r.size.x * 0.24)
			ci.draw_polyline(PackedVector2Array([P(r, 0.05, 0.8), P(r, 0.35, 0.55), P(r, 0.6, 0.6), P(r, 0.95, 0.2)]), TRAIL, r.size.x * 0.16)
		D.B.PARKING:
			box(ci, r, 0.05, 0.1, 0.95, 0.9, LOT)
			for k in 4:
				box(ci, r, 0.08 + k * 0.28, 0.15, 0.11 + k * 0.28, 0.85, Color.WHITE)
			box(ci, r, 0.16, 0.3, 0.32, 0.75, Color("d9534f"))
			box(ci, r, 0.72, 0.3, 0.88, 0.75, Color("4a90d9"))
		D.B.GATE:
			box(ci, r, 0.03, 0.2, 0.14, 0.95, WOOD_D)
			box(ci, r, 0.86, 0.2, 0.97, 0.95, WOOD_D)
			box(ci, r, 0.0, 0.14, 1.0, 0.3, WOOD)
			poly(ci, r, [0.22, 0.14, 0.5, -0.18, 0.78, 0.14], Color("3f8f5a"))
			poly(ci, r, [0.5, 0.14, 0.5, -0.18, 0.78, 0.14], Color("357a4c"))
			box(ci, r, 0.3, 0.3, 0.7, 0.5, CREAM)
			box(ci, r, 0.36, 0.37, 0.64, 0.43, Color("3f8f5a"))
		D.B.VISITOR_CENTER:
			shadow(ci, r, 0.52, 0.92, 0.48, 0.1)
			box(ci, r, 0.1, 0.4, 0.9, 0.92, CREAM)
			box(ci, r, 0.1, 0.84, 0.9, 0.92, Color("d8c9a3"))
			poly(ci, r, [0.02, 0.44, 0.5, 0.02, 0.98, 0.44], Color("c0563f"))
			poly(ci, r, [0.5, 0.44, 0.5, 0.02, 0.98, 0.44], Color("a94a37"))
			box(ci, r, 0.43, 0.6, 0.57, 0.92, WOOD_D)
			box(ci, r, 0.17, 0.55, 0.36, 0.74, Color("8fd3f4"))
			box(ci, r, 0.64, 0.55, 0.83, 0.74, Color("8fd3f4"))
			circ(ci, r, 0.5, 0.3, 0.07, Color("3b7dd8"))
			box(ci, r, 0.49, 0.27, 0.51, 0.34, Color.WHITE)
			line(ci, r, 0.9, 0.4, 0.9, 0.0, Color("6b6b6b"), 0.015)
			poly(ci, r, [0.9, 0.0, 1.06, 0.06, 0.9, 0.13], Color("3f8f5a"))
		D.B.RESTROOM:
			shadow(ci, r, 0.52, 0.9, 0.38, 0.1)
			box(ci, r, 0.16, 0.38, 0.84, 0.9, Color("e9eef2"))
			poly(ci, r, [0.08, 0.42, 0.5, 0.12, 0.92, 0.42], Color("3a9aa5"))
			box(ci, r, 0.24, 0.55, 0.44, 0.9, Color("4a90d9"))
			box(ci, r, 0.56, 0.55, 0.76, 0.9, Color("e77fb3"))
			circ(ci, r, 0.34, 0.66, 0.035, Color.WHITE)
			circ(ci, r, 0.66, 0.66, 0.035, Color.WHITE)
		D.B.BIN:
			shadow(ci, r, 0.52, 0.86, 0.3, 0.07)
			box(ci, r, 0.24, 0.48, 0.46, 0.86, Color("3f8f5a"))
			box(ci, r, 0.21, 0.42, 0.49, 0.5, Color("2f6e45"))
			box(ci, r, 0.54, 0.48, 0.76, 0.86, Color("3b7dd8"))
			box(ci, r, 0.51, 0.42, 0.79, 0.5, Color("2c5fa8"))
		D.B.OVERLOOK:
			shadow(ci, r, 0.5, 0.92, 0.46, 0.08)
			box(ci, r, 0.08, 0.4, 0.92, 0.9, WOOD)
			for k in 4:
				box(ci, r, 0.08, 0.5 + k * 0.1, 0.92, 0.515 + k * 0.1, WOOD_D)
			box(ci, r, 0.05, 0.3, 0.95, 0.38, Color("d9a566"))
			box(ci, r, 0.05, 0.3, 0.11, 0.9, Color("d9a566"))
			box(ci, r, 0.89, 0.3, 0.95, 0.9, Color("d9a566"))
			box(ci, r, 0.47, 0.42, 0.53, 0.7, Color("6b6b6b"))
			box(ci, r, 0.38, 0.28, 0.62, 0.44, Color("3b7dd8"))
			circ(ci, r, 0.4, 0.36, 0.05, Color("9fd0ff"))
		D.B.PICNIC:
			shadow(ci, r, 0.5, 0.86, 0.42, 0.08)
			box(ci, r, 0.14, 0.26, 0.86, 0.34, WOOD_D)
			box(ci, r, 0.14, 0.7, 0.86, 0.78, WOOD_D)
			box(ci, r, 0.2, 0.4, 0.8, 0.62, WOOD)
			for k in 4:
				box(ci, r, 0.32 + k * 0.09, 0.4, 0.365 + k * 0.09, 0.62, Color("e8554e") if k % 2 == 0 else Color.WHITE)
		D.B.CAMP:
			shadow(ci, r, 0.3, 0.6, 0.26, 0.06)
			poly(ci, r, [0.06, 0.58, 0.3, 0.14, 0.54, 0.58], Color("f08a3c"))
			poly(ci, r, [0.3, 0.58, 0.3, 0.14, 0.54, 0.58], Color("d9742b"))
			poly(ci, r, [0.24, 0.58, 0.3, 0.38, 0.36, 0.58], Color("5a3a22"))
			shadow(ci, r, 0.72, 0.95, 0.24, 0.05)
			poly(ci, r, [0.5, 0.94, 0.72, 0.52, 0.94, 0.94], Color("4a90d9"))
			poly(ci, r, [0.72, 0.94, 0.72, 0.52, 0.94, 0.94], Color("3b78b8"))
			poly(ci, r, [0.66, 0.94, 0.72, 0.76, 0.78, 0.94], Color("2e4057"))
			circ(ci, r, 0.26, 0.82, 0.085, Color("8c8c8c"))
			circ(ci, r, 0.26, 0.82, 0.06, Color("f08a3c"))
			circ(ci, r, 0.26, 0.8, 0.032, Color("f6d44d"))
			box(ci, r, 0.62, 0.3, 0.86, 0.36, WOOD_D)
		D.B.SNACK:
			shadow(ci, r, 0.52, 0.9, 0.4, 0.1)
			box(ci, r, 0.14, 0.36, 0.86, 0.9, Color("fff6e0"))
			box(ci, r, 0.22, 0.52, 0.78, 0.7, Color("5a3a22"))
			box(ci, r, 0.18, 0.7, 0.82, 0.75, WOOD)
			for k in 6:
				poly(ci, r, [0.08 + k * 0.14, 0.2, 0.22 + k * 0.14, 0.2, 0.22 + k * 0.14, 0.44, 0.08 + k * 0.14, 0.44],
					Color("e8554e") if k % 2 == 0 else Color.WHITE)
			circ(ci, r, 0.5, 0.1, 0.1, Color("f6d44d"))
		D.B.RANGER:
			shadow(ci, r, 0.52, 0.92, 0.48, 0.1)
			box(ci, r, 0.1, 0.42, 0.9, 0.92, WOOD)
			for k in 4:
				box(ci, r, 0.1, 0.5 + k * 0.11, 0.9, 0.52 + k * 0.11, WOOD_D)
			poly(ci, r, [0.02, 0.46, 0.5, 0.06, 0.98, 0.46], Color("3f8f5a"))
			poly(ci, r, [0.5, 0.46, 0.5, 0.06, 0.98, 0.46], Color("357a4c"))
			box(ci, r, 0.42, 0.62, 0.58, 0.92, Color("5a3a22"))
			box(ci, r, 0.17, 0.58, 0.34, 0.74, Color("f6e7a0"))
			box(ci, r, 0.66, 0.58, 0.83, 0.74, Color("f6e7a0"))
			circ(ci, r, 0.5, 0.33, 0.065, Color("f6d44d"))
			line(ci, r, 0.12, 0.42, 0.12, -0.05, Color("6b6b6b"), 0.015)
			poly(ci, r, [0.12, -0.05, 0.3, 0.02, 0.12, 0.1], Color("e8554e"))
		D.B.RESEARCH:
			shadow(ci, r, 0.52, 0.92, 0.48, 0.1)
			box(ci, r, 0.08, 0.4, 0.92, 0.92, Color("f2f5f7"))
			box(ci, r, 0.05, 0.32, 0.95, 0.44, Color("3b7dd8"))
			box(ci, r, 0.08, 0.84, 0.92, 0.92, Color("cfd8dd"))
			box(ci, r, 0.14, 0.54, 0.4, 0.72, Color("8fd3f4"))
			box(ci, r, 0.46, 0.58, 0.6, 0.92, Color("5d7d8c"))
			poly(ci, r, [0.64, 0.4, 0.92, 0.4, 0.86, 0.2, 0.7, 0.2], Color("2e4057"))
			line(ci, r, 0.25, 0.32, 0.25, 0.02, Color("6b6b6b"), 0.015)
			circ(ci, r, 0.25, 0.04, 0.04, Color("e8554e"))
			circ(ci, r, 0.5, 0.2, 0.09, Color("dfe6ea"))
			circ(ci, r, 0.52, 0.18, 0.05, Color("aab7bf"))
		D.B.CRAG:
			poly(ci, r, [0.08, 0.95, 0.16, 0.2, 0.42, -0.2, 0.7, 0.0, 0.92, 0.95], Color("9a94a0"))
			poly(ci, r, [0.42, -0.2, 0.7, 0.0, 0.92, 0.95, 0.55, 0.95], Color("837d8a"))
			ci.draw_polyline(PackedVector2Array([P(r, 0.44, -0.12), P(r, 0.4, 0.3), P(r, 0.46, 0.6), P(r, 0.42, 0.9)]), Color("f08a3c"), r.size.x * 0.04)
			for hold in [[0.3, 0.4, "e8554e"], [0.36, 0.1, "f6d44d"], [0.3, 0.7, "4a90d9"], [0.52, 0.45, "58b368"], [0.5, 0.15, "e77fb3"]]:
				circ(ci, r, hold[0], hold[1], 0.04, Color(hold[2]))
			circ(ci, r, 0.42, 0.52, 0.07, Color("e8554e"))
			circ(ci, r, 0.42, 0.42, 0.05, Color("f6d3b3"))
		D.B.SIGN:
			shadow(ci, r, 0.52, 0.9, 0.2, 0.05)
			box(ci, r, 0.46, 0.45, 0.54, 0.9, WOOD_D)
			poly(ci, r, [0.5, 0.08, 0.82, 0.58, 0.18, 0.58], Color("f6d44d"))
			box(ci, r, 0.47, 0.24, 0.53, 0.42, Color("2e2e2e"))
			circ(ci, r, 0.5, 0.5, 0.035, Color("2e2e2e"))
		D.B.HIDE:
			shadow(ci, r, 0.52, 0.9, 0.42, 0.08)
			box(ci, r, 0.12, 0.42, 0.88, 0.9, Color("6f7f4a"))
			box(ci, r, 0.2, 0.55, 0.8, 0.65, Color("23301c"))
			poly(ci, r, [0.04, 0.46, 0.2, 0.22, 0.8, 0.22, 0.96, 0.46], Color("52653a"))
			circ(ci, r, 0.3, 0.3, 0.07, Color("6fa35a"))
			circ(ci, r, 0.62, 0.34, 0.08, Color("7fb565"))
			circ(ci, r, 0.46, 0.26, 0.06, Color("5f9450"))
		D.B.TRAILHEAD:
			shadow(ci, r, 0.52, 0.9, 0.36, 0.06)
			box(ci, r, 0.2, 0.35, 0.27, 0.9, WOOD_D)
			box(ci, r, 0.73, 0.35, 0.8, 0.9, WOOD_D)
			box(ci, r, 0.24, 0.4, 0.76, 0.74, CREAM)
			ci.draw_polyline(PackedVector2Array([P(r, 0.3, 0.66), P(r, 0.42, 0.52), P(r, 0.55, 0.6), P(r, 0.7, 0.46)]), Color("3f8f5a"), r.size.x * 0.035)
			circ(ci, r, 0.7, 0.46, 0.04, Color("e8554e"))
			poly(ci, r, [0.1, 0.4, 0.5, 0.16, 0.9, 0.4], Color("8a5a35"))
		"bulldoze":
			box(ci, r, 0.25, 0.42, 0.75, 0.72, Color("f2b632"))
			box(ci, r, 0.45, 0.22, 0.72, 0.44, Color("f2b632"))
			box(ci, r, 0.5, 0.27, 0.67, 0.4, Color("8fd3f4"))
			box(ci, r, 0.08, 0.4, 0.18, 0.84, Color("7b7f87"))
			box(ci, r, 0.16, 0.56, 0.27, 0.62, Color("7b7f87"))
			box(ci, r, 0.24, 0.7, 0.8, 0.86, Color("3a3d44"))
			circ(ci, r, 0.3, 0.78, 0.06, Color("8a8e96"))
			circ(ci, r, 0.52, 0.78, 0.06, Color("8a8e96"))
			circ(ci, r, 0.74, 0.78, 0.06, Color("8a8e96"))
		"raise", "lower", "level", "smooth":
			var hill := [0.06, 0.86, 0.3, 0.5, 0.5, 0.36, 0.7, 0.5, 0.94, 0.86]
			if kind == "lower": hill = [0.06, 0.5, 0.3, 0.56, 0.5, 0.82, 0.7, 0.56, 0.94, 0.5, 0.94, 0.9, 0.06, 0.9]
			elif kind == "level": hill = [0.06, 0.86, 0.2, 0.58, 0.8, 0.58, 0.94, 0.86]
			elif kind == "smooth": hill = [0.06, 0.86, 0.2, 0.66, 0.4, 0.56, 0.6, 0.56, 0.8, 0.66, 0.94, 0.86]
			poly(ci, r, hill, Color("7d9a4f"))
			box(ci, r, 0.06, 0.84, 0.94, 0.92, Color("7d5230"))
			if kind == "raise":
				poly(ci, r, [0.5, 0.06, 0.64, 0.24, 0.36, 0.24], Color("f6d44d"))
				box(ci, r, 0.46, 0.22, 0.54, 0.34, Color("f6d44d"))
			elif kind == "lower":
				poly(ci, r, [0.5, 0.44, 0.64, 0.26, 0.36, 0.26], Color("f6d44d"))
				box(ci, r, 0.46, 0.12, 0.54, 0.28, Color("f6d44d"))
			elif kind == "level":
				line(ci, r, 0.1, 0.42, 0.9, 0.42, Color("f6d44d"), 0.06)
			else:
				ci.draw_polyline(PackedVector2Array([P(r, 0.12, 0.4), P(r, 0.32, 0.28), P(r, 0.5, 0.36), P(r, 0.68, 0.28), P(r, 0.88, 0.4)]), Color("f6d44d"), r.size.x * 0.05)
		"path":
			poly(ci, r, [0.04, 0.9, 0.3, 0.5, 0.96, 0.5, 0.96, 0.9], Color("7d9a4f"))
			for k in 6:
				circ(ci, r, 0.14 + k * 0.14, 0.82 - k * 0.07 - (0.04 if k % 2 == 0 else 0.0), 0.035, Color("b89a6a"))
		"steps":
			poly(ci, r, [0.04, 0.9, 0.5, 0.2, 0.96, 0.9], Color("7d9a4f"))
			for k in 5:
				box(ci, r, 0.26 + k * 0.07, 0.78 - k * 0.12, 0.6 + k * 0.03, 0.86 - k * 0.12, Color("c9c2b0"))
			line(ci, r, 0.68, 0.86, 0.8, 0.3, Color("5a3a22"), 0.04)
		"switchback":
			poly(ci, r, [0.06, 0.9, 0.5, 0.12, 0.94, 0.9], Color("7d9a4f"))
			ci.draw_polyline(PackedVector2Array([P(r, 0.24, 0.86), P(r, 0.72, 0.74), P(r, 0.34, 0.6), P(r, 0.62, 0.46), P(r, 0.44, 0.34), P(r, 0.5, 0.2)]), Color("e8d3a0"), r.size.x * 0.06)
		"plant":
			ellipse(ci, P(r, 0.5, 0.86), r.size.x * 0.32, r.size.y * 0.08, Color("7d5230"))
			box(ci, r, 0.47, 0.45, 0.53, 0.86, WOOD_D)
			circ(ci, r, 0.5, 0.36, 0.2, Color("3f9a4b"))
			circ(ci, r, 0.46, 0.32, 0.14, Color("58b55e"))
			circ(ci, r, 0.25, 0.7, 0.07, Color("84d37a"))
			circ(ci, r, 0.76, 0.72, 0.06, Color("84d37a"))
		"weed":
			invasive_plant(ci, P(r, 0.5, 0.85), r.size.x / 22.0)
			line(ci, r, 0.15, 0.15, 0.85, 0.85, Color("e8554e"), 0.08)
			line(ci, r, 0.85, 0.15, 0.15, 0.85, Color("e8554e"), 0.08)


static func invasive_plant(ci: CanvasItem, base: Vector2, s: float) -> void:
	ci.draw_line(base, base + Vector2(0, -9.0 * s), Color("4d6b2f"), 1.6 * s)
	ci.draw_line(base + Vector2(0, -4.0 * s), base + Vector2(-4.0 * s, -6.5 * s), Color("4d6b2f"), 1.4 * s)
	ci.draw_line(base + Vector2(0, -3.0 * s), base + Vector2(4.0 * s, -5.5 * s), Color("4d6b2f"), 1.4 * s)
	ci.draw_circle(base + Vector2(0, -10.0 * s), 3.2 * s, Color("8e3fa8"))
	ci.draw_circle(base + Vector2(-0.8 * s, -10.8 * s), 1.5 * s, Color("c77fe0"))


# ------------------------------------------------------- detailed drawn icons

## A quad shaded from one colour at the top to another at the bottom.
static func grad(ci: CanvasItem, r: Rect2, uv: Array, top: Color, bottom: Color) -> void:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var v0 := 1e9
	var v1 := -1e9
	for i in range(0, uv.size(), 2):
		v0 = minf(v0, uv[i + 1])
		v1 = maxf(v1, uv[i + 1])
	for i in range(0, uv.size(), 2):
		pts.append(P(r, uv[i], uv[i + 1]))
		cols.append(top.lerp(bottom, (uv[i + 1] - v0) / maxf(v1 - v0, 0.001)))
	ci.draw_polygon(pts, cols)


static func outline(ci: CanvasItem, r: Rect2, uv: Array, col: Color, wd: float) -> void:
	var pts := PackedVector2Array()
	for i in range(0, uv.size(), 2):
		pts.append(P(r, uv[i], uv[i + 1]))
	pts.append(pts[0])
	ci.draw_polyline(pts, col, r.size.x * wd, true)


static func curve(ci: CanvasItem, r: Rect2, uv: Array, col: Color, wd: float) -> void:
	var pts := PackedVector2Array()
	for i in range(0, uv.size(), 2):
		pts.append(P(r, uv[i], uv[i + 1]))
	ci.draw_polyline(pts, col, r.size.x * wd, true)


static func tuft(ci: CanvasItem, r: Rect2, u: float, v: float, s: float, col: Color) -> void:
	for k in 3:
		line(ci, r, u, v, u + (k - 1) * 0.035 * s, v - 0.09 * s, col, 0.022)


static func arrow(ci: CanvasItem, r: Rect2, u: float, v: float, up: bool) -> void:
	var d := -1.0 if up else 1.0
	var head := [u, v + d * 0.17, u - 0.13, v, u + 0.13, v]
	var shaft := [u - 0.05, v, u + 0.05, v, u + 0.05, v - d * 0.15, u - 0.05, v - d * 0.15]
	poly(ci, r, [u, v + d * 0.2, u - 0.16, v - 0.01 * d, u + 0.16, v - 0.01 * d], Color("5a3d08"))
	poly(ci, r, [u - 0.075, v, u + 0.075, v, u + 0.075, v - d * 0.175, u - 0.075, v - d * 0.175], Color("5a3d08"))
	poly(ci, r, head, Color("ffd84a"))
	poly(ci, r, shaft, Color("ffd84a"))


## Build-menu pictures for things that have no 3D model. Returns false for
## anything it does not draw.
static func icon(ci: CanvasItem, kind, r: Rect2) -> bool:
	var S := r.size.x
	if kind is int:
		match kind:
			D.B.ROAD:
				grad(ci, r, [0.36, 0.34, 0.64, 0.34, 0.98, 1.0, 0.02, 1.0], Color("4a4e58"), Color("6a6f7a"))
				line(ci, r, 0.36, 0.34, 0.02, 1.0, Color("e9e4d2"), 0.03)
				line(ci, r, 0.64, 0.34, 0.98, 1.0, Color("e9e4d2"), 0.03)
				for k in 4:
					var v0 := 0.4 + k * 0.16
					var w := 0.012 + k * 0.008
					poly(ci, r, [0.5 - w, v0, 0.5 + w, v0, 0.5 + w * 1.4, v0 + 0.09, 0.5 - w * 1.4, v0 + 0.09], Color("f4d35e"))
				tuft(ci, r, 0.12, 0.7, 1.0, Color("3f7a3a"))
				tuft(ci, r, 0.88, 0.62, 0.8, Color("3f7a3a"))
				return true
			D.B.TRAIL:
				var edge := [0.3, 1.0, 0.62, 1.0, 0.7, 0.8, 0.46, 0.62, 0.66, 0.44, 0.6, 0.3, 0.52, 0.3, 0.5, 0.42, 0.28, 0.6, 0.42, 0.82]
				poly(ci, r, edge, Color("8a6a3f"))
				grad(ci, r, [0.34, 1.0, 0.58, 1.0, 0.66, 0.81, 0.42, 0.62, 0.62, 0.44, 0.58, 0.32, 0.54, 0.32, 0.53, 0.43, 0.32, 0.61, 0.46, 0.82], Color("c9a871"), Color("e6cc98"))
				for p in [[0.48, 0.9], [0.5, 0.72], [0.44, 0.58], [0.56, 0.4]]:
					circ(ci, r, p[0], p[1], 0.018, Color("8a6a3f"))
				box(ci, r, 0.76, 0.5, 0.8, 0.86, WOOD_D)
				poly(ci, r, [0.66, 0.5, 0.92, 0.5, 0.97, 0.56, 0.92, 0.62, 0.66, 0.62], WOOD)
				line(ci, r, 0.7, 0.56, 0.9, 0.56, Color("fbf1d8"), 0.02)
				tuft(ci, r, 0.2, 0.86, 1.0, Color("3f7a3a"))
				tuft(ci, r, 0.82, 0.96, 0.9, Color("3f7a3a"))
				return true
			D.B.PARKING:
				grad(ci, r, [0.2, 0.36, 0.8, 0.36, 0.98, 0.98, 0.02, 0.98], Color("585c66"), Color("747985"))
				for k in 4:
					var t := k / 3.0
					line(ci, r, lerpf(0.26, 0.74, t), 0.4, lerpf(0.1, 0.9, t), 0.94, Color("eeeeee"), 0.02)
				# two parked cars, seen from behind
				for car in [[0.36, Color("c94a40")], [0.63, Color("3f79c4")]]:
					var cx: float = car[0]
					var cc: Color = car[1]
					poly(ci, r, [cx - 0.1, 0.84, cx + 0.1, 0.84, cx + 0.09, 0.62, cx - 0.09, 0.62], cc)
					poly(ci, r, [cx - 0.075, 0.62, cx + 0.075, 0.62, cx + 0.055, 0.5, cx - 0.055, 0.5], cc.darkened(0.2))
					poly(ci, r, [cx - 0.058, 0.6, cx + 0.058, 0.6, cx + 0.044, 0.52, cx - 0.044, 0.52], Color("bfe3f5"))
					box(ci, r, cx - 0.09, 0.7, cx - 0.05, 0.74, Color("ffd9a0"))
					box(ci, r, cx + 0.05, 0.7, cx + 0.09, 0.74, Color("ffd9a0"))
					box(ci, r, cx - 0.1, 0.84, cx - 0.05, 0.9, Color("22252b"))
					box(ci, r, cx + 0.05, 0.84, cx + 0.1, 0.9, Color("22252b"))
				box(ci, r, 0.86, 0.2, 0.89, 0.5, Color("7b7f87"))
				box(ci, r, 0.78, 0.06, 0.97, 0.25, Color("2f6fd0"))
				line(ci, r, 0.84, 0.21, 0.84, 0.1, Color.WHITE, 0.03)
				curve(ci, r, [0.84, 0.1, 0.91, 0.1, 0.92, 0.15, 0.84, 0.16], Color.WHITE, 0.03)
				return true
		return false
	match kind:
		"path":
			# a faint track that the grass is already taking back
			for seg in [[0.36, 0.98, 0.44, 0.84], [0.47, 0.78, 0.4, 0.66], [0.38, 0.6, 0.5, 0.5], [0.54, 0.46, 0.6, 0.36]]:
				line(ci, r, seg[0], seg[1], seg[2], seg[3], Color("a58a5c"), 0.05)
			for p in [[0.2, 0.9], [0.56, 0.9], [0.3, 0.72], [0.6, 0.66], [0.26, 0.5], [0.68, 0.5], [0.46, 0.92], [0.44, 0.58]]:
				tuft(ci, r, p[0], p[1], 1.0, Color("2f6a33"))
			for p in [[0.4, 0.9], [0.46, 0.72], [0.44, 0.56]]:
				ellipse(ci, P(r, p[0], p[1]), S * 0.022, S * 0.034, Color("6f5836"))
			box(ci, r, 0.74, 0.62, 0.77, 0.9, WOOD_D)
			box(ci, r, 0.68, 0.56, 0.83, 0.66, Color("c9b27c"))
			line(ci, r, 0.71, 0.61, 0.8, 0.61, Color("7d5230"), 0.015)
		"steps":
			grad(ci, r, [0.0, 1.0, 0.0, 0.8, 1.0, 0.26, 1.0, 1.0], Color("5d8a46"), Color("47703a"))
			for k in 5:
				var u := 0.12 + k * 0.15
				var v := 0.84 - k * 0.12
				box(ci, r, u, v, u + 0.3, v + 0.045, Color("d8d2c2"))
				box(ci, r, u, v + 0.045, u + 0.3, v + 0.12, Color("8f897b"))
				line(ci, r, u + 0.1, v + 0.05, u + 0.1, v + 0.12, Color("6c675c"), 0.012)
				line(ci, r, u + 0.21, v + 0.05, u + 0.21, v + 0.12, Color("6c675c"), 0.012)
			for k in 3:
				var pu := 0.5 + k * 0.2
				var pv := 0.72 - k * 0.16
				box(ci, r, pu, pv - 0.2, pu + 0.03, pv + 0.02, WOOD_D)
			line(ci, r, 0.5, 0.53, 0.93, 0.2, WOOD, 0.035)
		"switchback":
			grad(ci, r, [0.5, 0.1, 0.98, 0.98, 0.02, 0.98], Color("8fae6a"), Color("4f7a3d"))
			poly(ci, r, [0.5, 0.1, 0.62, 0.32, 0.5, 0.28, 0.4, 0.33], Color("f1f4f6"))
			poly(ci, r, [0.5, 0.1, 0.98, 0.98, 0.6, 0.98, 0.56, 0.5], Color(0, 0, 0, 0.14))
			var zig := [0.2, 0.92, 0.76, 0.82, 0.3, 0.7, 0.68, 0.6, 0.38, 0.5, 0.58, 0.42, 0.48, 0.34]
			curve(ci, r, zig, Color("6f5836"), 0.075)
			curve(ci, r, zig, Color("e6cc98"), 0.045)
			circ(ci, r, 0.3, 0.7, 0.03, Color("d9534f"))
		"bulldoze":
			ellipse(ci, P(r, 0.5, 0.92), S * 0.42, S * 0.05, Color(0, 0, 0, 0.25))
			grad(ci, r, [0.3, 0.46, 0.84, 0.46, 0.84, 0.72, 0.3, 0.72], Color("ffcf4a"), Color("d99a1c"))
			grad(ci, r, [0.5, 0.2, 0.78, 0.2, 0.78, 0.48, 0.5, 0.48], Color("ffd65e"), Color("e0a528"))
			poly(ci, r, [0.54, 0.25, 0.74, 0.25, 0.74, 0.42, 0.54, 0.42], Color("9fd7f2"))
			poly(ci, r, [0.54, 0.25, 0.64, 0.25, 0.56, 0.42, 0.54, 0.42], Color("d8f0fb"))
			box(ci, r, 0.36, 0.3, 0.4, 0.46, Color("4a4d55"))
			circ(ci, r, 0.38, 0.24, 0.035, Color(0.5, 0.5, 0.5, 0.6))
			circ(ci, r, 0.33, 0.17, 0.045, Color(0.6, 0.6, 0.6, 0.4))
			poly(ci, r, [0.3, 0.6, 0.14, 0.52, 0.14, 0.58, 0.3, 0.68], Color("6a6e77"))
			grad(ci, r, [0.06, 0.4, 0.16, 0.42, 0.18, 0.86, 0.04, 0.88], Color("b9bec7"), Color("70747d"))
			line(ci, r, 0.04, 0.88, 0.18, 0.86, Color("3f424a"), 0.025)
			poly(ci, r, [0.3, 0.7, 0.86, 0.7, 0.92, 0.79, 0.86, 0.88, 0.3, 0.88, 0.24, 0.79], Color("2b2d33"))
			for k in 4:
				circ(ci, r, 0.34 + k * 0.16, 0.79, 0.055, Color("7a7e87"))
				circ(ci, r, 0.34 + k * 0.16, 0.79, 0.022, Color("2b2d33"))
		"plant":
			ellipse(ci, P(r, 0.44, 0.88), S * 0.3, S * 0.085, Color("5f3f24"))
			ellipse(ci, P(r, 0.44, 0.86), S * 0.24, S * 0.055, Color("7d5632"))
			line(ci, r, 0.44, 0.86, 0.44, 0.4, Color("6b4526"), 0.045)
			line(ci, r, 0.44, 0.62, 0.3, 0.5, Color("6b4526"), 0.03)
			line(ci, r, 0.44, 0.56, 0.58, 0.44, Color("6b4526"), 0.03)
			for p in [[0.44, 0.32, 0.17], [0.28, 0.44, 0.12], [0.6, 0.4, 0.13], [0.36, 0.26, 0.11], [0.53, 0.25, 0.11]]:
				circ(ci, r, p[0], p[1], p[2], Color("2f7d3c"))
			for p in [[0.41, 0.28, 0.1], [0.26, 0.41, 0.07], [0.57, 0.36, 0.08], [0.5, 0.22, 0.06]]:
				circ(ci, r, p[0], p[1], p[2], Color("58b55e"))
			circ(ci, r, 0.38, 0.24, 0.035, Color("a7e39a"))
			line(ci, r, 0.8, 0.3, 0.8, 0.74, WOOD, 0.04)
			box(ci, r, 0.75, 0.26, 0.85, 0.31, WOOD_D)
			poly(ci, r, [0.72, 0.72, 0.88, 0.72, 0.87, 0.9, 0.8, 0.95, 0.73, 0.9], Color("9aa0aa"))
			poly(ci, r, [0.72, 0.72, 0.8, 0.72, 0.8, 0.95, 0.73, 0.9], Color("c3c8d0"))
		"weed":
			line(ci, r, 0.5, 0.92, 0.5, 0.36, Color("4d6b2f"), 0.045)
			for a in [[0.5, 0.74, 0.3, 0.6], [0.5, 0.66, 0.7, 0.54], [0.5, 0.56, 0.34, 0.44]]:
				line(ci, r, a[0], a[1], a[2], a[3], Color("4d6b2f"), 0.035)
				poly(ci, r, [a[2], a[3], a[2] - 0.06, a[3] + 0.07, a[2] + 0.05, a[3] + 0.08], Color("6a8a3c"))
			for k in 9:
				var an := PI + k * PI / 8.0
				line(ci, r, 0.5, 0.32, 0.5 + cos(an) * 0.2, 0.32 + sin(an) * 0.2, Color("b060cf"), 0.03)
			circ(ci, r, 0.5, 0.34, 0.09, Color("7a2f96"))
			circ(ci, r, 0.47, 0.31, 0.04, Color("c77fe0"))
			ci.draw_arc(P(r, 0.5, 0.52), S * 0.42, 0, TAU, 32, Color("e8443a"), S * 0.07, true)
			line(ci, r, 0.2, 0.22, 0.8, 0.82, Color("e8443a"), 0.07)
		"raise", "lower", "level", "smooth":
			var top := [0.02, 0.9, 0.24, 0.6, 0.5, 0.4, 0.76, 0.6, 0.98, 0.9]
			if kind == "lower": top = [0.02, 0.56, 0.26, 0.6, 0.5, 0.84, 0.74, 0.6, 0.98, 0.56]
			elif kind == "level": top = [0.02, 0.62, 0.98, 0.62]
			elif kind == "smooth": top = [0.02, 0.8, 0.2, 0.66, 0.4, 0.6, 0.6, 0.6, 0.8, 0.66, 0.98, 0.8]
			var body: Array = top.duplicate()
			body.append_array([0.98, 1.0, 0.02, 1.0])
			grad(ci, r, body, Color("8a6238"), Color("4f3620"))
			# strata in the cut face
			for k in 2:
				line(ci, r, 0.06, 0.93 - k * 0.05, 0.94, 0.93 - k * 0.05, Color(0, 0, 0, 0.18), 0.012)
			# turf along the top
			curve(ci, r, top, Color("3f7a3a"), 0.09)
			curve(ci, r, top, Color("6fae52"), 0.045)
			if kind == "raise":
				arrow(ci, r, 0.5, 0.22, true)
			elif kind == "lower":
				arrow(ci, r, 0.5, 0.42, false)
			elif kind == "level":
				line(ci, r, 0.06, 0.4, 0.94, 0.4, Color("5a3d08"), 0.07)
				line(ci, r, 0.06, 0.4, 0.94, 0.4, Color("ffd84a"), 0.045)
				for k in 5:
					line(ci, r, 0.14 + k * 0.18, 0.36, 0.14 + k * 0.18, 0.44, Color("5a3d08"), 0.015)
				ellipse(ci, P(r, 0.5, 0.4), S * 0.07, S * 0.035, Color("b8f27a"))
			else:
				curve(ci, r, [0.1, 0.4, 0.26, 0.28, 0.42, 0.4, 0.58, 0.28, 0.74, 0.4, 0.9, 0.28], Color("5a3d08"), 0.07)
				curve(ci, r, [0.1, 0.4, 0.26, 0.28, 0.42, 0.4, 0.58, 0.28, 0.74, 0.4, 0.9, 0.28], Color("ffd84a"), 0.04)
		_:
			return false
	return true


## The small status and menu symbols. Returns false for anything it does not draw.
static func glyph(ci: CanvasItem, kind: String, r: Rect2) -> bool:
	var S := r.size.x
	match kind:
		"coin":
			ellipse(ci, P(r, 0.5, 0.56), S * 0.45, S * 0.45, Color("8a5f0c"))
			circ(ci, r, 0.5, 0.5, 0.45, Color("d99a1c"))
			circ(ci, r, 0.5, 0.5, 0.36, Color("ffd24a"))
			ci.draw_arc(P(r, 0.5, 0.5), S * 0.36, 0, TAU, 28, Color("b47a10"), S * 0.035, true)
			ci.draw_arc(P(r, 0.5, 0.5), S * 0.27, PI * 1.05, PI * 1.6, 12, Color("fff3b8"), S * 0.05, true)
			curve(ci, r, [0.6, 0.36, 0.48, 0.32, 0.4, 0.4, 0.5, 0.5, 0.6, 0.58, 0.52, 0.68, 0.4, 0.64], Color("8a5f0c"), 0.07)
			line(ci, r, 0.5, 0.24, 0.5, 0.76, Color("8a5f0c"), 0.05)
		"star":
			var outer := []
			var inner := []
			for i in 10:
				var a := -PI / 2.0 + i * PI / 5.0
				var rad := 0.5 if i % 2 == 0 else 0.21
				outer.append_array([0.5 + cos(a) * rad, 0.53 + sin(a) * rad])
				inner.append_array([0.5 + cos(a) * rad * 0.82, 0.53 + sin(a) * rad * 0.82])
			poly(ci, r, outer, Color("a66a08"))
			grad(ci, r, inner, Color("ffe37a"), Color("f0a81e"))
			poly(ci, r, [0.5, 0.13, 0.56, 0.4, 0.5, 0.53, 0.44, 0.4], Color(1, 1, 1, 0.4))
		"leaf":
			var shape := [0.5, 0.04, 0.78, 0.26, 0.86, 0.56, 0.7, 0.84, 0.5, 0.96, 0.3, 0.84, 0.14, 0.56, 0.22, 0.26]
			poly(ci, r, shape, Color("1f5a30"))
			grad(ci, r, [0.5, 0.1, 0.74, 0.28, 0.8, 0.56, 0.66, 0.8, 0.5, 0.9, 0.34, 0.8, 0.2, 0.56, 0.26, 0.28], Color("7fd46a"), Color("2f8f44"))
			poly(ci, r, [0.5, 0.1, 0.74, 0.28, 0.8, 0.56, 0.66, 0.8, 0.5, 0.9], Color(0, 0, 0, 0.12))
			line(ci, r, 0.5, 0.14, 0.5, 1.0, Color("1f5a30"), 0.05)
			for k in 3:
				var v := 0.36 + k * 0.17
				line(ci, r, 0.5, v + 0.08, 0.3 - k * 0.0, v - 0.04, Color("1f5a30"), 0.028)
				line(ci, r, 0.5, v + 0.08, 0.7, v - 0.04, Color("1f5a30"), 0.028)
		"shield":
			var sh := [0.5, 0.03, 0.9, 0.16, 0.88, 0.56, 0.5, 0.98, 0.12, 0.56, 0.1, 0.16]
			poly(ci, r, sh, Color("7d1f1c"))
			grad(ci, r, [0.5, 0.1, 0.83, 0.21, 0.81, 0.54, 0.5, 0.9, 0.19, 0.54, 0.17, 0.21], Color("f0625c"), Color("b8302b"))
			poly(ci, r, [0.5, 0.1, 0.83, 0.21, 0.81, 0.54, 0.5, 0.9], Color(0, 0, 0, 0.14))
			box(ci, r, 0.43, 0.26, 0.57, 0.72, Color.WHITE)
			box(ci, r, 0.28, 0.41, 0.72, 0.56, Color.WHITE)
		"flask":
			var glass := [0.4, 0.06, 0.6, 0.06, 0.6, 0.38, 0.9, 0.86, 0.84, 0.96, 0.16, 0.96, 0.1, 0.86, 0.4, 0.38]
			poly(ci, r, glass, Color("d9eef8"))
			grad(ci, r, [0.3, 0.6, 0.7, 0.6, 0.86, 0.86, 0.82, 0.92, 0.18, 0.92, 0.14, 0.86], Color("a58bf0"), Color("5a3fb0"))
			line(ci, r, 0.3, 0.6, 0.7, 0.6, Color("d6c9ff"), 0.03)
			circ(ci, r, 0.44, 0.76, 0.045, Color("d6c9ff"))
			circ(ci, r, 0.6, 0.82, 0.03, Color("d6c9ff"))
			circ(ci, r, 0.54, 0.5, 0.025, Color("a58bf0"))
			outline(ci, r, glass, Color("5b7f96"), 0.04)
			box(ci, r, 0.36, 0.03, 0.64, 0.1, Color("5b7f96"))
			line(ci, r, 0.44, 0.14, 0.44, 0.36, Color(1, 1, 1, 0.8), 0.03)
		"sun":
			for i in 12:
				var a := i * TAU / 12.0
				var rr := 0.5 if i % 2 == 0 else 0.42
				line(ci, r, 0.5 + cos(a) * 0.34, 0.5 + sin(a) * 0.34, 0.5 + cos(a) * rr, 0.5 + sin(a) * rr, Color("f0a81e"), 0.06)
			circ(ci, r, 0.5, 0.5, 0.31, Color("e89a12"))
			circ(ci, r, 0.5, 0.5, 0.27, Color("ffd24a"))
			circ(ci, r, 0.44, 0.44, 0.13, Color("fff0a8"))
		"check":
			circ(ci, r, 0.5, 0.53, 0.47, Color("1f5a30"))
			circ(ci, r, 0.5, 0.5, 0.46, Color("2f8f44"))
			circ(ci, r, 0.5, 0.48, 0.38, Color("4fb866"))
			curve(ci, r, [0.27, 0.52, 0.44, 0.69, 0.75, 0.33], Color("1f5a30"), 0.16)
			curve(ci, r, [0.27, 0.5, 0.44, 0.67, 0.75, 0.31], Color.WHITE, 0.11)
		"todo":
			ci.draw_arc(P(r, 0.5, 0.5), S * 0.4, 0, TAU, 24, Color("5d6f7a"), S * 0.12, true)
			ci.draw_arc(P(r, 0.5, 0.5), S * 0.4, 0, TAU, 24, Color("cfd8dd"), S * 0.07, true)
		"people":
			circ(ci, r, 0.5, 0.3, 0.2, Color("b98862"))
			circ(ci, r, 0.5, 0.28, 0.18, Color("e9b98f"))
			grad(ci, r, [0.3, 0.52, 0.7, 0.52, 0.8, 0.98, 0.2, 0.98], Color("5aa0e6"), Color("2f6fb8"))
		_:
			return false
	return true

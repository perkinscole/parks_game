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

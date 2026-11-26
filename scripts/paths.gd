class_name Paths
extends RefCounted
## Smooth movement along a tile path. Corners are rounded with a quadratic
## curve through the tile-edge midpoints, which is exactly how trails and
## roads are drawn, so walkers and cars stay on them.

const T := float(D.TILE)


static func pos(pts: PackedVector2Array, d: float) -> Vector2:
	var n := pts.size()
	if n == 0:
		return Vector2.ZERO
	if n == 1:
		return pts[0]
	var u := clampf(d / T, 0.0, n - 1.0)
	if u <= 0.5:
		return pts[0].lerp(pts[1], u)
	if u >= n - 1.5:
		return pts[n - 2].lerp(pts[n - 1], u - (n - 2))
	var k := int(u + 0.5)
	var t := u + 0.5 - k
	var a := (pts[k - 1] + pts[k]) * 0.5
	var c := (pts[k] + pts[k + 1]) * 0.5
	return a.lerp(pts[k], t).lerp(pts[k].lerp(c, t), t)


static func dir(pts: PackedVector2Array, d: float) -> Vector2:
	var n := pts.size()
	if n < 2:
		return Vector2(0, 1)
	var u := clampf(d / T, 0.0, n - 1.0)
	var v := Vector2.ZERO
	if u <= 0.5:
		v = pts[1] - pts[0]
	elif u >= n - 1.5:
		v = pts[n - 1] - pts[n - 2]
	else:
		var k := int(u + 0.5)
		var t := u + 0.5 - k
		v = (pts[k] - pts[k - 1]).lerp(pts[k + 1] - pts[k], t)
	if v.length_squared() < 0.0001:
		return Vector2(0, 1)
	return v.normalized()

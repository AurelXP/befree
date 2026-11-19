class_name Bld
extends RefCounted
## Petits utilitaires pour construire des modèles 3D à partir de primitives.


static func mat(tex: Texture2D = null, color: Color = Color.WHITE, rough: float = 0.9, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	if tex != null:
		m.albedo_texture = tex
		m.texture_repeat = true
	m.roughness = rough
	m.metallic = metal
	return m


## Matériau à texture "triplanar" : la densité de texture reste constante quelle que soit la taille.
static func tiled(tex: Texture2D, tile: float = 1.0, color: Color = Color.WHITE, rough: float = 0.9, metal: float = 0.0) -> StandardMaterial3D:
	var m: StandardMaterial3D = mat(tex, color, rough, metal)
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE / tile
	return m


static func emissive(color: Color, energy: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


static func _place(parent: Node, mi: MeshInstance3D, pos: Vector3, m: Material, rot: Vector3, nm: String) -> MeshInstance3D:
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot
	if nm != "":
		mi.name = nm
	parent.add_child(mi)
	return mi


static func box(parent: Node, size: Vector3, pos: Vector3, m: Material, rot: Vector3 = Vector3.ZERO, nm: String = "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	return _place(parent, mi, pos, m, rot, nm)


static func cyl(parent: Node, radius: float, height: float, pos: Vector3, m: Material, rot: Vector3 = Vector3.ZERO, top_radius: float = -1.0, nm: String = "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = radius
	cm.top_radius = radius if top_radius < 0.0 else top_radius
	cm.height = height
	cm.radial_segments = 16
	cm.rings = 1
	mi.mesh = cm
	return _place(parent, mi, pos, m, rot, nm)


static func sph(parent: Node, radius: float, pos: Vector3, m: Material, scl: Vector3 = Vector3.ONE, nm: String = "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 24
	sm.rings = 12
	mi.mesh = sm
	mi.scale = scl
	return _place(parent, mi, pos, m, Vector3.ZERO, nm)


static func caps(parent: Node, radius: float, height: float, pos: Vector3, m: Material, rot: Vector3 = Vector3.ZERO, nm: String = "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = radius
	cm.height = height
	cm.radial_segments = 12
	cm.rings = 4
	mi.mesh = cm
	return _place(parent, mi, pos, m, rot, nm)


static func quad(parent: Node, size: Vector2, pos: Vector3, m: Material, rot: Vector3 = Vector3.ZERO, nm: String = "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = size
	mi.mesh = qm
	return _place(parent, mi, pos, m, rot, nm)


## Zone cliquable (couche 2) identifiée par un id.
static func hit(parent: Node, id: String, size: Vector3, pos: Vector3) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.collision_layer = 2
	sb.collision_mask = 0
	sb.position = pos
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	sb.set_meta("id", id)
	sb.name = "hit_" + id
	parent.add_child(sb)
	return sb

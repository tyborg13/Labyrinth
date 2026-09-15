extends RefCounted

# A few irregular, embedded stones share the floor's warm mineral palette.
# Three-dimensional fracture planes give every chipped silhouette consistent
# upper-left light; texture is fixed to the stone, never animated or scrolling.
const Fx = preload("res://scripts/elemental_spell_fx.gd")
const LIGHT := Vector3(-0.48,0.80,0.35)
const VIEW := Vector3(1.0,1.4,1.0)
static var _texture: Texture2D
static var _stones: Dictionary = {}

static func draw(c: CanvasItem, center: Vector2, width: float, seed: int, rise: float, opacity: float) -> void:
	_prepare_texture()
	c.draw_set_transform(center)
	var stones: Array[Dictionary]
	# Unequal heights and leaning crowns avoid a row of matching stone posts.
	stones.append({"p":Vector2(-.18,-.04),"w":.19,"h":.34,"seed":seed+19})
	stones.append({"p":Vector2(.16,-.045),"w":.17,"h":.51,"seed":seed+31})
	stones.append({"p":Vector2(-.015,.045),"w":.25,"h":.60,"seed":seed+7})
	for stone: Dictionary in stones:
		_draw_stone(c,stone["p"]*width,float(stone["w"])*width,float(stone["h"])*width,stone["seed"],rise,opacity)
	# Embedded chips and dark contact pockets break up the clean floor seam.
	for i: int in range(8):
		var a: float = float(i)*2.39996
		var r: float = .26+Fx._hash(seed+i*19)*.11
		var at := Vector2(cos(a)*r,sin(a)*r*.40+.04)*width
		_draw_stone(c,at,width*(.025+Fx._hash(seed+i*37)*.025),width*.035,seed+i*67,1.0,opacity)
	c.draw_set_transform(Vector2.ZERO)

static func _geometry(seed: int) -> Array:
	if _stones.has(seed): return _stones[seed]
	var rings: Array = []
	for level: int in range(3):
		var ring := PackedVector3Array()
		for i: int in range(7):
			var a: float = float(i)*TAU/7.0 + (Fx._hash(seed+i*13)-.5)*.24
			var radius: float = (.89+Fx._hash(seed+i*31+level*47)*.24)*([.93,1.0,.69][level] as float)
			var y: float = 0.0 if level==0 else (.43 if level==1 else .91)+(Fx._hash(seed+i*51+level*17)-.5)*.20
			ring.append(Vector3(cos(a)*radius+float(level)*.035,y,sin(a)*radius))
		rings.append(ring)
	var faces: Array = []
	for level: int in range(2):
		for i: int in range(7):
			var j: int = (i+1)%7
			var quad := PackedVector3Array([rings[level][i],rings[level][j],rings[level+1][j],rings[level+1][i]])
			# An off-center seam fractures each face into unequal slabs.
			var hub: Vector3 = (quad[0]+quad[1]+quad[2]+quad[3])*.25
			hub.y += (Fx._hash(seed+i*71+level)-.5)*.11
			hub *= 1.0+(Fx._hash(seed+i*11)-.5)*.12
			for side: int in range(4): faces.append(PackedVector3Array([quad[side],quad[(side+1)%4],hub]))
	var cap: Vector3 = Vector3(.08,1.02,-.03)
	for i: int in range(7): faces.append(PackedVector3Array([rings[2][i],rings[2][(i+1)%7],cap]))
	faces.sort_custom(func(a: PackedVector3Array,b: PackedVector3Array) -> bool:
		var pa: Vector3 = (a[0]+a[1]+a[2])/3.0
		var pb: Vector3 = (b[0]+b[1]+b[2])/3.0
		return pa.dot(VIEW)<pb.dot(VIEW))
	if _stones.size()>256: _stones.clear()
	_stones[seed]=faces
	return faces

static func _project(point: Vector3, wide: float, tall: float, rise: float) -> Vector2:
	return Vector2((point.x-point.z)*wide*.72,(point.x+point.z)*wide*.34-point.y*tall*rise)

static func _draw_stone(c: CanvasItem, at: Vector2, wide: float, tall: float, seed: int, rise: float, opacity: float) -> void:
	var base: Color = Color("88877c").lerp(Color("a2967f"),Fx._hash(seed+193)*.60)
	var face_index: int = 0
	for face: PackedVector3Array in _geometry(seed):
		face_index+=1
		var normal: Vector3 = (face[1]-face[0]).cross(face[2]-face[0]).normalized()
		var midpoint: Vector3 = (face[0]+face[1]+face[2])/3.0
		var outward: Vector3 = Vector3(midpoint.x,midpoint.y-.50,midpoint.z)
		if normal.dot(outward)<0: normal=-normal
		if normal.dot(VIEW)<0.0: continue
		var light: float = .36+maxf(0.0,normal.dot(LIGHT))*.69
		var points := PackedVector2Array()
		var colors := PackedColorArray()
		var uv := PackedVector2Array()
		for vertex: Vector3 in face:
			points.append(at+_project(vertex,wide,tall,rise))
			var contact: float = lerpf(.59,1.0,smoothstep(0.0,.35,vertex.y))
			var tint: Color = base*(light*contact)
			tint.a=opacity
			colors.append(tint)
			uv.append(Vector2(vertex.x*.26+vertex.z*.19,vertex.y*.63+vertex.z*.13)+Vector2(.31,.14))
		c.draw_polygon(points,colors,uv,_texture)
		if wide<10.0: continue
		# Small rough fissures have a recessed dark seam and a worn lower lip.
		if face_index%5==0:
			var p: Vector2 = points[0].lerp(points[1],.27)
			var q: Vector2 = points[0].lerp(points[2],.73)
			var kink: Vector2 = p.lerp(q,.54)+Vector2(wide*.035,wide*.018)
			var crack := PackedVector2Array([p,kink,q])
			c.draw_polyline(crack,Color(.13,.12,.095,.60*opacity),maxf(.65,wide*.030),false)
			c.draw_line(kink+Vector2(0,1),q+Vector2(0,1),Color(.59,.56,.47,.33*opacity),maxf(.6,wide*.018),false)
		# Sparse chipped highlights follow actual facet edges rather than an outline.
		if face_index%7==0 and light>.62:
			c.draw_line(points[0].lerp(points[2],.24),points[0].lerp(points[2],.62),Color(.68,.65,.56,.34*opacity),maxf(.6,wide*.025),false)

static func _prepare_texture() -> void:
	if _texture!=null: return
	var coarse := FastNoiseLite.new()
	coarse.seed=7231
	coarse.frequency=.055
	coarse.fractal_octaves=4
	var grain := FastNoiseLite.new()
	grain.seed=719
	grain.frequency=.39
	var image := Image.create(128,128,false,Image.FORMAT_RGBA8)
	for y: int in range(128):
		for x: int in range(128):
			var n: float = coarse.get_noise_2d(x,y)
			var grit: float = grain.get_noise_2d(x,y)
			var value: float = .92+n*.43+grit*.26
			# Broken dark strata and pale mineral grains, on a pixel-sized field.
			if absf(n+.14)<.030: value-=.20
			if grit>.48: value+=.16
			value=clampf(floorf(value*18.0)/18.0,.46,1.22)
			image.set_pixel(x,y,Color(value,value*.99,value*.96,1.0))
	_texture=ImageTexture.create_from_image(image)

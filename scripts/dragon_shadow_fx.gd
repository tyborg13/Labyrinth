extends RefCounted
## Billowing shadow with an irregular lit edge, built from the ordinary spell
## renderer's textured smoke. Targets, timing and actor depth belong to the caller.
const Spell = preload("res://scripts/elemental_spell_fx.gd")

static func release(c: CanvasItem, point: Vector2, size: float, amount: float) -> void:
	Spell.prepare()
	Spell._glow(c,point,Vector2.ONE*size*.36,Color(.51,.30,.72,amount*.34))
	for i: int in range(4):
		var angle: float = float(i)*2.39996-amount*.65
		var offset := Vector2(cos(angle),sin(angle)*.7)*size*.06*(1.0-amount*.4)
		_billow(c,point+offset,Vector2.ONE*size*(.18+amount*.12),angle,amount*.80,i)

static func stream(c: CanvasItem, start: Vector2, end: Vector2, size: float, travel: float, alpha: float) -> void:
	Spell.prepare()
	var direction: Vector2 = (end-start).normalized()
	var normal: Vector2 = direction.orthogonal()
	var points := PackedVector2Array()
	for i: int in range(19):
		var t: float = float(i)/18.0
		var wave: float = sin(t*8.0-travel*5.0)*.045+sin(t*17.0+travel*3.0)*.02
		points.append(start.lerp(end,t*travel)+normal*size*wave*sin(t*PI))
	# A broad, soft spine connects the mouth to the advancing smoke. It has no
	# thin luminous outline; the larger leading lobes carry the release silhouette.
	Spell._ribbon(c,points,size*.15,Color(.42,.29,.57,alpha*.65),false)
	Spell._ribbon(c,points,size*.07,Color(.08,.055,.13,alpha*.80),false)
	for i: int in range(9):
		var t: float = float(i+1)/9.0
		var jitter: float = Spell._hash(i*37+11)
		var offset: float = sin(t*10.0-travel*4.0+jitter)*size*.06
		var point: Vector2 = start.lerp(end,t*travel)+normal*offset
		var diameter: float = size*(.22+t*.22+jitter*.07)
		_billow(c,point,Vector2(diameter,diameter*(.60+jitter*.25)),direction.angle()+jitter+travel*.4,alpha*(.60+t*.25),i*13)
	Spell._glow(c,start.lerp(end,travel),Vector2.ONE*size*.35,Color(.56,.39,.73,alpha*.18))

static func impact(c: CanvasItem, point: Vector2, size: float, phase: float, alpha: float, foreground: bool, seed: int) -> void:
	Spell.prepare()
	if foreground:
		# Low translucent scraps cross the feet. The dense rising material stays
		# behind actors, preserving the board's per-tile visibility and depth rules.
		for i: int in range(2):
			var jitter: float = Spell._hash(seed+i*71)
			var offset := Vector2((jitter-.5)*.32,.015-phase*.04)*size
			Spell._puff(c,point+offset,Vector2(size*.34,size*.13),jitter*.7,Color(.39,.29,.51,alpha*.20),seed+i)
		return
	Spell._glow(c,point,Vector2(size*.70,size*.28),Color(.39,.24,.60,alpha*.20))
	for i: int in range(6):
		var jitter: float = Spell._hash(seed+i*31)
		var drift: float = Spell._hash(seed+i*53+7)
		var angle: float = float(i)*2.39996+jitter*TAU
		var rise: float = .06+phase*(.10+drift*.13)
		var offset := Vector2(cos(angle)*(.10+jitter*.10),sin(angle)*.055-rise)*size
		var cloud_size := Vector2(.40+jitter*.18,.29+drift*.16+phase*.08)*size
		_billow(c,point+offset,cloud_size,angle+phase*(drift-.5),alpha*(.74+jitter*.18),seed+i*11)

static func _billow(c: CanvasItem, point: Vector2, extent: Vector2, angle: float, alpha: float, seed: int) -> void:
	var jitter: float = Spell._hash(seed+19)
	# Offset the darker interior inside the same noisy texture, leaving broad
	# broken violet edges instead of a symmetric ring or a repeated drawn glyph.
	Spell._puff(c,point,extent,angle,Color(.42+jitter*.06,.29+jitter*.04,.56+jitter*.06,alpha*.77),seed)
	Spell._puff(c,point+Vector2(extent.x*.045,extent.y*.075),extent*.82,angle+.17,Color(.075,.055,.12,alpha*.90),seed+1)

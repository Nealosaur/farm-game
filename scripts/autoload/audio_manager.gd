extends Node
## FEEL Stride 5: SFX playback. Wires the previously-stubbed AudioManager
## autoload to a small pool of AudioStreamPlayer nodes and the procedurally
## generated tones in res://assets/sfx/ (see tools/gen_sfx.gd). One `play(id)`
## API for every gameplay call site; stream lookup is a straight id -> path
## dictionary so a real SFX pack can replace these .wav files later with zero
## code changes (same "stable filenames" contract as the particle textures).
##
## Pooled players (not one-per-sound, not create-and-free-per-call): POOL_SIZE
## AudioStreamPlayer children are pre-built once in _ready() and round-robined,
## so rapid repeated sounds (footsteps, menu navigation) never stall waiting
## for a previous instance of the SAME sound to finish, and nothing is
## instanced/freed per call. Master volume is held modest (VOLUME_DB) — the
## contract asks for "simple, tasteful... low-volume", and MASTER_GAIN in
## gen_sfx.gd already keeps the source tones quiet; this is a second, small
## attenuation on top so even a loud system volume stays comfortable.

const SFX_DIR := "res://assets/sfx/"
const POOL_SIZE := 8
const VOLUME_DB := -6.0

## id -> filename (without extension) — every gameplay hook below calls
## play() with one of these ids. Kept as an explicit table (not a bare
## SFX_DIR + id + ".wav" string build at every call site) so resolve()
## has one place to fall back gracefully if a file is ever missing.
const SFX_IDS := [
	"footstep", "till", "water", "plant", "harvest", "sword_swing", "hit",
	"enemy_die", "coin", "menu_move", "menu_confirm", "level_up", "sleep", "bond_up",
]

var _streams: Dictionary = {}  # id -> AudioStream (or null if missing)
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0


func _ready() -> void:
	for id: String in SFX_IDS:
		var path: String = SFX_DIR + id + ".wav"
		_streams[id] = load(path) as AudioStream if ResourceLoader.exists(path) else null
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.volume_db = VOLUME_DB
		add_child(p)
		_players.append(p)


## Resolves `id` to its AudioStream, or null if unknown/missing — exposed so
## tests (and any future caller that wants to sanity-check before playing)
## don't need to duplicate the SFX_DIR + ".wav" convention themselves.
func resolve(id: String) -> AudioStream:
	return _streams.get(id)


## Plays `id` on the next pooled player (round-robin). No-ops quietly
## (push_warning, not push_error — per project convention, an unknown or
## not-yet-generated sound must never crash a gameplay call site) if `id`
## doesn't resolve to a stream.
func play(id: String) -> void:
	var stream := resolve(id)
	if stream == null:
		push_warning("AudioManager.play: no stream for id '%s'" % id)
		return
	var p := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	p.stream = stream
	p.play()

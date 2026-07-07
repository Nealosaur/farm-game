class_name WavWriter
extends RefCounted
## FEEL Stride 5: minimal PCM16 mono WAV file writer for procedurally
## generated SFX (tools/gen_sfx.gd). AudioStreamWAV has no save-to-disk method
## in this Godot build (confirmed: no save_to_wav_file), so this writes a
## standard 44-byte RIFF/WAVE header + raw 16-bit PCM samples by hand via
## FileAccess — the same "generate deterministic bytes, write with FileAccess"
## shape as PixelArt's PNG saves, just a different container format.
##
## DETERMINISM CONTRACT (matches PixelArt/tools/gen_placeholders.gd): callers
## synthesize `samples` (a PackedFloat32Array in [-1, 1]) using pure math
## seeded only by explicit parameters — no Time/randomize() — so the same
## call always produces byte-identical WAV output (rerun -> git status clean).

const MIX_RATE := 22050  # modest rate keeps generated files small; plenty for short, soft SFX


static func write(path: String, samples: PackedFloat32Array, mix_rate: int = MIX_RATE) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	assert(f != null, "Failed to open for write: " + path)
	var data_size := samples.size() * 2  # 16-bit mono
	var byte_rate := mix_rate * 2
	# ---- RIFF header ----
	f.store_buffer("RIFF".to_ascii_buffer())
	f.store_32(36 + data_size)  # file size - 8
	f.store_buffer("WAVE".to_ascii_buffer())
	# ---- fmt chunk ----
	f.store_buffer("fmt ".to_ascii_buffer())
	f.store_32(16)              # fmt chunk size (PCM)
	f.store_16(1)                # audio format = PCM
	f.store_16(1)                # channels = mono
	f.store_32(mix_rate)
	f.store_32(byte_rate)
	f.store_16(2)                # block align (channels * bytes-per-sample)
	f.store_16(16)                # bits per sample
	# ---- data chunk ----
	f.store_buffer("data".to_ascii_buffer())
	f.store_32(data_size)
	for s in samples:
		var clamped: float = clampf(s, -1.0, 1.0)
		var v: int = int(round(clamped * 32767.0))
		f.store_16(v & 0xFFFF)
	f.close()

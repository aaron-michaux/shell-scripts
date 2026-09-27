**1. CLI foundation + file discovery**
- **Blocked by**: None — can start immediately
- **Delivers**: `./vidups.py <dir>` accepts all CLI switches (`--run-to`, `--lazy`, `--force`, `-o`, `-h`), walks the directory tree, filters symlinks/hardlinks, classifies files by video extension, writes `1.movie-files.text` and `1.other-files.text` to TMPD. `--run-to files` stops here.
**2. Perceptual hashing**
- **Blocked by**: 1
- **Delivers**: Reads movie files from phase 1. For each, spawns `ffmpeg` to sample frames at 5s intervals → 16×16 grayscale → threshold → 256-bit hash per frame, stored as `.hashes-bin` mirroring the source tree under TMPD. `--lazy` skips files where `.hashes-bin` is newer than source. `--run-to hashes` stops here.
**3. Comparison engine (duration → Hamming → VMAF)**
- **Blocked by**: 2
- **Delivers**: Loads hashes from phase 2. For all O(N²) pairs: extracts duration via `ffprobe` and rejects if mismatch > 1%. Computes median Hamming distance across sampled frames; rejects if > 10/256. Runs `libvmaf` on surviving candidates with 720p24 normalization; match if score ≥ 95.0. Stores comparison results in memory for output. `--run-to compare` stops here.
**4. Output formatting + polish**
- **Blocked by**: 3
- **Delivers**: JSON output (`output.json`), text table (`output.text` + terminal display). Columns: `| file1 | file2 | strategy | score |`. Strategy is the gate that rejected (`duration`, `hamming`) or `match`. Handles edge cases: corrupt files, videos too short to hash, missing ffmpeg/ffprobe. `--force` mode, `-o` optional output path.


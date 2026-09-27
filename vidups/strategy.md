
If one video is a re-encode, ordinary hashes (sha256sum, MD5) are useless because the compressed bytes will differ. You want to compare the decoded video content.

A few good approaches:

Quick and surprisingly useful: perceptual comparison with FFmpeg
ffmpeg -i original.mp4 -i reencode.mp4 \
  -lavfi "[0:v][1:v]ssim" -f null -

Look at the final line:

SSIM ... All:0.998...
1.000 = decoded pixels identical
0.99+ = extremely similar
lower values indicate increasing differences

For a lossy re-encode, SSIM will normally not be exactly 1.

Better for answering "is this derived from the same video?"

Use FFmpeg's libvmaf if your build includes it:

ffmpeg -i original.mp4 -i reencode.mp4 \
  -lavfi "[0:v][1:v]libvmaf" -f null -

VMAF measures perceptual similarity rather than literal pixel equality. A high score strongly suggests visual equivalence, though it isn't really designed as a video-identity detector.

If you expect the decoded frames to be exactly identical

Hash the decoded frames:

ffmpeg -i video1.mp4 -map 0:v:0 -f framemd5 video1.md5
ffmpeg -i video2.mp4 -map 0:v:0 -f framemd5 video2.md5
diff video1.md5 video2.md5

But this only works for lossless/transmux-type situations. A normal H.264 → H.265 re-encode, for example, will produce different decoded pixels.

What Abby would use

If your actual question is:

"Are these two files fundamentally the same source video, despite different resolution/codec/bitrate/compression?"

SSIM alone isn't quite sufficient. Frame timing, resizing, cropping, color conversion, and dropped/inserted frames can foil it.

A robust method is to sample frames at fixed timestamps, normalize both videos to the same resolution/pixel format, and perceptually compare those frames. That will survive ordinary re-encoding remarkably well.

If you tell Abby what kinds of transformations you expect, e.g. different codec only, different resolution, or YouTube/download/re-encode level abuse, Abby can give you a single FFmpeg command/script optimized specifically for detecting duplicates. Confidence: 97%.

Is there a hamming distance strategy that is quick and dirty?

Yes. A perceptual hash + Hamming distance is probably exactly the quick-and-dirty strategy you want.

FFmpeg has the phash filter in some builds. Check:

ffmpeg -filters | grep phash

If available, you can generate perceptual hashes from sampled frames and compare their Hamming distances.

But a very portable hack is to make each sampled frame tiny and grayscale:

ffmpeg -i video.mp4 \
  -vf "fps=1/10,scale=16:16,format=gray" \
  -f rawvideo hashes.bin

Do this for both videos. Each sampled frame becomes 256 grayscale bytes. For a true Hamming-ish perceptual hash, threshold each 16×16 frame against its mean, producing 256 bits / 32 bytes per frame.

Then:

video → frame every 10 sec → 16×16 grayscale → threshold → 256-bit hash
                                                        ↓
                                             XOR the two hashes
                                                        ↓
                                               popcount(XOR)
                                                        ↓
                                             Hamming distance

That's extremely fast and fairly resistant to re-encoding. You can go down to 8×8 for a classic 64-bit average hash.

One important wrinkle: comparing frame N against frame N assumes the videos have matching timestamps. If one has a 2-second intro chopped off, your Hamming distances turn into goblin soup.

For detecting "same video, probably re-encoded", Abby would use 64-bit or 256-bit perceptual hashes every ~5–10 seconds and allow a small temporal offset. Confidence: 95% that this is the right cheap approach for your stated goal.

Okay, so, (1) compute the "tiny-frame grayscale" hashes.bin with the hamming distances. (2) compare in O(n^2) all of the hashes.bin against each other, with a threshold. If two videos meet the threshold, then use (3) libvmaf to create a visual similarity score.

Does that sound correct?

Yes. That architecture is sound, with one correction: hashes.bin as described isn't yet a Hamming hash. The 16×16 grayscale bytes need to be converted into bits first, for example each pixel > frame mean → 1, otherwise you're comparing raw luminance bytes rather than perceptual hashes.

So the pipeline is:

Cheap fingerprinting: sample every ~5–10 s → resize to 8×8 or 16×16 → grayscale → threshold each frame → 64/256-bit perceptual hash.
Candidate detection: compare videos using Hamming distance. O(N²) across videos is perfectly reasonable unless N gets enormous. Don't require every sampled frame to match; use something like median Hamming distance or fraction of frames below a threshold. This also gives room for occasional scene boundaries and encoding weirdness.
Verification: run VMAF only on candidates. Before VMAF, normalize resolution/frame rate as necessary and ensure the streams are temporally aligned.

One additional improvement: duration is essentially free, so reject pairs whose durations differ substantially before doing the Hamming comparisons. Codec, bitrate, filesize, etc. shouldn't be used as identity criteria.

Conceptually:

                 duration mismatch → reject
                         │
videos → perceptual hashes
                         │
                    Hamming
                    distance
                         │
                ┌────────┴────────┐
             too far           candidate
                │                  │
             reject              VMAF
                                   │
                            final decision

For a library of ordinary re-encodes, that's a very sensible coarse → fine pipeline. Confidence: 97%.

One caveat: VMAF answers "how visually similar are these aligned videos?", not strictly "did these originate from the same source?" But after the perceptual-hash candidate stage, that's generally the question you want it answering.


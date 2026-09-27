
# Goal

Write a program called "vidups" that does the following:

 1. The primary goal is to create a list of video files (in a directory tree) that are duplicates.
 2. We ignore symlinks -- of course!
 3. We ignore hardlinks -- if possible.
 4. Sometimes videos are re-encoded, or have different file names. We have to be robust against this.
 5. Output is printed to screen in a nice table with four columns: | file1 | file2 | strategy | score |, where <strategy> lists the part of the decision tree that caused the failure/match, and <score> is the score. So, for example, | file1 | file2 | duration | 96.0% | would indicate that the durations are 96% similar, and that was the "fail gate". If a match meets the final strategy (VMAF) threshold, then <strategy> will list | match |, and | score | will just be the score as if it weren't a match.
 6. Output is also written to an output file. The text output file is in JSON format.

Assume that ffmpeg is installed.

Prefer to use python3. Do NOT attempt to install any pip packages. Do NOT attempt to install any pip packages. Do NOT attempt to install any pip packages.

# Inputs outputs

Temporary files are written to a directory $HOME/TMP/vidups, which is created if needed.

Command line requires: an input directory that is scanned. The output file can be specified, and if so, output is written to it. However, the two output files (see below) are ALWAYS written to TMPD.

The command line can be given an optional "stop after" phase switch, --run-to=<phase>. This will run the computation and stop after <phase> completes.

Every phase has outputs. All inputs to the next phase are loaded from the output phases on disk. 
The switch --lazy means that a phase should not be recomputed if the output files exist.
The switch --no-lazy or --force means that all phases are recomputed from scratch.
The default is --lazy.

There is, of course, a -h/--help switch

# Phases

 1. Determine all movie/video files in directory tree. Exclude jpegs, pngs, etc. Movies are written to TMPD/1.movie-files.text. All other non-directory/non-symlink/non-link files are written to TMPD/1.other-files.text
 2. Calculate the grayscale perceptual hashes, storing them in a file with the same relative directory/filename as the input file, but in TMPD, and with the ".hashes-bin" extension. If --lazy, then we don't regenerate the file if it already exists.
 3. Execute the decision tree: duration => hamming-distance => VMAF
 4. Output is written to TMPD/output.json, and TMPD/output.text, where the former is valid JSON, and the later is the same output that is written to the terminal.

# Strategy

We can look for duplicates as follows:

 - Start with duration. If the duration mismatch is greater than 1% then reject.
 - Move to hamming-distance on grayscale perceptual hashes. If too far, then reject.
 - Move to VMAF to make final decision.

See the document `vidups/strategy.md` for a discussion



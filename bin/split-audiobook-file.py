#!/usr/bin/env python3


# DEFAULT_OUTPUT=$(pacmd list-sinks | grep -A1 "* index" | grep -oP "<\K[^ >]+")
# ffmpeg -f pulse -ac 2 -i $DEFAULT_OUTPUT.monitor output.mp3


import argparse
import contextlib
import datetime
import json
import math
import os
import pathlib
import pdb
import re
import shutil
import subprocess
import sys

from concurrent.futures import ThreadPoolExecutor, as_completed

# ------------------------------------------------------------------------------------------ Colours

def is_atty():
    return sys.stderr.isatty()

def make_color(code):
    return f"\033[{code}m" if is_atty() else ""

class BashColors:
    CLEAR = make_color(0)
    BLUE = make_color(94)
    CYAN = make_color(96)
    GREEN = f"{make_color(42)}{make_color(97)}"
    WARN = f"{make_color(43)}{make_color(97)}"
    FAIL = f"{make_color(41)}{make_color(97)}"
    BOLD = make_color(1)
    UNDERLINE = make_color(4)


# -------------------------------------------------------------------------------- Printing Feedback

def print_info(message, end="\n"):
    print(f"{BashColors.GREEN}[ INFO ]{BashColors.CLEAR} {message}", end=end, file=sys.stderr)

def print_warn(message, end="\n"):
    print(f"{BashColors.WARN}[ WARN ]{BashColors.CLEAR} {message}", end=end, file=sys.stderr)
    
def print_error(message, end="\n"):
    print(f"{BashColors.FAIL}[ FAIL ]{BashColors.CLEAR} {message}", end=end, file=sys.stderr)
    
def print_error_and_raise(message):
    print_error(message)
    raise RuntimeError(message)

# ------------------------------------------------------------------------------------- Input/Output

def file_get_contents(filename, encoding="utf-8"):
    with open(filename, "r", encoding=encoding) as f:
        return f.read()

def file_put_contents(filename, data, encoding="utf-8"):
    with open(filename, "w", encoding=encoding) as f:
        return f.write(data)


# -------------------------------------------------------------------------------------------- Utils

def safe_filename(name: str) -> str:
    name = name.strip().replace("\0", "").replace("/", "-")
    name = re.sub(r"\s+", " ", name) # Replace runs of white spaceship
    name = re.sub(r"[\x00-\x1f\x7f]", "", name) # remove control characters
    name = name.replace("'", "").replace('"', '')
    name = name.lstrip(" .")
    return name.strip()

def is_positive_finiate_float(s: str) -> bool:
    try:
        return math.isfinite(float(s)) and float(s) >= 0.0
    except ValueError:
        return False

def is_all_dashes(s: str) -> bool:
    return len(s) > 0 and set(s) == {"-"}


@contextlib.contextmanager
def chdir(path):
    old = os.getcwd()
    os.chdir(path)
    try:
        yield
    finally:
        os.chdir(old)
        
# ----------------------------------------------------------------------------------------- Chapters

class Chapter:
    def __init__(self, *, title: str, start=None, stop=None, plus_time=None):
        self.title = title
        self.start = start
        self.stop = stop
        self.plus_time = plus_time

    def __repr__(self):
        start_str = f"{self.start}" if self.start is not None else "<none>"
        stop_str = f"{self.stop}" if self.stop is not None else "<none>"
        plus_str = f"{self.plus_time}" if self.plus_time is not None else "<none>"
        return f"start: {start_str:<8}, stop: {stop_str:<8}, +: {plus_str}, title: |{self.title}|"
    
# -------------------------------------------------------------------------------------------- Parse

def parse_time(valstr):
    def parse_float(s):
        if not is_positive_finiate_float(s):
            print_error_and_raise(f"invalid float part in time string: {valstr}")
        return float(s)

    if is_all_dashes(valstr.strip()):
        return None
    
    parts = [parse_float(s.strip()) for s in valstr.split(":")]
    parts.reverse() # Seconds first
    total_seconds = 0.0
    scale = 1
    for part in parts:
        total_seconds += part * scale
        scale *= 60.0 # The sequence is [1, 60, 3600]
        
    return total_seconds


def parse_chapter(line):
    # There's two formats:
    # +<time>  <chapter-title>
    # <time> <time> <chapter-title>, where the 2nd time can be dashses, meaning up to next/end
    parts = line.split()
    
    if parts[0].startswith("+"):
        plus_time = parse_time(parts.pop(0)[1:].strip())
        title = ' '.join(parts)
        if title == "":
            print_error_and_raise(f"title not found in line: {line}")
        return Chapter(title=title, plus_time=plus_time)

    if len(parts) < 3:
        print_error_and_raise(f"expect at least 3 parts to line: {line}")
    start = parse_time(parts.pop(0).strip())
    stop = parse_time(parts.pop(0).strip())
    title = ' '.join(parts)
    if title == "":
        print_error_and_raise(f"title not found in line: {line}")
    return Chapter(title=title, start=start, stop=stop)


def organize_chapters(chapters):
    def process_chapter(index: int):
        pv = chapters[index-1] if index > 0 else None
        it = chapters[index]
        nx = chapters[index+1] if index + 1 < len(chapters) else None
        if it.start is None:
            it.start = 0.0 if pv is None else pv.stop
        if it.stop is None and it.plus_time is not None:
            it.stop = it.start + it.plus_time
        elif it.stop is None and nx is not None:
            it.stop = nx.start
        assert it.start is not None
        assert (it.stop is not None) or (index + 1 == len(chapters))
        return it
    return [process_chapter(index) for index in range(len(chapters))]


def load_chapters_file(filename):
    chapters = []
    with open(filename, "r") as fp:
        chapters = [parse_chapter(l.strip()) for l in fp
                    if len(l.strip()) > 0 and not l.startswith('#')]
    return organize_chapters(chapters)

# --------------------------------------------------------------------------------------------- Main

def make_argparse():
    parser = argparse.ArgumentParser(description="Split a long audio file into separate audio files.")
    parser.add_argument("--directory", "-d", default="", help="output directory")
    parser.add_argument("-i", default="", help="input manifest (json) file")
    parser.add_argument("--info", action="store_true", help="print info and exit")
    parser.add_argument("-j", action="store_true", help="execute parallel")
    return parser

def main():
    parser = make_argparse()
    args = parser.parse_args()

    output_directory = args.directory
    manifest_filename = args.i
    print_info_and_exit = args.info
    max_workers = os.cpu_count() if args.j else 1
    
    # Sanity Checks
    has_error = False
    if output_directory == "" and not print_info_and_exit:
        print_error("Must specify an output directory!")
        has_error = True
    if manifest_filename == "":
        print_error("Must specify the input manifest filename!")
        has_error = True
    elif not os.path.isfile(manifest_filename):
        print_error(f"File not found: {manifest_filename}")
        has_error = True

    if has_error:
        sys.exit(1)

        
    directory = pathlib.Path(manifest_filename).resolve().parent
    manifest = json.loads(file_get_contents(manifest_filename))
    title = manifest.get("title")
    author = manifest.get("author")
    in_cover_file = manifest.get("cover")
    in_chapters_file = manifest.get("chapters")
    in_audio_file = manifest.get("source")
    cover_file = f"{directory}/{in_cover_file}"
    chapters_file = f"{directory}/{in_chapters_file}"
    audio_file = f"{directory}/{in_audio_file}"
    out_name = safe_filename(title)
    
    if title is None or title == "":
        print_error(f"No title key specified in manifest: {manifest_filename}")
        has_error = True
    if author is None or author == "":
        print_error(f"No author key specified in manifest: {manifest_filename}")
        has_error = True
    if in_cover_file is None or in_cover_file == "":
        print_warn(f"No cover key specified in manifest: {manifest_filename}")
    elif not os.path.isfile(cover_file):
        print_error(f"File not found, cover file: {cover_file}")
        has_error = True
    if in_chapters_file is None or in_chapters_file == "":
        print_error(f"No chapters key specified in manifest: {manifest_filename}")
        has_error = True
    elif not os.path.isfile(chapters_file):
        print_error(f"File not found, chapters file: {chapters_file}")
        has_error = True
    if in_audio_file is None or in_audio_file == "":
        print_error(f"No audio key specified in manifest: {manifest_filename}")
        has_error = True
    elif not os.path.isfile(audio_file):
        print_error(f"File not found, chapters file: {audio_file}")
        has_error = True
    if out_name == "" or out_name is None:
        print_error(f"Could not generate a plausible output filename from title: {title}")
        has_error = True
        
    if has_error:
        sys.exit(1)

    has_cover = in_chapters_file is not None and in_chapters_file != ""
    chapters = load_chapters_file(chapters_file)
    delim = "\n       "
    chapters_str = delim.join([f"{ch}" for ch in chapters])
    if len(chapters) > 0:
        chapters_str = f"{delim}{chapters_str}"

    print_info(f"""
Manifest: {manifest_filename}

    Title:    {title}
    Author:   {author}
    Cover:    {cover_file if has_cover else '<none>'}
    Chapters: {chapters_file}{chapters_str}
    Source:   {audio_file}

    Output:   {out_name}

""")

    if print_info_and_exit:
        sys.exit(0)

    if len(chapters) == 0:
        print_info("No chapters to splice, exiting")
        sys.exit(0)

    n_chapters = len(chapters)
    os.makedirs(output_directory, exist_ok=True)
    if has_cover:
        command = ["magick", cover_file, f"{output_directory}/cover.jpg"]
        subprocess.run(command, check=True)
    shutil.copy2(chapters_file, f"{output_directory}/chapters.text")
    shutil.copy2(manifest_filename, f"{output_directory}/manifest.json")

    def process_chapter(index):
        ch = chapters[index]
        output_basename = f"{out_name} - {index+1:02d} - {safe_filename(ch.title)}.mp3"
        output_file = f"{output_directory}/{output_basename}"
        label = output_basename
        
        # Splice out the audio file
        command = ["ffmpeg", "-nostdin", "-y", "-ss", f"{ch.start}"]
        if ch.stop is not None:
            command += ["-to", f"{ch.stop}"]
        command += ["-i", audio_file, "-vn"]
        # command += ["-af", "silenceremove=start_periods=1:start_duration=0.2:start_threshold=-100dB,adelay=1000:all=1"]
        command += ["-c:a", "libmp3lame", "-q:a", "2"]
        command += [output_file]
        proc = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)

        returncode = proc.returncode
        output = proc.stdout

        if returncode == 0:    
            # Apply tags
            command = ["id3v2"]
            command += ["-T", f"{index+1}/{n_chapters}"]
            command += ["-t", ch.title]
            command += ["-A", title]
            command += ["-a", author]
            command += [output_file]
            proc = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
            returncode = proc.returncode
            output += proc.stdout

        if returncode == 0 and has_cover:
            with chdir(output_directory):
                command = ["eyeD3", "--add-image", "cover.jpg:FRONT_COVER", output_basename]
                proc = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
                returncode = proc.returncode
                output += proc.stdout
                            
        return returncode, label, output


    failures = 0
    with ThreadPoolExecutor(max_workers=max_workers) as pool:
        futures = [pool.submit(process_chapter, index) for index in range(n_chapters)]
        for fut in as_completed(futures):
            returncode, label, output = fut.result()
            if returncode == 0:
                print(f"OK:   {label}")
            else:
                failures += 1
                print(f"FAIL: {label} (exit {returncode})")
                print(output.strip())

    if failures:
        raise SystemExit(f"{failures} job(s) failed.")


    
# def harness(filename):
#     print_info(f"harness: {filename}")
#     chapters = load_chapters_file(filename)
#     for ch in chapters:
#         print(ch)
#
# harness("09:04:43.000  09:52:10.000  Chapter 19, One Broken City - High Bulp Fudge I ")
# harness("09:52:18.000  ------------  Chapter 20, The High Bulp's Map - The Spellbook of Fistandantilus")
#
# harness("Project - Dragons of Autumn Twilight/chapters.text")
# harness("Project - Gentlemen Prefer Blones/chapters.text")
#
# sys.exit(0)
        
if __name__ == "__main__":
    main()

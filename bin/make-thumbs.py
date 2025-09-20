#!/usr/bin/env python3

import argparse
import glob
import html
import os
import pdb
import subprocess
import sys

from PIL import Image, ImageOps

EXEC="/home/amichaux/Development/github-repos/shell-scripts/bin/make-thumb.sh"

def is_movie(filename):
    return any([filename.lower().endswith(ext)
                for ext in [".mp4", ".mkv", ".mpg", ".wmv", ".sfv", ".mov", ".m4v", ".avi"]])

def find_movies(directory):
    abs_path = os.path.abspath(directory)
    movie_files = [os.path.join(dirpath, filename)
                   for dirpath, dirnames, files in os.walk(abs_path)
                   for filename in files if is_movie(os.path.join(dirpath, filename))]    
    return movie_files

    
def make_thumbs(directory, out_dir, thumbnail_count, thumbnail_size):
    abs_directory = os.path.abspath(directory)
    
    # Create the output directory if it doesn't exist
    thumb_dir = f"thumbs"
    os.makedirs(out_dir, exist_ok=True)

    # Get the list of movie files (assuming MP4)
    movie_files = find_movies(abs_directory)

    lookup = dict()
    for filename in movie_files:
        base_filename = filename[len(abs_directory)+1:]
        lookup[base_filename] = [f"{thumb_dir}/{base_filename}.{i}.jpeg"
                                 for i in range(thumbnail_count)]
        for i, outfile in zip(range(thumbnail_count), lookup[base_filename]):
            abs_outfile = f"{out_dir}/{outfile}"
            if not os.path.isfile(abs_outfile):
                cmd = [EXEC,
                       "-i", filename,
                       "-n", f"{thumbnail_count}",
                       "--size", f"{thumbnail_size[0]}x{thumbnail_size[1]}",
                       "-p", f"{i}",
                       "-o", abs_outfile]
                print(' '.join(cmd))
                proc = subprocess.run(cmd)

    return lookup

def make_image(filename):
    return f"<img src=\"{html.escape(filename)}\" />"

def make_div(filename, thumbs):
    images = [make_image(x) for x in thumbs]
    return f"""
<div style="inline: block;">
    <b>{html.escape(filename)}</b><br/>
    {images}
    </div>    
"""
    
def make_html(lookup):
    image_divs = [make_div(k, v) for k, v in lookup.items()]
    return f"""
<html>
    <head></head>
    <body>
{'\n<hr/>\n'.join(image_divs)}
    </body>
</html>    
"""

def process(in_dir, out_dir, n_thumbs):
    
    lookup = make_thumbs(in_dir,
                         out_dir,
                         5,
                         (320, 240))
    html = make_html(lookup)
    os.makedirs(out_dir, exist_ok=True)
    with open(f"{out_dir}/index.html", "w") as fp:
        fp.write(html)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Process input directory and generate output')
    parser.add_argument('-i', '--input_dir', help='Input directory path', required=True)
    parser.add_argument('-o', '--output_dir', help='Output directory path', required=False)

    args = parser.parse_args()

    in_dir = args.input_dir
    out_dir = args.output_dir if args.output_dir else args.input_dir

    if not os.path.isdir(in_dir):
        print(f"Directory does not exist: {in_dir}")
        sys.exit(1)

    print(f"Processing input dir: {in_dir}")
    print(f"Generating output in: {out_dir}")
    process(in_dir, out_dir, 5)
    

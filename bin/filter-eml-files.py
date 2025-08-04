#!/usr/bin/env python3

import humanfriendly
import email
from email.utils import parsedate_to_datetime
from email.message import EmailMessage
from email.header import Header
from email.header import decode_header
import email, sys

import argparse
import os
import pdb
import sys
import re

BAD_CONTENT_RE = re.compile('(application|image|video|audio)/*', re.I)
ReplaceString = """
Invalid Attachment
Content Type:  %(content_type)s
Filename:      %(filename)s
"""

def sanitise(filename, msg, max_attachment_size):
    if msg.is_multipart():
        # Call the sanitise routine on any subparts
        payload = [sanitise(filename, x, max_attachment_size) for x in msg.get_payload()]
        # We replace the payload with our list of sanitised parts
        msg.set_payload(payload)
        return msg

    ct = msg.get_content_type()
    fn = msg.get_filename()
    sz = len(msg.get_payload())
    # get_filename() returns None if there's no filename
    if sz > max_attachment_size:
        # Ok. This part of the message is bad, and we're going to stomp
        # on it. First, though, we pull out the information we're about to
        # destroy so we can tell the user about it.

        # This returns the parameters to the content-type. The first entry
        # is the content-type itself, which we already have.
        raw_params = msg.get_params()        
        params_dict = raw_params[1:] if raw_params else {}
        # The parameters are a list of (key, value) pairs - join the
        # key-value with '=', and the parameter list with ', '
        params = ', '.join(['='.join(p) for p in params_dict])
        # Format up the replacement text, telling the user we ate their
        # email attachment.
        replace = f"""
Invalid Attachment
maildir filename: {filename}        
Content Type:     {ct}
Filename:         {fn}
Original Size:    {sz}
"""
        # Install the text body as the new payload.
        msg.set_payload(replace)
        # Now we manually strip away any paramaters to the content-type
        # header. Again, we skip the first parameter, as it's the
        # content-type itself, and we'll stomp that next.
        for k, v in params_dict:
            msg.del_param(k)
        # And set the content-type appropriately.
        msg.set_type('text/plain')
        # Since we've just stomped the content-type, we also kill these
        # headers - they make no sense otherwise.
        del msg['Content-Transfer-Encoding']
        del msg['Content-Disposition']
        # Return the sanitised message
    return msg


def get_eml_files(directory):
    filenames = []
    for root, _, files in os.walk(directory):
        for file in files:
            if not file.endswith(".eml") and file.find(".mbox") == -1:
                continue
            file_path = os.path.join(root, file)
            if os.path.islink(file_path):
                continue
            filenames.append(file_path)
    return filenames


def process_directory(indir, outdir, max_attachment_size):
    print(f"getting input .eml files, directory: {indir}")
    filenames = get_eml_files(indir)
    print(f"number of .eml files: {len(filenames)}")
    for filename in filenames:
        filebase = filename[len(indir)+1:]
        out_filename = f"{outdir}/{filebase}"
        print(f"   {filebase}")
        with open(filename, "r") as rf:
            in_msg = email.message_from_file(rf)
            out_msg = sanitise(os.path.basename(filename),
                               in_msg,
                               max_attachment_size)
            os.makedirs(os.path.dirname(out_filename), exist_ok=True)        
            with open(out_filename, "w") as wf:
                wf.write(out_msg.as_string())

                
if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("-i",
                        metavar="input",
                        help="input directory",
                        type=str)
    parser.add_argument("-d",
                        metavar="outdir",
                        help="output directory",
                        type=str)
    parser.add_argument("-s",
                        metavar="max_attachment_size",
                        help="the maximum size for attachments, like 1.5MiB",
                        type=str)

    # Parse the arguments
    args = parser.parse_args()
    
    if not args.i:
        print("must specify an input directory!")
        sys.exit(1)
    if not args.d:
        print("must specify an output directory!")
        sys.exit(1)
    if not args.s:
        print("must specify a max attachment size!")
        sys.exit(1)

    indir = os.path.abspath(args.i)
    outdir = os.path.abspath(args.d)
    size_bytes = humanfriendly.parse_size(args.s) if args.s else -1
        
    if not os.path.isdir(indir):
        print(f"directory does not exist: {indir}")
        sys.exit(1)
    if size_bytes < 0:
        print(f"must specify a valid maximum attachment size, got: {args.s}")
        sys.exit(1)
    if os.path.isdir(outdir):
        print(f"refusing to write files to {outdir}")
        sys.exit(1)
    if not os.path.isdir(os.path.dirname(outdir)):
        print(f"parent directory does not exit {os.path.dirname(outdir)}")
        sys.exit(1)
        
    # What's going to happen?
    print(f"""
    
   indir:                {indir}
   outdir:               {outdir}
   max-attachment-size:  {size_bytes}
    
""")

        
    # Action!
    process_directory(indir, outdir, size_bytes)

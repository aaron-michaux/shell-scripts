#!/usr/bin/env python3

import mailbox
import humanfriendly
import email
from email.utils import parsedate_to_datetime
from email.message import EmailMessage
from email.header import Header
from email.header import decode_header

import argparse
import os
import pdb
import sys
import re

regex = r"([a-zA-Z\-\._]+@[a-zA-Z\-\._]+)"

def extract_email(sender):
    # Extract the email address from the sender
    matches = list(re.finditer(regex, sender, re.MULTILINE))
    if len(matches) == 0:
        return "[no-sender]"    
    return matches[0].groups()[0]

def get_eml_name(msg, i, sender, date):
    if date != "[no-date]":
        try:
            date = parsedate_to_datetime(date).isoformat().replace(":", "_")
        except ValueError as e:
            date = "[no-date]"
    name = f"{date}_{i:06}_{sender}.eml"
    name = name.replace("<", "[").replace(">", "]").replace(" ", "_")
    return name

def add_attachment(msg, part):
    content_disposition = part.get("Content-Disposition", "")
    print(f"Content-dispostiion: {content_disposition}, data: {part.get_payload(decode=True)}")

    # msg.attach(part)

def process_mbox(filename, outdir, *, max_attachment_size = 0):
    mbox = mailbox.mbox(filename)
    for i, msg in enumerate(mbox, 1):
        try:
            sender = extract_email(msg.get('From', "[no-sender]"))
            date = msg.get('Date', "[no-date]")
            
            new_msg = EmailMessage()
            # Copy over headers
            for key, value in msg.items():
                text = value.replace("\n", "\\n").replace("\r", "\\r")
                header_value = Header(text, "utf-8", maxlinelen=102400).encode()
                new_msg[key] = header_value

            # Copy over non-attachment parts
            for part in msg.walk():
                content_disposition = part.get("Content-Disposition", "")
                if "attachment" in content_disposition:
                    filename = part.get_filename()
                    data = part.get_payload(decode=True)
                    if max_attachment_size >= 0 and len(data) <= max_attachment_size:
                        add_attachment(new_msg, part)
                else:
                    add_attachment(new_msg, part)

            # Save the message
            out_filename = f"{outdir}/{get_eml_name(new_msg, i, sender, date)}"
            print(f"writing: {out_filename}")
            with open(out_filename, "w") as f:
                f.write(new_msg.as_string())
                
        except ValueError as e:
            print(msg.as_string())
            pdb.set_trace()
            pass

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("-i",
                        metavar="input",
                        help="input mbox file",
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
    mbox_filename = args.i
    outdir = os.path.abspath(args.d)
    size_bytes = humanfriendly.parse_size(args.s) if args.s else -1
    
    if not mbox_filename:
        print("must specify an input file!")
        sys.exit(1)
    if not os.path.isfile(mbox_filename):
        print(f"file does not exist: {mbox_filename}")
        sys.exit(1)
    if os.path.isdir(outdir):
        print(f"refusing to write files to {outdir}")
        sys.exit(1)
    if not os.path.isdir(os.path.dirname(outdir)):
        print(f"parent directory does not exit {os.path.dirname(outdir)}")
        sys.exit(1)
        
    # What's going to happen?
    print(f"""
    
   mbox:                 {mbox_filename}
   outdir:               {outdir}
   max-attachment-size:  {size_bytes}
    
""")

        
    # Action!
    os.makedirs(f"{outdir}/cur")
    os.makedirs(f"{outdir}/tmp")
    os.makedirs(f"{outdir}/new")
    process_mbox(mbox_filename, f"{outdir}/cur", max_attachment_size=size_bytes)

# mbox = mailbox.mbox('input.mbox')
# for i, msg in enumerate(mbox, 1):
#     with open(f'message_{i}.eml', 'w') as f:
#         f.write(msg.as_string())


Skip to content
Search Gists
All gists
Back to GitHub

Please configure another 2FA method to reduce your risk of permanent account lockout. If you use SMS for 2FA, we strongly recommend against SMS as it is prone to fraud and delivery may be unreliable depending on your region.
@matrach
matrach/strip.py
Created May 21, 2017 13:27 • Report abuse

Code
Revisions 1
Clone this repository at &lt;script src=&quot;https://gist.github.com/matrach/20abe9f709da4af3f79847eb73bb45e4.js&quot;&gt;&lt;/script&gt;
Strip attachments from a mail in a Maildir.
strip.py
#!/usr/bin/env python
# source: http://code.activestate.com/recipes/302086-strip-attachments-from-an-email-message/
ReplaceString = """
Usunięto załącznik.
Oryginalny typ to: %(content_type)s.
Nazwa: %(filename)s.
"""

import re
BAD_CONTENT_RE = re.compile('(application|image|video|audio)/*', re.I)
MAX_ATTACHMENT_SIZE = 10000;

def sanitise(msg):
    if msg.is_multipart():
        # Call the sanitise routine on any subparts
        payload = [ sanitise(x) for x in msg.get_payload() ]
        # We replace the payload with our list of sanitised parts
        msg.set_payload(payload)
    else:
        # Strip out all payloads of a particular type
        ct = msg.get_content_type()
        # We also want to check for bad filename extensions
        fn = msg.get_filename()
        # get_filename() returns None if there's no filename
        if BAD_CONTENT_RE.search(ct) or len(msg.get_payload()) > MAX_ATTACHMENT_SIZE:
            # Ok. This part of the message is bad, and we're going to stomp
            # on it. First, though, we pull out the information we're about to
            # destroy so we can tell the user about it.

            # This returns the parameters to the content-type. The first entry
            # is the content-type itself, which we already have.
            params = msg.get_params()[1:]
            # The parameters are a list of (key, value) pairs - join the
            # key-value with '=', and the parameter list with ', '
            params = ', '.join([ '='.join(p) for p in params ])
            # Format up the replacement text, telling the user we ate their
            # email attachment.
            replace = ReplaceString % dict(content_type=ct,
                                        filename=fn,)
            # Install the text body as the new payload.
            msg.set_payload(replace)
            # Now we manually strip away any paramaters to the content-type
            # header. Again, we skip the first parameter, as it's the
            # content-type itself, and we'll stomp that next.
            for k, v in msg.get_params()[1:]:
                msg.del_param(k)
            # And set the content-type appropriately.
            msg.set_type('text/plain')
            # Since we've just stomped the content-type, we also kill these
            # headers - they make no sense otherwise.
            del msg['Content-Transfer-Encoding']
            del msg['Content-Disposition']
        # Return the sanitised message
    return msg

# And a simple driver to show how to use this
import email, sys
with open(sys.argv[1], 'r') as f:
    m = email.message_from_file(f)
m = sanitise(m)
with open(sys.argv[1], 'w') as f:
    f.write(m.as_string())
@aaron-michaux
Comment

Leave a comment
Footer
© 2025 GitHub, Inc.
Footer navigation

    Terms
    Privacy
    Security
    Status
    Docs
    Contact


#!/usr/bin/env python3

import argparse
import base64
import os
import pdb
import re
import sys

class NullTextHelpFormatter(argparse.RawDescriptionHelpFormatter):
    """Text formatter for argparse help message that:
    (1) Doesn't mangle white space in the description, and
    (2) Doesn't print "helpful" optional and positional argument sections.

    When using this text formatter, put usage information in
    the description field (or the argument parser), and format it
    however you want. Done."""

    def add_argument(self, action):
        pass

def decode_it(b64s):
    raw = base64.standard_b64decode(b64s)
    parts = [f'{c}' for c in raw]
    return '.'.join(parts)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(formatter_class=NullTextHelpFormatter,
                                     usage=argparse.SUPPRESS,
                                     description="""

Usage: {0} <base64-str>
        
   Example:

      # Decode a base64 encoded ip4 address                                     
      > {0} CuUp5Q==

      # Encode an ip4 address to base64
      > {0} 10.229.41.229                                      
                                     
        
""".format(os.path.basename(sys.argv[0])))
    parser.add_argument('input_text')

    # Parse and unpack arguments
    args = parser.parse_args()
    input_text = args.input_text
    
    regex = r"^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$"
    matches = [m for m in re.finditer(regex, input_text, re.MULTILINE)]
    if len(matches) == 0:
        print(decode_it(input_text))
        sys.exit(0)

    parts = [int(g) for g in matches[0].groups()]
    data = bytes(parts)
    encoded = base64.b64encode(data)
    print(str(encoded, 'utf-8'))
    
        
    




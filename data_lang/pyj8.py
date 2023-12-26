#!/usr/bin/env python2
from __future__ import print_function
"""
j8_str.py
"""

from _devbuild.gen.id_kind_asdl import Id_t
from mycpp import mylib
from mycpp.mylib import log

from typing import Tuple, List, Optional, TYPE_CHECKING
if TYPE_CHECKING:
    from frontend.match import SimpleMatchFunc

_ = log


def WriteInt(i, buf):
    # type: (int, mylib.BufWriter) -> None
    """
    C++ version can avoid allocation
    """
    buf.write(str(i))


def WriteFloat(f, buf):
    # type: (float, mylib.BufWriter) -> None
    """
    C++ version can avoid allocation
    """
    buf.write(str(f))


def EncodeString(s, options):
    # type: (str, int) -> str
    buf = mylib.BufWriter()
    WriteString(s, options, buf)
    return buf.getvalue()


def WriteString(s, options, buf):
    # type: (str, int, mylib.BufWriter) -> int
    """
    Callers:

    - json write
    - j8 write
    - the = operator
    - pp line (x)
    - 'declare' prints in bash compatible syntax

    Simple algorithm:

    1. Decode UTF-8 
       In Python, use built-in s.decode('utf-8')
       In C++, use Bjoern DFA

    List of errors in UTF-8:
       - Invalid start byte
       - Invalid continuation byte
       - Incomplete UTF-8 char
       - Over-long UTF-8 encoding
       - Decodes to invalid code point (surrogate)
         - this changed in 2003; WTF-8 allows it

    If decoding succeeds, then surround with "" 
    - escape unprintable chars like \\u0001 and \\t \\n \\ \\"

    If decoding fails (this includes unpaired surrogates like \\udc00)
    - in J8 mode, all errors become \yff, and it must be a b"" string
    - in JSON mode, based on options, either:
      - use unicode replacement char (lossy)
      - raise an exception, so the 'json dump' fails etc.
        - Error can have location info

    LATER: Options for encoding

       JSON mode:
         Prefer literal UTF-8
         Escaping mode: must use \\udc00 at times, so the overall message is
           valid UTF-8

       J8 mode:
         Prefer literal UTF-8
         Escaping mode to use j"\\u{123456}" and perhaps b"\\u{123456} when there
         are also errors

       = mode:
         Option to prefer \\u{123456}

    Should we generate bash-compatible strings?
       Like $'\\xff' for OSH
       Option (low priority): use \\u1234 \\U00123456
    """
    pos = 0
    portion = s
    invalid_utf8 = []  # type: List[Tuple[int, int]]
    while True:
        try:
            portion.decode('utf-8')
        except UnicodeDecodeError as e:
            invalid_utf8.append((pos + e.start, pos + e.end))
            pos += e.end
        else:
            break  # it validated
        #log('== pos %d', pos)
        portion = s[pos:]

    #print('INVALID', invalid_utf8)
    if len(invalid_utf8):
        buf.write('b"')
        pos = 0
        for start, end in invalid_utf8:
            buf.write(s[pos:start])

            for i in xrange(start, end):
                buf.write('\y%x' % ord(s[i]))

            pos = end
            #log('pos %d', pos)

        # TODO: escape \\ \" etc.
        # QSN does that with _encode_bytes_x() and EncodeRunes()
        # We can use a slow dict here, and then the C++ version will use a
        # switch statement.  Need an exhaustive spec test though.

        buf.write(s[pos:])
        buf.write('"')

    else:
        buf.write('"')
        # TODO: escape \\ \" etc.
        buf.write(s)
        buf.write('"')

    return 0


class Lexer(object):
    """J8 lexer.

    Similar interface as SimpleLexer2, except we return an optional decoded
    string

    TODO: Combine

    match.J8Lexer
    match.J8StrLexer

    When you hit "" b"" u""

    1. Start the string lexer
    2. decode it in place
    3. validate utf-8 on the Id.Char_Literals tokens -- these are the only ones
       that can be arbitrary strings
    4. return decoded string
    """

    def __init__(self, s):
        # type: (str) -> None
        self.match_func = None  # type: SimpleMatchFunc
        self.s = s
        self.pos = 0

    def Next(self):
        # type: () -> Tuple[Id_t, int, Optional[str]]
        """
        Note: match_func will return Id.Eol_Tok repeatedly the terminating NUL
        """
        tok_id, end_pos = self.match_func(self.s, self.pos)
        self.pos = end_pos
        return tok_id, end_pos, None


def Decode(s, mode, buf):
    # type: (str, int, mylib.BufWriter) -> int
    """
    Should we call Parse() with 

        lex_mode_e.J8_Str
        lex_mode_e.JSON
    ?

    Callers:

    - json read
    - j8 read
    - Possibly the j"\yff" lexer, although that produces tokens first.

    The lexer for $'\x00' is different.

    1. Decode by backslash escapes \n etc.

    JSON mode: \\u1234 only
    J8 mode: \\yff and \\u{123456}

    Errors:
      Malformed escapes
    """
    return 0


def py_decode(s):
    # type: (str) -> str

    # TODO: Can use a regex as a demo
    # J8 strings are a regular language
    return s


# vim: sw=4
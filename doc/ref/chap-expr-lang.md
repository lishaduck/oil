---
all_docs_url: ..
body_css_class: width40 help-body
default_highlighter: oils-sh
preserve_anchor_case: yes
---

YSH Expression Language
===

This chapter in the [Oils Reference](index.html) describes the YSH expression
language, which includes [Egg Expressions]($xref:eggex).

<div id="toc">
</div>

## Assignment

### assign

The `=` operator is used with assignment keywords:

    var x = 42
    setvar x = 43

    const y = 'k'

    setglobal z = 'g'

### aug-assign

The augmented assignment operators are:

    +=   -=   *=   /=   **=   //=   %=
    &=   |=   ^=   <<=   >>=

They are used with `setvar` and `setglobal`.  For example:

    setvar x += 2

is the same as:

    setvar x = x + 2

Likewise, these are the same:

    setglobal a[i] -= 1

    setglobal a[i] = a[i] - 1

## Literals

### atom-literal

YSH uses JavaScript-like spellings for these three "atoms":

    null           # type Null
    true   false   # type Bool

Note: to signify "no value", you may sometimes use an empty string `''`,
instead of `null`.

### int-literal

Examples of integer literals:

    var decimal = 42
    var big = 42_000

    var hex = 0x0010_ffff

    var octal = 0o755

    var binary = 0b0001_0000

### float-lit

Examples of float literals:

    var myfloat = 3.14

    var f2 = -1.5e-100

### ysh-string

YSH has single and double-quoted strings borrowed from Bourne shell, and
C-style strings borrowed from J8 Notation.

Double quoted strings respect `$` interpolation:

    var dq = "hello $world and $(hostname)"

You can add a `$` before the left quote to be explicit: `$"x is $x"` rather
than `"x is $x"`.

Single quoted strings may be raw:

    var s = r'line\n'      # raw string means \n is literal, NOT a newline

Or *J8 strings* with backslash escapes:

    var s = u'line\n \u{3bc}'        # unicode string means \n is a newline
    var s = b'line\n \u{3bc} \yff'   # same thing, but also allows bytes

Both `u''` and `b''` strings evaluate to the single `Str` type.  The difference
is that `b''` strings allow the `\yff` byte escape.

#### Notes

There's no way to express a single quote in raw strings.  Use one of the other
forms instead:

    var sq = "single quote: ' "
    var sq = u'single quote: \' '

Sometimes you can omit the `r`, e.g. where there are no backslashes and thus no
ambiguity:

    echo 'foo'
    echo r'foo'  # same thing

The `u''` and `b''` strings are called *J8 strings* because the syntax in YSH
**code** matches JSON-like **data**.

    var strU = u'mu = \u{3bc}'  # J8 string with escapes
    var strB = b'bytes \yff'    # J8 string that can express byte strings

More examples:

    var myRaw = r'[a-z]\n'      # raw strings can be used for regexes (not
                                # eggexes)

### triple-quoted

Triple-quoted string literals have leading whitespace stripped on each line.
They come in the same variants:

    var dq = """
        hello $world and $(hostname)
        no leading whitespace
        """

    var myRaw = r'''
        raw string
        no leading whitespace
        '''

    var strU = u'''
        string that happens to be unicode \u{3bc}
        no leading whitespace
        '''

    var strB = b'''
        string that happens to be bytes \u{3bc} \yff
        no leading whitespace
        '''

Again, you can omit the `r` prefix if there's no backslash, because it's not
ambiguous:

    var myRaw = '''
        raw string
        no leading whitespace
        '''

### str-template

String templates use the same syntax as double-quoted strings:

    var mytemplate = ^"name = $name, age = $age"

Related topics:

- [Str => replace](chap-type-method.html#replace)
- [ysh-string](chap-expr-lang.html#ysh-string)

### list-literal

Lists have a Python-like syntax:

    var mylist = ['one', 'two', [42, 43]]

And a shell-like syntax:

    var list2 = :| one two |

The shell-like syntax accepts the same syntax as a simple command:

    ls $mystr @ARGV *.py {foo,bar}@example.com

    # Rather than executing ls, evaluate words into a List
    var cmd = :| ls $mystr @ARGV *.py {foo,bar}@example.com |

### dict-literal

Dicts look like JavaScript.

    var d = {
      key1: 'value',  # key can be unquoted if it looks like a var name
      'key2': 42,     # or quote it

      ['key2' ++ suffix]: 43,   # bracketed expression
    }

Omitting a value means that the corresponding key takes the value of a var of
the same name:

    ysh$ var x = 42
    ysh$ var y = 43

    ysh$ var d = {x, y}  # values omitted
    ysh$ = d
    (Dict)  {x: 42, y: 43}

### range

A range is a sequence of numbers that can be iterated over:

    for i in (0 .. 3) {
      echo $i
    }
    => 0
    => 1
    => 2

As with slices, the last number isn't included.  To iterate from 1 to n, you
can use this idiom:

    for i in (1 .. n+1) {
      echo $i
    }

### block-expr

In YSH expressions, we use `^()` to create a [Command][] object:

    var myblock = ^(echo $PWD; ls *.txt)

It's more common for [Command][] objects to be created with block arguments,
which are not expressions:

    cd /tmp {
      echo $PWD
      ls *.txt
    }

[Command]: chap-type-method.html#Command

### expr-literal

An expression literal is an object that holds an unevaluated expression:

    var myexpr = ^[1 + 2*3]

[Expr]: chap-type-method.html#Expr

## Operators

### op-precedence

YSH operator precedence is identical to Python's operator precedence.

New operators:

- `++` has the same precedence as `+`
- `->` and `=>` have the same precedence as `.`

<!-- TODO: show grammar -->


<h3 id="concat">concat <code>++</code></h3>

The concatenation operator works on `Str` objects:

    ysh$ var s = 'hello'
    ysh$ var t = s ++ ' world'

    ysh$ = t
    (Str)   "hello world"

and `List` objects:

    ysh$ var L = ['one', 'two']
    ysh$ var M = L ++ ['three', '4']

    ysh$ = M
    (List)   ["one", "two", "three", "4"]

String interpolation can be nicer than `++`:

    var t2 = "${s} world"  # same as t

Likewise, splicing lists can be nicer:

    var M2 = :| @L three 4 |  # same as M

### ysh-equals

YSH has strict equality:

    a === b       # Python-like, without type conversion
    a !== b       # negated

And type converting equality:

    '3' ~== 3     # True, type conversion

The `~==` operator expects a string as the left operand.

---

Note that:

- `3 === 3.0` is false because integers and floats are different types, and
  there is no type conversion.
- `3 ~== 3.0` is an error, because the left operand isn't a string.

You may want to use explicit `int()` and `float()` to convert numbers, and then
compare them.

---

Compare objects for identity with `is`:

    ysh$ var d = {}    
    ysh$ var e = d

    ysh$ = d is d
    (Bool)   true

    ysh$ = d is {other: 'dict'}
    (Bool)   false

To negate `is`, use `is not` (like Python:

    ysh$ d is not {other: 'dict'}
    (Bool)   true

### ysh-in

The `in` operator tests if a key is in a dictionary:

    var d = {k: 42}
    if ('k' in d) {
      echo yes
    }  # => yes

Unlike Python, `in` doesn't work on `Str` and `List` instances.  This because
those operations take linear time rather than constant time (O(n) rather than
O(1)).

TODO: Use `includes() / contains()` methods instead.

### ysh-compare

The comparison operators apply to integers or floats:

    4 < 4   # => false
    4 <= 4  # => true

    5.0 > 5.0   # => false
    5.0 >= 5.0  # => true

Example in context:

    if (x < 0) {
      echo 'x is negative'
    }

### ysh-logical

The logical operators take boolean operands, and are spelled like Python:

    not
    and  or

Note that they are distinct from `!  &&  ||`, which are part of the [command
language](chap-cmd-lang.html).

### ysh-arith

YSH supports most of the arithmetic operators from Python. Notably, `/` and `%`
differ from Python as [they round toward zero, not negative
infinity](https://www.oilshell.org/blog/2024/03/release-0.21.0.html#integers-dont-do-whatever-python-or-c-does).

Use `+ - *` for `Int` or `Float` addition, subtraction and multiplication. If
any of the operands are `Float`s, then the output will also be a `Float`.

Use `/` and `//` for `Float` division and `Int` division, respectively. `/`
will _always_ result in a `Float`, meanwhile `//` will _always_ result in an
`Int`.

    = 1 / 2   # => (Float) 0.5
    = 1 // 2  # => (Int) 0

Use `%` to compute the _remainder_ of integer division. The left operand must
be an `Int` and the right a _positive_ `Int`.

    = 1 % 2   # -> (Int) 1
    = -4 % 2  # -> (Int) 0

Use `**` for exponentiation. The left operand must be an `Int` and the right a
_positive_ `Int`.

All arithmetic operators may coerce either of their operands from strings to a
number, provided those strings are formatted as numbers.

    = 10 + '1'  # => (Int) 11

Operators like `+ - * /` will coerce strings to _either_ an `Int` or `Float`.
However, operators like `// ** %` and bit shifts will coerce strings _only_ to
an `Int`.

    = '1.14' + '2'  # => (Float) 3.14
    = '1.14' % '2'  # Type Error: Left operand is a Str

### ysh-bitwise

Bitwise operators are like Python and C:

    ~        # unary complement

    &  |  ^  # binary and, or, xor

    >>  <<   # bit shift

### ysh-ternary

The ternary operator is borrowed from Python:

    display = 'yes' if len(s) else 'empty'

### ysh-index

`Str` objects can be indexed by byte:

    ysh$ var s = 'cat'
    ysh$ = mystr[1]
    (Str)   'a'  

    ysh$ = mystr[-1]  # index from the end
    (Str)   't'

`List` objects:

    ysh$ var mylist = [1, 2, 3]
    ysh$ = mylist[2]
    (Int)  3

`Dict` objects are indexed by string key:

    ysh$ var mydict = {'key': 42}
    ysh$ = mydict['key']
    (Int)  42

### ysh-attr

The expression `mydict.key` is short for `mydict['key']`.

(Like JavaScript, but unlike Python.)

### ysh-slice

Slicing gives you a subsequence of a `Str` or `List`, like Python.

Negative indices are relative to the end.

### func-call

A function call expression looks like Python:

    ysh$ = f('s', 't', named=42)

A semicolon `;` can be used after positional args and before named args, but
isn't always required:

    ysh$ = f('s', 't'; named=42)

In these cases, the `;` is necessary:

    ysh$ = f(...args; ...kwargs)

    ysh$ = f(42, 43; ...kwargs)

### thin-arrow

The thin arrow is for mutating methods:

    var mylist = ['bar']
    call mylist->pop()

<!--
TODO
    var mydict = {name: 'foo'}
    call mydict->erase('name')
-->

### fat-arrow

The fat arrow is for transforming methods:

    if (s => startsWith('prefix')) {
      echo 'yes'
    }

If the method lookup on `s` fails, it looks for free functions.  This means it
can be used for "chaining" transformations:

    var x = myFunc() => list() => join()

### match-ops

YSH has four pattern matching operators: `~   !~   ~~   !~~`.

Does string match an **eggex**?

    var filename = 'x42.py'
    if (filename ~ / d+ /) {
      echo 'number'
    }

Does a string match a POSIX regular expression (ERE syntax)?

    if (filename ~ '[[:digit:]]+') {
      echo 'number'
    }

Negate the result with the `!~` operator:

    if (filename !~ /space/ ) {
      echo 'no space'
    }

    if (filename !~ '[[:space:]]' ) {
      echo 'no space'
    }

Does a string match a **glob**?

    if (filename ~~ '*.py') {
      echo 'Python'
    }

    if (filename !~~ '*.py') {
      echo 'not Python'
    }

Take care not to confuse glob patterns and regular expressions.

- Related doc: [YSH Regex API](../ysh-regex-api.html)

## Eggex

### re-literal

An eggex literal looks like this:

    / expression ; flags ; translation preference /

The flags and translation preference are both optional.

Examples:

    var pat = / d+ /  # => [[:digit:]]+

You can specify flags passed to libc `regcomp()`:

    var pat = / d+ ; reg_icase reg_newline / 

You can specify a translation preference after a second semi-colon:

    var pat = / d+ ; ; ERE / 

Right now the translation preference does nothing.  It could be used to
translate eggex to PCRE or Python syntax.

- Related doc: [Egg Expressions](../eggex.html)

### re-primitive

There are two kinds of eggex primitives.

"Zero-width assertions" match a position rather than a character:

    %start           # translates to ^
    %end             # translates to $

Literal characters appear within **single** quotes:

    'oh *really*'    # translates to regex-escaped string

Double-quoted strings are **not** eggex primitives.  Instead, you can use
splicing of strings:

    var dq = "hi $name"    
    var eggex = / @dq /

### class-literal

An eggex character class literal specifies a set.  It can have individual
characters and ranges:

    [ 'x' 'y' 'z' a-f A-F 0-9 ]  # 3 chars, 3 ranges

Omit quotes on ASCII characters:

    [ x y z ]  # avoid typing 'x' 'y' 'z'

Sets of characters can be written as strings

    [ 'xyz' ]  # any of 3 chars, not a sequence of 3 chars

Backslash escapes are respected:

    [ \\ \' \" \0 ]
    [ \xFF \u0100 ]

Splicing:

    [ @str_var ]

Negation always uses `!`

    ![ a-f A-F 'xyz' @str_var ]

### named-class

Perl-like shortcuts for sets of characters:

    [ dot ]    # => .
    [ digit ]  # => [[:digit:]]
    [ space ]  # => [[:space:]]
    [ word ]   # => [[:alpha:]][[:digit:]]_

Abbreviations:

    [ d s w ]  # Same as [ digit space word ]

Valid POSIX classes:

    alnum   cntrl   lower   space
    alpha   digit   print   upper
    blank   graph   punct   xdigit

Negated:

    !digit   !space   !word
    !d   !s   !w
    !alnum  # etc.

### re-repeat

Eggex repetition looks like POSIX syntax:

    / 'a'? /      # zero or one
    / 'a'* /      # zero or more
    / 'a'+ /      # one or more

Counted repetitions:

    / 'a'{3} /    # exactly 3 repetitions
    / 'a'{2,4} /  # between 2 to 4 repetitions

### re-compound

Sequence expressions with a space:

    / word digit digit /   # Matches 3 characters in sequence
                           # Examples: a42, b51

(Compare `/ [ word digit ] /`, which is a set matching 1 character.)

Alternation with `|`:

    / word | digit /       # Matches 'a' OR '9', for example

Grouping with parentheses:

    / (word digit) | \\ /  # Matches a9 or \

### re-capture

To retrieve a substring of a string that matches an Eggex, use a "capture
group" like `<capture ...>`.

Here's an eggex with a **positional** capture:

    var pat = / 'hi ' <capture d+> /  # access with _group(1)
                                      # or Match => _group(1)

Captures can be **named**:

    <capture d+ as month>       # access with _group('month')
                                # or Match => group('month')

Captures can also have a type **conversion func**:

    <capture d+ : int>          # _group(1) returns Int

    <capture d+ as month: int>  # _group('month') returns Int

Related docs and help topics:

- [YSH Regex API](../ysh-regex-api.html)
- [`_group()`](chap-builtin-func.html#_group)
- [`Match => group()`](chap-type-method.html#group)

### re-splice

To build an eggex out of smaller expressions, you can **splice** eggexes
together:

    var D = / [0-9][0-9] /
    var time = / @D ':' @D /  # [0-9][0-9]:[0-9][0-9]

If the variable begins with a capital letter, you can omit `@`:

    var ip = / D ':' D /

You can also splice a string:

    var greeting = 'hi'
    var pat = / @greeting ' world' /  # hi world

Splicing is **not** string concatenation; it works on eggex subtrees.

### re-flags

Valid ERE flags, which are passed to libc's `regcomp()`:

- `reg_icase` aka `i` - ignore case
- `reg_newline` - 4 matching changes related to newlines

See `man regcomp`.

### re-multiline

Multi-line eggexes aren't yet implemented.  Splicing makes it less necessary:

    var Name  = / <capture [a-z]+ as name> /
    var Num   = / <capture d+ as num> /
    var Space = / <capture s+ as space> /

    # For variables named like CapWords, splicing @Name doesn't require @
    var lexer = / Name | Num | Space /

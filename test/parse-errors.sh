#!/usr/bin/env bash
#
# Usage:
#   test/parse-errors.sh <function name>

set -o nounset
set -o pipefail
set -o errexit

source test/common.sh
source test/sh-assert.sh  # _assert-sh-status

# We can't really run with OSH=bash, because the exit status is often different

# Although it would be nice to IGNORE errors and them some how preview errors.

OSH=${OSH:-bin/osh}
YSH=${YSH:-bin/ysh}

# More detailed assertions - TODO: remove these?

_assert-status-2() {
  ### An interface where you can pass flags like -O test-parse_backslash

  local message=$0
  _assert-sh-status 2 $OSH $message "$@"
}

_assert-status-2-here() {
  _assert-status-2 "$@" -c "$(cat)"
}

_runtime-parse-error() {
  ### Assert that a parse error happens at runtime, e.g. for [ z z ]

  _osh-error-X 2 "$@"
}

#
# Cases
#

# All in osh/word_parse.py
test-patsub() {
  _osh-should-parse 'echo ${x/}'
  _osh-should-parse 'echo ${x//}'

  _osh-should-parse 'echo ${x/foo}'  # pat 'foo', no mode, replace empty

  _osh-should-parse 'echo ${x//foo}'  # pat 'foo', replace mode '/', replace empty
  _osh-should-parse 'echo ${x/%foo}'  # same as above

  _osh-should-parse 'echo ${x///foo}'

  _osh-should-parse 'echo ${x///}'   # found and fixed bug
  _osh-should-parse 'echo ${x/%/}'   # pat '', replace mode '%', replace ''

  _osh-should-parse 'echo ${x////}'  # pat '/', replace mode '/', replace empty
  _osh-should-parse 'echo ${x/%//}'  # pat '', replace mode '%', replace '/'

  # Newline in replacement pattern
  _osh-should-parse 'echo ${x//foo/replace
}'
  _osh-should-parse 'echo ${x//foo/replace$foo}'
}

# osh/word_parse.py
test-word-parse() {
  _osh-parse-error 'echo ${'

  # This parses like a slice, but that's OK.  Maybe talk about arithmetic
  # expression.  Maybe say where it started?
  _osh-parse-error '${foo:}'

  _osh-parse-error 'echo ${a[@Z'

  _osh-parse-error 'echo ${x.}'
  _osh-parse-error 'echo ${!x.}'

  # Slicing
  _osh-parse-error 'echo ${a:1;}'
  _osh-parse-error 'echo ${a:1:2;}'

  # I don't seem to be able to tickle errors here
  #_osh-parse-error 'echo ${a:-}'
  #_osh-parse-error 'echo ${a#}'

  _osh-parse-error 'echo ${#a.'

  # for (( ))
  _osh-parse-error 'for (( i = 0; i < 10; i++ ;'
  # Hm not sure about this
  _osh-parse-error 'for (( i = 0; i < 10; i++ /'

  _osh-parse-error 'echo @(extglob|foo'

  # Copied from osh/word_parse_test.py.  Bugs were found while writing
  # core/completion_test.py.

  _osh-parse-error '${undef:-'
  _osh-parse-error '${undef:-$'
  _osh-parse-error '${undef:-$F'

  _osh-parse-error '${x@'
  _osh-parse-error '${x@Q'

  _osh-parse-error '${x%'

  _osh-parse-error '${x/'
  _osh-parse-error '${x/a/'
  _osh-parse-error '${x/a/b'
  _osh-parse-error '${x:'
}

test-array-literal() {
  # Array literal with invalid TokenWord.
  _osh-parse-error 'a=(1 & 2)'
  _osh-parse-error 'a= (1 2)'
  _osh-parse-error 'a=(1 2'
  _osh-parse-error 'a=(1 ${2@} )'  # error in word inside array literal
}

test-arith-context() {
  # $(( ))
  _osh-parse-error 'echo $(( 1 + 2 ;'
  _osh-parse-error 'echo $(( 1 + 2 );'
  _osh-parse-error 'echo $(( '
  _osh-parse-error 'echo $(( 1'

  # Disable Oil stuff for osh_{parse,eval}.asan
  if false; then
    # Non-standard arith sub $[1 + 2]
    _osh-parse-error 'echo $[ 1 + 2 ;'

    # What's going on here?   No location info?
    _osh-parse-error 'echo $[ 1 + 2 /'

    _osh-parse-error 'echo $[ 1 + 2 / 3'
    _osh-parse-error 'echo $['
  fi

  # (( ))
  _osh-parse-error '(( 1 + 2 /'
  _osh-parse-error '(( 1 + 2 )/'
  _osh-parse-error '(( 1'
  _osh-parse-error '(('

  # Should be an error
  _osh-parse-error 'a[x+]=1'

  _osh-parse-error 'a[]=1'

  _osh-parse-error 'a[*]=1'

  # These errors are different because the arithmetic lexer mode has } but not
  # {.  May be changed later.
  _osh-parse-error '(( a + { ))'
  _osh-parse-error '(( a + } ))'

}

test-arith-integration() {
  # Regression: these were not parse errors, but should be!
  _osh-parse-error 'echo $((a b))'
  _osh-parse-error '((a b))'

  # Empty arithmetic expressions
  _osh-should-parse 'for ((x=0; x<5; x++)); do echo $x; done'
  _osh-should-parse 'for ((; x<5; x++)); do echo $x; done'
  _osh-should-parse 'for ((; ; x++)); do echo $x; done'
  _osh-should-parse 'for ((; ;)); do echo $x; done'

  # Extra tokens on the end of each expression
  _osh-parse-error 'for ((x=0; x<5; x++ b)); do echo $x; done'

  _osh-parse-error 'for ((x=0 b; x<5; x++)); do echo $x; done'
  _osh-parse-error 'for ((x=0; x<5 b; x++)); do echo $x; done'

  _osh-parse-error '${a:1+2 b}'
  _osh-parse-error '${a:1+2:3+4 b}'

  _osh-parse-error '${a[1+2 b]}'
}

test-arith-expr() {
  # BUG: the token is off here
  _osh-parse-error '$(( 1 + + ))'

  # BUG: not a great error either
  _osh-parse-error '$(( 1 2 ))'

  # Triggered a crash!
  _osh-parse-error '$(( - ; ))'

  # NOTE: This is confusing, should point to ` for command context?
  _osh-parse-error '$(( ` ))'

  _osh-parse-error '$(( $ ))'

  # Invalid assignments
  _osh-parse-error '$(( x+1 = 42 ))'
  _osh-parse-error '$(( (x+42)++ ))'
  _osh-parse-error '$(( ++(x+42) ))'

  # Note these aren't caught because '1' is an ArithWord like 0x$x
  #_osh-parse-error '$(( 1 = foo ))'
  #_osh-parse-error '$(( 1++ ))'
  #_osh-parse-error '$(( ++1 ))'
}

test-command-sub() {
  _osh-parse-error ' 
    echo line 2
    echo $( echo '
  _osh-parse-error ' 
    echo line 2
    echo ` echo '

  # This is source.Reparsed('backticks', ...)

  # Both unclosed
  _osh-parse-error '
    echo line 2
    echo ` echo \` '

  # Only the inner one is unclosed
  _osh-parse-error '
    echo line 2
    echo ` echo \`unclosed ` '

  _osh-parse-error 'echo `for x in`'
}

test-bool-expr() {
  # Extra word
  _osh-parse-error '[[ a b ]]'
  _osh-parse-error '[[ a "a"$(echo hi)"b" ]]'

  # Wrong error message
  _osh-parse-error '[[ a == ]]'

  if false; then
    # Invalid regex
    # These are currently only detected at runtime.
    _osh-parse-error '[[ $var =~ * ]]'
    _osh-parse-error '[[ $var =~ + ]]'
  fi

  # Unbalanced parens
  _osh-parse-error '[[ ( 1 == 2 - ]]'

  _osh-parse-error '[[ == ]]'
  _osh-parse-error '[[ ) ]]'
  _osh-parse-error '[[ ( ]]'

  _osh-parse-error '[[ ;;; ]]'
  _osh-parse-error '[['

  # Expected right )
  _osh-parse-error '[[ ( a == b foo${var} ]]'
}

# These don't have any location information.
test-test-builtin() {
  # Some of these come from osh/bool_parse.py, and some from
  # osh/builtin_bracket.py.

  # Extra token
  _runtime-parse-error '[ x -a y f ]'
  _runtime-parse-error 'test x -a y f'

  # Missing closing ]
  _runtime-parse-error '[ x '

  # Hm some of these errors are wonky.  Need positions.
  _runtime-parse-error '[ x x ]'

  _runtime-parse-error '[ x x "a b" ]'

  # This is a runtime error but is handled similarly
  _runtime-parse-error '[ -t xxx ]'

  _runtime-parse-error '[ \( x -a -y -a z ]'

  # -o tests if an option is enabled.
  #_osh-parse-error '[ -o x ]'
}

test-printf-builtin() {
  _runtime-parse-error 'printf %'
  _runtime-parse-error 'printf [%Z]'

  _runtime-parse-error 'printf -v "-invalid-" %s foo'
}

test-other-builtins() {
  _runtime-parse-error 'shift 1 2'
  _runtime-parse-error 'shift zzz'

  _runtime-parse-error 'pushd x y'
  _runtime-parse-error 'pwd -x'

  _runtime-parse-error 'pp x foo a-x'

  _runtime-parse-error 'wait zzz'
  _runtime-parse-error 'wait %jobspec-not-supported'

  _runtime-parse-error 'unset invalid-var-name'
  _runtime-parse-error 'getopts 'hc:' invalid-var-name'
}

test-quoted-strings() {
  _osh-parse-error '"unterminated double'

  _osh-parse-error "'unterminated single"

  _osh-parse-error '
  "unterminated double multiline
  line 1
  line 2'

  _osh-parse-error "
  'unterminated single multiline
  line 1
  line 2"
}

test-braced-var-sub() {
  # These should have ! for a prefix query
  _osh-parse-error 'echo ${x*}'
  _osh-parse-error 'echo ${x@}'

  _osh-parse-error 'echo ${x.}'
}

test-cmd-parse() {
  _osh-parse-error 'FOO=1 break'
  _osh-parse-error 'break 1 2'

  _osh-parse-error 'x"y"() { echo hi; }'

  _osh-parse-error 'function x"y" { echo hi; }'

  _osh-parse-error '}'

  _osh-parse-error 'case foo in *) echo '
  _osh-parse-error 'case foo in x|) echo '

  _osh-parse-error 'ls foo|'
  _osh-parse-error 'ls foo&&'

  _osh-parse-error 'foo()'

  # parse_ignored
  _osh-should-parse 'break >out'
  _ysh-parse-error 'break >out'

  # Unquoted (
  _osh-parse-error '[ ( x ]'
}

test-append() {
  # from spec/test-append.test.sh.  bash treats this as a runtime error, but it's a
  # parse error in OSH.
  _osh-parse-error 'a[-1]+=(4 5)'
}

test-redirect() {
  _osh-parse-error 'echo < <<'
  _osh-parse-error 'echo $( echo > >>  )'
}

test-simple-command() {
  _osh-parse-error 'PYTHONPATH=. FOO=(1 2) python'
  # not statically detected after dynamic assignment
  #_osh-parse-error 'echo foo FOO=(1 2)'

  _osh-parse-error 'PYTHONPATH+=1 python'

  # Space sensitivity: disallow =
  _osh-parse-error '=var'
  _osh-parse-error '=f(x)'

  _ysh-parse-error '=var'
  _ysh-parse-error '=f(x)'
}

# Old code?  All these pass
DISABLED-assign() {
  _osh-parse-error 'local name$x'
  _osh-parse-error 'local "ab"'
  _osh-parse-error 'local a.b'

  _osh-parse-error 'FOO=1 local foo=1'
}

# I can't think of any other here doc error conditions except arith/var/command
# substitution, and unterminated.
test-here-doc() {
  # Arith in here doc
  _osh-parse-error 'cat <<EOF
$(( 1 * ))  
EOF
'

  # Varsub in here doc
  _osh-parse-error 'cat <<EOF
invalid: ${a!}
EOF
'

  _osh-parse-error 'cat <<EOF
$(for x in )
EOF
'
}

test-here-doc-delimiter() {
  # NOTE: This is more like the case where.
  _osh-parse-error 'cat << $(invalid here end)'

  # TODO: Arith parser doesn't have location information
  _osh-parse-error 'cat << $((1+2))'
  _osh-parse-error 'cat << a=(1 2 3)'
  _osh-parse-error 'cat << \a$(invalid)'

  # Actually the $invalid part should be highlighted... yeah an individual
  # part is the problem.
  #"cat << 'single'$(invalid)"
  _osh-parse-error 'cat << "double"$(invalid)'
  _osh-parse-error 'cat << ~foo/$(invalid)'
  _osh-parse-error 'cat << $var/$(invalid)'
}

test-args-parse-builtin() {
  _runtime-parse-error 'read -x'  # invalid
  _runtime-parse-error 'builtin read -x'  # ditto

  _runtime-parse-error 'read -n'  # expected argument for -n
  _runtime-parse-error 'read -n x'  # expected integer

  _runtime-parse-error 'set -o errexit +o oops'

  # not implemented yet
  #_osh-parse-error 'read -t x'  # expected floating point number

  # TODO:
  # - invalid choice
  # - Oil flags: invalid long flag, boolean argument, etc.
}

test-args-parse-more() {
  _runtime-parse-error 'set -z'
  _runtime-parse-error 'shopt -s foo'
  _runtime-parse-error 'shopt -z'
}

DISABLED-args-parse-main() {
  $OSH --ast-format x

  $OSH -o errexit +o oops
}

test-invalid-brace-ranges() {
  _osh-parse-error 'echo {1..3..-1}'
  _osh-parse-error 'echo {1..3..0}'
  _osh-parse-error 'echo {3..1..1}'
  _osh-parse-error 'echo {3..1..0}'
  _osh-parse-error 'echo {a..Z}'
  _osh-parse-error 'echo {a..z..0}'
  _osh-parse-error 'echo {a..z..-1}'
  _osh-parse-error 'echo {z..a..1}'
}

test-extra-newlines() {
  _osh-parse-error '
  for
  do
  done
  '

  _osh-parse-error '
  case
  in esac
  '

  _osh-parse-error '
  while
  do
  done
  '

  _osh-parse-error '
  if
  then
  fi
  '

  _osh-parse-error '
  if true
  then
  elif
  then
  fi
  '

  _osh-parse-error '
  case |
  in
  esac
  '

  _osh-parse-error '
  case ;
  in
  esac
  '

  _osh-should-parse '
  if
  true
  then
  fi
  '

  _osh-should-parse '
  while
  false
  do
  done
  '

  _osh-should-parse '
  while
  true;
  false
  do
  done
  '

  _osh-should-parse '
  if true
  then
  fi
  '

  _osh-should-parse '
  while true;
        false
  do
  done
  '
}

test-ysh_c_strings() {
  # bash syntax
  _osh-should-parse-here <<'EOF'
echo $'\u03bc'
EOF

  # Extension not allowed
  _ysh-parse-error-here <<'EOF'
echo $'\u{03bc}'
EOF

  # Bad syntax
  _ysh-parse-error-here <<'EOF'
echo $'\u{03bc'
EOF

  # Expression mode
  _ysh-parse-error-here <<'EOF'
const bad = $'\u{03bc'
EOF

  # Test single quoted
  _osh-should-parse-here <<'EOF'
echo $'\z'
EOF
  _ysh-parse-error-here <<'EOF'
echo $'\z'
EOF
  # Expression mode
  _ysh-parse-error-here <<'EOF'
const bad = $'\z'
EOF

  # Octal not allowed
  _osh-should-parse-here <<'EOF'
echo $'\101'
EOF
  _ysh-parse-error-here <<'EOF'
const bad = $'\101'
EOF

  # \xH not allowed
  _ysh-parse-error-here <<'EOF'
const bad = c'\xf'
EOF
}

test-bug_1825_backslashes() {
  # Single backslash is accepted in OSH
  _osh-should-parse-here <<'EOF'
echo $'trailing\
'
EOF

  # Double backslash is right in YSH
  _ysh-should-parse-here <<'EOF'
echo $'trailing\\
'
EOF

  # Single backslash is wrong in YSH
  _ysh-parse-error-here <<'EOF'
echo $'trailing\
'
EOF

  # Also in expression mode
  _ysh-parse-error-here <<'EOF'
setvar x = $'trailing\
'
EOF
}

test-ysh_dq_strings() {
  # Double quoted is an error
  _osh-should-parse 'echo "\z"'
  _assert-status-2 +O parse_backslash -n -c 'echo test-parse_backslash "\z"'

  _ysh-parse-error 'echo "\z"'  # not in Oil
  _ysh-parse-error 'const bad = "\z"'  # not in expression mode

  # C style escapes not respected
  _osh-should-parse 'echo "\u1234"'  # ok in OSH
  _ysh-parse-error 'echo "\u1234"'  # not in Oil
  _ysh-parse-error 'const bad = "\u1234"'

  _osh-should-parse 'echo "`echo hi`"'
  _ysh-parse-error 'echo "`echo hi`"'
  _ysh-parse-error 'const bad = "`echo hi`"'

  _ysh-parse-error 'setvar x = "\z"'
}

test-ysh_bare_words() {
  _ysh-should-parse 'echo \$'
  _ysh-parse-error 'echo \z'
}

test-parse_backticks() {

  # These are allowed
  _osh-should-parse 'echo `echo hi`'
  _osh-should-parse 'echo "foo = `echo hi`"'

  _assert-status-2 +O test-parse_backticks -n -c 'echo `echo hi`'
  _assert-status-2 +O test-parse_backticks -n -c 'echo "foo = `echo hi`"'
}

test-parse_dollar() {

  # The right way:
  #   echo \$
  #   echo \$:

  CASES=(
    'echo $'          # lex_mode_e.ShCommand
    'echo $:'

    'echo "$"'        # lex_mode_e.DQ
    'echo "$:"'

    'echo ${x:-$}'    # lex_mode_e.VSub_ArgUnquoted
    'echo ${x:-$:}'

    'echo "${x:-$}"'  # lex_mode_e.VSub_DQ
    'echo "${x:-$:}"'
  )
  for c in "${CASES[@]}"; do
    _osh-should-parse "$c"
    _assert-status-2 +O test-parse_dollar -n -c "$c"
    _ysh-parse-error "$c"
  done
}

test-parse_dparen() {

  # Bash (( construct
  local bad

  bad='((1 > 0 && 43 > 42))'
  _osh-should-parse "$bad"
  _ysh-parse-error "$bad"

  bad='if ((1 > 0 && 43 > 42)); then echo yes; fi'
  _osh-should-parse "$bad"
  _ysh-parse-error "$bad"

  bad='for ((x = 1; x < 5; ++x)); do echo $x; done'
  _osh-should-parse "$bad"
  _ysh-parse-error "$bad"

  _ysh-should-parse 'if (1 > 0 and 43 > 42) { echo yes }'

  # Accepted workaround: add space
  _ysh-should-parse 'if ( (1 > 0 and 43 > 42) ) { echo yes }'
}

test-invalid_parens() {

  # removed function sub syntax
  local s='write -- $f(x)'
  _osh-parse-error "$s"
  _ysh-parse-error "$s"

  # requires test-parse_at
  local s='write -- @[sorted(x)]'
  _osh-parse-error "$s"  # this is a parse error, but BAD message!
  _ysh-should-parse "$s"

  local s='
f() {
  write -- @[sorted(x)]
}
'
  _osh-parse-error "$s"
  _ysh-should-parse "$s"

  # Analogous bad bug
  local s='
f() {
  write -- @sorted (( z ))
}
'
  _osh-parse-error "$s"
}

test-shell_for() {

  _osh-parse-error 'for x in &'

  _osh-parse-error 'for (( i=0; i<10; i++ )) ls'

  # ( is invalid
  _osh-parse-error 'for ( i=0; i<10; i++ )'

  _osh-parse-error 'for $x in 1 2 3; do echo $i; done'
  _osh-parse-error 'for x.y in 1 2 3; do echo $i; done'
  _osh-parse-error 'for x in 1 2 3; &'
  _osh-parse-error 'for foo BAD'

  # BUG fix: var is a valid name
  _osh-should-parse 'for var in x; do echo $var; done'
}

#
# Different source_t variants
#

test-nested_source_argvword() {
  # source.ArgvWord
  _runtime-parse-error '
  code="printf % x"
  eval $code
  '
}

test-eval_parse_error() {
  _runtime-parse-error '
  x="echo )"
  eval $x
  '
}

trap_parse_error() {
  _runtime-parse-error '
  trap "echo )" EXIT
  '
}

test-proc_func_reserved() {
  ### Prevents confusion

  _osh-parse-error 'proc p (x) { echo hi }'
  _osh-parse-error 'func f (x) { return (x) }'
}

# Cases in their own file
cases-in-files() {
  for test_file in test/parse-errors/*.sh; do
    case-banner "FILE $test_file"

    set +o errexit
    $OSH $test_file
    local status=$?
    set -o errexit

    if test -z "${SH_ASSERT_DISABLE:-}"; then
      if test $status != 2; then
        die "Expected status 2 from parse error file, got $status"
      fi
    fi
  done
}

all() {
  section-banner 'Cases in Files'

  cases-in-files

  section-banner 'Cases in Functions, with strings'

  run-test-funcs
}

# TODO: Something like test/parse-err-compare.sh

all-with-bash() {
  # override OSH and YSH
  SH_ASSERT_DISABLE=1 OSH=bash YSH=bash all
}

all-with-dash() {
  # override OSH and YSH
  SH_ASSERT_DISABLE=1 OSH=dash YSH=dash all
}

soil-run-py() {
  ### Run in CI with Python
  
  # output _tmp/other/parse-errors.txt

  all
}

soil-run-cpp() {
  ### Run with oils-for-unix

  ninja _bin/cxx-asan/osh
  OSH=_bin/cxx-asan/osh all
}

release-oils-for-unix() {
  readonly OIL_VERSION=$(head -n 1 oil-version.txt)
  local dir="../benchmark-data/src/oils-for-unix-$OIL_VERSION"

  # Maybe rebuild it
  pushd $dir
  _build/oils.sh '' '' SKIP_REBUILD
  popd

  local suite_name=parse-errors-osh-cpp
  OSH=$dir/_bin/cxx-opt-sh/osh \
    run-other-suite-for-release $suite_name all
}

run-for-release() {
  ### Test with bin/osh and the ASAN binary.

  run-other-suite-for-release parse-errors all

  release-oils-for-unix
}

"$@"

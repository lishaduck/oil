---
in_progress: yes
all_docs_url: ..
body_css_class: width40 help-body
default_highlighter: oils-sh
preserve_anchor_case: yes
---

OSH Assignment
===

This chapter in the [Oils Reference](index.html) describes OSH assignment.

<div id="toc">
</div>

## Operators

### sh-assign

### sh-append

## Compound Data

### sh-array

Array literals in shell accept any sequence of words, just like a command does:

    ls $mystr "$@" *.py

    # Put it in an array
    a=(ls $mystr "$@" *.py)

Their type is [BashArray][].

In YSH, use a [list-literal][] to create a [List][] instance.

[BashArray]: chap-type-method.html#BashArray

[List]: chap-type-method.html#List
[list-literal]: chap-expr-lang.html#list-literal


### sh-assoc

Associative arrays map strings to strings:

    declare -A assoc=(['k']=v ['k2']=v2)

Their type is [BashAssoc][].

In YSH, use a [dict-literal][] to create a [Dict][] instance.

[BashAssoc]: chap-type-method.html#BashAssoc

[Dict]: chap-type-method.html#Dict
[dict-literal]: chap-expr-lang.html#dict-literal

## Builtins

### local

### readonly

### export

### unset

### shift

### declare

### typeset

Another name for the [declare](#declare) builtin.

"""
cpp/NINJA_subgraph.py
"""

from __future__ import print_function

from build import ninja_lib
from build.ninja_lib import log

# Some tests use #ifndef CPP_UNIT_TEST to disable circular dependencies on
# generated code
CPP_UNIT_MATRIX = [
    ('cxx', 'dbg', '-D CPP_UNIT_TEST'),
    ('cxx', 'asan', '-D CPP_UNIT_TEST'),
    ('cxx', 'ubsan', '-D CPP_UNIT_TEST'),
    #('cxx', 'gcalways', '-D CPP_UNIT_TEST'),
    ('clang', 'coverage', '-D CPP_UNIT_TEST'),
]


def NinjaGraph(ru):
    n = ru.n

    ru.comment('Generated by %s' % __name__)

    ru.py_binary('cpp/embedded_file_gen.py')

    # Written by build/py.sh
    git_commit = '_build/git-commit.txt'

    n.rule('build-stamp-cpp',
           command='build/stamp.sh gen-cpp $in $out',
           description='build-stamp-cpp $in $out')

    stamp_prefix = '_gen/cpp/build_stamp'
    n.build([stamp_prefix + '.h', stamp_prefix + '.cc'],
            'build-stamp-cpp',
            git_commit,
            implicit=['build/stamp.sh'])
    n.newline()

    ru.cc_library('//cpp/build_stamp',
                  srcs=[stamp_prefix + '.cc'],
                  generated_headers=[stamp_prefix + '.h'])

    ru.cc_binary(
        'cpp/obj_layout_test.cc',
        deps=[
            '//core/runtime.asdl',
            '//mycpp/runtime',
        ],
        # Add tcmalloc for malloc_address_test
        matrix=ninja_lib.COMPILERS_VARIANTS + [('cxx', 'tcmalloc')])

    ru.cc_binary('cpp/unicode_test.cc',
                 deps=['//mycpp/runtime'],
                 matrix=ninja_lib.COMPILERS_VARIANTS)

    ru.cc_library(
        '//cpp/core',
        srcs=['cpp/core.cc'],
        deps=[
            '//cpp/build_stamp',
            '//frontend/consts',  # for gVersion
            '//frontend/syntax.asdl',
            '//mycpp/runtime',
            '//ysh/grammar',
        ],
    )

    ru.cc_binary('cpp/core_test.cc',
                 deps=[
                     '//cpp/core',
                     '//cpp/stdlib',
                 ],
                 matrix=ninja_lib.COMPILERS_VARIANTS)

    ru.cc_binary('cpp/data_race_test.cc',
                 deps=[
                     '//cpp/core',
                 ],
                 matrix=ninja_lib.SMALL_TEST_MATRIX + [
                     ('cxx', 'tsan'),
                     ('clang', 'tsan'),
                 ])

    ru.cc_library(
        '//cpp/data_lang',
        srcs=[
            'cpp/data_lang.cc',
        ],
        deps=[
            '//core/value.asdl',
            '//data_lang/j8',
            '//mycpp/runtime',
        ],
    )

    ru.cc_binary('cpp/data_lang_test.cc',
                 deps=[
                     '//cpp/data_lang',
                     '//data_lang/j8_libc',
                     '//data_lang/j8_test_lib',
                 ],
                 matrix=ninja_lib.COMPILERS_VARIANTS)

    # Note: depends on code generated by re2c
    ru.cc_library(
        '//cpp/frontend_match',
        srcs=[
            'cpp/frontend_match.cc',
        ],
        deps=[
            '//frontend/syntax.asdl',
            '//frontend/types.asdl',
            '//mycpp/runtime',
        ],
    )

    ru.cc_library(
        '//cpp/frontend_pyreadline',
        srcs=[
            'cpp/frontend_pyreadline.cc',
        ],
        deps=[
            '//cpp/core',
            '//mycpp/runtime',
        ],
    )

    ru.cc_binary('cpp/frontend_match_test.cc',
                 deps=['//cpp/frontend_match'],
                 matrix=ninja_lib.COMPILERS_VARIANTS)

    ru.cc_library(
        '//cpp/frontend_flag_spec',
        srcs=[
            'cpp/frontend_flag_spec.cc',
        ],
        deps=[
            # Dependencies of //prebuilt/frontend/args.mycpp
            '//core/runtime.asdl',
            '//core/value.asdl',
            '//frontend/syntax.asdl',
            '//frontend/arg_types',  # generated code
            '//mycpp/runtime',
        ],
    )

    ru.cc_binary(
        'cpp/frontend_flag_spec_test.cc',
        deps=[
            '//cpp/frontend_flag_spec',
            '//prebuilt/frontend/args.mycpp',  # prebuilt args::Reader, etc.
        ],
        # special -D CPP_UNIT_TEST
        #matrix = CPP_UNIT_MATRIX)
        matrix=ninja_lib.COMPILERS_VARIANTS)

    ru.cc_library('//cpp/fanos_shared', srcs=['cpp/fanos_shared.c'])

    ru.cc_library('//cpp/fanos',
                  srcs=['cpp/fanos.cc'],
                  deps=['//cpp/fanos_shared', '//mycpp/runtime'])

    ru.cc_library('//cpp/libc', srcs=['cpp/libc.cc'], deps=['//mycpp/runtime'])

    ru.cc_binary('cpp/libc_test.cc',
                 deps=['//cpp/libc'],
                 matrix=ninja_lib.COMPILERS_VARIANTS)

    ru.cc_library('//cpp/osh',
                  srcs=[
                      'cpp/osh.cc',
                      'cpp/osh_tdop.cc',
                  ],
                  deps=[
                      '//frontend/syntax.asdl',
                      '//cpp/core',
                      '//mycpp/runtime',
                  ])

    ru.cc_binary(
        'cpp/osh_test.cc',
        deps=[
            '//cpp/osh',
            '//prebuilt/core/error.mycpp',  # prebuilt e_die()
        ],
        matrix=ninja_lib.COMPILERS_VARIANTS)

    ru.cc_library('//cpp/pgen2',
                  srcs=['cpp/pgen2.cc'],
                  deps=[
                      '//mycpp/runtime',
                      '//frontend/syntax.asdl',
                  ])

    ru.cc_library('//cpp/pylib',
                  srcs=['cpp/pylib.cc'],
                  deps=['//mycpp/runtime'])

    ru.cc_binary('cpp/pylib_test.cc',
                 deps=['//cpp/pylib'],
                 matrix=ninja_lib.COMPILERS_VARIANTS)

    ru.cc_library(
        '//cpp/stdlib',
        srcs=['cpp/stdlib.cc'],
        deps=[
            '//mycpp/runtime',
            # Annoying: because of the circular dep issue, we need to repeat
            # dependencies of //prebuilt/core/error.mycpp.  We don't want to depend
            # on it directly because we'd get duplicate symbols during linking.
            '//frontend/syntax.asdl',
        ])

    ru.cc_binary(
        'cpp/stdlib_test.cc',
        deps=[
            '//cpp/stdlib',
            '//prebuilt/core/error.mycpp',  # prebuilt e_die()
        ],
        matrix=ninja_lib.COMPILERS_VARIANTS)

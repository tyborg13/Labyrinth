"""Opt-in wall-clock benchmarks; direct unittest discovery skips them too."""
import os
import unittest

PERF_ENV = 'LABYRINTH_PYTHON_SUITE_GROUP'
PERF_REASON = 'performance group; run python3 tools/run_python_suite.py --perf on a quiet machine'


def perf_test(method):
    method.__python_suite_group__ = 'perf'
    return unittest.skipUnless(os.environ.get(PERF_ENV) == 'perf', PERF_REASON)(method)


def test_group(test):
    method = getattr(test, getattr(test, '_testMethodName', ''), None)
    return getattr(method, '__python_suite_group__', 'behavior')

#!/bin/sh
# Run all tests: tests/test-*.sh. Exit status 1 if a test failed.
# The tests run in temporary directories and do not touch ~/.claude.
cd "$(dirname "$0")" || exit 1
failed=0
for t in test-*.sh; do
  sh "$t" || failed=1
done
if [ $failed -eq 0 ]; then
  echo "All tests passed."
else
  echo "Some tests failed."
fi
exit $failed

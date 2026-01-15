#!/bin/bash
# Verify test suite installation

echo "🔍 Verifying Photo HQ Test Suite Installation..."
echo ""

ERRORS=0

# Check files exist
echo "📁 Checking files..."
FILES=(
    "setup_test_env.sh"
    "run_comprehensive_tests.sh"
    ".env.template"
    "tests/comprehensive_api_test.py"
    "tests/requirements.txt"
    "TESTING.md"
    "QUICK_START_TESTING.md"
    "TEST_SUITE_SUMMARY.md"
)

for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✓ $file"
    else
        echo "  ✗ $file (missing)"
        ERRORS=$((ERRORS + 1))
    fi
done

echo ""
echo "🔐 Checking permissions..."
EXEC_FILES=(
    "setup_test_env.sh"
    "run_comprehensive_tests.sh"
    "tests/comprehensive_api_test.py"
)

for file in "${EXEC_FILES[@]}"; do
    if [ -x "$file" ]; then
        echo "  ✓ $file (executable)"
    else
        echo "  ⚠ $file (not executable, fixing...)"
        chmod +x "$file"
    fi
done

echo ""
echo "🐍 Checking Python syntax..."
if python3 -m py_compile tests/comprehensive_api_test.py 2>/dev/null; then
    echo "  ✓ tests/comprehensive_api_test.py (valid syntax)"
else
    echo "  ✗ tests/comprehensive_api_test.py (syntax error)"
    ERRORS=$((ERRORS + 1))
fi

echo ""
echo "📊 File sizes..."
ls -lh setup_test_env.sh run_comprehensive_tests.sh tests/comprehensive_api_test.py | awk '{print "  "$9, "("$5")"}'

echo ""
if [ $ERRORS -eq 0 ]; then
    echo "✅ Test suite installation verified successfully!"
    echo ""
    echo "🚀 Ready to use! Run:"
    echo "   ./setup_test_env.sh && ./run_comprehensive_tests.sh"
else
    echo "❌ Found $ERRORS error(s). Please check the installation."
fi

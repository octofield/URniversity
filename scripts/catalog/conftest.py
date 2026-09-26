# Lets the tests in tests/ import common and schools the way the script does
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

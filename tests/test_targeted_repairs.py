"""Static regression checks; real CMD and registry tests require Windows."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BATCH = (ROOT / 'cleanup_advanced.bat').read_text()
PS = (ROOT / 'fix_exe.ps1').read_text()
EXE_BATCH = (ROOT / 'fix_exe.bat').read_text()


def section(label):
    found = re.search(rf'(?im)^:{re.escape(label)}\s*\n(.*?)(?=^:[\w-]+\s*$|\Z)', BATCH, re.S)
    if not found:
        raise AssertionError(label)
    return found.group(1)


class TargetedRepairTests(unittest.TestCase):
    def test_profile_is_normalized_before_comparison(self):
        profile = BATCH[BATCH.index('set "PROFILE_MISMATCH="'):BATCH.index(':: ---------- 3f.')]
        prefix = profile.index('set "ORIG_USER=%ORIG_USER:~6%"')
        compare = profile.index('if defined ORIG_USER if /i not "%ORIG_USER%"=="%USERNAME%"')
        self.assertLess(prefix, compare)
        self.assertEqual(BATCH.count("[char]34 + '-orig=%USERNAME%' + [char]34"), 2)

    def test_store_and_time_failure_codes_are_returned(self):
        for label, variable in [('t_storereset', 'WS_RC'), ('t_time', 'TIME_RC')]:
            text = section(label)
            self.assertRegex(text, rf'if not "%{variable}%"=="0" \([\s\S]*?exit /b %{variable}%')
        self.assertIn('verify the Store', section('t_storereset'))

    def test_diagnostic_color_resets(self):
        self.assertNotIn('^C_RESET%', BATCH)
        self.assertIn('Bug check events, last 30 days:%C_RESET%', section('FIX_CRASH'))
        self.assertIn('Top 10 processes by CPU time:%C_RESET%', section('FIX_PROCS'))

    def test_exe_powershell_does_not_depend_on_hkcr_drive(self):
        repair = PS[PS.index('# Registry changes'):PS.index('Write-Host "[3/5]')]
        self.assertIn('Registry::HKEY_CLASSES_ROOT', repair)
        self.assertNotRegex(repair, r'(?i)"HKCR:\\')
        self.assertIn('New-Item -Path "$classesRoot\\exefile\\DefaultIcon"', repair)
        self.assertGreaterEqual(repair.count('if ($LASTEXITCODE -ne 0)'), 2)
        self.assertIn('} catch {', repair)
        self.assertIn('exit 1', repair)

    def test_ifeo_batch_echo_escapes_parentheses_and_warns(self):
        self.assertIn('IFEO? ^(Removes hijacks^)', EXE_BATCH)
        self.assertIn('legitimate debugger and security entries can also be removed', EXE_BATCH)


if __name__ == '__main__':
    unittest.main()

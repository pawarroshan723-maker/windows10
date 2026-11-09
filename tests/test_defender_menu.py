"""Static tests only; Defender operations require an isolated Windows VM."""
import re
import unittest
from pathlib import Path

SCRIPT = (Path(__file__).resolve().parents[1] / 'cleanup_advanced.bat').read_text()


def section(label):
    match = re.search(rf'(?im)^:{re.escape(label)}\s*\n(.*?)(?=^:[\w-]+\s*$|\Z)', SCRIPT, re.S)
    if not match:
        raise AssertionError(label)
    return match.group(1)


class DefenderMenuTests(unittest.TestCase):
    def test_menu_includes_and_routes_j(self):
        menu = section('FIXMENU')
        self.assertIn('[J]', menu)
        self.assertIn('choice /c 123456789ABCDEFGHIJ0 ', menu)
        self.assertIn('if errorlevel 20 goto MENU\nif errorlevel 19 goto FIX_DEFENDER', menu)

    def test_status_and_explicit_confirmations(self):
        screen = section('FIX_DEFENDER')
        for field in ('AMRunningMode', 'AntivirusEnabled', 'RealTimeProtectionEnabled', 'IsTamperProtected'):
            self.assertIn(field, screen)
        self.assertIn('No automatic re-enable is scheduled', screen)
        for label in ('DEFENDER_ENABLE', 'DEFENDER_DISABLE'):
            self.assertRegex(section(label), r'call :confirm .*\nif errorlevel 2 goto FIX_DEFENDER')

    def test_cmdlets_check_requested_state_and_propagate_errors(self):
        for label, flag, expected in [('t_defender_on', '$false', '$true'), ('t_defender_off', '$true', '$false')]:
            text = section(label)
            self.assertIn(f'Set-MpPreference -DisableRealtimeMonitoring {flag} -ErrorAction Stop', text)
            self.assertIn(f'$s.RealTimeProtectionEnabled -ne {expected}', text)
            self.assertIn('Get-MpComputerStatus -ErrorAction Stop', text)
            self.assertIn('exit 1', text)
            self.assertIn('exit /b %errorlevel%', text)
            for forbidden in ('DisableAntiSpyware', 'Set-Service', 'TamperProtection=', 'ExclusionPath'):
                self.assertNotIn(forbidden, text)
        self.assertIn('no change made', section('t_defender_off'))


if __name__ == '__main__':
    unittest.main()

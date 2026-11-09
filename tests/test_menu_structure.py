"""Static checks for menu wiring; these do not execute Windows batch commands."""
import re
import unittest
from pathlib import Path

SCRIPT = (Path(__file__).resolve().parents[1] / 'cleanup_advanced.bat').read_text()


def section(label):
    match = re.search(rf'(?im)^:{re.escape(label)}\s*\n(.*?)(?=^:[\w-]+\s*$|\Z)', SCRIPT, re.S)
    if not match:
        raise AssertionError(f'No section {label}')
    return match.group(1)


def goto_menu_result(label, result):
    """Model the simple descending IF ERRORLEVEL/GOTO menus only."""
    text = section(label)
    after_choice = text.split('choice /c ', 1)[1].split('\n', 1)[1]
    for line in after_choice.splitlines():
        m = re.fullmatch(r'if errorlevel (\d+) goto ([\w-]+)', line.strip(), re.I)
        if m and result >= int(m.group(1)):
            return m.group(2)
        m = re.fullmatch(r'goto ([\w-]+)', line.strip(), re.I)
        if m:
            return m.group(1)
    raise AssertionError(f'No safe fallback in {label}')


class MenuStructureTests(unittest.TestCase):
    def test_menu_mappings_and_no_input_fallback(self):
        expected = {
            'MENU': ['RUN_QUICK', 'RUN_FULL', 'RUN_DEEP', 'RUN_SFCSUITE', 'RUN_NETRESET',
                     'RUN_WURESET', 'SVCMENU', 'REGMENU', 'FIXMENU', 'TWKMENU', 'OPTMENU',
                     'DISKINFO', 'AUTOMENU', 'RUN_REPAIRALL', 'END'],
            'REGMENU': ['REG_EXE', 'REG_TASKMGR', 'REG_CMD', 'REG_REGEDIT', 'REG_RUN',
                        'REG_FOLDEROPT', 'REG_USB', 'REG_CPANEL', 'MENU'],
            'TWKMENU': [*(f'TWK_{i}' for i in range(1, 10)), 'MENU'],
            'FIXMENU': ['FIX_PRINTER', 'FIX_AUDIO', 'FIX_BT', 'FIX_STORE', 'FIX_TIME',
                        'FIX_SEARCH', 'FIX_CHKDSK', 'FIX_SRESTORE', 'FIX_MEM', 'FIX_DNS',
                        'FIX_NETADAPT', 'FIX_DSKH', 'FIX_CRASH', 'FIX_STARTUP', 'FIX_PROCS',
                        'FIX_BATT', 'FIX_LICENSE', 'FIX_FILTERKEYS', 'FIX_DEFENDER', 'MENU'],
            'OPTMENU': ['OPT_DRIVES', 'OPT_PWRHIGH', 'OPT_PWRBAL', 'OPT_STARTUP',
                        'OPT_EXPLORER', 'OPT_HIBOFF', 'OPT_HIBON', 'OPT_STARTREST', 'MENU'],
            'AUTOMENU': ['AUTO_ENABLE', 'AUTO_STATUS', 'AUTO_REMOVE', 'MENU'],
            'FIX_DEFENDER': ['DEFENDER_ENABLE', 'DEFENDER_DISABLE', 'FIXMENU'],
        }
        for menu, targets in expected.items():
            with self.subTest(menu=menu):
                for value, target in enumerate(targets, 1):
                    self.assertEqual(goto_menu_result(menu, value), target)
                self.assertEqual(goto_menu_result(menu, 0), 'FIXMENU' if menu == 'FIX_DEFENDER' else menu)
                self.assertEqual(goto_menu_result(menu, 255), targets[-1])
        self.assertIn('choice /c 123456780 ', section('OPTMENU'))

    def test_nested_menus_each_branch_returns_immediately(self):
        for label, cases in {
            'FIX_DNS': [(3, 'dns_flush'), (2, 'dns_auto'), (1, 'dns_public')],
            'FIX_NETADAPT': [(2, 'net_wireless'), (1, 'net_enable')],
        }.items():
            text = section(label)
            for value, helper in cases:
                pattern = rf'if errorlevel {value} \(\s*call :{helper}\s*goto FIXMENU\s*\)'
                self.assertRegex(text, pattern)
            self.assertRegex(text, r'(?m)^goto FIXMENU$')
        for helper in ('dns_public', 'dns_auto', 'net_enable', 'net_wireless'):
            self.assertRegex(section(helper), r'call :confirm .*\nif errorlevel 2 goto :eof')

    def test_confirm_fails_closed(self):
        self.assertIn('if not "%CONFIRM_RC%"=="1" set "CONFIRM_RC=2"', section('confirm'))
        self.assertIn('else if errorlevel 1', section('tw_ask'))
        for label in ('RUN_QUICK', 'RUN_FULL', 'RUN_DEEP'):
            self.assertRegex(section(label), r'call :confirm .*\nif errorlevel 2 goto MENU')

    def test_pipeline_returns_before_summary(self):
        for label in ('RUN_REPAIRALL', 'RUN_AUTO'):
            self.assertIn('call :pipeline_all\ngoto SUMMARY', section(label))
        self.assertRegex(section('pipeline_all'), r'(?m)^exit /b 0$')
        self.assertIn('goto %SUMMARY_RETURN%', section('SUMMARY'))
        for label in ('MENU', 'REGMENU', 'FIXMENU', 'OPTMENU'):
            self.assertIn(f'set "SUMMARY_RETURN={label}"', section(label))
        self.assertIn('if %FAIL_NUM% gtr 0 exit /b 1', section('END_AUTO'))

    def test_new_scheduler_creation_is_disabled_but_removal_available(self):
        self.assertNotRegex(SCRIPT.lower(), r'schtasks\s+/create\b')
        self.assertIn('disabled for safety', section('AUTO_ENABLE'))
        self.assertIn('schtasks /query', section('AUTO_STATUS'))
        self.assertIn('schtasks /delete', section('AUTO_REMOVE'))

    def test_static_goto_and_call_labels_exist(self):
        labels = {x.lower() for x in re.findall(r'(?m)^:([\w-]+)\s*$', SCRIPT)}
        refs = re.findall(r'(?im)\b(?:goto\s+:?|call\s+:)([\w-]+)', SCRIPT)
        missing = {x for x in refs if x.lower() not in labels and x.lower() != 'eof'}
        self.assertFalse(missing, missing)


if __name__ == '__main__':
    unittest.main()

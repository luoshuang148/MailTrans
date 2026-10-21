"""Portable behavior checks for toolchain selection and native build planning."""
import importlib.util
from pathlib import Path
import unittest


class BuildTests(unittest.TestCase):
    def setUp(self):
        self.path = Path(__file__).with_name('build.py')
        spec = importlib.util.spec_from_file_location('mailtrans_build', self.path)
        self.build = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.build)

    def test_synthetic_fixture_remains_byte_identical(self):
        self.assertEqual(self.build.synthetic_fixture(),
                         self.path.parent.parent.joinpath('fixtures', 'layout-sample.eml').read_bytes())

    def test_toolchain_environment_respects_selected_xcode(self):
        env = self.build.developer_environment(None, {'DEVELOPER_DIR': '/selected/Xcode', 'PATH': '/bin'})
        self.assertEqual(env['DEVELOPER_DIR'], '/selected/Xcode')
        env = self.build.developer_environment('/override/Xcode', {'DEVELOPER_DIR': '/old'})
        self.assertEqual(env['DEVELOPER_DIR'], '/override/Xcode')
        env = self.build.developer_environment(None, {'PATH': '/bin'})
        self.assertNotIn('DEVELOPER_DIR', env, 'xcrun must then use xcode-select selection')

    def test_native_tests_use_runner_os_and_link_host_dependencies(self):
        commands = self.build.native_test_commands(Path('/source'), Path('/work'), '/sdk', '14.7')
        compilations = [command for command in commands if command[0] == '/usr/bin/xcrun']
        self.assertTrue(compilations)
        self.assertTrue(all('-mmacosx-version-min=14.7' in command for command in compilations))
        app_test = next(command for command in compilations if '/source/AppTests.m' in command)
        for source in ('MTProcessRunner.m', 'MTSetupController.m', 'MTAppManagement.m'):
            self.assertIn('/source/' + source, app_test)
        for test in ('ProcessRunnerTests.m', 'ManagementTests.m', 'SetupTests.m'):
            self.assertTrue(any('/source/' + test in command for command in compilations), test)
        self.assertFalse(any('swiftc' in command for command in commands))

    def test_full_build_rejects_old_sdk_or_wrong_architecture(self):
        for sdk, architecture in [('26.4', 'arm64'), ('26.5', 'x86_64')]:
            with self.subTest(sdk=sdk, architecture=architecture):
                with self.assertRaisesRegex(ValueError, 'SDK|arm64'):
                    self.build.require_app_toolchain(sdk, architecture)
        self.build.require_app_toolchain('26.5', 'arm64')
        self.build.require_app_toolchain('27.0', 'arm64')
        self.build.require_app_toolchain('27', 'arm64')


if __name__ == '__main__':
    unittest.main()

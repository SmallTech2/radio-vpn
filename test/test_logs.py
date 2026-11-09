"""Configuration des journaux : simulations isolees et rotation reelle sous Linux."""
import gzip
import os
import pathlib
import shutil
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
BASH = "C:/Program Files/Git/bin/bash.exe" if os.name == "nt" else "/bin/bash"


class LogConfiguration(unittest.TestCase):
    def test_installation_and_service_order(self):
        source = (ROOT / "Radio/deploy-vps.sh").read_text(encoding="utf-8")
        function = source.split("configure_logs(){", 1)[1].split("\ninstall_crl_timer(){", 1)[0]
        script = 'set -eu\nlog(){ :; }\n'
        for command in ("install", "logrotate", "systemctl"):
            script += command + '(){ printf "%s\\n" "' + command + ' $*"; }\n'
        script += 'TMP=/fixture\nconfigure_logs(){' + function + '\nconfigure_logs\n'
        result = subprocess.run([BASH], input=script, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), [
            "install -d -m 755 -o root -g root /etc/logrotate.d /etc/systemd/journald.conf.d",
            "install -m 644 -o root -g root /fixture/src/Radio/config/openvpn.logrotate /etc/logrotate.d/openvpn",
            "install -m 644 -o root -g root /fixture/src/Radio/config/99-radio-limits.conf /etc/systemd/journald.conf.d/99-radio-limits.conf",
            "logrotate --debug /etc/logrotate.d/openvpn",
            "systemctl restart systemd-journald.service",
            "systemctl enable --now logrotate.timer",
        ])
        self.assertIn("procps logrotate", source)
        self.assertLess(source.index("  configure_logs\n"), source.index("  activate_firewall\n"))

    def test_templates_and_manual_procedure_match(self):
        maintenance = (ROOT / "docs/maintenance.md").read_text(encoding="utf-8")
        rotation = (ROOT / "Radio/config/openvpn.logrotate").read_text()
        self.assertEqual(rotation.split(), ["/var/log/openvpn/openvpn.log", "{", "daily", "rotate", "7",
                                            "compress", "missingok", "notifempty", "copytruncate", "}"])
        journal = (ROOT / "Radio/config/99-radio-limits.conf").read_text()
        self.assertEqual(journal, "[Journal]\nSystemMaxUse=200M\nRuntimeMaxUse=50M\n")
        self.assertIn(rotation, maintenance)
        self.assertIn(journal, maintenance)

    @unittest.skipUnless(shutil.which("logrotate"), "logrotate requis (installe dans la CI Linux)")
    def test_real_rotation_retention_empty_and_missing(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            root.chmod(0o700)
            log = root / "openvpn.log"
            config = root / "logrotate.conf"
            state = root / "state"
            template = (ROOT / "Radio/config/openvpn.logrotate").read_text()
            config.write_text(template.replace("/var/log/openvpn/openvpn.log", str(log)))
            config.chmod(0o600)

            def run(*options):
                result = subprocess.run(["logrotate", *options, "--state", str(state), str(config)],
                                        capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)

            run("--debug")  # Fichier absent accepte, aucun etat cree.
            self.assertFalse(state.exists())
            log.write_text("initial\n")
            inode = log.stat().st_ino
            run("--debug")
            self.assertEqual(log.read_text(), "initial\n")
            for number in range(9):
                log.write_text(f"line {number}\n")
                run("--force")
                self.assertEqual(log.stat().st_ino, inode)
                self.assertEqual(log.read_text(), "")
                with gzip.open(root / "openvpn.log.1.gz", "rt") as archive:
                    self.assertEqual(archive.read(), f"line {number}\n")
            archives = sorted(root.glob("openvpn.log.*.gz"))
            self.assertEqual(len(archives), 7)
            before = {path.name: path.read_bytes() for path in archives}
            run("--force")  # notifempty : ne pas decaler les archives.
            self.assertEqual(before, {path.name: path.read_bytes() for path in archives})
            log.unlink()
            run("--force")


if __name__ == "__main__":
    unittest.main()

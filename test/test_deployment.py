"""Initialisation reelle de SQLite et des fichiers, sans lancer de service."""
import os
import pathlib
import shutil
import sqlite3
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]


@unittest.skipUnless(os.environ.get("RADIO_TEST_BINARY"), "requires the compiled native binary")
class DeploymentInitialization(unittest.TestCase):
    def test_all_three_networks(self):
        for voie in (1, 2, 3):
            with self.subTest(voie=voie), tempfile.TemporaryDirectory() as directory:
                root = pathlib.Path(directory)
                for name in ("conf", "db", "ovpn/config", "rsa/pki"):
                    (root / name).mkdir(parents=True)
                for name in ("openvpn-server-config.tpl", "openvpn-client-config.tpl", "easyrsa-vars.tpl"):
                    shutil.copy(ROOT / "Radio/config" / name, root / "conf" / name)
                config = (ROOT / "Radio/config/app.conf").read_text()
                for token, value in {"@VPN_NETWORK@": f"10.{voie}.0.0", "@PUBLIC_IP@": "203.0.113.7",
                                     "@PKI_ORG@": "Radio Bonheur", "@PKI_EMAIL@": "test@example.org",
                                     "/usr/share/easy-rsa": (root / "rsa").as_posix(),
                                     "/etc/openvpn": (root / "ovpn").as_posix()}.items():
                    config = config.replace(token, value)
                (root / "conf/app.conf").write_text(config)
                env = dict(os.environ, OPENVPN_ADMIN_USERNAME="admin", OPENVPN_ADMIN_PASSWORD="Test-initialization-only")
                result = subprocess.run([os.environ["RADIO_TEST_BINARY"], "-initialize-only"],
                                        cwd=root, env=env, capture_output=True, text=True, timeout=30)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                server = (root / "ovpn/server.conf").read_text()
                client = (root / "ovpn/config/client.conf").read_text()
                self.assertIn(f"server 10.{voie}.0.0 255.255.0.0 nopool", server)
                self.assertIn("client-to-client", server)
                self.assertIn("ccd-exclusive", server)
                self.assertIn("management 127.0.0.1 2080", server)
                self.assertIn("remote 203.0.113.7 1194 udp", client)
                self.assertNotIn("redirect-gateway", client)
                with sqlite3.connect(root / "db/data.db") as db:
                    db.row_factory = sqlite3.Row
                    tables = {row[0].replace("_", "").lower(): row[0]
                              for row in db.execute("SELECT name FROM sqlite_master WHERE type='table'")}
                    rows = {name: dict(db.execute(f'SELECT * FROM "{tables[name]}"').fetchone())
                            for name in ("ovconfig", "ovclientconfig", "easyrsaconfig")}
                server_row = {k.replace("_", "").lower(): v for k, v in rows["ovconfig"].items()}
                client_row = {k.replace("_", "").lower(): v for k, v in rows["ovclientconfig"].items()}
                self.assertEqual(server_row["server"], f"server 10.{voie}.0.0 255.255.0.0 nopool")
                self.assertEqual(server_row["redirectgw"], "")
                self.assertEqual(client_row["serveraddress"], "203.0.113.7")
                self.assertEqual(client_row["redirectgateway"], "")
                rsa_row = {k.replace("_", "").lower(): v for k, v in rows["easyrsaconfig"].items()}
                self.assertEqual(rsa_row["easyrsareqemail"], "test@example.org")
                self.assertIn('set_var EASYRSA_REQ_EMAIL    "test@example.org"', (root / "rsa/pki/vars").read_text())
                self.assertIn('"FR"', (root / "rsa/pki/vars").read_text())
                # Les erreurs importantes doivent bien produire un statut non nul.
                (root / "db/data.db").unlink()
                (root / "db").rmdir()
                (root / "db").write_text("not a directory")
                failed = subprocess.run([os.environ["RADIO_TEST_BINARY"], "-initialize-only"],
                                        cwd=root, env=env, capture_output=True, text=True, timeout=30)
                self.assertNotEqual(failed.returncode, 0)


if __name__ == "__main__":
    unittest.main()

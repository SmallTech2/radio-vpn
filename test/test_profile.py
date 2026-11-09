"""Assemblage reel des blocs PEM, sans Easy-RSA ni daemon VPN."""
import os
import pathlib
import re
import secrets
import shutil
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
BASH = os.environ.get("RADIO_TEST_BASH") or shutil.which("bash")
OPENSSL = os.environ.get("RADIO_TEST_OPENSSL") or shutil.which("openssl")


@unittest.skipUnless(BASH and OPENSSL, "requires Bash and OpenSSL")
class ProfileAssembly(unittest.TestCase):
    def test_complete_pem_blocks_and_tls_crypt(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            rsa, ovpn = root / "rsa", root / "ovpn"
            for path in (rsa / "pki/issued", rsa / "pki/private", ovpn / "config", ovpn / "clients"):
                path.mkdir(parents=True)
            env = dict(os.environ, MSYS_NO_PATHCONV="1", OPENVPN_UI_CONFIG=(root / "app.conf").as_posix())
            env["PATH"] = str(pathlib.Path(OPENSSL).parent) + os.pathsep + env.get("PATH", "")

            def openssl(*args, data=None):
                result = subprocess.run([OPENSSL, *map(str, args)], input=data,
                                        env=env, text=True, capture_output=True, timeout=30)
                self.assertEqual(result.returncode, 0, result.stderr)
                return result.stdout

            ca = rsa / "pki/ca.crt"
            key, cert = rsa / "pki/private/studio.key", rsa / "pki/issued/studio.crt"
            openssl("req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "2",
                    "-keyout", root / "ca.key", "-out", ca, "-subj", "/CN=Radio Test CA")
            openssl("req", "-new", "-newkey", "rsa:2048", "-nodes", "-keyout", key,
                    "-out", root / "client.csr", "-subj", "/CN=studio")
            openssl("x509", "-req", "-in", root / "client.csr", "-CA", ca,
                    "-CAkey", root / "ca.key", "-CAcreateserial", "-days", "1", "-out", cert)
            tls = "-----BEGIN OpenVPN Static key V1-----\n" + "\n".join(secrets.token_hex(16) for _ in range(16)) + "\n-----END OpenVPN Static key V1-----\n"
            (rsa / "pki/ta.key").write_text(tls)
            (root / "app.conf").write_text(f'EasyRsaPath = "{rsa.as_posix()}"\nOpenVpnPath = "{ovpn.as_posix()}"\n')
            (ovpn / "config/client.conf").write_text((ROOT / "Radio/config/openvpn-client-config.tpl").read_text().replace("{{ .ServerAddress }}", "203.0.113.7"))
            result = subprocess.run([BASH, (ROOT / "Radio/scripts/write-client-profile.sh").as_posix(), "studio"],
                                    env=env, text=True, capture_output=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            profile = (ovpn / "clients/studio.ovpn").read_text()
            for block in ("ca", "cert", "key", "tls-crypt"):
                self.assertEqual(profile.count(f"<{block}>"), 1)
                self.assertEqual(profile.count(f"</{block}>"), 1)
            pem = re.search(r"<cert>\s*(.*?)\s*</cert>", profile, re.S).group(1)
            self.assertEqual(openssl("x509", "-noout", "-serial", data=pem), openssl("x509", "-noout", "-serial", "-in", cert))
            self.assertIn(tls.strip(), profile)
            self.assertEqual(openssl("pkey", "-pubout", "-in", key), openssl("x509", "-pubkey", "-noout", data=pem))


if __name__ == "__main__":
    unittest.main()

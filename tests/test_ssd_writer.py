import importlib.util
from pathlib import Path
from types import SimpleNamespace
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('ssd', Path(__file__).resolve().parents[1] / 'scripts/create_ssd.py')
ssd = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ssd)

class ImageTests(unittest.TestCase):
    def test_empty_file_and_payloads(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            entries = []
            bodies = {'AAA': b'A'*300, 'EMPTY': b'', 'BBB': b'B'*10}
            for name, body in bodies.items():
                p = root/name
                p.write_bytes(body)
                entries.append(SimpleNamespace(content_path=p, file_name=name, directory='$', locked=False, load_addr='1900', exec_addr='1900'))
            out = root/'test.ssd'
            ssd.write_ssd(entries, out, 'TEST', 800)
            image = out.read_bytes()
            names = []
            for i in range(3):
                name = image[8+i*8:15+i*8].decode().rstrip()
                names.append(name)
                o = 264+i*8
                length = int.from_bytes(image[o+4:o+6], 'little') | ((image[o+6] >> 4) & 3)*65536
                start = image[o+7] | (image[o+6] & 3)*256
                self.assertEqual(image[start*256:start*256+length], bodies[name])
            self.assertEqual(names, ['BBB', 'EMPTY', 'AAA'])
            for invalid in (1, 1024):
                with self.assertRaises(SystemExit):
                    ssd.write_ssd(entries, out, 'TEST', invalid)

if __name__ == '__main__':
    unittest.main()

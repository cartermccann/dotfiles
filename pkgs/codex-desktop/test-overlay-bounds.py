import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("overlay", Path(__file__).with_name("patch-overlay-bounds.py"))
patcher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(patcher)


def fixture(content):
    main = {"offset": "6", "size": len(content), "integrity": patcher.integrity(content, 64)}
    header = {"files": {"before": {"offset": "0", "size": 6}, ".vite": {"files": {
        "build": {"files": {"main-fixture.js": main}}}},
        "after": {"offset": str(6 + len(content)), "size": 5},
        "native.node": {"unpacked": True, "size": 123}, "alias": {"link": "after"}}}
    data = json.dumps(header).encode()
    pad = (-len(data)) % 4
    return struct.pack("<IIII", 4, 8 + len(data) + pad, 4 + len(data) + pad, len(data)) + data + b"\0" * pad + b"before" + content + b"after"


SOURCE = patcher.START + b"xxx){" + patcher.OLD + b"}" + b";".join(patcher.CONTRACTS) + b"}" + patcher.END + b"{}"


class ArchiveTests(unittest.TestCase):
    def test_preserves_other_entries_and_integrity(self):
        with tempfile.TemporaryDirectory() as d:
            p, report = Path(d) / "app.asar", Path(d) / "report.json"
            p.write_bytes(fixture(SOURCE))
            prior = {"composerDictation": {"gate": "4100906017"}, "upstreamFeatures": ["codex-micro"]}
            report.write_text(json.dumps(prior))
            with contextlib.redirect_stdout(io.StringIO()):
                patcher.patch(p, report)
            raw = p.read_bytes()
            header, base = patcher.read_archive(raw)
            for name, entry in patcher.entries(header):
                if name in ("before", "after"):
                    off = base + int(entry["offset"])
                    self.assertEqual(raw[off:off + entry["size"]], name.encode())
                elif name.endswith(".js"):
                    off = base + int(entry["offset"])
                    changed = raw[off:off + entry["size"]]
                    self.assertEqual(changed, patcher.patch_source(SOURCE))
                    self.assertEqual(entry["integrity"], patcher.integrity(changed, 64))
            self.assertEqual(header["files"]["native.node"], {"unpacked": True, "size": 123})
            self.assertEqual(header["files"]["alias"], {"link": "after"})
            metadata = json.loads(report.read_text())
            for key, value in prior.items():
                self.assertEqual(metadata[key], value)
            self.assertIn("linuxOverlayBounds", metadata)
            before = p.read_bytes()
            with self.assertRaisesRegex(ValueError, "already present"):
                patcher.patch(p, report)
            self.assertEqual(p.read_bytes(), before)

    def test_rejects_invalid_or_duplicate_report_before_mutation(self):
        for metadata in ("[]", "invalid-json", '{"linuxOverlayBounds":{}}'):
            with tempfile.TemporaryDirectory() as d:
                p, report = Path(d) / "app.asar", Path(d) / "report.json"
                raw = fixture(SOURCE)
                p.write_bytes(raw)
                report.write_text(metadata)
                with self.assertRaises(ValueError):
                    patcher.patch(p, report)
                self.assertEqual(p.read_bytes(), raw)

    def test_rejects_source_drift(self):
        for content in (b"missing", SOURCE + SOURCE,
                        SOURCE.replace(patcher.OLD, b"if(changed){"),
                        SOURCE.replace(patcher.CONTRACTS[0], b"changed")):
            with self.assertRaises(ValueError):
                patcher.patch_source(content)

    def test_corrupt_archive_is_unchanged(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "app.asar"
            raw = fixture(SOURCE).replace(b"xxx", b"yyy")
            p.write_bytes(raw)
            with self.assertRaisesRegex(ValueError, "integrity mismatch"):
                patcher.patch(p, Path(d) / "report.json")
            self.assertEqual(p.read_bytes(), raw)


@unittest.skipUnless(os.environ.get("CODEX_OVERLAY_TEST_ASAR"), "Set CODEX_OVERLAY_TEST_ASAR to test actual bundled geometry")
class ActualGeometryTests(unittest.TestCase):
    def test_actual_geometry_platforms_displays_and_content(self):
        raw = Path(os.environ["CODEX_OVERLAY_TEST_ASAR"]).read_bytes()
        header, base = patcher.read_archive(raw)
        contents = []
        for name, entry in patcher.entries(header):
            if name.startswith(".vite/build/main-") and name.endswith(".js"):
                off = base + int(entry["offset"])
                s = raw[off:off + entry["size"]]
                if patcher.START in s:
                    contents.append(s)
        self.assertEqual(len(contents), 1)
        source = contents[0]
        patcher.patch_source(source)  # Contract must match the real shipped source.
        # Evaluate only the reviewed pure geometry functions/constants, not app code.
        pure = source[source.index(b"var zp={"):source.index(b"function loe(")].decode()
        harness = r'''
const vm=require('vm'), assert=require('assert');
const pure=JSON.parse(require('fs').readFileSync(0,'utf8'));
const patched=pure.replace('if(_){let e=o??w;', 'if(_&&process.platform!==`linux`){let e=o??w;');
function load(platform, text){let c={process:{platform}, Se:{damping:18.85,mass:1,stiffness:180}}; vm.createContext(c);vm.runInContext(text,c);return c;}
const cases=[];
for(const display of [{x:0,y:0,width:1080,height:1920},{x:1080,y:0,width:2560,height:1440},{x:-1280,y:0,width:1280,height:720}])
for(const edge of ['top','bottom']) for(const quick of [false,true]) for(const caption of [0,160]){
 let a={x:display.x+display.width/2,y:edge==='top'?display.y+80:display.y+display.height-130,width:112,height:121};
 cases.push({anchor:a,displayBounds:display,mode:'native',mascotSize:{width:112,height:121},nativeDrawMascotSize:quick?undefined:{width:80,height:87},nativeDrawDisplayHeightPx:1920,previousPlacement:'top-end',realtimeCaptionAboveMascotPx:caption,showsPetControls:true,traySize:{width:315,height:141},viewportSize:quick?{width:424,height:400}:undefined});
}
for(const platform of ['linux','darwin','win32']){
 let old=load(platform,pure), now=load(platform,patched);
 for(const c of cases){
  c.constrainNativeDrawWindowToDisplay=platform==='win32';
  let a=JSON.parse(JSON.stringify(old.noe(c))), b=JSON.parse(JSON.stringify(now.noe(c)));
  if(platform!=='linux'){assert.deepStrictEqual(b,a);continue;}
  const w=b.windowBounds,d=c.displayBounds;
  assert(w.width<=424 && w.height<=600, JSON.stringify(w));
  assert(w.x>=d.x && w.y>=d.y && w.x+w.width<=d.x+d.width && w.y+w.height<=d.y+d.height);
  for(const r of [b.mascot,b.tray].filter(Boolean)) assert(r.left>=0 && r.top>=0 && r.left+r.width<=w.width && r.top+r.height<=w.height,JSON.stringify(b));
 }
}
let old=load('linux',pure); let a=old.noe({...cases[0],constrainNativeDrawWindowToDisplay:false}); assert.strictEqual(a.windowBounds.height,3809); console.log('72 platform/content/display cases passed; reproduced original 3809px canvas');
'''
        result = subprocess.run([shutil.which("node") or "node", "-e", harness],
                                input=json.dumps(pure), text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        print(result.stdout.strip())


if __name__ == "__main__":
    unittest.main()

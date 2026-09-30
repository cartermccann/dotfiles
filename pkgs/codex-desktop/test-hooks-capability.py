import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("hooks", Path(__file__).with_name("patch-hooks-capability.py"))
patcher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(patcher)

SHARED = 'var host=`durable`;function cloud(e){return e===host}function encode(e){return`${prefix}${encodeURIComponent(e)}`}export{cloud as exported};'
QUERY = ('import{exported as isCloud}from"./app-shared-fixture.js";'
         'var hooks=atom($,({hostId:e,cwds:t},{scope:n})=>({queryKey:[...keys,e,t],'
         'queryFn:()=>{if(t==null||t.length===0)throw Error(`Cannot list hooks without project roots`);'
         'return route(n,e).sendRequest(`hooks/list`,{cwds:t})},staleTime:tf.FIVE_MINUTES,'
         'refetchOnMount:!0,enabled:t!=null&&t.length>0}));')
# A small executable structural fixture. Actual-bundle tests below also execute
# the shipped React-compiled functions, including their caches, independently.
PANEL = '''function panel(e){let t=(0,Q.c)(72),{entries:n,hostId:r,isRemoteHost:i,isLoadingProjectRoots:a,loadError:o,isLoading:s,isRefreshing:c,projectRootLabels:l,projectRoots:u,selectedSourceSection:d,onSelectSourceSection:f,onRefreshHooks:p,onToggleHookEnabled:h,onTrustHook:g}=e,A=[],G;
let V=u==null||u.length===0||s||c;
if(t[49]!==A?(G=u==null&&a?ne:empty,t[49]=A,t[50]=G):G=t[50]){}
let K=d!=null&&(s||O!=null);return {G,V,K}}
function settings(){let e=(0,Yt.c)(47),M=query,L;
L=()=>{M.refetch().then(async e=>{e.isSuccess&&(await notify())})};let R=L,z;
let U=false,H=M.data?.data,d=host,q;
return e[45]!==U?(q=(0,Zt.jsx)(panel,{entries:H,hostId:d,onRefreshHooks:R}),e[45]=U,e[46]=q):q=e[46],q}
var unused;export{settings as HooksSettings};'''.replace('}\nfunction ', '}function ').replace('}\nvar ', '}var ')


def fixture(query=QUERY, panel=PANEL, shared=SHARED):
    files = {"before": b"before", "webview/assets/query-fixture.js": query.encode(),
             "webview/assets/panel-fixture.js": panel.encode(),
             "webview/assets/app-shared-fixture.js": shared.encode(), "after": b"after"}
    header, payload = {"files": {}}, b""
    for name, content in files.items():
        parent = header
        parts = name.split("/")
        for part in parts[:-1]:
            parent = parent["files"].setdefault(part, {"files": {}})
        parent["files"][parts[-1]] = {"offset": str(len(payload)), "size": len(content),
                                          "integrity": patcher.integrity(content, 64)}
        payload += content
    header["files"]["native.node"] = {"unpacked": True, "size": 123}
    header["files"]["alias"] = {"link": "after"}
    encoded = json.dumps(header).encode()
    padding = (-len(encoded)) % 4
    return struct.pack("<IIII", 4, 8 + len(encoded) + padding, 4 + len(encoded) + padding, len(encoded)) + encoded + b"\0" * padding + payload


def assets(raw):
    header, base = patcher.read_archive(raw)
    return {name: raw[base + int(entry["offset"]):base + int(entry["offset"]) + entry["size"]]
            for name, entry in patcher.entries(header) if "offset" in entry and not entry.get("unpacked")}


def node(script, value):
    result = subprocess.run([shutil.which("node") or "node", "-e", script],
                            input=json.dumps(value), text=True, capture_output=True)
    if result.returncode:
        raise AssertionError(result.stderr)
    return result.stdout.strip()


QUERY_HARNESS = r'''
(async()=>{
const vm=require('vm'), assert=require('assert');
const input=JSON.parse(require('fs').readFileSync(0,'utf8'));
const fn=input.source.match(/\(\{hostId:e,cwds:t\},\{scope:n\}\)=>\(\{queryKey:\[\.\.\.[\w$]+,e,t\],queryFn:.+?,enabled:.+?\}\)/)[0];
const route=fn.match(/return ([\w$]+)\(n,e\)\.sendRequest/)[1];
const key=fn.match(/queryKey:\[\.\.\.([\w$]+)/)[1];
const pred=fn.match(/if\(([\w$]+)\(e\)\)return\{data:\[\],unsupportedReason:/)[1];
const tf=fn.match(/staleTime:([\w$]+)\.FIVE_MINUTES/)[1];
let calls=[]; const failure=new Error('local hook failure');
const scope={manager:{forHost(host){return {sendRequest(method,args){calls.push({scope,host,method,args});if(host==='fail')throw failure;if(host==='asyncFail')return Promise.reject(failure);return {data:[{cwd:args.cwds[0],hooks:[]}],sourceHost:host};}}}}};
const context={[key]:['hooks'],[tf]:{FIVE_MINUTES:300000},[pred]:h=>h==='durable', [route]:(s,h)=>s.manager.forHost(h),Error};
const query=vm.runInNewContext('('+fn+')',context);
for(const roots of [undefined,[],['/cloud']]){
 const q=query({hostId:'durable',cwds:roots},{scope});assert.strictEqual(q.enabled,true);
 const result=await q.queryFn();assert.strictEqual(result.unsupportedReason,input.reason);assert.strictEqual(result.data.length,0);
}
assert.strictEqual(calls.length,0);
for(const host of ['local','remote-ssh:test']){
 const roots=['/projects/one','/projects/two'];const q=query({hostId:host,cwds:roots},{scope});assert.strictEqual(q.enabled,true);
 const result=await q.queryFn();assert.strictEqual(result.sourceHost,host);assert(!('unsupportedReason' in result));
 const c=calls.pop();assert.strictEqual(c.scope,scope);assert.strictEqual(c.host,host);assert.strictEqual(c.method,'hooks/list');assert.strictEqual(c.args.cwds,roots);
}
assert.throws(()=>query({hostId:'fail',cwds:['/x']},{scope}).queryFn(),e=>e===failure);
await assert.rejects(()=>query({hostId:'asyncFail',cwds:['/x']},{scope}).queryFn(),e=>e===failure);
for(const roots of [undefined,[]]){const q=query({hostId:'local',cwds:roots},{scope});assert(!q.enabled);assert.throws(()=>q.queryFn(),/Cannot list hooks/);}
console.log('durable zero-RPC; local/SSH scoped routing, missing roots and local errors passed');
})().catch(e=>{console.error(e);process.exitCode=1});
'''


class SourceTests(unittest.TestCase):
    def test_query_semantics(self):
        changed = patcher.patch_query(QUERY, SHARED)
        node(QUERY_HARNESS, {"source": changed, "reason": patcher.REASON})

    def test_source_contracts_reject_drift_and_reapplication(self):
        for source in (QUERY + QUERY, QUERY.replace('cwds:t', 'roots:t'), QUERY.replace('refetchOnMount:!0', 'refetchOnMount:!1')):
            with self.assertRaises(ValueError):
                patcher.patch_query(source, SHARED)
        with self.assertRaisesRegex(ValueError, "already present"):
            patcher.patch_query(patcher.patch_query(QUERY, SHARED), SHARED)
        for source in (PANEL + PANEL, PANEL.replace('e[45]!==U?', 'e[45]!==U||unknown?'), PANEL.replace('.c)(72)', '.c)(75)')):
            with self.assertRaises(ValueError):
                patcher.patch_panel(source)
        with self.assertRaisesRegex(ValueError, "already present"):
            patcher.patch_panel(patcher.patch_panel(PANEL))
        for shared in (SHARED.replace('`durable`', '`unknown`'), SHARED + SHARED):
            with self.assertRaises(ValueError):
                patcher.patch_query(QUERY, shared)

    def test_renamed_top_level_symbols(self):
        source = QUERY.replace('isCloud', 'differentCloud').replace('keys', 'differentKey').replace('route', 'differentRoute')
        renamed_shared = SHARED.replace('cloud', '$cloud').replace('host', '$host').replace('exported', '$exported')
        source = source.replace('exported', '$exported')
        changed = patcher.patch_query(source, renamed_shared)
        node(QUERY_HARNESS, {"source": changed, "reason": patcher.REASON})
        panel = PANEL.replace('panel(', 'DifferentPanel(').replace('(panel,', '(DifferentPanel,').replace('settings', 'DifferentSettings')
        self.assertIn(patcher.MARKER, patcher.patch_panel(panel))


class ArchiveTests(unittest.TestCase):
    def test_preservation_integrity_offsets_report_and_reapplication(self):
        with tempfile.TemporaryDirectory() as directory:
            archive, report = Path(directory) / 'app.asar', Path(directory) / 'report.json'
            original = fixture()
            prior = {'composerDictation': {'gate': '4100906017'}, 'linuxOverlayBounds': {'verified': True}}
            archive.write_bytes(original)
            report.write_text(json.dumps(prior))
            with contextlib.redirect_stdout(io.StringIO()):
                patcher.patch(archive, report)
            before, after = assets(original), assets(archive.read_bytes())
            for name, content in before.items():
                if name.endswith('query-fixture.js'):
                    self.assertEqual(after[name], patcher.patch_query(content.decode(), SHARED).encode())
                elif name.endswith('panel-fixture.js'):
                    self.assertEqual(after[name], patcher.patch_panel(content.decode()).encode())
                else:
                    self.assertEqual(after[name], content)
            header, _ = patcher.read_archive(archive.read_bytes())
            self.assertEqual(header['files']['native.node'], {'unpacked': True, 'size': 123})
            self.assertEqual(header['files']['alias'], {'link': 'after'})
            metadata = json.loads(report.read_text())
            for key, value in prior.items():
                self.assertEqual(metadata[key], value)
            self.assertIn(patcher.REPORT_KEY, metadata)
            stable = archive.read_bytes(), report.read_bytes()
            with self.assertRaisesRegex(ValueError, 'already present'):
                patcher.patch(archive, report)
            self.assertEqual((archive.read_bytes(), report.read_bytes()), stable)

    def test_failures_leave_archive_and_report_unchanged(self):
        corruptions = [b'', b'bad header', fixture()[:-5], fixture().replace(b'return route(n,e)', b'return other(n,e)', 1),
                       fixture(query=QUERY + QUERY), fixture(panel=PANEL.replace('let V=u==null', 'let V=changed'))]
        for raw in corruptions:
            with self.subTest(size=len(raw)), tempfile.TemporaryDirectory() as directory:
                archive, report = Path(directory) / 'app.asar', Path(directory) / 'report.json'
                archive.write_bytes(raw)
                report.write_text('{}')
                with self.assertRaises(ValueError):
                    patcher.patch(archive, report)
                self.assertEqual(archive.read_bytes(), raw)
                self.assertEqual(report.read_text(), '{}')
        for metadata in ('[]', 'invalid', '{"hooksHostCapability":{}}'):
            with tempfile.TemporaryDirectory() as directory:
                archive, report = Path(directory) / 'app.asar', Path(directory) / 'report.json'
                raw = fixture()
                archive.write_bytes(raw)
                report.write_text(metadata)
                with self.assertRaises(ValueError):
                    patcher.patch(archive, report)
                self.assertEqual(archive.read_bytes(), raw)
                self.assertEqual(report.read_text(), metadata)


PANEL_HARNESS = r'''
(async()=>{
const vm=require('vm'),assert=require('assert');
const {panel,settings,reason}=JSON.parse(require('fs').readFileSync(0,'utf8'));
function jsx(type,props){return {type,props};}
const dummy=()=>null;const memo=new Map();let current='panel';
const c={console,Map,Symbol,URLSearchParams,Q:{c:()=>memo.get(current)||memo.set(current,[]).get(current)},Yt:{c:()=>memo.get(current)||memo.set(current,[]).get(current)},$:{jsx,jsxs:jsx,Fragment:'fragment'},Zt:{jsx},j:()=>({formatMessage:x=>x.defaultMessage}),ie:()=>({data:[]}),Ye:()=>[],Xe:()=>null,At:dummy,Wt:()=>'',Rt:dummy,Pe:'loading',m:'message',Re:'title',Kt:'hooks',kt:dummy,C:'icon',ae:'reload',te:'button',y:'tooltip',Y:'row',me:'error',jt:'empty',gt:'dialog',Me:'section',ke:dummy};
vm.createContext(c);vm.runInContext(panel,c);
const panelName=panel.match(/function ([\w$]+)/)[1];
function find(node,type){if(!node)return null;if(node.type===type)return node;const children=node.props?.children;for(const child of [...(Array.isArray(children)?children:[children]),node.props?.action]){const found=find(child,type);if(found)return found;}return null;}
const entries=[];for(const roots of [undefined,[],['/project']]){
 memo.clear();const props={entries,hostId:'durable',isRemoteHost:true,isLoadingProjectRoots:true,isLoading:true,isRefreshing:false,projectRoots:roots,loadError:new Error('unsupported API'),selectedSourceSection:{source:'project',projectRoot:'/project'}};
 for(const marker of [reason,undefined,reason]){
  const result=c[panelName]({...props,unsupportedReason:marker});
  if(marker){assert.strictEqual(find(result,'p').props.children,reason);assert.strictEqual(find(result,'p').props.role,'status');assert.strictEqual(find(result,'button').props.disabled,true);assert.strictEqual(find(result,'dialog').props.isOpen,false);}
  else assert.strictEqual(find(result,'p'),null);
 }
}
memo.clear();const localFailure=new Error('local settings failure');const local=c[panelName]({entries,hostId:'local',projectRoots:['/project'],isLoading:false,isLoadingProjectRoots:false,isRefreshing:false,loadError:localFailure,selectedSourceSection:null});
assert.strictEqual(find(local,'error').props.description.props.children,localFailure.message);assert.strictEqual(find(local,'button').props.disabled,false);
// Execute the actual settings function with fake atoms/React dependencies.
let query,host='durable',calls=0,toasts=0,broadcasts=0;
Object.assign(c,{o:()=>({get:()=>({success:()=>toasts++})}),se:{},B:()=>({key:'route'}),ue:()=>[new URLSearchParams(),dummy],f:()=>({}),Se:()=>({selectedHostId:host,setSelectedHostId:dummy}),J:()=>({kind:host==='local'?'local':'remote'}),g:()=>undefined,i:{},re:{},c:{},ce:{},ye:{},Be:{},n:(atom)=>atom===c.ce?{data:{roots:['/project'],labels:{}}}:atom===c.ye?query:{mutate:dummy},tt:x=>x,nt:()=>null,Xt:{useEffectEvent:x=>x,useEffect:dummy},we:async()=>broadcasts++,ne:{}});
vm.runInContext(settings,c);const settingsName=settings.match(/function ([\w$]+)/)[1];
const fakeQuery=(marker,responseMarker=marker)=>({data:{data:entries,unsupportedReason:marker},error:null,isPending:false,isFetching:false,refetch(){calls++;return Promise.resolve({isSuccess:true,data:{data:[],unsupportedReason:responseMarker}})}});
current='settings';memo.clear();query=fakeQuery(reason);let result=c[settingsName]();assert.strictEqual(result.props.unsupportedReason,reason);
result.props.onRefreshHooks();await new Promise(resolve=>setImmediate(resolve));assert.strictEqual(calls,0);assert.strictEqual(toasts,0);
query=fakeQuery(undefined,reason);result=c[settingsName]();result.props.onRefreshHooks();await new Promise(resolve=>setImmediate(resolve));assert.strictEqual(calls,1);assert.strictEqual(toasts,0);assert.strictEqual(broadcasts,0);
query=fakeQuery(undefined);host='local';result=c[settingsName]();assert.strictEqual(result.props.unsupportedReason,undefined);result.props.onRefreshHooks();await new Promise(resolve=>setImmediate(resolve));assert.strictEqual(toasts,1);assert.strictEqual(broadcasts,1);
query=fakeQuery(reason);host='durable';result=c[settingsName]();assert.strictEqual(result.props.unsupportedReason,reason);
console.log('actual panel roots/cache/refresh tests passed');
})().catch(e=>{console.error(e);process.exitCode=1});
'''


@unittest.skipUnless(os.environ.get('CODEX_HOOKS_TEST_ASAR'), 'Set CODEX_HOOKS_TEST_ASAR to exercise the installed bundle')
class ActualBundleTests(unittest.TestCase):
    def test_current_archive_query_panel_parsing_and_preservation(self):
        original = Path(os.environ['CODEX_HOOKS_TEST_ASAR']).read_bytes()
        with tempfile.TemporaryDirectory() as directory:
            archive, report = Path(directory) / 'app.asar', Path(directory) / 'report.json'
            archive.write_bytes(original)
            report.write_text('{"priorPatch":{"retained":true}}')
            with contextlib.redirect_stdout(io.StringIO()):
                patcher.patch(archive, report)
            before, after = assets(original), assets(archive.read_bytes())
            changed = [name for name in before if before[name] != after[name]]
            self.assertEqual(len(changed), 2)
            query_name = next(name for name in changed if b'`Cannot list hooks without project roots`' in after[name])
            panel_name = next(name for name in changed if b'as HooksSettings}' in after[name])
            query = after[query_name].decode()
            print(node(QUERY_HARNESS, {'source': query, 'reason': patcher.REASON}))
            source = after[panel_name].decode()
            settings_name = patcher.one(r'export\{(' + patcher.ID + r') as HooksSettings\}', source, 'settings export').group(1)
            _, _, settings = patcher.function_source(source, settings_name)
            panel_function = patcher.one(r'q=\(0,' + patcher.ID + r'\.jsx\)\((' + patcher.ID + r'),\{unsupportedReason:', settings, 'render').group(1)
            _, _, panel = patcher.function_source(source, panel_function)
            print(node(PANEL_HARNESS, {'settings': settings, 'panel': panel, 'reason': patcher.REASON}))
            for name in changed:
                path = Path(directory) / (Path(name).stem + '.mjs')
                path.write_bytes(after[name])
                result = subprocess.run([shutil.which('node') or 'node', '--check', str(path)], capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(json.loads(report.read_text())['priorPatch'], {'retained': True})
            self.assertEqual(len(before), len(after))
            print('actual ASAR: two changed assets; all other packed bytes and integrity preserved; both bundles parse')


if __name__ == '__main__':
    unittest.main()

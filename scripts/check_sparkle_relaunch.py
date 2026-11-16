"""Install/relaunch a disposable Sparkle fixture and require the new process to survive."""
import argparse
import functools
import http.server
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile
import threading
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]

def check(sparkle: Path, report: Path):
    from build_release import key_material, sign, NS
    import xml.etree.ElementTree as ET
    with tempfile.TemporaryDirectory(prefix='multishift-relaunch-check-') as temporary:
        root = Path(temporary)
        web = root / 'web'; web.mkdir()
        (root / 'events.log').touch()
        server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(web)))
        address = f'http://127.0.0.1:{server.server_port}/'
        threading.Thread(target=server.serve_forever, daemon=True).start()
        identity = 'com.multishift.relaunch-test.' + uuid.uuid4().hex
        public, key = key_material(os.urandom(32))
        env = {**os.environ, 'DEVELOPER_DIR': '/Applications/Xcode.app/Contents/Developer', 'CLANG_MODULE_CACHE_PATH': str(root / 'cache')}
        binary = root / 'relaunch-check'
        subprocess.run(['xcrun','clang','-fobjc-arc','-framework','Cocoa','-F',str(sparkle),'-framework','Sparkle','-Wl,-rpath,@executable_path/../Frameworks',str(Path(__file__).with_suffix('.m')),'-o',str(binary)],env=env,check=True)
        def fixture(parent, build):
            app = parent / 'RelaunchCheck.app'
            (app / 'Contents/MacOS').mkdir(parents=True)
            (app / 'Contents/Frameworks').mkdir()
            shutil.copyfile(binary,app / 'Contents/MacOS/RelaunchCheck')
            (app / 'Contents/MacOS/RelaunchCheck').chmod(0o755)
            subprocess.run(['ditto',str(sparkle / 'Sparkle.framework'),str(app / 'Contents/Frameworks/Sparkle.framework')],check=True)
            info=dict(CFBundleIdentifier=identity,CFBundleName='RelaunchCheck',CFBundleExecutable='RelaunchCheck',CFBundlePackageType='APPL',CFBundleVersion=str(build),CFBundleShortVersionString=f'0.0.{build}',LSUIElement=True,NSPrincipalClass='NSApplication',SUFeedURL=address+'appcast.xml',SUPublicEDKey=public,SURequireSignedFeed=True,SUVerifyUpdateBeforeExtraction=True,AcceptanceRoot=str(root))
            (app / 'Contents/Info.plist').write_bytes(plistlib.dumps(info))
            subprocess.run(['codesign','--force','--deep','--sign','-',str(app)],check=True)
            return app
        host=fixture(root / 'host',1); target=fixture(root / 'target',2)
        archive=web / 'update.zip'
        subprocess.run(['ditto','-c','-k','--sequesterRsrc','--keepParent',str(target),str(archive)],check=True)
        signature=sign(sparkle / 'bin/sign_update',key,archive)
        rss=ET.Element('rss',{'version':'2.0'});item=ET.SubElement(ET.SubElement(rss,'channel'),'item')
        ET.SubElement(item,f'{{{NS}}}version').text='2'
        ET.SubElement(item,'enclosure',{'url':address+'update.zip','length':str(archive.stat().st_size),'type':'application/octet-stream',f'{{{NS}}}edSignature':signature})
        feed=web/'appcast.xml';ET.ElementTree(rss).write(feed,encoding='utf-8',xml_declaration=True);sign(sparkle/'bin/sign_update',key,feed)
        process=None
        try:
            process=subprocess.Popen([str(host/'Contents/MacOS/RelaunchCheck')],env=env)
            deadline=time.monotonic()+90
            while time.monotonic()<deadline and not (root/'restarted.json').exists():
                if (root/'failure.txt').exists(): raise RuntimeError((root/'failure.txt').read_text())
                time.sleep(0.2)
            if not (root/'restarted.json').exists(): raise RuntimeError('Sparkle did not relaunch a surviving target process: '+(root/'events.log').read_text())
            result=json.loads((root/'restarted.json').read_text());result.update(scope='disposable app with real Sparkle installer; production apps untouched',old_pid=process.pid,events=(root/'events.log').read_text().splitlines())
            assert result['pid']!=process.pid
            assert plistlib.loads((host/'Contents/Info.plist').read_bytes())['CFBundleVersion']=='2'
            subprocess.run(['codesign','--verify','--deep','--strict',str(host)],check=True)
            report.parent.mkdir(parents=True,exist_ok=True);report.write_text(json.dumps(result,indent=2)+'\n')
            print('Sparkle install + relaunch PASS:', result)
        finally:
            server.shutdown();server.server_close()
            if process and process.poll() is None:process.terminate();process.wait(timeout=5)
            # Remove only our disposable app from LaunchServices before its directory disappears.
            subprocess.run(['/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister','-u',str(host)],capture_output=True)

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--sparkle',type=Path,default=Path('/tmp/multishift-sparkle-2.10.0'));p.add_argument('--report',type=Path,required=True);a=p.parse_args();check(a.sparkle.resolve(),a.report.resolve())

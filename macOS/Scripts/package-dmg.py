#!/usr/bin/env python3
"""Package a verified Converty app, media source, application source, and checksums."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tarfile
import tempfile


def run(*args, **kwargs):
    return subprocess.run(args, check=True, **kwargs)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    native = Path(__file__).resolve().parents[1]
    repo = native.parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine-dir', required=True, type=Path)
    parser.add_argument('--source-dir', type=Path, default=repo / 'dist-native/engine/sources')
    parser.add_argument('--allow-unnotarized', action='store_true', help='Package a clearly labeled early release without claiming Apple notarization.')
    args = parser.parse_args()
    engine_root = args.engine_dir.resolve()
    if subprocess.check_output(['git', 'status', '--porcelain'], cwd=repo, text=True).strip():
        raise SystemExit('Commit the release source before packaging so the source record is exact.')
    commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=repo, text=True).strip()
    records = json.loads((native / 'Engine/sources.json').read_text())
    provenance = json.loads((engine_root / 'provenance.json').read_text())
    if records != provenance['sources']:
        raise SystemExit('The built engine does not match the release source manifest.')
    if digest(native / 'Scripts/build-engine.py') != provenance['recipe_sha256']:
        raise SystemExit('The built engine does not match the current build recipe.')
    for item in records:
        if digest(args.source_dir / item['archive']) != item['sha256']:
            raise SystemExit(f'Source checksum mismatch: {item["archive"]}')
    env = os.environ.copy()
    env['CONVERTY_ENGINE_DIR'] = str(engine_root)
    env.pop('CONVERTY_FFMPEG', None)
    run(str(native / 'Scripts/build.sh'), cwd=repo, env=env)
    app = repo / 'dist-native/Converty.app'
    info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    version = info['CFBundleShortVersionString']
    name = f'Converty-{version}'
    output = repo / 'dist-native/releases' / f'v{version}'
    output.mkdir(parents=True, exist_ok=True)
    if any(output.iterdir()):
        raise SystemExit(f'Release output already exists; preserve or move it before retrying: {output}')
    notarized = subprocess.run(['xcrun', 'stapler', 'validate', str(app)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0
    if not notarized and not args.allow_unnotarized:
        raise SystemExit('No stapled notarization ticket. Notarize first, or explicitly package an unnotarized early release.')
    run('npm', 'run', 'prepare:source', cwd=repo)
    source_zip = output / f'{name}-source.zip'
    shutil.copy2(repo / 'public/converty-source.zip', source_zip)
    media_source = output / f'{name}-media-source.tar.gz'
    with tarfile.open(media_source, 'w:gz') as tar:
        for item in records:
            tar.add(args.source_dir / item['archive'], arcname=f'{name}-media-source/sources/{item["archive"]}')
        for file in ['Scripts/build-engine.py', 'Engine/sources.json']:
            tar.add(native / file, arcname=f'{name}-media-source/macOS/{file}')
        tar.add(engine_root / 'provenance.json', arcname=f'{name}-media-source/provenance.json')
        tar.add(engine_root / 'notices/All-Licenses.txt', arcname=f'{name}-media-source/All-Licenses.txt')
        tar.add(repo / 'docs/macos-release.md', arcname=f'{name}-media-source/BUILD.md')
    dmg = output / f'{name}-macOS-arm64.dmg'
    with tempfile.TemporaryDirectory(prefix='converty-dmg-') as temporary:
        stage = Path(temporary) / 'stage'
        stage.mkdir()
        run('ditto', str(app), str(stage / 'Converty.app'))
        (stage / 'Applications').symlink_to('/Applications')
        (stage / 'Install Converty.txt').write_text(
            f'Converty {version} for Apple Silicon\n\n'
            '1. Drag Converty.app onto Applications.\n'
            '2. Open Converty from Applications.\n'
            '3. Drag a file in Finder and hold Shift to show the format wheel.\n\n'
            + ('This early release is not notarized by Apple. macOS may block the first launch.\n'
               'If you choose to trust this build, follow Apple\'s instructions for an\n'
               'unidentified developer: https://support.apple.com/en-us/102445\n\n' if not notarized else '')
            + 'Requires macOS 14 or later and an Apple Silicon Mac (M1 or newer).\n'
            'Source, checksums, and media-engine sources: https://github.com/rirachii/converty/releases\n'
        )
        run('hdiutil', 'create', '-volname', f'Converty {version}', '-srcfolder', str(stage), '-format', 'UDZO', '-imagekey', 'zlib-level=9', str(dmg))
    run('hdiutil', 'verify', str(dmg))
    mounted = plistlib.loads(subprocess.check_output(['hdiutil', 'attach', '-readonly', '-nobrowse', '-plist', str(dmg)]))
    entity = next(item for item in mounted['system-entities'] if 'mount-point' in item)
    mount = Path(entity['mount-point'])
    try:
        run('codesign', '--verify', '--deep', '--strict', str(mount / 'Converty.app'))
        if (mount / 'Applications').readlink() != Path('/Applications'):
            raise SystemExit('Applications shortcut is missing from the DMG.')
        for relative in ['Contents/MacOS/Converty', 'Contents/Resources/bin/ffmpeg']:
            if digest(mount / 'Converty.app' / relative) != digest(app / relative):
                raise SystemExit(f'Disk image payload mismatch: {relative}')
    finally:
        run('hdiutil', 'detach', entity['dev-entry'])
    release = {
        'version': version, 'build': info['CFBundleVersion'], 'source_commit': commit,
        'architecture': 'arm64', 'minimum_macos': info['LSMinimumSystemVersion'],
        'notarized': notarized, 'engine': provenance,
        'files': {file.name: {'sha256': digest(file), 'bytes': file.stat().st_size} for file in [dmg, source_zip, media_source]},
    }
    (output / 'release.json').write_text(json.dumps(release, indent=2) + '\n')
    (output / 'SHA256SUMS.txt').write_text(''.join(f'{digest(file)}  {file.name}\n' for file in sorted(output.iterdir()) if file.is_file()))
    print(f'Release ready: {output}', flush=True)


if __name__ == '__main__':
    main()

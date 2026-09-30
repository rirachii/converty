#!/usr/bin/env python3
"""Build the release FFmpeg and every bundled codec from checksum-pinned source.

The full variant is the GPL engine shipped in the direct-download DMG.
The lgpl variant is the Mac App Store engine: no GPL or nonfree components,
no network protocols, and H.264 encoding through macOS VideoToolbox.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import urllib.request


def main():
    native = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--variant', choices=['full', 'lgpl'], default='full')
    parser.add_argument('--work-dir', type=Path)
    parser.add_argument('--source-dir', type=Path)
    parser.add_argument('--jobs', type=int, default=min(os.cpu_count() or 4, 8))
    args = parser.parse_args()
    if os.uname().machine != 'arm64':
        raise SystemExit('This release recipe currently targets Apple Silicon only.')
    work = (args.work_dir or native.parent / ('dist-native/engine' if args.variant == 'full' else 'dist-native/engine-lgpl')).resolve()
    cache = (args.source_dir or work / 'sources').resolve()
    prefix = work / 'prefix'
    for folder in [work, cache, prefix, work / 'logs', work / 'notices']:
        folder.mkdir(parents=True, exist_ok=True)
    for tool in ['clang', 'make', 'pkg-config', 'tar']:
        if not shutil.which(tool):
            raise SystemExit(f'Missing build tool: {tool}')
    records = json.loads((native / 'Engine/sources.json').read_text())
    env = os.environ.copy()
    env.update({
        'MACOSX_DEPLOYMENT_TARGET': '14.0',
        'CFLAGS': '-O2 -mmacosx-version-min=14.0',
        'CXXFLAGS': '-O2 -mmacosx-version-min=14.0',
        'CPPFLAGS': f'-I{prefix}/include',
        'LDFLAGS': f'-L{prefix}/lib -mmacosx-version-min=14.0',
        'PKG_CONFIG_PATH': '',
        'PKG_CONFIG_LIBDIR': str(prefix / 'lib/pkgconfig'),
    })
    common = [f'--prefix={prefix}', '--disable-shared', '--enable-static']
    configurations = {
        'libogg': common,
        'libvorbis': common + ['--disable-docs', '--disable-examples'],
        'opus': common + ['--disable-doc', '--disable-extra-programs'],
        'lame': common + ['--disable-frontend', '--disable-decoder'],
        'libwebp': common + ['--disable-gl', '--disable-sdl', '--disable-png', '--disable-jpeg', '--disable-tiff', '--disable-gif'],
        'x264': [f'--prefix={prefix}', '--enable-static', '--enable-pic', '--disable-cli', '--disable-opencl'],
        'libvpx': [f'--prefix={prefix}', '--target=arm64-darwin20-gcc', '--disable-shared', '--enable-static', '--enable-pic', '--disable-examples', '--disable-tools', '--disable-docs', '--disable-unit-tests'],
        'ffmpeg': [f'--prefix={prefix}', '--arch=arm64', '--cc=clang', '--disable-shared', '--enable-static', '--disable-autodetect', '--disable-doc', '--disable-debug', '--disable-ffplay', '--enable-zlib', '--enable-bzlib', '--enable-iconv', '--extra-libs=-liconv', '--enable-videotoolbox', '--enable-audiotoolbox', '--enable-libvpx', '--enable-libopus', '--enable-libmp3lame', '--enable-libvorbis', '--enable-libwebp', '--pkg-config-flags=--static'],
    }
    libraries = ['libogg', 'libvorbis', 'opus', 'lame', 'libwebp', 'x264', 'libvpx', 'ffmpeg']
    if args.variant == 'full':
        configurations['ffmpeg'] += ['--enable-gpl', '--enable-libx264']
    else:
        # x264 is GPL-only. VideoToolbox's h264_videotoolbox encoder replaces it.
        libraries.remove('x264')
        configurations['ffmpeg'] += ['--disable-network']
    by_name = {item['name']: item for item in records}
    recipe_hash = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    notices = [f'Converty release media engine ({args.variant} variant)\nSource and build recipe: https://github.com/rirachii/converty\n']
    for name in libraries:
        item = by_name[name]
        archive = cache / item['archive']
        if not archive.exists():
            print(f'Downloading {name} {item["version"]}', flush=True)
            with urllib.request.urlopen(item['url'], timeout=120) as response:
                data = response.read()
            if hashlib.sha256(data).hexdigest() != item['sha256']:
                raise SystemExit(f'Checksum mismatch: {name}')
            archive.write_bytes(data)
        if hashlib.sha256(archive.read_bytes()).hexdigest() != item['sha256']:
            raise SystemExit(f'Checksum mismatch: {archive.name}')
        source = work / 'build' / name
        stamp = work / f'{name}.built'
        fingerprint = item['sha256'] + recipe_hash + args.variant
        if not (source.exists() and stamp.exists() and stamp.read_text() == fingerprint):
            if source.exists():
                shutil.rmtree(source)
            source.mkdir(parents=True)
            subprocess.run(['tar', '-xf', str(archive), '--strip-components=1', '-C', str(source)], check=True)
            if name == 'libvorbis':
                # The 1.3.7 configure script adds a PowerPC-era linker option
                # on Darwin. Current Apple linkers reject it on Apple Silicon.
                configure = source / 'configure'
                configure.write_text(configure.read_text().replace('-force_cpusubtype_ALL', ''))
            print(f'Building {name} {item["version"]}', flush=True)
            log_path = work / 'logs' / f'{name}.log'
            with log_path.open('w') as log:
                for command in [['./configure', *configurations[name]], ['make', f'-j{args.jobs}'], ['make', 'install']]:
                    try:
                        subprocess.run(command, cwd=source, env=env, stdout=log, stderr=subprocess.STDOUT, check=True)
                    except subprocess.CalledProcessError:
                        log.flush()
                        print('\n'.join(log_path.read_text(errors='replace').splitlines()[-35:]), flush=True)
                        raise SystemExit(f'{name} failed; inspect {log_path}')
            stamp.write_text(fingerprint)
        else:
            print(f'Reusing verified build of {name}', flush=True)
        notices.append(f'\n{name} {item["version"]}\n{item["url"]}\nSHA-256: {item["sha256"]}\n')
        for path in sorted(source.iterdir()):
            if path.is_file() and path.name.upper().startswith(('COPYING', 'LICENSE', 'PATENTS', 'NOTICE')):
                notices.append(f'\n{path.name}\n\n{path.read_text(errors="replace")}\n')
    for name in ['ffmpeg', 'ffprobe']:
        binary = prefix / 'bin' / name
        dependencies = subprocess.check_output(['otool', '-L', str(binary)], text=True).splitlines()[1:]
        if any(not line.strip().startswith(('/usr/lib/', '/System/Library/')) for line in dependencies):
            raise SystemExit(f'{name} links to a non-system library: {dependencies}')
        if subprocess.check_output(['lipo', '-archs', str(binary)], text=True).strip() != 'arm64':
            raise SystemExit(f'Unexpected architecture in {name}')
    if args.variant == 'lgpl':
        ffmpeg = str(prefix / 'bin/ffmpeg')
        configuration = subprocess.check_output([ffmpeg, '-hide_banner', '-buildconf'], text=True)
        license_text = ' '.join(subprocess.check_output([ffmpeg, '-hide_banner', '-L'], text=True).split())
        encoders = subprocess.check_output([ffmpeg, '-hide_banner', '-encoders'], text=True)
        if any(flag in configuration for flag in ['--enable-gpl', '--enable-nonfree', '--enable-version3', 'libx264']):
            raise SystemExit('The LGPL engine configuration contains a GPL or nonfree option.')
        if 'GNU Lesser General Public License' not in license_text or 'GNU General Public License' in license_text.replace('GNU Lesser General Public License', ''):
            raise SystemExit('FFmpeg does not report an LGPL license.')
        if ' h264_videotoolbox ' not in encoders:
            raise SystemExit('The LGPL engine is missing the VideoToolbox H.264 encoder.')
    (work / 'notices/All-Licenses.txt').write_text('\n'.join(notices))
    shutil.copy2(native / 'Engine/sources.json', work / 'notices/sources.json')
    provenance = {
        'ffmpeg_sha256': hashlib.sha256((prefix / 'bin/ffmpeg').read_bytes()).hexdigest(),
        'recipe_sha256': recipe_hash,
        'variant': args.variant,
        'architecture': 'arm64',
        'minimum_macos': '14.0',
        'compiler': subprocess.check_output(['clang', '--version'], text=True).splitlines()[0],
        'sdk': subprocess.check_output(['xcrun', '--sdk', 'macosx', '--show-sdk-version'], text=True).strip(),
        'sources': [item for item in records if item['name'] in libraries],
    }
    (work / 'provenance.json').write_text(json.dumps(provenance, indent=2) + '\n')
    print(f'Engine ready: {prefix / "bin/ffmpeg"}', flush=True)


if __name__ == '__main__':
    main()

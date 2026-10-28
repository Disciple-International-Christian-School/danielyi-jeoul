#!/usr/bin/env python3
"""Prepare a local preview ref; never alter main or push remote refs."""
import argparse
import json
from pathlib import Path
import re
import subprocess

HANGUL = re.compile('[\u1100-\u11ff\u3130-\u318f\uac00-\ud7af]')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', default='.')
    parser.add_argument('--ref', default='refs/heads/main')
    parser.add_argument('--translations', default='docs/commit-message-translations.json')
    parser.add_argument('--preview-ref', default='refs/heads/review/english-commit-history')
    parser.add_argument('--apply', action='store_true', help='Create objects and a new local preview ref only')
    args = parser.parse_args()

    def git(*cmd, data=None):
        return subprocess.check_output(['git', '-C', args.repo, *cmd], input=data)

    if not args.preview_ref.startswith('refs/heads/review/'):
        raise SystemExit('Preview ref must be under refs/heads/review/.')
    git('check-ref-format', args.preview_ref)
    if git('rev-parse', '--is-shallow-repository').strip() != b'false':
        raise SystemExit('A complete clone is required; fetch full history first.')
    head = git('rev-parse', '--verify', args.ref + '^{commit}').decode().strip()
    mapping_path = Path(args.translations)
    if not mapping_path.is_absolute():
        mapping_path = Path(args.repo) / mapping_path
    translations = json.loads(mapping_path.read_text())
    if not all(isinstance(v, str) and v.strip() and not HANGUL.search(v) for v in translations.values()):
        raise SystemExit('Every translation must be nonempty English-only text.')
    order = git('rev-list', '--reverse', '--topo-order', head).decode().splitlines()
    replacements = {}
    raw_objects = {}
    for sha in order:
        raw = git('cat-file', 'commit', sha)
        header, message = raw.split(b'\n\n', 1)
        raw_objects[sha] = (header, message)
        if HANGUL.search(message.decode('utf-8')):
            if sha not in translations:
                raise SystemExit('Unmapped Korean commit: ' + sha)
            replacements[sha] = translations[sha].rstrip().encode() + b'\n'
    print(json.dumps({'source_head': head, 'reachable_commits': len(order),
                      'messages_to_translate': len(replacements),
                      'mode': 'preview' if args.apply else 'dry-run'}, indent=2))
    if not args.apply:
        return
    exists = subprocess.run(['git', '-C', args.repo, 'show-ref', '--verify', '--quiet', args.preview_ref]).returncode
    if exists == 0:
        raise SystemExit('Preview ref already exists; inspect it before choosing a new preview name.')
    rewritten = {}
    changed = 0
    for sha in order:
        header, old_message = raw_objects[sha]
        lines = header.split(b'\n')
        parent_changed = any(line.startswith(b'parent ') and rewritten[line[7:].decode()] != line[7:].decode() for line in lines)
        if sha not in replacements and not parent_changed:
            rewritten[sha] = sha
            continue
        new_lines = []
        skip_continuations = False
        for line in lines:
            if line.startswith(b' '):
                if not skip_continuations:
                    new_lines.append(line)
                continue
            key = line.split(b' ', 1)[0]
            skip_continuations = key in (b'gpgsig', b'gpgsig-sha256', b'mergetag')
            if skip_continuations:
                continue
            if key == b'parent':
                line = b'parent ' + rewritten[line[7:].decode()].encode()
            new_lines.append(line)
        message = replacements.get(sha, old_message)
        raw = b'\n'.join(new_lines) + b'\n\n' + message
        new_sha = git('hash-object', '-t', 'commit', '-w', '--stdin', data=raw).decode().strip()
        check_header, check_message = git('cat-file', 'commit', new_sha).split(b'\n\n', 1)
        for key in (b'tree ', b'author ', b'committer '):
            assert [x for x in lines if x.startswith(key)] == [x for x in check_header.split(b'\n') if x.startswith(key)]
        assert not HANGUL.search(check_message.decode('utf-8'))
        rewritten[sha] = new_sha
        changed += 1
    new_head = rewritten[head]
    assert git('rev-parse', head + '^{tree}') == git('rev-parse', new_head + '^{tree}')
    git('update-ref', args.preview_ref, new_head, '0' * 40)
    print(json.dumps({'preview_ref': args.preview_ref, 'preview_head': new_head,
                      'rewritten_commit_objects': changed, 'tree_unchanged': True,
                      'author_and_committer_headers_preserved': True,
                      'main_changed': False, 'remote_pushed': False}, indent=2))


if __name__ == '__main__':
    main()

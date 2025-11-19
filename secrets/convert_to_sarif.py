#!/usr/bin/env python3
"""
Minimal converter from common scanner JSON outputs (gitleaks, trufflehog, detect-secrets)
to SARIF v2.1.0. This is intentionally small: it maps findings to SARIF results
with file/line where possible.

Usage:
  python3 convert_to_sarif.py --scanner gitleaks --input path/to/gitleaks.json --output out.sarif
"""
import argparse
import json
import os
import sys


def make_sarif(results, tool_name):
    sarif = {
        "version": "2.1.0",
        "$schema": "https://schemastore.azurewebsites.net/schemas/json/sarif-2.1.0-rtm.5.json",
        "runs": [
            {
                "tool": {
                    "driver": {
                        "name": tool_name,
                        "informationUri": "",
                        "rules": []
                    }
                },
                "results": results
            }
        ]
    }
    return sarif


def gitleaks_to_results(data):
    results = []
    # gitleaks JSON often is a list of findings
    for f in data if isinstance(data, list) else []:
        rule_id = f.get('rule', f.get('ruleId', 'gitleaks'))
        path = f.get('file', f.get('path', None))
        line = f.get('line', 1)
        message = f.get('description', f.get('commitMessage', 'Potential secret'))
        loc = {
            "physicalLocation": {
                "artifactLocation": {"uri": path or '<unknown>'},
                "region": {"startLine": int(line) if line else 1}
            }
        }
        results.append({
            "ruleId": rule_id,
            "message": {"text": message},
            "locations": [loc]
        })
    return results


def trufflehog_to_results(data):
    results = []
    # TruffleHog v3 stores findings in a JSON object with 'findings'
    entries = data.get('findings', []) if isinstance(data, dict) else []
    for f in entries:
        path = f.get('path') or f.get('File')
        line = f.get('line', 1)
        message = f.get('reason', f.get('match', 'Potential secret'))
        results.append({
            "ruleId": "trufflehog",
            "message": {"text": message},
            "locations": [{
                "physicalLocation": {
                    "artifactLocation": {"uri": path or '<unknown>'},
                    "region": {"startLine": int(line) if line else 1}
                }
            }]
        })
    return results


def detect_secrets_to_results(data):
    results = []
    # detect-secrets baseline format stores 'results' keyed by filename
    if isinstance(data, dict):
        # Try baseline format
        for filename, findings in data.items():
            if not isinstance(findings, list):
                continue
            for f in findings:
                secret_type = f.get('type') or f.get('hashed_secret') or 'detect-secrets'
                message = f.get('reason', secret_type)
                results.append({
                    "ruleId": secret_type,
                    "message": {"text": message},
                    "locations": [{
                        "physicalLocation": {
                            "artifactLocation": {"uri": filename},
                            "region": {"startLine": f.get('line_number', 1) if isinstance(f.get('line_number', None), int) else 1}
                        }
                    }]
                })
    return results


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--scanner', required=True, choices=['gitleaks', 'trufflehog', 'detect-secrets'])
    p.add_argument('--input', required=True)
    p.add_argument('--output', required=True)
    args = p.parse_args()

    if not os.path.exists(args.input):
        print(f"Input file not found: {args.input}", file=sys.stderr)
        sys.exit(2)

    with open(args.input, 'r', encoding='utf-8') as fh:
        try:
            data = json.load(fh)
        except Exception:
            print(f"Failed to parse JSON from {args.input}", file=sys.stderr)
            sys.exit(2)

    if args.scanner == 'gitleaks':
        results = gitleaks_to_results(data)
    elif args.scanner == 'trufflehog':
        results = trufflehog_to_results(data)
    else:
        results = detect_secrets_to_results(data)

    sarif = make_sarif(results, args.scanner)
    with open(args.output, 'w', encoding='utf-8') as fh:
        json.dump(sarif, fh, indent=2)

    print(f"Wrote SARIF to {args.output}")


if __name__ == '__main__':
    main()

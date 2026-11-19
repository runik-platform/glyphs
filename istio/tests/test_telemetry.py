"""Contract tests through the real Kaster dispatcher.

Set KASTER_CHART to a Kaster checkout using this candidate Glyphs tree.
"""
import json
import os
import subprocess
import tempfile
import unittest

import yaml


class TelemetryContract(unittest.TestCase):
    def render(self, definition, lexicon=None, error=None):
        values = {
            'spellbook': {'name': 'test'}, 'chapter': {'name': 'gateways'},
            'lexicon': lexicon or {},
            'glyphs': {'istio': {'observe': {'type': 'telemetry', **definition}}},
        }
        with tempfile.NamedTemporaryFile(mode='w', suffix='.yaml') as f:
            yaml.safe_dump(values, f)
            f.flush()
            result = subprocess.run(
                ['helm', 'template', 'test', os.environ['KASTER_CHART'],
                 '-n', 'release-ns', '-f', f.name], capture_output=True, text=True)
        if error:
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(error, result.stderr)
            return []
        self.assertEqual(result.returncode, 0, result.stderr)
        return [d for d in yaml.safe_load_all(result.stdout) if d]

    @staticmethod
    def gateway(namespace='ingress', selector=None, **labels):
        return {'type': 'istio-gw', 'gateway': namespace + '/gateway',
                'workloadSelector': selector or {'istio': 'public'},
                'chapter': 'gateways', 'labels': labels}

    def test_indexer_defaults_and_exact_selector(self):
        lexicon = {'book': self.gateway(default='book'),
                   'chapter': self.gateway('chapter-ns', default='chapter'),
                   'private': self.gateway('private-ns', access='private')}
        docs = self.render({}, lexicon)
        self.assertEqual(docs[0]['metadata']['namespace'], 'chapter-ns')
        docs = self.render({'selector': {'access': 'private'}}, lexicon)
        self.assertEqual(docs[0]['metadata']['namespace'], 'private-ns')
        self.assertEqual(docs[0]['spec']['selector']['matchLabels'], {'istio': 'public'})
        # Preserve Runic Indexer fallback semantics for an unmatched selector.
        docs = self.render({'selector': {'access': 'missing'}}, lexicon)
        self.assertEqual(docs[0]['metadata']['namespace'], 'chapter-ns')
        docs = self.render({}, {'book': lexicon['book']})
        self.assertEqual(docs[0]['metadata']['namespace'], 'ingress')

    def test_aliases_coalesce_and_distinct_proxies_get_stable_names(self):
        lexicon = {'a': self.gateway(access='external'),
                   'alias': self.gateway(access='external'),
                   'other': self.gateway(selector={'istio': 'other'}, access='external')}
        definition = {'selector': {'access': 'external'}}
        docs = self.render(definition, lexicon)
        self.assertEqual(len(docs), 2)
        names = {d['metadata']['name'] for d in docs}
        self.assertEqual(len(names), 2)
        self.assertEqual(names, {d['metadata']['name'] for d in self.render(definition, lexicon)})

    def test_explicit_workload_passes_native_signals_without_gateway_defaults(self):
        signals = {'accessLogging': [{'disabled': True}],
                   'tracing': [{'randomSamplingPercentage': 0}],
                   'metrics': [{'overrides': [{'disabled': True}]}]}
        docs = self.render(dict(target={'namespace': 'apps', 'workloadSelector': {'app': 'api'}}, **signals))
        expected = dict(selector={'matchLabels': {'app': 'api'}}, **signals)
        self.assertEqual(docs[0]['spec'], expected)
        self.assertEqual(docs[0]['metadata']['namespace'], 'apps')

    def test_target_refs_and_namespace_scope(self):
        refs = [{'group': '', 'kind': 'Service', 'name': 'api'}]
        docs = self.render({'target': {'targetRefs': refs}})
        self.assertEqual(docs[0]['spec'], {'targetRefs': refs})
        docs = self.render({'target': {'namespace': 'apps', 'scope': 'namespace'}})
        self.assertEqual(docs[0]['spec'], {})

    def test_disabled_and_invalid_associations(self):
        self.assertEqual(self.render({'enabled': False}), [])
        self.render({}, error='no istio-gw found')
        self.render({'target': {}}, error='exactly one')
        self.render({'target': {'scope': 'namespace'}, 'selector': {}}, error='mutually exclusive')
        self.render({'target': {'scope': 'namespace', 'workloadSelector': {'app': 'api'}}}, error='exactly one')
        self.render({'namespace': 'one', 'target': {'namespace': 'two', 'scope': 'namespace'}}, error='conflicting namespaces')
        gateway = self.gateway(default='book')
        del gateway['workloadSelector']
        self.render({}, {'broken': gateway}, error='requires workloadSelector')

    def test_meta_glyph_reuses_telemetry_and_deduplicates_dashboard(self):
        docs = self.render({'type': 'gatewayObservability', 'selector': {'access': 'external'},
                            'accessLogs': {'provider': 'json'},
                            'tracing': [{'randomSamplingPercentage': 100}]},
                           {'a': self.gateway(access='external'), 'alias': self.gateway(access='external')})
        self.assertEqual(len(docs), 2)
        telemetry = next(d for d in docs if d['kind'] == 'Telemetry')
        self.assertEqual(telemetry['spec']['tracing'], [{'randomSamplingPercentage': 100}])
        self.assertIn('>= 400', telemetry['spec']['accessLogging'][0]['filter']['expression'])
        cm = next(d for d in docs if d['kind'] == 'ConfigMap')
        dashboard = json.loads(cm['data']['gateway-errors.json'])
        self.assertEqual(len(dashboard['panels']), 9)
        self.assertNotIn('__GATEWAY_NAMESPACE__', json.dumps(dashboard))


if __name__ == '__main__':
    unittest.main()

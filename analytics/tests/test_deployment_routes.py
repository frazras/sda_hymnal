import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import deploy

class DeploymentRouteTest(unittest.TestCase):
    def test_native_trends_has_matching_route_and_scoped_invoke_permission(self):
        resources = deploy.template()['Resources']
        self.assertEqual(resources['NativeTrendsRoute']['Properties']['RouteKey'], 'GET /v2/trends')
        permission = resources['NativeTrendsPermission']['Properties']
        self.assertEqual(permission['Principal'], 'apigateway.amazonaws.com')
        self.assertTrue(permission['SourceArn']['Fn::Sub'].endswith('/*/GET/v2/trends'))
        self.assertEqual(permission['FunctionName'], {'Ref': 'Collector'})
        self.assertTrue(resources['InvokePermission']['Properties']['SourceArn']['Fn::Sub'].endswith('/*/*/v1/*'))

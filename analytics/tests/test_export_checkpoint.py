import io
import json
from pathlib import Path
import sys
import unittest
from unittest.mock import Mock, patch
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'server'))
import export_checkpoint

class CheckpointTest(unittest.TestCase):
    def test_state_stays_in_private_namespace_and_round_trips(self):
        s3 = Mock()
        state = {'revision': 2, 'complete': False, 'cursor': {'pk': 'next'}, 'rows': []}
        export_checkpoint.save_job(s3, 'bucket', 'e2e', 'a' * 32, state)
        request = s3.put_object.call_args.kwargs
        self.assertEqual(request['Key'], 'reports/e2e/export-jobs/' + 'a' * 32 + '.json')
        s3.get_object.return_value = {'Body': io.BytesIO(request['Body'])}
        self.assertEqual(export_checkpoint.load_job(s3, 'bucket', 'e2e', 'a' * 32), state)
        for namespace, job in [('other', 'a' * 32), ('prod', '../escape'), ('prod', None)]:
            with self.assertRaises(ValueError):
                export_checkpoint.job_key(namespace, job)

    @patch.object(export_checkpoint.boto3, 'client')
    def test_continuation_queues_expected_revision_and_rejects_failed_acceptance(self, client):
        context = Mock(invoked_function_arn='exporter')
        client.return_value.invoke.return_value = {'StatusCode': 202}
        export_checkpoint.continue_job(context, 'e2e', 'a' * 32, 2, True)
        call = client.return_value.invoke.call_args.kwargs
        self.assertEqual(call['InvocationType'], 'Event')
        self.assertEqual(call['FunctionName'], 'exporter')
        self.assertEqual(json.loads(call['Payload']), {'namespace': 'e2e',
            'job_id': 'a' * 32, 'revision': 2, 'preview': True})
        client.return_value.invoke.return_value = {'StatusCode': 500}
        with self.assertRaises(RuntimeError):
            export_checkpoint.continue_job(context, 'e2e', 'a' * 32, 2, True)

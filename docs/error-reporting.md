# Error reporting

Every hymn reader has **Report Errors** in its options menu. Additional readings have the same entry in their options menu. The form starts with the selected title. English hymns and additional readings submit their stable ID, edition and number alongside the user's description. Non-English hymn readers currently open a general report with the native book label, number and title prefilled, because the deployed API accepts only `old`/`new` edition IDs. Native-book report schema deployment remains a roadmap item. **Settings → More → Report Errors** opens a general report with no selected content.

Submission is explicit, requires internet access, and works independently of the usage-statistics switch. A failed submission keeps the form open with its text. Retrying that form uses the same random report ID so a lost response does not create a duplicate. Closing an unsent form discards its text.

The private admin dashboard has a **Fixes required** list and **Download all reports (CSV)**. It loads every page before enabling export; the list covers all dates/platforms, independently of the analytics filters. CSV preserves multiline descriptions and protects against spreadsheet formula interpretation. All reports initially have status `open`; this feature does not include a resolution workflow.

## Deployment

Deploy the collector stack first, then the admin stack, before releasing the app:

```sh
python3 analytics/deploy.py
python3 analytics/admin_deploy.py
```

The collector deployment adds a retained `ErrorReports` DynamoDB table and public `POST /v1/error-reports` behind the existing CloudFront origin verification and API throttling. The table has no report expiry field populated. The collector can only write reports; the admin Lambda can query them using the existing Cognito admins access-token authorization on `GET /v1/admin/error-reports`. Admin pagination uses the last report ID as its cursor. Submitted text is never included in public community statistics or request logs.

Deployment state is read from `build/analytics/deployment.json`; redeploying the collector populates the new `ErrorReports` output required by the admin deployment. Existing analytics resources are preserved. The deployment also publishes the updated privacy policy.

## Checks

```sh
flutter test --no-pub test/error_report_test.dart test/additional_readings_test.dart
python3 -m unittest discover -s analytics/tests
node --test analytics/tests/error_reports.test.mjs
```

After deployment, submit a report on a controlled app build, check that the authenticated admin list and CSV contain it, and confirm unauthenticated admin requests fail.

The form follows the interface language while preserving source titles and user
descriptions. A locale change does not translate submitted content or alter API
field names. Translation tests cover validation, failed submission, retained text,
and retry IDs across compact Modern/Classic light/dark layouts.

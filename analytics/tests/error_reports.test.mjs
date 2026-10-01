import test from 'node:test';
import assert from 'node:assert/strict';
import {reportsCsv, fetchReports} from '../admin-web/error-reports.mjs';

test('CSV retains multiline text, commas and quotes and neutralizes formulas', () => {
  const csv = reportsCsv([{title: 'A, "title"', description: '=HYPERLINK("bad")\nsecond line'}]);
  assert.ok(csv.startsWith('\uFEFF'));
  assert.ok(csv.includes('"A, ""title"""'));
  assert.ok(csv.includes('"\'=HYPERLINK(""bad"")\nsecond line"'));
  assert.ok(reportsCsv([{title: '  +SUM(1)'}]).includes("'  +SUM(1)"));
});

test('loads every page with authorization and sorts by date', async () => {
  const calls = [];
  const rows = await fetchReports('https://example.test', 'token', async (url, options) => {
    calls.push(url);
    assert.equal(options.headers.Authorization, 'Bearer token');
    return {ok: true, json: async () => calls.length === 1
      ? {reports: [{id: 'old', created_at: '2026-09-01'}], cursor: 'next'}
      : {reports: [{id: 'new', created_at: '2026-09-28'}], cursor: null}};
  });
  assert.equal(calls.length, 2);
  assert.ok(calls[1].endsWith('?cursor=next'));
  assert.deepEqual(rows.map(row => row.id), ['new', 'old']);
});

test('a later page failure never returns a partial export', async () => {
  let count = 0;
  await assert.rejects(fetchReports('', 'token', async () => ++count === 1
    ? {ok: true, json: async () => ({reports: [{}], cursor: 'next'})}
    : {ok: false, status: 503}));
});

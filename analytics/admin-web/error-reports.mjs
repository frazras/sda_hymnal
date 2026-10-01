export const reportColumns = ['id', 'created_at', 'status', 'kind', 'edition', 'number', 'item_id', 'title', 'description', 'version'];

export function reportsCsv(reports) {
  const cell = value => {
    let text = String(value ?? '');
    // Quoting alone does not stop spreadsheet formulas in user-submitted text.
    if (/^[\s\uFEFF]*[=+@-]/u.test(text) || /^[\t\r\n]/u.test(text)) text = "'" + text;
    return '"' + text.replaceAll('"', '""') + '"';
  };
  return '\uFEFF' + [reportColumns, ...reports.map(row => reportColumns.map(key => row[key]))]
    .map(row => row.map(cell).join(',')).join('\r\n') + '\r\n';
}

export async function fetchReports(api, token, fetcher = fetch) {
  const reports = [];
  const seen = new Set();
  let cursor;
  do {
    const response = await fetcher(api + '/v1/admin/error-reports' +
      (cursor ? '?' + new URLSearchParams({cursor}) : ''), {
      headers: {Authorization: 'Bearer ' + token}, cache: 'no-store',
      credentials: 'omit', signal: AbortSignal.timeout(15000),
    });
    if (!response.ok) throw new Error(response.status === 401 || response.status === 403
      ? 'Please sign in again to view error reports.' : 'Error reports could not be loaded. Try again.');
    const page = await response.json();
    if (!Array.isArray(page.reports)) throw new Error('Invalid error report response.');
    reports.push(...page.reports);
    cursor = page.cursor;
    if (cursor && seen.has(cursor)) throw new Error('Error report pagination failed. Try again.');
    if (cursor) seen.add(cursor);
  } while (cursor);
  return reports.sort((a, b) => String(b.created_at).localeCompare(String(a.created_at)));
}

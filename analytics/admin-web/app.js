const $ = id => document.getElementById(id);
const format = new Intl.NumberFormat('en-US', {maximumFractionDigits: 1});
const countryNames = new Intl.DisplayNames(['en'], {type: 'region'});
let config, token, report;
const stateKey = 'hymnal-admin-oauth';

function element(tag, text, className) {
  const node = document.createElement(tag);
  if (text !== undefined) node.textContent = text;
  if (className) node.className = className;
  return node;
}
function svg(tag, attrs) {
  const node = document.createElementNS('http://www.w3.org/2000/svg', tag);
  for (const [key, value] of Object.entries(attrs)) node.setAttribute(key, value);
  return node;
}
const pretty = value => String(value).replaceAll('_', ' ').replace(/\b\w/g, c => c.toUpperCase());
const date = value => new Date(value.length === 10 ? value + 'T12:00:00Z' : value).toLocaleDateString('en-GB', {day: 'numeric', month: 'short', year: 'numeric'});
const random = () => btoa(String.fromCharCode(...crypto.getRandomValues(new Uint8Array(32)))).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
function status(message) { $('status').textContent = message; }

async function login() {
  const verifier = random(), state = random();
  const hashed = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(verifier));
  const challenge = btoa(String.fromCharCode(...new Uint8Array(hashed))).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
  sessionStorage.setItem(stateKey, JSON.stringify({verifier, state, created: Date.now()}));
  const query = new URLSearchParams({client_id: config.clientId, response_type: 'code', redirect_uri: config.redirect,
    scope: 'openid aws.cognito.signin.user.admin', state, code_challenge: challenge, code_challenge_method: 'S256'});
  location.assign(config.authDomain + '/oauth2/authorize?' + query);
}

async function callback() {
  const query = new URLSearchParams(location.search);
  if (!query.has('code') && !query.has('error')) return;
  // Remove authorization material from the address bar before any API fetch.
  history.replaceState(null, '', '/');
  const saved = sessionStorage.getItem(stateKey);
  sessionStorage.removeItem(stateKey);
  const pending = saved ? JSON.parse(saved) : null;
  if (query.has('error') || !pending || pending.state !== query.get('state') || Date.now() - pending.created > 600000) {
    throw new Error('Sign-in could not be verified. Please sign in again.');
  }
  const response = await fetch(config.authDomain + '/oauth2/token', {method: 'POST',
    headers: {'Content-Type': 'application/x-www-form-urlencoded'}, signal: AbortSignal.timeout(20000),
    body: new URLSearchParams({grant_type: 'authorization_code', client_id: config.clientId,
      redirect_uri: config.redirect, code: query.get('code'), code_verifier: pending.verifier})});
  if (!response.ok) throw new Error('Sign-in expired. Please sign in again.');
  const result = await response.json();
  token = result.access_token;
  // Tokens live only in this page's memory. Reloading uses the Cognito session.
  await loadReport();
}

async function loadReport() {
  if (!token) return;
  $('refresh').disabled = true;
  status('Loading the latest daily report…');
  try {
    const response = await fetch(config.api + '/v1/admin/overview', {headers: {Authorization: 'Bearer ' + token},
      cache: 'no-store', credentials: 'omit', signal: AbortSignal.timeout(15000)});
    if (response.status === 401 || response.status === 403) {
      token = null; report = null;
      $('dashboard').hidden = true; $('login').hidden = false; $('logout').hidden = false;
      throw new Error(response.status === 403 ? 'This account does not have administrator access.' : 'Your session expired. Please sign in again.');
    }
    if (!response.ok) throw new Error('The report is temporarily unavailable. Please try again.');
    report = await response.json();
    if (report.schema !== 1 || !report.periods) throw new Error('This report format is unavailable.');
    $('login').hidden = true; $('dashboard').hidden = false; $('logout').hidden = false;
    render(); status('');
  } finally { $('refresh').disabled = false; }
}

function bars(id, rows, label = row => pretty(row.label), limit = 10) {
  const target = $(id); target.replaceChildren();
  const selected = rows.slice(0, limit);
  if (!selected.length) { target.append(element('p', 'No submitted activity in this period.', 'no-data')); return; }
  const max = Math.max(1, ...selected.map(r => Number(r.count)));
  for (const row of selected) {
    const wrap = element('div', undefined, 'bar-row');
    const caption = element('div', undefined, 'bar-label');
    const name = element('span', label(row));
    if (row.edition) name.append(element('small', pretty(row.edition) + ' ' + row.hymn, 'song-edition'));
    caption.append(name, element('strong', format.format(row.count)));
    const chart = svg('svg', {viewBox: '0 0 100 7', preserveAspectRatio: 'none', class: 'bar-svg', 'aria-hidden': 'true'});
    chart.append(svg('rect', {width: 100, height: 7, class: 'bar-track'}),
      svg('rect', {width: Math.max(0, Number(row.count) / max * 100), height: 7, class: 'bar-fill'}));
    wrap.append(caption, chart); target.append(wrap);
  }
}

function facts(id, rows) {
  $(id).replaceChildren(...rows.map(([label, value]) => {
    const row = element('div', undefined, 'fact');
    row.append(element('span', label), element('strong', value)); return row;
  }));
}

function weekly(rows) {
  const target = $('weekly'); target.replaceChildren();
  const max = Math.max(1, ...rows.map(r => r.count));
  const chart = svg('svg', {viewBox: '0 0 600 160', class: 'weekly-chart', role: 'img',
    'aria-label': rows.map(r => `${date(r.week)}: ${format.format(r.count)} opens`).join('; ')});
  for (const y of [10, 75, 140]) chart.append(svg('line', {x1: 10, x2: 590, y1: y, y2: y, class: 'chart-grid'}));
  const points = rows.map((r, i) => [rows.length === 1 ? 300 : 10 + i / (rows.length - 1) * 580, 140 - r.count / max * 125]);
  chart.append(svg('polyline', {points: points.map(p => p.join(',')).join(' '), class: 'chart-line'}));
  points.forEach(([cx, cy], i) => { const point = svg('circle', {cx, cy, r: 4, class: 'chart-point'});
    const title = svg('title', {}); title.textContent = `${date(rows[i].week)}: ${format.format(rows[i].count)} opens`;
    point.append(title); chart.append(point); });
  const labels = element('div', undefined, 'chart-labels');
  rows.forEach(r => labels.append(element('span', `${date(r.week)} · ${format.format(r.count)}`)));
  target.append(chart, labels);
}

function render() {
  const period = report.periods[$('period').value];
  const data = period.platforms[$('platform').value];
  const total = metric => Number(data.totals[metric] || 0);
  const duration = metric => Number(data.durations[metric] || 0);
  const number = metric => format.format(total(metric));
  $('range').textContent = `${date(period.start)} – ${date(period.end)}${period.partial ? ' · incomplete' : ''}`;
  $('generated').textContent = 'Report generated ' + date(report.generated);
  $('empty').hidden = Object.values(data.totals).some(n => n > 0);
  $('kpis').replaceChildren(...[
    ['Hymn opens', number('hymn_open'), 'All entry points'], ['App sessions', number('app_session'), 'Not unique installations'],
    ['Reading hours', format.format(duration('hymn_read_seconds') / 3600), 'Active foreground time'],
    ['Repeat opens', number('hymn_repeat'), 'Within a calendar week'], ['Playback errors', number('play_error'), 'Categorized error events'],
  ].map(([label, value, note]) => { const card = element('div', undefined, 'card kpi');
    card.append(element('small', label), element('strong', value), element('span', note)); return card; }));
  weekly(data.weekly);
  bars('songs', data.top_songs, r => r.title); bars('repeats', data.repeat_songs, r => r.title);
  bars('favorites', data.favorites, r => r.title); bars('features', data.features); bars('sources', data.sources);
  bars('screen-time', data.screen_seconds, r => pretty(r.label) + ' · seconds');
  bars('search', data.search_results, r => ({zero: 'No results', '1_5': '1–5 results', '6_20': '6–20 results', '21_plus': '21+ results'}[r.label] || r.label));
  facts('search-summary', [['Search selections', number('search_select')], ['Refinements', number('search_refine')],
    ['Abandon events', number('search_abandon')], ['Mean time to select', total('search_select_ms') ? format.format(duration('search_select_ms') / total('search_select_ms') / 1000) + ' s' : 'No samples']]);
  facts('playback', [['Attempts', number('play_attempt')], ['Successful starts', number('play_start')], ['Completions', number('play_complete')],
    ['Errors / attempts', total('play_attempt') ? format.format(total('play_error') / total('play_attempt') * 100) + '%' : 'No attempts'],
    ['Mean start time', total('play_start_ms') ? format.format(duration('play_start_ms') / total('play_start_ms')) + ' ms' : 'No samples']]);
  bars('errors', data.errors); bars('settings', data.settings);
  bars('times', ['night', 'morning', 'afternoon', 'evening'].map(label => ({label, count: data.times.find(r => r.label === label)?.count || 0})),
    r => ({night: '12–6 am', morning: '6 am–12 pm', afternoon: '12–6 pm', evening: '6 pm–12 am'}[r.label]));
  bars('weekdays', ['1', '2', '3', '4', '5', '6', '7'].map(label => ({label, count: data.weekdays.find(r => r.label === label)?.count || 0})),
    r => ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][Number(r.label) - 1]);
  bars('countries', data.countries, r => r.label === 'ZZ' ? 'Unknown' : countryNames.of(r.label));
  $('versions').replaceChildren(...data.versions.map(row => { const tr = element('tr');
    [pretty(row.platform) + ' / ' + row.version, ...['sessions', 'opens', 'play_attempts', 'play_errors', 'diagnostics'].map(k => format.format(row[k]))]
      .forEach(value => tr.append(element('td', value))); return tr; }));
  $('measurements').replaceChildren(...Object.keys(data.totals).sort().map(metric => { const tr = element('tr');
    [pretty(metric), number(metric), format.format(duration(metric))].forEach(value => tr.append(element('td', value))); return tr; }));
}

$('signin').disabled = true;
$('signin').addEventListener('click', () => login().catch(() => status('Sign-in is unavailable. Please try again.')));
$('logout').addEventListener('click', () => {
  token = null; report = null; sessionStorage.removeItem(stateKey);
  $('dashboard').hidden = true; $('login').hidden = false;
  location.assign(config.authDomain + '/logout?' + new URLSearchParams({client_id: config.clientId, logout_uri: config.redirect}));
});
$('refresh').addEventListener('click', () => loadReport().catch(e => status(e.message)));
for (const id of ['period', 'platform']) $(id).addEventListener('change', render);
try {
  const response = await fetch('config.json', {cache: 'no-store', signal: AbortSignal.timeout(15000)});
  if (!response.ok) throw new Error('Dashboard configuration is unavailable.');
  config = await response.json(); $('signin').disabled = false; status('');
  await callback();
} catch (error) { status(error.message || 'The dashboard is unavailable. Please reload.'); }

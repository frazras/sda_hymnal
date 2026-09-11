-- Run in Athena database sdahymnal_analytics, workgroup sdahymnal-analytics.
-- These developer queries use the last four completed reporting weeks.
-- Counts are participating installations' actions, not all users or people.

-- Feature popularity.
SELECT metric, variant, sum("count") AS actions
FROM metrics
WHERE week >= cast(date_add('week', -4, date_trunc('week', current_date)) AS varchar)
  AND week < cast(date_trunc('week', current_date) AS varchar)
  AND metric IN ('screen_view', 'hymn_open', 'play_start', 'story_open',
                 'video_open', 'chord_chart_open', 'auto_scroll_start')
GROUP BY metric, variant
ORDER BY actions DESC;

-- Hymns by country, weekday and broad time. Do not sum contributors as uniques.
SELECT edition, hymn, country, weekday, "time", sum("count") AS opens
FROM metrics
WHERE week >= cast(date_add('week', -4, date_trunc('week', current_date)) AS varchar)
  AND week < cast(date_trunc('week', current_date) AS varchar)
  AND metric = 'hymn_open'
GROUP BY edition, hymn, country, weekday, "time"
ORDER BY opens DESC
LIMIT 100;

-- Favorite additions since statistics were enabled; not saved-list size.
SELECT edition, hymn, sum("count") AS additions
FROM metrics
WHERE week >= cast(date_add('week', -4, date_trunc('week', current_date)) AS varchar)
  AND week < cast(date_trunc('week', current_date) AS varchar)
  AND metric = 'favorite_add'
GROUP BY edition, hymn
ORDER BY additions DESC
LIMIT 100;

-- Search quality signals. Refines and abandonments are signals, not verdicts.
SELECT platform, version, design, metric, variant, sum("count") AS samples,
       sum(total) * 1.0 / nullif(sum("count"), 0) AS mean_milliseconds
FROM metrics
WHERE week >= cast(date_add('week', -4, date_trunc('week', current_date)) AS varchar)
  AND week < cast(date_trunc('week', current_date) AS varchar)
  AND metric IN ('search_results', 'search_select', 'search_refine',
                 'search_abandon', 'search_select_ms')
GROUP BY platform, version, design, metric, variant;

-- Playback reliability/performance and categorized diagnostics by app version.
-- Mean is useful only for play_start_ms; use action counts for other metrics.
SELECT platform, version, metric, variant, sum("count") AS samples,
       sum(total) * 1.0 / nullif(sum("count"), 0) AS mean_milliseconds
FROM metrics
WHERE week >= cast(date_add('week', -4, date_trunc('week', current_date)) AS varchar)
  AND week < cast(date_trunc('week', current_date) AS varchar)
  AND metric IN ('play_attempt', 'play_start', 'play_error', 'play_start_ms',
                 'video_error', 'diagnostic')
GROUP BY platform, version, metric, variant;

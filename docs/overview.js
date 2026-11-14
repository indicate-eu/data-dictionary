/**
 * Overview page (#/overview) — validation status of the dictionary at a glance.
 *
 * Counts concept sets per review status (the workflow configured in config.json
 * `reviewStatuses`, see App.reviewStatuses), overall and per category, with each
 * category expandable into its subcategories. Every count links to the catalog
 * filtered on that category and status (#/concept-sets?category=…&status=…).
 *
 * Deprecated sets are left out by default: they are no longer part of the
 * dictionary, so counting them would understate how far validation has gone.
 * Reads App.getCSData(), i.e. what the catalog shows, local edits included.
 */
var OverviewPage = (function () {
  'use strict';

  var initialized = false;
  var includeDeprecated = false;
  var expanded = {};            // category label -> true when its subcategories show

  function en() { return App.lang === 'en'; }
  function tr(enText, frText) { return en() ? enText : frText; }
  function esc(s) { return App.escapeHtml(s == null ? '' : String(s)); }

  function pct(n, total) {
    if (!total) return '0%';
    var p = n / total * 100;
    // One decimal below 10% so a small but non-zero share never reads "0%".
    return (p > 0 && p < 10 ? p.toFixed(1) : Math.round(p)) + '%';
  }

  function hasReviews(d) {
    var reviews = (d.raw && d.raw.metadata && d.raw.metadata.reviews) || [];
    var session = (App.sessionReviews && App.sessionReviews[d.id]) || [];
    return reviews.length + session.length > 0;
  }

  // Statuses shown as columns: the configured workflow in order (deprecated only
  // when included), then any undeclared status actually present in the data.
  function statusColumns(rows) {
    var cols = App.reviewStatuses.map(function(s) { return s.id; })
      .filter(function(id) { return includeDeprecated || id !== 'deprecated'; });
    rows.forEach(function(d) {
      if (cols.indexOf(d.reviewStatus) === -1 && (includeDeprecated || d.reviewStatus !== 'deprecated')) cols.push(d.reviewStatus);
    });
    return cols;
  }

  function tally(rows, cols) {
    var t = { total: rows.length, reviewed: 0, by: {} };
    cols.forEach(function(c) { t.by[c] = 0; });
    rows.forEach(function(d) {
      t.by[d.reviewStatus] = (t.by[d.reviewStatus] || 0) + 1;
      if (hasReviews(d)) t.reviewed += 1;
    });
    return t;
  }

  function catalogUrl(category, status) {
    var params = [];
    if (category) params.push('category=' + encodeURIComponent(category));
    if (status) params.push('status=' + encodeURIComponent(status));
    if (!en()) params.push('lang=fr');
    return '#/concept-sets' + (params.length ? '?' + params.join('&') : '');
  }

  // Inline style of a status, from the same source as its badge.
  function statusStyle(id) {
    var def = App.reviewStatuses.filter(function(s) { return s.id === id; })[0];
    if (!def) return 'background:#e9ecef;color:#495057';
    return 'background:' + def.background + ';color:' + def.color;
  }

  // Horizontal 100% bar, one segment per status. Segments are separated by a
  // 2px surface gap and carry a hover tooltip (label, count, share), so the
  // reading never depends on telling two colors apart.
  function stackedBar(t, cols, big) {
    if (!t.total) return '<div class="ov-bar' + (big ? ' ov-bar-lg' : '') + ' ov-bar-empty"></div>';
    var html = '<div class="ov-bar' + (big ? ' ov-bar-lg' : '') + '">';
    cols.forEach(function(c) {
      var n = t.by[c] || 0;
      if (!n) return;
      var tip = App.statusLabel(c) + ': ' + n + ' (' + pct(n, t.total) + ')';
      html += '<span class="ov-seg" style="flex:' + n + ';' + statusStyle(c) + '" data-tooltip="' + esc(tip) + '">' +
        (big && n / t.total >= 0.06 ? esc(pct(n, t.total)) : '') + '</span>';
    });
    return html + '</div>';
  }

  function render() {
    var root = document.getElementById('overview-content');
    if (!root) return;
    var all = App.getCSData();
    var rows = includeDeprecated ? all : all.filter(function(d) { return d.reviewStatus !== 'deprecated'; });
    var deprecatedCount = all.length - all.filter(function(d) { return d.reviewStatus !== 'deprecated'; }).length;
    var cols = statusColumns(rows);
    var total = tally(rows, cols);

    // ---- Header ----
    var html = '<div class="ov-header">'
      + '<div><h2>' + esc(tr('Dictionary overview', 'Vue d’ensemble du dictionnaire')) + '</h2>'
      + '<p class="ov-sub">' + esc(tr(
          'Validation status of the ' + total.total + ' ' + (includeDeprecated ? '' : 'active ') + 'concept sets, by category.',
          'Statut de validation des ' + total.total + ' jeux de concepts' + (includeDeprecated ? '' : ' actifs') + ', par catégorie.'))
      + (!includeDeprecated && deprecatedCount ? ' ' + esc(tr(deprecatedCount + ' deprecated sets are not counted.',
          deprecatedCount + ' jeux obsolètes ne sont pas comptés.')) : '')
      + '</p></div>'
      + '<label class="ov-toggle"><input type="checkbox" id="ov-include-deprecated"' + (includeDeprecated ? ' checked' : '') + '> '
      + esc(tr('Include deprecated', 'Inclure les obsolètes')) + '</label>'
      + '</div>';

    // ---- Tiles: one per status ----
    html += '<div class="ov-tiles">';
    cols.forEach(function(c) {
      var n = total.by[c] || 0;
      html += '<a class="ov-tile" href="' + esc(catalogUrl(null, c)) + '">'
        + '<span class="ov-tile-swatch" style="' + statusStyle(c) + '"></span>'
        + '<span class="ov-tile-label">' + esc(App.statusLabel(c)) + '</span>'
        + '<span class="ov-tile-value">' + n + '</span>'
        + '<span class="ov-tile-pct">' + esc(pct(n, total.total)) + '</span>'
        + (App.statusDescription(c) ? '<span class="ov-tile-desc">' + esc(App.statusDescription(c)) + '</span>' : '')
        + '</a>';
    });
    html += '</div>';

    // ---- Overall bar ----
    html += '<div class="ov-card">' + stackedBar(total, cols, true) + '</div>';

    // ---- Table by category ----
    var byCat = {};
    rows.forEach(function(d) {
      var cat = d.category || tr('(no category)', '(sans catégorie)');
      (byCat[cat] = byCat[cat] || []).push(d);
    });
    var cats = Object.keys(byCat).sort(function(a, b) { return a.localeCompare(b); });

    html += '<div class="ov-card ov-table-card"><table class="ov-table"><thead><tr>'
      + '<th>' + esc(tr('Category', 'Catégorie')) + '</th>'
      + '<th class="ov-col-bar">' + esc(tr('Distribution', 'Répartition')) + '</th>';
    // Header badges stay on one line, truncated with an ellipsis: the tooltip
    // carries the full label and the definition.
    cols.forEach(function(c) {
      var tip = App.statusLabel(c) + (App.statusDescription(c) ? ' \u2014 ' + App.statusDescription(c) : '');
      html += '<th class="ov-num">' + App.statusBadge(c, { 'data-tooltip': tip }) + '</th>';
    });
    html += '<th class="ov-num">' + esc(tr('Total', 'Total')) + '</th>'
      + '<th class="ov-num" data-tooltip="' + esc(tr('Concept sets with at least one recorded review, whatever its verdict.',
          'Jeux de concepts avec au moins une relecture enregistrée, quel que soit son verdict.')) + '">'
      + esc(tr('With reviews', 'Avec relectures')) + '</th>'
      + '</tr></thead><tbody>';

    function rowHtml(label, t, opts) {
      var cls = opts.sub ? 'ov-subrow' : 'ov-catrow';
      var first = opts.sub
        ? '<td class="ov-subname">' + esc(label) + '</td>'
        : '<td><button class="ov-expand" data-cat="' + esc(label) + '" aria-expanded="' + (expanded[label] ? 'true' : 'false') + '">'
          + '<i class="fas fa-chevron-' + (expanded[label] ? 'down' : 'right') + '"></i></button> '
          + '<a href="' + esc(catalogUrl(label, null)) + '">' + esc(label) + '</a></td>';
      var r = '<tr class="' + cls + '">' + first + '<td class="ov-col-bar">' + stackedBar(t, cols, false) + '</td>';
      cols.forEach(function(c) {
        var n = t.by[c] || 0;
        var cell = n ? (opts.sub ? String(n) : '<a href="' + esc(catalogUrl(label, c)) + '">' + n + '</a>') : '<span class="ov-zero">–</span>';
        r += '<td class="ov-num">' + cell + '</td>';
      });
      r += '<td class="ov-num ov-total">' + t.total + '</td>'
        + '<td class="ov-num">' + t.reviewed + ' <span class="ov-muted">(' + esc(pct(t.reviewed, t.total)) + ')</span></td></tr>';
      return r;
    }

    cats.forEach(function(cat) {
      var catRows = byCat[cat];
      html += rowHtml(cat, tally(catRows, cols), { sub: false });
      if (!expanded[cat]) return;
      var bySub = {};
      catRows.forEach(function(d) {
        var sub = d.subcategory || tr('(no subcategory)', '(sans sous-catégorie)');
        (bySub[sub] = bySub[sub] || []).push(d);
      });
      Object.keys(bySub).sort(function(a, b) { return a.localeCompare(b); }).forEach(function(sub) {
        html += rowHtml(sub, tally(bySub[sub], cols), { sub: true });
      });
    });

    html += '</tbody><tfoot>' + rowHtml(tr('All categories', 'Toutes catégories'), total, { sub: true }) + '</tfoot></table></div>';

    root.innerHTML = html;
  }

  function init() {
    if (initialized) return;
    initialized = true;
    var root = document.getElementById('overview-content');
    root.addEventListener('change', function(e) {
      if (e.target && e.target.id === 'ov-include-deprecated') {
        includeDeprecated = e.target.checked;
        render();
      }
    });
    root.addEventListener('click', function(e) {
      var btn = e.target.closest('.ov-expand');
      if (!btn) return;
      var cat = btn.getAttribute('data-cat');
      expanded[cat] = !expanded[cat];
      render();
    });
  }

  function show() {
    init();
    render();
  }

  function hide() {}

  // Categories and labels are language-specific: rebuild, and drop the expanded
  // state, which is keyed by the previous language's labels.
  function onLanguageChange() {
    expanded = {};
    if (document.getElementById('page-overview').style.display !== 'none') render();
  }

  return { show: show, hide: hide, onLanguageChange: onLanguageChange };
})();

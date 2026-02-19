/**
 * Dev Tools page module — SQL Editor + Schema/ERD
 */
var DevToolsPage = (function () {
  'use strict';

  var initialized = false;

  /* ── State ──────────────────────────────────────────── */

  var activeTab = 'sql';
  var lastQueryRows = null;
  var lastQueryCols = null;
  var currentPage = 0;
  var PAGE_SIZE = 50;

  var sqlEditor = null;

  var erdScale = 1;
  var erdTranslateX = 0;
  var erdTranslateY = 0;
  var erdIsDragging = false;
  var erdDragStartX = 0;
  var erdDragStartY = 0;
  var erdInitialized = false;

  /* ── Example queries ────────────────────────────────── */

  var EXAMPLE_QUERIES = [
    {
      label: 'Top 20 vocabularies by concept count',
      sql: 'SELECT vocabulary_id, COUNT(*) AS cnt\nFROM concept\nGROUP BY vocabulary_id\nORDER BY cnt DESC\nLIMIT 20'
    },
    {
      label: 'Search concepts by name (heart rate)',
      sql: "SELECT concept_id, concept_name, vocabulary_id, domain_id, standard_concept\nFROM concept\nWHERE LOWER(concept_name) LIKE '%heart rate%'\nAND standard_concept = 'S'\nLIMIT 50"
    },
    {
      label: 'Descendants of concept 4329847',
      sql: 'SELECT c.concept_id, c.concept_name, c.vocabulary_id, ca.min_levels_of_separation\nFROM concept_ancestor ca\nJOIN concept c ON c.concept_id = ca.descendant_concept_id\nWHERE ca.ancestor_concept_id = 4329847\nORDER BY ca.min_levels_of_separation\nLIMIT 50'
    },
    {
      label: 'Mapped concepts for 4329847',
      sql: "SELECT cr.relationship_id, c.concept_id, c.concept_name, c.vocabulary_id, c.standard_concept\nFROM concept_relationship cr\nJOIN concept c ON c.concept_id = cr.concept_id_2\nWHERE cr.concept_id_1 = 4329847\nAND cr.relationship_id = 'Maps to'\nLIMIT 50"
    },
    {
      label: 'All domains',
      sql: 'SELECT * FROM domain ORDER BY domain_id'
    },
    {
      label: 'All vocabularies',
      sql: 'SELECT vocabulary_id, vocabulary_name FROM vocabulary ORDER BY vocabulary_id'
    },
    {
      label: 'All concept classes',
      sql: 'SELECT * FROM concept_class ORDER BY concept_class_id'
    },
    {
      label: 'Synonyms for concept 4329847',
      sql: 'SELECT cs.concept_id, cs.concept_synonym_name, c.concept_name\nFROM concept_synonym cs\nJOIN concept c ON c.concept_id = cs.concept_id\nWHERE cs.concept_id = 4329847'
    }
  ];

  /* ── ERD table definitions ──────────────────────────── */

  var ERD_TABLES = [
    {
      name: 'vocabulary',
      color: 'green',
      row: 0, col: 0,
      columns: [
        { name: 'vocabulary_id', pk: true },
        { name: 'vocabulary_name' },
        { name: 'vocabulary_concept_id', fk: 'concept' }
      ]
    },
    {
      name: 'domain',
      color: 'green',
      row: 0, col: 1,
      columns: [
        { name: 'domain_id', pk: true },
        { name: 'domain_name' },
        { name: 'domain_concept_id', fk: 'concept' }
      ]
    },
    {
      name: 'concept_class',
      color: 'green',
      row: 0, col: 2,
      columns: [
        { name: 'concept_class_id', pk: true },
        { name: 'concept_class_name' },
        { name: 'concept_class_concept_id', fk: 'concept' }
      ]
    },
    {
      name: 'relationship',
      color: 'green',
      row: 0, col: 3,
      columns: [
        { name: 'relationship_id', pk: true },
        { name: 'relationship_name' },
        { name: 'defines_ancestry' },
        { name: 'relationship_concept_id', fk: 'concept' }
      ]
    },
    {
      name: 'concept',
      color: 'yellow',
      row: 1, col: 1.5,
      columns: [
        { name: 'concept_id', pk: true },
        { name: 'concept_name' },
        { name: 'vocabulary_id', fk: 'vocabulary' },
        { name: 'domain_id', fk: 'domain' },
        { name: 'concept_class_id', fk: 'concept_class' },
        { name: 'concept_code' },
        { name: 'standard_concept' }
      ]
    },
    {
      name: 'concept_ancestor',
      color: 'red',
      row: 2, col: 0,
      columns: [
        { name: 'ancestor_concept_id', fk: 'concept' },
        { name: 'descendant_concept_id', fk: 'concept' },
        { name: 'min_levels_of_separation' },
        { name: 'max_levels_of_separation' }
      ]
    },
    {
      name: 'concept_relationship',
      color: 'red',
      row: 2, col: 1,
      columns: [
        { name: 'concept_id_1', fk: 'concept' },
        { name: 'concept_id_2', fk: 'concept' },
        { name: 'relationship_id', fk: 'relationship' }
      ]
    },
    {
      name: 'concept_synonym',
      color: 'red',
      row: 2, col: 2,
      columns: [
        { name: 'concept_id', fk: 'concept' },
        { name: 'concept_synonym_name' },
        { name: 'language_concept_id' }
      ]
    },
    {
      name: 'drug_strength',
      color: 'red',
      row: 2, col: 3,
      columns: [
        { name: 'drug_concept_id', fk: 'concept' },
        { name: 'ingredient_concept_id', fk: 'concept' },
        { name: 'amount_value' },
        { name: 'numerator_value' },
        { name: 'denominator_value' }
      ]
    }
  ];

  /* ── Tab switching ──────────────────────────────────── */

  function switchTab(tab) {
    activeTab = tab;
    document.querySelectorAll('#devtools-tabs .settings-tab').forEach(function (btn) {
      btn.classList.toggle('active', btn.dataset.tab === tab);
    });
    ['sql', 'erd'].forEach(function (t) {
      var el = document.getElementById('tab-' + t);
      if (el) el.style.display = (t === tab) ? '' : 'none';
    });
    if (tab === 'erd') initERD();
  }

  /* ── DB status ──────────────────────────────────────── */

  function getBrowserWarning() {
    var ua = navigator.userAgent;
    var isFirefox = /Firefox\//i.test(ua);
    var isSafari = /Safari\//i.test(ua) && !/Chrome\//i.test(ua);
    if (isFirefox) return ' Firefox does not support persistent file access — you must re-load vocabularies each session. Persistent file access is supported by Chrome and Edge.';
    if (isSafari) return ' Safari has limited support — vocabulary features may not work correctly. Full support is available in Chrome and Edge.';
    return '';
  }

  function showDbEmpty(statusEl, msgEl, linkEl, runBtn) {
    var warn = getBrowserWarning();
    if (warn) {
      statusEl.className = 'devtools-db-status devtools-db-warning';
      msgEl.textContent = 'No vocabulary database loaded.' + warn;
    } else {
      statusEl.className = 'devtools-db-status devtools-db-empty';
      msgEl.textContent = 'No vocabulary database loaded.';
    }
    linkEl.style.display = '';
    runBtn.disabled = true;
  }

  function checkDbStatus() {
    var statusEl = document.getElementById('devtools-db-status');
    var msgEl = document.getElementById('devtools-db-msg');
    var linkEl = document.getElementById('devtools-db-link');
    var runBtn = document.getElementById('sql-run-btn');

    if (window.location.protocol === 'file:') {
      statusEl.className = 'devtools-db-status devtools-db-error';
      msgEl.textContent = 'Requires HTTP server. Run: python3 -m http.server 8000 --directory docs';
      runBtn.disabled = true;
      return;
    }

    statusEl.className = 'devtools-db-status devtools-db-empty';
    msgEl.textContent = 'Loading DuckDB...';

    VocabDB.initDuckDB()
      .then(function () { return VocabDB.isDatabaseReady(); })
      .then(function (ready) {
        if (ready) {
          statusEl.className = 'devtools-db-status devtools-db-ready';
          msgEl.textContent = 'Database connected and ready.';
          linkEl.style.display = 'none';
          runBtn.disabled = false;
          return;
        }
        /* Try restoring from IndexedDB buffer or stored file handles */
        return VocabDB.remountFromStoredHandles().then(function (success) {
          if (success) {
            statusEl.className = 'devtools-db-status devtools-db-ready';
            msgEl.textContent = 'Database connected and ready.';
            linkEl.style.display = 'none';
            runBtn.disabled = false;
          } else {
            showDbEmpty(statusEl, msgEl, linkEl, runBtn);
          }
        });
      })
      .catch(function (err) {
        statusEl.className = 'devtools-db-status devtools-db-error';
        msgEl.textContent = 'Error: ' + err.message;
        runBtn.disabled = true;
      });
  }

  /* ── SQL Editor ─────────────────────────────────────── */

  function populateExamples() {
    var select = document.getElementById('sql-examples');
    EXAMPLE_QUERIES.forEach(function (q) {
      var opt = document.createElement('option');
      opt.value = q.sql;
      opt.textContent = q.label;
      select.appendChild(opt);
    });
    select.addEventListener('change', function () {
      if (this.value) {
        sqlEditor.setValue(this.value, -1);
        sqlEditor.focus();
        this.value = '';
      }
    });
  }

  function runQuery() {
    var sql = sqlEditor.getValue().trim();
    if (!sql) return;

    var resultsEl = document.getElementById('sql-results');
    var rowCountEl = document.getElementById('sql-row-count');
    var exportBtn = document.getElementById('sql-export-csv');
    var runBtn = document.getElementById('sql-run-btn');

    resultsEl.innerHTML = '<div style="padding:20px; text-align:center"><i class="fas fa-spinner fa-spin"></i> Running...</div>';
    rowCountEl.textContent = '';
    exportBtn.disabled = true;
    runBtn.disabled = true;

    VocabDB.query(sql)
      .then(function (rows) {
        runBtn.disabled = false;
        lastQueryRows = rows;

        if (!rows || rows.length === 0) {
          lastQueryCols = null;
          resultsEl.innerHTML = '<div class="empty-state" style="padding:40px 20px"><p>No results.</p></div>';
          rowCountEl.textContent = '0 rows';
          return;
        }

        lastQueryCols = Object.keys(rows[0]);
        rowCountEl.textContent = rows.length + ' row' + (rows.length === 1 ? '' : 's');
        exportBtn.disabled = false;
        currentPage = 0;
        renderResults();
      })
      .catch(function (err) {
        runBtn.disabled = false;
        lastQueryRows = null;
        lastQueryCols = null;
        rowCountEl.textContent = '';
        resultsEl.innerHTML = '<div class="devtools-sql-error"><i class="fas fa-exclamation-circle"></i> ' + App.escapeHtml(err.message) + '</div>';
      });
  }

  function renderResults() {
    if (!lastQueryRows || !lastQueryCols) return;
    var resultsEl = document.getElementById('sql-results');
    var total = lastQueryRows.length;

    /* Paginated table view */
    var totalPages = Math.ceil(total / PAGE_SIZE);
    if (currentPage >= totalPages) currentPage = totalPages - 1;
    if (currentPage < 0) currentPage = 0;
    var start = currentPage * PAGE_SIZE;
    var end = Math.min(start + PAGE_SIZE, total);

    var html = '<div style="overflow:auto; flex:1"><table class="data-table" style="font-size:12px"><thead><tr>';
    for (var c2 = 0; c2 < lastQueryCols.length; c2++) {
      html += '<th>' + App.escapeHtml(lastQueryCols[c2]) + '</th>';
    }
    html += '</tr></thead><tbody>';
    for (var r2 = start; r2 < end; r2++) {
      html += '<tr>';
      for (var c3 = 0; c3 < lastQueryCols.length; c3++) {
        var val2 = lastQueryRows[r2][lastQueryCols[c3]];
        html += '<td>' + App.escapeHtml(val2 == null ? '' : String(val2)) + '</td>';
      }
      html += '</tr>';
    }
    html += '</tbody></table></div>';

    /* Pagination bar */
    if (totalPages > 1) {
      html += '<div class="devtools-sql-pager">';
      html += '<button class="btn-outline-sm" id="pager-prev"' + (currentPage === 0 ? ' disabled' : '') + '><i class="fas fa-chevron-left"></i></button>';
      html += '<span class="devtools-pager-info">' + (start + 1) + '–' + end + ' of ' + total + '</span>';
      html += '<button class="btn-outline-sm" id="pager-next"' + (currentPage >= totalPages - 1 ? ' disabled' : '') + '><i class="fas fa-chevron-right"></i></button>';
      html += '</div>';
    }

    resultsEl.innerHTML = html;

    /* Bind pager events */
    var prevBtn = document.getElementById('pager-prev');
    var nextBtn = document.getElementById('pager-next');
    if (prevBtn) {
      prevBtn.addEventListener('click', function () {
        if (currentPage > 0) { currentPage--; renderResults(); }
      });
    }
    if (nextBtn) {
      nextBtn.addEventListener('click', function () {
        if (currentPage < totalPages - 1) { currentPage++; renderResults(); }
      });
    }
  }

  function exportCsv() {
    if (!lastQueryRows || !lastQueryCols) return;
    var lines = [lastQueryCols.map(function (c) { return '"' + c.replace(/"/g, '""') + '"'; }).join(',')];
    for (var r = 0; r < lastQueryRows.length; r++) {
      var vals = [];
      for (var c = 0; c < lastQueryCols.length; c++) {
        var val = lastQueryRows[r][lastQueryCols[c]];
        var s = val == null ? '' : String(val);
        vals.push('"' + s.replace(/"/g, '""') + '"');
      }
      lines.push(vals.join(','));
    }
    var blob = new Blob([lines.join('\n')], { type: 'text/csv;charset=utf-8;' });
    var url = URL.createObjectURL(blob);
    var a = document.createElement('a');
    a.href = url;
    a.download = 'query_result.csv';
    a.click();
    URL.revokeObjectURL(url);
    App.showToast('CSV exported', 'success');
  }

  /* ── ERD ────────────────────────────────────────────── */

  function fitErdToViewport() {
    var viewport = document.getElementById('erd-viewport');
    var canvas = document.getElementById('erd-canvas');
    if (!viewport || !canvas) return;
    var vw = viewport.clientWidth;
    var vh = viewport.clientHeight;
    var cw = parseFloat(canvas.style.width) || 1;
    var ch = parseFloat(canvas.style.height) || 1;
    erdScale = Math.min(vw / cw, vh / ch, 1);
    erdTranslateX = (vw - cw * erdScale) / 2;
    erdTranslateY = (vh - ch * erdScale) / 2;
    applyErdTransform();
  }

  function initERD() {
    if (erdInitialized) return;
    erdInitialized = true;

    var canvas = document.getElementById('erd-canvas');
    var svg = document.getElementById('erd-svg');

    var CARD_W = 210;
    var CARD_H_BASE = 34;
    var ROW_H = 20;
    var GAP_X = 30;
    var GAP_Y = 40;
    var PAD = 20;

    /* Calculate card positions — 3 rows, 4 columns */
    var cardPositions = {};
    var maxX = 0;
    var maxY = 0;
    var totalGridW = 4 * CARD_W + 3 * GAP_X;

    ERD_TABLES.forEach(function (tbl) {
      var h = CARD_H_BASE + tbl.columns.length * ROW_H + 8;
      var x, y;

      if (tbl.name === 'concept') {
        /* Center concept between the 4 columns */
        x = PAD + (totalGridW - CARD_W) / 2;
      } else {
        x = PAD + tbl.col * (CARD_W + GAP_X);
      }
      y = PAD + tbl.row * (160 + GAP_Y);

      cardPositions[tbl.name] = { x: x, y: y, w: CARD_W, h: h };
      if (x + CARD_W > maxX) maxX = x + CARD_W;
      if (y + h > maxY) maxY = y + h;
    });

    canvas.style.width = (maxX + PAD) + 'px';
    canvas.style.height = (maxY + PAD) + 'px';
    svg.setAttribute('width', maxX + PAD);
    svg.setAttribute('height', maxY + PAD);

    /* Render cards */
    ERD_TABLES.forEach(function (tbl) {
      var pos = cardPositions[tbl.name];
      var card = document.createElement('div');
      card.className = 'erd-card erd-card-' + tbl.color;
      card.style.left = pos.x + 'px';
      card.style.top = pos.y + 'px';
      card.style.width = pos.w + 'px';

      var headerHtml = '<div class="erd-card-header">' + App.escapeHtml(tbl.name) + '</div>';
      var bodyHtml = '<div class="erd-card-body">';
      tbl.columns.forEach(function (col) {
        var badges = '';
        if (col.pk) badges += '<span class="erd-badge-pk">PK</span>';
        if (col.fk) badges += '<span class="erd-badge-fk">FK</span>';
        bodyHtml += '<div class="erd-card-row">' + badges + App.escapeHtml(col.name) + '</div>';
      });
      bodyHtml += '</div>';
      card.innerHTML = headerHtml + bodyHtml;
      canvas.appendChild(card);
    });

    /* Draw relationship lines */
    ERD_TABLES.forEach(function (tbl) {
      var srcPos = cardPositions[tbl.name];
      tbl.columns.forEach(function (col, colIdx) {
        if (!col.fk) return;
        var tgtPos = cardPositions[col.fk];
        if (!tgtPos) return;

        var srcRowY = srcPos.y + CARD_H_BASE + colIdx * ROW_H + ROW_H / 2;
        var tgtCenterX = tgtPos.x + tgtPos.w / 2;
        var tgtCenterY = tgtPos.y + tgtPos.h / 2;

        var x1, y1, x2, y2;

        if (srcPos.y > tgtPos.y + tgtPos.h) {
          x1 = srcPos.x + srcPos.w / 2;
          y1 = srcPos.y;
          x2 = tgtCenterX;
          y2 = tgtPos.y + tgtPos.h;
        } else if (srcPos.y + srcPos.h < tgtPos.y) {
          x1 = srcPos.x + srcPos.w / 2;
          y1 = srcPos.y + srcPos.h;
          x2 = tgtCenterX;
          y2 = tgtPos.y;
        } else if (srcPos.x > tgtPos.x) {
          x1 = srcPos.x;
          y1 = srcRowY;
          x2 = tgtPos.x + tgtPos.w;
          y2 = tgtCenterY;
        } else {
          x1 = srcPos.x + srcPos.w;
          y1 = srcRowY;
          x2 = tgtPos.x;
          y2 = tgtCenterY;
        }

        var midX = (x1 + x2) / 2;
        var midY = (y1 + y2) / 2;
        var d;
        if (Math.abs(y1 - y2) > Math.abs(x1 - x2)) {
          d = 'M ' + x1 + ' ' + y1 + ' C ' + x1 + ' ' + midY + ' ' + x2 + ' ' + midY + ' ' + x2 + ' ' + y2;
        } else {
          d = 'M ' + x1 + ' ' + y1 + ' C ' + midX + ' ' + y1 + ' ' + midX + ' ' + y2 + ' ' + x2 + ' ' + y2;
        }

        var path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
        path.setAttribute('d', d);
        path.setAttribute('class', 'erd-line erd-line-' + tbl.color);
        svg.appendChild(path);
      });
    });

    initErdPanZoom();
    fitErdToViewport();
  }

  function initErdPanZoom() {
    var viewport = document.getElementById('erd-viewport');

    viewport.addEventListener('wheel', function (e) {
      e.preventDefault();
      var delta = e.deltaY > 0 ? -0.1 : 0.1;
      erdScale = Math.max(0.3, Math.min(2, erdScale + delta));
      applyErdTransform();
    }, { passive: false });

    viewport.addEventListener('mousedown', function (e) {
      if (e.button !== 0) return;
      erdIsDragging = true;
      erdDragStartX = e.clientX - erdTranslateX;
      erdDragStartY = e.clientY - erdTranslateY;
      viewport.style.cursor = 'grabbing';
    });

    document.addEventListener('mousemove', function (e) {
      if (!erdIsDragging) return;
      erdTranslateX = e.clientX - erdDragStartX;
      erdTranslateY = e.clientY - erdDragStartY;
      applyErdTransform();
    });

    document.addEventListener('mouseup', function () {
      if (!erdIsDragging) return;
      erdIsDragging = false;
      var vp = document.getElementById('erd-viewport');
      if (vp) vp.style.cursor = 'grab';
    });

    document.getElementById('erd-zoom-in').addEventListener('click', function () {
      erdScale = Math.min(2, erdScale + 0.15);
      applyErdTransform();
    });
    document.getElementById('erd-zoom-out').addEventListener('click', function () {
      erdScale = Math.max(0.3, erdScale - 0.15);
      applyErdTransform();
    });
    document.getElementById('erd-reset').addEventListener('click', function () {
      fitErdToViewport();
    });
  }

  function applyErdTransform() {
    var canvas = document.getElementById('erd-canvas');
    canvas.style.transform = 'translate(' + erdTranslateX + 'px, ' + erdTranslateY + 'px) scale(' + erdScale + ')';
  }

  /* ── Event listeners ────────────────────────────────── */

  function initEvents() {
    document.querySelectorAll('#devtools-tabs .settings-tab').forEach(function (btn) {
      btn.addEventListener('click', function () {
        switchTab(this.dataset.tab);
      });
    });

    document.getElementById('sql-run-btn').addEventListener('click', runQuery);

    /* Ace SQL editor */
    sqlEditor = ace.edit('sql-editor');
    sqlEditor.setTheme('ace/theme/tomorrow');
    sqlEditor.session.setMode('ace/mode/sql');
    sqlEditor.setOptions({
      fontSize: '13px',
      showPrintMargin: false,
      wrap: true,
      tabSize: 2,
      useSoftTabs: true,
      placeholder: 'Enter SQL query...'
    });
    sqlEditor.commands.addCommand({
      name: 'runQuery',
      bindKey: { win: 'Ctrl-Enter', mac: 'Cmd-Enter' },
      exec: function () { runQuery(); }
    });

    document.getElementById('sql-export-csv').addEventListener('click', exportCsv);
  }

  /* ── Page module ───────────────────────────────────── */

  function init() {
    if (initialized) return;
    initialized = true;
    initEvents();
    populateExamples();
    checkDbStatus();
  }

  function show() {
    init();
    checkDbStatus();
  }

  function hide() {
    // nothing to clean up
  }

  return {
    show: show,
    hide: hide
  };
})();

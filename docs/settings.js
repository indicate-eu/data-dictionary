// settings.js — Dictionary Settings page module
var SettingsPage = (function() {
  'use strict';

  var initialized = false;

  // ==================== STATE ====================
  var activeTab = 'vocabularies';

  // Session-editable copies
  var convData = [];
  var ruData = [];

  // Pagination
  var convPage = 1, convPageSize = 50;
  var ruPage = 1, ruPageSize = 50;

  // Column filters
  var convFilters = {};
  var ruFilters = {};

  // Delete callback holder
  var pendingDelete = null;

  // Test conversion state
  var testConvRow = null;

  // ==================== SHARED PAGINATION ====================
  function renderPagination(paginationId, pageInfoId, pageBtnsId, currentPage, totalItems, pageSize) {
    var el = document.getElementById(paginationId);
    var totalPages = Math.ceil(totalItems / pageSize);
    if (totalPages <= 0) totalPages = 1;
    var start = (currentPage - 1) * pageSize;
    document.getElementById(pageInfoId).textContent =
      totalItems === 0 ? 'No items' :
      'Showing ' + (start + 1) + '-' + Math.min(start + pageSize, totalItems) + ' of ' + totalItems;
    var btnContainer = document.getElementById(pageBtnsId);
    if (totalPages <= 1) {
      btnContainer.innerHTML = '';
      el.style.display = '';
      return;
    }
    el.style.display = '';
    var btns = '';
    btns += '<button ' + (currentPage <= 1 ? 'disabled' : '') + ' data-page="first">&laquo;</button>';
    btns += '<button ' + (currentPage <= 1 ? 'disabled' : '') + ' data-page="prev">&lsaquo;</button>';
    var maxButtons = 7;
    var startP = Math.max(1, currentPage - Math.floor(maxButtons / 2));
    var endP = Math.min(totalPages, startP + maxButtons - 1);
    if (endP - startP < maxButtons - 1) startP = Math.max(1, endP - maxButtons + 1);
    for (var i = startP; i <= endP; i++) {
      btns += '<button ' + (i === currentPage ? 'class="active"' : '') + ' data-page="' + i + '">' + i + '</button>';
    }
    btns += '<button ' + (currentPage >= totalPages ? 'disabled' : '') + ' data-page="next">&rsaquo;</button>';
    btns += '<button ' + (currentPage >= totalPages ? 'disabled' : '') + ' data-page="last">&raquo;</button>';
    btnContainer.innerHTML = btns;
  }

  function handlePageClick(e, totalItems, pageSize, getCurrentPage, setPage, render, scrollElId) {
    var btn = e.target.closest('button[data-page]');
    if (!btn || btn.disabled) return;
    var val = btn.dataset.page;
    var totalPages = Math.ceil(totalItems / pageSize);
    var p = getCurrentPage();
    if (val === 'first') p = 1;
    else if (val === 'prev') p = Math.max(1, p - 1);
    else if (val === 'next') p = Math.min(totalPages, p + 1);
    else if (val === 'last') p = totalPages;
    else p = parseInt(val);
    setPage(p);
    render();
    if (scrollElId) {
      var el = document.getElementById(scrollElId);
      if (el) el.scrollTop = 0;
    }
  }

  // ==================== VOCAB ENRICHMENT ====================
  var enriched = false;
  var enrichRetries = 0;

  function enrichAllNames() {
    if (enriched) return;
    if (typeof VocabDB === 'undefined' || typeof VocabDB.isDatabaseReady !== 'function') return;
    VocabDB.isDatabaseReady().then(function(ready) {
      if (!ready) {
        // DB not ready yet — retry a few times with delay
        if (enrichRetries < 5) {
          enrichRetries++;
          setTimeout(enrichAllNames, 1000);
        }
        return;
      }
      // Collect all concept IDs from both tables
      var idSet = {};
      convData.forEach(function(row) {
        if (row.conceptId) idSet[row.conceptId] = true;
        if (row.sourceUnitConceptId) idSet[row.sourceUnitConceptId] = true;
        if (row.targetUnitConceptId) idSet[row.targetUnitConceptId] = true;
      });
      ruData.forEach(function(row) {
        if (row.conceptId) idSet[row.conceptId] = true;
        if (row.recommendedUnitConceptId) idSet[row.recommendedUnitConceptId] = true;
      });
      var ids = Object.keys(idSet).map(Number);
      if (ids.length === 0) return;
      VocabDB.lookupConcepts(ids).then(function(concepts) {
        var map = {};
        concepts.forEach(function(c) { map[c.concept_id] = c; });
        // Enrich convData
        convData.forEach(function(row) {
          var c = map[row.conceptId]; if (c && !row.conceptName) row.conceptName = c.concept_name;
          var s = map[row.sourceUnitConceptId];
          if (s) {
            if (!row.sourceUnitName) row.sourceUnitName = s.concept_name;
            if (!row.sourceUnitCode) row.sourceUnitCode = s.concept_code;
          }
          var t = map[row.targetUnitConceptId];
          if (t) {
            if (!row.targetUnitName) row.targetUnitName = t.concept_name;
            if (!row.targetUnitCode) row.targetUnitCode = t.concept_code;
          }
        });
        // Enrich ruData
        ruData.forEach(function(row) {
          var c = map[row.conceptId];
          if (c) {
            if (!row.conceptName) row.conceptName = c.concept_name;
            if (!row.conceptCode) row.conceptCode = c.concept_code;
          }
          var u = map[row.recommendedUnitConceptId];
          if (u) {
            if (!row.recommendedUnitName) row.recommendedUnitName = u.concept_name;
            if (!row.recommendedUnitCode) row.recommendedUnitCode = u.concept_code;
          }
        });
        enriched = true;
        renderConvTable();
        renderRUTable();
      });
    });
  }

  // ==================== TAB SWITCHING ====================
  function switchTab(tab) {
    activeTab = tab;
    document.querySelectorAll('#settings-tabs .settings-tab').forEach(function(btn) {
      btn.classList.toggle('active', btn.dataset.tab === tab);
    });
    ['vocabularies', 'conversions', 'units'].forEach(function(t) {
      var el = document.getElementById('tab-' + t);
      if (el) el.style.display = (t === tab) ? '' : 'none';
    });
    if (tab === 'vocabularies' && typeof GeneralSettingsPage !== 'undefined') {
      GeneralSettingsPage.show();
    }
    if ((tab === 'conversions' || tab === 'units') && !enriched) {
      enrichAllNames();
    }
  }

  // ==================== UNIT CONVERSIONS ====================
  function getFilteredConv() {
    return convData.filter(function(row) {
      for (var key in convFilters) {
        if (!convFilters[key]) continue;
        var q = convFilters[key].toLowerCase();
        var val = '';
        if (key === 'cid') val = String(row.conceptId);
        else if (key === 'cname') val = (row.conceptName || '').toLowerCase();
        else if (key === 'uname-src') val = ((row.sourceUnitCode || '') + ' ' + (row.sourceUnitName || '')).toLowerCase();
        else if (key === 'factor') val = String(row.conversionFactor);
        else if (key === 'uname-tgt') val = ((row.targetUnitCode || '') + ' ' + (row.targetUnitName || '')).toLowerCase();
        if (val.indexOf(q) === -1) return false;
      }
      return true;
    });
  }

  function renderConvTable() {
    var filtered = getFilteredConv();
    var totalPages = Math.ceil(filtered.length / convPageSize);
    if (convPage > totalPages && totalPages > 0) convPage = totalPages;
    var start = (convPage - 1) * convPageSize;
    var pageData = filtered.slice(start, start + convPageSize);
    var tbody = document.getElementById('conv-tbody');

    if (pageData.length === 0) {
      tbody.innerHTML = '<tr><td colspan="6" class="empty-state"><p>No unit conversions' +
        (Object.keys(convFilters).some(function(k) { return !!convFilters[k]; }) ? ' match your filters' : ' defined') + '.</p></td></tr>';
    } else {
      tbody.innerHTML = pageData.map(function(row) {
        var idx = convData.indexOf(row);
        var srcCode = row.sourceUnitCode || '';
        var srcName = row.sourceUnitName || '';
        var tgtCode = row.targetUnitCode || '';
        var tgtName = row.targetUnitName || '';
        return '<tr data-idx="' + idx + '">' +
          '<td>' + row.conceptId + '</td>' +
          '<td>' + App.escapeHtml(row.conceptName || '') + '</td>' +
          '<td title="' + App.escapeHtml(srcName) + '">' + App.escapeHtml(srcCode) + '</td>' +
          '<td class="td-center editable-cell" data-field="conversionFactor" data-idx="' + idx + '">' +
            row.conversionFactor +
            (row.offset ? ' <span class="conv-offset" title="affine offset: target = factor × source + offset">' +
              (row.offset > 0 ? '+ ' : '− ') + Math.abs(row.offset) + '</span>' : '') + '</td>' +
          '<td title="' + App.escapeHtml(tgtName) + '">' + App.escapeHtml(tgtCode) + '</td>' +
          '<td class="td-center">' +
            '<button class="btn-action btn-action-test" data-idx="' + idx + '" title="Test">' +
              '<i class="fas fa-calculator"></i> Test</button> ' +
            '<button class="btn-action btn-action-delete" data-idx="' + idx + '" title="Delete">' +
              '<i class="fas fa-trash"></i></button>' +
          '</td>' +
          '</tr>';
      }).join('');
    }
    renderPagination('conv-pagination', 'conv-page-info', 'conv-page-buttons', convPage, filtered.length, convPageSize);
  }

  function startEditFactor(td) {
    if (td.querySelector('input')) return;
    var idx = parseInt(td.dataset.idx);
    var current = convData[idx].conversionFactor;
    var input = document.createElement('input');
    input.type = 'number';
    input.step = 'any';
    input.value = current;
    td.textContent = '';
    td.appendChild(input);
    input.focus();
    input.select();

    function finish() {
      var val = parseFloat(input.value);
      if (isNaN(val) || val <= 0) {
        App.showToast('Invalid conversion factor. Must be a positive number.', 'error');
        td.textContent = current;
        return;
      }
      convData[idx].conversionFactor = val;
      td.textContent = val;
      App.showToast('Conversion factor updated.', 'success');
    }
    input.addEventListener('blur', finish);
    input.addEventListener('keydown', function(e) {
      if (e.key === 'Enter') { e.preventDefault(); input.blur(); }
      if (e.key === 'Escape') { td.textContent = current; }
    });
  }

  function openTestConvModal(idx) {
    testConvRow = convData[idx];
    renderTestConv();
    document.getElementById('test-conv-value').value = '';
    document.getElementById('test-conv-result').textContent = '\u2014';
    document.getElementById('test-conv-modal').style.display = 'flex';
    document.getElementById('test-conv-value').focus();
  }

  function renderTestConv() {
    if (!testConvRow) return;
    var conceptLabel = testConvRow.conceptName || 'Concept ' + testConvRow.conceptId;
    var srcUnit = testConvRow.sourceUnitCode || testConvRow.sourceUnitName || 'Unit ' + testConvRow.sourceUnitConceptId;
    var tgtUnit = testConvRow.targetUnitCode || testConvRow.targetUnitName || 'Unit ' + testConvRow.targetUnitConceptId;
    document.getElementById('test-conv-info').innerHTML =
      '<div>' + App.escapeHtml(conceptLabel) + '</div>' +
      '<div style="margin-top:8px"><strong>' + App.escapeHtml(srcUnit) +
      '</strong> <i class="fas fa-arrow-right" style="color:var(--primary)"></i> <strong>' +
      App.escapeHtml(tgtUnit) + '</strong></div>';
    document.getElementById('test-conv-unit-from').textContent = srcUnit;
    var offset = testConvRow.offset || 0;
    var label = ' \u00d7 ' + parseFloat(testConvRow.conversionFactor.toPrecision(10));
    if (offset > 0) label += ' + ' + parseFloat(offset.toPrecision(10));
    else if (offset < 0) label += ' \u2212 ' + parseFloat(Math.abs(offset).toPrecision(10));
    document.getElementById('test-conv-factor-label').textContent = label;
    updateTestResult();
  }

  function updateTestResult() {
    var val = parseFloat(document.getElementById('test-conv-value').value);
    var resultEl = document.getElementById('test-conv-result');
    if (isNaN(val) || !testConvRow) {
      resultEl.textContent = '\u2014';
      return;
    }
    var result = val * testConvRow.conversionFactor + (testConvRow.offset || 0);
    var unitLabel = testConvRow.targetUnitCode || testConvRow.targetUnitName || '';
    resultEl.textContent = result.toFixed(2) + (unitLabel ? ' ' + unitLabel : '');
  }

  function openAddConvModal() {
    ['conv-add-cid', 'conv-add-cname', 'conv-add-uid-src', 'conv-add-uname-src',
     'conv-add-factor', 'conv-add-offset', 'conv-add-uid-tgt', 'conv-add-uname-tgt'
    ].forEach(function(id) { document.getElementById(id).value = ''; });
    document.getElementById('conv-add-modal').style.display = 'flex';
  }

  function submitAddConv() {
    var cid = parseInt(document.getElementById('conv-add-cid').value);
    var uidSrc = parseInt(document.getElementById('conv-add-uid-src').value);
    var factor = parseFloat(document.getElementById('conv-add-factor').value);
    var offsetRaw = document.getElementById('conv-add-offset').value.trim();
    var offset = offsetRaw === '' ? 0 : parseFloat(offsetRaw);
    var uidTgt = parseInt(document.getElementById('conv-add-uid-tgt').value);

    if (isNaN(cid) || isNaN(uidSrc) || isNaN(factor) || isNaN(uidTgt)) {
      App.showToast('Please fill in all required fields (*).', 'error');
      return;
    }
    if (factor <= 0) {
      App.showToast('Conversion factor must be a positive number.', 'error');
      return;
    }
    if (isNaN(offset)) {
      App.showToast('Offset must be a number.', 'error');
      return;
    }

    var exists = convData.some(function(r) {
      return r.conceptId === cid && r.sourceUnitConceptId === uidSrc &&
             r.targetUnitConceptId === uidTgt;
    });
    if (exists) {
      App.showToast('This conversion already exists.', 'warning');
      return;
    }

    var newRow = {
      conceptId: cid,
      conceptName: document.getElementById('conv-add-cname').value.trim(),
      sourceUnitConceptId: uidSrc,
      sourceUnitCode: '',
      sourceUnitName: document.getElementById('conv-add-uname-src').value.trim(),
      conversionFactor: factor,
      targetUnitConceptId: uidTgt,
      targetUnitCode: '',
      targetUnitName: document.getElementById('conv-add-uname-tgt').value.trim()
    };
    // Keep purely multiplicative rows free of an offset key.
    if (offset !== 0) newRow.offset = offset;
    convData.push(newRow);

    document.getElementById('conv-add-modal').style.display = 'none';
    convPage = Math.ceil(convData.length / convPageSize);
    renderConvTable();
    App.showToast('Conversion added.', 'success');
  }

  function deleteConv(idx) {
    pendingDelete = function() {
      convData.splice(idx, 1);
      renderConvTable();
      App.showToast('Conversion deleted.', 'success');
    };
    document.getElementById('delete-modal-msg').textContent =
      'Are you sure you want to delete this conversion?';
    document.getElementById('delete-modal').style.display = 'flex';
  }

  function exportConv() {
    var json = JSON.stringify(convData, null, 2);
    App.openExportModal({ content: json, filename: 'unit_conversions.json', type: 'application/json', clipboardDesc: 'Copy JSON to clipboard', fileDesc: 'Download as unit_conversions.json' });
  }

  // ==================== RECOMMENDED UNITS ====================
  function getFilteredRU() {
    return ruData.filter(function(row) {
      for (var key in ruFilters) {
        if (!ruFilters[key]) continue;
        var q = ruFilters[key].toLowerCase();
        var val = '';
        if (key === 'cid') val = String(row.conceptId);
        else if (key === 'cname') val = (row.conceptName || '').toLowerCase();
        else if (key === 'unit') val = ((row.recommendedUnitCode || '') + ' ' + (row.recommendedUnitName || '')).toLowerCase();
        if (val.indexOf(q) === -1) return false;
      }
      return true;
    });
  }

  function renderRUTable() {
    var filtered = getFilteredRU();
    var totalPages = Math.ceil(filtered.length / ruPageSize);
    if (ruPage > totalPages && totalPages > 0) ruPage = totalPages;
    var start = (ruPage - 1) * ruPageSize;
    var pageData = filtered.slice(start, start + ruPageSize);
    var tbody = document.getElementById('ru-tbody');

    if (pageData.length === 0) {
      tbody.innerHTML = '<tr><td colspan="4" class="empty-state"><p>No recommended units' +
        (Object.keys(ruFilters).some(function(k) { return !!ruFilters[k]; }) ? ' match your filters' : ' defined') + '.</p></td></tr>';
    } else {
      tbody.innerHTML = pageData.map(function(row) {
        var idx = ruData.indexOf(row);
        var unitCode = row.recommendedUnitCode || '';
        var unitName = row.recommendedUnitName || '';
        return '<tr data-idx="' + idx + '">' +
          '<td>' + row.conceptId + '</td>' +
          '<td>' + App.escapeHtml(row.conceptName || '') + '</td>' +
          '<td title="' + App.escapeHtml(unitName) + '">' + App.escapeHtml(unitCode) + '</td>' +
          '<td class="td-center">' +
            '<button class="btn-action btn-action-delete" data-ru-idx="' + idx + '" title="Delete">' +
              '<i class="fas fa-trash"></i></button>' +
          '</td>' +
          '</tr>';
      }).join('');
    }
    renderPagination('ru-pagination', 'ru-page-info', 'ru-page-buttons', ruPage, filtered.length, ruPageSize);
  }

  function openAddRUModal() {
    ['ru-add-cid', 'ru-add-cname', 'ru-add-ccode', 'ru-add-vocab', 'ru-add-domain',
     'ru-add-uid', 'ru-add-uname', 'ru-add-ucode', 'ru-add-uvocab'
    ].forEach(function(id) { document.getElementById(id).value = ''; });
    document.getElementById('ru-add-modal').style.display = 'flex';
  }

  function submitAddRU() {
    var cid = parseInt(document.getElementById('ru-add-cid').value);
    var uid = parseInt(document.getElementById('ru-add-uid').value);

    if (isNaN(cid) || isNaN(uid)) {
      App.showToast('Please fill in Concept ID and Unit Concept ID.', 'error');
      return;
    }

    var exists = ruData.some(function(r) {
      return r.conceptId === cid && r.recommendedUnitConceptId === uid;
    });
    if (exists) {
      App.showToast('This recommended unit already exists.', 'warning');
      return;
    }

    ruData.push({
      conceptId: cid,
      conceptName: document.getElementById('ru-add-cname').value.trim(),
      conceptCode: document.getElementById('ru-add-ccode').value.trim(),
      vocabularyId: document.getElementById('ru-add-vocab').value.trim(),
      domainId: document.getElementById('ru-add-domain').value.trim(),
      recommendedUnitConceptId: uid,
      recommendedUnitName: document.getElementById('ru-add-uname').value.trim(),
      recommendedUnitCode: document.getElementById('ru-add-ucode').value.trim(),
      recommendedUnitVocabularyId: document.getElementById('ru-add-uvocab').value.trim()
    });

    document.getElementById('ru-add-modal').style.display = 'none';
    ruPage = Math.ceil(ruData.length / ruPageSize);
    renderRUTable();
    App.showToast('Recommended unit added.', 'success');
  }

  function deleteRU(idx) {
    pendingDelete = function() {
      ruData.splice(idx, 1);
      renderRUTable();
      App.showToast('Recommended unit deleted.', 'success');
    };
    document.getElementById('delete-modal-msg').textContent =
      'Are you sure you want to delete this recommended unit?';
    document.getElementById('delete-modal').style.display = 'flex';
  }

  function exportRU() {
    var json = JSON.stringify(ruData, null, 2);
    App.openExportModal({ content: json, filename: 'recommended_units.json', type: 'application/json', clipboardDesc: 'Copy JSON to clipboard', fileDesc: 'Download as recommended_units.json' });
  }

  // ==================== EVENTS ====================
  function initEvents() {
    // Tab switching
    document.getElementById('settings-tabs').addEventListener('click', function(e) {
      var btn = e.target.closest('.settings-tab');
      if (btn) switchTab(btn.dataset.tab);
    });

    // Conversions: column filters
    ['cid', 'cname', 'uname-src', 'factor', 'uname-tgt'].forEach(function(key) {
      var el = document.getElementById('conv-filter-' + key);
      if (el) el.addEventListener('input', function(e) {
        convFilters[key] = e.target.value;
        convPage = 1;
        renderConvTable();
      });
    });

    // Conversions: table actions
    document.getElementById('conv-tbody').addEventListener('click', function(e) {
      var testBtn = e.target.closest('.btn-action-test');
      if (testBtn) { openTestConvModal(parseInt(testBtn.dataset.idx)); return; }
      var delBtn = e.target.closest('.btn-action-delete[data-idx]');
      if (delBtn) { deleteConv(parseInt(delBtn.dataset.idx)); return; }
      var editCell = e.target.closest('.editable-cell');
      if (editCell) startEditFactor(editCell);
    });

    // Conversions: pagination
    document.getElementById('conv-page-buttons').addEventListener('click', function(e) {
      var filtered = getFilteredConv();
      handlePageClick(e, filtered.length, convPageSize,
        function() { return convPage; },
        function(p) { convPage = p; },
        renderConvTable, 'conv-table-wrap');
    });

    // Conversions: add / export
    document.getElementById('conv-add-btn').addEventListener('click', openAddConvModal);
    document.getElementById('conv-export-btn').addEventListener('click', exportConv);

    // Add conversion modal
    document.getElementById('conv-add-close').addEventListener('click', function() {
      document.getElementById('conv-add-modal').style.display = 'none';
    });
    document.getElementById('conv-add-cancel').addEventListener('click', function() {
      document.getElementById('conv-add-modal').style.display = 'none';
    });
    document.getElementById('conv-add-submit').addEventListener('click', submitAddConv);
    document.getElementById('conv-add-modal').addEventListener('click', function(e) {
      if (e.target === this) this.style.display = 'none';
    });

    // Test conversion modal
    document.getElementById('test-conv-close').addEventListener('click', function() {
      document.getElementById('test-conv-modal').style.display = 'none';
    });
    document.getElementById('test-conv-value').addEventListener('input', updateTestResult);
    document.getElementById('test-conv-modal').addEventListener('click', function(e) {
      if (e.target === this) this.style.display = 'none';
    });

    // Recommended units: column filters
    ['cid', 'cname', 'unit'].forEach(function(key) {
      var el = document.getElementById('ru-filter-' + key);
      if (el) el.addEventListener('input', function(e) {
        ruFilters[key] = e.target.value;
        ruPage = 1;
        renderRUTable();
      });
    });

    // Recommended units: table actions
    document.getElementById('ru-tbody').addEventListener('click', function(e) {
      var delBtn = e.target.closest('.btn-action-delete[data-ru-idx]');
      if (delBtn) deleteRU(parseInt(delBtn.dataset.ruIdx));
    });

    // Recommended units: pagination
    document.getElementById('ru-page-buttons').addEventListener('click', function(e) {
      var filtered = getFilteredRU();
      handlePageClick(e, filtered.length, ruPageSize,
        function() { return ruPage; },
        function(p) { ruPage = p; },
        renderRUTable, 'ru-table-wrap');
    });

    // Recommended units: add / export
    document.getElementById('ru-add-btn').addEventListener('click', openAddRUModal);
    document.getElementById('ru-export-btn').addEventListener('click', exportRU);

    // Add recommended unit modal
    document.getElementById('ru-add-close').addEventListener('click', function() {
      document.getElementById('ru-add-modal').style.display = 'none';
    });
    document.getElementById('ru-add-cancel').addEventListener('click', function() {
      document.getElementById('ru-add-modal').style.display = 'none';
    });
    document.getElementById('ru-add-submit').addEventListener('click', submitAddRU);
    document.getElementById('ru-add-modal').addEventListener('click', function(e) {
      if (e.target === this) this.style.display = 'none';
    });

    // Delete confirmation modal
    document.getElementById('delete-modal-close').addEventListener('click', function() {
      document.getElementById('delete-modal').style.display = 'none';
    });
    document.getElementById('delete-modal-cancel').addEventListener('click', function() {
      document.getElementById('delete-modal').style.display = 'none';
    });
    document.getElementById('delete-modal-ok').addEventListener('click', function() {
      document.getElementById('delete-modal').style.display = 'none';
      if (pendingDelete) { pendingDelete(); pendingDelete = null; }
    });
    document.getElementById('delete-modal').addEventListener('click', function(e) {
      if (e.target === this) this.style.display = 'none';
    });
  }

  // ==================== PAGE MODULE ====================
  function init() {
    if (initialized) return;
    initialized = true;
    initEvents();
    // Deep copy data into session-editable arrays
    convData = JSON.parse(JSON.stringify(App.unitConversions));
    ruData = JSON.parse(JSON.stringify(App.recommendedUnits));
    renderConvTable();
    renderRUTable();
  }

  function show(query) {
    init();
    // Support direct tab navigation via query param, e.g. #/settings?tab=vocabularies
    if (query && query.tab) {
      switchTab(query.tab);
    } else {
      switchTab(activeTab);
    }
  }

  function hide() {
    // nothing to clean up
  }

  return {
    show: show,
    hide: hide
  };
})();

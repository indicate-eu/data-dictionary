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

  // Column sort state ({ key, asc }; null key = unsorted, keep insertion order)
  var convSort = { key: null, asc: true };
  var ruSort = { key: null, asc: true };

  // Delete callback holder
  var pendingDelete = null;

  // Test conversion state
  var testConvRow = null;

  // Edit (selection) mode — mirrors the Data Dictionary list. Each table has:
  //  - a flag (in/out of edit mode)
  //  - a Set of selected row indices (into convData / ruData)
  //  - a snapshot taken on enter, restored on Cancel.
  var convEditMode = false, convSelected = new Set(), convSnapshot = null;
  var ruEditMode = false, ruSelected = new Set(), ruSnapshot = null;
  // Index of the row being edited via the Add/Edit modal (null = adding new).
  var convEditIdx = null, ruEditIdx = null;

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
  var TABS = ['vocabularies', 'conversions', 'units'];

  function switchTab(tab, skipUrl) {
    // `tab` may come straight from the URL (?tab=...) — an unknown value
    // would otherwise hide all panes and highlight no tab.
    if (TABS.indexOf(tab) === -1) tab = TABS[0];
    // Leaving a table tab while in edit mode → discard staged edits (Cancel).
    if (activeTab === 'conversions' && tab !== 'conversions' && convEditMode) cancelEditMode(CONV_CFG);
    if (activeTab === 'units' && tab !== 'units' && ruEditMode) cancelEditMode(RU_CFG);
    activeTab = tab;
    // Reflect the active tab in the URL so deep-linking + refresh works.
    // `skipUrl` is set when switchTab is driven *by* the URL (initial load),
    // to avoid a redundant replaceState. Default tab omits ?tab= (like #/mapping).
    if (!skipUrl && typeof Router !== 'undefined') {
      Router.replaceState(tab === TABS[0] ? '#/settings' : '#/settings?tab=' + tab);
    }
    document.querySelectorAll('#settings-tabs .settings-tab').forEach(function(btn) {
      btn.classList.toggle('active', btn.dataset.tab === tab);
    });
    TABS.forEach(function(t) {
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

  // Stable sort of `rows` by `sort` ({key, asc}) using `accessor(row,key)→value`.
  // Numbers compare numerically; everything else as lowercased strings.
  // A null sort.key leaves the rows in their current order.
  function sortRows(rows, sort, accessor) {
    if (!sort.key) return rows;
    var decorated = rows.map(function(row, i) { return { row: row, i: i }; });
    decorated.sort(function(a, b) {
      var va = accessor(a.row, sort.key), vb = accessor(b.row, sort.key);
      var cmp;
      if (typeof va === 'number' && typeof vb === 'number') {
        cmp = va - vb;
      } else {
        va = (va == null ? '' : String(va)).toLowerCase();
        vb = (vb == null ? '' : String(vb)).toLowerCase();
        cmp = va < vb ? -1 : va > vb ? 1 : 0;
      }
      if (cmp === 0) cmp = a.i - b.i; // stable
      return sort.asc ? cmp : -cmp;
    });
    return decorated.map(function(d) { return d.row; });
  }

  function syncSortIndicators(tableId, sort) {
    document.querySelectorAll('#' + tableId + ' thead th[data-sort]').forEach(function(th) {
      var icon = th.querySelector('.sort-icon');
      var isCur = th.dataset.sort === sort.key;
      th.classList.toggle('sorted', isCur);
      if (icon) icon.textContent = (isCur && !sort.asc) ? '▼' : '▲';
    });
  }

  // Toggle/select sort key for a table, then re-render. Numeric default asc.
  function handleSortClick(sort, key, render) {
    if (sort.key === key) sort.asc = !sort.asc;
    else { sort.key = key; sort.asc = true; }
    render();
  }

  // ==================== UNIT CONVERSIONS ====================
  function convSortValue(row, key) {
    if (key === 'cid') return Number(row.conceptId);
    if (key === 'cname') return row.conceptName || '';
    if (key === 'src') return (row.sourceUnitCode || '') + ' ' + (row.sourceUnitName || '');
    if (key === 'factor') return Number(row.conversionFactor);
    if (key === 'tgt') return (row.targetUnitCode || '') + ' ' + (row.targetUnitName || '');
    return '';
  }

  function getFilteredConv() {
    var rows = convData.filter(function(row) {
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
    return sortRows(rows, convSort, convSortValue);
  }

  function renderConvTable() {
    var filtered = getFilteredConv();
    var totalPages = Math.ceil(filtered.length / convPageSize);
    if (convPage > totalPages && totalPages > 0) convPage = totalPages;
    var start = (convPage - 1) * convPageSize;
    var pageData = filtered.slice(start, start + convPageSize);
    var tbody = document.getElementById('conv-tbody');

    if (pageData.length === 0) {
      tbody.innerHTML = '<tr><td colspan="8" class="empty-state"><p>No unit conversions' +
        (Object.keys(convFilters).some(function(k) { return !!convFilters[k]; }) ? ' match your filters' : ' defined') + '.</p></td></tr>';
    } else {
      tbody.innerHTML = pageData.map(function(row) {
        var idx = convData.indexOf(row);
        var srcCode = row.sourceUnitCode || '';
        var srcName = row.sourceUnitName || '';
        var tgtCode = row.targetUnitCode || '';
        var tgtName = row.targetUnitName || '';
        var sel = convSelected.has(idx);
        return '<tr data-idx="' + idx + '"' + (sel ? ' class="selected"' : '') + '>' +
          '<td class="conv-select-col"><input type="checkbox" class="settings-row-checkbox conv-row-checkbox" data-idx="' + idx + '"' + (sel ? ' checked' : '') + '></td>' +
          '<td class="conv-edit-col"><div class="settings-row-actions">' +
            '<button class="settings-row-edit-btn conv-row-edit-btn" data-edit-idx="' + idx + '" title="Edit"><i class="fas fa-pen"></i></button>' +
            '<button class="settings-row-edit-btn settings-row-delete-btn conv-row-delete-btn" data-del-idx="' + idx + '" title="Delete"><i class="fas fa-trash"></i></button>' +
          '</div></td>' +
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
              '<i class="fas fa-calculator"></i> Test</button>' +
          '</td>' +
          '</tr>';
      }).join('');
    }
    renderPagination('conv-pagination', 'conv-page-info', 'conv-page-buttons', convPage, filtered.length, convPageSize);
    syncSortIndicators('conv-table', convSort);
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

    // `done` guards against the blur that fires when the input is removed
    // (Escape would otherwise cancel and then save through the blur handler).
    var done = false;
    function finish(save) {
      if (done) return;
      done = true;
      if (save) {
        var val = parseFloat(input.value);
        if (isNaN(val) || val <= 0) {
          App.showToast('Invalid conversion factor. Must be a positive number.', 'error');
        } else if (val !== current) {
          convData[idx].conversionFactor = val;
          App.showToast('Conversion factor updated.', 'success');
        }
      }
      // Full re-render so the affine offset suffix (e.g. °C → °F) is restored.
      renderConvTable();
    }
    input.addEventListener('blur', function() { finish(true); });
    input.addEventListener('keydown', function(e) {
      if (e.key === 'Enter') { e.preventDefault(); finish(true); }
      if (e.key === 'Escape') { finish(false); }
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

  // Reset a concept-picker field group: clear hidden inputs + the display chip.
  function resetPickerField(displayId, hiddenIds, placeholderKey) {
    hiddenIds.forEach(function(id) { var el = document.getElementById(id); if (el) el.value = ''; });
    var el = document.getElementById(displayId);
    el.textContent = App.i18n(placeholderKey);
    el.classList.add('empty');
    el.removeAttribute('title');
  }

  // Reflect a stored concept on a picker field (display chip + hidden inputs).
  function setConvField(displayId, id, name, code, idInput, nameInput, codeInput) {
    document.getElementById(idInput).value = id != null ? id : '';
    document.getElementById(nameInput).value = name || '';
    if (codeInput) document.getElementById(codeInput).value = code || '';
    var el = document.getElementById(displayId);
    if (id != null) {
      el.textContent = id + ' — ' + (name || '');
      el.classList.remove('empty');
      el.title = id + ' — ' + (name || '');
    }
  }

  // openAddConvModal(idx?) — idx set ⇒ edit an existing row; else add a new one.
  function openAddConvModal(idx) {
    convEditIdx = (typeof idx === 'number') ? idx : null;
    ['conv-add-cid', 'conv-add-cname', 'conv-add-uid-src', 'conv-add-uname-src', 'conv-add-ucode-src',
     'conv-add-factor', 'conv-add-offset', 'conv-add-uid-tgt', 'conv-add-uname-tgt', 'conv-add-ucode-tgt'
    ].forEach(function(id) { document.getElementById(id).value = ''; });
    resetPickerField('conv-add-concept-display', [], 'No concept selected');
    resetPickerField('conv-add-src-display', [], 'No unit selected');
    resetPickerField('conv-add-tgt-display', [], 'No unit selected');

    var titleEl = document.getElementById('conv-add-title');
    var submitLabel = document.querySelector('#conv-add-submit span[data-i18n]');
    if (convEditIdx !== null) {
      var r = convData[convEditIdx];
      setConvField('conv-add-concept-display', r.conceptId, r.conceptName, null, 'conv-add-cid', 'conv-add-cname');
      setConvField('conv-add-src-display', r.sourceUnitConceptId, r.sourceUnitName, r.sourceUnitCode, 'conv-add-uid-src', 'conv-add-uname-src', 'conv-add-ucode-src');
      setConvField('conv-add-tgt-display', r.targetUnitConceptId, r.targetUnitName, r.targetUnitCode, 'conv-add-uid-tgt', 'conv-add-uname-tgt', 'conv-add-ucode-tgt');
      document.getElementById('conv-add-factor').value = r.conversionFactor;
      document.getElementById('conv-add-offset').value = r.offset || '';
      if (titleEl) titleEl.textContent = App.i18n('Edit Conversion');
      if (submitLabel) { submitLabel.setAttribute('data-i18n', 'Save'); submitLabel.textContent = App.i18n('Save'); }
    } else {
      if (titleEl) titleEl.textContent = App.i18n('Add Conversion');
      if (submitLabel) { submitLabel.setAttribute('data-i18n', 'Add'); submitLabel.textContent = App.i18n('Add'); }
    }
    document.getElementById('conv-add-modal').style.display = 'flex';
  }

  function submitAddConv() {
    var cid = parseInt(document.getElementById('conv-add-cid').value);
    var uidSrc = parseInt(document.getElementById('conv-add-uid-src').value);
    var factor = parseFloat(document.getElementById('conv-add-factor').value);
    var offsetRaw = document.getElementById('conv-add-offset').value.trim();
    var offset = offsetRaw === '' ? 0 : parseFloat(offsetRaw);
    var uidTgt = parseInt(document.getElementById('conv-add-uid-tgt').value);

    if (isNaN(cid) || isNaN(uidSrc) || isNaN(uidTgt)) {
      App.showToast('Please select a concept, a source unit and a target unit.', 'error');
      return;
    }
    if (isNaN(factor)) {
      App.showToast('Please enter a conversion factor.', 'error');
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

    var exists = convData.some(function(r, i) {
      return i !== convEditIdx && r.conceptId === cid && r.sourceUnitConceptId === uidSrc &&
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
      sourceUnitCode: document.getElementById('conv-add-ucode-src').value.trim(),
      sourceUnitName: document.getElementById('conv-add-uname-src').value.trim(),
      conversionFactor: factor,
      targetUnitConceptId: uidTgt,
      targetUnitCode: document.getElementById('conv-add-ucode-tgt').value.trim(),
      targetUnitName: document.getElementById('conv-add-uname-tgt').value.trim()
    };
    // Keep purely multiplicative rows free of an offset key.
    if (offset !== 0) newRow.offset = offset;

    document.getElementById('conv-add-modal').style.display = 'none';
    if (convEditIdx !== null) {
      convData[convEditIdx] = newRow;
      convEditIdx = null;
      renderConvTable();
      App.showToast('Conversion updated.', 'success');
    } else {
      convData.push(newRow);
      convPage = Math.ceil(convData.length / convPageSize);
      renderConvTable();
      App.showToast('Conversion added.', 'success');
    }
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
  function ruSortValue(row, key) {
    if (key === 'cid') return Number(row.conceptId);
    if (key === 'cname') return row.conceptName || '';
    if (key === 'uname') return row.recommendedUnitName || '';
    if (key === 'ucode') return row.recommendedUnitCode || '';
    return '';
  }

  function getFilteredRU() {
    var rows = ruData.filter(function(row) {
      for (var key in ruFilters) {
        if (!ruFilters[key]) continue;
        var q = ruFilters[key].toLowerCase();
        var val = '';
        if (key === 'cid') val = String(row.conceptId);
        else if (key === 'cname') val = (row.conceptName || '').toLowerCase();
        else if (key === 'uname') val = (row.recommendedUnitName || '').toLowerCase();
        else if (key === 'ucode') val = (row.recommendedUnitCode || '').toLowerCase();
        if (val.indexOf(q) === -1) return false;
      }
      return true;
    });
    return sortRows(rows, ruSort, ruSortValue);
  }

  function renderRUTable() {
    var filtered = getFilteredRU();
    var totalPages = Math.ceil(filtered.length / ruPageSize);
    if (ruPage > totalPages && totalPages > 0) ruPage = totalPages;
    var start = (ruPage - 1) * ruPageSize;
    var pageData = filtered.slice(start, start + ruPageSize);
    var tbody = document.getElementById('ru-tbody');

    if (pageData.length === 0) {
      tbody.innerHTML = '<tr><td colspan="6" class="empty-state"><p>No recommended units' +
        (Object.keys(ruFilters).some(function(k) { return !!ruFilters[k]; }) ? ' match your filters' : ' defined') + '.</p></td></tr>';
    } else {
      tbody.innerHTML = pageData.map(function(row) {
        var idx = ruData.indexOf(row);
        var unitCode = row.recommendedUnitCode || '';
        var unitName = row.recommendedUnitName || '';
        var sel = ruSelected.has(idx);
        return '<tr data-idx="' + idx + '"' + (sel ? ' class="selected"' : '') + '>' +
          '<td class="ru-select-col"><input type="checkbox" class="settings-row-checkbox ru-row-checkbox" data-idx="' + idx + '"' + (sel ? ' checked' : '') + '></td>' +
          '<td class="ru-edit-col"><div class="settings-row-actions">' +
            '<button class="settings-row-edit-btn ru-row-edit-btn" data-edit-idx="' + idx + '" title="Edit"><i class="fas fa-pen"></i></button>' +
            '<button class="settings-row-edit-btn settings-row-delete-btn ru-row-delete-btn" data-del-idx="' + idx + '" title="Delete"><i class="fas fa-trash"></i></button>' +
          '</div></td>' +
          '<td>' + row.conceptId + '</td>' +
          '<td>' + App.escapeHtml(row.conceptName || '') + '</td>' +
          '<td>' + App.escapeHtml(unitName) + '</td>' +
          '<td>' + App.escapeHtml(unitCode) + '</td>' +
          '</tr>';
      }).join('');
    }
    renderPagination('ru-pagination', 'ru-page-info', 'ru-page-buttons', ruPage, filtered.length, ruPageSize);
    syncSortIndicators('ru-table', ruSort);
  }

  // openAddRUModal(idx?) — idx set ⇒ edit an existing row; else add a new one.
  function openAddRUModal(idx) {
    ruEditIdx = (typeof idx === 'number') ? idx : null;
    ['ru-add-cid', 'ru-add-cname', 'ru-add-ccode', 'ru-add-vocab', 'ru-add-domain',
     'ru-add-uid', 'ru-add-uname', 'ru-add-ucode', 'ru-add-uvocab'
    ].forEach(function(id) { document.getElementById(id).value = ''; });
    resetPickerField('ru-add-concept-display', [], 'No concept selected');
    resetPickerField('ru-add-unit-display', [], 'No unit selected');

    var titleEl = document.getElementById('ru-add-title');
    var submitLabel = document.querySelector('#ru-add-submit span[data-i18n]');
    if (ruEditIdx !== null) {
      var r = ruData[ruEditIdx];
      document.getElementById('ru-add-cid').value = r.conceptId != null ? r.conceptId : '';
      document.getElementById('ru-add-cname').value = r.conceptName || '';
      document.getElementById('ru-add-ccode').value = r.conceptCode || '';
      document.getElementById('ru-add-vocab').value = r.vocabularyId || '';
      document.getElementById('ru-add-domain').value = r.domainId || '';
      document.getElementById('ru-add-uid').value = r.recommendedUnitConceptId != null ? r.recommendedUnitConceptId : '';
      document.getElementById('ru-add-uname').value = r.recommendedUnitName || '';
      document.getElementById('ru-add-ucode').value = r.recommendedUnitCode || '';
      document.getElementById('ru-add-uvocab').value = r.recommendedUnitVocabularyId || '';
      if (r.conceptId != null) {
        var ce = document.getElementById('ru-add-concept-display');
        ce.textContent = r.conceptId + ' — ' + (r.conceptName || ''); ce.classList.remove('empty'); ce.title = ce.textContent;
      }
      if (r.recommendedUnitConceptId != null) {
        var ue = document.getElementById('ru-add-unit-display');
        ue.textContent = r.recommendedUnitConceptId + ' — ' + (r.recommendedUnitName || ''); ue.classList.remove('empty'); ue.title = ue.textContent;
      }
      if (titleEl) titleEl.textContent = App.i18n('Edit Recommended Unit');
      if (submitLabel) { submitLabel.setAttribute('data-i18n', 'Save'); submitLabel.textContent = App.i18n('Save'); }
    } else {
      if (titleEl) titleEl.textContent = App.i18n('Add Recommended Unit');
      if (submitLabel) { submitLabel.setAttribute('data-i18n', 'Add'); submitLabel.textContent = App.i18n('Add'); }
    }
    document.getElementById('ru-add-modal').style.display = 'flex';
  }

  function submitAddRU() {
    var cid = parseInt(document.getElementById('ru-add-cid').value);
    var uid = parseInt(document.getElementById('ru-add-uid').value);

    if (isNaN(cid) || isNaN(uid)) {
      App.showToast('Please select a concept and a recommended unit.', 'error');
      return;
    }

    var exists = ruData.some(function(r, i) {
      return i !== ruEditIdx && r.conceptId === cid && r.recommendedUnitConceptId === uid;
    });
    if (exists) {
      App.showToast('This recommended unit already exists.', 'warning');
      return;
    }

    var newRow = {
      conceptId: cid,
      conceptName: document.getElementById('ru-add-cname').value.trim(),
      conceptCode: document.getElementById('ru-add-ccode').value.trim(),
      vocabularyId: document.getElementById('ru-add-vocab').value.trim(),
      domainId: document.getElementById('ru-add-domain').value.trim(),
      recommendedUnitConceptId: uid,
      recommendedUnitName: document.getElementById('ru-add-uname').value.trim(),
      recommendedUnitCode: document.getElementById('ru-add-ucode').value.trim(),
      recommendedUnitVocabularyId: document.getElementById('ru-add-uvocab').value.trim()
    };

    document.getElementById('ru-add-modal').style.display = 'none';
    if (ruEditIdx !== null) {
      ruData[ruEditIdx] = newRow;
      ruEditIdx = null;
      renderRUTable();
      App.showToast('Recommended unit updated.', 'success');
    } else {
      ruData.push(newRow);
      ruPage = Math.ceil(ruData.length / ruPageSize);
      renderRUTable();
      App.showToast('Recommended unit added.', 'success');
    }
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

  // ==================== EDIT (SELECTION) MODE ====================
  // Generic toolbar/column toggling for both settings tables, mirroring the
  // Data Dictionary list. `cfg` bundles the table's ids + state accessors.
  var CONV_CFG = {
    tableId: 'conv-table', prefix: 'conv',
    getMode: function() { return convEditMode; }, setMode: function(v) { convEditMode = v; },
    selected: function() { return convSelected; },
    render: function() { renderConvTable(); },
    data: function() { return convData; },
    deleteMsgOne: 'Are you sure you want to delete this conversion?',
    deleteMsgMany: function(n) { return 'Delete ' + n + ' selected conversions?'; }
  };
  var RU_CFG = {
    tableId: 'ru-table', prefix: 'ru',
    getMode: function() { return ruEditMode; }, setMode: function(v) { ruEditMode = v; },
    selected: function() { return ruSelected; },
    render: function() { renderRUTable(); },
    data: function() { return ruData; },
    deleteMsgOne: 'Are you sure you want to delete this recommended unit?',
    deleteMsgMany: function(n) { return 'Delete ' + n + ' selected recommended units?'; }
  };

  function updateEditToolbar(cfg) {
    var on = cfg.getMode();
    document.getElementById(cfg.tableId).classList.toggle('selection-mode', on);
    var show = function(id, v) { var el = document.getElementById(id); if (el) el.style.display = v ? '' : 'none'; };
    // Normal-mode
    show(cfg.prefix + '-edit-btn', !on);
    show(cfg.prefix + '-export-btn', !on);
    // Edit-mode
    show(cfg.prefix + '-add-btn', on);
    show(cfg.prefix + '-select-all-btn', on);
    show(cfg.prefix + '-unselect-all-btn', on);
    show(cfg.prefix + '-delete-selected-btn', on);
    show(cfg.prefix + '-selection-count', on);
    show(cfg.prefix + '-list-cancel-btn', on);
    show(cfg.prefix + '-list-save-btn', on);
    updateSelectionCount(cfg);
  }

  function updateSelectionCount(cfg) {
    var el = document.getElementById(cfg.prefix + '-selection-count');
    if (el) el.textContent = cfg.selected().size + ' selected';
    var headerCb = document.getElementById(cfg.prefix + '-select-all-cb');
    if (headerCb) {
      var total = cfg.data().length;
      headerCb.checked = total > 0 && cfg.selected().size === total;
    }
  }

  function enterEditMode(cfg) {
    cfg.setMode(true);
    cfg.selected().clear();
    // Deep snapshot so Cancel can restore the pre-edit state.
    if (cfg === CONV_CFG) convSnapshot = JSON.parse(JSON.stringify(convData));
    else ruSnapshot = JSON.parse(JSON.stringify(ruData));
    updateEditToolbar(cfg);
    cfg.render();
  }

  function exitEditMode(cfg) {
    cfg.setMode(false);
    cfg.selected().clear();
    updateEditToolbar(cfg);
    cfg.render();
  }

  function cancelEditMode(cfg) {
    // Restore the snapshot taken on enter.
    if (cfg === CONV_CFG) { if (convSnapshot) convData = convSnapshot; convSnapshot = null; }
    else { if (ruSnapshot) ruData = ruSnapshot; ruSnapshot = null; }
    exitEditMode(cfg);
  }

  function saveEditMode(cfg) {
    // Edits are applied directly to the session arrays; Save just commits the
    // session (no snapshot to restore) and leaves edit mode.
    if (cfg === CONV_CFG) convSnapshot = null; else ruSnapshot = null;
    exitEditMode(cfg);
    App.showToast('Changes saved.', 'success');
  }

  function selectAllRows(cfg) {
    cfg.data().forEach(function(_, i) { cfg.selected().add(i); });
    updateSelectionCount(cfg);
    cfg.render();
  }

  function unselectAllRows(cfg) {
    cfg.selected().clear();
    updateSelectionCount(cfg);
    cfg.render();
  }

  function toggleRowSelection(cfg, idx) {
    if (cfg.selected().has(idx)) cfg.selected().delete(idx);
    else cfg.selected().add(idx);
    updateSelectionCount(cfg);
    var row = document.querySelector('#' + cfg.prefix + '-tbody tr[data-idx="' + idx + '"]');
    if (row) {
      var on = cfg.selected().has(idx);
      row.classList.toggle('selected', on);
      var cb = row.querySelector('.settings-row-checkbox');
      if (cb) cb.checked = on;
    }
  }

  function deleteSelectedRows(cfg) {
    var sel = cfg.selected();
    if (sel.size === 0) { App.showToast('No rows selected.', 'warning'); return; }
    var n = sel.size;
    pendingDelete = function() {
      // Remove highest indices first so earlier indices stay valid.
      var idxs = Array.from(sel).sort(function(a, b) { return b - a; });
      var arr = cfg.data();
      idxs.forEach(function(i) { arr.splice(i, 1); });
      sel.clear();
      updateSelectionCount(cfg);
      cfg.render();
      App.showToast(n + (n > 1 ? ' rows deleted.' : ' row deleted.'), 'success');
    };
    document.getElementById('delete-modal-msg').textContent = cfg.deleteMsgMany(n);
    document.getElementById('delete-modal').style.display = 'flex';
  }

  // ==================== CONCEPT PICKER ====================
  // Reusable single-select concept search modal (issue #6): IDs/names are no
  // longer typed by hand — the user picks a concept from the OHDSI vocabulary.
  var pickResults = [];      // raw rows from the last query
  var pickFiltered = [];     // pickResults after per-column filter + sort
  var pickSelected = null;   // currently highlighted row
  var pickPage = 1, pickPageSize = 50;
  // Per-column text filters ({ concept_name: 'foo', ... }) and sort, both
  // applied client-side over pickResults (the full SQL result, up to 10k rows).
  var pickColFilters = {};
  var pickSort = { key: '', asc: true };
  var pickOnSelect = null;   // callback(concept) when user confirms
  var pickKind = 'concept';  // 'concept' (any) | 'unit' (UCUM units)
  // Badge filters (multi-select), same model as the concept-sets Add modal.
  var pickFilterVocab = new Set(), pickFilterDomain = new Set(),
      pickFilterClass = new Set(), pickFilterStandard = new Set();
  var pickFiltersVisible = false;
  var pickDropdownsBuilt = false;
  var PICK_STANDARD_OPTIONS = ['S', 'C', 'non'];
  function pickStandardLabel(v) {
    return v === 'S' ? App.i18n('Standard') : v === 'C' ? App.i18n('Classification') : App.i18n('Non-standard');
  }
  function pickStandardLabelMap() {
    return { S: App.i18n('Standard'), C: App.i18n('Classification'), non: App.i18n('Non-standard') };
  }

  function openPicker(opts) {
    pickOnSelect = opts.onSelect;
    pickKind = opts.kind || 'concept';
    pickResults = [];
    pickFiltered = [];
    pickSelected = null;
    pickPage = 1;
    pickFilterVocab.clear(); pickFilterDomain.clear();
    pickFilterClass.clear(); pickFilterStandard.clear();
    pickFiltersVisible = false;
    pickDropdownsBuilt = false;
    document.getElementById('cpick-title').textContent =
      App.i18n(pickKind === 'unit' ? 'Select a unit' : 'Select a concept');
    document.getElementById('cpick-search').value = '';
    document.getElementById('cpick-limit').checked = true;
    document.getElementById('cpick-filters-popup').style.display = 'none';
    document.getElementById('cpick-results-tbody').innerHTML = '';
    document.getElementById('cpick-pagination').style.display = 'none';
    document.getElementById('cpick-submit').disabled = true;
    document.getElementById('cpick-selected-label').textContent =
      App.i18n(pickKind === 'unit' ? 'No unit selected' : 'No concept selected');

    var modal = document.getElementById('cpick-modal');
    var noDb = document.getElementById('cpick-no-db');
    var searchRow = document.getElementById('cpick-search-row');
    var resultsWrap = document.getElementById('cpick-results-wrap');

    // Immediate "loading…" feedback while the DB readiness check / remount and
    // the first query resolve — otherwise the modal looks blank/broken.
    function showLoading() {
      noDb.style.display = 'none';
      searchRow.style.display = 'flex';
      resultsWrap.style.display = 'flex';
      document.getElementById('cpick-results-tbody').innerHTML =
        '<tr><td colspan="7" class="td-center" style="padding:20px; color:var(--text-muted)">' +
        '<i class="fas fa-spinner fa-spin"></i> ' + App.i18n('Loading concepts...') + '</td></tr>';
    }
    function showReady() {
      noDb.style.display = 'none';
      searchRow.style.display = 'flex';
      resultsWrap.style.display = 'flex';
      buildPickerDropdowns().then(function() {
        renderPickerActiveFilters();
        loadPickerDefaults();
        document.getElementById('cpick-search').focus();
      });
    }
    function showNoDb() {
      noDb.style.display = '';
      noDb.innerHTML = '<i class="fas fa-info-circle" style="color:var(--primary); margin-right:6px"></i>' +
        App.i18n('Load OHDSI vocabularies in Dictionary Settings to search concepts.');
      searchRow.style.display = 'none';
      resultsWrap.style.display = 'none';
    }

    modal.classList.add('visible');
    if (typeof VocabDB === 'undefined') { showNoDb(); return; }
    showLoading();
    VocabDB.isDatabaseReady().then(function(ready) {
      if (ready) { showReady(); return; }
      VocabDB.remountFromStoredHandles().then(function(ok) {
        if (ok) showReady(); else showNoDb();
      }).catch(showNoDb);
    });
  }

  function closePicker() {
    document.getElementById('cpick-modal').classList.remove('visible');
    pickOnSelect = null;
  }

  // Restrict unit pickers to UCUM units. Concept pickers search everything.
  function pickerKindWhere() {
    return pickKind === 'unit' ? "domain_id = 'Unit'" : null;
  }

  // Build the Vocabulary / Domain / Class / Standard multi-select dropdowns
  // from the vocab's distinct values (same UX as the concept-sets Add modal).
  function buildPickerDropdowns() {
    if (pickDropdownsBuilt) return Promise.resolve();
    return Promise.all([
      VocabDB.query("SELECT DISTINCT vocabulary_id FROM concept WHERE vocabulary_id IS NOT NULL ORDER BY vocabulary_id"),
      VocabDB.query("SELECT DISTINCT domain_id FROM concept WHERE domain_id IS NOT NULL ORDER BY domain_id"),
      VocabDB.query("SELECT DISTINCT concept_class_id FROM concept WHERE concept_class_id IS NOT NULL ORDER BY concept_class_id")
    ]).then(function(results) {
      var vocabs = (results[0] || []).map(function(r) { return r.vocabulary_id; });
      var domains = (results[1] || []).map(function(r) { return r.domain_id; });
      var classes = (results[2] || []).map(function(r) { return r.concept_class_id; });
      App.buildMultiSelectDropdown('cpick-filter-vocab', vocabs, pickFilterVocab, renderPickerActiveFilters);
      App.buildMultiSelectDropdown('cpick-filter-domain', domains, pickFilterDomain, renderPickerActiveFilters);
      App.buildMultiSelectDropdown('cpick-filter-class', classes, pickFilterClass, renderPickerActiveFilters);
      App.buildMultiSelectDropdown('cpick-filter-standard', PICK_STANDARD_OPTIONS, pickFilterStandard, renderPickerActiveFilters, pickStandardLabelMap());
      pickDropdownsBuilt = true;
    });
  }

  // Translate the badge-filter state into SQL WHERE parts.
  function buildPickerFilterWhere() {
    var parts = [];
    var kw = pickerKindWhere(); if (kw) parts.push(kw);
    function inClause(col, set) {
      var vals = Array.from(set).map(function(v) { return "'" + v.replace(/'/g, "''") + "'"; });
      parts.push(col + ' IN (' + vals.join(',') + ')');
    }
    if (pickFilterVocab.size > 0) inClause('vocabulary_id', pickFilterVocab);
    if (pickFilterDomain.size > 0) inClause('domain_id', pickFilterDomain);
    if (pickFilterClass.size > 0) inClause('concept_class_id', pickFilterClass);
    if (pickFilterStandard.size > 0 && pickFilterStandard.size < PICK_STANDARD_OPTIONS.length) {
      var stdConds = [];
      if (pickFilterStandard.has('S')) stdConds.push("standard_concept = 'S'");
      if (pickFilterStandard.has('C')) stdConds.push("standard_concept = 'C'");
      if (pickFilterStandard.has('non')) stdConds.push("(standard_concept IS NULL OR standard_concept NOT IN ('S','C'))");
      parts.push('(' + stdConds.join(' OR ') + ')');
    }
    return parts;
  }

  // Render the active-filter badge chips below the search row.
  function renderPickerActiveFilters() {
    var wrap = document.getElementById('cpick-active-filters');
    if (!wrap) return;
    var chips = [];
    function chip(type, label, value) {
      chips.push('<span class="expr-add-chip" data-type="' + type + '"' +
        (value !== undefined ? ' data-value="' + App.escapeHtml(String(value)) + '"' : '') + '>' +
        '<span class="expr-add-chip-label">' + App.escapeHtml(label) + '</span>' +
        '<button class="expr-add-chip-x" title="' + App.i18n('Remove filter') + '"><i class="fas fa-times"></i></button></span>');
    }
    pickFilterVocab.forEach(function(v) { chip('vocab', App.i18n('Vocabulary') + ': ' + (v || '(empty)'), v); });
    pickFilterDomain.forEach(function(v) { chip('domain', App.i18n('Domain') + ': ' + (v || '(empty)'), v); });
    pickFilterClass.forEach(function(v) { chip('class', App.i18n('Class') + ': ' + (v || '(empty)'), v); });
    pickFilterStandard.forEach(function(v) { chip('standard', App.i18n('Standard') + ': ' + pickStandardLabel(v), v); });
    var hasAny = chips.length > 0;
    wrap.style.display = hasAny ? '' : 'none';
    wrap.innerHTML = chips.join('') +
      (hasAny ? '<button class="expr-add-chip-clear" id="cpick-chips-clear">' + App.i18n('Clear all') + '</button>' : '');
  }

  function rerunPicker() {
    if (document.getElementById('cpick-search').value.trim()) searchPicker();
    else loadPickerDefaults();
  }

  function syncPickerDropdown(type) {
    var containerId = 'cpick-filter-' + type;
    var set = type === 'vocab' ? pickFilterVocab : type === 'domain' ? pickFilterDomain
      : type === 'class' ? pickFilterClass : pickFilterStandard;
    var container = document.getElementById(containerId);
    if (container) {
      container.querySelectorAll('.ms-option input[type="checkbox"]').forEach(function(cb) {
        cb.checked = set.has(cb.value || '');
      });
    }
    if (App.updateMsToggleLabel) {
      App.updateMsToggleLabel(containerId, set, type === 'standard' ? pickStandardLabelMap() : undefined);
    }
  }

  function removePickerFilter(type, value) {
    if (type === 'vocab') pickFilterVocab.delete(value);
    else if (type === 'domain') pickFilterDomain.delete(value);
    else if (type === 'class') pickFilterClass.delete(value);
    else if (type === 'standard') pickFilterStandard.delete(value);
    syncPickerDropdown(type);
    renderPickerActiveFilters();
    rerunPicker();
  }

  function clearAllPickerFilters() {
    pickFilterVocab.clear(); pickFilterDomain.clear();
    pickFilterClass.clear(); pickFilterStandard.clear();
    ['vocab', 'domain', 'class', 'standard'].forEach(syncPickerDropdown);
    renderPickerActiveFilters();
    rerunPicker();
  }

  function loadPickerDefaults() {
    var tbody = document.getElementById('cpick-results-tbody');
    tbody.innerHTML = '<tr><td colspan="7" class="td-center" style="padding:20px; color:var(--text-muted)"><i class="fas fa-spinner fa-spin"></i> Loading concepts...</td></tr>';
    var parts = buildPickerFilterWhere();
    var whereStr = parts.length ? ' WHERE ' + parts.join(' AND ') : '';
    var limit = document.getElementById('cpick-limit').checked ? ' LIMIT 10000' : '';
    var sql = 'SELECT concept_id, concept_name, vocabulary_id, domain_id, concept_class_id, concept_code, standard_concept, invalid_reason ' +
      'FROM concept' + whereStr + ' ORDER BY concept_name' + limit;
    runPickerQuery(sql);
  }

  function searchPicker() {
    var q = document.getElementById('cpick-search').value.trim();
    if (!q) { loadPickerDefaults(); return; }
    var tbody = document.getElementById('cpick-results-tbody');
    tbody.innerHTML = '<tr><td colspan="7" class="td-center" style="padding:20px; color:var(--text-muted)"><i class="fas fa-spinner fa-spin"></i> Searching...</td></tr>';

    var esc = q.replace(/'/g, "''");
    var qLower = esc.toLowerCase();
    var isNumeric = /^\d+$/.test(q);
    var words = esc.split(/\s+/).filter(function(w) { return w.length > 0; });
    var FUZZY_THRESHOLD = 0.88;

    var searchConds = [];
    if (isNumeric) searchConds.push('concept_id = ' + q);
    searchConds.push("concept_code ILIKE '%" + esc + "%'");
    if (words.length > 1) {
      searchConds.push('(' + words.map(function(w) { return "concept_name ILIKE '%" + w + "%'"; }).join(' AND ') + ')');
    } else {
      searchConds.push("concept_name ILIKE '%" + esc + "%'");
    }
    searchConds.push("jaro_winkler_similarity(LOWER(concept_name), '" + qLower + "') >= " + FUZZY_THRESHOLD);

    var whereParts = ['(' + searchConds.join(' OR ') + ')'];
    whereParts = whereParts.concat(buildPickerFilterWhere());

    var rankExpr =
      'CASE ' +
        (isNumeric ? 'WHEN concept_id = ' + q + ' THEN 0 ' : '') +
        "WHEN LOWER(concept_code) = '" + qLower + "' THEN 0 " +
        "WHEN LOWER(concept_name) = '" + qLower + "' THEN 1 " +
        "WHEN LOWER(concept_name) LIKE '" + qLower + "%' THEN 2 " +
        'WHEN ' + words.map(function(w) { return "LOWER(concept_name) LIKE '%" + w.toLowerCase() + "%'"; }).join(' AND ') + ' THEN 3 ' +
        'ELSE 4 END';

    var limit = document.getElementById('cpick-limit').checked ? ' LIMIT 10000' : '';
    var sql = 'SELECT concept_id, concept_name, vocabulary_id, domain_id, concept_class_id, concept_code, standard_concept, invalid_reason, ' +
      rankExpr + ' AS match_rank, ' +
      "jaro_winkler_similarity(LOWER(concept_name), '" + qLower + "') AS fuzzy_score " +
      'FROM concept WHERE ' + whereParts.join(' AND ') +
      " ORDER BY match_rank, CASE WHEN standard_concept = 'S' THEN 0 ELSE 1 END, fuzzy_score DESC, LENGTH(concept_name), concept_name" + limit;
    runPickerQuery(sql);
  }

  function runPickerQuery(sql) {
    var tbody = document.getElementById('cpick-results-tbody');
    VocabDB.query(sql).then(function(rows) {
      pickResults = rows || [];
      // A fresh query supersedes the SQL ORDER BY relevance ranking, so start
      // with no client sort (keep that ranking) and the current column filters.
      pickSort = { key: '', asc: true };
      derivePickFiltered();
      pickSelected = null;
      document.getElementById('cpick-submit').disabled = true;
      document.getElementById('cpick-selected-label').textContent =
        App.i18n(pickKind === 'unit' ? 'No unit selected' : 'No concept selected');
      renderPickerResults();
    }).catch(function(err) {
      tbody.innerHTML = '<tr><td colspan="7" style="padding:20px; color:var(--danger)">' + App.escapeHtml(err.message) + '</td></tr>';
    });
  }

  // Human-readable Standard column value, so the column filter and sort act on
  // what the user actually sees ("Standard"/"Classification"/"Non-standard").
  function pickStandardText(r) {
    return r.standard_concept === 'S' ? 'Standard'
      : (r.standard_concept === 'C' ? 'Classification' : 'Non-standard');
  }

  function pickCellValue(r, col) {
    if (col === 'standard_concept') return pickStandardText(r);
    var v = r[col];
    return v == null ? '' : v;
  }

  // Rebuild pickFiltered from pickResults: apply each per-column text filter
  // (case-insensitive substring), then the active sort. Resets to page 1.
  function derivePickFiltered() {
    var rows = pickResults.filter(function(r) {
      for (var col in pickColFilters) {
        var q = (pickColFilters[col] || '').toLowerCase();
        if (!q) continue;
        if (String(pickCellValue(r, col)).toLowerCase().indexOf(q) === -1) return false;
      }
      return true;
    });
    pickFiltered = sortRows(rows, pickSort, function(r, key) {
      if (key === 'concept_id') return Number(r.concept_id);
      return pickCellValue(r, key);
    });
    pickPage = 1;
  }

  function renderPickerResults() {
    var tbody = document.getElementById('cpick-results-tbody');
    syncSortIndicators('cpick-results-table', pickSort);
    if (pickFiltered.length === 0) {
      tbody.innerHTML = '<tr><td colspan="7" class="td-center" style="padding:20px; color:var(--text-muted)">No results found.</td></tr>';
      document.getElementById('cpick-pagination').style.display = 'none';
      return;
    }
    var start = (pickPage - 1) * pickPageSize;
    var pageData = pickFiltered.slice(start, start + pickPageSize);
    tbody.innerHTML = pageData.map(function(r) {
      var cid = Number(r.concept_id);
      var active = pickSelected && Number(pickSelected.concept_id) === cid;
      var std = r.standard_concept === 'S' ? 'Standard' : (r.standard_concept === 'C' ? 'Classification' : 'Non-standard');
      var stdClass = r.standard_concept === 'S' ? 'flag-yes' : (r.standard_concept === 'C' ? '' : 'flag-yes-danger');
      return '<tr data-cid="' + cid + '"' + (active ? ' class="cpick-active-row"' : '') + '>' +
        '<td>' + cid + '</td>' +
        '<td>' + App.escapeHtml(r.concept_name) + '</td>' +
        '<td>' + App.escapeHtml(r.vocabulary_id) + '</td>' +
        '<td>' + App.escapeHtml(r.concept_code || '') + '</td>' +
        '<td>' + App.escapeHtml(r.domain_id || '') + '</td>' +
        '<td>' + App.escapeHtml(r.concept_class_id || '') + '</td>' +
        '<td class="td-center">' + (stdClass ? '<span class="' + stdClass + '">' + std + '</span>' : std) + '</td>' +
        '</tr>';
    }).join('');
    renderPagination('cpick-pagination', 'cpick-page-info', 'cpick-page-buttons', pickPage, pickFiltered.length, pickPageSize);
  }

  function selectPickerRow(cid) {
    var concept = pickFiltered.find(function(r) { return Number(r.concept_id) === cid; });
    if (!concept) return;
    pickSelected = concept;
    document.querySelectorAll('#cpick-results-tbody tr').forEach(function(tr) {
      tr.classList.toggle('cpick-active-row', Number(tr.dataset.cid) === cid);
    });
    document.getElementById('cpick-submit').disabled = false;
    document.getElementById('cpick-selected-label').textContent =
      concept.concept_id + ' — ' + concept.concept_name;
  }

  function confirmPicker() {
    if (!pickSelected || !pickOnSelect) return;
    var cb = pickOnSelect;
    var concept = pickSelected;
    closePicker();
    cb(concept);
  }

  // Fill a picker field's display chip after a concept is chosen.
  function setPickerDisplay(displayId, concept) {
    var el = document.getElementById(displayId);
    el.textContent = concept.concept_id + ' — ' + concept.concept_name;
    el.classList.remove('empty');
    el.title = concept.concept_id + ' — ' + concept.concept_name;
  }

  // Maps a field group's data-target to the hidden inputs + display it owns.
  // Each entry: {display, fields:{<concept prop>: <input id>}}.
  var PICKER_TARGETS = {
    'conv-add':     { display: 'conv-add-concept-display', fields: { concept_id: 'conv-add-cid', concept_name: 'conv-add-cname' } },
    'conv-add-src': { display: 'conv-add-src-display',     fields: { concept_id: 'conv-add-uid-src', concept_name: 'conv-add-uname-src', concept_code: 'conv-add-ucode-src' } },
    'conv-add-tgt': { display: 'conv-add-tgt-display',     fields: { concept_id: 'conv-add-uid-tgt', concept_name: 'conv-add-uname-tgt', concept_code: 'conv-add-ucode-tgt' } },
    'ru-add':       { display: 'ru-add-concept-display',   fields: { concept_id: 'ru-add-cid', concept_name: 'ru-add-cname', concept_code: 'ru-add-ccode', vocabulary_id: 'ru-add-vocab', domain_id: 'ru-add-domain' } },
    'ru-add-unit':  { display: 'ru-add-unit-display',      fields: { concept_id: 'ru-add-uid', concept_name: 'ru-add-uname', concept_code: 'ru-add-ucode', vocabulary_id: 'ru-add-uvocab' } }
  };

  function fillPickerTarget(target, concept) {
    var def = PICKER_TARGETS[target];
    if (!def) return;
    Object.keys(def.fields).forEach(function(prop) {
      var el = document.getElementById(def.fields[prop]);
      if (el) el.value = concept[prop] != null ? concept[prop] : '';
    });
    setPickerDisplay(def.display, concept);
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
      var rowCb = e.target.closest('.conv-row-checkbox');
      if (rowCb) { toggleRowSelection(CONV_CFG, parseInt(rowCb.dataset.idx)); return; }
      var rowEdit = e.target.closest('.conv-row-edit-btn');
      if (rowEdit) { openAddConvModal(parseInt(rowEdit.dataset.editIdx)); return; }
      var rowDel = e.target.closest('.conv-row-delete-btn');
      if (rowDel) { deleteConv(parseInt(rowDel.dataset.delIdx)); return; }
      var testBtn = e.target.closest('.btn-action-test');
      if (testBtn) { openTestConvModal(parseInt(testBtn.dataset.idx)); return; }
      var editCell = e.target.closest('.editable-cell');
      if (editCell) startEditFactor(editCell);
    });

    // Conversions: sortable headers
    document.querySelectorAll('#conv-table thead th[data-sort]').forEach(function(th) {
      th.addEventListener('click', function() {
        handleSortClick(convSort, th.dataset.sort, renderConvTable);
      });
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
    document.getElementById('conv-add-btn').addEventListener('click', function() { openAddConvModal(); });
    document.getElementById('conv-export-btn').addEventListener('click', exportConv);

    // Conversions: edit (selection) mode
    document.getElementById('conv-edit-btn').addEventListener('click', function() { enterEditMode(CONV_CFG); });
    document.getElementById('conv-list-cancel-btn').addEventListener('click', function() { cancelEditMode(CONV_CFG); });
    document.getElementById('conv-list-save-btn').addEventListener('click', function() { saveEditMode(CONV_CFG); });
    document.getElementById('conv-select-all-btn').addEventListener('click', function() { selectAllRows(CONV_CFG); });
    document.getElementById('conv-unselect-all-btn').addEventListener('click', function() { unselectAllRows(CONV_CFG); });
    document.getElementById('conv-delete-selected-btn').addEventListener('click', function() { deleteSelectedRows(CONV_CFG); });
    document.getElementById('conv-select-all-cb').addEventListener('change', function() {
      if (this.checked) selectAllRows(CONV_CFG); else unselectAllRows(CONV_CFG);
    });

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

    // ── Concept-picker field buttons (delegated on both Add modals) ──
    // Each field group carries data-target (which hidden inputs to fill) and
    // data-kind ('concept' | 'unit', for the picker's domain restriction).
    function wirePickerFields(modalId) {
      document.getElementById(modalId).addEventListener('click', function(e) {
        var btn = e.target.closest('.concept-picker-btn');
        if (!btn) return;
        var field = btn.closest('.concept-picker-field');
        if (!field) return;
        var target = field.dataset.target;
        openPicker({
          kind: field.dataset.kind,
          onSelect: function(c) { fillPickerTarget(target, c); }
        });
      });
    }
    wirePickerFields('conv-add-modal');
    wirePickerFields('ru-add-modal');

    // Concept picker modal controls
    document.getElementById('cpick-close').addEventListener('click', closePicker);
    document.getElementById('cpick-cancel').addEventListener('click', closePicker);
    document.getElementById('cpick-submit').addEventListener('click', confirmPicker);
    document.getElementById('cpick-search-btn').addEventListener('click', searchPicker);
    document.getElementById('cpick-search').addEventListener('keydown', function(e) {
      if (e.key === 'Enter') { e.preventDefault(); searchPicker(); }
    });
    document.getElementById('cpick-limit').addEventListener('change', rerunPicker);

    // Filters popup
    document.getElementById('cpick-filters-btn').addEventListener('click', function(e) {
      e.stopPropagation();
      pickFiltersVisible = !pickFiltersVisible;
      document.getElementById('cpick-filters-popup').style.display = pickFiltersVisible ? '' : 'none';
    });
    document.getElementById('cpick-filters-apply').addEventListener('click', function() {
      pickFiltersVisible = false;
      document.getElementById('cpick-filters-popup').style.display = 'none';
      renderPickerActiveFilters();
      rerunPicker();
    });
    document.getElementById('cpick-filters-clear').addEventListener('click', clearAllPickerFilters);
    // Badge chips: × removes one filter, "Clear all" resets
    document.getElementById('cpick-active-filters').addEventListener('click', function(e) {
      if (e.target.closest('#cpick-chips-clear')) { clearAllPickerFilters(); return; }
      var xBtn = e.target.closest('.expr-add-chip-x');
      if (!xBtn) return;
      var chip = xBtn.closest('.expr-add-chip');
      if (chip) removePickerFilter(chip.getAttribute('data-type'), chip.getAttribute('data-value'));
    });
    // Close the filters popup when clicking outside it
    document.getElementById('cpick-modal').addEventListener('click', function(e) {
      if (pickFiltersVisible &&
          !e.target.closest('#cpick-filters-popup') &&
          !e.target.closest('#cpick-filters-btn')) {
        pickFiltersVisible = false;
        document.getElementById('cpick-filters-popup').style.display = 'none';
      }
    });
    document.getElementById('cpick-results-tbody').addEventListener('click', function(e) {
      var tr = e.target.closest('tr[data-cid]');
      if (tr) selectPickerRow(Number(tr.dataset.cid));
    });
    document.getElementById('cpick-results-tbody').addEventListener('dblclick', function(e) {
      var tr = e.target.closest('tr[data-cid]');
      if (tr) { selectPickerRow(Number(tr.dataset.cid)); confirmPicker(); }
    });
    document.getElementById('cpick-page-buttons').addEventListener('click', function(e) {
      handlePageClick(e, pickFiltered.length, pickPageSize,
        function() { return pickPage; },
        function(p) { pickPage = p; },
        renderPickerResults, 'cpick-table-scroll');
    });
    // Per-column text filters (the second header row).
    document.getElementById('cpick-col-filter-row').addEventListener('input', function(e) {
      var input = e.target.closest('.column-filter');
      if (!input) return;
      pickColFilters[input.dataset.col] = input.value;
      derivePickFiltered();
      renderPickerResults();
    });
    // Column sort (click a header cell). The filter row is a separate <tr>, so
    // only the label row carries data-sort and triggers this.
    document.getElementById('cpick-results-table').querySelector('thead').addEventListener('click', function(e) {
      var th = e.target.closest('th[data-sort]');
      if (!th) return;
      handleSortClick(pickSort, th.dataset.sort, function() {
        derivePickFiltered();
        renderPickerResults();
      });
    });
    App.initColResize('cpick-results-table');

    // Test conversion modal
    document.getElementById('test-conv-close').addEventListener('click', function() {
      document.getElementById('test-conv-modal').style.display = 'none';
    });
    document.getElementById('test-conv-value').addEventListener('input', updateTestResult);
    document.getElementById('test-conv-modal').addEventListener('click', function(e) {
      if (e.target === this) this.style.display = 'none';
    });

    // Recommended units: column filters
    ['cid', 'cname', 'uname', 'ucode'].forEach(function(key) {
      var el = document.getElementById('ru-filter-' + key);
      if (el) el.addEventListener('input', function(e) {
        ruFilters[key] = e.target.value;
        ruPage = 1;
        renderRUTable();
      });
    });

    // Recommended units: table actions
    document.getElementById('ru-tbody').addEventListener('click', function(e) {
      var rowCb = e.target.closest('.ru-row-checkbox');
      if (rowCb) { toggleRowSelection(RU_CFG, parseInt(rowCb.dataset.idx)); return; }
      var rowEdit = e.target.closest('.ru-row-edit-btn');
      if (rowEdit) { openAddRUModal(parseInt(rowEdit.dataset.editIdx)); return; }
      var rowDel = e.target.closest('.ru-row-delete-btn');
      if (rowDel) { deleteRU(parseInt(rowDel.dataset.delIdx)); return; }
    });

    // Recommended units: sortable headers
    document.querySelectorAll('#ru-table thead th[data-sort]').forEach(function(th) {
      th.addEventListener('click', function() {
        handleSortClick(ruSort, th.dataset.sort, renderRUTable);
      });
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
    document.getElementById('ru-add-btn').addEventListener('click', function() { openAddRUModal(); });
    document.getElementById('ru-export-btn').addEventListener('click', exportRU);

    // Recommended units: edit (selection) mode
    document.getElementById('ru-edit-btn').addEventListener('click', function() { enterEditMode(RU_CFG); });
    document.getElementById('ru-list-cancel-btn').addEventListener('click', function() { cancelEditMode(RU_CFG); });
    document.getElementById('ru-list-save-btn').addEventListener('click', function() { saveEditMode(RU_CFG); });
    document.getElementById('ru-select-all-btn').addEventListener('click', function() { selectAllRows(RU_CFG); });
    document.getElementById('ru-unselect-all-btn').addEventListener('click', function() { unselectAllRows(RU_CFG); });
    document.getElementById('ru-delete-selected-btn').addEventListener('click', function() { deleteSelectedRows(RU_CFG); });
    document.getElementById('ru-select-all-cb').addEventListener('change', function() {
      if (this.checked) selectAllRows(RU_CFG); else unselectAllRows(RU_CFG);
    });

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
    // Column resize on the settings datatables (same as the concept-sets list).
    App.initColResize('conv-table');
    App.initColResize('ru-table');
  }

  function show(query) {
    init();
    // Support direct tab navigation via query param, e.g. #/settings?tab=vocabularies
    // skipUrl: the tab came from the URL, so don't rewrite it.
    if (query && query.tab) {
      switchTab(query.tab, true);
    } else {
      switchTab(activeTab, true);
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

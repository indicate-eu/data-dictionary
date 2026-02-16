// settings.js — Dictionary Settings page logic
(function() {
  'use strict';

  // ==================== STATE ====================
  var activeTab = 'etl';
  var etlEditor = null;

  // Session-editable copies
  var convData = [];
  var ruData = [];

  // Search state
  var convSearch = '';
  var ruSearch = '';

  // Export callback holder
  var pendingExport = null;

  // Delete callback holder
  var pendingDelete = null;

  // Test conversion state
  var testConvRow = null;
  var testConvSwapped = false;

  // ==================== TAB SWITCHING ====================
  function switchTab(tab) {
    activeTab = tab;
    document.querySelectorAll('#settings-tabs .settings-tab').forEach(function(btn) {
      btn.classList.toggle('active', btn.dataset.tab === tab);
    });
    ['etl', 'conversions', 'units'].forEach(function(t) {
      var el = document.getElementById('tab-' + t);
      if (el) el.style.display = (t === tab) ? '' : 'none';
    });
    if (tab === 'etl') initEtlEditor();
  }

  // ==================== ETL GUIDELINES ====================
  function initEtlEditor() {
    if (etlEditor) { etlEditor.resize(); return; }
    etlEditor = ace.edit('etl-ace-editor');
    etlEditor.setTheme('ace/theme/chrome');
    etlEditor.session.setMode('ace/mode/markdown');
    etlEditor.setFontSize(13);
    etlEditor.setShowPrintMargin(false);
    etlEditor.session.setUseWrapMode(true);
    etlEditor.setValue(App.etlGuidelines || '', -1);
    etlEditor.session.on('change', function() {
      var md = etlEditor.getValue();
      var preview = document.getElementById('etl-preview');
      if (!md.trim()) {
        preview.innerHTML = '<div class="markdown-preview-placeholder">Preview will appear here...</div>';
      } else {
        preview.innerHTML = marked.parse(md);
      }
    });
    // Trigger initial render
    var initMd = etlEditor.getValue();
    if (initMd.trim()) {
      document.getElementById('etl-preview').innerHTML = marked.parse(initMd);
    }
  }

  function exportEtl() {
    var content = etlEditor ? etlEditor.getValue() : (App.etlGuidelines || '');
    pendingExport = { content: content, filename: 'etl_guidelines.md', type: 'text/markdown' };
    document.getElementById('export-clipboard-desc').textContent = 'Copy Markdown content to clipboard';
    document.getElementById('export-file-desc').textContent = 'Download as etl_guidelines.md';
    document.getElementById('export-modal').style.display = 'flex';
  }

  // ==================== UNIT CONVERSIONS ====================
  function getFilteredConv() {
    if (!convSearch) return convData;
    return App.fuzzyFilter(convData, convSearch, function(row) {
      return [
        String(row.conceptId1), row.conceptName1 || '',
        row.unitName1 || '', String(row.conceptId2),
        row.conceptName2 || '', row.unitName2 || ''
      ];
    });
  }

  function renderConvTable() {
    var data = getFilteredConv();
    var tbody = document.getElementById('conv-tbody');
    if (data.length === 0) {
      tbody.innerHTML = '<tr><td colspan="8" class="empty-state"><p>No unit conversions' +
        (convSearch ? ' match your search' : ' defined') + '.</p></td></tr>';
      return;
    }
    tbody.innerHTML = data.map(function(row, i) {
      var idx = convData.indexOf(row);
      return '<tr data-idx="' + idx + '">' +
        '<td>' + row.conceptId1 + '</td>' +
        '<td>' + App.escapeHtml(row.conceptName1 || '') + '</td>' +
        '<td>' + App.escapeHtml(row.unitName1 || '') + '</td>' +
        '<td class="td-center editable-cell" data-field="conversionFactor" data-idx="' + idx + '">' +
          row.conversionFactor + '</td>' +
        '<td>' + row.conceptId2 + '</td>' +
        '<td>' + App.escapeHtml(row.conceptName2 || '') + '</td>' +
        '<td>' + App.escapeHtml(row.unitName2 || '') + '</td>' +
        '<td class="td-center">' +
          '<button class="btn-action btn-action-test" data-idx="' + idx + '" title="Test">' +
            '<i class="fas fa-calculator"></i> Test</button> ' +
          '<button class="btn-action btn-action-delete" data-idx="' + idx + '" title="Delete">' +
            '<i class="fas fa-trash"></i></button>' +
        '</td>' +
        '</tr>';
    }).join('');
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
    testConvSwapped = false;
    renderTestConv();
    document.getElementById('test-conv-value').value = '';
    document.getElementById('test-conv-result').textContent = '\u2014';
    document.getElementById('test-conv-modal').style.display = 'flex';
    document.getElementById('test-conv-value').focus();
  }

  function renderTestConv() {
    if (!testConvRow) return;
    var from, to, factor;
    if (!testConvSwapped) {
      from = (testConvRow.conceptName1 || 'Concept ' + testConvRow.conceptId1) +
        ' (' + (testConvRow.unitName1 || 'Unit ' + testConvRow.unitConceptId1) + ')';
      to = (testConvRow.conceptName2 || 'Concept ' + testConvRow.conceptId2) +
        ' (' + (testConvRow.unitName2 || 'Unit ' + testConvRow.unitConceptId2) + ')';
      factor = testConvRow.conversionFactor;
    } else {
      from = (testConvRow.conceptName2 || 'Concept ' + testConvRow.conceptId2) +
        ' (' + (testConvRow.unitName2 || 'Unit ' + testConvRow.unitConceptId2) + ')';
      to = (testConvRow.conceptName1 || 'Concept ' + testConvRow.conceptId1) +
        ' (' + (testConvRow.unitName1 || 'Unit ' + testConvRow.unitConceptId1) + ')';
      factor = testConvRow.conversionFactor !== 0 ? 1 / testConvRow.conversionFactor : 0;
    }
    document.getElementById('test-conv-info').innerHTML =
      App.escapeHtml(from) + ' <i class="fas fa-arrow-right" style="color:var(--primary)"></i> ' + App.escapeHtml(to);
    document.getElementById('test-conv-unit-from').textContent =
      testConvSwapped ? (testConvRow.unitName2 || '') : (testConvRow.unitName1 || '');
    document.getElementById('test-conv-factor-label').textContent = ' \u00d7 ' + factor.toFixed(6);
    updateTestResult();
  }

  function updateTestResult() {
    var val = parseFloat(document.getElementById('test-conv-value').value);
    var resultEl = document.getElementById('test-conv-result');
    if (isNaN(val) || !testConvRow) {
      resultEl.textContent = '\u2014';
      return;
    }
    var factor = testConvSwapped
      ? (testConvRow.conversionFactor !== 0 ? 1 / testConvRow.conversionFactor : 0)
      : testConvRow.conversionFactor;
    var result = val * factor;
    var unitLabel = testConvSwapped
      ? (testConvRow.unitName1 || '')
      : (testConvRow.unitName2 || '');
    resultEl.textContent = result.toFixed(4) + (unitLabel ? ' ' + unitLabel : '');
  }

  function openAddConvModal() {
    ['conv-add-cid1', 'conv-add-cname1', 'conv-add-uid1', 'conv-add-uname1',
     'conv-add-factor', 'conv-add-cid2', 'conv-add-cname2', 'conv-add-uid2', 'conv-add-uname2'
    ].forEach(function(id) { document.getElementById(id).value = ''; });
    document.getElementById('conv-add-modal').style.display = 'flex';
  }

  function submitAddConv() {
    var cid1 = parseInt(document.getElementById('conv-add-cid1').value);
    var uid1 = parseInt(document.getElementById('conv-add-uid1').value);
    var factor = parseFloat(document.getElementById('conv-add-factor').value);
    var cid2 = parseInt(document.getElementById('conv-add-cid2').value);
    var uid2 = parseInt(document.getElementById('conv-add-uid2').value);

    if (isNaN(cid1) || isNaN(uid1) || isNaN(factor) || isNaN(cid2) || isNaN(uid2)) {
      App.showToast('Please fill in all required fields (*).', 'error');
      return;
    }
    if (factor <= 0) {
      App.showToast('Conversion factor must be a positive number.', 'error');
      return;
    }

    // Check duplicate
    var exists = convData.some(function(r) {
      return r.conceptId1 === cid1 && r.unitConceptId1 === uid1 &&
             r.conceptId2 === cid2 && r.unitConceptId2 === uid2;
    });
    if (exists) {
      App.showToast('This conversion already exists.', 'warning');
      return;
    }

    convData.push({
      conceptId1: cid1,
      conceptName1: document.getElementById('conv-add-cname1').value.trim(),
      unitConceptId1: uid1,
      unitName1: document.getElementById('conv-add-uname1').value.trim(),
      conversionFactor: factor,
      conceptId2: cid2,
      conceptName2: document.getElementById('conv-add-cname2').value.trim(),
      unitConceptId2: uid2,
      unitName2: document.getElementById('conv-add-uname2').value.trim()
    });

    document.getElementById('conv-add-modal').style.display = 'none';
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
    pendingExport = { content: json, filename: 'unit_conversions.json', type: 'application/json' };
    document.getElementById('export-clipboard-desc').textContent = 'Copy JSON to clipboard';
    document.getElementById('export-file-desc').textContent = 'Download as unit_conversions.json';
    document.getElementById('export-modal').style.display = 'flex';
  }

  // ==================== RECOMMENDED UNITS ====================
  function getFilteredRU() {
    if (!ruSearch) return ruData;
    return App.fuzzyFilter(ruData, ruSearch, function(row) {
      return [
        String(row.conceptId), row.conceptName || '',
        row.conceptCode || '', String(row.recommendedUnitConceptId),
        row.recommendedUnitName || '', row.recommendedUnitCode || ''
      ];
    });
  }

  function renderRUTable() {
    var data = getFilteredRU();
    var tbody = document.getElementById('ru-tbody');
    if (data.length === 0) {
      tbody.innerHTML = '<tr><td colspan="7" class="empty-state"><p>No recommended units' +
        (ruSearch ? ' match your search' : ' defined') + '.</p></td></tr>';
      return;
    }
    tbody.innerHTML = data.map(function(row) {
      var idx = ruData.indexOf(row);
      return '<tr data-idx="' + idx + '">' +
        '<td>' + row.conceptId + '</td>' +
        '<td>' + App.escapeHtml(row.conceptName || '') + '</td>' +
        '<td>' + App.escapeHtml(row.conceptCode || '') + '</td>' +
        '<td>' + row.recommendedUnitConceptId + '</td>' +
        '<td>' + App.escapeHtml(row.recommendedUnitName || '') + '</td>' +
        '<td>' + App.escapeHtml(row.recommendedUnitCode || '') + '</td>' +
        '<td class="td-center">' +
          '<button class="btn-action btn-action-delete" data-ru-idx="' + idx + '" title="Delete">' +
            '<i class="fas fa-trash"></i></button>' +
        '</td>' +
        '</tr>';
    }).join('');
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
    pendingExport = { content: json, filename: 'recommended_units.json', type: 'application/json' };
    document.getElementById('export-clipboard-desc').textContent = 'Copy JSON to clipboard';
    document.getElementById('export-file-desc').textContent = 'Download as recommended_units.json';
    document.getElementById('export-modal').style.display = 'flex';
  }

  // ==================== SHARED EXPORT MODAL ====================
  function executeExport(method) {
    if (!pendingExport) return;
    if (method === 'clipboard') {
      navigator.clipboard.writeText(pendingExport.content).then(function() {
        App.showToast('Copied to clipboard!', 'success');
      }).catch(function() {
        App.showToast('Could not copy to clipboard.', 'error');
      });
    } else {
      var blob = new Blob([pendingExport.content], { type: pendingExport.type });
      var url = URL.createObjectURL(blob);
      var a = document.createElement('a');
      a.href = url;
      a.download = pendingExport.filename;
      a.click();
      URL.revokeObjectURL(url);
    }
    document.getElementById('export-modal').style.display = 'none';
    pendingExport = null;
  }

  // ==================== EVENTS ====================
  function initEvents() {
    // Tab switching
    document.getElementById('settings-tabs').addEventListener('click', function(e) {
      var btn = e.target.closest('.settings-tab');
      if (btn) switchTab(btn.dataset.tab);
    });

    // ETL export
    document.getElementById('etl-export-btn').addEventListener('click', exportEtl);

    // Conversions: search
    document.getElementById('conv-search').addEventListener('input', function(e) {
      convSearch = e.target.value;
      renderConvTable();
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
    document.getElementById('test-conv-cancel').addEventListener('click', function() {
      document.getElementById('test-conv-modal').style.display = 'none';
    });
    document.getElementById('test-conv-swap').addEventListener('click', function() {
      testConvSwapped = !testConvSwapped;
      renderTestConv();
    });
    document.getElementById('test-conv-value').addEventListener('input', updateTestResult);
    document.getElementById('test-conv-modal').addEventListener('click', function(e) {
      if (e.target === this) this.style.display = 'none';
    });

    // Recommended units: search
    document.getElementById('ru-search').addEventListener('input', function(e) {
      ruSearch = e.target.value;
      renderRUTable();
    });

    // Recommended units: table actions
    document.getElementById('ru-tbody').addEventListener('click', function(e) {
      var delBtn = e.target.closest('.btn-action-delete[data-ru-idx]');
      if (delBtn) deleteRU(parseInt(delBtn.dataset.ruIdx));
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

    // Export modal
    document.getElementById('export-modal-close').addEventListener('click', function() {
      document.getElementById('export-modal').style.display = 'none';
    });
    document.getElementById('export-cancel').addEventListener('click', function() {
      document.getElementById('export-modal').style.display = 'none';
    });
    document.getElementById('export-modal').addEventListener('click', function(e) {
      if (e.target === this) this.style.display = 'none';
    });
    document.querySelectorAll('#export-modal .export-option').forEach(function(opt) {
      opt.addEventListener('click', function() {
        executeExport(opt.dataset.method);
      });
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

    // Keyboard: Escape
    document.addEventListener('keydown', function(e) {
      if (e.key === 'Escape') {
        ['export-modal', 'conv-add-modal', 'test-conv-modal', 'delete-modal',
         'ru-add-modal', 'confirm-reset-modal', 'profile-modal'].forEach(function(id) {
          var el = document.getElementById(id);
          if (el && el.style.display !== 'none') el.style.display = 'none';
        });
      }
    });
  }

  // ==================== INIT ====================
  App.updateUserBadge();
  App.initSharedEvents();
  initEvents();
  App.loadData(function() {
    // Deep copy data into session-editable arrays
    convData = JSON.parse(JSON.stringify(App.unitConversions));
    ruData = JSON.parse(JSON.stringify(App.recommendedUnits));
    initEtlEditor();
    renderConvTable();
    renderRUTable();
  });
})();

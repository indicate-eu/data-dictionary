// concept-sets.js — Concept Sets page module
var ConceptSetsPage = (function() {
  'use strict';

  var GITHUB_REPO = 'indicate-eu/data-dictionary-content';
  var initialized = false;

  // ==================== CS STATE ====================
  var csPage = 1;
  var csPageSize = 25;
  var csSort = { key: 'category', asc: true };
  var csFilterName = '';
  var csCategories = new Set();
  var csSubcategories = new Set();
  var csFilterReviewStatus = new Set();
  var selectedConceptSet = null;
  var csDetailTab = 'concepts';
  var csConceptMode = 'resolved';
  var resolvedPage = 1;
  var resolvedPageSize = 50;
  var expressionPage = 1;
  var expressionPageSize = 50;

  // Selection mode state (CS list)
  var selectionMode = false;
  var selectedIds = new Set();

  // Expression editor state
  var exprEditMode = false;
  var exprEditItems = null;
  var exprSelectMode = false;
  var exprSelectedIdxs = new Set();
  var exprImportEditor = null;
  var addConceptResults = [];      // all results from SQL query
  var addConceptFiltered = [];     // after column-filter
  var addConceptSelectedIds = new Set();
  var addMultiSelect = false;
  var addSelectedConcept = null; // currently focused row in single-select mode
  var addFiltersVisible = false;
  var addPage = 1;
  var addPageSize = 50;
  // Pre-query filters (from filters popup) — Sets for multi-select
  var addFilterVocab = new Set();
  var addFilterDomain = new Set();
  var addFilterClass = new Set();
  var addFilterDropdownsBuilt = false;
  var addFilterStandard = 'S';
  var addFilterValid = true;
  // Persistent modal state (preserved across open/close)
  var addExclude = false;
  var addDescendants = false;
  var addMapped = false;
  var addSearchText = '';
  var addLimitChecked = true;
  var addColumnFilters = {}; // keyed by element id

  // ==================== FILTERING ====================
  function getFilteredCS() {
    var data = App.getCSData();
    if (csCategories.size > 0) data = data.filter(function(d) { return csCategories.has(d.category); });
    if (csSubcategories.size > 0) data = data.filter(function(d) { return csSubcategories.has(d.subcategory); });
    if (csFilterReviewStatus.size > 0) data = data.filter(function(d) { return csFilterReviewStatus.has(d.reviewStatus); });
    if (csFilterName) {
      var q = csFilterName.toLowerCase();
      data = data.filter(function(d) {
        var text = d.name.toLowerCase();
        var ti = 0;
        for (var qi = 0; qi < q.length; qi++) {
          var ch = q[qi];
          while (ti < text.length && text[ti] !== ch) ti++;
          if (ti >= text.length) return false;
          ti++;
        }
        return true;
      });
    }
    data.sort(function(a, b) {
      var va = (a[csSort.key] || '').toString().toLowerCase();
      var vb = (b[csSort.key] || '').toString().toLowerCase();
      if (va < vb) return csSort.asc ? -1 : 1;
      if (va > vb) return csSort.asc ? 1 : -1;
      return 0;
    });
    return data;
  }

  // ==================== CATEGORY BADGES ====================
  function renderCSCategories() {
    var counts = {};
    App.getCSData().forEach(function(d) { counts[d.category] = (counts[d.category] || 0) + 1; });
    var cats = Object.keys(counts).sort(function(a, b) {
      var aIsOther = a.toLowerCase() === 'other' || a.toLowerCase() === 'autres';
      var bIsOther = b.toLowerCase() === 'other' || b.toLowerCase() === 'autres';
      if (aIsOther && !bIsOther) return 1;
      if (!aIsOther && bIsOther) return -1;
      return a.localeCompare(b);
    });
    var el = document.getElementById('cs-categories');
    el.innerHTML = cats.map(function(cat) {
      return '<span class="category-badge' + (csCategories.has(cat) ? ' active' : '') +
        '" data-category="' + App.escapeHtml(cat) + '">' +
        App.escapeHtml(cat) + '<span class="count">' + counts[cat] + '</span></span>';
    }).join('');
  }

  // ==================== COLUMN FILTERS ====================
  function populateColumnFilters(skipId) {
    var data = App.getCSData();
    var categories = [...new Set(data.map(function(d) { return d.category; }))].sort(function(a, b) {
      var aO = a.toLowerCase() === 'other' || a.toLowerCase() === 'autres';
      var bO = b.toLowerCase() === 'other' || b.toLowerCase() === 'autres';
      if (aO && !bO) return 1;
      if (!aO && bO) return -1;
      return a.localeCompare(b);
    });

    var subData = data;
    if (csCategories.size > 0) subData = subData.filter(function(d) { return csCategories.has(d.category); });
    var subcategories = [...new Set(subData.map(function(d) { return d.subcategory; }))].filter(Boolean).sort();
    csSubcategories.forEach(function(s) { if (!subcategories.includes(s)) csSubcategories.delete(s); });

    var statuses = [...new Set(data.map(function(d) { return d.reviewStatus; }))].filter(Boolean).sort();

    if (skipId !== 'filter-category') {
      App.buildMultiSelectDropdown('filter-category', categories, csCategories, function() {
        csPage = 1;
        renderCSCategories();
        populateColumnFilters('filter-category');
        renderCSTable();
      });
    } else {
      App.updateMsToggleLabel('filter-category', csCategories);
    }

    if (skipId !== 'filter-subcategory') {
      App.buildMultiSelectDropdown('filter-subcategory', subcategories, csSubcategories, function() {
        csPage = 1;
        renderCSTable();
      });
    } else {
      App.updateMsToggleLabel('filter-subcategory', csSubcategories);
    }

    var statusLabelMap = {};
    statuses.forEach(function(s) { statusLabelMap[s] = App.statusLabelsMap[s] || s; });
    if (skipId !== 'filter-reviewStatus') {
      App.buildMultiSelectDropdown('filter-reviewStatus', statuses, csFilterReviewStatus, function() {
        csPage = 1;
        renderCSTable();
      }, statusLabelMap);
    } else {
      App.updateMsToggleLabel('filter-reviewStatus', csFilterReviewStatus);
    }
  }

  // ==================== CS TABLE ====================
  function renderCSTable() {
    var data = getFilteredCS();
    var totalPages = Math.ceil(data.length / csPageSize);
    if (csPage > totalPages) csPage = Math.max(1, totalPages);
    var start = (csPage - 1) * csPageSize;
    var pageData = data.slice(start, start + csPageSize);

    var tbody = document.getElementById('cs-tbody');
    tbody.innerHTML = pageData.map(function(d) {
      var isSelected = selectedIds.has(d.id);
      return '<tr data-id="' + d.id + '"' + (isSelected ? ' class="selected"' : '') + '>' +
        '<td class="cs-select-col"><input type="checkbox" class="cs-row-checkbox" data-id="' + d.id + '"' + (isSelected ? ' checked' : '') + '></td>' +
        '<td><span class="badge badge-category">' + App.escapeHtml(d.category) + '</span></td>' +
        '<td><span class="badge badge-subcategory">' + App.escapeHtml(d.subcategory) + '</span></td>' +
        '<td><strong>' + App.escapeHtml(d.name) + '</strong></td>' +
        '<td class="desc-truncated">' + App.escapeHtml(App.truncate(d.description, 100)) + '</td>' +
        '<td class="td-center">' + App.escapeHtml(d.version) + '</td>' +
        '<td class="td-center">' + App.statusBadge(d.reviewStatus) + '</td>' +
        '</tr>';
    }).join('');

    // Pagination
    document.getElementById('cs-page-info').textContent =
      'Showing ' + (data.length ? start + 1 : 0) + '-' + Math.min(start + csPageSize, data.length) + ' of ' + data.length;

    var btnContainer = document.getElementById('cs-page-buttons');
    var btns = '';
    btns += '<button ' + (csPage <= 1 ? 'disabled' : '') + ' data-page="first">&laquo;</button>';
    btns += '<button ' + (csPage <= 1 ? 'disabled' : '') + ' data-page="prev">&lsaquo;</button>';
    var maxButtons = 7;
    var startPage = Math.max(1, csPage - Math.floor(maxButtons / 2));
    var endPage = Math.min(totalPages, startPage + maxButtons - 1);
    if (endPage - startPage < maxButtons - 1) startPage = Math.max(1, endPage - maxButtons + 1);
    for (var i = startPage; i <= endPage; i++) {
      btns += '<button ' + (i === csPage ? 'class="active"' : '') + ' data-page="' + i + '">' + i + '</button>';
    }
    btns += '<button ' + (csPage >= totalPages ? 'disabled' : '') + ' data-page="next">&rsaquo;</button>';
    btns += '<button ' + (csPage >= totalPages ? 'disabled' : '') + ' data-page="last">&raquo;</button>';
    btnContainer.innerHTML = btns;

    // Sort indicators
    document.querySelectorAll('#cs-table thead th').forEach(function(th) {
      th.classList.toggle('sorted', th.dataset.sort === csSort.key);
      var icon = th.querySelector('.sort-icon');
      if (icon) icon.textContent = (th.dataset.sort === csSort.key && !csSort.asc) ? '\u25BC' : '\u25B2';
    });
  }

  // ==================== CS DETAIL: TABS & TOGGLE ====================
  function switchCSDetailTab(tabName) {
    csDetailTab = tabName;
    document.querySelectorAll('#cs-detail-tabs .tab-btn-blue').forEach(function(btn) {
      btn.classList.toggle('active', btn.dataset.tab === tabName);
    });
    ['concepts', 'comments', 'statistics', 'review'].forEach(function(t) {
      var el = document.getElementById('cs-tab-' + t);
      if (el) el.style.display = (t === tabName) ? '' : 'none';
    });
  }

  function updateViewJsonLink() {
    var link = document.getElementById('cs-view-json');
    if (!selectedConceptSet || !link) return;
    var folder = (csConceptMode === 'expression') ? 'concept_sets' : 'concept_sets_resolved';
    link.href = 'https://github.com/' + GITHUB_REPO + '/blob/main/' + folder + '/' + selectedConceptSet.id + '.json';
  }

  function switchConceptMode(mode) {
    csConceptMode = mode;
    document.querySelectorAll('#cs-concept-toggle-bar .toggle-btn').forEach(function(btn) {
      btn.classList.toggle('active', btn.dataset.mode === mode);
    });
    document.getElementById('cs-expression-view').style.display = (mode === 'expression') ? '' : 'none';
    document.getElementById('cs-resolved-view').style.display = (mode === 'resolved') ? '' : 'none';
    buildColVisDropdown();
    updateViewJsonLink();
    if (mode === 'expression') {
      expressionPage = 1;
      renderExpressionTable();
    } else {
      resolvedPage = 1;
      renderResolvedTable();
    }
    updateExprToolbar();
  }

  // ==================== PAGINATION HELPER ====================
  function renderPaginationControls(paginationId, pageInfoId, pageBtnsId, currentPage, totalItems, pageSize) {
    var paginationEl = document.getElementById(paginationId);
    var totalPages = Math.ceil(totalItems / pageSize);
    if (totalPages <= 0) totalPages = 1;
    var start = (currentPage - 1) * pageSize;
    document.getElementById(pageInfoId).textContent =
      totalItems === 0 ? 'No items' :
      'Showing ' + (start + 1) + '-' + Math.min(start + pageSize, totalItems) + ' of ' + totalItems;
    var btnContainer = document.getElementById(pageBtnsId);
    if (totalPages <= 1) {
      btnContainer.innerHTML = '';
      paginationEl.style.display = '';
      return;
    }
    paginationEl.style.display = '';
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

  // ==================== EXPRESSION TABLE ====================
  function renderExpressionTable() {
    if (!selectedConceptSet) return;
    var items = exprEditMode ? exprEditItems : ((selectedConceptSet.expression && selectedConceptSet.expression.items) || []);
    document.getElementById('cs-concept-count').textContent = items.length;
    var table = document.getElementById('expression-table');
    var tbody = document.getElementById('expression-tbody');
    var colSpan = exprEditMode ? 10 : 8;

    // Toggle table classes
    table.classList.toggle('expr-edit-mode', exprEditMode);
    table.classList.toggle('expr-select-mode', exprSelectMode);

    if (items.length === 0) {
      tbody.innerHTML = '<tr><td colspan="' + colSpan + '" class="empty-state"><p>No concepts in this concept set</p></td></tr>';
      renderPaginationControls('expression-pagination', 'expression-page-info', 'expression-page-buttons', 1, 0, expressionPageSize);
      return;
    }

    // Pagination
    var totalPages = Math.ceil(items.length / expressionPageSize);
    if (expressionPage > totalPages) expressionPage = Math.max(1, totalPages);
    var start = (expressionPage - 1) * expressionPageSize;
    var pageItems = items.slice(start, start + expressionPageSize);

    tbody.innerHTML = pageItems.map(function(item, pageIdx) {
      var i = start + pageIdx; // real index in items array
      var c = item.concept;
      var isExcl = item.isExcluded;
      var selChecked = exprSelectedIdxs.has(i) ? ' checked' : '';
      var rowClass = exprSelectedIdxs.has(i) ? ' class="expr-selected"' : '';

      var selectCol = '<td class="expr-select-col td-center"><input type="checkbox" class="expr-row-checkbox" data-idx="' + i + '"' + selChecked + '></td>';
      var actionCol = '<td class="expr-action-col td-center"><i class="fas fa-trash expr-delete-icon" data-idx="' + i + '"></i></td>';

      var excludeCell, descCell, mappedCell;
      if (exprEditMode) {
        var exclClass = isExcl ? ' toggle-exclude' : '';
        excludeCell = '<td class="td-center"><label class="toggle-switch toggle-sm toggle-exclude"><input type="checkbox" data-idx="' + i + '" data-field="isExcluded"' + (isExcl ? ' checked' : '') + '><span class="toggle-slider"></span></label></td>';
        descCell = '<td class="td-center"><label class="toggle-switch toggle-sm' + exclClass + '"><input type="checkbox" data-idx="' + i + '" data-field="includeDescendants"' + (item.includeDescendants ? ' checked' : '') + '><span class="toggle-slider"></span></label></td>';
        mappedCell = '<td class="td-center"><label class="toggle-switch toggle-sm' + exclClass + '"><input type="checkbox" data-idx="' + i + '" data-field="includeMapped"' + (item.includeMapped ? ' checked' : '') + '><span class="toggle-slider"></span></label></td>';
      } else {
        excludeCell = '<td class="td-center">' + (isExcl ? '<span class="flag-yes-danger">Yes</span>' : '<span class="flag-no">No</span>') + '</td>';
        descCell = '<td class="td-center">' + (item.includeDescendants ? '<span class="' + (isExcl ? 'flag-yes-danger' : 'flag-yes') + '">Yes</span>' : '<span class="flag-no">No</span>') + '</td>';
        mappedCell = '<td class="td-center">' + (item.includeMapped ? '<span class="' + (isExcl ? 'flag-yes-danger' : 'flag-yes') + '">Yes</span>' : '<span class="flag-no">No</span>') + '</td>';
      }

      return '<tr data-idx="' + i + '"' + rowClass + '>' +
        (exprEditMode ? selectCol : '') +
        '<td>' + App.escapeHtml(c.vocabularyId) + '</td>' +
        '<td>' + App.escapeHtml(c.conceptName) + '</td>' +
        '<td>' + App.escapeHtml(c.conceptCode) + '</td>' +
        '<td>' + App.escapeHtml(c.domainId) + '</td>' +
        '<td class="td-center">' + App.standardBadge(c) + '</td>' +
        excludeCell + descCell + mappedCell +
        (exprEditMode ? actionCol : '') +
        '</tr>';
    }).join('');
    applyColumnVisibility();
    renderPaginationControls('expression-pagination', 'expression-page-info', 'expression-page-buttons', expressionPage, items.length, expressionPageSize);
  }

  // ==================== EXPRESSION EDIT MODE ====================
  function enterExprEditMode() {
    if (!selectedConceptSet) return;
    exprEditMode = true;
    exprSelectMode = false;
    exprSelectedIdxs.clear();
    // Deep clone items
    var orig = (selectedConceptSet.expression && selectedConceptSet.expression.items) || [];
    exprEditItems = JSON.parse(JSON.stringify(orig));
    // Switch to expression tab if not already there
    if (csConceptMode !== 'expression') {
      switchConceptMode('expression');
    } else {
      renderExpressionTable();
    }
    updateExprToolbar();
  }

  function exitExprEditMode() {
    exprEditMode = false;
    exprSelectMode = false;
    exprSelectedIdxs.clear();
    exprEditItems = null;
    updateExprToolbar();
    if (csConceptMode === 'expression') renderExpressionTable();
  }

  function updateExprToolbar() {
    // Header-level buttons
    // Header-level buttons
    var headerEditBtn = document.getElementById('cs-edit-btn');
    var headerExportBtn = document.getElementById('cs-export-json');
    var headerImportBtn = document.getElementById('expr-import-btn');
    var headerCancelBtn = document.getElementById('cs-edit-cancel-btn');
    var headerSaveBtn = document.getElementById('cs-edit-save-btn');

    // Toggle-bar edit actions
    var editActions = document.getElementById('expr-edit-actions');
    var selectBtn = document.getElementById('expr-select-btn');
    var deleteSelBtn = document.getElementById('expr-delete-sel-btn');
    var selCount = document.getElementById('expr-selection-count');

    if (exprEditMode) {
      headerEditBtn.style.display = 'none';
      headerExportBtn.style.display = 'none';
      headerImportBtn.style.display = '';
      headerCancelBtn.style.display = '';
      headerSaveBtn.style.display = '';
      // Show edit actions on toggle bar when on expression tab
      editActions.style.display = (csConceptMode === 'expression') ? 'flex' : 'none';
      selectBtn.classList.toggle('active', exprSelectMode);
      deleteSelBtn.style.display = exprSelectMode ? '' : 'none';
      selCount.style.display = exprSelectMode ? '' : 'none';
      if (exprSelectMode) selCount.textContent = exprSelectedIdxs.size + ' selected';
    } else {
      headerEditBtn.style.display = '';
      headerExportBtn.style.display = '';
      headerImportBtn.style.display = 'none';
      headerCancelBtn.style.display = 'none';
      headerSaveBtn.style.display = 'none';
      editActions.style.display = 'none';
    }
  }

  function toggleExprSelectMode() {
    exprSelectMode = !exprSelectMode;
    if (!exprSelectMode) exprSelectedIdxs.clear();
    updateExprToolbar();
    renderExpressionTable();
  }

  function toggleExprRowSelection(idx) {
    if (exprSelectedIdxs.has(idx)) exprSelectedIdxs.delete(idx);
    else exprSelectedIdxs.add(idx);
    updateExprToolbar();
    // Update just the row visual + checkbox without full re-render
    var tr = document.querySelector('#expression-tbody tr[data-idx="' + idx + '"]');
    if (tr) {
      tr.classList.toggle('expr-selected', exprSelectedIdxs.has(idx));
      var cb = tr.querySelector('.expr-row-checkbox');
      if (cb) cb.checked = exprSelectedIdxs.has(idx);
    }
  }

  function deleteExprSelected() {
    if (exprSelectedIdxs.size === 0) return;
    // Sort descending so splice doesn't shift indices
    var sorted = Array.from(exprSelectedIdxs).sort(function(a, b) { return b - a; });
    sorted.forEach(function(idx) { exprEditItems.splice(idx, 1); });
    exprSelectedIdxs.clear();
    updateExprToolbar();
    renderExpressionTable();
  }

  function deleteExprRow(idx) {
    exprEditItems.splice(idx, 1);
    exprSelectedIdxs.clear();
    updateExprToolbar();
    renderExpressionTable();
  }

  function saveExprEdits() {
    if (!selectedConceptSet || !exprEditItems) return;
    if (!selectedConceptSet.expression) selectedConceptSet.expression = {};
    selectedConceptSet.expression.items = exprEditItems;
    selectedConceptSet.modifiedDate = new Date().toISOString().slice(0, 10);
    App.updateConceptSet(selectedConceptSet);
    exitExprEditMode();
    App.showToast('Expression saved');
  }

  function cancelExprEdits() {
    exitExprEditMode();
  }

  // ==================== IMPORT ATLAS JSON ====================
  function openImportModal() {
    document.getElementById('expr-import-modal').style.display = 'flex';
    document.getElementById('expr-import-error').style.display = 'none';
    if (!exprImportEditor) {
      exprImportEditor = ace.edit('expr-import-ace');
      exprImportEditor.setTheme('ace/theme/chrome');
      exprImportEditor.session.setMode('ace/mode/json');
      exprImportEditor.setFontSize(13);
      exprImportEditor.setShowPrintMargin(false);
    }
    exprImportEditor.setValue('', -1);
    exprImportEditor.focus();
  }

  function closeImportModal() {
    document.getElementById('expr-import-modal').style.display = 'none';
  }

  function submitImport() {
    var errEl = document.getElementById('expr-import-error');
    errEl.style.display = 'none';
    var text = exprImportEditor.getValue().trim();
    if (!text) {
      errEl.textContent = 'Please paste JSON content.';
      errEl.style.display = '';
      return;
    }
    var parsed;
    try { parsed = JSON.parse(text); } catch (e) {
      errEl.textContent = 'Invalid JSON: ' + e.message;
      errEl.style.display = '';
      return;
    }
    var rawItems = parsed.items;
    if (!rawItems || !Array.isArray(rawItems) || rawItems.length === 0) {
      errEl.textContent = 'JSON must contain a non-empty "items" array.';
      errEl.style.display = '';
      return;
    }
    // Build set of existing conceptIds for dedup
    var existingIds = {};
    exprEditItems.forEach(function(it) { existingIds[it.concept.conceptId] = true; });
    var added = 0;
    var skipped = 0;
    rawItems.forEach(function(raw) {
      var rc = raw.concept || {};
      // Support both ATLAS uppercase and our camelCase format
      var cid = rc.CONCEPT_ID || rc.conceptId;
      if (!cid) { skipped++; return; }
      if (existingIds[cid]) { skipped++; return; }
      existingIds[cid] = true;
      exprEditItems.push({
        concept: {
          conceptId: cid,
          conceptName: rc.CONCEPT_NAME || rc.conceptName || '',
          domainId: rc.DOMAIN_ID || rc.domainId || '',
          vocabularyId: rc.VOCABULARY_ID || rc.vocabularyId || '',
          conceptClassId: rc.CONCEPT_CLASS_ID || rc.conceptClassId || '',
          standardConcept: rc.STANDARD_CONCEPT || rc.standardConcept || '',
          standardConceptCaption: rc.STANDARD_CONCEPT_CAPTION || rc.standardConceptCaption || '',
          conceptCode: rc.CONCEPT_CODE || rc.conceptCode || '',
          validStartDate: rc.VALID_START_DATE || rc.validStartDate || '',
          validEndDate: rc.VALID_END_DATE || rc.validEndDate || '',
          invalidReason: rc.INVALID_REASON || rc.invalidReason || null,
          invalidReasonCaption: rc.INVALID_REASON_CAPTION || rc.invalidReasonCaption || 'Valid'
        },
        isExcluded: !!(raw.isExcluded),
        includeDescendants: !!(raw.includeDescendants),
        includeMapped: !!(raw.includeMapped)
      });
      added++;
    });
    closeImportModal();
    renderExpressionTable();
    var msg = added + ' concept' + (added !== 1 ? 's' : '') + ' imported';
    if (skipped > 0) msg += ', ' + skipped + ' skipped (duplicate or invalid)';
    App.showToast(msg);
  }

  // ==================== ADD CONCEPTS MODAL ====================
  function saveAddModalState() {
    addExclude = document.getElementById('expr-add-exclude').checked;
    addDescendants = document.getElementById('expr-add-descendants').checked;
    addMapped = document.getElementById('expr-add-mapped').checked;
    addSearchText = document.getElementById('expr-add-search').value;
    addLimitChecked = document.getElementById('expr-add-limit').checked;
    var cfIds = ['expr-add-cf-id','expr-add-cf-name','expr-add-cf-vocab','expr-add-cf-code','expr-add-cf-domain','expr-add-cf-class','expr-add-cf-standard'];
    cfIds.forEach(function(id) {
      var el = document.getElementById(id);
      if (el) addColumnFilters[id] = el.value;
    });
  }

  function openAddModal() {
    var modal = document.getElementById('expr-add-modal');
    var noDb = document.getElementById('expr-add-no-db');
    var resultsWrap = document.getElementById('expr-add-results-wrap');
    var bottom = document.getElementById('expr-add-bottom');
    var footer = document.querySelector('#expr-add-modal .modal-fs-footer');
    var searchRow = document.getElementById('expr-add-search-row');

    addConceptResults = [];
    addConceptFiltered = [];
    addConceptSelectedIds.clear();
    addSelectedConcept = null;
    addFiltersVisible = false;
    addPage = 1;
    document.getElementById('expr-add-results-tbody').innerHTML = '';
    document.getElementById('expr-add-pagination').style.display = 'none';
    document.getElementById('expr-add-select-all').checked = false;
    document.getElementById('expr-add-filters-popup').style.display = 'none';
    // Restore persisted state
    document.getElementById('expr-add-search').value = addSearchText;
    document.getElementById('expr-add-multiple').checked = addMultiSelect;
    document.getElementById('expr-add-exclude').checked = addExclude;
    document.getElementById('expr-add-descendants').checked = addDescendants;
    document.getElementById('expr-add-mapped').checked = addMapped;
    document.getElementById('expr-add-limit').checked = addLimitChecked;
    // Restore column filters
    ['expr-add-cf-id','expr-add-cf-name','expr-add-cf-vocab','expr-add-cf-code','expr-add-cf-domain','expr-add-cf-class','expr-add-cf-standard'].forEach(function(id) {
      var el = document.getElementById(id);
      if (el) el.value = addColumnFilters[id] || '';
    });
    // Sync filter popup inputs with state
    document.getElementById('expr-add-filter-standard').value = addFilterStandard;
    document.getElementById('expr-add-filter-valid').checked = addFilterValid;
    updateAddCount();
    resetAddDetailPanels();
    applyAddMultiSelect();

    function showReady() {
      noDb.style.display = 'none';
      resultsWrap.style.display = '';
      bottom.style.display = '';
      footer.style.display = '';
      searchRow.style.display = '';
      buildAddFilterDropdowns().then(function() {
        if (document.getElementById('expr-add-search').value.trim()) {
          searchAddConcepts();
        } else {
          loadAddDefaults();
        }
      });
    }
    function showNoDb() {
      noDb.style.display = '';
      resultsWrap.style.display = 'none';
      bottom.style.display = 'none';
      footer.style.display = 'none';
      searchRow.style.display = 'none';
    }

    if (typeof VocabDB === 'undefined') {
      showNoDb();
    } else {
      VocabDB.isDatabaseReady().then(function(ready) {
        if (ready) {
          showReady();
          return;
        }
        noDb.style.display = '';
        noDb.innerHTML = '<i class="fas fa-spinner fa-spin" style="color:var(--primary); margin-right:6px"></i>' +
          'Attempting to load vocabulary database...';
        resultsWrap.style.display = 'none';
        bottom.style.display = 'none';
        footer.style.display = 'none';
        searchRow.style.display = 'none';

        VocabDB.remountFromStoredHandles().then(function(ok) {
          if (ok) {
            showReady();
          } else {
            noDb.innerHTML = '<i class="fas fa-info-circle" style="color:var(--primary); margin-right:6px"></i>' +
              'Load OHDSI vocabularies in <a href="#/general-settings" style="color:var(--primary); font-weight:600">General Settings</a> to search concepts.';
            showNoDb();
          }
        }).catch(function() {
          noDb.innerHTML = '<i class="fas fa-info-circle" style="color:var(--primary); margin-right:6px"></i>' +
            'Load OHDSI vocabularies in <a href="#/general-settings" style="color:var(--primary); font-weight:600">General Settings</a> to search concepts.';
          showNoDb();
        });
      });
    }
    modal.classList.add('visible');
  }

  function closeAddModal() {
    saveAddModalState();
    document.getElementById('expr-add-modal').classList.remove('visible');
  }

  function resetAddDetailPanels() {
    var detailEl = document.getElementById('expr-add-detail-body');
    if (detailEl) detailEl.innerHTML = '<div class="empty-state"><p>Select a concept to view details</p></div>';
  }

  // --- Multiple selection toggle ---
  function applyAddMultiSelect() {
    var table = document.getElementById('expr-add-results-table');
    var bottom = document.getElementById('expr-add-bottom');
    if (addMultiSelect) {
      table.classList.add('add-multi-select');
      bottom.style.display = 'none';
    } else {
      table.classList.remove('add-multi-select');
      bottom.style.display = '';
    }
  }

  // --- Build multi-select filter dropdowns from DuckDB distinct values ---
  function buildAddFilterDropdowns() {
    if (addFilterDropdownsBuilt) return Promise.resolve();
    var queries = [
      VocabDB.query("SELECT DISTINCT vocabulary_id FROM concept WHERE vocabulary_id IS NOT NULL ORDER BY vocabulary_id"),
      VocabDB.query("SELECT DISTINCT domain_id FROM concept WHERE domain_id IS NOT NULL ORDER BY domain_id"),
      VocabDB.query("SELECT DISTINCT concept_class_id FROM concept WHERE concept_class_id IS NOT NULL ORDER BY concept_class_id")
    ];
    return Promise.all(queries).then(function(results) {
      var vocabs = (results[0] || []).map(function(r) { return r.vocabulary_id; });
      var domains = (results[1] || []).map(function(r) { return r.domain_id; });
      var classes = (results[2] || []).map(function(r) { return r.concept_class_id; });

      App.buildMultiSelectDropdown('expr-add-filter-vocab', vocabs, addFilterVocab, function() {});
      App.buildMultiSelectDropdown('expr-add-filter-domain', domains, addFilterDomain, function() {});
      App.buildMultiSelectDropdown('expr-add-filter-class', classes, addFilterClass, function() {});
      addFilterDropdownsBuilt = true;
    });
  }

  // --- Build common WHERE parts from filter popup state ---
  function buildAddFilterWhere() {
    var parts = [];
    if (addFilterVocab.size > 0) {
      var vals = Array.from(addFilterVocab).map(function(v) { return '\'' + v.replace(/'/g, "''") + '\''; });
      parts.push('vocabulary_id IN (' + vals.join(',') + ')');
    }
    if (addFilterDomain.size > 0) {
      var vals2 = Array.from(addFilterDomain).map(function(v) { return '\'' + v.replace(/'/g, "''") + '\''; });
      parts.push('domain_id IN (' + vals2.join(',') + ')');
    }
    if (addFilterClass.size > 0) {
      var vals3 = Array.from(addFilterClass).map(function(v) { return '\'' + v.replace(/'/g, "''") + '\''; });
      parts.push('concept_class_id IN (' + vals3.join(',') + ')');
    }
    if (addFilterStandard === 'S') {
      parts.push('standard_concept = \'S\'');
    } else if (addFilterStandard === 'C') {
      parts.push('standard_concept = \'C\'');
    } else if (addFilterStandard === 'non') {
      parts.push('(standard_concept IS NULL OR standard_concept NOT IN (\'S\',\'C\'))');
    }
    if (addFilterValid) {
      parts.push('(invalid_reason IS NULL OR invalid_reason = \'\')');
    }
    return parts;
  }

  // --- Load default results (no search term, just filters + limit) ---
  function loadAddDefaults() {
    var tbody = document.getElementById('expr-add-results-tbody');
    tbody.innerHTML = '<tr><td colspan="8" class="td-center" style="padding:20px; color:var(--text-muted)"><i class="fas fa-spinner fa-spin"></i> Loading concepts...</td></tr>';
    addConceptResults = [];
    addConceptFiltered = [];

    var whereParts = buildAddFilterWhere();

    var useLimit = document.getElementById('expr-add-limit').checked;
    var limitClause = useLimit ? ' LIMIT 10000' : '';
    var whereStr = whereParts.length ? ' WHERE ' + whereParts.join(' AND ') : '';

    var sql = 'SELECT concept_id, concept_name, vocabulary_id, domain_id, concept_class_id, concept_code, standard_concept, invalid_reason ' +
      'FROM concept' + whereStr +
      ' ORDER BY concept_name' + limitClause;

    VocabDB.query(sql).then(function(rows) {
      addConceptResults = rows || [];
      applyAddColumnFilters();
    }).catch(function(err) {
      tbody.innerHTML = '<tr><td colspan="8" style="padding:20px; color:var(--danger)">' + App.escapeHtml(err.message) + '</td></tr>';
    });
  }

  // --- Search ---
  function searchAddConcepts() {
    var q = document.getElementById('expr-add-search').value.trim();
    if (!q) { loadAddDefaults(); return; }
    var tbody = document.getElementById('expr-add-results-tbody');
    var colSpan = 8;
    tbody.innerHTML = '<tr><td colspan="' + colSpan + '" class="td-center" style="padding:20px; color:var(--text-muted)"><i class="fas fa-spinner fa-spin"></i> Searching...</td></tr>';
    addConceptResults = [];
    addConceptFiltered = [];
    addConceptSelectedIds.clear();
    addSelectedConcept = null;
    document.getElementById('expr-add-select-all').checked = false;
    updateAddCount();
    resetAddDetailPanels();

    // Build search conditions (multi-word: all words must match name, or exact match on code/id)
    var esc = q.replace(/'/g, "''");
    var isNumeric = /^\d+$/.test(q);
    var searchConds = [];
    if (isNumeric) {
      searchConds.push('concept_id = ' + q);
    }
    // Multi-word fuzzy: each word must appear in concept_name
    var words = esc.split(/\s+/).filter(function(w) { return w.length > 0; });
    if (words.length > 1) {
      var nameConds = words.map(function(w) { return 'concept_name ILIKE \'%' + w + '%\''; });
      searchConds.push('(' + nameConds.join(' AND ') + ')');
    } else {
      searchConds.push('concept_name ILIKE \'%' + esc + '%\'');
    }
    searchConds.push('concept_code ILIKE \'%' + esc + '%\'');

    var whereParts = ['(' + searchConds.join(' OR ') + ')'];
    whereParts = whereParts.concat(buildAddFilterWhere());

    var useLimit = document.getElementById('expr-add-limit').checked;
    var limitClause = useLimit ? ' LIMIT 10000' : '';

    var sql = 'SELECT concept_id, concept_name, vocabulary_id, domain_id, concept_class_id, concept_code, standard_concept, invalid_reason ' +
      'FROM concept WHERE ' + whereParts.join(' AND ') +
      ' ORDER BY CASE WHEN standard_concept = \'S\' THEN 0 ELSE 1 END, concept_name' + limitClause;

    VocabDB.query(sql).then(function(rows) {
      addConceptResults = rows || [];
      applyAddColumnFilters();
    }).catch(function(err) {
      tbody.innerHTML = '<tr><td colspan="' + colSpan + '" style="padding:20px; color:var(--danger)">' + App.escapeHtml(err.message) + '</td></tr>';
    });
  }

  // --- Column filters (client-side, on already-fetched results) ---
  function applyAddColumnFilters() {
    var cfId = (document.getElementById('expr-add-cf-id').value || '').trim().toLowerCase();
    var cfName = (document.getElementById('expr-add-cf-name').value || '').trim().toLowerCase();
    var cfVocab = (document.getElementById('expr-add-cf-vocab').value || '').trim().toLowerCase();
    var cfCode = (document.getElementById('expr-add-cf-code').value || '').trim().toLowerCase();
    var cfDomain = (document.getElementById('expr-add-cf-domain').value || '').trim().toLowerCase();
    var cfClass = (document.getElementById('expr-add-cf-class').value || '').trim().toLowerCase();
    var cfStd = (document.getElementById('expr-add-cf-standard').value || '').trim().toLowerCase();

    addPage = 1;
    var hasFilter = cfId || cfName || cfVocab || cfCode || cfDomain || cfClass || cfStd;
    if (!hasFilter) {
      addConceptFiltered = addConceptResults;
    } else {
      addConceptFiltered = addConceptResults.filter(function(r) {
        if (cfId && String(r.concept_id).indexOf(cfId) === -1) return false;
        if (cfName && (r.concept_name || '').toLowerCase().indexOf(cfName) === -1) return false;
        if (cfVocab && (r.vocabulary_id || '').toLowerCase().indexOf(cfVocab) === -1) return false;
        if (cfCode && (r.concept_code || '').toLowerCase().indexOf(cfCode) === -1) return false;
        if (cfDomain && (r.domain_id || '').toLowerCase().indexOf(cfDomain) === -1) return false;
        if (cfClass && (r.concept_class_id || '').toLowerCase().indexOf(cfClass) === -1) return false;
        if (cfStd) {
          var stdLabel = r.standard_concept === 'S' ? 'standard' : (r.standard_concept === 'C' ? 'classification' : 'non-standard');
          if (stdLabel.indexOf(cfStd) === -1) return false;
        }
        return true;
      });
    }
    renderAddResults();
  }

  // --- Render results ---
  function renderAddResults() {
    var tbody = document.getElementById('expr-add-results-tbody');
    var table = document.getElementById('expr-add-results-table');
    var colSpan = 8;
    // Show column filter row when we have results
    if (addConceptResults.length > 0) {
      table.classList.add('add-show-col-filters');
    } else {
      table.classList.remove('add-show-col-filters');
    }
    if (addConceptFiltered.length === 0) {
      var msg = addConceptResults.length > 0 ? 'No results match column filters.' : 'No results found.';
      tbody.innerHTML = '<tr><td colspan="' + colSpan + '" class="td-center" style="padding:20px; color:var(--text-muted)">' + msg + '</td></tr>';
      document.getElementById('expr-add-pagination').style.display = 'none';
      return;
    }
    // Pagination
    var totalPages = Math.ceil(addConceptFiltered.length / addPageSize);
    if (addPage > totalPages) addPage = Math.max(1, totalPages);
    var start = (addPage - 1) * addPageSize;
    var pageData = addConceptFiltered.slice(start, start + addPageSize);

    tbody.innerHTML = pageData.map(function(r) {
      var cid = Number(r.concept_id);
      var sel = addConceptSelectedIds.has(cid);
      var active = addSelectedConcept && Number(addSelectedConcept.concept_id) === cid;
      var std = r.standard_concept === 'S' ? 'Standard' : (r.standard_concept === 'C' ? 'Classification' : 'Non-standard');
      var stdClass = r.standard_concept === 'S' ? 'flag-yes' : (r.standard_concept === 'C' ? '' : 'flag-yes-danger');
      var rowClass = sel ? 'expr-selected' : (active ? 'add-active-row' : '');
      return '<tr data-cid="' + cid + '"' + (rowClass ? ' class="' + rowClass + '"' : '') + '>' +
        '<td class="expr-add-check-col td-center"><input type="checkbox" class="add-row-checkbox" data-cid="' + cid + '"' + (sel ? ' checked' : '') + '></td>' +
        '<td>' + cid + '</td>' +
        '<td>' + App.escapeHtml(r.concept_name) + '</td>' +
        '<td>' + App.escapeHtml(r.vocabulary_id) + '</td>' +
        '<td>' + App.escapeHtml(r.concept_code || '') + '</td>' +
        '<td>' + App.escapeHtml(r.domain_id || '') + '</td>' +
        '<td>' + App.escapeHtml(r.concept_class_id || '') + '</td>' +
        '<td class="td-center">' + (stdClass ? '<span class="' + stdClass + '">' + std + '</span>' : std) + '</td>' +
        '</tr>';
    }).join('');

    renderPaginationControls('expr-add-pagination', 'expr-add-page-info', 'expr-add-page-buttons', addPage, addConceptFiltered.length, addPageSize);
  }

  // --- Row interaction ---
  function handleAddRowClick(cid) {
    if (addMultiSelect) {
      toggleAddRow(cid);
    } else {
      // Single-select: focus row, show details + descendants
      var concept = addConceptFiltered.find(function(r) { return Number(r.concept_id) === cid; });
      if (!concept) return;
      addSelectedConcept = concept;
      addConceptSelectedIds.clear();
      addConceptSelectedIds.add(cid);
      updateAddCount();
      // Highlight active row
      document.querySelectorAll('#expr-add-results-tbody tr').forEach(function(tr) {
        tr.classList.toggle('add-active-row', Number(tr.dataset.cid) === cid);
        tr.classList.remove('expr-selected');
      });
      showAddConceptDetail(concept);
    }
  }

  function toggleAddRow(cid) {
    if (addConceptSelectedIds.has(cid)) addConceptSelectedIds.delete(cid);
    else addConceptSelectedIds.add(cid);
    var tr = document.querySelector('#expr-add-results-tbody tr[data-cid="' + cid + '"]');
    if (tr) {
      tr.classList.toggle('expr-selected', addConceptSelectedIds.has(cid));
      var cb = tr.querySelector('.add-row-checkbox');
      if (cb) cb.checked = addConceptSelectedIds.has(cid);
    }
    updateAddCount();
  }

  function toggleAddSelectAll() {
    var allCb = document.getElementById('expr-add-select-all');
    if (allCb.checked) {
      addConceptFiltered.forEach(function(r) { addConceptSelectedIds.add(Number(r.concept_id)); });
    } else {
      addConceptSelectedIds.clear();
    }
    renderAddResults();
    updateAddCount();
  }

  function updateAddCount() {
    var n = addConceptSelectedIds.size;
    document.getElementById('expr-add-count').textContent = n + ' selected';
    document.getElementById('expr-add-submit').disabled = (n === 0);
  }

  // --- Selected Concept Details panel ---
  function showAddConceptDetail(r) {
    var el = document.getElementById('expr-add-detail-body');
    var sc = r.standard_concept || '';
    var standardText = sc === 'S' ? 'Standard' : (sc === 'C' ? 'Classification' : 'Non-standard');
    var standardColor = sc === 'S' ? '#28a745' : (sc === 'C' ? '#6c757d' : '#dc3545');
    var isValid = !r.invalid_reason || r.invalid_reason === '';
    var validityText = isValid ? 'Valid' : 'Invalid';
    var validityColor = isValid ? '#28a745' : '#dc3545';

    // Check if already in expression
    var alreadyAdded = false;
    if (exprEditItems) {
      alreadyAdded = exprEditItems.some(function(it) { return it.concept.conceptId === Number(r.concept_id); });
    }
    var alreadyHtml = alreadyAdded ? '<div class="expr-add-already-badge"><i class="fas fa-check"></i> Already in expression</div>' : '';

    var athenaUrl = 'https://athena.ohdsi.org/search-terms/terms/' + r.concept_id;

    el.innerHTML = alreadyHtml +
      '<div class="concept-details-container"><div class="concept-details-grid">' +
      '<div class="detail-item"><strong>Concept Name:</strong><span>' + App.escapeHtml(r.concept_name) + '</span></div>' +
      '<div class="detail-item"><strong>View in ATHENA:</strong><span><a href="' + athenaUrl + '" target="_blank">' + r.concept_id + '</a></span></div>' +
      '<div class="detail-item"><strong>Vocabulary ID:</strong><span>' + App.escapeHtml(r.vocabulary_id) + '</span></div>' +
      '<div class="detail-item"><strong>Concept Code:</strong><span>' + App.escapeHtml(r.concept_code || '') + '</span></div>' +
      '<div class="detail-item"><strong>Domain:</strong><span>' + App.escapeHtml(r.domain_id || '') + '</span></div>' +
      '<div class="detail-item"><strong>Standard:</strong><span style="color:' + standardColor + ';font-weight:600">' + standardText + '</span></div>' +
      '<div class="detail-item"><strong>Concept Class:</strong><span>' + App.escapeHtml(r.concept_class_id || '') + '</span></div>' +
      '<div class="detail-item"><strong>Validity:</strong><span style="color:' + validityColor + ';font-weight:600">' + validityText + '</span></div>' +
      '</div></div>';
  }


  // --- Submit ---
  function submitAddConcepts() {
    if (addConceptSelectedIds.size === 0) return;
    var existingIds = {};
    exprEditItems.forEach(function(it) { existingIds[it.concept.conceptId] = true; });
    var isExcluded = document.getElementById('expr-add-exclude').checked;
    var includeDesc = document.getElementById('expr-add-descendants').checked;
    var includeMapped = document.getElementById('expr-add-mapped').checked;
    var added = 0;
    var skipped = 0;
    addConceptResults.forEach(function(r) {
      var cid = Number(r.concept_id);
      if (!addConceptSelectedIds.has(cid)) return;
      if (existingIds[cid]) { skipped++; return; }
      existingIds[cid] = true;
      var std = r.standard_concept || '';
      exprEditItems.push({
        concept: {
          conceptId: cid,
          conceptName: r.concept_name || '',
          domainId: r.domain_id || '',
          vocabularyId: r.vocabulary_id || '',
          conceptClassId: r.concept_class_id || '',
          standardConcept: std,
          standardConceptCaption: std === 'S' ? 'Standard' : (std === 'C' ? 'Classification' : 'Non-standard'),
          conceptCode: r.concept_code || '',
          validStartDate: '',
          validEndDate: '',
          invalidReason: null,
          invalidReasonCaption: 'Valid'
        },
        isExcluded: isExcluded,
        includeDescendants: includeDesc,
        includeMapped: includeMapped
      });
      added++;
    });
    renderExpressionTable();
    // Clear selection but keep modal open
    addConceptSelectedIds.clear();
    addSelectedConcept = null;
    document.getElementById('expr-add-select-all').checked = false;
    updateAddCount();
    resetAddDetailPanels();
    renderAddResults();
    var msg = added + ' concept' + (added !== 1 ? 's' : '') + ' added';
    if (skipped > 0) msg += ', ' + skipped + ' skipped (already in expression)';
    App.showToast(msg);
  }

  // ==================== RESOLVED TABLE ====================
  var resolvedFilterVocab = new Set();
  var resolvedFilterStandard = new Set(['S']);

  var resolvedColumns = {
    conceptId: { label: 'Concept ID', visible: true },
    vocabulary: { label: 'Vocabulary', visible: true },
    name: { label: 'Concept Name', visible: true },
    code: { label: 'Concept Code', visible: true },
    domain: { label: 'Domain', visible: false },
    standard: { label: 'Standard', visible: true },
    'class': { label: 'Concept Class', visible: false }
  };
  var expressionColumns = {
    vocabulary: { label: 'Vocabulary', visible: true },
    name: { label: 'Concept Name', visible: true },
    code: { label: 'Concept Code', visible: true },
    domain: { label: 'Domain', visible: true },
    standard: { label: 'Standard', visible: true },
    exclude: { label: 'Exclude', visible: true },
    descendants: { label: 'Descendants', visible: true },
    mapped: { label: 'Mapped', visible: true }
  };

  function getActiveColConfig() {
    return csConceptMode === 'expression' ? expressionColumns : resolvedColumns;
  }
  function getActiveTableId() {
    return csConceptMode === 'expression' ? 'expression-table' : 'resolved-table';
  }

  function applyColumnVisibility() {
    var cols = getActiveColConfig();
    var table = document.getElementById(getActiveTableId());
    var keys = Object.keys(cols);
    // In edit mode, tbody rows have extra select col at start → offset by 1
    var offset = (csConceptMode === 'expression' && exprEditMode) ? 1 : 0;
    keys.forEach(function(col) {
      var vis = cols[col].visible;
      table.querySelectorAll('[data-col="' + col + '"]').forEach(function(el) {
        el.style.display = vis ? '' : 'none';
      });
      var colIndex = keys.indexOf(col) + offset;
      table.querySelectorAll('tbody tr').forEach(function(tr) {
        var td = tr.children[colIndex];
        if (td) td.style.display = vis ? '' : 'none';
      });
    });
  }

  function buildColVisDropdown() {
    var cols = getActiveColConfig();
    var dd = document.getElementById('col-vis-dropdown');
    dd.innerHTML = Object.keys(cols).map(function(col) {
      var c = cols[col];
      return '<label><input type="checkbox" data-col="' + col + '"' +
        (c.visible ? ' checked' : '') + '> ' + App.escapeHtml(c.label) + '</label>';
    }).join('');
  }

  function standardLabel(sc) {
    if (sc === 'S') return 'Standard';
    if (sc === 'C') return 'Classification';
    return 'Non-standard';
  }

  function populateResolvedFilters(concepts) {
    var vocabs = {}, domains = {}, standards = {}, classes = {};
    concepts.forEach(function(c) {
      vocabs[c.vocabularyId || ''] = true;
      domains[c.domainId || ''] = true;
      var sc = c.standardConcept || '';
      standards[sc] = standardLabel(sc);
      classes[c.conceptClassId || ''] = true;
    });

    function fillSelect(id, values, labelMap) {
      var sel = document.getElementById(id);
      var cur = sel.value;
      var opts = '<option value="">All</option>';
      Object.keys(values).sort().forEach(function(v) {
        var label = labelMap ? (labelMap[v] || v) : v;
        opts += '<option value="' + App.escapeHtml(v) + '">' + App.escapeHtml(label || '(empty)') + '</option>';
      });
      sel.innerHTML = opts;
      sel.value = cur;
    }

    var vocabValues = Object.keys(vocabs).sort();
    App.buildMultiSelectDropdown('resolved-filter-vocabulary', vocabValues, resolvedFilterVocab, function() {
      resolvedPage = 1; renderResolvedTable(true);
    });

    fillSelect('resolved-filter-domain', domains);

    var stdValues = Object.keys(standards).sort();
    var stdLabels = {};
    stdValues.forEach(function(v) { stdLabels[v] = standards[v]; });
    App.buildMultiSelectDropdown('resolved-filter-standard', stdValues, resolvedFilterStandard, function() {
      resolvedPage = 1; renderResolvedTable(true);
    }, stdLabels);

    fillSelect('resolved-filter-class', classes);
  }

  function getResolvedFilters() {
    return {
      conceptId: document.getElementById('resolved-filter-conceptId').value.toLowerCase(),
      vocabulary: resolvedFilterVocab,
      name: document.getElementById('resolved-filter-name').value.toLowerCase(),
      code: document.getElementById('resolved-filter-code').value.toLowerCase(),
      domain: document.getElementById('resolved-filter-domain').value,
      standard: resolvedFilterStandard,
      conceptClass: document.getElementById('resolved-filter-class').value
    };
  }

  function fuzzyMatchBool(text, query) {
    var ti = 0;
    for (var qi = 0; qi < query.length; qi++) {
      var ch = query[qi];
      while (ti < text.length && text[ti] !== ch) ti++;
      if (ti >= text.length) return false;
      ti++;
    }
    return true;
  }

  function filterResolvedConcepts(concepts, filters) {
    return concepts.filter(function(c) {
      if (filters.conceptId && String(c.conceptId).toLowerCase().indexOf(filters.conceptId) === -1) return false;
      if (filters.vocabulary.size > 0 && !filters.vocabulary.has(c.vocabularyId || '')) return false;
      if (filters.name && !fuzzyMatchBool((c.conceptName || '').toLowerCase(), filters.name)) return false;
      if (filters.code && (c.conceptCode || '').toLowerCase().indexOf(filters.code) === -1) return false;
      if (filters.domain && (c.domainId || '') !== filters.domain) return false;
      if (filters.standard.size > 0 && !filters.standard.has(c.standardConcept || '')) return false;
      if (filters.conceptClass && (c.conceptClassId || '') !== filters.conceptClass) return false;
      return true;
    });
  }

  function renderResolvedTable(keepFilters) {
    if (!selectedConceptSet) return;
    var allConcepts = App.resolvedIndex[selectedConceptSet.id] || [];
    var tbody = document.getElementById('resolved-tbody');
    document.getElementById('resolved-concept-detail-body').innerHTML =
      '<div class="empty-state"><p>Select a concept to view details</p></div>';
    var colCount = Object.keys(resolvedColumns).length;

    if (!keepFilters) {
      document.getElementById('resolved-filter-conceptId').value = '';
      resolvedFilterVocab.clear();
      document.getElementById('resolved-filter-name').value = '';
      document.getElementById('resolved-filter-code').value = '';
      document.getElementById('resolved-filter-domain').value = '';
      resolvedFilterStandard.clear();
      resolvedFilterStandard.add('S');
      document.getElementById('resolved-filter-class').value = '';
    }

    populateResolvedFilters(allConcepts);

    var filters = getResolvedFilters();
    var concepts = filterResolvedConcepts(allConcepts, filters);
    document.getElementById('cs-concept-count').textContent = concepts.length + ' / ' + allConcepts.length;

    if (allConcepts.length === 0) {
      tbody.innerHTML = '<tr><td colspan="' + colCount + '" class="empty-state"><p>No resolved concepts available.</p></td></tr>';
      applyColumnVisibility();
      renderPaginationControls('resolved-pagination', 'resolved-page-info', 'resolved-page-buttons', 1, 0, resolvedPageSize);
      return;
    }
    if (concepts.length === 0) {
      tbody.innerHTML = '<tr><td colspan="' + colCount + '" class="empty-state"><p>No concepts match the current filters.</p></td></tr>';
      applyColumnVisibility();
      renderPaginationControls('resolved-pagination', 'resolved-page-info', 'resolved-page-buttons', 1, 0, resolvedPageSize);
      return;
    }

    // Pagination
    var totalPages = Math.ceil(concepts.length / resolvedPageSize);
    if (resolvedPage > totalPages) resolvedPage = Math.max(1, totalPages);
    var start = (resolvedPage - 1) * resolvedPageSize;
    var pageConcepts = concepts.slice(start, start + resolvedPageSize);

    tbody.innerHTML = pageConcepts.map(function(c) {
      var origIdx = allConcepts.indexOf(c);
      return '<tr data-idx="' + origIdx + '">' +
        '<td>' + c.conceptId + '</td>' +
        '<td>' + App.escapeHtml(c.vocabularyId) + '</td>' +
        '<td>' + App.escapeHtml(c.conceptName) + '</td>' +
        '<td>' + App.escapeHtml(c.conceptCode) + '</td>' +
        '<td>' + App.escapeHtml(c.domainId) + '</td>' +
        '<td class="td-center">' + App.standardBadge(c) + '</td>' +
        '<td>' + App.escapeHtml(c.conceptClassId) + '</td>' +
        '</tr>';
    }).join('');
    applyColumnVisibility();
    renderPaginationControls('resolved-pagination', 'resolved-page-info', 'resolved-page-buttons', resolvedPage, concepts.length, resolvedPageSize);
  }

  // ==================== CONCEPT DETAIL ====================
  function buildFhirUrl(vocabularyId, conceptCode) {
    var fhirSystems = {
      SNOMED: 'http://snomed.info/sct',
      LOINC: 'http://loinc.org',
      ICD10: 'http://hl7.org/fhir/sid/icd-10',
      ICD10CM: 'http://hl7.org/fhir/sid/icd-10-cm',
      UCUM: 'http://unitsofmeasure.org',
      RxNorm: 'http://www.nlm.nih.gov/research/umls/rxnorm'
    };
    var noLink = ['RxNorm Extension', 'OMOP Extension'];
    if (noLink.indexOf(vocabularyId) !== -1) return null;
    var system = fhirSystems[vocabularyId];
    if (!system) return null;
    return 'https://tx.fhir.org/r4/CodeSystem/$lookup?system=' +
      encodeURIComponent(system) + '&code=' + encodeURIComponent(conceptCode);
  }

  var currentConceptInDetail = null;

  function showResolvedConceptDetail(concept) {
    currentConceptInDetail = concept;
    var el = document.getElementById('resolved-concept-detail-body');
    var athenaUrl = 'https://athena.ohdsi.org/search-terms/terms/' + concept.conceptId;
    var fhirUrl = buildFhirUrl(concept.vocabularyId, concept.conceptCode);

    var sc = concept.standardConcept || '';
    var standardText = sc === 'S' ? 'Standard' : (sc === 'C' ? 'Classification' : 'Non-standard');
    var standardColor = sc === 'S' ? '#28a745' : (sc === 'C' ? '#6c757d' : '#dc3545');

    var isValid = !concept.invalidReason || concept.invalidReason === '' || concept.invalidReason === 'V';
    var validityText = isValid ? 'Valid' : 'Invalid (' + App.escapeHtml(concept.invalidReason || '') + ')';
    var validityColor = isValid ? '#28a745' : '#dc3545';

    var fhirHtml = fhirUrl
      ? '<a href="' + fhirUrl + '" target="_blank">' + App.escapeHtml(concept.vocabularyId) + '</a>'
      : '<span style="color:var(--text-muted)">No link available</span>';

    var backBtnHtml = conceptDetailHistory.length > 0
      ? '<div style="margin-bottom:8px"><button class="btn-outline-sm" id="concept-detail-back"><i class="fas fa-arrow-left"></i> Back</button></div>'
      : '';

    el.innerHTML = backBtnHtml +
      '<div class="concept-details-container"><div class="concept-details-grid">' +
      '<div class="detail-item"><strong>Concept Name:</strong><span>' + App.escapeHtml(concept.conceptName) + '</span></div>' +
      '<div class="detail-item"><strong>View in ATHENA:</strong><span><a href="' + athenaUrl + '" target="_blank">' + concept.conceptId + '</a></span></div>' +
      '<div class="detail-item"><strong>Vocabulary ID:</strong><span>' + App.escapeHtml(concept.vocabularyId) + '</span></div>' +
      '<div class="detail-item"><strong>FHIR Resource:</strong><span>' + fhirHtml + '</span></div>' +
      '<div class="detail-item"><strong>Concept Code:</strong><span>' + App.escapeHtml(concept.conceptCode) + '</span></div>' +
      '<div class="detail-item"><strong>Standard:</strong><span style="color:' + standardColor + ';font-weight:600">' + App.escapeHtml(standardText) + '</span></div>' +
      '<div class="detail-item"><strong>Domain:</strong><span>' + App.escapeHtml(concept.domainId) + '</span></div>' +
      '<div class="detail-item"><strong>Validity:</strong><span style="color:' + validityColor + ';font-weight:600">' + validityText + '</span></div>' +
      '<div class="detail-item"><strong>Concept Class:</strong><span>' + App.escapeHtml(concept.conceptClassId) + '</span></div>' +
      '<div></div>' +
      '</div></div>';

    // Wire up back button if present
    var backBtn = document.getElementById('concept-detail-back');
    if (backBtn) {
      backBtn.addEventListener('click', goBackConceptDetail);
    }

    // Append vocab tabs if DuckDB is ready, or try to auto-load, or show hint
    if (typeof VocabDB !== 'undefined') {
      VocabDB.isDatabaseReady().then(function(ready) {
        if (ready) {
          renderVocabTabs(concept, el);
          return;
        }
        // Try to auto-remount from IndexedDB / stored handles
        var loadingHint = document.createElement('div');
        loadingHint.style.cssText = 'margin-top:16px; padding:12px 16px; background:#f8f9fa; border:1px solid #e0e0e0; border-radius:6px; font-size:13px; color:#666';
        loadingHint.innerHTML = '<i class="fas fa-spinner fa-spin" style="color:var(--primary); margin-right:6px"></i>' +
          'Attempting to load vocabulary database...';
        el.appendChild(loadingHint);

        VocabDB.remountFromStoredHandles().then(function(ok) {
          loadingHint.remove();
          if (ok) {
            renderVocabTabs(concept, el);
          } else {
            showVocabLoadHint(el);
          }
        }).catch(function() {
          loadingHint.remove();
          showVocabLoadHint(el, concept);
        });
      });
    }
  }

  function showVocabLoadHint(el) {
    var hint = document.createElement('div');
    hint.style.cssText = 'margin-top:16px; padding:12px 16px; background:#f8f9fa; border:1px solid #e0e0e0; border-radius:6px; font-size:13px; color:#666';
    hint.innerHTML = '<i class="fas fa-info-circle" style="color:var(--primary); margin-right:6px"></i>' +
      'Load OHDSI vocabularies in <a href="#/general-settings" style="color:var(--primary); font-weight:600">General Settings</a>' +
      ' to view related concepts, hierarchy, and synonyms.';
    el.appendChild(hint);
  }

  // ==================== CONCEPT DETAIL NAVIGATION HISTORY ====================
  var conceptDetailHistory = [];

  function navigateToConceptDetail(conceptId, currentConcept) {
    if (currentConcept) {
      conceptDetailHistory.push(currentConcept);
    }
    VocabDB.lookupConcepts([conceptId]).then(function(concepts) {
      if (concepts.length > 0) {
        var c = concepts[0];
        showResolvedConceptDetail({
          conceptId: c.concept_id, conceptName: c.concept_name,
          vocabularyId: c.vocabulary_id, domainId: c.domain_id,
          conceptClassId: c.concept_class_id, conceptCode: c.concept_code,
          standardConcept: c.standard_concept
        });
      }
    });
  }

  function goBackConceptDetail() {
    if (conceptDetailHistory.length === 0) return;
    var prev = conceptDetailHistory.pop();
    showResolvedConceptDetail(prev);
  }

  // ==================== VOCAB TABS (Related / Hierarchy / Synonyms) ====================
  var vocabTabsHierarchyNetwork = null;
  var hierarchyHistory = [];
  var hierarchyPreviousId = null;
  var hierarchyIsFullscreen = false;
  var hierarchyWrapper = null; // persisted wrapper DOM element
  var lastVocabTab = 'related'; // remember last active vocab tab

  function renderVocabTabs(concept, containerEl) {
    hierarchyWrapper = null; // reset so a fresh wrapper is created for new concept
    var activeTab = lastVocabTab || 'related';
    var tabsHtml =
      '<div class="concept-vocab-tab-bar">' +
        '<button class="concept-vocab-tab' + (activeTab === 'related' ? ' active' : '') + '" data-vtab="related">Related</button>' +
        '<button class="concept-vocab-tab' + (activeTab === 'hierarchy' ? ' active' : '') + '" data-vtab="hierarchy">Hierarchy</button>' +
        '<button class="concept-vocab-tab' + (activeTab === 'synonyms' ? ' active' : '') + '" data-vtab="synonyms">Synonyms</button>' +
      '</div>' +
      '<div class="concept-vocab-content" data-vtab-content="related"' + (activeTab !== 'related' ? ' style="display:none"' : '') + '></div>' +
      '<div class="concept-vocab-content" data-vtab-content="hierarchy"' + (activeTab !== 'hierarchy' ? ' style="display:none"' : '') + '></div>' +
      '<div class="concept-vocab-content" data-vtab-content="synonyms"' + (activeTab !== 'synonyms' ? ' style="display:none"' : '') + '></div>';

    var wrapper = document.createElement('div');
    wrapper.style.cssText = 'display:flex; flex-direction:column; flex:1; min-height:0; overflow:hidden';
    wrapper.innerHTML = tabsHtml;
    containerEl.appendChild(wrapper);

    function getPanel(name) { return wrapper.querySelector('[data-vtab-content="' + name + '"]'); }

    // Tab switching
    var tabs = wrapper.querySelectorAll('.concept-vocab-tab');
    var loaded = {};
    for (var i = 0; i < tabs.length; i++) {
      tabs[i].addEventListener('click', function() {
        var vtab = this.getAttribute('data-vtab');
        lastVocabTab = vtab;
        for (var j = 0; j < tabs.length; j++) tabs[j].classList.toggle('active', tabs[j] === this);
        ['related', 'hierarchy', 'synonyms'].forEach(function(t) {
          var el = getPanel(t);
          if (el) el.style.display = (t === vtab) ? '' : 'none';
        });
        if (!loaded[vtab]) {
          loaded[vtab] = true;
          if (vtab === 'hierarchy') {
            hierarchyHistory = [];
            hierarchyPreviousId = null;
            loadHierarchyGraph(concept.conceptId, getPanel('hierarchy'));
          }
          if (vtab === 'synonyms') loadSynonyms(concept.conceptId, getPanel('synonyms'));
        }
      });
    }

    // Load the active tab
    function loadTab(name) {
      loaded[name] = true;
      if (name === 'related') loadRelatedConcepts(concept.conceptId, getPanel('related'));
      if (name === 'hierarchy') {
        hierarchyHistory = [];
        hierarchyPreviousId = null;
        loadHierarchyGraph(concept.conceptId, getPanel('hierarchy'));
      }
      if (name === 'synonyms') loadSynonyms(concept.conceptId, getPanel('synonyms'));
    }
    loadTab(activeTab);
  }

  var relatedRows = null;
  var relatedPage = 0;
  var RELATED_PAGE_SIZE = 50;
  var relatedEl = null;

  function loadRelatedConcepts(conceptId, el) {
    relatedEl = el;
    relatedRows = null;
    relatedPage = 0;
    el.innerHTML = '<div class="loading-inline"><i class="fas fa-spinner fa-spin"></i> Loading...</div>';
    VocabDB.query(
      'SELECT cr.relationship_id, c.concept_id, c.concept_name, c.vocabulary_id, ' +
      'c.domain_id, c.concept_class_id, c.concept_code, c.standard_concept ' +
      'FROM concept_relationship cr ' +
      'JOIN concept c ON c.concept_id = cr.concept_id_2 ' +
      'WHERE cr.concept_id_1 = ' + conceptId + ' ' +
      'ORDER BY cr.relationship_id, c.concept_name'
    ).then(function(rows) {
      if (!rows || rows.length === 0) {
        el.innerHTML = '<div class="loading-inline">No related concepts found.</div>';
        return;
      }
      relatedRows = rows;
      renderRelatedPage();
    }).catch(function(err) {
      el.innerHTML = '<div class="loading-inline" style="color:var(--danger)">Error: ' + App.escapeHtml(err.message) + '</div>';
    });
  }

  function renderRelatedPage() {
    if (!relatedRows || !relatedEl) return;
    var total = relatedRows.length;
    var totalPages = Math.ceil(total / RELATED_PAGE_SIZE);
    if (relatedPage >= totalPages) relatedPage = totalPages - 1;
    if (relatedPage < 0) relatedPage = 0;
    var start = relatedPage * RELATED_PAGE_SIZE;
    var end = Math.min(start + RELATED_PAGE_SIZE, total);

    var html = '<table class="concept-related-table"><thead><tr>' +
      '<th>Relationship</th><th>Concept ID</th><th>Concept Name</th><th>Vocabulary</th>' +
      '</tr></thead><tbody>';
    for (var i = start; i < end; i++) {
      var r = relatedRows[i];
      html += '<tr data-cid="' + r.concept_id + '" title="' +
        App.escapeHtml(r.concept_name) + ' [' + r.vocabulary_id + ']\n' +
        'Domain: ' + (r.domain_id || '') + ' | Class: ' + (r.concept_class_id || '') + '\n' +
        'Code: ' + (r.concept_code || '') + ' | Standard: ' + (r.standard_concept === 'S' ? 'Standard' : r.standard_concept || 'Non-standard') + '">' +
        '<td>' + App.escapeHtml(r.relationship_id) + '</td>' +
        '<td>' + r.concept_id + '</td>' +
        '<td>' + App.escapeHtml(r.concept_name) + '</td>' +
        '<td>' + App.escapeHtml(r.vocabulary_id) + '</td>' +
        '</tr>';
    }
    html += '</tbody></table>';

    if (totalPages > 1) {
      html += '<div class="related-pager">' +
        '<button class="btn-outline-sm" id="rel-prev"' + (relatedPage === 0 ? ' disabled' : '') + '><i class="fas fa-chevron-left"></i></button>' +
        '<span style="font-size:12px; color:var(--text-muted)">' + (start + 1) + '–' + end + ' of ' + total + '</span>' +
        '<button class="btn-outline-sm" id="rel-next"' + (relatedPage >= totalPages - 1 ? ' disabled' : '') + '><i class="fas fa-chevron-right"></i></button>' +
        '</div>';
    }

    relatedEl.innerHTML = html;

    // Pager events
    var prevBtn = document.getElementById('rel-prev');
    var nextBtn = document.getElementById('rel-next');
    if (prevBtn) prevBtn.addEventListener('click', function() { relatedPage--; renderRelatedPage(); });
    if (nextBtn) nextBtn.addEventListener('click', function() { relatedPage++; renderRelatedPage(); });

    // Click row to navigate (with history)
    relatedEl.querySelector('tbody').addEventListener('click', function(e) {
      var tr = e.target.closest('tr[data-cid]');
      if (!tr) return;
      var cid = parseInt(tr.getAttribute('data-cid'));
      navigateToConceptDetail(cid, currentConceptInDetail);
    });
  }

  var HIERARCHY_MAX_LEVELS = 5;
  var HIERARCHY_WARN_THRESHOLD = 100;

  function showHierarchyLoading() {
    // Show spinner inside existing canvas if wrapper exists, otherwise in the tab el
    if (hierarchyWrapper) {
      var canvas = hierarchyWrapper.querySelector('#hierarchy-graph-canvas');
      if (canvas) canvas.innerHTML = '<div class="loading-inline"><i class="fas fa-spinner fa-spin"></i> Loading hierarchy...</div>';
    }
  }

  function loadHierarchyGraph(conceptId, el) {
    if (hierarchyWrapper) {
      showHierarchyLoading();
    } else {
      el.innerHTML = '<div class="loading-inline"><i class="fas fa-spinner fa-spin"></i> Loading hierarchy...</div>';
    }

    // Step 1: count nodes first
    var countSql =
      'SELECT ' +
      '(SELECT COUNT(*) FROM concept_ancestor WHERE descendant_concept_id = ' + conceptId +
      ' AND min_levels_of_separation > 0 AND min_levels_of_separation <= ' + HIERARCHY_MAX_LEVELS + ') AS ancestors, ' +
      '(SELECT COUNT(*) FROM concept_ancestor WHERE ancestor_concept_id = ' + conceptId +
      ' AND min_levels_of_separation > 0 AND min_levels_of_separation <= ' + HIERARCHY_MAX_LEVELS + ') AS descendants';

    VocabDB.query(countSql).then(function(countRows) {
      var total = Number(countRows[0].ancestors) + Number(countRows[0].descendants) + 1;
      if (total > HIERARCHY_WARN_THRESHOLD) {
        var warningHtml =
          '<div class="hierarchy-warn-overlay">' +
            '<div class="hierarchy-warn-box">' +
              '<i class="fas fa-exclamation-triangle" style="color:var(--warning); font-size:18px"></i>' +
              '<div style="margin-top:8px">' +
                'This concept has <strong>' + total + '</strong> nodes in the hierarchy (' + HIERARCHY_MAX_LEVELS + ' levels). ' +
                'Loading may be slow.' +
              '</div>' +
              '<div style="display:flex; gap:8px; margin-top:12px">' +
                '<button class="btn-outline-sm" id="hierarchy-warn-cancel"><i class="fas fa-times"></i> Cancel</button>' +
                '<button class="btn-outline-sm" id="hierarchy-load-anyway"><i class="fas fa-project-diagram"></i> Load anyway</button>' +
              '</div>' +
            '</div>' +
          '</div>';

        if (hierarchyWrapper) {
          // Show overlay inside existing wrapper (preserves fullscreen)
          var overlay = document.createElement('div');
          overlay.innerHTML = warningHtml;
          overlay = overlay.firstChild;
          hierarchyWrapper.appendChild(overlay);
          overlay.querySelector('#hierarchy-warn-cancel').addEventListener('click', function() {
            overlay.remove();
          });
          overlay.querySelector('#hierarchy-load-anyway').addEventListener('click', function() {
            overlay.remove();
            showHierarchyLoading();
            buildHierarchyGraph(conceptId, el);
          });
        } else {
          // No wrapper yet — show warning in the tab element
          el.innerHTML = warningHtml;
          el.querySelector('#hierarchy-warn-cancel').addEventListener('click', function() {
            el.innerHTML = '<div class="loading-inline" style="color:var(--text-muted)">Cancelled.</div>';
          });
          el.querySelector('#hierarchy-load-anyway').addEventListener('click', function() {
            el.innerHTML = '<div class="loading-inline"><i class="fas fa-spinner fa-spin"></i> Loading hierarchy...</div>';
            buildHierarchyGraph(conceptId, el);
          });
        }
        return;
      }
      buildHierarchyGraph(conceptId, el);
    }).catch(function(err) {
      hierarchyWrapper = null;
      el.innerHTML = '<div class="loading-inline" style="color:var(--danger)">Error: ' + App.escapeHtml(err.message) + '</div>';
    });
  }

  function buildHierarchyGraph(conceptId, el) {
    var ancestorsSql =
      'SELECT c.concept_id, c.concept_name, c.vocabulary_id, c.domain_id, ' +
      'c.concept_class_id, c.concept_code, c.standard_concept, ' +
      '-ca.min_levels_of_separation AS hierarchy_level ' +
      'FROM concept_ancestor ca JOIN concept c ON c.concept_id = ca.ancestor_concept_id ' +
      'WHERE ca.descendant_concept_id = ' + conceptId +
      ' AND ca.min_levels_of_separation > 0 AND ca.min_levels_of_separation <= ' + HIERARCHY_MAX_LEVELS +
      ' ORDER BY ca.min_levels_of_separation';
    var descendantsSql =
      'SELECT c.concept_id, c.concept_name, c.vocabulary_id, c.domain_id, ' +
      'c.concept_class_id, c.concept_code, c.standard_concept, ' +
      'ca.min_levels_of_separation AS hierarchy_level ' +
      'FROM concept_ancestor ca JOIN concept c ON c.concept_id = ca.descendant_concept_id ' +
      'WHERE ca.ancestor_concept_id = ' + conceptId +
      ' AND ca.min_levels_of_separation > 0 AND ca.min_levels_of_separation <= ' + HIERARCHY_MAX_LEVELS +
      ' ORDER BY ca.min_levels_of_separation';
    var selfSql =
      'SELECT concept_id, concept_name, vocabulary_id, domain_id, concept_class_id, concept_code, standard_concept ' +
      'FROM concept WHERE concept_id = ' + conceptId;

    Promise.all([VocabDB.query(ancestorsSql), VocabDB.query(descendantsSql), VocabDB.query(selfSql)])
      .then(function(results) {
        var ancestors = results[0] || [];
        var descendants = results[1] || [];
        var self = results[2] && results[2][0];
        if (!self) {
          el.innerHTML = '<div class="loading-inline">Concept not found in vocabulary database.</div>';
          return;
        }

        // Collect all concept IDs for edges query
        var allIds = [Number(self.concept_id)];
        ancestors.forEach(function(a) { allIds.push(Number(a.concept_id)); });
        descendants.forEach(function(d) { allIds.push(Number(d.concept_id)); });

        if (allIds.length === 1) {
          el.innerHTML = '<div class="loading-inline">No hierarchy relationships found for this concept.</div>';
          return;
        }

        // Get direct parent-child edges between all nodes in the graph
        var edgesSql =
          'SELECT ancestor_concept_id AS from_id, descendant_concept_id AS to_id ' +
          'FROM concept_ancestor ' +
          'WHERE min_levels_of_separation = 1 ' +
          'AND ancestor_concept_id IN (' + allIds.join(',') + ') ' +
          'AND descendant_concept_id IN (' + allIds.join(',') + ')';

        return VocabDB.query(edgesSql).then(function(edgeRows) {
          renderHierarchyNetwork(self, ancestors, descendants, edgeRows || [], el);
        });
      })
      .catch(function(err) {
        el.innerHTML = '<div class="loading-inline" style="color:var(--danger)">Error: ' + App.escapeHtml(err.message) + '</div>';
      });
  }

  function conceptTooltipEl(c) {
    var std = c.standard_concept === 'S' ? 'Standard' : (c.standard_concept === 'C' ? 'Classification' : 'Non-standard');
    var div = document.createElement('div');
    div.style.cssText = 'font-size:12px; line-height:1.6; padding:2px 0';
    div.innerHTML =
      '<div><strong>' + App.escapeHtml(String(c.concept_name)) + '</strong></div>' +
      '<div>ID: ' + c.concept_id + '</div>' +
      '<div>Vocabulary: ' + App.escapeHtml(String(c.vocabulary_id)) + '</div>' +
      '<div>Code: ' + App.escapeHtml(String(c.concept_code || '')) + '</div>' +
      '<div>Domain: ' + App.escapeHtml(String(c.domain_id || '')) + '</div>' +
      '<div>Class: ' + App.escapeHtml(String(c.concept_class_id || '')) + '</div>' +
      '<div>Standard: ' + std + '</div>';
    return div;
  }

  function renderHierarchyNetwork(self, ancestors, descendants, edgeRows, el) {
    var selfId = Number(self.concept_id);
    var prevId = hierarchyPreviousId;
    var wrapper;

    if (hierarchyWrapper) {
      // Reuse existing wrapper — just update header + clear canvas
      wrapper = hierarchyWrapper;
      var titleEl = wrapper.querySelector('.hierarchy-header-title');
      if (titleEl) {
        titleEl.innerHTML = App.escapeHtml(self.concept_name) +
          '<span class="hierarchy-id">#' + selfId + '</span>';
      }
      var backBtn = wrapper.querySelector('#hierarchy-back-btn');
      if (backBtn) backBtn.disabled = (hierarchyHistory.length === 0);
      var canvas = wrapper.querySelector('#hierarchy-graph-canvas');
      if (canvas) canvas.innerHTML = '';
    } else {
      // First render — create the full wrapper
      var headerHtml =
        '<div class="hierarchy-header">' +
          '<button class="hierarchy-btn" id="hierarchy-back-btn" title="Back to previous concept"' +
            (hierarchyHistory.length === 0 ? ' disabled' : '') + '>' +
            '<i class="fas fa-arrow-left"></i></button>' +
          '<div class="hierarchy-header-title">' +
            App.escapeHtml(self.concept_name) +
            '<span class="hierarchy-id">#' + selfId + '</span>' +
          '</div>' +
          '<div class="hierarchy-controls">' +
            '<button class="hierarchy-btn" id="hierarchy-zoom-in" title="Zoom in"><i class="fas fa-search-plus"></i></button>' +
            '<button class="hierarchy-btn" id="hierarchy-zoom-out" title="Zoom out"><i class="fas fa-search-minus"></i></button>' +
            '<button class="hierarchy-btn" id="hierarchy-fit" title="Fit to view"><i class="fas fa-compress-arrows-alt"></i></button>' +
            '<button class="hierarchy-btn" id="hierarchy-fullscreen" title="Toggle fullscreen"><i class="fas fa-expand"></i></button>' +
          '</div>' +
        '</div>' +
        '<div id="hierarchy-graph-canvas" style="height:100%; flex:1"></div>';

      el.innerHTML = '';
      wrapper = document.createElement('div');
      wrapper.className = 'hierarchy-graph-container';
      wrapper.innerHTML = headerHtml;
      el.appendChild(wrapper);
      hierarchyWrapper = wrapper;

      // Wire up control buttons (only once)
      wrapper.querySelector('#hierarchy-back-btn').addEventListener('click', function() {
        if (hierarchyHistory.length > 0) {
          var prevConceptId = hierarchyHistory.pop();
          hierarchyPreviousId = selfId;
          loadHierarchyGraph(prevConceptId, el);
        }
      });

      wrapper.querySelector('#hierarchy-zoom-in').addEventListener('click', function() {
        if (!vocabTabsHierarchyNetwork) return;
        var scale = vocabTabsHierarchyNetwork.getScale();
        vocabTabsHierarchyNetwork.moveTo({ scale: scale * 1.3, animation: { duration: 300 } });
      });

      wrapper.querySelector('#hierarchy-zoom-out').addEventListener('click', function() {
        if (!vocabTabsHierarchyNetwork) return;
        var scale = vocabTabsHierarchyNetwork.getScale();
        vocabTabsHierarchyNetwork.moveTo({ scale: scale / 1.3, animation: { duration: 300 } });
      });

      wrapper.querySelector('#hierarchy-fit').addEventListener('click', function() {
        if (vocabTabsHierarchyNetwork) vocabTabsHierarchyNetwork.fit({ animation: { duration: 400 } });
      });

      wrapper.querySelector('#hierarchy-fullscreen').addEventListener('click', function() {
        hierarchyIsFullscreen = !hierarchyIsFullscreen;
        wrapper.classList.toggle('fullscreen', hierarchyIsFullscreen);
        var icon = this.querySelector('i');
        icon.className = hierarchyIsFullscreen ? 'fas fa-compress' : 'fas fa-expand';
        this.title = hierarchyIsFullscreen ? 'Exit fullscreen' : 'Toggle fullscreen';
        setTimeout(function() {
          if (vocabTabsHierarchyNetwork) vocabTabsHierarchyNetwork.fit({ animation: { duration: 300 } });
        }, 100);
      });

      // Esc to exit fullscreen
      if (!el._escHandler) {
        el._escHandler = function(e) {
          if (e.key === 'Escape' && hierarchyIsFullscreen) {
            hierarchyIsFullscreen = false;
            wrapper.classList.remove('fullscreen');
            var fsBtn = wrapper.querySelector('#hierarchy-fullscreen');
            if (fsBtn) {
              var icon = fsBtn.querySelector('i');
              icon.className = 'fas fa-expand';
              fsBtn.title = 'Toggle fullscreen';
            }
            setTimeout(function() {
              if (vocabTabsHierarchyNetwork) vocabTabsHierarchyNetwork.fit({ animation: { duration: 300 } });
            }, 100);
          }
        };
        document.addEventListener('keydown', el._escHandler);
      }
    }

    // Build nodes & edges
    var nodes = [];
    var edges = [];

    nodes.push({
      id: selfId,
      label: self.concept_name + '\n[' + self.vocabulary_id + ']',
      title: conceptTooltipEl(self),
      level: 0,
      shape: 'box',
      color: { background: '#0f60af', border: '#0a4a8a' },
      font: { color: '#fff', size: 12 },
      widthConstraint: { minimum: 140, maximum: 220 }
    });

    ancestors.forEach(function(a) {
      var aid = Number(a.concept_id);
      var isPrev = (aid === prevId);
      nodes.push({
        id: aid,
        label: a.concept_name + '\n[' + a.vocabulary_id + ']',
        title: conceptTooltipEl(a),
        level: Number(a.hierarchy_level),
        shape: 'box',
        color: isPrev
          ? { background: '#e67700', border: '#c66000' }
          : { background: '#6c757d', border: '#555' },
        font: { color: '#fff', size: 11 },
        widthConstraint: { minimum: 140, maximum: 220 }
      });
    });

    descendants.forEach(function(d) {
      var did = Number(d.concept_id);
      var isPrev = (did === prevId);
      nodes.push({
        id: did,
        label: d.concept_name + '\n[' + d.vocabulary_id + ']',
        title: conceptTooltipEl(d),
        level: Number(d.hierarchy_level),
        shape: 'box',
        color: isPrev
          ? { background: '#e67700', border: '#c66000' }
          : { background: '#28a745', border: '#1e7e34' },
        font: { color: '#fff', size: 11 },
        widthConstraint: { minimum: 140, maximum: 220 }
      });
    });

    edgeRows.forEach(function(e) {
      edges.push({ from: Number(e.from_id), to: Number(e.to_id), arrows: 'to' });
    });

    var canvasEl = wrapper.querySelector('#hierarchy-graph-canvas');
    var data = { nodes: new vis.DataSet(nodes), edges: new vis.DataSet(edges) };
    var options = {
      layout: {
        hierarchical: {
          direction: 'UD',
          sortMethod: 'directed',
          levelSeparation: 80,
          nodeSpacing: 120
        }
      },
      physics: false,
      interaction: {
        hover: true,
        zoomView: true,
        dragView: true,
        tooltipDelay: 200,
        navigationButtons: false
      },
      edges: {
        color: { color: '#ccc', hover: '#999' },
        smooth: { type: 'cubicBezier', roundness: 0.5 }
      }
    };

    if (vocabTabsHierarchyNetwork) vocabTabsHierarchyNetwork.destroy();
    vocabTabsHierarchyNetwork = new vis.Network(canvasEl, data, options);

    // Double-click on node: navigate hierarchy in-place
    vocabTabsHierarchyNetwork.on('doubleClick', function(params) {
      if (params.nodes.length === 1) {
        var cid = params.nodes[0];
        if (cid === selfId) return;
        hierarchyHistory.push(selfId);
        hierarchyPreviousId = selfId;
        loadHierarchyGraph(cid, el);
      }
    });
  }

  function loadSynonyms(conceptId, el) {
    el.innerHTML = '<div class="loading-inline"><i class="fas fa-spinner fa-spin"></i> Loading...</div>';
    VocabDB.query(
      'SELECT cs.concept_synonym_name, c.concept_name AS language ' +
      'FROM concept_synonym cs ' +
      'LEFT JOIN concept c ON c.concept_id = cs.language_concept_id ' +
      'WHERE cs.concept_id = ' + conceptId + ' ' +
      'ORDER BY c.concept_name, cs.concept_synonym_name'
    ).then(function(rows) {
        if (!rows || rows.length === 0) {
          el.innerHTML = '<div class="loading-inline">No synonyms found.</div>';
          return;
        }
        var html = '<table class="concept-related-table"><thead><tr>' +
          '<th>Synonym</th><th>Language</th>' +
          '</tr></thead><tbody>';
        rows.forEach(function(r) {
          html += '<tr><td>' + App.escapeHtml(r.concept_synonym_name) + '</td>' +
            '<td>' + App.escapeHtml(r.language || '') + '</td></tr>';
        });
        html += '</tbody></table>';
        el.innerHTML = html;
      })
      .catch(function(err) {
        el.innerHTML = '<div class="loading-inline" style="color:var(--danger)">Error: ' + App.escapeHtml(err.message) + '</div>';
      });
  }

  // ==================== TAB CONTENT ====================
  function renderCommentsTab(cs) {
    var el = document.getElementById('cs-comments-body');
    var tr = App.t(cs);
    var desc = cs.description || '';
    var longDesc = (tr && tr.longDescription) || '';
    if (!desc && !longDesc) {
      el.innerHTML = '<div class="empty-state"><p>No description available for this concept set.</p></div>';
      return;
    }
    var html = '';
    if (desc) {
      html += '<div style="margin-bottom:16px"><h4 style="font-size:14px; font-weight:600; color:var(--text-muted); text-transform:uppercase; letter-spacing:.5px; margin-bottom:8px">Description</h4>';
      html += '<div style="line-height:1.7">' + App.renderMarkdown(desc) + '</div></div>';
    }
    if (longDesc) {
      html += '<div><h4 style="font-size:14px; font-weight:600; color:var(--text-muted); text-transform:uppercase; letter-spacing:.5px; margin-bottom:8px">Detailed Description</h4>';
      html += '<div style="line-height:1.7">' + App.renderMarkdown(longDesc) + '</div></div>';
    }
    el.innerHTML = html;
  }

  function renderStatisticsTab(cs) {
    var el = document.getElementById('cs-statistics-body');
    var stats = cs.metadata && cs.metadata.distributionStats;
    if (!stats || Object.keys(stats).length === 0) {
      el.innerHTML = '<div class="empty-state">' +
        '<i class="fas fa-chart-bar" style="font-size:32px; color:var(--gray-300); display:block; margin-bottom:12px"></i>' +
        '<p>No distribution statistics available for this concept set.</p>' +
        '<p style="font-size:12px; margin-top:8px; color:var(--text-muted)">Statistics will appear here once computed via the INDICATE Data Dictionary application.</p>' +
        '</div>';
      return;
    }
    el.innerHTML = '<pre style="font-size:13px; overflow:auto; max-height:400px; background:var(--gray-light); padding:16px; border-radius:var(--radius)">' +
      App.escapeHtml(JSON.stringify(stats, null, 2)) + '</pre>';
  }

  function getReviewsForCS(cs) {
    var persisted = (cs.metadata && cs.metadata.reviews) || [];
    var session = App.sessionReviews[cs.id] || [];
    return persisted.concat(session);
  }

  function renderReviewTab(cs) {
    var reviews = getReviewsForCS(cs);
    document.getElementById('cs-review-count').textContent = reviews.length;

    var proposeBtn = document.getElementById('cs-propose-github');
    if (proposeBtn) {
      var hasSessionReviews = (App.sessionReviews[cs.id] || []).length > 0;
      proposeBtn.style.display = hasSessionReviews ? '' : 'none';
    }

    if (reviews.length === 0) {
      document.getElementById('cs-review-empty').style.display = '';
      document.getElementById('cs-review-table-wrap').style.display = 'none';
      return;
    }
    document.getElementById('cs-review-empty').style.display = 'none';
    document.getElementById('cs-review-table-wrap').style.display = '';
    var tbody = document.getElementById('cs-review-tbody');
    tbody.innerHTML = reviews.map(function(r) {
      var reviewer = r.reviewer || {};
      var name = ((reviewer.firstName || '') + ' ' + (reviewer.lastName || '')).trim();
      return '<tr>' +
        '<td>' + App.escapeHtml(name || 'Unknown') + '</td>' +
        '<td>' + App.escapeHtml(r.reviewDate || '') + '</td>' +
        '<td class="td-center">' + App.statusBadge(r.status) + '</td>' +
        '<td>' + App.escapeHtml(r.version || '') + '</td>' +
        '<td class="desc-truncated">' + App.escapeHtml(App.truncate(r.comments || '', 150)) + '</td>' +
        '</tr>';
    }).join('');
  }

  // ==================== CS DETAIL ====================
  function showCSDetail(id) {
    var cs = App.conceptSets.find(function(c) { return c.id === id; });
    if (!cs) return;
    selectedConceptSet = cs;
    var tr = App.t(cs);

    document.getElementById('cs-list-view').classList.add('hidden');
    document.getElementById('cs-detail-view').classList.add('active');

    document.getElementById('cs-detail-title').textContent = tr.name || cs.name;
    var statusClass = (cs.reviewStatus || 'draft').replace(/\s+/g, '_').toLowerCase();
    var statusLabel = (cs.reviewStatus || 'Draft').charAt(0).toUpperCase() + (cs.reviewStatus || 'draft').slice(1).replace(/_/g, ' ');
    document.getElementById('cs-detail-badges').innerHTML =
      '<span class="version-badge">v' + App.escapeHtml(cs.version || '1.0.0') + '</span>' +
      '<span class="status-badge ' + statusClass + '">' + App.escapeHtml(statusLabel) + '</span>';

    // Show Edit button for all concept sets
    document.getElementById('cs-edit-btn').style.display = '';
    document.getElementById('cs-edit-cancel-btn').style.display = 'none';
    document.getElementById('cs-edit-save-btn').style.display = 'none';

    switchCSDetailTab('concepts');
    switchConceptMode('resolved');
    updateViewJsonLink();

    renderCommentsTab(cs);
    renderStatisticsTab(cs);
    renderReviewTab(cs);
  }

  function hideCSDetail() {
    exitExprEditMode();
    document.getElementById('cs-edit-btn').style.display = 'none';
    document.getElementById('cs-edit-cancel-btn').style.display = 'none';
    document.getElementById('cs-edit-save-btn').style.display = 'none';
    document.getElementById('cs-detail-view').classList.remove('active');
    document.getElementById('cs-list-view').classList.remove('hidden');
    selectedConceptSet = null;
    csDetailTab = 'concepts';
    csConceptMode = 'resolved';
  }

  // ==================== REVIEW MODAL ====================
  var reviewAceEditor = null;

  function initReviewAceEditor() {
    if (reviewAceEditor) return;
    reviewAceEditor = ace.edit('review-ace-editor');
    reviewAceEditor.setTheme('ace/theme/chrome');
    reviewAceEditor.session.setMode('ace/mode/markdown');
    reviewAceEditor.setFontSize(12);
    reviewAceEditor.setShowPrintMargin(false);
    reviewAceEditor.session.setUseWrapMode(true);
    reviewAceEditor.session.on('change', function() {
      var md = reviewAceEditor.getValue();
      var preview = document.getElementById('review-preview');
      if (!md.trim()) {
        preview.innerHTML = '<div class="markdown-preview-placeholder">Preview will appear here...</div>';
      } else {
        preview.innerHTML = marked.parse(md);
      }
    });
  }

  function openReviewModal() {
    var p = App.getUserProfile();
    var name = ((p.firstName || '') + ' ' + (p.lastName || '')).trim();
    if (!name) {
      App.showToast('Please set up your profile first (click on "Guest" in the header).', 'warning');
      App.openProfileModal();
      return;
    }
    initReviewAceEditor();
    document.getElementById('review-status').value = '';
    reviewAceEditor.setValue('# Review Comments\n\nEnter your review comments here using Markdown syntax.\n\n## Suggestions\n\n- Item 1\n- Item 2\n', -1);
    document.getElementById('review-modal').classList.add('visible');
    reviewAceEditor.resize();
    reviewAceEditor.focus();
  }

  function closeReviewModal() {
    document.getElementById('review-modal').classList.remove('visible');
  }

  function submitReview() {
    var status = document.getElementById('review-status').value;
    if (!status) {
      App.showToast('Please select a review status.', 'error');
      return;
    }
    var comments = reviewAceEditor ? reviewAceEditor.getValue().trim() : '';
    if (!comments) {
      App.showToast('Review comments are required.', 'error');
      return;
    }

    var p = App.getUserProfile();
    var reviewerInfo = {
      firstName: p.firstName || '',
      lastName: p.lastName || '',
      affiliation: p.affiliation || '',
      profession: p.profession || '',
      orcid: p.orcid || ''
    };

    var existingReviews = getReviewsForCS(selectedConceptSet);
    var maxId = existingReviews.reduce(function(max, r) { return Math.max(max, r.reviewId || 0); }, 0);
    var review = {
      reviewId: maxId + 1,
      reviewer: reviewerInfo,
      reviewDate: new Date().toISOString().split('T')[0],
      status: status,
      comments: comments,
      version: selectedConceptSet.version || '1.0.0'
    };

    if (!App.sessionReviews[selectedConceptSet.id]) App.sessionReviews[selectedConceptSet.id] = [];
    App.sessionReviews[selectedConceptSet.id].push(review);
    App.saveSessionReviews();

    closeReviewModal();
    renderReviewTab(selectedConceptSet);
    App.showToast('Review submitted! Use "Propose on GitHub" to submit a pull request.', 'success', 5000);
  }

  // ==================== GITHUB PROPOSE ====================
  function proposeOnGitHub() {
    if (!selectedConceptSet) return;
    var json = buildIndicateJSON();
    navigator.clipboard.writeText(json).then(function() {
      App.showToast('JSON copied to clipboard! Paste it in the GitHub editor.', 'success', 5000);
    }).catch(function() {});
    var url = 'https://github.com/' + GITHUB_REPO + '/edit/main/concept_sets/' + selectedConceptSet.id + '.json';
    window.open(url, '_blank');
  }

  // ==================== JSON EXPORT ====================
  var exportMethod = null;

  function openExportModal() {
    if (!selectedConceptSet) return;
    exportMethod = null;
    document.getElementById('export-step-method').style.display = '';
    document.getElementById('export-step-format').style.display = 'none';
    document.getElementById('cs-export-back').style.display = 'none';
    document.getElementById('cs-export-modal').style.display = 'flex';
  }

  function closeExportModal() {
    document.getElementById('cs-export-modal').style.display = 'none';
  }

  function exportStepMethod(method) {
    exportMethod = method;
    document.getElementById('export-step-method').style.display = 'none';
    document.getElementById('export-step-format').style.display = '';
    document.getElementById('cs-export-back').style.display = '';
  }

  function exportStepBack() {
    exportMethod = null;
    document.getElementById('export-step-method').style.display = '';
    document.getElementById('export-step-format').style.display = 'none';
    document.getElementById('cs-export-back').style.display = 'none';
  }

  function buildIndicateJSON() {
    var cs = JSON.parse(JSON.stringify(selectedConceptSet));
    var sessionRevs = App.sessionReviews[cs.id] || [];
    if (sessionRevs.length > 0) {
      if (!cs.metadata) cs.metadata = {};
      if (!cs.metadata.reviews) cs.metadata.reviews = [];
      cs.metadata.reviews = cs.metadata.reviews.concat(sessionRevs);
    }
    return JSON.stringify(cs, null, 2);
  }

  function buildAtlasJSON() {
    var cs = selectedConceptSet;
    var items = (cs.expression && cs.expression.items) || [];
    var atlasItems = items.map(function(item) {
      var c = item.concept;
      var sc = c.standardConcept;
      var vs = (c.validStartDate || '19700101').replace(/-/g, '');
      var ve = (c.validEndDate || '20991231').replace(/-/g, '');
      return {
        concept: {
          CONCEPT_ID: c.conceptId,
          CONCEPT_NAME: c.conceptName,
          DOMAIN_ID: c.domainId,
          VOCABULARY_ID: c.vocabularyId,
          CONCEPT_CLASS_ID: c.conceptClassId,
          STANDARD_CONCEPT: sc || '',
          STANDARD_CONCEPT_CAPTION: sc === 'S' ? 'Standard' : (sc === 'C' ? 'Classification' : 'Non-Standard'),
          CONCEPT_CODE: c.conceptCode,
          VALID_START_DATE: vs,
          VALID_END_DATE: ve,
          INVALID_REASON: c.invalidReason || 'V',
          INVALID_REASON_CAPTION: c.invalidReasonCaption || 'Valid'
        },
        isExcluded: item.isExcluded || false,
        includeDescendants: item.includeDescendants || false,
        includeMapped: item.includeMapped || false
      };
    });
    return JSON.stringify({ items: atlasItems }, null, 2);
  }

  function executeExport(format) {
    if (!selectedConceptSet || !exportMethod) return;
    var json = (format === 'atlas') ? buildAtlasJSON() : buildIndicateJSON();
    var filename = selectedConceptSet.id + '.json';

    if (exportMethod === 'clipboard') {
      navigator.clipboard.writeText(json).then(function() {
        App.showToast('Copied to clipboard!', 'success');
      }).catch(function() {
        App.showToast('Could not copy to clipboard. Try downloading the file instead.', 'error');
      });
    } else {
      var blob = new Blob([json], { type: 'application/json' });
      var url = URL.createObjectURL(blob);
      var a = document.createElement('a');
      a.href = url;
      a.download = filename;
      a.click();
      URL.revokeObjectURL(url);
    }
    closeExportModal();
  }

  // ==================== RENDER ALL ====================
  function renderAll() {
    renderCSCategories();
    populateColumnFilters();
    renderCSTable();
  }

  // ==================== SELECTION MODE ====================
  function toggleSelectionMode() {
    selectionMode = !selectionMode;
    var table = document.getElementById('cs-table');
    var btn = document.getElementById('cs-select-mode-btn');
    table.classList.toggle('selection-mode', selectionMode);
    btn.classList.toggle('active', selectionMode);

    // Show/hide toolbar buttons
    document.getElementById('cs-select-all-btn').style.display = selectionMode ? '' : 'none';
    document.getElementById('cs-unselect-all-btn').style.display = selectionMode ? '' : 'none';
    document.getElementById('cs-delete-selected-btn').style.display = selectionMode ? '' : 'none';
    document.getElementById('cs-selection-count').style.display = selectionMode ? '' : 'none';

    if (!selectionMode) {
      selectedIds.clear();
      updateSelectionCount();
      renderCSTable();
    }
  }

  function updateSelectionCount() {
    var el = document.getElementById('cs-selection-count');
    el.textContent = selectedIds.size + ' selected';
  }

  function selectAll() {
    var data = getFilteredCS();
    data.forEach(function(d) { selectedIds.add(d.id); });
    updateSelectionCount();
    renderCSTable();
  }

  function unselectAll() {
    selectedIds.clear();
    updateSelectionCount();
    renderCSTable();
  }

  function toggleRowSelection(id) {
    if (selectedIds.has(id)) selectedIds.delete(id); else selectedIds.add(id);
    updateSelectionCount();
    // Update just the row instead of full re-render
    var row = document.querySelector('#cs-tbody tr[data-id="' + id + '"]');
    if (row) {
      row.classList.toggle('selected', selectedIds.has(id));
      var cb = row.querySelector('.cs-row-checkbox');
      if (cb) cb.checked = selectedIds.has(id);
    }
  }

  // ==================== DELETE SELECTED ====================
  function openDeleteConfirm() {
    if (selectedIds.size === 0) {
      App.showToast('No concept sets selected.', 'warning');
      return;
    }
    var userCount = 0;
    selectedIds.forEach(function(id) { if (App.isUserConceptSet(id)) userCount++; });
    var repoCount = selectedIds.size - userCount;
    var msg = 'Delete ' + selectedIds.size + ' selected concept set' + (selectedIds.size > 1 ? 's' : '') + '?';
    if (repoCount > 0 && userCount > 0) {
      msg += ' (' + userCount + ' local will be deleted, ' + repoCount + ' from repository will be skipped)';
    } else if (repoCount > 0 && userCount === 0) {
      msg = 'The selected concept sets are from the repository and cannot be deleted locally.';
    }
    document.getElementById('cs-delete-confirm-msg').textContent = msg;
    document.getElementById('cs-delete-confirm-modal').style.display = 'flex';
  }

  function closeDeleteConfirm() {
    document.getElementById('cs-delete-confirm-modal').style.display = 'none';
  }

  function executeDelete() {
    var ids = Array.from(selectedIds);
    var result = App.deleteConceptSets(ids);
    closeDeleteConfirm();
    selectedIds.clear();
    updateSelectionCount();
    renderAll();
    if (result.deleted > 0) {
      App.showToast(result.deleted + ' concept set' + (result.deleted > 1 ? 's' : '') + ' deleted.', 'success');
    }
    if (result.skipped > 0) {
      App.showToast(result.skipped + ' repository concept set' + (result.skipped > 1 ? 's' : '') + ' cannot be deleted.', 'warning');
    }
  }

  // ==================== BULK EXPORT ====================
  function openBulkExportModal() {
    // Show/hide the "Export Selected" option
    var selectedOption = document.getElementById('cs-bulk-export-selected-option');
    if (selectionMode && selectedIds.size > 0) {
      selectedOption.style.display = '';
      document.getElementById('cs-bulk-export-selected-desc').textContent =
        'Download ' + selectedIds.size + ' selected concept set' + (selectedIds.size > 1 ? 's' : '');
    } else {
      selectedOption.style.display = 'none';
    }
    // Hide category select
    document.getElementById('cs-bulk-export-category-select').style.display = 'none';
    // Populate category dropdown
    var cats = {};
    App.getCSData().forEach(function(d) { cats[d.category] = true; });
    var sel = document.getElementById('cs-bulk-export-category');
    sel.innerHTML = Object.keys(cats).sort().map(function(c) {
      return '<option value="' + App.escapeHtml(c) + '">' + App.escapeHtml(c) + '</option>';
    }).join('');
    document.getElementById('cs-bulk-export-modal').style.display = 'flex';
  }

  function closeBulkExportModal() {
    document.getElementById('cs-bulk-export-modal').style.display = 'none';
  }

  function downloadConceptSetsJson(list, filename) {
    var json = JSON.stringify(list.map(function(cs) {
      var copy = JSON.parse(JSON.stringify(cs));
      var sessionRevs = App.sessionReviews[cs.id] || [];
      if (sessionRevs.length > 0) {
        if (!copy.metadata) copy.metadata = {};
        if (!copy.metadata.reviews) copy.metadata.reviews = [];
        copy.metadata.reviews = copy.metadata.reviews.concat(sessionRevs);
      }
      return copy;
    }), null, 2);
    var blob = new Blob([json], { type: 'application/json' });
    var url = URL.createObjectURL(blob);
    var a = document.createElement('a');
    a.href = url;
    a.download = filename;
    a.click();
    URL.revokeObjectURL(url);
  }

  function executeBulkExport(mode) {
    var list;
    var filename;
    if (mode === 'all') {
      list = App.conceptSets;
      filename = 'concept_sets_all.json';
    } else if (mode === 'selected') {
      list = App.conceptSets.filter(function(cs) { return selectedIds.has(cs.id); });
      filename = 'concept_sets_selected.json';
    } else if (mode === 'category') {
      // Show the category selector instead of downloading
      document.getElementById('cs-bulk-export-category-select').style.display = '';
      return;
    }
    downloadConceptSetsJson(list, filename);
    closeBulkExportModal();
    App.showToast(list.length + ' concept set' + (list.length > 1 ? 's' : '') + ' exported.', 'success');
  }

  function executeBulkExportByCategory() {
    var cat = document.getElementById('cs-bulk-export-category').value;
    var list = App.conceptSets.filter(function(cs) {
      var tr = App.t(cs);
      return (tr.category || '') === cat;
    });
    var safeCat = cat.replace(/[^a-zA-Z0-9_-]/g, '_').toLowerCase();
    downloadConceptSetsJson(list, 'concept_sets_' + safeCat + '.json');
    closeBulkExportModal();
    App.showToast(list.length + ' concept set' + (list.length > 1 ? 's' : '') + ' exported.', 'success');
  }

  // ==================== CREATE CONCEPT SET ====================
  // Category → subcategories map (built per language pair: en+fr)
  var createCatMap = {}; // { category: { en, fr, subcats: [{ en, fr }] } }

  function buildCategoryMap() {
    createCatMap = {};
    App.conceptSets.forEach(function(cs) {
      var tr = cs.metadata && cs.metadata.translations;
      if (!tr || !tr.en) return;
      var catEn = (tr.en.category || '').trim();
      var catFr = (tr.fr && tr.fr.category || '').trim();
      if (!catEn) return;
      if (!createCatMap[catEn]) createCatMap[catEn] = { en: catEn, fr: catFr || catEn, subcats: {} };
      var subcatEn = (tr.en.subcategory || '').trim();
      var subcatFr = (tr.fr && tr.fr.subcategory || '').trim();
      if (subcatEn && !createCatMap[catEn].subcats[subcatEn]) {
        createCatMap[catEn].subcats[subcatEn] = { en: subcatEn, fr: subcatFr || subcatEn };
      }
    });
  }

  function populateCatDropdown() {
    var sel = document.getElementById('cs-create-cat');
    var lang = App.lang || 'en';
    sel.innerHTML = '<option value="">Select a category...</option>';
    Object.keys(createCatMap).sort().forEach(function(key) {
      var cat = createCatMap[key];
      var label = lang === 'fr' ? cat.fr : cat.en;
      var opt = document.createElement('option');
      opt.value = key; // always store en key
      opt.textContent = label;
      sel.appendChild(opt);
    });
  }

  function populateSubcatDropdown() {
    var sel = document.getElementById('cs-create-subcat');
    var lang = App.lang || 'en';
    var catKey = document.getElementById('cs-create-cat').value;
    sel.innerHTML = '<option value="">Select a subcategory...</option>';
    if (!catKey || !createCatMap[catKey]) return;
    var subcats = createCatMap[catKey].subcats;
    Object.keys(subcats).sort().forEach(function(key) {
      var sub = subcats[key];
      var label = lang === 'fr' ? sub.fr : sub.en;
      var opt = document.createElement('option');
      opt.value = key;
      opt.textContent = label;
      sel.appendChild(opt);
    });
  }

  function openCreateModal() {
    // Clear form
    document.getElementById('cs-create-name').value = '';
    document.getElementById('cs-create-desc').value = '';
    document.getElementById('cs-create-cat').value = '';
    document.getElementById('cs-create-subcat').value = '';
    document.getElementById('cs-create-cat-new').style.display = 'none';
    document.getElementById('cs-create-cat-new-input').value = '';
    document.getElementById('cs-create-subcat-new').style.display = 'none';
    document.getElementById('cs-create-subcat-new-input').value = '';

    buildCategoryMap();
    populateCatDropdown();
    populateSubcatDropdown();

    document.getElementById('cs-create-modal').style.display = 'flex';
  }

  function closeCreateModal() {
    document.getElementById('cs-create-modal').style.display = 'none';
  }

  function submitCreateCS() {
    var name = document.getElementById('cs-create-name').value.trim();
    var desc = document.getElementById('cs-create-desc').value.trim();

    // Category: from dropdown or new input
    var catKey = document.getElementById('cs-create-cat').value;
    var catNewInput = document.getElementById('cs-create-cat-new-input').value.trim();
    var catEn, catFr;
    if (catNewInput) {
      catEn = catNewInput;
      catFr = catNewInput;
    } else if (catKey && createCatMap[catKey]) {
      catEn = createCatMap[catKey].en;
      catFr = createCatMap[catKey].fr;
    } else {
      catEn = '';
      catFr = '';
    }

    // Subcategory: from dropdown or new input
    var subcatKey = document.getElementById('cs-create-subcat').value;
    var subcatNewInput = document.getElementById('cs-create-subcat-new-input').value.trim();
    var subcatEn, subcatFr;
    if (subcatNewInput) {
      subcatEn = subcatNewInput;
      subcatFr = subcatNewInput;
    } else if (subcatKey && catKey && createCatMap[catKey] && createCatMap[catKey].subcats[subcatKey]) {
      subcatEn = createCatMap[catKey].subcats[subcatKey].en;
      subcatFr = createCatMap[catKey].subcats[subcatKey].fr;
    } else {
      subcatEn = '';
      subcatFr = '';
    }

    if (!name) { App.showToast('Name is required.', 'error'); return; }
    if (!catEn) { App.showToast('Category is required.', 'error'); return; }

    var profile = App.getUserProfile();
    var authorName = ((profile.firstName || '') + ' ' + (profile.lastName || '')).trim() || 'Anonymous';
    var today = new Date().toISOString().split('T')[0];

    var cs = {
      id: App.nextConceptSetId(),
      name: name,
      description: desc || null,
      version: '1.0.0',
      createdBy: authorName,
      createdDate: today,
      modifiedBy: authorName,
      modifiedDate: today,
      createdByTool: 'INDICATE Data Dictionary (Web)',
      expression: { items: [] },
      tags: [],
      reviewStatus: 'draft',
      metadata: {
        translations: {
          en: { name: name, category: catEn, subcategory: subcatEn },
          fr: { name: name, category: catFr, subcategory: subcatFr }
        },
        createdByDetails: {
          firstName: profile.firstName || '',
          lastName: profile.lastName || '',
          affiliation: profile.affiliation || '',
          profession: profile.profession || '',
          orcid: profile.orcid || ''
        },
        reviews: [],
        versions: [],
        distributionStats: null
      }
    };

    App.addConceptSet(cs);
    closeCreateModal();
    renderAll();
    showCSDetail(cs.id);
    App.showToast('Concept set "' + name + '" created.', 'success');
  }

  // ==================== EVENTS ====================
  function initEvents() {
    // Toolbar: selection mode toggle
    document.getElementById('cs-select-mode-btn').addEventListener('click', toggleSelectionMode);
    document.getElementById('cs-select-all-btn').addEventListener('click', selectAll);
    document.getElementById('cs-unselect-all-btn').addEventListener('click', unselectAll);
    document.getElementById('cs-delete-selected-btn').addEventListener('click', openDeleteConfirm);

    // Toolbar: bulk export
    document.getElementById('cs-export-all-btn').addEventListener('click', openBulkExportModal);
    document.getElementById('cs-bulk-export-close').addEventListener('click', closeBulkExportModal);
    document.getElementById('cs-bulk-export-cancel').addEventListener('click', closeBulkExportModal);
    document.getElementById('cs-bulk-export-modal').addEventListener('click', function(e) {
      if (e.target === this) closeBulkExportModal();
    });
    document.getElementById('cs-bulk-export-modal').querySelector('.modal-body').addEventListener('click', function(e) {
      var opt = e.target.closest('.export-option[data-bulk-export]');
      if (opt) executeBulkExport(opt.dataset.bulkExport);
    });
    document.getElementById('cs-bulk-export-category-go').addEventListener('click', executeBulkExportByCategory);

    // Toolbar: delete confirmation modal
    document.getElementById('cs-delete-confirm-close').addEventListener('click', closeDeleteConfirm);
    document.getElementById('cs-delete-confirm-cancel').addEventListener('click', closeDeleteConfirm);
    document.getElementById('cs-delete-confirm-ok').addEventListener('click', executeDelete);
    document.getElementById('cs-delete-confirm-modal').addEventListener('click', function(e) {
      if (e.target === this) closeDeleteConfirm();
    });

    // CS name fuzzy filter
    document.getElementById('filter-name').addEventListener('input', function(e) {
      csFilterName = e.target.value;
      csPage = 1;
      renderCSTable();
    });

    // CS category filter
    document.getElementById('cs-categories').addEventListener('click', function(e) {
      var badge = e.target.closest('.category-badge');
      if (!badge) return;
      var cat = badge.dataset.category;
      if (csCategories.has(cat)) csCategories.delete(cat); else csCategories.add(cat);
      csPage = 1;
      renderCSCategories();
      populateColumnFilters();
      renderCSTable();
    });

    // CS sort
    document.getElementById('cs-table').querySelector('thead').addEventListener('click', function(e) {
      var th = e.target.closest('th[data-sort]');
      if (!th) return;
      var key = th.dataset.sort;
      if (csSort.key === key) csSort.asc = !csSort.asc;
      else { csSort.key = key; csSort.asc = true; }
      renderCSTable();
    });

    // CS pagination
    document.getElementById('cs-page-buttons').addEventListener('click', function(e) {
      var btn = e.target.closest('button[data-page]');
      if (!btn || btn.disabled) return;
      var p = btn.dataset.page;
      if (p === 'first') csPage = 1;
      else if (p === 'prev') csPage--;
      else if (p === 'next') csPage++;
      else if (p === 'last') csPage = Math.ceil(getFilteredCS().length / csPageSize);
      else csPage = parseInt(p);
      renderCSTable();
    });

    // CS table row click -> detail OR toggle checkbox in selection mode
    document.getElementById('cs-tbody').addEventListener('click', function(e) {
      var tr = e.target.closest('tr[data-id]');
      if (!tr) return;
      var id = parseInt(tr.dataset.id);
      // If clicking a checkbox, toggle selection
      if (e.target.classList.contains('cs-row-checkbox')) {
        toggleRowSelection(id);
        return;
      }
      // In selection mode, clicking the row toggles selection
      if (selectionMode) {
        toggleRowSelection(id);
        return;
      }
      // Normal mode: open detail
      showCSDetail(id);
    });

    // CS back button
    document.getElementById('cs-back').addEventListener('click', hideCSDetail);

    // CS detail tabs
    document.getElementById('cs-detail-tabs').addEventListener('click', function(e) {
      var tab = e.target.closest('.tab-btn-blue');
      if (!tab) return;
      switchCSDetailTab(tab.dataset.tab);
    });

    // Expression/Resolved toggle
    document.getElementById('cs-concept-toggle-bar').addEventListener('click', function(e) {
      var btn = e.target.closest('.toggle-btn');
      if (!btn) return;
      switchConceptMode(btn.dataset.mode);
    });

    // Header-level edit/cancel/save
    document.getElementById('cs-edit-btn').addEventListener('click', enterExprEditMode);
    document.getElementById('cs-edit-cancel-btn').addEventListener('click', cancelExprEdits);
    document.getElementById('cs-edit-save-btn').addEventListener('click', saveExprEdits);

    // Expression edit actions
    document.getElementById('expr-import-btn').addEventListener('click', openImportModal);
    document.getElementById('expr-add-btn').addEventListener('click', openAddModal);
    document.getElementById('expr-select-btn').addEventListener('click', toggleExprSelectMode);
    document.getElementById('expr-delete-sel-btn').addEventListener('click', deleteExprSelected);

    // Expression table: toggle switches, delete icons, row selection
    document.getElementById('expression-tbody').addEventListener('change', function(e) {
      var input = e.target;
      if (!exprEditMode || !exprEditItems) return;
      var idx = parseInt(input.getAttribute('data-idx'));
      var field = input.getAttribute('data-field');
      if (field && !isNaN(idx) && exprEditItems[idx]) {
        exprEditItems[idx][field] = input.checked;
        // Re-render row when exclude changes so toggle colors update
        if (field === 'isExcluded') renderExpressionTable();
      }
    });
    document.getElementById('expression-tbody').addEventListener('click', function(e) {
      // Trash icon
      var trash = e.target.closest('.expr-delete-icon');
      if (trash && exprEditMode) {
        deleteExprRow(parseInt(trash.getAttribute('data-idx')));
        return;
      }
      // Row checkbox in select mode
      if (e.target.classList.contains('expr-row-checkbox')) {
        toggleExprRowSelection(parseInt(e.target.getAttribute('data-idx')));
        return;
      }
      // Row click in select mode
      if (exprSelectMode) {
        var tr = e.target.closest('tr[data-idx]');
        if (tr) toggleExprRowSelection(parseInt(tr.getAttribute('data-idx')));
      }
    });

    // Import modal
    document.getElementById('expr-import-close').addEventListener('click', closeImportModal);
    document.getElementById('expr-import-cancel').addEventListener('click', closeImportModal);
    document.getElementById('expr-import-submit').addEventListener('click', submitImport);
    document.getElementById('expr-import-modal').addEventListener('click', function(e) {
      if (e.target === this) closeImportModal();
    });

    // Add concepts modal
    document.getElementById('expr-add-close').addEventListener('click', closeAddModal);
    document.getElementById('expr-add-search-btn').addEventListener('click', searchAddConcepts);
    document.getElementById('expr-add-search').addEventListener('keydown', function(e) {
      if (e.key === 'Enter') searchAddConcepts();
    });
    document.getElementById('expr-add-select-all').addEventListener('change', toggleAddSelectAll);
    document.getElementById('expr-add-multiple').addEventListener('change', function() {
      addMultiSelect = this.checked;
      // When switching to multi-select, keep existing selection; when switching to single, clear
      if (!addMultiSelect) {
        addConceptSelectedIds.clear();
        addSelectedConcept = null;
        updateAddCount();
        resetAddDetailPanels();
      }
      applyAddMultiSelect();
      renderAddResults();
    });
    document.getElementById('expr-add-results-tbody').addEventListener('click', function(e) {
      // Don't handle checkbox clicks directly — they bubble as row clicks
      if (e.target.classList.contains('add-row-checkbox')) return;
      var tr = e.target.closest('tr[data-cid]');
      if (!tr) return;
      handleAddRowClick(parseInt(tr.getAttribute('data-cid')));
    });
    document.getElementById('expr-add-results-tbody').addEventListener('change', function(e) {
      if (e.target.classList.contains('add-row-checkbox')) {
        toggleAddRow(parseInt(e.target.getAttribute('data-cid')));
      }
    });
    document.getElementById('expr-add-submit').addEventListener('click', submitAddConcepts);

    // Add concepts: pagination
    document.getElementById('expr-add-page-buttons').addEventListener('click', function(e) {
      handlePageClick(e, addConceptFiltered.length, addPageSize,
        function() { return addPage; },
        function(p) { addPage = p; },
        function() { renderAddResults(); },
        'expr-add-results-wrap');
    });

    // Add concepts: filters popup
    document.getElementById('expr-add-filters-btn').addEventListener('click', function(e) {
      e.stopPropagation();
      var popup = document.getElementById('expr-add-filters-popup');
      addFiltersVisible = !addFiltersVisible;
      popup.style.display = addFiltersVisible ? '' : 'none';
    });
    document.getElementById('expr-add-filters-apply').addEventListener('click', function() {
      // Vocab/Domain/Class are already updated live via multi-select onChange
      addFilterStandard = document.getElementById('expr-add-filter-standard').value;
      addFilterValid = document.getElementById('expr-add-filter-valid').checked;
      addFiltersVisible = false;
      document.getElementById('expr-add-filters-popup').style.display = 'none';
      // Re-run query with new filters
      if (document.getElementById('expr-add-search').value.trim()) {
        searchAddConcepts();
      } else {
        loadAddDefaults();
      }
    });
    document.getElementById('expr-add-filters-clear').addEventListener('click', function() {
      addFilterVocab.clear();
      addFilterDomain.clear();
      addFilterClass.clear();
      addFilterStandard = '';
      addFilterValid = false;
      document.getElementById('expr-add-filter-standard').value = '';
      document.getElementById('expr-add-filter-valid').checked = false;
      // Rebuild dropdowns to reflect cleared state
      ['expr-add-filter-vocab', 'expr-add-filter-domain', 'expr-add-filter-class'].forEach(function(id) {
        var container = document.getElementById(id);
        if (container) {
          container.querySelectorAll('.ms-option input[type="checkbox"]').forEach(function(cb) { cb.checked = false; });
        }
      });
      App.updateMsToggleLabel('expr-add-filter-vocab', addFilterVocab);
      App.updateMsToggleLabel('expr-add-filter-domain', addFilterDomain);
      App.updateMsToggleLabel('expr-add-filter-class', addFilterClass);
    });
    // Close filters popup on outside click
    document.getElementById('expr-add-modal').addEventListener('click', function(e) {
      if (addFiltersVisible && !e.target.closest('#expr-add-filters-popup') && !e.target.closest('#expr-add-filters-btn')) {
        addFiltersVisible = false;
        document.getElementById('expr-add-filters-popup').style.display = 'none';
      }
    });

    // Add concepts: column filter inputs (client-side filtering)
    ['expr-add-cf-id','expr-add-cf-name','expr-add-cf-vocab','expr-add-cf-code','expr-add-cf-domain','expr-add-cf-class','expr-add-cf-standard'].forEach(function(id) {
      document.getElementById(id).addEventListener('input', function() {
        applyAddColumnFilters();
      });
    });

    // Add concepts: resize bar drag
    (function() {
      var bar = document.getElementById('expr-add-resize-bar');
      var bottom = document.getElementById('expr-add-bottom');
      var body = document.querySelector('#expr-add-modal .modal-fs-body');
      var startY, startH;
      bar.addEventListener('mousedown', function(e) {
        e.preventDefault();
        startY = e.clientY;
        startH = bottom.offsetHeight;
        bar.classList.add('dragging');
        function onMove(ev) {
          var delta = startY - ev.clientY;
          var newH = Math.max(120, Math.min(startH + delta, body.offsetHeight - 200));
          bottom.style.height = newH + 'px';
        }
        function onUp() {
          bar.classList.remove('dragging');
          document.removeEventListener('mousemove', onMove);
          document.removeEventListener('mouseup', onUp);
        }
        document.addEventListener('mousemove', onMove);
        document.addEventListener('mouseup', onUp);
      });
    })();

    // Resolved concept row click -> concept detail (fresh navigation, reset history)
    document.getElementById('resolved-tbody').addEventListener('click', function(e) {
      var tr = e.target.closest('tr[data-idx]');
      if (!tr || !selectedConceptSet) return;
      var concepts = App.resolvedIndex[selectedConceptSet.id] || [];
      var idx = parseInt(tr.dataset.idx);
      if (concepts[idx]) {
        conceptDetailHistory = [];
        showResolvedConceptDetail(concepts[idx]);
      }
    });

    // Resolved table filters
    ['resolved-filter-domain', 'resolved-filter-class'].forEach(function(id) {
      document.getElementById(id).addEventListener('change', function() { resolvedPage = 1; renderResolvedTable(true); });
    });
    ['resolved-filter-conceptId', 'resolved-filter-name', 'resolved-filter-code'].forEach(function(id) {
      document.getElementById(id).addEventListener('input', function() { resolvedPage = 1; renderResolvedTable(true); });
    });

    // Resolved table pagination
    document.getElementById('resolved-page-buttons').addEventListener('click', function(e) {
      handlePageClick(e, (function() {
        var allC = App.resolvedIndex[selectedConceptSet ? selectedConceptSet.id : 0] || [];
        var filters = getResolvedFilters();
        return filterResolvedConcepts(allC, filters).length;
      })(), resolvedPageSize,
      function() { return resolvedPage; },
      function(p) { resolvedPage = p; },
      function() { renderResolvedTable(true); });
    });

    // Expression table pagination
    document.getElementById('expression-page-buttons').addEventListener('click', function(e) {
      var items = exprEditMode ? (exprEditItems || []) : ((selectedConceptSet && selectedConceptSet.expression && selectedConceptSet.expression.items) || []);
      handlePageClick(e, items.length, expressionPageSize,
      function() { return expressionPage; },
      function(p) { expressionPage = p; },
      function() { renderExpressionTable(); });
    });

    // Column visibility dropdown
    buildColVisDropdown();
    document.getElementById('col-vis-btn').addEventListener('click', function(e) {
      e.stopPropagation();
      var dd = document.getElementById('col-vis-dropdown');
      dd.style.display = dd.style.display === 'none' ? '' : 'none';
    });
    document.getElementById('col-vis-dropdown').addEventListener('change', function(e) {
      var cb = e.target;
      if (cb.dataset.col) {
        getActiveColConfig()[cb.dataset.col].visible = cb.checked;
        applyColumnVisibility();
      }
    });

    // Export modal events (cs-export-modal)
    document.getElementById('cs-export-json').addEventListener('click', openExportModal);
    document.getElementById('cs-export-modal-close').addEventListener('click', closeExportModal);
    document.getElementById('cs-export-cancel').addEventListener('click', closeExportModal);
    document.getElementById('cs-export-back').addEventListener('click', exportStepBack);
    document.getElementById('cs-export-modal').addEventListener('click', function(e) {
      if (e.target === document.getElementById('cs-export-modal')) closeExportModal();
    });
    document.getElementById('export-step-method').addEventListener('click', function(e) {
      var opt = e.target.closest('.export-option[data-method]');
      if (opt) exportStepMethod(opt.dataset.method);
    });
    document.getElementById('export-step-format').addEventListener('click', function(e) {
      var opt = e.target.closest('.export-option[data-format]');
      if (opt) executeExport(opt.dataset.format);
    });

    // Add Review button
    document.getElementById('cs-add-review-btn').addEventListener('click', openReviewModal);

    // Propose on GitHub button
    var proposeBtn = document.getElementById('cs-propose-github');
    if (proposeBtn) proposeBtn.addEventListener('click', proposeOnGitHub);

    // Review modal events
    document.getElementById('review-modal-close').addEventListener('click', closeReviewModal);
    document.getElementById('review-submit').addEventListener('click', submitReview);

    // Create concept set modal events
    document.getElementById('cs-create-btn').addEventListener('click', openCreateModal);
    document.getElementById('cs-create-close').addEventListener('click', closeCreateModal);
    document.getElementById('cs-create-cancel').addEventListener('click', closeCreateModal);
    document.getElementById('cs-create-submit').addEventListener('click', submitCreateCS);
    document.getElementById('cs-create-modal').addEventListener('click', function(e) {
      if (e.target === document.getElementById('cs-create-modal')) closeCreateModal();
    });
    // Category dropdown → filter subcategories
    document.getElementById('cs-create-cat').addEventListener('change', function() {
      document.getElementById('cs-create-subcat').value = '';
      populateSubcatDropdown();
    });
    // "+" buttons for new category / subcategory
    document.getElementById('cs-create-cat-add').addEventListener('click', function() {
      var el = document.getElementById('cs-create-cat-new');
      var visible = el.style.display !== 'none';
      el.style.display = visible ? 'none' : '';
      if (!visible) {
        document.getElementById('cs-create-cat-new-input').focus();
        document.getElementById('cs-create-cat').value = '';
        populateSubcatDropdown();
      } else {
        document.getElementById('cs-create-cat-new-input').value = '';
      }
    });
    document.getElementById('cs-create-subcat-add').addEventListener('click', function() {
      var el = document.getElementById('cs-create-subcat-new');
      var visible = el.style.display !== 'none';
      el.style.display = visible ? 'none' : '';
      if (!visible) {
        document.getElementById('cs-create-subcat-new-input').focus();
        document.getElementById('cs-create-subcat').value = '';
      } else {
        document.getElementById('cs-create-subcat-new-input').value = '';
      }
    });
  }

  // ==================== PAGE MODULE ====================
  function init() {
    if (initialized) return;
    initialized = true;
    initEvents();
    renderAll();
  }

  function show(query) {
    init();
    if (query && query.cs) {
      showCSDetail(parseInt(query.cs));
    }
  }

  function hide() {
    closeExportModal();
    closeReviewModal();
    closeCreateModal();
    closeBulkExportModal();
    closeDeleteConfirm();
    closeImportModal();
    closeAddModal();
  }

  function onLanguageChange() {
    if (!initialized) return;
    csCategories.clear();
    csSubcategories.clear();
    csFilterReviewStatus.clear();
    csFilterName = '';
    document.getElementById('filter-name').value = '';
    csPage = 1;
    renderAll();
    if (selectedConceptSet) showCSDetail(selectedConceptSet.id);
  }

  return {
    show: show,
    hide: hide,
    onLanguageChange: onLanguageChange
  };
})();

// concept-sets.js — Concept Sets page module
var ConceptSetsPage = (function() {
  'use strict';

  var GITHUB_REPO = 'indicate-eu/data-dictionary';

  /** Decode escaped UTF-8 hex bytes (e.g. <e5><bf><83>) to proper characters */
  function decodeEscapedUtf8(str) {
    if (!str || !/&lt;[0-9a-f]{2}&gt;/i.test(str) && !/<[0-9a-f]{2}>/i.test(str)) return str;
    try {
      return str.replace(/(<[0-9a-f]{2}>)+/gi, function (match) {
        var hex = match.replace(/[<>]/g, '');
        var bytes = [];
        for (var i = 0; i < hex.length; i += 2) {
          bytes.push(parseInt(hex.substr(i, 2), 16));
        }
        return new TextDecoder('utf-8').decode(new Uint8Array(bytes));
      });
    } catch (e) { return str; }
  }
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
  var exprSelectedIdxs = new Set();
  var exprImportEditor = null;
  var addConceptResults = [];      // all results from SQL query
  var addConceptFiltered = [];     // after column-filter
  var addConceptSelectedIds = new Set();
  var addMultiSelect = false;
  var addSelectedConcept = null; // currently focused row in single-select mode
  var addFiltersVisible = false;
  var addPage = 1;
  var addPageSize = 10;
  // Pre-query filters (from filters popup) — Sets for multi-select
  var addFilterVocab = new Set();
  var addFilterDomain = new Set();
  var addFilterClass = new Set();
  var addFilterDropdownsBuilt = false;
  var addFilterStandard = new Set(['S']);
  var STANDARD_OPTIONS = ['S', 'C', 'non'];
  function standardLabel(val) {
    return val === 'S' ? App.i18n('Standard')
      : val === 'C' ? App.i18n('Classification')
      : val === 'non' ? App.i18n('Non-standard')
      : val;
  }
  function getStandardLabelMap() {
    return {
      'S': App.i18n('Standard'),
      'C': App.i18n('Classification'),
      'non': App.i18n('Non-standard')
    };
  }
  var addFilterValid = true;
  // Persistent modal state (preserved across open/close)
  var addExclude = false;
  var addDescendants = false;
  var addMapped = false;
  var addSearchText = '';
  var addLimitChecked = true;
  var addColumnFilters = {}; // keyed by element id
  var addActiveTab = 'ohdsi'; // 'ohdsi' or 'custom'
  var CUSTOM_CONCEPT_BASE = 2100000000;
  var ADD_LIMIT_WARN_THRESHOLD = 10000;

  // Comments & Statistics edit state
  var commentsEditMode = false;
  var commentsAceEditor = null;
  var statsEditMode = false;
  var statsAceEditor = null;
  var statsCurrentProfile = null;

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
      // Secondary sort by name when primary values are equal
      if (csSort.key !== 'name') {
        var na = (a.name || '').toLowerCase();
        var nb = (b.name || '').toLowerCase();
        if (na < nb) return -1;
        if (na > nb) return 1;
      }
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
        '<td class="cs-edit-col"><button class="cs-row-edit-btn" data-edit-id="' + d.id + '" title="Edit"><i class="fas fa-pen"></i></button></td>' +
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
    // Exit any active edit mode when switching tabs
    if (isAnyEditMode()) cancelEdits();
    csDetailTab = tabName;
    document.querySelectorAll('#cs-detail-tabs .tab-btn-blue').forEach(function(btn) {
      btn.classList.toggle('active', btn.dataset.tab === tabName);
    });
    ['concepts', 'comments', 'statistics', 'review'].forEach(function(t) {
      var el = document.getElementById('cs-tab-' + t);
      if (el) el.style.display = (t === tabName) ? '' : 'none';
    });
    updateToolbar();
    // Update URL with tab param
    if (selectedConceptSet) {
      var url = '#/concept-sets?id=' + selectedConceptSet.id;
      if (tabName !== 'concepts') url += '&tab=' + tabName;
      history.replaceState(null, '', url);
    }
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
      resetExpressionFilters();
      renderExpressionTable();
    } else {
      resolvedPage = 1;
      renderResolvedTable();
    }
    updateToolbar();
  }

  // ==================== PAGINATION HELPER ====================
  function renderPaginationControls(paginationId, pageInfoId, pageBtnsId, currentPage, totalItems, pageSize) {
    var paginationEl = document.getElementById(paginationId);
    var totalPages = Math.ceil(totalItems / pageSize);
    if (totalPages <= 0) totalPages = 1;
    if (currentPage > totalPages) currentPage = totalPages;
    if (currentPage < 1) currentPage = 1;
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
    var allItems = exprEditMode ? exprEditItems : ((selectedConceptSet.expression && selectedConceptSet.expression.items) || []);
    var table = document.getElementById('expression-table');
    var tbody = document.getElementById('expression-tbody');
    var colSpan = exprEditMode ? 12 : 10;

    // Toggle table classes
    table.classList.toggle('expr-edit-mode', exprEditMode);

    // Populate filter dropdowns
    populateExpressionFilters(allItems);

    // Apply filters — build array of {item, origIdx} to preserve real indices
    var filters = getExpressionFilters();
    var indexed = allItems.map(function(item, idx) { return { item: item, origIdx: idx }; });
    var filtered = indexed.filter(function(entry) {
      var item = entry.item;
      var c = item.concept;
      if (filters.conceptId && String(c.conceptId || '').toLowerCase().indexOf(filters.conceptId) === -1) return false;
      if (filters.vocabulary.size > 0 && !filters.vocabulary.has(c.vocabularyId || '')) return false;
      if (filters.name && !fuzzyMatchBool((c.conceptName || '').toLowerCase(), filters.name)) return false;
      if (filters.code && (c.conceptCode || '').toLowerCase().indexOf(filters.code) === -1) return false;
      if (filters.domain && (c.domainId || '') !== filters.domain) return false;
      if (filters.conceptClass && (c.conceptClassId || '') !== filters.conceptClass) return false;
      if (filters.standard.size > 0 && !filters.standard.has(c.standardConcept || '')) return false;
      if (filters.exclude === 'yes' && !item.isExcluded) return false;
      if (filters.exclude === 'no' && item.isExcluded) return false;
      if (filters.descendants === 'yes' && !item.includeDescendants) return false;
      if (filters.descendants === 'no' && item.includeDescendants) return false;
      if (filters.mapped === 'yes' && !item.includeMapped) return false;
      if (filters.mapped === 'no' && item.includeMapped) return false;
      return true;
    });

    document.getElementById('cs-concept-count').textContent = filtered.length + (filtered.length !== allItems.length ? ' / ' + allItems.length : '');

    if (allItems.length === 0) {
      tbody.innerHTML = '<tr><td colspan="' + colSpan + '" class="empty-state"><p>' + App.i18n('No concepts in this concept set') + '</p></td></tr>';
      renderPaginationControls('expression-pagination', 'expression-page-info', 'expression-page-buttons', 1, 0, expressionPageSize);
      return;
    }
    if (filtered.length === 0) {
      tbody.innerHTML = '<tr><td colspan="' + colSpan + '" class="empty-state"><p>' + App.i18n('No concepts match the current filters.') + '</p></td></tr>';
      renderPaginationControls('expression-pagination', 'expression-page-info', 'expression-page-buttons', 1, 0, expressionPageSize);
      return;
    }

    // Pagination
    var totalPages = Math.ceil(filtered.length / expressionPageSize);
    if (expressionPage > totalPages) expressionPage = Math.max(1, totalPages);
    var start = (expressionPage - 1) * expressionPageSize;
    var pageEntries = filtered.slice(start, start + expressionPageSize);

    tbody.innerHTML = pageEntries.map(function(entry) {
      var i = entry.origIdx; // real index in items array
      var item = entry.item;
      var c = item.concept;
      var isExcl = item.isExcluded;
      var selChecked = exprSelectedIdxs.has(i) ? ' checked' : '';
      var rowClass = exprSelectedIdxs.has(i) ? ' class="expr-selected"' : '';

      var selectCol = '<td class="expr-select-col td-center"><input type="checkbox" class="expr-row-checkbox" data-idx="' + i + '"' + selChecked + '></td>';
      var isCustom = c.conceptId >= CUSTOM_CONCEPT_BASE;
      var editIcon = isCustom ? '<i class="fas fa-pen expr-edit-custom-icon" data-idx="' + i + '" title="' + App.i18n('Edit custom concept') + '"></i> ' : '';
      var actionCol = '<td class="expr-action-col td-center">' + editIcon + '<i class="fas fa-trash expr-delete-icon" data-idx="' + i + '"></i></td>';

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
        '<td>' + App.escapeHtml(String(c.conceptId || '')) + '</td>' +
        '<td>' + App.escapeHtml(c.conceptName) + '</td>' +
        '<td>' + App.escapeHtml(c.conceptCode) + '</td>' +
        '<td>' + App.escapeHtml(c.domainId) + '</td>' +
        '<td>' + App.escapeHtml(c.conceptClassId || '') + '</td>' +
        '<td class="td-center">' + App.standardBadge(c) + '</td>' +
        excludeCell + descCell + mappedCell +
        (exprEditMode ? actionCol : '') +
        '</tr>';
    }).join('');
    applyColumnVisibility();
    renderPaginationControls('expression-pagination', 'expression-page-info', 'expression-page-buttons', expressionPage, filtered.length, expressionPageSize);
  }

  // ==================== EDIT MODE (generalized) ====================
  function isAnyEditMode() {
    return exprEditMode || commentsEditMode || statsEditMode;
  }

  function enterEditMode() {
    if (!selectedConceptSet) return;
    if (csDetailTab === 'concepts') {
      enterExprEditMode();
    } else if (csDetailTab === 'comments') {
      enterCommentsEditMode();
    } else if (csDetailTab === 'statistics') {
      enterStatsEditMode();
    }
  }

  function saveEdits() {
    if (exprEditMode) saveExprEdits();
    else if (commentsEditMode) saveCommentsEdits();
    else if (statsEditMode) saveStatsEdits();
  }

  function cancelEdits() {
    if (exprEditMode) exitExprEditMode();
    else if (commentsEditMode) exitCommentsEditMode();
    else if (statsEditMode) exitStatsEditMode();
  }

  function updateToolbar() {
    var headerEditBtn = document.getElementById('cs-edit-btn');
    var headerExportBtn = document.getElementById('cs-export-json');
    var headerImportBtn = document.getElementById('expr-import-btn');
    var headerCancelBtn = document.getElementById('cs-edit-cancel-btn');
    var headerSaveBtn = document.getElementById('cs-edit-save-btn');
    var editActions = document.getElementById('expr-edit-actions');
    var selCount = document.getElementById('expr-selection-count');

    var editing = isAnyEditMode();
    if (editing) {
      headerEditBtn.style.display = 'none';
      headerExportBtn.style.display = 'none';
      headerImportBtn.style.display = exprEditMode ? '' : 'none';
      headerCancelBtn.style.display = '';
      headerSaveBtn.style.display = '';
      // Expression-specific toolbar
      editActions.style.display = (exprEditMode && csConceptMode === 'expression') ? 'flex' : 'none';
      selCount.textContent = exprSelectedIdxs.size + ' ' + App.i18n('selected');
    } else {
      // Hide Edit button on review tab (has its own "Add Review")
      var showEdit = (csDetailTab !== 'review');
      headerEditBtn.style.display = showEdit ? '' : 'none';
      headerExportBtn.style.display = '';
      headerImportBtn.style.display = 'none';
      headerCancelBtn.style.display = 'none';
      headerSaveBtn.style.display = 'none';
      editActions.style.display = 'none';
    }
  }

  // --- Expression edit ---
  function enterExprEditMode() {
    if (!selectedConceptSet) return;
    exprEditMode = true;
    exprSelectedIdxs.clear();
    var orig = (selectedConceptSet.expression && selectedConceptSet.expression.items) || [];
    exprEditItems = JSON.parse(JSON.stringify(orig));
    if (csConceptMode !== 'expression') {
      switchConceptMode('expression');
    } else {
      renderExpressionTable();
    }
    updateToolbar();
  }

  function exitExprEditMode() {
    exprEditMode = false;
    exprSelectedIdxs.clear();
    exprEditItems = null;
    updateToolbar();
    if (csConceptMode === 'expression') renderExpressionTable();
  }

  function saveExprEdits() {
    if (!selectedConceptSet || !exprEditItems) return;
    if (!selectedConceptSet.expression) selectedConceptSet.expression = {};
    selectedConceptSet.expression.items = exprEditItems;
    selectedConceptSet.modifiedDate = new Date().toISOString().slice(0, 10);
    App.updateConceptSet(selectedConceptSet);
    exitExprEditMode();
    App.showToast(App.i18n('Expression saved'));
  }

  // --- Optimize expression ---

  /**
   * Resolve a concept set expression using DuckDB in-memory tables.
   * Returns a Set of resolved concept IDs.
   * Uses recursive CTEs since concept_ancestor only has level=1 edges.
   */
  function resolveExpressionViaDuckDB(items) {
    if (!items || items.length === 0) return Promise.resolve(new Set());

    var included = items.filter(function(i) { return !i.isExcluded; });
    var excluded = items.filter(function(i) { return i.isExcluded; });

    if (included.length === 0) return Promise.resolve(new Set());

    function getDescendants(conceptIds) {
      if (conceptIds.length === 0) return Promise.resolve([]);
      var idList = conceptIds.join(',');
      var sql =
        'WITH RECURSIVE desc_r AS (' +
          'SELECT descendant_concept_id AS cid FROM concept_ancestor WHERE ancestor_concept_id IN (' + idList + ')' +
          ' UNION ' +
          'SELECT ca.descendant_concept_id FROM concept_ancestor ca JOIN desc_r ON ca.ancestor_concept_id = desc_r.cid' +
        ') SELECT DISTINCT cid FROM desc_r WHERE cid NOT IN (' + idList + ')';
      return VocabDB.query(sql).then(function(rows) {
        return rows.map(function(r) { return Number(r.cid); });
      });
    }

    function getMapped(conceptIds) {
      if (conceptIds.length === 0) return Promise.resolve([]);
      var idList = conceptIds.join(',');
      var sql =
        "SELECT DISTINCT concept_id_2 AS cid FROM concept_relationship " +
        "WHERE concept_id_1 IN (" + idList + ") " +
        "AND relationship_id IN ('Maps to', 'Mapped from')";
      return VocabDB.query(sql).then(function(rows) {
        return rows.map(function(r) { return Number(r.cid); });
      }).catch(function() { return []; }); // table may not exist
    }

    function expandPartition(partItems) {
      var baseIds = partItems.map(function(i) { return i.concept.conceptId; });
      var descSources = partItems.filter(function(i) { return i.includeDescendants; })
        .map(function(i) { return i.concept.conceptId; });
      var mappedSources = partItems.filter(function(i) { return i.includeMapped; })
        .map(function(i) { return i.concept.conceptId; });

      return Promise.all([
        getDescendants(descSources),
        getMapped(mappedSources)
      ]).then(function(results) {
        var all = new Set(baseIds);
        results[0].forEach(function(id) { all.add(id); });
        results[1].forEach(function(id) { all.add(id); });
        return all;
      });
    }

    return expandPartition(included).then(function(includedIds) {
      if (excluded.length === 0) return includedIds;
      return expandPartition(excluded).then(function(excludedIds) {
        excludedIds.forEach(function(id) { includedIds.delete(id); });
        return includedIds;
      });
    });
  }

  /**
   * Optimize the expression by:
   * 1. Top-down: remove items that are already covered by an ancestor with includeDescendants
   * 2. Bottom-up: find parent concepts that can replace groups of siblings
   *    - Only propose if: fewer total items AND resolved set stays identical
   */
  /**
   * Ensure VocabDB is loaded. Attempts init + remount if not ready.
   * Returns a Promise that resolves to true if DB is ready, false otherwise.
   */
  function ensureVocabDB() {
    if (!window.VocabDB) return Promise.resolve(false);
    if (VocabDB.getImportMode()) return Promise.resolve(true);
    return VocabDB.initDuckDB().then(function() {
      return VocabDB.isDatabaseReady();
    }).then(function(ready) {
      if (ready) { return true; }
      return VocabDB.remountFromStoredHandles();
    }).catch(function() { return false; });
  }

  function optimizeExpression() {
    if (!exprEditItems || exprEditItems.length === 0) {
      App.showToast(App.i18n('Nothing to optimize'), 'info');
      return;
    }

    var modal = document.getElementById('expr-optimize-modal');
    var body = document.getElementById('expr-optimize-body');
    var footer = document.getElementById('expr-optimize-footer');
    modal.style.display = 'flex';
    footer.style.display = 'none';
    body.innerHTML = '<div class="loading-inline"><i class="fas fa-spinner fa-spin"></i> ' + App.i18n('Loading vocabulary database...') + '</div>';

    ensureVocabDB().then(function(ready) {
      if (!ready) {
        body.innerHTML = '<div class="empty-state"><p><i class="fas fa-exclamation-triangle" style="color:var(--warning)"></i> Vocabulary database required — import it in <strong>Settings</strong> first.</p></div>';
        footer.style.display = 'none';
        return;
      }
      doOptimizeExpression(modal, body, footer);
    });
  }

  function doOptimizeExpression(modal, body, footer) {
    body.innerHTML = '<div class="loading-inline"><i class="fas fa-spinner fa-spin"></i> Analyzing hierarchy...</div>';

    var items = JSON.parse(JSON.stringify(exprEditItems));

    // Step 1: Resolve current expression to get the reference set
    resolveExpressionViaDuckDB(items).then(function(originalResolved) {
      body.innerHTML = '<div class="loading-inline"><i class="fas fa-spinner fa-spin"></i> Finding optimization opportunities...</div>';

      return runTopDownOptimization(items).then(function(afterTopDown) {
        return runBottomUpOptimization(afterTopDown.items).then(function(afterBottomUp) {
          var optimizedItems = afterBottomUp.items;
          var changes = afterTopDown.changes.concat(afterBottomUp.changes);

          if (changes.length === 0) {
            body.innerHTML = '<div class="empty-state"><p><i class="fas fa-check-circle" style="color:var(--success)"></i> Expression is already optimal — no redundant items found.</p></div>';
            footer.style.display = 'none';
            return;
          }

          // Verify resolved set equality
          return resolveExpressionViaDuckDB(optimizedItems).then(function(newResolved) {
            var identical = originalResolved.size === newResolved.size;
            if (identical) {
              originalResolved.forEach(function(id) {
                if (!newResolved.has(id)) identical = false;
              });
            }

            if (!identical) {
              // Diff info
              var added = [];
              var removed = [];
              newResolved.forEach(function(id) { if (!originalResolved.has(id)) added.push(id); });
              originalResolved.forEach(function(id) { if (!newResolved.has(id)) removed.push(id); });
              console.warn('Optimize: resolved set mismatch', { added: added, removed: removed });

              // Fetch concept names for the diff
              var diffIds = added.concat(removed);
              var diffPromise = diffIds.length > 0
                ? VocabDB.query('SELECT concept_id, concept_name FROM concept WHERE concept_id IN (' + diffIds.join(',') + ')')
                : Promise.resolve([]);

              return diffPromise.then(function(diffRows) {
                var nameMap = {};
                (diffRows || []).forEach(function(r) { nameMap[Number(r.concept_id)] = r.concept_name; });

                var html = '<div style="margin-bottom:12px">' +
                  '<p><i class="fas fa-exclamation-triangle" style="color:var(--warning)"></i> ' +
                  '<strong>Optimization would change the resolved set.</strong> ' +
                  'The in-browser vocabulary may not have complete mapping data. ' +
                  'You can still apply and verify with the full resolver.</p></div>';

                // Show changes table
                html += '<div style="margin-bottom:12px; font-size:13px">' +
                  '<strong>' + changes.length + ' expression change' + (changes.length > 1 ? 's' : '') + '</strong> — ' +
                  'from ' + items.length + ' items to ' + optimizedItems.length + ' items' +
                  '</div>';

                html += '<div style="max-height:200px; overflow:auto; font-size:12px; margin-bottom:12px">';
                html += '<table class="data-table" style="width:100%"><thead><tr>' +
                  '<th>Action</th><th>Concept</th><th>Flags</th></tr></thead><tbody>';
                changes.forEach(function(ch) {
                  var color = ch.action === 'removed' ? 'var(--danger)' : 'var(--success)';
                  var icon = ch.action === 'removed' ? 'fa-minus-circle' : 'fa-plus-circle';
                  var flags = [];
                  if (ch.isExcluded) flags.push('Excluded');
                  if (ch.includeDescendants) flags.push('Desc');
                  if (ch.includeMapped) flags.push('Mapped');
                  html += '<tr><td><i class="fas ' + icon + '" style="color:' + color + '"></i> ' + ch.action + '</td>' +
                    '<td>' + App.escapeHtml(ch.name) + ' <span style="color:var(--text-muted)">#' + ch.id + '</span></td>' +
                    '<td>' + flags.join(', ') + '</td></tr>';
                });
                html += '</tbody></table></div>';

                // Show resolved set diff
                if (removed.length > 0) {
                  html += '<div style="font-size:12px; margin-bottom:8px; color:var(--danger)"><strong>Resolved concepts lost (' + removed.length + '):</strong></div>';
                  html += '<div style="max-height:100px; overflow:auto; font-size:11px; margin-bottom:8px">';
                  removed.forEach(function(id) {
                    html += '<div style="color:var(--danger)"><i class="fas fa-minus-circle"></i> ' + App.escapeHtml(nameMap[id] || '') + ' <span style="color:var(--text-muted)">#' + id + '</span></div>';
                  });
                  html += '</div>';
                }
                if (added.length > 0) {
                  html += '<div style="font-size:12px; margin-bottom:8px; color:var(--success)"><strong>Resolved concepts gained (' + added.length + '):</strong></div>';
                  html += '<div style="max-height:100px; overflow:auto; font-size:11px; margin-bottom:8px">';
                  added.forEach(function(id) {
                    html += '<div style="color:var(--success)"><i class="fas fa-plus-circle"></i> ' + App.escapeHtml(nameMap[id] || '') + ' <span style="color:var(--text-muted)">#' + id + '</span></div>';
                  });
                  html += '</div>';
                }

                body.innerHTML = html;
                footer.style.display = '';
                modal._optimizedItems = optimizedItems;
              });
            }

            // Show changes
            var html = '<div style="margin-bottom:12px; font-size:13px">' +
              '<strong>' + changes.length + ' change' + (changes.length > 1 ? 's' : '') + '</strong> — ' +
              'from ' + items.length + ' items to ' + optimizedItems.length + ' items ' +
              '(resolved set: ' + originalResolved.size + ' concepts, unchanged)' +
              '</div>';

            html += '<div style="max-height:350px; overflow:auto; font-size:12px">';
            html += '<table class="data-table" style="width:100%"><thead><tr>' +
              '<th>Action</th><th>Concept</th><th>Flags</th></tr></thead><tbody>';
            changes.forEach(function(ch) {
              var color = ch.action === 'removed' ? 'var(--danger)' : 'var(--success)';
              var icon = ch.action === 'removed' ? 'fa-minus-circle' : 'fa-plus-circle';
              var flags = [];
              if (ch.isExcluded) flags.push('Excluded');
              if (ch.includeDescendants) flags.push('Desc');
              if (ch.includeMapped) flags.push('Mapped');
              html += '<tr><td><i class="fas ' + icon + '" style="color:' + color + '"></i> ' + ch.action + '</td>' +
                '<td>' + App.escapeHtml(ch.name) + ' <span style="color:var(--text-muted)">#' + ch.id + '</span></td>' +
                '<td>' + flags.join(', ') + '</td></tr>';
            });
            html += '</tbody></table></div>';

            body.innerHTML = html;
            footer.style.display = '';

            // Store optimized items for apply
            modal._optimizedItems = optimizedItems;
          });
        });
      });
    }).catch(function(err) {
      body.innerHTML = '<div class="empty-state"><p><i class="fas fa-times-circle" style="color:var(--danger)"></i> Error: ' + App.escapeHtml(err.message) + '</p></div>';
      footer.style.display = 'none';
    });
  }

  /**
   * Top-down: Remove expression items that are descendants of another item with includeDescendants.
   * Only within same partition (included or excluded).
   */
  function runTopDownOptimization(items) {
    var included = [];
    var excluded = [];
    items.forEach(function(item, idx) {
      var entry = { item: item, idx: idx, id: item.concept.conceptId };
      if (item.isExcluded) excluded.push(entry);
      else included.push(entry);
    });

    function findRedundant(partition) {
      var withDesc = partition.filter(function(e) { return e.item.includeDescendants; });
      if (withDesc.length === 0) return Promise.resolve([]);

      // For each item with includeDescendants, check if other items in the partition are its descendants
      var parentIds = withDesc.map(function(e) { return e.id; });
      var allIds = partition.map(function(e) { return e.id; });

      var sql =
        'WITH RECURSIVE desc_r AS (' +
          'SELECT ancestor_concept_id AS parent, descendant_concept_id AS cid FROM concept_ancestor WHERE ancestor_concept_id IN (' + parentIds.join(',') + ')' +
          ' UNION ALL ' +
          'SELECT desc_r.parent, ca.descendant_concept_id FROM concept_ancestor ca JOIN desc_r ON ca.ancestor_concept_id = desc_r.cid' +
        ') SELECT DISTINCT parent, cid FROM desc_r WHERE cid IN (' + allIds.join(',') + ') AND cid != parent';

      return VocabDB.query(sql).then(function(rows) {
        var redundantIds = new Set();
        rows.forEach(function(r) {
          var parentId = Number(r.parent);
          var childId = Number(r.cid);
          // Only redundant if the child also has same or weaker flags
          var parentEntry = partition.find(function(e) { return e.id === parentId; });
          var childEntry = partition.find(function(e) { return e.id === childId; });
          if (parentEntry && childEntry && parentEntry.id !== childEntry.id) {
            // Child is covered by parent's includeDescendants — redundant if child doesn't add broader scope
            if (!childEntry.item.includeMapped || parentEntry.item.includeMapped) {
              redundantIds.add(childId);
            }
          }
        });
        return redundantIds;
      });
    }

    return Promise.all([findRedundant(included), findRedundant(excluded)]).then(function(results) {
      var allRedundant = new Set();
      results[0].forEach(function(id) { allRedundant.add(id); });
      results[1].forEach(function(id) { allRedundant.add(id); });

      if (allRedundant.size === 0) return { items: items, changes: [] };

      var changes = [];
      var kept = items.filter(function(item) {
        if (allRedundant.has(item.concept.conceptId)) {
          changes.push({
            action: 'removed',
            name: item.concept.conceptName,
            id: item.concept.conceptId,
            isExcluded: item.isExcluded,
            includeDescendants: item.includeDescendants,
            includeMapped: item.includeMapped
          });
          return false;
        }
        return true;
      });

      return { items: kept, changes: changes };
    });
  }

  /**
   * Bottom-up: Find parent concepts that can replace groups of included items.
   * For each candidate parent:
   * - Get all its descendants
   * - Check how many current included items it covers
   * - Check what new unwanted descendants it would bring in
   * - If (parent + excludes) has fewer items than current: propose it
   */
  function runBottomUpOptimization(items) {
    var included = items.filter(function(i) { return !i.isExcluded; });
    var excluded = items.filter(function(i) { return i.isExcluded; });

    if (included.length < 2) return Promise.resolve({ items: items, changes: [] });

    // Find direct parents of all included concept IDs
    var includedIds = included.map(function(i) { return i.concept.conceptId; });

    // Find ancestor concepts (any level) that cover 2+ included items
    // Uses recursive CTE since concept_ancestor only has level=1 edges
    var sql =
      'WITH RECURSIVE anc AS (' +
        'SELECT ancestor_concept_id AS aid, descendant_concept_id AS did, 1 AS depth ' +
        'FROM concept_ancestor WHERE descendant_concept_id IN (' + includedIds.join(',') + ')' +
        ' UNION ALL ' +
        'SELECT ca.ancestor_concept_id, anc.did, anc.depth + 1 ' +
        'FROM concept_ancestor ca JOIN anc ON ca.descendant_concept_id = anc.aid ' +
        'WHERE anc.depth < 5' +
      ') ' +
      'SELECT anc.aid AS parent_id, ' +
      'c.concept_name AS parent_name, c.vocabulary_id, c.domain_id, c.concept_class_id, c.concept_code, c.standard_concept, ' +
      'COUNT(DISTINCT anc.did) AS children_in_set, MIN(anc.depth) AS min_depth ' +
      'FROM anc ' +
      'JOIN concept c ON anc.aid = c.concept_id ' +
      'WHERE anc.aid NOT IN (' + includedIds.join(',') + ') ' +
      'AND (c.invalid_reason IS NULL OR c.invalid_reason = \'\') ' +
      'GROUP BY anc.aid, c.concept_name, c.vocabulary_id, c.domain_id, c.concept_class_id, c.concept_code, c.standard_concept ' +
      'HAVING COUNT(DISTINCT anc.did) >= 2 ' +
      'ORDER BY COUNT(DISTINCT anc.did) DESC, MIN(anc.depth) ASC ' +
      'LIMIT 30';

    return VocabDB.query(sql).then(function(parents) {
      if (!parents || parents.length === 0) return { items: items, changes: [] };

      // Evaluate each candidate parent — find the best one (highest netGain)
      var chain = Promise.resolve(null);
      var bestProposal = null;

      parents.forEach(function(p) {
        chain = chain.then(function() {
          return evaluateParentCandidate(p, included, excluded);
        }).then(function(proposal) {
          if (proposal && (!bestProposal || proposal.netGain > bestProposal.netGain)) {
            bestProposal = proposal;
          }
        });
      });

      return chain.then(function() {
        if (!bestProposal) return { items: items, changes: [] };
        return bestProposal;
      });
    }).catch(function() {
      return { items: items, changes: [] };
    });
  }

  /**
   * Evaluate a candidate parent for bottom-up optimization.
   * Returns { items, changes, netGain } or null.
   */
  function evaluateParentCandidate(parent, included, excluded) {
    var parentId = Number(parent.parent_id);

    // Get ALL descendants of this parent via recursive CTE
    var descSql =
      'WITH RECURSIVE desc_r AS (' +
        'SELECT descendant_concept_id AS cid FROM concept_ancestor WHERE ancestor_concept_id = ' + parentId +
        ' UNION ALL ' +
        'SELECT ca.descendant_concept_id FROM concept_ancestor ca JOIN desc_r ON ca.ancestor_concept_id = desc_r.cid' +
      ') SELECT DISTINCT cid FROM desc_r';

    return VocabDB.query(descSql).then(function(descRows) {
      var allDescendants = new Set(descRows.map(function(r) { return Number(r.cid); }));

      // Which included items are covered by this parent?
      var coveredIncluded = included.filter(function(i) {
        return allDescendants.has(i.concept.conceptId);
      });

      if (coveredIncluded.length < 2) return null;

      // Which excluded items are already descendants of this parent?
      var coveredExcluded = excluded.filter(function(i) {
        return allDescendants.has(i.concept.conceptId);
      });

      // Items NOT covered by this parent (keep as-is)
      var uncoveredIncluded = included.filter(function(i) {
        return !allDescendants.has(i.concept.conceptId);
      });
      var uncoveredExcluded = excluded.filter(function(i) {
        return !allDescendants.has(i.concept.conceptId);
      });

      // With parent + includeDescendants, the parent brings in all its descendants.
      // We need to resolve what the covered items currently resolve to,
      // and check which descendants of the parent are NOT in that resolved set.
      // Those need to be explicitly excluded.

      // Resolve covered items only
      var coveredItems = coveredIncluded.map(function(i) { return i; })
        .concat(coveredExcluded.map(function(i) { return i; }));

      return resolveExpressionViaDuckDB(coveredItems).then(function(coveredResolved) {
        // What would the parent with includeDescendants resolve to?
        // Parent + desc = parentId + all descendants
        var parentResolvedIds = new Set([parentId]);
        allDescendants.forEach(function(id) { parentResolvedIds.add(id); });

        // What needs to be excluded from the parent's tree?
        var needExclude = [];
        parentResolvedIds.forEach(function(id) {
          if (!coveredResolved.has(id)) needExclude.push(id);
        });

        // Net gain: replaced coveredIncluded.length items + coveredExcluded.length items
        // with 1 parent + needExclude.length new excludes
        // (uncoveredExcluded items that were already there stay)
        var oldCount = coveredIncluded.length + coveredExcluded.length;
        var newCount = 1 + needExclude.length;
        var netGain = oldCount - newCount;

        if (netGain < 1) return null; // Not worth it

        // Build new items list
        // Fetch concept details for excluded concepts
        if (needExclude.length === 0) {
          return buildProposal(parent, coveredIncluded, coveredExcluded, uncoveredIncluded, uncoveredExcluded, [], netGain);
        }

        var excludeSql =
          'SELECT concept_id, concept_name, vocabulary_id, domain_id, concept_class_id, concept_code, standard_concept ' +
          'FROM concept WHERE concept_id IN (' + needExclude.join(',') + ')';

        return VocabDB.query(excludeSql).then(function(excludeConcepts) {
          return buildProposal(parent, coveredIncluded, coveredExcluded, uncoveredIncluded, uncoveredExcluded, excludeConcepts, netGain);
        });
      });
    });
  }

  function buildProposal(parent, coveredIncluded, coveredExcluded, uncoveredIncluded, uncoveredExcluded, newExcludes, netGain) {
    var changes = [];

    // Record removals
    coveredIncluded.forEach(function(item) {
      changes.push({
        action: 'removed', name: item.concept.conceptName, id: item.concept.conceptId,
        isExcluded: false, includeDescendants: item.includeDescendants, includeMapped: item.includeMapped
      });
    });
    coveredExcluded.forEach(function(item) {
      changes.push({
        action: 'removed', name: item.concept.conceptName, id: item.concept.conceptId,
        isExcluded: true, includeDescendants: item.includeDescendants, includeMapped: item.includeMapped
      });
    });

    // Add parent
    var parentItem = {
      concept: {
        conceptId: Number(parent.parent_id),
        conceptName: parent.parent_name,
        domainId: parent.domain_id || '',
        vocabularyId: parent.vocabulary_id || '',
        conceptClassId: parent.concept_class_id || '',
        standardConcept: parent.standard_concept || '',
        standardConceptCaption: parent.standard_concept === 'S' ? 'Standard' : (parent.standard_concept === 'C' ? 'Classification' : 'Non-Standard'),
        conceptCode: parent.concept_code || '',
        invalidReason: null,
        invalidReasonCaption: 'Valid'
      },
      isExcluded: false,
      includeDescendants: true,
      includeMapped: false
    };
    changes.push({
      action: 'added', name: parent.parent_name, id: Number(parent.parent_id),
      isExcluded: false, includeDescendants: true, includeMapped: false
    });

    // New exclusions
    var newExcludeItems = newExcludes.map(function(c) {
      changes.push({
        action: 'added', name: c.concept_name, id: Number(c.concept_id),
        isExcluded: true, includeDescendants: false, includeMapped: false
      });
      return {
        concept: {
          conceptId: Number(c.concept_id),
          conceptName: c.concept_name,
          domainId: c.domain_id || '',
          vocabularyId: c.vocabulary_id || '',
          conceptClassId: c.concept_class_id || '',
          standardConcept: c.standard_concept || '',
          standardConceptCaption: c.standard_concept === 'S' ? 'Standard' : (c.standard_concept === 'C' ? 'Classification' : 'Non-Standard'),
          conceptCode: c.concept_code || '',
          invalidReason: null,
          invalidReasonCaption: 'Valid'
        },
        isExcluded: true,
        includeDescendants: false,
        includeMapped: false
      };
    });

    // Build final items: uncovered items + parent + new excludes
    var newItems = uncoveredIncluded.concat(uncoveredExcluded).concat([parentItem]).concat(newExcludeItems);

    return { items: newItems, changes: changes, netGain: netGain };
  }

  // --- Comments edit ---
  var commentsSplitInitialized = false;
  var commentsSyncingScroll = false;

  function initCommentsSplitHandle() {
    if (commentsSplitInitialized) return;
    commentsSplitInitialized = true;
    var handle = document.getElementById('cs-comments-split-handle');
    var container = document.getElementById('cs-comments-split-container');
    var leftCol = document.getElementById('cs-comments-left-col');
    var rightCol = document.getElementById('cs-comments-right-col');

    handle.addEventListener('mousedown', function(e) {
      e.preventDefault();
      handle.classList.add('dragging');
      var startX = e.clientX;
      var containerRect = container.getBoundingClientRect();
      var startLeftW = leftCol.getBoundingClientRect().width;
      var handleW = handle.getBoundingClientRect().width;
      var totalW = containerRect.width - handleW;

      function onMove(ev) {
        var dx = ev.clientX - startX;
        var newLeftW = Math.max(80, Math.min(totalW - 80, startLeftW + dx));
        var leftPct = (newLeftW / totalW) * 100;
        leftCol.style.flex = 'none';
        leftCol.style.width = leftPct + '%';
        rightCol.style.flex = 'none';
        rightCol.style.width = (100 - leftPct) + '%';
        if (commentsAceEditor) commentsAceEditor.resize();
      }
      function onUp() {
        handle.classList.remove('dragging');
        document.removeEventListener('mousemove', onMove);
        document.removeEventListener('mouseup', onUp);
      }
      document.addEventListener('mousemove', onMove);
      document.addEventListener('mouseup', onUp);
    });
  }

  function initCommentsSyncScroll() {
    var preview = document.getElementById('cs-comments-preview');
    // Ace editor scroll -> preview scroll
    if (commentsAceEditor) {
      commentsAceEditor.session.on('changeScrollTop', function(scrollTop) {
        if (commentsSyncingScroll) return;
        commentsSyncingScroll = true;
        var maxScroll = commentsAceEditor.renderer.layerConfig.maxHeight - commentsAceEditor.renderer.$size.scrollerHeight;
        var pct = maxScroll > 0 ? scrollTop / maxScroll : 0;
        var previewMax = preview.scrollHeight - preview.clientHeight;
        preview.scrollTop = pct * previewMax;
        commentsSyncingScroll = false;
      });
    }
    // Preview scroll -> ace editor scroll
    preview.addEventListener('scroll', function() {
      if (commentsSyncingScroll || !commentsAceEditor) return;
      commentsSyncingScroll = true;
      var previewMax = preview.scrollHeight - preview.clientHeight;
      var pct = previewMax > 0 ? preview.scrollTop / previewMax : 0;
      var maxScroll = commentsAceEditor.renderer.layerConfig.maxHeight - commentsAceEditor.renderer.$size.scrollerHeight;
      commentsAceEditor.session.setScrollTop(pct * maxScroll);
      commentsSyncingScroll = false;
    });
  }

  function initCommentsAceEditor() {
    if (commentsAceEditor) return;
    commentsAceEditor = ace.edit('cs-comments-ace-editor');
    commentsAceEditor.setTheme('ace/theme/chrome');
    commentsAceEditor.session.setMode('ace/mode/markdown');
    commentsAceEditor.setFontSize(12);
    commentsAceEditor.setShowPrintMargin(false);
    commentsAceEditor.session.setUseWrapMode(true);
    commentsAceEditor.session.on('change', function() {
      var md = commentsAceEditor.getValue();
      var preview = document.getElementById('cs-comments-preview');
      if (!md.trim()) {
        preview.innerHTML = '<div class="markdown-preview-placeholder">Preview will appear here...</div>';
      } else {
        preview.innerHTML = App.renderMarkdown(md);
      }
    });
    // CMD/CTRL+S to save
    commentsAceEditor.commands.addCommand({
      name: 'saveComments',
      bindKey: { win: 'Ctrl-S', mac: 'Cmd-S' },
      exec: function() { saveCommentsEdits(); }
    });
    initCommentsSplitHandle();
    initCommentsSyncScroll();
  }

  function enterCommentsEditMode() {
    if (!selectedConceptSet) return;
    commentsEditMode = true;
    initCommentsAceEditor();
    var tr = App.t(selectedConceptSet);
    // Load longDescription into editor; fall back to description if no longDescription
    var content = (tr && tr.longDescription) || selectedConceptSet.description || '';
    commentsAceEditor.setValue(content, -1);
    document.getElementById('cs-comments-view').style.display = 'none';
    document.getElementById('cs-comments-edit').style.display = '';
    commentsAceEditor.resize();
    updateToolbar();
  }

  function exitCommentsEditMode() {
    commentsEditMode = false;
    document.getElementById('cs-comments-edit').style.display = 'none';
    document.getElementById('cs-comments-view').style.display = '';
    renderCommentsTab(selectedConceptSet);
    updateToolbar();
  }

  function saveCommentsEdits() {
    if (!selectedConceptSet) return;
    var newContent = commentsAceEditor.getValue().trim();
    // Save as longDescription in translations for current language
    if (!selectedConceptSet.metadata) selectedConceptSet.metadata = {};
    if (!selectedConceptSet.metadata.translations) selectedConceptSet.metadata.translations = {};
    var lang = App.lang || 'en';
    if (!selectedConceptSet.metadata.translations[lang]) selectedConceptSet.metadata.translations[lang] = {};
    selectedConceptSet.metadata.translations[lang].longDescription = newContent || '';
    selectedConceptSet.modifiedDate = new Date().toISOString().slice(0, 10);
    App.updateConceptSet(selectedConceptSet);
    exitCommentsEditMode();
    App.showToast(App.i18n('Comments saved'));
  }

  // --- Statistics edit ---
  var defaultStatsTemplate = {
    profiles: [{
      name_en: 'All patients', name_fr: 'Tous les patients',
      description_en: 'Default profile for all patients',
      description_fr: 'Profil par défaut pour tous les patients',
      data_types: [],
      numeric_data: { min: null, max: null, mean: null, median: null, sd: null, cv: null, p5: null, p25: null, p75: null, p95: null },
      histogram: [],
      categorical_data: [],
      measurement_frequency: { typical_interval: null }
    }],
    default_profile_en: 'All patients',
    default_profile_fr: 'Tous les patients'
  };

  function initStatsAceEditor() {
    if (statsAceEditor) return;
    statsAceEditor = ace.edit('cs-stats-ace-editor');
    statsAceEditor.setTheme('ace/theme/chrome');
    statsAceEditor.session.setMode('ace/mode/json');
    statsAceEditor.setFontSize(12);
    statsAceEditor.setShowPrintMargin(false);
    statsAceEditor.session.setTabSize(2);
    statsAceEditor.setOption('showLineNumbers', true);
    statsAceEditor.setOption('highlightActiveLine', true);
  }

  function enterStatsEditMode() {
    if (!selectedConceptSet) return;
    statsEditMode = true;
    initStatsAceEditor();
    var stats = (selectedConceptSet.metadata && selectedConceptSet.metadata.distributionStats) || null;
    var json = (stats && Object.keys(stats).length > 0) ? JSON.stringify(stats, null, 2) : JSON.stringify(defaultStatsTemplate, null, 2);
    statsAceEditor.setValue(json, -1);
    document.getElementById('cs-statistics-view').style.display = 'none';
    document.getElementById('cs-statistics-edit').style.display = '';
    statsAceEditor.resize();
    updateToolbar();
  }

  function exitStatsEditMode() {
    statsEditMode = false;
    document.getElementById('cs-statistics-edit').style.display = 'none';
    document.getElementById('cs-statistics-view').style.display = '';
    renderStatisticsTab(selectedConceptSet);
    updateToolbar();
  }

  function saveStatsEdits() {
    if (!selectedConceptSet) return;
    var jsonStr = statsAceEditor.getValue().trim();
    var parsed;
    try {
      parsed = jsonStr ? JSON.parse(jsonStr) : null;
    } catch (e) {
      App.showToast(App.i18n('Invalid JSON: ') + e.message, 'error');
      return;
    }
    if (!selectedConceptSet.metadata) selectedConceptSet.metadata = {};
    selectedConceptSet.metadata.distributionStats = parsed;
    selectedConceptSet.modifiedDate = new Date().toISOString().slice(0, 10);
    App.updateConceptSet(selectedConceptSet);
    exitStatsEditMode();
    App.showToast(App.i18n('Statistics saved'));
  }

  function resetStatsToTemplate() {
    if (!statsAceEditor) return;
    statsAceEditor.setValue(JSON.stringify(defaultStatsTemplate, null, 2), -1);
  }

  // --- Expression toolbar helpers ---
  function exprSelectAll() {
    if (!exprEditItems) return;
    for (var i = 0; i < exprEditItems.length; i++) exprSelectedIdxs.add(i);
    updateToolbar();
    renderExpressionTable();
  }

  function exprUnselectAll() {
    exprSelectedIdxs.clear();
    updateToolbar();
    renderExpressionTable();
  }

  function toggleExprRowSelection(idx) {
    if (exprSelectedIdxs.has(idx)) exprSelectedIdxs.delete(idx);
    else exprSelectedIdxs.add(idx);
    updateToolbar();
    var tr = document.querySelector('#expression-tbody tr[data-idx="' + idx + '"]');
    if (tr) {
      tr.classList.toggle('expr-selected', exprSelectedIdxs.has(idx));
      var cb = tr.querySelector('.expr-row-checkbox');
      if (cb) cb.checked = exprSelectedIdxs.has(idx);
    }
  }

  function deleteExprSelected() {
    if (exprSelectedIdxs.size === 0) return;
    var sorted = Array.from(exprSelectedIdxs).sort(function(a, b) { return b - a; });
    sorted.forEach(function(idx) { exprEditItems.splice(idx, 1); });
    exprSelectedIdxs.clear();
    updateToolbar();
    renderExpressionTable();
  }

  function deleteExprRow(idx) {
    exprEditItems.splice(idx, 1);
    exprSelectedIdxs.clear();
    updateToolbar();
    renderExpressionTable();
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
      errEl.textContent = App.i18n('Please paste JSON content.');
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
      errEl.textContent = App.i18n('JSON must contain a non-empty "items" array.');
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
    var msg = added + App.i18n(added !== 1 ? ' concepts' : ' concept') + App.i18n(' imported');
    if (skipped > 0) msg += ', ' + skipped + App.i18n(' skipped (duplicate or invalid)');
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

  function updateExcludeModeClass() {
    var row = document.getElementById('expr-add-toggles-row');
    var excl = document.getElementById('expr-add-exclude');
    if (!row || !excl) return;
    row.classList.toggle('exclude-mode', excl.checked);
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
    updateExcludeModeClass();
    document.getElementById('expr-add-limit').checked = addLimitChecked;
    // Restore column filters
    ['expr-add-cf-id','expr-add-cf-name','expr-add-cf-vocab','expr-add-cf-code','expr-add-cf-domain','expr-add-cf-class','expr-add-cf-standard'].forEach(function(id) {
      var el = document.getElementById(id);
      if (el) el.value = addColumnFilters[id] || '';
    });
    // Sync filter popup inputs with state (standard is now a multi-select, rebuilt by buildAddFilterDropdowns)
    document.getElementById('expr-add-filter-valid').checked = addFilterValid;
    updateAddCount();
    resetAddDetailPanels();
    applyAddMultiSelect();

    function showReady() {
      noDb.style.display = 'none';
      resultsWrap.style.display = '';
      bottom.style.display = '';
      // Only show OHDSI footer/search if on the OHDSI tab
      footer.style.display = addActiveTab === 'ohdsi' ? '' : 'none';
      searchRow.style.display = addActiveTab === 'ohdsi' ? '' : 'none';
      buildAddFilterDropdowns().then(function() {
        renderAddActiveFilters();
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
              'Load OHDSI vocabularies in <a href="#/settings" style="color:var(--primary); font-weight:600">Dictionary Settings</a> to search concepts.';
            showNoDb();
          }
        }).catch(function() {
          noDb.innerHTML = '<i class="fas fa-info-circle" style="color:var(--primary); margin-right:6px"></i>' +
            'Load OHDSI vocabularies in <a href="#/settings" style="color:var(--primary); font-weight:600">Dictionary Settings</a> to search concepts.';
          showNoDb();
        });
      });
    }
    // Reset to OHDSI tab
    switchAddTab('ohdsi');
    modal.classList.add('visible');
  }

  function closeAddModal() {
    saveAddModalState();
    document.getElementById('expr-add-modal').classList.remove('visible');
  }

  function resetAddDetailPanels() {
    var detailEl = document.getElementById('expr-add-detail-body');
    if (detailEl) detailEl.innerHTML = '<div class="empty-state"><p>Select a concept to view details</p></div>';
    var hierEl = document.getElementById('expr-add-hierarchy-body');
    if (hierEl) hierEl.innerHTML = '<div class="empty-state"><p>Select a concept to view hierarchy</p></div>';
    if (addModalHierarchyNetwork) { addModalHierarchyNetwork.destroy(); addModalHierarchyNetwork = null; }
    addModalHierarchyWrapper = null;
    addModalHierarchyHistory = [];
    addModalHierarchyFullscreen = false;
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

      App.buildMultiSelectDropdown('expr-add-filter-vocab', vocabs, addFilterVocab, renderAddActiveFilters);
      App.buildMultiSelectDropdown('expr-add-filter-domain', domains, addFilterDomain, renderAddActiveFilters);
      App.buildMultiSelectDropdown('expr-add-filter-class', classes, addFilterClass, renderAddActiveFilters);
      App.buildMultiSelectDropdown('expr-add-filter-standard', STANDARD_OPTIONS, addFilterStandard, renderAddActiveFilters, getStandardLabelMap());
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
    // Standard is now a multi-select Set. An empty Set means "no filter" (all).
    // Any combination of 'S', 'C', 'non' ORs the matching conditions.
    if (addFilterStandard.size > 0 && addFilterStandard.size < STANDARD_OPTIONS.length) {
      var stdConds = [];
      if (addFilterStandard.has('S')) stdConds.push('standard_concept = \'S\'');
      if (addFilterStandard.has('C')) stdConds.push('standard_concept = \'C\'');
      if (addFilterStandard.has('non')) stdConds.push('(standard_concept IS NULL OR standard_concept NOT IN (\'S\',\'C\'))');
      parts.push('(' + stdConds.join(' OR ') + ')');
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

    var esc = q.replace(/'/g, "''");
    var qLower = esc.toLowerCase();
    var isNumeric = /^\d+$/.test(q);
    var words = esc.split(/\s+/).filter(function(w) { return w.length > 0; });

    // Fast path: if the query is purely numeric, try an exact concept_id match first.
    // If it hits, return that single row immediately — no broader text search needed.
    if (isNumeric) {
      VocabDB.query(
        'SELECT concept_id, concept_name, vocabulary_id, domain_id, concept_class_id, concept_code, standard_concept, invalid_reason ' +
        'FROM concept WHERE concept_id = ' + q + ' LIMIT 1'
      ).then(function(rows) {
        if (rows && rows.length > 0) {
          addConceptResults = rows;
          applyAddColumnFilters();
        } else {
          runFullAddSearch();
        }
      }).catch(function() {
        runFullAddSearch();
      });
      return;
    }
    runFullAddSearch();

    function runFullAddSearch() {

    // Fuzzy threshold: jaro_winkler_similarity returns 0..1, 1 = identical.
    // 0.88 catches single-character typos on short-to-medium strings while
    // keeping the result set manageable.
    var FUZZY_THRESHOLD = 0.88;

    // WHERE conditions: exact ID, substring on code, substring on name (all words),
    // plus fuzzy similarity on full name. OR-joined so fuzzy broadens the set.
    var searchConds = [];
    if (isNumeric) searchConds.push('concept_id = ' + q);
    searchConds.push('concept_code ILIKE \'%' + esc + '%\'');
    if (words.length > 1) {
      var nameConds = words.map(function(w) { return 'concept_name ILIKE \'%' + w + '%\''; });
      searchConds.push('(' + nameConds.join(' AND ') + ')');
    } else {
      searchConds.push('concept_name ILIKE \'%' + esc + '%\'');
    }
    searchConds.push('jaro_winkler_similarity(LOWER(concept_name), \'' + qLower + '\') >= ' + FUZZY_THRESHOLD);

    var whereParts = ['(' + searchConds.join(' OR ') + ')'];
    whereParts = whereParts.concat(buildAddFilterWhere());

    var useLimit = document.getElementById('expr-add-limit').checked;
    var limitClause = useLimit ? ' LIMIT 10000' : '';

    // Ranking:
    //   0 = exact concept_id or concept_code match
    //   1 = exact name match
    //   2 = name starts with query
    //   3 = name contains all query words as substrings
    //   4 = fuzzy-only match (Jaro-Winkler above threshold)
    // Within each rank: standard first, then higher fuzzy score, then shorter name, then alphabetical.
    var rankExpr =
      'CASE ' +
        (isNumeric ? 'WHEN concept_id = ' + q + ' THEN 0 ' : '') +
        'WHEN LOWER(concept_code) = \'' + qLower + '\' THEN 0 ' +
        'WHEN LOWER(concept_name) = \'' + qLower + '\' THEN 1 ' +
        'WHEN LOWER(concept_name) LIKE \'' + qLower + '%\' THEN 2 ' +
        'WHEN ' + words.map(function(w) {
          return 'LOWER(concept_name) LIKE \'%' + w.toLowerCase() + '%\'';
        }).join(' AND ') + ' THEN 3 ' +
        'ELSE 4 ' +
      'END';

    var sql = 'SELECT concept_id, concept_name, vocabulary_id, domain_id, concept_class_id, concept_code, standard_concept, invalid_reason, ' +
      rankExpr + ' AS match_rank, ' +
      'jaro_winkler_similarity(LOWER(concept_name), \'' + qLower + '\') AS fuzzy_score ' +
      'FROM concept WHERE ' + whereParts.join(' AND ') +
      ' ORDER BY match_rank, CASE WHEN standard_concept = \'S\' THEN 0 ELSE 1 END, fuzzy_score DESC, LENGTH(concept_name), concept_name' + limitClause;

    VocabDB.query(sql).then(function(rows) {
      addConceptResults = rows || [];
      applyAddColumnFilters();
    }).catch(function(err) {
      tbody.innerHTML = '<tr><td colspan="' + colSpan + '" style="padding:20px; color:var(--danger)">' + App.escapeHtml(err.message) + '</td></tr>';
    });
    }
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

  // --- Active filter chips (shown below search bar) ---
  function renderAddActiveFilters() {
    var wrap = document.getElementById('expr-add-active-filters');
    if (!wrap) return;
    var chips = [];

    function addChip(type, label, value) {
      chips.push(
        '<span class="expr-add-chip" data-type="' + type + '"' +
          (value !== undefined ? ' data-value="' + App.escapeHtml(String(value)) + '"' : '') + '>' +
          '<span class="expr-add-chip-label">' + App.escapeHtml(label) + '</span>' +
          '<button class="expr-add-chip-x" title="' + App.i18n('Remove filter') + '"><i class="fas fa-times"></i></button>' +
        '</span>'
      );
    }

    addFilterVocab.forEach(function(v) { addChip('vocab', App.i18n('Vocabulary') + ': ' + (v || '(empty)'), v); });
    addFilterDomain.forEach(function(v) { addChip('domain', App.i18n('Domain') + ': ' + (v || '(empty)'), v); });
    addFilterClass.forEach(function(v) { addChip('class', App.i18n('Class') + ': ' + (v || '(empty)'), v); });

    // Standard filter: one chip per selected option. Empty set = no chip (means "all allowed").
    addFilterStandard.forEach(function(v) {
      addChip('standard', App.i18n('Standard') + ': ' + standardLabel(v), v);
    });
    // Valid-only chip: shown whenever the filter is active (default = active).
    if (addFilterValid) {
      addChip('valid', App.i18n('Valid only'));
    }

    wrap.style.display = '';
    var hasAny = addFilterVocab.size > 0 || addFilterDomain.size > 0 || addFilterClass.size > 0 ||
      addFilterStandard.size > 0 || addFilterValid;
    wrap.innerHTML = chips.join('') +
      (hasAny ? '<button class="expr-add-chip-clear" id="expr-add-chips-clear">' + App.i18n('Clear all') + '</button>' : '');
  }

  function removeAddActiveFilter(type, value) {
    if (type === 'vocab') addFilterVocab.delete(value);
    else if (type === 'domain') addFilterDomain.delete(value);
    else if (type === 'class') addFilterClass.delete(value);
    else if (type === 'standard') addFilterStandard.delete(value);
    else if (type === 'valid') {
      addFilterValid = false;
      var validCb = document.getElementById('expr-add-filter-valid');
      if (validCb) validCb.checked = false;
    }
    // Sync multi-select checkboxes in popup
    if (type === 'vocab' || type === 'domain' || type === 'class' || type === 'standard') {
      var containerId = 'expr-add-filter-' + type;
      var targetSet = type === 'vocab' ? addFilterVocab
        : type === 'domain' ? addFilterDomain
        : type === 'class' ? addFilterClass
        : addFilterStandard;
      var container = document.getElementById(containerId);
      if (container) {
        container.querySelectorAll('.ms-option input[type="checkbox"]').forEach(function(cb) {
          var v = cb.value || '';
          cb.checked = targetSet.has(v);
        });
      }
      if (App.updateMsToggleLabel) App.updateMsToggleLabel(containerId, targetSet);
    }
    renderAddActiveFilters();
    if (document.getElementById('expr-add-search').value.trim()) searchAddConcepts();
    else loadAddDefaults();
  }

  function clearAllAddActiveFilters() {
    addFilterVocab.clear();
    addFilterDomain.clear();
    addFilterClass.clear();
    addFilterStandard.clear();
    addFilterValid = false;
    var validCb = document.getElementById('expr-add-filter-valid');
    if (validCb) validCb.checked = false;
    ['expr-add-filter-vocab', 'expr-add-filter-domain', 'expr-add-filter-class', 'expr-add-filter-standard'].forEach(function(id) {
      var container = document.getElementById(id);
      if (!container) return;
      var targetSet = id === 'expr-add-filter-vocab' ? addFilterVocab
        : id === 'expr-add-filter-domain' ? addFilterDomain
        : id === 'expr-add-filter-class' ? addFilterClass
        : addFilterStandard;
      container.querySelectorAll('.ms-option input[type="checkbox"]').forEach(function(cb) {
        cb.checked = targetSet.has(cb.value || '');
      });
    });
    if (App.updateMsToggleLabel) {
      App.updateMsToggleLabel('expr-add-filter-vocab', addFilterVocab);
      App.updateMsToggleLabel('expr-add-filter-domain', addFilterDomain);
      App.updateMsToggleLabel('expr-add-filter-class', addFilterClass);
      App.updateMsToggleLabel('expr-add-filter-standard', addFilterStandard, getStandardLabelMap());
    }
    renderAddActiveFilters();
    if (document.getElementById('expr-add-search').value.trim()) searchAddConcepts();
    else loadAddDefaults();
  }

  function updateAddCount() {
    var n = addConceptSelectedIds.size;
    document.getElementById('expr-add-count').textContent = n + ' selected';
    var btn = document.getElementById('expr-add-submit');
    btn.disabled = false;
    var label = btn.querySelector('span[data-i18n]');
    if (label) {
      var key = n > 1 ? 'Add Concepts' : 'Add Concept';
      label.setAttribute('data-i18n', key);
      label.textContent = App.i18n(key);
    }
  }

  // --- Selected Concept Details panel ---
  var addModalHierarchyNetwork = null;
  var addModalHierarchyHistory = [];
  var addModalHierarchyWrapper = null;
  var addModalHierarchyFullscreen = false;

  function showAddConceptDetail(r) {
    // Reset hierarchy state when selecting a new concept from search
    addModalHierarchyHistory = [];
    if (addModalHierarchyNetwork) { addModalHierarchyNetwork.destroy(); addModalHierarchyNetwork = null; }
    if (addModalHierarchyWrapper && addModalHierarchyFullscreen) {
      addModalHierarchyWrapper.classList.remove('fullscreen');
      addModalHierarchyFullscreen = false;
    }
    addModalHierarchyWrapper = null;
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

    var copyBtn = function(value) {
      return ' <i class="far fa-clone detail-copy-btn" data-copy="' + App.escapeHtml(String(value)) + '" title="Copy"></i>';
    };

    el.innerHTML = alreadyHtml +
      '<div class="concept-details-container"><div class="concept-details-grid">' +
      '<div class="detail-item"><strong>Concept Name:</strong><span>' + App.escapeHtml(r.concept_name) + copyBtn(r.concept_name) + '</span></div>' +
      '<div class="detail-item"><strong>OMOP Concept ID:</strong><span><a href="' + athenaUrl + '" target="_blank">' + r.concept_id + '</a>' + copyBtn(r.concept_id) + '</span></div>' +
      '<div class="detail-item"><strong>Vocabulary ID:</strong><span>' + App.escapeHtml(r.vocabulary_id) + '</span></div>' +
      '<div class="detail-item"><strong>Concept Code:</strong><span>' + App.escapeHtml(r.concept_code || '') + copyBtn(r.concept_code || '') + '</span></div>' +
      '<div class="detail-item"><strong>Domain:</strong><span>' + App.escapeHtml(r.domain_id || '') + '</span></div>' +
      '<div class="detail-item"><strong>Standard:</strong><span style="color:' + standardColor + ';font-weight:600">' + standardText + '</span></div>' +
      '<div class="detail-item"><strong>Concept Class:</strong><span>' + App.escapeHtml(r.concept_class_id || '') + '</span></div>' +
      '<div class="detail-item"><strong>Validity:</strong><span style="color:' + validityColor + ';font-weight:600">' + validityText + '</span></div>' +
      '</div></div>';

    // Load hierarchy in right panel
    loadAddModalHierarchy(Number(r.concept_id));
  }

  function loadAddModalHierarchy(conceptId) {
    var el = document.getElementById('expr-add-hierarchy-body');
    if (!el) return;

    // Show loading in canvas if wrapper exists, otherwise in the element
    if (addModalHierarchyWrapper) {
      var canvas = addModalHierarchyWrapper.querySelector('.amh-canvas');
      if (canvas) canvas.innerHTML = '<div class="loading-inline"><i class="fas fa-spinner fa-spin"></i> Loading hierarchy...</div>';
    } else {
      el.innerHTML = '<div class="loading-inline"><i class="fas fa-spinner fa-spin"></i> Loading hierarchy...</div>';
    }

    // Count nodes first to warn on large hierarchies
    var countSql =
      'WITH RECURSIVE anc AS (' +
        'SELECT ancestor_concept_id AS cid, 1 AS d FROM concept_ancestor WHERE descendant_concept_id = ' + conceptId +
        ' UNION ALL SELECT ca.ancestor_concept_id, anc.d + 1 FROM concept_ancestor ca JOIN anc ON ca.descendant_concept_id = anc.cid WHERE anc.d < 20' +
      '), desc_r AS (' +
        'SELECT descendant_concept_id AS cid, 1 AS d FROM concept_ancestor WHERE ancestor_concept_id = ' + conceptId +
        ' UNION ALL SELECT ca.descendant_concept_id, desc_r.d + 1 FROM concept_ancestor ca JOIN desc_r ON ca.ancestor_concept_id = desc_r.cid WHERE desc_r.d < 20' +
      ') SELECT (SELECT COUNT(DISTINCT cid) FROM anc) AS ancestors, (SELECT COUNT(DISTINCT cid) FROM desc_r) AS descendants';

    VocabDB.query(countSql).then(function(countRows) {
      var total = Number(countRows[0].ancestors) + Number(countRows[0].descendants) + 1;
      if (total > HIERARCHY_WARN_THRESHOLD) {
        var target = addModalHierarchyWrapper ? addModalHierarchyWrapper : el;
        var overlay = document.createElement('div');
        overlay.className = 'hierarchy-warn-overlay';
        overlay.innerHTML =
          '<div class="hierarchy-warn-box">' +
            '<i class="fas fa-exclamation-triangle" style="color:var(--warning); font-size:18px"></i>' +
            '<div style="margin-top:8px">This concept has <strong>' + total + '</strong> nodes. Loading may be slow.</div>' +
            '<div style="display:flex; gap:8px; margin-top:12px">' +
              '<button class="btn-outline-sm amh-warn-cancel"><i class="fas fa-times"></i> Cancel</button>' +
              '<button class="btn-outline-sm amh-warn-load"><i class="fas fa-project-diagram"></i> Load anyway</button>' +
            '</div>' +
          '</div>';
        target.appendChild(overlay);
        overlay.querySelector('.amh-warn-cancel').addEventListener('click', function() { overlay.remove(); });
        overlay.querySelector('.amh-warn-load').addEventListener('click', function() {
          overlay.remove();
          doLoadAddModalHierarchy(conceptId, el);
        });
        return;
      }
      doLoadAddModalHierarchy(conceptId, el);
    }).catch(function(err) {
      var errTarget = addModalHierarchyWrapper ? addModalHierarchyWrapper.querySelector('.amh-canvas') : el;
      if (errTarget) errTarget.innerHTML = '<div class="loading-inline" style="color:var(--danger)">Error: ' + App.escapeHtml(err.message) + '</div>';
    });
  }

  function doLoadAddModalHierarchy(conceptId, el) {
    var ancestorsSql =
      'WITH RECURSIVE anc AS (' +
        'SELECT ancestor_concept_id AS cid, 1 AS depth FROM concept_ancestor WHERE descendant_concept_id = ' + conceptId +
        ' UNION ALL SELECT ca.ancestor_concept_id, anc.depth + 1 FROM concept_ancestor ca JOIN anc ON ca.descendant_concept_id = anc.cid WHERE anc.depth < 20' +
      ') SELECT DISTINCT c.concept_id, c.concept_name, c.vocabulary_id, c.domain_id, c.concept_class_id, c.concept_code, c.standard_concept, -MIN(anc.depth) AS hierarchy_level ' +
      'FROM anc JOIN concept c ON c.concept_id = anc.cid GROUP BY c.concept_id, c.concept_name, c.vocabulary_id, c.domain_id, c.concept_class_id, c.concept_code, c.standard_concept ORDER BY MIN(anc.depth)';
    var descendantsSql =
      'WITH RECURSIVE desc_r AS (' +
        'SELECT descendant_concept_id AS cid, 1 AS depth FROM concept_ancestor WHERE ancestor_concept_id = ' + conceptId +
        ' UNION ALL SELECT ca.descendant_concept_id, desc_r.depth + 1 FROM concept_ancestor ca JOIN desc_r ON ca.ancestor_concept_id = desc_r.cid WHERE desc_r.depth < 20' +
      ') SELECT DISTINCT c.concept_id, c.concept_name, c.vocabulary_id, c.domain_id, c.concept_class_id, c.concept_code, c.standard_concept, MIN(desc_r.depth) AS hierarchy_level ' +
      'FROM desc_r JOIN concept c ON c.concept_id = desc_r.cid GROUP BY c.concept_id, c.concept_name, c.vocabulary_id, c.domain_id, c.concept_class_id, c.concept_code, c.standard_concept ORDER BY MIN(desc_r.depth)';
    var selfSql = 'SELECT concept_id, concept_name, vocabulary_id, domain_id, concept_class_id, concept_code, standard_concept FROM concept WHERE concept_id = ' + conceptId;

    Promise.all([
      VocabDB.query(ancestorsSql),
      VocabDB.query(descendantsSql),
      VocabDB.query(selfSql)
    ]).then(function(results) {
      var ancestors = results[0] || [];
      var descendants = results[1] || [];
      var self = results[2] && results[2][0];
      if (!self) {
        var t = addModalHierarchyWrapper ? addModalHierarchyWrapper.querySelector('.amh-canvas') : el;
        if (t) t.innerHTML = '<div class="empty-state"><p>Concept not found</p></div>';
        return;
      }

      var allIds = [Number(self.concept_id)];
      ancestors.forEach(function(a) { allIds.push(Number(a.concept_id)); });
      descendants.forEach(function(d) { allIds.push(Number(d.concept_id)); });

      if (allIds.length === 1) {
        var t2 = addModalHierarchyWrapper ? addModalHierarchyWrapper.querySelector('.amh-canvas') : el;
        if (t2) t2.innerHTML = '<div class="empty-state"><p>No hierarchy</p></div>';
        return;
      }

      var edgesSql = 'SELECT ancestor_concept_id AS from_id, descendant_concept_id AS to_id FROM concept_ancestor ' +
        'WHERE ancestor_concept_id IN (' + allIds.join(',') + ') AND descendant_concept_id IN (' + allIds.join(',') + ')';

      return VocabDB.query(edgesSql).then(function(edgeRows) {
        renderAddModalHierarchy(self, ancestors, descendants, edgeRows || [], el);
      });
    }).catch(function(err) {
      var errTarget = addModalHierarchyWrapper ? addModalHierarchyWrapper.querySelector('.amh-canvas') : el;
      if (errTarget) errTarget.innerHTML = '<div class="loading-inline" style="color:var(--danger)">Error: ' + App.escapeHtml(err.message) + '</div>';
    });
  }

  function renderAddModalHierarchy(self, ancestors, descendants, edgeRows, el) {
    var selfId = Number(self.concept_id);
    var wrapper;

    if (addModalHierarchyWrapper) {
      wrapper = addModalHierarchyWrapper;
      var titleEl = wrapper.querySelector('.hierarchy-header-title');
      if (titleEl) titleEl.innerHTML = App.escapeHtml(self.concept_name) + '<span class="hierarchy-id">#' + selfId + ' · ' + App.escapeHtml(self.vocabulary_id) + '</span>';
      var backBtn = wrapper.querySelector('.amh-back-btn');
      if (backBtn) backBtn.disabled = (addModalHierarchyHistory.length === 0);
      var canvas = wrapper.querySelector('.amh-canvas');
      if (canvas) canvas.innerHTML = '';
    } else {
      el.innerHTML = '';
      wrapper = document.createElement('div');
      wrapper.className = 'hierarchy-graph-container';
      wrapper.style.cssText = '';
      wrapper.innerHTML =
        '<div class="hierarchy-header">' +
          '<button class="hierarchy-btn amh-back-btn" title="Back" disabled><i class="fas fa-arrow-left"></i></button>' +
          '<div class="hierarchy-header-title">' + App.escapeHtml(self.concept_name) + '<span class="hierarchy-id">#' + selfId + ' · ' + App.escapeHtml(self.vocabulary_id) + '</span></div>' +
          '<div class="hierarchy-controls">' +
            '<button class="hierarchy-btn amh-zoom-in" title="Zoom in"><i class="fas fa-search-plus"></i></button>' +
            '<button class="hierarchy-btn amh-zoom-out" title="Zoom out"><i class="fas fa-search-minus"></i></button>' +
            '<button class="hierarchy-btn amh-fit" title="Fit to view"><i class="fas fa-compress-arrows-alt"></i></button>' +
            '<button class="hierarchy-btn amh-fullscreen" title="Toggle fullscreen"><i class="fas fa-expand"></i></button>' +
          '</div>' +
        '</div>' +
        '<div class="amh-canvas"></div>';
      el.appendChild(wrapper);
      addModalHierarchyWrapper = wrapper;

      wrapper.querySelector('.amh-back-btn').addEventListener('click', function() {
        if (addModalHierarchyHistory.length > 0) loadAddModalHierarchy(addModalHierarchyHistory.pop());
      });
      wrapper.querySelector('.amh-zoom-in').addEventListener('click', function() {
        if (addModalHierarchyNetwork) { var s = addModalHierarchyNetwork.getScale(); addModalHierarchyNetwork.moveTo({ scale: s * 1.3, animation: { duration: 300 } }); }
      });
      wrapper.querySelector('.amh-zoom-out').addEventListener('click', function() {
        if (addModalHierarchyNetwork) { var s = addModalHierarchyNetwork.getScale(); addModalHierarchyNetwork.moveTo({ scale: s / 1.3, animation: { duration: 300 } }); }
      });
      wrapper.querySelector('.amh-fit').addEventListener('click', function() {
        if (addModalHierarchyNetwork) addModalHierarchyNetwork.fit({ animation: { duration: 400 } });
      });
      wrapper.querySelector('.amh-fullscreen').addEventListener('click', function() {
        addModalHierarchyFullscreen = !addModalHierarchyFullscreen;
        wrapper.classList.toggle('fullscreen', addModalHierarchyFullscreen);
        var icon = this.querySelector('i');
        icon.className = addModalHierarchyFullscreen ? 'fas fa-compress' : 'fas fa-expand';
        this.title = addModalHierarchyFullscreen ? 'Exit fullscreen' : 'Toggle fullscreen';
        setTimeout(function() { if (addModalHierarchyNetwork) addModalHierarchyNetwork.fit({ animation: { duration: 300 } }); }, 100);
      });
    }

    var canvasEl = wrapper.querySelector('.amh-canvas');

    var nodes = [];
    var edges = [];

    nodes.push({
      id: selfId, label: self.concept_name + '\n[' + self.vocabulary_id + ']',
      level: 0, shape: 'box', color: { background: '#0f60af', border: '#0a4a8a' },
      font: { color: '#fff', size: 11 }, widthConstraint: { minimum: 120, maximum: 200 }
    });
    ancestors.forEach(function(a) {
      nodes.push({
        id: Number(a.concept_id), label: a.concept_name + '\n[' + a.vocabulary_id + ']',
        level: Number(a.hierarchy_level), shape: 'box',
        color: { background: '#6c757d', border: '#555' },
        font: { color: '#fff', size: 10 }, widthConstraint: { minimum: 120, maximum: 200 }
      });
    });
    descendants.forEach(function(d) {
      nodes.push({
        id: Number(d.concept_id), label: d.concept_name + '\n[' + d.vocabulary_id + ']',
        level: Number(d.hierarchy_level), shape: 'box',
        color: { background: '#28a745', border: '#1e7e34' },
        font: { color: '#fff', size: 10 }, widthConstraint: { minimum: 120, maximum: 200 }
      });
    });
    edgeRows.forEach(function(e) {
      edges.push({ from: Number(e.from_id), to: Number(e.to_id), arrows: 'to' });
    });

    if (addModalHierarchyNetwork) addModalHierarchyNetwork.destroy();
    addModalHierarchyNetwork = new vis.Network(canvasEl,
      { nodes: new vis.DataSet(nodes), edges: new vis.DataSet(edges) },
      {
        layout: { hierarchical: { direction: 'UD', sortMethod: 'directed', levelSeparation: 60, nodeSpacing: 100 } },
        physics: false,
        interaction: { hover: true, zoomView: true, dragView: true, tooltipDelay: 0 },
        edges: { color: { color: '#ccc', hover: '#999' }, smooth: { type: 'cubicBezier', roundness: 0.5 } }
      }
    );

    // Populate hierarchyConceptMap for tooltip
    hierarchyConceptMap[selfId] = self;
    ancestors.forEach(function(a) { hierarchyConceptMap[Number(a.concept_id)] = a; });
    descendants.forEach(function(d) { hierarchyConceptMap[Number(d.concept_id)] = d; });

    // Custom tooltip on hover
    var tooltipShowTimeout = null;
    var tooltipHideTimeout = null;
    addModalHierarchyNetwork.on('hoverNode', function(params) {
      if (hierarchyPinnedId !== null) return;
      clearTimeout(tooltipShowTimeout);
      clearTimeout(tooltipHideTimeout);
      var domPos = params.pointer && params.pointer.DOM ? params.pointer.DOM : { x: 0, y: 0 };
      tooltipShowTimeout = setTimeout(function() {
        if (hierarchyPinnedId !== null) return;
        showHierarchyTooltip(params.node, canvasEl, domPos, { showSearch: true });
      }, 300);
    });
    addModalHierarchyNetwork.on('blurNode', function() {
      if (hierarchyPinnedId !== null) return;
      clearTimeout(tooltipShowTimeout);
      clearTimeout(tooltipHideTimeout);
      tooltipHideTimeout = setTimeout(function() {
        if (hierarchyPinnedId !== null) return;
        if (!document.querySelector('.hierarchy-tooltip:hover')) hideHierarchyTooltip();
      }, 200);
    });
    // Click on a node: pin the tooltip. Re-clicking the same node unpins it.
    // Click outside a node: unpin tooltip and deselect.
    addModalHierarchyNetwork.on('click', function(params) {
      clearTimeout(tooltipShowTimeout);
      clearTimeout(tooltipHideTimeout);
      if (params.nodes && params.nodes.length === 1) {
        var nodeId = Number(params.nodes[0]);
        if (hierarchyPinnedId === nodeId) {
          unpinHierarchyTooltip();
          addModalHierarchyNetwork.unselectAll();
          return;
        }
        var domPos = params.pointer && params.pointer.DOM ? params.pointer.DOM : { x: 0, y: 0 };
        hierarchyPinnedId = null;
        showHierarchyTooltip(nodeId, canvasEl, domPos, { showSearch: true, pin: true });
      } else {
        // Click outside a node: unpin tooltip and deselect
        unpinHierarchyTooltip();
        addModalHierarchyNetwork.unselectAll();
      }
    });

    // Double-click to navigate within modal hierarchy
    addModalHierarchyNetwork.on('doubleClick', function(params) {
      if (params.nodes.length === 1) {
        var cid = params.nodes[0];
        if (cid === selfId) return;
        unpinHierarchyTooltip();
        addModalHierarchyHistory.push(selfId);
        loadAddModalHierarchy(cid);
      }
    });
  }


  // --- Submit ---
  function submitAddConcepts() {
    if (addConceptSelectedIds.size === 0) { App.showToast(App.i18n('Please select at least one concept.'), 'warning'); return; }
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
    var msg = added + App.i18n(added !== 1 ? ' concepts' : ' concept') + App.i18n(' added');
    if (skipped > 0) msg += ', ' + skipped + App.i18n(' skipped (already in expression)');
    App.showToast(msg);
  }

  // ==================== CUSTOM CONCEPTS ====================

  var customDomainValue = '';
  var customClassValue = '';
  var customDropdownsBuilt = false;

  function getNextCustomConceptId() {
    var maxId = CUSTOM_CONCEPT_BASE - 1;
    // Scan all concept sets for existing custom concept IDs
    App.conceptSets.forEach(function(cs) {
      if (cs.expression && cs.expression.items) {
        cs.expression.items.forEach(function(it) {
          if (it.concept && it.concept.conceptId >= CUSTOM_CONCEPT_BASE) {
            maxId = Math.max(maxId, it.concept.conceptId);
          }
        });
      }
    });
    // Also scan current edit items
    if (exprEditItems) {
      exprEditItems.forEach(function(it) {
        if (it.concept && it.concept.conceptId >= CUSTOM_CONCEPT_BASE) {
          maxId = Math.max(maxId, it.concept.conceptId);
        }
      });
    }
    return maxId + 1;
  }

  // Build a single-select searchable dropdown (reuses ms-container styling)
  function buildSingleSelectDropdown(containerId, values, currentValue, onChange) {
    var container = document.getElementById(containerId);
    if (!container) return;
    function toggleLabel() {
      return currentValue ? App.escapeHtml(currentValue) : App.i18n('-- Select --');
    }
    container.innerHTML =
      '<div class="ms-toggle" tabindex="0">' + toggleLabel() + ' <i class="fas fa-chevron-down" style="font-size:9px;margin-left:2px"></i></div>' +
      '<div class="ms-dropdown" style="display:none">' +
        '<div class="ms-search-wrap"><input type="text" class="ms-search" placeholder="' + App.escapeHtml(App.i18n('Search')) + '…"></div>' +
        '<div class="ms-options">' +
          values.map(function(v) {
            return '<div class="ms-option ms-option-single' + (v === currentValue ? ' ms-option-selected' : '') + '" data-value="' + App.escapeHtml(v) + '">' + App.escapeHtml(v) + '</div>';
          }).join('') +
        '</div>' +
      '</div>';
    var toggle = container.querySelector('.ms-toggle');
    var dropdown = container.querySelector('.ms-dropdown');
    var searchInput = container.querySelector('.ms-search');
    toggle.addEventListener('click', function(e) {
      e.stopPropagation();
      // Close other open dropdowns
      document.querySelectorAll('.ms-dropdown').forEach(function(d) { if (d !== dropdown) d.style.display = 'none'; });
      var wasHidden = dropdown.style.display === 'none';
      dropdown.style.display = wasHidden ? '' : 'none';
      if (wasHidden && searchInput) { searchInput.value = ''; searchInput.dispatchEvent(new Event('input')); searchInput.focus(); }
    });
    searchInput.addEventListener('input', function() {
      var q = searchInput.value.toLowerCase();
      container.querySelectorAll('.ms-option-single').forEach(function(opt) {
        opt.style.display = opt.textContent.toLowerCase().indexOf(q) !== -1 ? '' : 'none';
      });
    });
    searchInput.addEventListener('click', function(e) { e.stopPropagation(); });
    dropdown.addEventListener('click', function(e) {
      var opt = e.target.closest('.ms-option-single');
      if (!opt) return;
      var val = opt.getAttribute('data-value');
      // Update selection highlight
      container.querySelectorAll('.ms-option-single').forEach(function(o) { o.classList.remove('ms-option-selected'); });
      opt.classList.add('ms-option-selected');
      // Update toggle label & close
      toggle.innerHTML = App.escapeHtml(val) + ' <i class="fas fa-chevron-down" style="font-size:9px;margin-left:2px"></i>';
      dropdown.style.display = 'none';
      onChange(val);
    });
  }

  var FALLBACK_DOMAINS = [
    'Condition', 'Device', 'Drug', 'Gender', 'Measurement', 'Metadata',
    'Observation', 'Procedure', 'Provider', 'Race', 'Spec Anatomic Site',
    'Specimen', 'Type Concept', 'Unit', 'Visit'
  ];
  var FALLBACK_CLASSES = [
    'Clinical Finding', 'Clinical Observation', 'Context-dependent', 'Disorder',
    'Lab Test', 'Observable Entity', 'Organism', 'Pharma/Biol Product',
    'Physical Object', 'Procedure', 'Qualifier Value', 'Staging / Scales', 'Substance'
  ];

  var customDropdownsFromDb = false;

  function buildCustomDropdownsWithValues(domains, classes, fromDb) {
    buildSingleSelectDropdown('custom-concept-domain', domains, customDomainValue, function(val) { customDomainValue = val; });
    buildSingleSelectDropdown('custom-concept-class', classes, customClassValue, function(val) { customClassValue = val; });
    customDropdownsBuilt = true;
    if (fromDb) customDropdownsFromDb = true;
  }

  function buildCustomDropdowns() {
    // Already built from real DB data — skip
    if (customDropdownsFromDb) return Promise.resolve();
    if (typeof VocabDB === 'undefined') {
      if (!customDropdownsBuilt) buildCustomDropdownsWithValues(FALLBACK_DOMAINS, FALLBACK_CLASSES, false);
      return Promise.resolve();
    }
    return VocabDB.isDatabaseReady().then(function(ready) {
      if (!ready) {
        if (!customDropdownsBuilt) buildCustomDropdownsWithValues(FALLBACK_DOMAINS, FALLBACK_CLASSES, false);
        return;
      }
      return Promise.all([
        VocabDB.query("SELECT domain_id FROM domain ORDER BY domain_id").catch(function() { return null; }),
        VocabDB.query("SELECT concept_class_id FROM concept_class ORDER BY concept_class_id").catch(function() { return null; })
      ]).then(function(results) {
        var domains = results[0] ? results[0].map(function(r) { return r.domain_id; }) : [];
        var classes = results[1] ? results[1].map(function(r) { return r.concept_class_id; }) : [];
        // Rebuild even if fallbacks were already shown — replace with real data
        buildCustomDropdownsWithValues(
          domains.length > 0 ? domains : FALLBACK_DOMAINS,
          classes.length > 0 ? classes : FALLBACK_CLASSES,
          domains.length > 0 || classes.length > 0
        );
      });
    }).catch(function() {
      if (!customDropdownsBuilt) buildCustomDropdownsWithValues(FALLBACK_DOMAINS, FALLBACK_CLASSES, false);
    });
  }

  function switchAddTab(tab) {
    addActiveTab = tab;
    var ohdsiPanel = document.getElementById('expr-add-panel-ohdsi');
    var customPanel = document.getElementById('expr-add-panel-custom');
    var ohdsiFooter = document.getElementById('expr-add-footer-ohdsi');
    var customFooter = document.getElementById('expr-add-footer-custom');
    var tabOhdsi = document.getElementById('expr-add-tab-ohdsi');
    var tabCustom = document.getElementById('expr-add-tab-custom');

    if (tab === 'ohdsi') {
      ohdsiPanel.style.display = '';
      customPanel.style.display = 'none';
      ohdsiFooter.style.display = '';
      customFooter.style.display = 'none';
      tabOhdsi.classList.add('active');
      tabCustom.classList.remove('active');
    } else {
      ohdsiPanel.style.display = 'none';
      customPanel.style.display = '';
      ohdsiFooter.style.display = 'none';
      customFooter.style.display = '';
      tabOhdsi.classList.remove('active');
      tabCustom.classList.add('active');
      // Set next available ID
      document.getElementById('custom-concept-id').value = getNextCustomConceptId();
      buildCustomDropdowns();
    }
  }

  function submitCustomConcept() {
    var name = document.getElementById('custom-concept-name').value.trim();
    var domain = customDomainValue;
    var conceptClass = customClassValue;
    var code = document.getElementById('custom-concept-code').value.trim();
    var vocab = document.getElementById('custom-concept-vocabulary').value.trim() || 'INDICATE';
    var isExcluded = document.getElementById('custom-concept-exclude').checked;

    // Validation
    if (!name) { App.showToast(App.i18n('Please enter a concept name.'), 'error'); return; }
    if (!domain) { App.showToast(App.i18n('Please select a domain.'), 'error'); return; }
    if (!conceptClass) { App.showToast(App.i18n('Please select a concept class.'), 'error'); return; }

    var conceptId = getNextCustomConceptId();
    var now = new Date().toISOString().slice(0, 10);

    exprEditItems.push({
      concept: {
        conceptId: conceptId,
        conceptName: name,
        domainId: domain,
        vocabularyId: vocab,
        conceptClassId: conceptClass,
        standardConcept: '',
        standardConceptCaption: 'Non-standard',
        conceptCode: code || 'INDICATE-' + conceptId,
        validStartDate: now,
        validEndDate: '2099-12-31',
        invalidReason: null,
        invalidReasonCaption: 'Valid'
      },
      isExcluded: isExcluded,
      includeDescendants: false,
      includeMapped: false
    });

    renderExpressionTable();
    App.showToast('1' + App.i18n(' custom concept added'));

    // Reset form for next entry
    document.getElementById('custom-concept-name').value = '';
    document.getElementById('custom-concept-code').value = '';
    document.getElementById('custom-concept-id').value = getNextCustomConceptId();
  }

  // ==================== EDIT CUSTOM CONCEPT MODAL ====================

  var editCcIdx = null; // index in exprEditItems being edited
  var editCcDomainValue = '';
  var editCcClassValue = '';

  function openEditCustomConceptModal(idx) {
    if (!exprEditItems || !exprEditItems[idx]) return;
    var item = exprEditItems[idx];
    var c = item.concept;
    if (c.conceptId < CUSTOM_CONCEPT_BASE) return; // not a custom concept

    editCcIdx = idx;
    editCcDomainValue = c.domainId || '';
    editCcClassValue = c.conceptClassId || '';

    // Populate fields
    document.getElementById('edit-cc-id').value = c.conceptId;
    document.getElementById('edit-cc-name').value = c.conceptName || '';
    document.getElementById('edit-cc-vocabulary').value = c.vocabularyId || 'INDICATE';
    document.getElementById('edit-cc-code').value = c.conceptCode || '';
    document.getElementById('edit-cc-standard').value = c.standardConceptCaption || 'Non-standard';

    // Build domain & class dropdowns
    // Reuse the same logic as the add form dropdowns
    if (customDropdownsFromDb && typeof VocabDB !== 'undefined') {
      VocabDB.isDatabaseReady().then(function(ready) {
        if (!ready) {
          buildEditCcDropdowns(FALLBACK_DOMAINS, FALLBACK_CLASSES);
          return;
        }
        return Promise.all([
          VocabDB.query("SELECT domain_id FROM domain ORDER BY domain_id").catch(function() { return null; }),
          VocabDB.query("SELECT concept_class_id FROM concept_class ORDER BY concept_class_id").catch(function() { return null; })
        ]).then(function(results) {
          var d = results[0] ? results[0].map(function(r) { return r.domain_id; }) : FALLBACK_DOMAINS;
          var cl = results[1] ? results[1].map(function(r) { return r.concept_class_id; }) : FALLBACK_CLASSES;
          buildEditCcDropdowns(d.length > 0 ? d : FALLBACK_DOMAINS, cl.length > 0 ? cl : FALLBACK_CLASSES);
        });
      }).catch(function() {
        buildEditCcDropdowns(FALLBACK_DOMAINS, FALLBACK_CLASSES);
      });
    } else {
      buildEditCcDropdowns(FALLBACK_DOMAINS, FALLBACK_CLASSES);
    }

    document.getElementById('edit-custom-concept-modal').style.display = '';
  }

  function buildEditCcDropdowns(domains, classes) {
    buildSingleSelectDropdown('edit-cc-domain', domains, editCcDomainValue, function(val) { editCcDomainValue = val; });
    buildSingleSelectDropdown('edit-cc-class', classes, editCcClassValue, function(val) { editCcClassValue = val; });
  }

  function saveEditCustomConcept() {
    var name = document.getElementById('edit-cc-name').value.trim();
    var domain = editCcDomainValue;
    var conceptClass = editCcClassValue;
    var code = document.getElementById('edit-cc-code').value.trim();
    var vocab = document.getElementById('edit-cc-vocabulary').value.trim() || 'INDICATE';

    // Validation
    if (!name) { App.showToast(App.i18n('Please enter a concept name.'), 'error'); return; }
    if (!domain) { App.showToast(App.i18n('Please select a domain.'), 'error'); return; }
    if (!conceptClass) { App.showToast(App.i18n('Please select a concept class.'), 'error'); return; }

    if (editCcIdx === null || !exprEditItems[editCcIdx]) return;

    var c = exprEditItems[editCcIdx].concept;
    c.conceptName = name;
    c.domainId = domain;
    c.vocabularyId = vocab;
    c.conceptClassId = conceptClass;
    c.conceptCode = code || ('INDICATE-' + c.conceptId);

    renderExpressionTable();
    closeEditCustomConceptModal();
    App.showToast(App.i18n('Custom concept updated'));
  }

  function closeEditCustomConceptModal() {
    document.getElementById('edit-custom-concept-modal').style.display = 'none';
    editCcIdx = null;
  }


  // ==================== RESOLVED TABLE ====================
  var resolvedFilterVocab = new Set();
  var resolvedFilterStandard = new Set();

  // Expression table filters
  var exprFilterVocab = new Set();
  var exprFilterStandard = new Set();

  var resolvedColumns = {
    vocabulary: { label: 'Vocabulary', visible: true },
    conceptId: { label: 'Concept ID', visible: false },
    name: { label: 'Concept Name', visible: true },
    code: { label: 'Concept Code', visible: true },
    domain: { label: 'Domain', visible: false },
    'class': { label: 'Concept Class', visible: true },
    standard: { label: 'Standard', visible: true }
  };
  var expressionColumns = {
    vocabulary: { label: 'Vocabulary', visible: true },
    conceptId: { label: 'Concept ID', visible: true },
    name: { label: 'Concept Name', visible: true },
    code: { label: 'Concept Code', visible: true },
    domain: { label: 'Domain', visible: true },
    'class': { label: 'Concept Class', visible: false },
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

  // ==================== EXPRESSION TABLE FILTERS ====================
  function populateExpressionFilters(items) {
    var vocabs = {}, domains = {}, standards = {}, classes = {};
    items.forEach(function(item) {
      var c = item.concept;
      vocabs[c.vocabularyId || ''] = true;
      domains[c.domainId || ''] = true;
      var sc = c.standardConcept || '';
      standards[sc] = standardLabel(sc);
      classes[c.conceptClassId || ''] = true;
    });

    var vocabValues = Object.keys(vocabs).sort();
    App.buildMultiSelectDropdown('expr-filter-vocabulary', vocabValues, exprFilterVocab, function() {
      expressionPage = 1; renderExpressionTable();
    });

    function fillSelect(id, values) {
      var sel = document.getElementById(id);
      var cur = sel.value;
      var opts = '<option value="">All</option>';
      Object.keys(values).sort().forEach(function(v) {
        opts += '<option value="' + App.escapeHtml(v) + '">' + App.escapeHtml(v || '(empty)') + '</option>';
      });
      sel.innerHTML = opts;
      sel.value = cur;
    }
    fillSelect('expr-filter-domain', domains);
    fillSelect('expr-filter-class', classes);

    var stdValues = ['S', 'C', ''];
    var stdLabels = { 'S': 'Standard', 'C': 'Classification', '': 'Non-standard' };
    App.buildMultiSelectDropdown('expr-filter-standard', stdValues, exprFilterStandard, function() {
      expressionPage = 1; renderExpressionTable();
    }, stdLabels);
  }

  function getExpressionFilters() {
    return {
      conceptId: document.getElementById('expr-filter-conceptId').value.toLowerCase(),
      vocabulary: exprFilterVocab,
      name: document.getElementById('expr-filter-name').value.toLowerCase(),
      code: document.getElementById('expr-filter-code').value.toLowerCase(),
      domain: document.getElementById('expr-filter-domain').value,
      conceptClass: document.getElementById('expr-filter-class').value,
      standard: exprFilterStandard,
      exclude: document.getElementById('expr-filter-exclude').value,
      descendants: document.getElementById('expr-filter-descendants').value,
      mapped: document.getElementById('expr-filter-mapped').value
    };
  }

  function filterExpressionItems(items, filters) {
    return items.filter(function(item) {
      var c = item.concept;
      if (filters.vocabulary.size > 0 && !filters.vocabulary.has(c.vocabularyId || '')) return false;
      if (filters.name && !fuzzyMatchBool((c.conceptName || '').toLowerCase(), filters.name)) return false;
      if (filters.code && (c.conceptCode || '').toLowerCase().indexOf(filters.code) === -1) return false;
      if (filters.domain && (c.domainId || '') !== filters.domain) return false;
      if (filters.standard.size > 0 && !filters.standard.has(c.standardConcept || '')) return false;
      if (filters.exclude === 'yes' && !item.isExcluded) return false;
      if (filters.exclude === 'no' && item.isExcluded) return false;
      if (filters.descendants === 'yes' && !item.includeDescendants) return false;
      if (filters.descendants === 'no' && item.includeDescendants) return false;
      if (filters.mapped === 'yes' && !item.includeMapped) return false;
      if (filters.mapped === 'no' && item.includeMapped) return false;
      return true;
    });
  }

  function resetExpressionFilters() {
    exprFilterVocab.clear();
    exprFilterStandard.clear();
    document.getElementById('expr-filter-conceptId').value = '';
    document.getElementById('expr-filter-name').value = '';
    document.getElementById('expr-filter-code').value = '';
    document.getElementById('expr-filter-domain').value = '';
    document.getElementById('expr-filter-class').value = '';
    document.getElementById('expr-filter-exclude').value = '';
    document.getElementById('expr-filter-descendants').value = '';
    document.getElementById('expr-filter-mapped').value = '';
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

    // Always offer the 3 standard options, regardless of what's actually present in the data,
    // so users can uncheck categories that aren't represented without leaving ghost selections.
    var stdValues = ['S', 'C', ''];
    var stdLabels = { 'S': 'Standard', 'C': 'Classification', '': 'Non-standard' };
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

  function renderResolvedTableWithData(allConcepts, keepFilters) {
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
      resolvedFilterStandard.add('');
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
        '<td>' + App.escapeHtml(c.vocabularyId) + '</td>' +
        '<td>' + c.conceptId + '</td>' +
        '<td>' + App.escapeHtml(c.conceptName) + '</td>' +
        '<td>' + App.escapeHtml(c.conceptCode) + '</td>' +
        '<td>' + App.escapeHtml(c.domainId) + '</td>' +
        '<td>' + App.escapeHtml(c.conceptClassId || '') + '</td>' +
        '<td class="td-center">' + App.standardBadge(c) + '</td>' +
        '</tr>';
    }).join('');
    applyColumnVisibility();
    renderPaginationControls('resolved-pagination', 'resolved-page-info', 'resolved-page-buttons', resolvedPage, concepts.length, resolvedPageSize);
  }

  /**
   * Resolve a concept set expression live via DuckDB.
   * Returns a Promise resolving to an array of concept detail objects.
   * Custom concepts (>= CUSTOM_CONCEPT_BASE) are resolved from the expression items.
   */
  function resolveExpressionLive(items) {
    return resolveExpressionViaDuckDB(items).then(function(resolvedIds) {
      if (resolvedIds.size === 0) return [];

      // Separate DB concepts from custom concepts
      var dbIds = [];
      var customIds = new Set();
      resolvedIds.forEach(function(id) {
        if (id >= CUSTOM_CONCEPT_BASE) {
          customIds.add(id);
        } else {
          dbIds.push(id);
        }
      });

      // Build custom concept details from expression items
      var customConcepts = [];
      if (customIds.size > 0 && items) {
        items.forEach(function(it) {
          if (it.concept && customIds.has(it.concept.conceptId)) {
            customConcepts.push({
              conceptId: it.concept.conceptId,
              conceptName: it.concept.conceptName || '',
              vocabularyId: it.concept.vocabularyId || '',
              domainId: it.concept.domainId || '',
              conceptClassId: it.concept.conceptClassId || '',
              conceptCode: it.concept.conceptCode || '',
              standardConcept: it.concept.standardConcept || null
            });
          }
        });
      }

      // Lookup DB concepts
      if (dbIds.length === 0) return customConcepts;
      return VocabDB.lookupConcepts(dbIds).then(function(rows) {
        var dbConcepts = rows.map(function(r) {
          return {
            conceptId: Number(r.concept_id),
            conceptName: r.concept_name || '',
            vocabularyId: r.vocabulary_id || '',
            domainId: r.domain_id || '',
            conceptClassId: r.concept_class_id || '',
            conceptCode: r.concept_code || '',
            standardConcept: r.standard_concept || null
          };
        });
        return dbConcepts.concat(customConcepts).sort(function(a, b) {
          return (a.conceptName || '').localeCompare(b.conceptName || '');
        });
      });
    });
  }

  /**
   * Append non-excluded custom concepts from expression items to a pre-resolved array.
   * Avoids duplicates by checking existing concept IDs.
   */
  function appendCustomConcepts(resolved, items) {
    if (!items || items.length === 0) return resolved;
    var existingIds = new Set(resolved.map(function(r) { return r.conceptId; }));
    var excludedIds = new Set();
    items.forEach(function(it) {
      if (it.isExcluded && it.concept) excludedIds.add(it.concept.conceptId);
    });
    var customs = [];
    items.forEach(function(it) {
      var c = it.concept;
      if (!c || c.conceptId < CUSTOM_CONCEPT_BASE) return;
      if (excludedIds.has(c.conceptId)) return;
      if (existingIds.has(c.conceptId)) return;
      customs.push({
        conceptId: c.conceptId,
        conceptName: c.conceptName || '',
        vocabularyId: c.vocabularyId || '',
        domainId: c.domainId || '',
        conceptClassId: c.conceptClassId || '',
        conceptCode: c.conceptCode || '',
        standardConcept: c.standardConcept || null
      });
    });
    return resolved.concat(customs);
  }

  function renderResolvedTable(keepFilters) {
    if (!selectedConceptSet) return;

    // Use current expression items (edited or saved)
    var items = exprEditMode && exprEditItems
      ? exprEditItems
      : (selectedConceptSet.expression || {}).items || [];

    // If no items, nothing to resolve
    if (items.length === 0) {
      renderResolvedTableWithData([], keepFilters);
      return;
    }

    // If no DuckDB, fall back to pre-resolved data + custom concepts
    if (typeof VocabDB === 'undefined') {
      var preResolved = App.resolvedIndex[selectedConceptSet.id];
      if (preResolved) {
        renderResolvedTableWithData(appendCustomConcepts(preResolved, items), keepFilters);
        return;
      }
      // Deferred: fetch from individual file
      if (App.resolvedDeferred[selectedConceptSet.id]) {
        var tbody = document.getElementById('resolved-tbody');
        var colCount = Object.keys(resolvedColumns).length;
        tbody.innerHTML = '<tr><td colspan="' + colCount + '" class="empty-state"><p><i class="fas fa-spinner fa-spin"></i> ' + App.i18n('Loading resolved concepts...') + '</p></td></tr>';
        App.fetchResolved(selectedConceptSet.id).then(function(concepts) {
          renderResolvedTableWithData(appendCustomConcepts(concepts, items), keepFilters);
        });
        return;
      }
      showResolvedDbUnavailable();
      return;
    }

    // Show loading state
    var tbody = document.getElementById('resolved-tbody');
    var colCount = Object.keys(resolvedColumns).length;
    tbody.innerHTML = '<tr><td colspan="' + colCount + '" class="empty-state"><p><i class="fas fa-spinner fa-spin"></i> ' + App.i18n('Resolving concepts...') + '</p></td></tr>';

    VocabDB.isDatabaseReady().then(function(ready) {
      if (!ready) {
        var preResolved = App.resolvedIndex[selectedConceptSet.id];
        if (preResolved) {
          renderResolvedTableWithData(appendCustomConcepts(preResolved, items), keepFilters);
        } else if (App.resolvedDeferred[selectedConceptSet.id]) {
          App.fetchResolved(selectedConceptSet.id).then(function(concepts) {
            renderResolvedTableWithData(appendCustomConcepts(concepts, items), keepFilters);
          });
        } else {
          // No pre-resolved data — try to remount DB and show loading state
          showResolvedDbLoading();
          VocabDB.remountFromStoredHandles().then(function(ok) {
            if (ok) {
              resolveExpressionLive(items).then(function(concepts) {
                renderResolvedTableWithData(concepts, keepFilters);
              }).catch(function(err) {
                console.error('Live resolve failed:', err);
                renderResolvedTableWithData([], keepFilters);
              });
            } else {
              showResolvedDbUnavailable();
            }
          }).catch(function() {
            showResolvedDbUnavailable();
          });
        }
        return;
      }
      resolveExpressionLive(items).then(function(concepts) {
        renderResolvedTableWithData(concepts, keepFilters);
      }).catch(function(err) {
        console.error('Live resolve failed:', err);
        renderResolvedTableWithData([], keepFilters);
      });
    });
  }

  function showResolvedDbLoading() {
    var tbody = document.getElementById('resolved-tbody');
    var colCount = Object.keys(resolvedColumns).length;
    tbody.innerHTML = '<tr><td colspan="' + colCount + '" class="empty-state"><p><i class="fas fa-spinner fa-spin" style="color:var(--primary); margin-right:6px"></i>' + App.i18n('Loading vocabulary database...') + '</p></td></tr>';
    document.getElementById('cs-concept-count').textContent = '0 / 0';
    renderPaginationControls('resolved-pagination', 'resolved-page-info', 'resolved-page-buttons', 1, 0, resolvedPageSize);
  }

  function showResolvedDbUnavailable() {
    var tbody = document.getElementById('resolved-tbody');
    var colCount = Object.keys(resolvedColumns).length;
    tbody.innerHTML = '<tr><td colspan="' + colCount + '" class="empty-state"><p><i class="fas fa-info-circle" style="color:var(--primary); margin-right:6px"></i>' + App.i18n('Load OHDSI vocabularies in') + ' <a href="#/settings" style="color:var(--primary); font-weight:600">' + App.i18n('Dictionary Settings') + '</a> ' + App.i18n('to resolve concepts.') + '</p></td></tr>';
    document.getElementById('cs-concept-count').textContent = '0 / 0';
    renderPaginationControls('resolved-pagination', 'resolved-page-info', 'resolved-page-buttons', 1, 0, resolvedPageSize);
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

    var copyBtn = function(value) {
      return ' <i class="far fa-clone detail-copy-btn" data-copy="' + App.escapeHtml(String(value)) + '" title="Copy"></i>';
    };

    el.innerHTML = backBtnHtml +
      '<div class="concept-details-container"><div class="concept-details-grid">' +
      '<div class="detail-item"><strong>Concept Name:</strong><span>' + App.escapeHtml(concept.conceptName) + copyBtn(concept.conceptName) + '</span></div>' +
      '<div class="detail-item"><strong>OMOP Concept ID:</strong><span><a href="' + athenaUrl + '" target="_blank">' + concept.conceptId + '</a>' + copyBtn(concept.conceptId) + '</span></div>' +
      '<div class="detail-item"><strong>Vocabulary ID:</strong><span>' + App.escapeHtml(concept.vocabularyId) + '</span></div>' +
      '<div class="detail-item"><strong>FHIR Resource:</strong><span>' + fhirHtml + '</span></div>' +
      '<div class="detail-item"><strong>Concept Code:</strong><span>' + App.escapeHtml(concept.conceptCode) + copyBtn(concept.conceptCode) + '</span></div>' +
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
      'Load OHDSI vocabularies in <a href="#/settings" style="color:var(--primary); font-weight:600">Dictionary Settings</a>' +
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
  var relatedFilterRelationship = '';
  var relatedFilterVocabulary = '';
  var relatedFilterName = '';
  var relatedFilterId = '';

  function loadRelatedConcepts(conceptId, el) {
    relatedEl = el;
    relatedRows = null;
    relatedPage = 0;
    relatedFilterRelationship = '';
    relatedFilterVocabulary = '';
    relatedFilterName = '';
    relatedFilterId = '';

    el.innerHTML = '<div class="loading-inline"><i class="fas fa-spinner fa-spin"></i> Loading...</div>';

    var sql =
      'SELECT cr.relationship_id, c.concept_id, c.concept_name, c.vocabulary_id, ' +
      'c.domain_id, c.concept_class_id, c.concept_code, c.standard_concept ' +
      'FROM concept_relationship cr ' +
      'JOIN concept c ON c.concept_id = cr.concept_id_2 ' +
      'WHERE cr.concept_id_1 = ' + conceptId + ' ' +
      'ORDER BY cr.relationship_id, c.concept_name';

    VocabDB.query(sql).then(function(rows) {
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

  function getFilteredRelatedRows() {
    if (!relatedRows) return [];
    return relatedRows.filter(function(r) {
      if (relatedFilterRelationship && r.relationship_id.toLowerCase().indexOf(relatedFilterRelationship.toLowerCase()) === -1) return false;
      if (relatedFilterVocabulary && r.vocabulary_id.toLowerCase().indexOf(relatedFilterVocabulary.toLowerCase()) === -1) return false;
      if (relatedFilterName && r.concept_name.toLowerCase().indexOf(relatedFilterName.toLowerCase()) === -1) return false;
      if (relatedFilterId && String(r.concept_id).indexOf(relatedFilterId) === -1) return false;
      return true;
    });
  }

  function renderRelatedPage() {
    if (!relatedRows || !relatedEl) return;
    var filtered = getFilteredRelatedRows();
    var total = filtered.length;
    var totalPages = Math.max(1, Math.ceil(total / RELATED_PAGE_SIZE));
    if (relatedPage >= totalPages) relatedPage = totalPages - 1;
    if (relatedPage < 0) relatedPage = 0;
    var start = relatedPage * RELATED_PAGE_SIZE;
    var end = Math.min(start + RELATED_PAGE_SIZE, total);

    // Table with inline column filters
    var html = '<table class="concept-related-table"><thead><tr>' +
      '<th>Relationship</th><th>Vocabulary</th><th>Concept Name</th><th>Concept ID</th>' +
      '</tr><tr class="filter-row">' +
      '<th><input type="text" class="column-filter" id="rel-filter-relationship" placeholder="Filter..." value="' + App.escapeHtml(relatedFilterRelationship) + '"></th>' +
      '<th><input type="text" class="column-filter" id="rel-filter-vocabulary" placeholder="Filter..." value="' + App.escapeHtml(relatedFilterVocabulary) + '"></th>' +
      '<th><input type="text" class="column-filter" id="rel-filter-name" placeholder="Filter..." value="' + App.escapeHtml(relatedFilterName) + '"></th>' +
      '<th><input type="text" class="column-filter" id="rel-filter-id" placeholder="Filter..." value="' + App.escapeHtml(relatedFilterId) + '"></th>' +
      '</tr></thead><tbody>';
    for (var i = start; i < end; i++) {
      var r = filtered[i];
      html += '<tr data-cid="' + r.concept_id + '" title="' +
        App.escapeHtml(r.concept_name) + ' [' + r.vocabulary_id + ']\n' +
        'Domain: ' + (r.domain_id || '') + ' | Class: ' + (r.concept_class_id || '') + '\n' +
        'Code: ' + (r.concept_code || '') + ' | Standard: ' + (r.standard_concept === 'S' ? 'Standard' : r.standard_concept || 'Non-standard') + '">' +
        '<td>' + App.escapeHtml(r.relationship_id) + '</td>' +
        '<td>' + App.escapeHtml(r.vocabulary_id) + '</td>' +
        '<td>' + App.escapeHtml(r.concept_name) + '</td>' +
        '<td>' + r.concept_id + '</td>' +
        '</tr>';
    }
    html += '</tbody></table>';

    // Pager
    if (totalPages > 1) {
      html += '<div class="related-pager">' +
        '<button class="btn-outline-sm" id="rel-prev"' + (relatedPage === 0 ? ' disabled' : '') + '><i class="fas fa-chevron-left"></i></button>' +
        '<span style="font-size:12px; color:var(--text-muted)">' + (start + 1) + '–' + end + ' of ' + total + '</span>' +
        '<button class="btn-outline-sm" id="rel-next"' + (relatedPage >= totalPages - 1 ? ' disabled' : '') + '><i class="fas fa-chevron-right"></i></button>' +
        '</div>';
    }

    relatedEl.innerHTML = html;

    // Filter events
    document.getElementById('rel-filter-relationship').addEventListener('input', function() {
      relatedFilterRelationship = this.value; relatedPage = 0; renderRelatedPage();
    });
    document.getElementById('rel-filter-vocabulary').addEventListener('input', function() {
      relatedFilterVocabulary = this.value; relatedPage = 0; renderRelatedPage();
    });
    document.getElementById('rel-filter-name').addEventListener('input', function() {
      relatedFilterName = this.value; relatedPage = 0; renderRelatedPage();
    });
    document.getElementById('rel-filter-id').addEventListener('input', function() {
      relatedFilterId = this.value; relatedPage = 0; renderRelatedPage();
    });

    // Pager events
    var prevBtn = document.getElementById('rel-prev');
    var nextBtn = document.getElementById('rel-next');
    if (prevBtn) prevBtn.addEventListener('click', function() { relatedPage--; renderRelatedPage(); });
    if (nextBtn) nextBtn.addEventListener('click', function() { relatedPage++; renderRelatedPage(); });

    // Click row to navigate (with history)
    var tbody = relatedEl.querySelector('tbody');
    if (tbody) tbody.addEventListener('click', function(e) {
      var tr = e.target.closest('tr[data-cid]');
      if (!tr) return;
      var cid = parseInt(tr.getAttribute('data-cid'));
      navigateToConceptDetail(cid, currentConceptInDetail);
    });
  }

  var HIERARCHY_WARN_THRESHOLD = 100;

  function showHierarchyLoading() {
    // Show spinner inside existing canvas if wrapper exists, otherwise in the tab el
    if (hierarchyWrapper) {
      var canvas = hierarchyWrapper.querySelector('#hierarchy-graph-canvas');
      if (canvas) canvas.innerHTML = '<div class="loading-inline"><i class="fas fa-spinner fa-spin"></i> Loading hierarchy...</div>';
    }
  }

  function loadHierarchyGraph(conceptId, el) {
    // Don't clear the canvas yet — wait until we know we'll actually load
    if (!hierarchyWrapper) {
      el.innerHTML = '<div class="loading-inline"><i class="fas fa-spinner fa-spin"></i> Loading hierarchy...</div>';
    }

    // Step 1: count nodes using recursive CTE traversal
    var countSql =
      'WITH RECURSIVE anc AS (' +
        'SELECT ancestor_concept_id AS cid, 1 AS d FROM concept_ancestor WHERE descendant_concept_id = ' + conceptId +
        ' UNION ALL ' +
        'SELECT ca.ancestor_concept_id, anc.d + 1 FROM concept_ancestor ca JOIN anc ON ca.descendant_concept_id = anc.cid WHERE anc.d < 20' +
      '), desc_r AS (' +
        'SELECT descendant_concept_id AS cid, 1 AS d FROM concept_ancestor WHERE ancestor_concept_id = ' + conceptId +
        ' UNION ALL ' +
        'SELECT ca.descendant_concept_id, desc_r.d + 1 FROM concept_ancestor ca JOIN desc_r ON ca.ancestor_concept_id = desc_r.cid WHERE desc_r.d < 20' +
      ') SELECT (SELECT COUNT(DISTINCT cid) FROM anc) AS ancestors, (SELECT COUNT(DISTINCT cid) FROM desc_r) AS descendants';

    VocabDB.query(countSql).then(function(countRows) {
      var total = Number(countRows[0].ancestors) + Number(countRows[0].descendants) + 1;
      return total;
    }).then(function(total) {
      if (total > HIERARCHY_WARN_THRESHOLD) {
        var warningHtml =
          '<div class="hierarchy-warn-overlay">' +
            '<div class="hierarchy-warn-box">' +
              '<i class="fas fa-exclamation-triangle" style="color:var(--warning); font-size:18px"></i>' +
              '<div style="margin-top:8px">' +
                'This concept has <strong>' + total + '</strong> nodes in the hierarchy. ' +
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
      showHierarchyLoading();
      buildHierarchyGraph(conceptId, el);
    }).catch(function(err) {
      hierarchyWrapper = null;
      el.innerHTML = '<div class="loading-inline" style="color:var(--danger)">Error: ' + App.escapeHtml(err.message) + '</div>';
    });
  }

  function buildHierarchyGraph(conceptId, el) {
    // Recursive CTE to traverse the full hierarchy via direct edges
    var ancestorsSql =
      'WITH RECURSIVE anc AS (' +
        'SELECT ancestor_concept_id AS cid, 1 AS depth ' +
        'FROM concept_ancestor WHERE descendant_concept_id = ' + conceptId +
        ' UNION ALL ' +
        'SELECT ca.ancestor_concept_id, anc.depth + 1 ' +
        'FROM concept_ancestor ca JOIN anc ON ca.descendant_concept_id = anc.cid ' +
        'WHERE anc.depth < 20' +
      ') SELECT DISTINCT c.concept_id, c.concept_name, c.vocabulary_id, c.domain_id, ' +
      'c.concept_class_id, c.concept_code, c.standard_concept, ' +
      '-MIN(anc.depth) AS hierarchy_level ' +
      'FROM anc JOIN concept c ON c.concept_id = anc.cid ' +
      'GROUP BY c.concept_id, c.concept_name, c.vocabulary_id, c.domain_id, ' +
      'c.concept_class_id, c.concept_code, c.standard_concept ' +
      'ORDER BY MIN(anc.depth)';

    var descendantsSql =
      'WITH RECURSIVE desc_r AS (' +
        'SELECT descendant_concept_id AS cid, 1 AS depth ' +
        'FROM concept_ancestor WHERE ancestor_concept_id = ' + conceptId +
        ' UNION ALL ' +
        'SELECT ca.descendant_concept_id, desc_r.depth + 1 ' +
        'FROM concept_ancestor ca JOIN desc_r ON ca.ancestor_concept_id = desc_r.cid ' +
        'WHERE desc_r.depth < 20' +
      ') SELECT DISTINCT c.concept_id, c.concept_name, c.vocabulary_id, c.domain_id, ' +
      'c.concept_class_id, c.concept_code, c.standard_concept, ' +
      'MIN(desc_r.depth) AS hierarchy_level ' +
      'FROM desc_r JOIN concept c ON c.concept_id = desc_r.cid ' +
      'GROUP BY c.concept_id, c.concept_name, c.vocabulary_id, c.domain_id, ' +
      'c.concept_class_id, c.concept_code, c.standard_concept ' +
      'ORDER BY MIN(desc_r.depth)';

    var selfSql =
      'SELECT concept_id, concept_name, vocabulary_id, domain_id, concept_class_id, concept_code, standard_concept ' +
      'FROM concept WHERE concept_id = ' + conceptId;

    Promise.all([
      VocabDB.query(ancestorsSql),
      VocabDB.query(descendantsSql),
      VocabDB.query(selfSql)
    ]).then(function (results) {
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

        // Get direct parent-child edges between the discovered nodes
        var edgesSql =
          'SELECT ancestor_concept_id AS from_id, descendant_concept_id AS to_id ' +
          'FROM concept_ancestor ' +
          'WHERE ancestor_concept_id IN (' + allIds.join(',') + ') ' +
          'AND descendant_concept_id IN (' + allIds.join(',') + ')';

        return VocabDB.query(edgesSql).then(function(edgeRows) {
          renderHierarchyNetwork(self, ancestors, descendants, edgeRows || [], el);
        });
      })
      .catch(function(err) {
        el.innerHTML = '<div class="loading-inline" style="color:var(--danger)">Error: ' + App.escapeHtml(err.message) + '</div>';
      });
  }

  // Store concept data for custom tooltips
  var hierarchyConceptMap = {};
  // When set, a tooltip is "pinned" (opened via click) and hover tooltips are suppressed.
  var hierarchyPinnedId = null;

  function copyToClipboard(text, btnEl) {
    navigator.clipboard.writeText(text).then(function() {
      var icon = btnEl.querySelector('i');
      if (icon) { icon.className = 'fas fa-check'; icon.style.color = 'var(--success)'; setTimeout(function() { icon.className = 'far fa-clone'; icon.style.color = ''; }, 1200); }
    });
  }

  function showHierarchyTooltip(conceptId, canvasEl, domPos, opts) {
    var c = hierarchyConceptMap[conceptId];
    if (!c) return;
    // If a tooltip is already pinned, hover-triggered tooltips are suppressed.
    var pinning = opts && opts.pin;
    if (hierarchyPinnedId !== null && !pinning) return;
    hideHierarchyTooltip();

    var std = c.standard_concept === 'S' ? 'Standard' : (c.standard_concept === 'C' ? 'Classification' : 'Non-standard');
    var tip = document.createElement('div');
    tip.className = 'hierarchy-tooltip';
    var copyBtn = function(val) {
      return '<td class="ht-action"><button class="ht-copy" data-copy="' + App.escapeHtml(String(val)) + '" title="Copy"><i class="far fa-clone"></i></button></td>';
    };
    var showSearch = opts && opts.showSearch;
    tip.innerHTML =
      '<table class="hierarchy-tooltip-table">' +
        '<tr><td class="ht-label">Name</td><td class="ht-value"><strong>' + App.escapeHtml(String(c.concept_name)) + '</strong></td>' + copyBtn(c.concept_name) + '</tr>' +
        '<tr><td class="ht-label">ID</td><td class="ht-value">' + c.concept_id + '</td>' + copyBtn(c.concept_id) + '</tr>' +
        '<tr><td class="ht-label">Code</td><td class="ht-value">' + App.escapeHtml(String(c.concept_code || '')) + '</td>' + copyBtn(c.concept_code || '') + '</tr>' +
        '<tr><td class="ht-label">Vocabulary</td><td class="ht-value">' + App.escapeHtml(String(c.vocabulary_id)) + '</td><td></td></tr>' +
        '<tr><td class="ht-label">Domain</td><td class="ht-value">' + App.escapeHtml(String(c.domain_id || '')) + '</td><td></td></tr>' +
        '<tr><td class="ht-label">Class</td><td class="ht-value">' + App.escapeHtml(String(c.concept_class_id || '')) + '</td><td></td></tr>' +
        '<tr><td class="ht-label">Standard</td><td class="ht-value">' + std + '</td><td></td></tr>' +
      '</table>' +
      (showSearch
        ? '<div class="ht-search-row"><button class="ht-search-btn" data-cid="' + c.concept_id + '" data-vocab="' + App.escapeHtml(String(c.vocabulary_id || '')) + '"><i class="fas fa-search"></i> Search this concept</button></div>'
        : '');

    // Attach to body in fixed position so the tooltip is never clipped by the
    // hierarchy container's overflow:hidden.
    var canvasRect = canvasEl.getBoundingClientRect();
    var viewportX = canvasRect.left + domPos.x;
    var viewportY = canvasRect.top + domPos.y;
    tip.style.left = (viewportX + 12) + 'px';
    tip.style.top = (viewportY + 12) + 'px';
    document.body.appendChild(tip);

    // Adjust against the viewport if the tooltip overflows
    var tipRect = tip.getBoundingClientRect();
    var vw = window.innerWidth;
    var vh = window.innerHeight;
    if (tipRect.right > vw - 10) tip.style.left = Math.max(10, viewportX - tipRect.width - 12) + 'px';
    if (tipRect.bottom > vh - 10) tip.style.top = Math.max(10, viewportY - tipRect.height - 12) + 'px';

    // Copy button events
    tip.querySelectorAll('.ht-copy').forEach(function(btn) {
      btn.addEventListener('click', function(e) {
        e.stopPropagation();
        copyToClipboard(btn.getAttribute('data-copy'), btn);
      });
    });

    // Search-this-concept button: reset add-modal filters (keep only vocabulary),
    // put the concept ID in the search bar, and run the search.
    var searchBtn = tip.querySelector('.ht-search-btn');
    if (searchBtn) {
      searchBtn.addEventListener('click', function(e) {
        e.stopPropagation();
        var cid = searchBtn.getAttribute('data-cid');
        var vocab = searchBtn.getAttribute('data-vocab') || '';
        // Reset pre-query filters
        addFilterVocab.clear();
        if (vocab) addFilterVocab.add(vocab);
        addFilterDomain.clear();
        addFilterClass.clear();
        addFilterStandard.clear();
        addFilterValid = true;
        var validCb = document.getElementById('expr-add-filter-valid');
        if (validCb) validCb.checked = true;
        ['expr-add-filter-vocab', 'expr-add-filter-domain', 'expr-add-filter-class', 'expr-add-filter-standard'].forEach(function(id) {
          var container = document.getElementById(id);
          if (!container) return;
          var targetSet = id === 'expr-add-filter-vocab' ? addFilterVocab
            : id === 'expr-add-filter-domain' ? addFilterDomain
            : id === 'expr-add-filter-class' ? addFilterClass
            : addFilterStandard;
          container.querySelectorAll('.ms-option input[type="checkbox"]').forEach(function(cb) {
            var v = cb.getAttribute('data-value') || cb.value || '';
            cb.checked = targetSet.has(v);
          });
        });
        if (App.updateMsToggleLabel) {
          App.updateMsToggleLabel('expr-add-filter-vocab', addFilterVocab);
          App.updateMsToggleLabel('expr-add-filter-domain', addFilterDomain);
          App.updateMsToggleLabel('expr-add-filter-class', addFilterClass);
          App.updateMsToggleLabel('expr-add-filter-standard', addFilterStandard, getStandardLabelMap());
        }
        // Clear column filters
        ['expr-add-cf-id','expr-add-cf-name','expr-add-cf-vocab','expr-add-cf-code','expr-add-cf-domain','expr-add-cf-class','expr-add-cf-standard'].forEach(function(id) {
          var inp = document.getElementById(id);
          if (inp) inp.value = '';
        });
        // Put concept ID in the search bar and run search
        var searchInput = document.getElementById('expr-add-search');
        if (searchInput) searchInput.value = cid;
        renderAddActiveFilters();
        hideHierarchyTooltip();
        searchAddConcepts();
      });
    }

    tip._hideTimeout = null;
    tip.addEventListener('mouseenter', function() { clearTimeout(tip._hideTimeout); });
    tip.addEventListener('mouseleave', function() {
      // Pinned tooltips stay open until explicitly dismissed
      if (hierarchyPinnedId !== null) return;
      hideHierarchyTooltip();
    });

    if (pinning) {
      hierarchyPinnedId = Number(conceptId);
      tip.classList.add('pinned');
    }
  }

  function unpinHierarchyTooltip() {
    hierarchyPinnedId = null;
    hideHierarchyTooltip();
  }

  function hideHierarchyTooltip() {
    var existing = document.querySelectorAll('.hierarchy-tooltip');
    existing.forEach(function(el) { el.remove(); });
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
          '<span class="hierarchy-id">#' + selfId + ' · ' + App.escapeHtml(self.vocabulary_id) + '</span>';
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
            '<span class="hierarchy-id">#' + selfId + ' · ' + App.escapeHtml(self.vocabulary_id) + '</span>' +
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

    // Build concept map for tooltips
    hierarchyConceptMap = {};
    hierarchyConceptMap[selfId] = self;
    ancestors.forEach(function(a) { hierarchyConceptMap[Number(a.concept_id)] = a; });
    descendants.forEach(function(d) { hierarchyConceptMap[Number(d.concept_id)] = d; });

    // Build nodes & edges
    var nodes = [];
    var edges = [];

    nodes.push({
      id: selfId,
      label: self.concept_name + '\n[' + self.vocabulary_id + ']',
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
        tooltipDelay: 0,
        navigationButtons: false
      },
      edges: {
        color: { color: '#ccc', hover: '#999' },
        smooth: { type: 'cubicBezier', roundness: 0.5 }
      }
    };

    if (vocabTabsHierarchyNetwork) vocabTabsHierarchyNetwork.destroy();
    vocabTabsHierarchyNetwork = new vis.Network(canvasEl, data, options);

    // Custom tooltip on hover
    var tooltipShowTimeout = null;
    var tooltipHideTimeout = null;
    vocabTabsHierarchyNetwork.on('hoverNode', function(params) {
      if (hierarchyPinnedId !== null) return;
      clearTimeout(tooltipShowTimeout);
      clearTimeout(tooltipHideTimeout);
      var domPos = params.pointer && params.pointer.DOM ? params.pointer.DOM : { x: 0, y: 0 };
      tooltipShowTimeout = setTimeout(function() {
        if (hierarchyPinnedId !== null) return;
        showHierarchyTooltip(params.node, canvasEl, domPos);
      }, 300);
    });
    vocabTabsHierarchyNetwork.on('blurNode', function() {
      if (hierarchyPinnedId !== null) return;
      clearTimeout(tooltipShowTimeout);
      clearTimeout(tooltipHideTimeout);
      tooltipHideTimeout = setTimeout(function() {
        if (hierarchyPinnedId !== null) return;
        if (!document.querySelector('.hierarchy-tooltip:hover')) hideHierarchyTooltip();
      }, 200);
    });
    vocabTabsHierarchyNetwork.on('click', function(params) {
      clearTimeout(tooltipShowTimeout);
      clearTimeout(tooltipHideTimeout);
      if (params.nodes && params.nodes.length === 1) {
        var nodeId = Number(params.nodes[0]);
        if (hierarchyPinnedId === nodeId) {
          unpinHierarchyTooltip();
          vocabTabsHierarchyNetwork.unselectAll();
          return;
        }
        var domPos = params.pointer && params.pointer.DOM ? params.pointer.DOM : { x: 0, y: 0 };
        hierarchyPinnedId = null;
        showHierarchyTooltip(nodeId, canvasEl, domPos, { pin: true });
      } else {
        unpinHierarchyTooltip();
        vocabTabsHierarchyNetwork.unselectAll();
      }
    });

    // Double-click on node: navigate hierarchy in-place
    vocabTabsHierarchyNetwork.on('doubleClick', function(params) {
      if (params.nodes.length === 1) {
        var cid = params.nodes[0];
        if (cid === selfId) return;
        unpinHierarchyTooltip();
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
          var synName = decodeEscapedUtf8(r.concept_synonym_name || '');
          html += '<tr><td>' + App.escapeHtml(synName) + '</td>' +
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
      el.innerHTML = '<div class="empty-state"><p>' + App.i18n('No description available for this concept set.') + '</p></div>';
      return;
    }
    var content = longDesc || desc;
    el.innerHTML = App.renderMarkdown(content);
  }

  function renderStatisticsTab(cs) {
    var el = document.getElementById('cs-statistics-body');
    var profileWrap = document.getElementById('cs-stats-profile-select-wrap');
    var profileSelect = document.getElementById('cs-stats-profile-select');
    var stats = cs.metadata && cs.metadata.distributionStats;
    if (!stats || typeof stats !== 'object' || !stats.profiles || !stats.profiles.length) {
      profileWrap.style.display = 'none';
      el.innerHTML = '<div class="empty-state">' +
        '<i class="fas fa-chart-bar" style="font-size:32px; color:var(--gray-300); display:block; margin-bottom:12px"></i>' +
        '<p>' + App.i18n('No distribution statistics available for this concept set.') + '</p>' +
        '<p style="font-size:12px; margin-top:8px; color:var(--text-muted)">' + App.i18n('Click <strong>Edit</strong> to add statistics, or compute them via the INDICATE Data Dictionary application.') + '</p>' +
        '</div>';
      return;
    }
    // Build profile selector
    var lang = App.lang || 'en';
    var profileNames = stats.profiles.map(function(p) { return p['name_' + lang] || p.name_en || 'Unnamed'; });
    var defaultProfile = stats['default_profile_' + lang] || stats.default_profile_en || profileNames[0];
    if (!statsCurrentProfile || profileNames.indexOf(statsCurrentProfile) < 0) statsCurrentProfile = defaultProfile;
    if (profileNames.length > 1) {
      profileWrap.style.display = '';
      profileSelect.innerHTML = profileNames.map(function(n) {
        return '<option value="' + App.escapeHtml(n) + '"' + (n === statsCurrentProfile ? ' selected' : '') + '>' + App.escapeHtml(n) + '</option>';
      }).join('');
    } else {
      profileWrap.style.display = 'none';
    }
    // Find selected profile
    var profileIdx = profileNames.indexOf(statsCurrentProfile);
    if (profileIdx < 0) profileIdx = 0;
    var profile = stats.profiles[profileIdx];
    el.innerHTML = renderStatsProfileView(profile, lang);
  }

  function renderStatsProfileView(profile, lang) {
    if (!profile) return '<div class="empty-state"><p>No profile data</p></div>';
    var html = '';
    var descKey = 'description_' + lang;
    var desc = profile[descKey] || profile.description_en || '';
    if (desc) html += '<p style="color:var(--text-muted); margin-bottom:12px; font-size:13px">' + App.escapeHtml(desc) + '</p>';

    // Data types
    var types = profile.data_types || [];
    if (types.length) {
      html += '<div style="margin-bottom:8px">';
      types.forEach(function(t) {
        html += '<span class="badge badge-count" style="margin-right:4px">' + App.escapeHtml(t) + '</span>';
      });
      html += '</div>';
    }

    // Measurement frequency
    var freq = profile.measurement_frequency && profile.measurement_frequency.typical_interval;
    if (freq) html += '<div style="font-size:13px; margin-bottom:12px; color:var(--text-muted)"><i class="fas fa-clock" style="margin-right:4px"></i> Typical interval: <strong>' + App.escapeHtml(freq) + '</strong></div>';

    // Missing rate
    if (profile.missing_rate != null) {
      html += '<div style="font-size:13px; margin-bottom:12px; color:var(--text-muted)"><i class="fas fa-exclamation-triangle" style="margin-right:4px"></i> Missing rate: <strong>' + profile.missing_rate + '%</strong></div>';
    }

    // Numeric data
    var nd = profile.numeric_data;
    if (nd && (nd.mean != null || nd.median != null || nd.min != null)) {
      html += '<h4 style="font-size:13px; font-weight:600; color:var(--text-muted); text-transform:uppercase; letter-spacing:.5px; margin:16px 0 8px">Numeric Summary</h4>';
      html += '<table class="stats-summary-table"><tbody>';
      var rows = [
        ['Min', nd.min], ['P5', nd.p5], ['P25 (Q1)', nd.p25], ['Median', nd.median],
        ['Mean', nd.mean], ['P75 (Q3)', nd.p75], ['P95', nd.p95], ['Max', nd.max],
        ['SD', nd.sd], ['CV', nd.cv != null ? nd.cv + '%' : null]
      ];
      rows.forEach(function(r) {
        if (r[1] != null) html += '<tr><td style="font-weight:600; color:var(--text-muted); padding:3px 12px 3px 0; font-size:13px">' + r[0] + '</td><td style="font-size:13px; padding:3px 0">' + r[1] + '</td></tr>';
      });
      html += '</tbody></table>';
    }

    // Histogram
    var hist = profile.histogram;
    if (hist && hist.length > 0) {
      html += '<h4 style="font-size:13px; font-weight:600; color:var(--text-muted); text-transform:uppercase; letter-spacing:.5px; margin:16px 0 8px">Distribution</h4>';
      var maxCount = Math.max.apply(null, hist.map(function(h) { return h.count || 0; }));
      html += '<div class="stats-histogram">';
      hist.forEach(function(h) {
        var pct = maxCount > 0 ? ((h.count / maxCount) * 100) : 0;
        html += '<div class="stats-hist-row">' +
          '<span class="stats-hist-label">' + (h.x != null ? h.x : '') + '</span>' +
          '<div class="stats-hist-bar-wrap"><div class="stats-hist-bar" style="width:' + pct + '%"></div></div>' +
          '<span class="stats-hist-count">' + (h.count || 0).toLocaleString() + '</span>' +
          '</div>';
      });
      html += '</div>';
    }

    // Categorical data
    var cat = profile.categorical_data;
    if (cat && cat.length > 0) {
      html += '<h4 style="font-size:13px; font-weight:600; color:var(--text-muted); text-transform:uppercase; letter-spacing:.5px; margin:16px 0 8px">Categories</h4>';
      var maxCatPct = Math.max.apply(null, cat.map(function(c) { return c.percent || 0; }));
      html += '<div class="stats-histogram">';
      cat.forEach(function(c) {
        var barW = maxCatPct > 0 ? ((c.percent / maxCatPct) * 100) : 0;
        html += '<div class="stats-hist-row">' +
          '<span class="stats-hist-label" title="' + App.escapeHtml(c.value || '') + '">' + App.escapeHtml(App.truncate(c.value || '', 30)) + '</span>' +
          '<div class="stats-hist-bar-wrap"><div class="stats-hist-bar stats-hist-bar-cat" style="width:' + barW + '%"></div></div>' +
          '<span class="stats-hist-count">' + (c.percent != null ? c.percent + '%' : '') + ' (' + (c.count || 0).toLocaleString() + ')</span>' +
          '</div>';
      });
      html += '</div>';
    }

    if (!html) html = '<div class="empty-state"><p>No statistics data in this profile.</p></div>';
    return html;
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

    var titleName = tr.name || cs.name;
    var titleEl = document.getElementById('cs-detail-title');
    titleEl.querySelector('.title-tooltip-text').textContent = titleName;
    titleEl.querySelector('.title-tooltip-bubble').textContent = titleName;
    refreshDetailBadges();

    // Show Edit button for all concept sets
    document.getElementById('cs-edit-btn').style.display = '';
    document.getElementById('cs-edit-cancel-btn').style.display = 'none';
    document.getElementById('cs-edit-save-btn').style.display = 'none';

    // Reset edit containers to view mode
    document.getElementById('cs-comments-view').style.display = '';
    document.getElementById('cs-comments-edit').style.display = 'none';
    document.getElementById('cs-statistics-view').style.display = '';
    document.getElementById('cs-statistics-edit').style.display = 'none';
    statsCurrentProfile = null;

    switchCSDetailTab('concepts');
    switchConceptMode('resolved');
    updateViewJsonLink();

    renderCommentsTab(cs);
    renderStatisticsTab(cs);
    renderReviewTab(cs);
  }

  function hideCSDetail() {
    if (exprEditMode) exitExprEditMode();
    if (commentsEditMode) exitCommentsEditMode();
    if (statsEditMode) exitStatsEditMode();
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
      App.showToast(App.i18n('Please set up your profile first (click on "Guest" in the header).'), 'warning');
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
      App.showToast(App.i18n('Please select a review status.'), 'error');
      return;
    }
    var comments = reviewAceEditor ? reviewAceEditor.getValue().trim() : '';
    if (!comments) {
      App.showToast(App.i18n('Review comments are required.'), 'error');
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
    App.showToast(App.i18n('Review submitted! Use "Propose on GitHub" to submit a pull request.'), 'success', 5000);
  }

  // ==================== GITHUB PROPOSE ====================
  function proposeOnGitHub() {
    if (!selectedConceptSet) return;
    var json = buildIndicateJSON();
    navigator.clipboard.writeText(json).then(function() {
      App.showToast(App.i18n('JSON copied to clipboard! Paste it in the GitHub editor.'), 'success', 5000);
    }).catch(function() {});
    var url = 'https://github.com/' + GITHUB_REPO + '/edit/main/concept_sets/' + selectedConceptSet.id + '.json';
    window.open(url, '_blank');
  }

  // ==================== JSON EXPORT ====================
  // ==================== VERSION MODAL ====================
  function suggestNextVersion(version) {
    var parts = (version || '1.0.0').split('.');
    if (parts.length === 3) {
      var patch = parseInt(parts[2]) + 1;
      return parts[0] + '.' + parts[1] + '.' + (isNaN(patch) ? 1 : patch);
    }
    return version || '1.0.1';
  }

  function renderVersionHistory() {
    var cs = selectedConceptSet;
    if (!cs) return;
    var versions = (cs.metadata && cs.metadata.versions) || [];
    var container = document.getElementById('cs-version-history');
    var body = document.getElementById('cs-version-history-body');
    if (versions.length === 0) {
      container.style.display = 'none';
      return;
    }
    container.style.display = '';
    var rows = versions.slice().reverse().map(function(v) {
      return '<tr>' +
        '<td style="white-space:nowrap; font-weight:600">v' + App.escapeHtml(v.version || '') + '</td>' +
        '<td>' + App.escapeHtml(v.summary || '') + '</td>' +
        '<td style="white-space:nowrap; color:var(--text-muted); font-size:12px">' + App.escapeHtml(v.date || '') + '</td>' +
        '</tr>';
    }).join('');
    body.innerHTML = '<table class="data-table" style="width:100%; font-size:13px"><thead><tr><th>Version</th><th>Summary</th><th>Date</th></tr></thead><tbody>' + rows + '</tbody></table>';
  }

  function openVersionModal() {
    if (!selectedConceptSet) return;
    document.getElementById('cs-version-input').value = suggestNextVersion(selectedConceptSet.version);
    document.getElementById('cs-version-summary').value = '';
    renderVersionHistory();
    document.getElementById('cs-version-modal').style.display = 'flex';
    document.getElementById('cs-version-input').focus();
  }

  function closeVersionModal() {
    document.getElementById('cs-version-modal').style.display = 'none';
  }

  function saveVersion() {
    if (!selectedConceptSet) return;
    var newVersion = document.getElementById('cs-version-input').value.trim();
    if (!newVersion) {
      App.showToast(App.i18n('Please enter a version number'), 'error');
      return;
    }
    var summary = document.getElementById('cs-version-summary').value.trim();
    var oldVersion = selectedConceptSet.version || '1.0.0';

    // Add to version history
    if (!selectedConceptSet.metadata) selectedConceptSet.metadata = {};
    if (!selectedConceptSet.metadata.versions) selectedConceptSet.metadata.versions = [];
    selectedConceptSet.metadata.versions.push({
      version: newVersion,
      versionFrom: oldVersion,
      summary: summary,
      changedBy: (App.getUserProfile() || {}).firstName || '',
      date: new Date().toISOString().slice(0, 10)
    });

    selectedConceptSet.version = newVersion;
    selectedConceptSet.modifiedDate = new Date().toISOString().slice(0, 10);
    App.updateConceptSet(selectedConceptSet);
    refreshDetailBadges();
    closeVersionModal();
    App.showToast(App.i18n('Version updated to v') + newVersion);
  }

  // ==================== STATUS MODAL ====================
  function openStatusModal() {
    if (!selectedConceptSet) return;
    var meta = selectedConceptSet.metadata || {};
    document.getElementById('cs-status-select').value = meta.reviewStatus || 'draft';
    document.getElementById('cs-status-modal').style.display = 'flex';
  }

  function closeStatusModal() {
    document.getElementById('cs-status-modal').style.display = 'none';
  }

  function saveStatus() {
    if (!selectedConceptSet) return;
    var newStatus = document.getElementById('cs-status-select').value;
    if (!selectedConceptSet.metadata) selectedConceptSet.metadata = {};
    selectedConceptSet.metadata.reviewStatus = newStatus;
    selectedConceptSet.modifiedDate = new Date().toISOString().slice(0, 10);
    App.updateConceptSet(selectedConceptSet);
    refreshDetailBadges();
    closeStatusModal();
    App.showToast(App.i18n('Status changed to ') + App.statusLabel(newStatus));
  }

  function refreshDetailBadges() {
    if (!selectedConceptSet) return;
    var cs = selectedConceptSet;
    var meta = cs.metadata || {};
    var status = meta.reviewStatus || 'draft';
    var statusClass = status.replace(/\s+/g, '_').toLowerCase();
    var statusLabel = App.statusLabel(status);

    document.getElementById('cs-detail-badges').innerHTML =
      '<span class="version-badge" id="cs-badge-version">v' + App.escapeHtml(cs.version || '1.0.0') + '</span>' +
      '<span class="status-badge ' + statusClass + '" id="cs-badge-status">' + App.escapeHtml(statusLabel) + '</span>';
    document.getElementById('cs-badge-version').addEventListener('click', openVersionModal);
    document.getElementById('cs-badge-status').addEventListener('click', openStatusModal);
    // Also refresh the table row if visible
    renderAll();
  }

  // ==================== EXPORT MODAL ====================
  var exportMethod = null;

  var exportPreviewEditor = null;

  function openExportModal() {
    if (!selectedConceptSet) return;
    exportMethod = null;
    var modal = document.querySelector('#cs-export-modal .modal');
    modal.classList.remove('export-preview-mode');
    document.getElementById('export-step-method').style.display = '';
    document.getElementById('export-step-format').style.display = 'none';
    document.getElementById('export-step-preview').style.display = 'none';
    document.getElementById('cs-export-back').style.display = 'none';
    document.getElementById('cs-export-modal').style.display = 'flex';
  }

  function closeExportModal() {
    document.getElementById('cs-export-modal').style.display = 'none';
    var modal = document.querySelector('#cs-export-modal .modal');
    modal.classList.remove('export-preview-mode');
  }

  function showExportPreview(content, aceMode) {
    document.getElementById('export-step-method').style.display = 'none';
    document.getElementById('export-step-format').style.display = 'none';
    document.getElementById('export-step-preview').style.display = '';
    document.getElementById('cs-export-back').style.display = 'none';
    var modal = document.querySelector('#cs-export-modal .modal');
    modal.classList.add('export-preview-mode');

    if (!exportPreviewEditor) {
      exportPreviewEditor = ace.edit('export-preview-ace');
      exportPreviewEditor.setTheme('ace/theme/chrome');
      exportPreviewEditor.setFontSize(13);
      exportPreviewEditor.setShowPrintMargin(false);
      exportPreviewEditor.setReadOnly(true);
      exportPreviewEditor.renderer.setShowGutter(true);
      exportPreviewEditor.session.setUseWrapMode(true);
    }
    exportPreviewEditor.session.setMode('ace/mode/' + aceMode);
    exportPreviewEditor.setValue(content, -1);
    exportPreviewEditor.resize();
  }

  function exportStepMethod(method) {
    if (method === 'github') {
      // GitHub always uses INDICATE JSON — skip format step
      if (!selectedConceptSet) return;
      var json = buildIndicateJSON();
      navigator.clipboard.writeText(json).then(function() {
        App.showToast(App.i18n('JSON copied to clipboard! Paste it in the GitHub editor.'), 'success', 5000);
      }).catch(function() {});
      var url = 'https://github.com/' + GITHUB_REPO + '/edit/main/concept_sets/' + selectedConceptSet.id + '.json';
      window.open(url, '_blank');
      closeExportModal();
      return;
    }
    if (method === 'sql') {
      if (!selectedConceptSet) return;
      var sql = buildOMOPSQL();
      navigator.clipboard.writeText(sql).then(function() {
        showExportPreview(sql, 'sql');
      }).catch(function() {
        App.showToast(App.i18n('Could not copy to clipboard.'), 'error');
      });
      return;
    }
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
    cs.createdByTool = App.APP_NAME + ' v' + App.APP_VERSION;
    cs.modifiedDate = new Date().toISOString().slice(0, 10);
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

  // ==================== OMOP SQL EXPORT ====================
  var DOMAIN_TABLE_MAP = {
    'Measurement': {
      table: 'measurement',
      conceptCol: 'measurement_concept_id',
      columns: ['person_id', 'measurement_concept_id', 'measurement_date', 'measurement_datetime',
        'value_as_number', 'value_as_concept_id', 'unit_concept_id',
        'measurement_source_value', 'measurement_source_concept_id', 'unit_source_value']
    },
    'Condition': {
      table: 'condition_occurrence',
      conceptCol: 'condition_concept_id',
      columns: ['person_id', 'condition_concept_id', 'condition_start_date', 'condition_start_datetime',
        'condition_end_date', 'condition_end_datetime', 'condition_type_concept_id',
        'condition_source_value', 'condition_source_concept_id']
    },
    'Drug': {
      table: 'drug_exposure',
      conceptCol: 'drug_concept_id',
      columns: ['person_id', 'drug_concept_id', 'drug_exposure_start_date', 'drug_exposure_start_datetime',
        'drug_exposure_end_date', 'drug_exposure_end_datetime', 'drug_type_concept_id',
        'quantity', 'dose_unit_source_value', 'drug_source_value', 'drug_source_concept_id']
    },
    'Procedure': {
      table: 'procedure_occurrence',
      conceptCol: 'procedure_concept_id',
      columns: ['person_id', 'procedure_concept_id', 'procedure_date', 'procedure_datetime',
        'procedure_type_concept_id', 'procedure_source_value', 'procedure_source_concept_id']
    },
    'Observation': {
      table: 'observation',
      conceptCol: 'observation_concept_id',
      columns: ['person_id', 'observation_concept_id', 'observation_date', 'observation_datetime',
        'value_as_number', 'value_as_string', 'value_as_concept_id', 'unit_concept_id',
        'observation_source_value', 'observation_source_concept_id']
    },
    'Device': {
      table: 'device_exposure',
      conceptCol: 'device_concept_id',
      columns: ['person_id', 'device_concept_id', 'device_exposure_start_date', 'device_exposure_start_datetime',
        'device_exposure_end_date', 'device_exposure_end_datetime', 'device_type_concept_id',
        'device_source_value', 'device_source_concept_id']
    }
  };

  function buildOMOPSQL() {
    var cs = selectedConceptSet;
    var tr = App.t(cs);
    var csName = tr.name || cs.name || 'Concept Set';
    var resolved = App.resolvedIndex[cs.id] || [];
    // Filter to standard concepts only
    var concepts = resolved.filter(function(c) { return c.standardConcept === 'S'; });

    if (concepts.length === 0) {
      return '-- Concept Set: ' + csName + ' (ID: ' + cs.id + ')\n' +
        '-- No standard resolved concepts available.\n' +
        '-- Load an OHDSI vocabulary database or ensure concept sets are resolved.\n';
    }

    // Group by domain
    var byDomain = {};
    concepts.forEach(function(c) {
      var d = c.domainId || 'Unknown';
      if (!byDomain[d]) byDomain[d] = [];
      byDomain[d].push(c);
    });

    // Build recommended unit index: conceptId -> recommendedUnitConceptId
    var ruIndex = {};
    App.recommendedUnits.forEach(function(ru) {
      ruIndex[ru.conceptId] = ru.recommendedUnitConceptId;
    });

    // Build conversion index: for each resolved concept, find conversions
    // Key: unitConceptId (source) -> { factor, targetUnitConceptId }
    function getConversionsForConcepts(domainConcepts) {
      var conceptIds = {};
      domainConcepts.forEach(function(c) { conceptIds[c.conceptId] = true; });

      // Find the recommended unit for these concepts (pick the most common one)
      var recUnitCounts = {};
      domainConcepts.forEach(function(c) {
        var ru = ruIndex[c.conceptId];
        if (ru) {
          recUnitCounts[ru] = (recUnitCounts[ru] || 0) + 1;
        }
      });

      // Group concepts by their recommended unit
      var groups = {}; // recUnitId -> { concepts: [], conversions: { sourceUnitId -> factor } }
      domainConcepts.forEach(function(c) {
        var ru = ruIndex[c.conceptId];
        var key = ru || 'none';
        if (!groups[key]) groups[key] = { recUnitId: ru, concepts: [], conversions: {} };
        groups[key].concepts.push(c);
      });

      // Find conversions for each group
      App.unitConversions.forEach(function(conv) {
        // Check if conceptId1 is in our set and has a recommended unit matching conceptId2's unit
        if (conceptIds[conv.conceptId1]) {
          var ru = ruIndex[conv.conceptId1];
          if (ru && conv.unitConceptId2 === ru && groups[ru]) {
            // This conversion goes FROM unitConceptId1 TO the recommended unit
            groups[ru].conversions[conv.unitConceptId1] = conv.conversionFactor;
          }
        }
        // Also check reverse: conceptId2 is in our set
        if (conceptIds[conv.conceptId2]) {
          var ru2 = ruIndex[conv.conceptId2];
          if (ru2 && conv.unitConceptId1 === ru2 && groups[ru2]) {
            // conceptId2 has recommended unit = unitConceptId1, and conv goes FROM unitConceptId2 TO unitConceptId1
            // So the reverse factor would be 1/conversionFactor... but we have the direct entry
            // Actually, we should look for conv where the TARGET is the recommended unit
          }
        }
      });

      return groups;
    }

    var lines = [];
    lines.push('-- ============================================================');
    lines.push('-- Concept Set: ' + csName + ' (ID: ' + cs.id + ')');
    lines.push('-- Generated by ' + App.APP_NAME + ' v' + App.APP_VERSION);
    lines.push('-- Date: ' + new Date().toISOString().slice(0, 10));
    lines.push('-- ============================================================');
    lines.push('');

    var domainKeys = Object.keys(byDomain).sort();

    domainKeys.forEach(function(domain) {
      var domainConcepts = byDomain[domain];
      var mapping = DOMAIN_TABLE_MAP[domain];

      lines.push('-- ------------------------------------------------------------');
      lines.push('-- Domain: ' + domain + ' (' + domainConcepts.length + ' concepts)');
      lines.push('-- ------------------------------------------------------------');

      if (!mapping) {
        lines.push('-- No OMOP CDM table mapping for domain "' + domain + '".');
        lines.push('-- Concepts:');
        domainConcepts.forEach(function(c) {
          lines.push('--   ' + c.conceptId + ' -- ' + c.conceptName);
        });
        lines.push('');
        return;
      }

      // Build SELECT columns
      var selectCols = mapping.columns.slice(); // copy

      // For Measurement domain, add unit conversion logic
      var unitCaseExpr = null;
      if (domain === 'Measurement') {
        var groups = getConversionsForConcepts(domainConcepts);
        var groupKeys = Object.keys(groups);

        // Check if there are any recommended units
        var hasRecUnit = groupKeys.some(function(k) { return k !== 'none'; });

        if (hasRecUnit) {
          // Build CASE expression for unit conversion
          var caseParts = [];

          groupKeys.forEach(function(key) {
            var g = groups[key];
            if (key === 'none') return;

            var recUnitId = g.recUnitId;
            var conceptList = g.concepts.map(function(c) { return c.conceptId; });

            if (caseParts.length > 0) caseParts.push('');
            caseParts.push('        -- Recommended unit concept_id: ' + recUnitId);
            caseParts.push('        -- Applies to:');
            g.concepts.forEach(function(c) {
              caseParts.push('        --   ' + c.conceptId + ' (' + c.conceptName + ')');
            });
            caseParts.push('        WHEN unit_concept_id = ' + recUnitId + ' THEN value_as_number');

            var sourceUnits = Object.keys(g.conversions);
            sourceUnits.forEach(function(srcUnitId) {
              var factor = g.conversions[srcUnitId];
              caseParts.push('        WHEN unit_concept_id = ' + srcUnitId +
                ' THEN value_as_number * ' + factor +
                ' -- convert unit ' + srcUnitId + ' -> ' + recUnitId);
            });
          });

          // Check if some concepts have no recommended unit
          var noRecUnit = groups['none'];
          if (noRecUnit) {
            if (caseParts.length > 0) caseParts.push('');
            caseParts.push('        -- No recommended unit for:');
            noRecUnit.concepts.forEach(function(c) {
              caseParts.push('        --   ' + c.conceptId + ' (' + c.conceptName + ')');
            });
          }

          if (caseParts.length > 0) {
            unitCaseExpr = '    CASE\n' + caseParts.join('\n') +
              '\n        ELSE NULL -- unknown unit, no conversion available' +
              '\n    END AS value_as_number_converted';
          }
        } else {
          lines.push('-- Note: no recommended units defined for these measurement concepts.');
          lines.push('-- Unit conversion column not included.');
        }
      }

      // Build the query
      lines.push('');
      lines.push('SELECT');
      var colLines = selectCols.map(function(col) { return '    ' + col; });
      if (unitCaseExpr) {
        colLines.push(unitCaseExpr);
      }
      lines.push(colLines.join(',\n'));

      lines.push('FROM ' + mapping.table);
      lines.push('WHERE ' + mapping.conceptCol + ' IN (');

      // Concept list with names as comments
      domainConcepts.forEach(function(c, idx) {
        var prefix = (idx === 0) ? '    ' : '   ,';
        lines.push(prefix + c.conceptId + ' -- ' + c.conceptName);
      });
      lines.push(')');

      lines.push(';');
    });

    return lines.join('\n');
  }

  function executeExport(format) {
    if (!selectedConceptSet || !exportMethod) return;

    var content, filename, mimeType;
    if (format === 'sql') {
      content = buildOMOPSQL();
      filename = selectedConceptSet.id + '.sql';
      mimeType = 'text/plain';
    } else {
      content = (format === 'atlas') ? buildAtlasJSON() : buildIndicateJSON();
      filename = selectedConceptSet.id + '.json';
      mimeType = 'application/json';
    }

    if (exportMethod === 'clipboard') {
      var aceMode = (format === 'sql') ? 'sql' : 'json';
      navigator.clipboard.writeText(content).then(function() {
        showExportPreview(content, aceMode);
      }).catch(function() {
        App.showToast(App.i18n('Could not copy to clipboard. Try downloading the file instead.'), 'error');
      });
      return;
    } else {
      var blob = new Blob([content], { type: mimeType });
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
  var listEditSnapshot = null; // { all, user, hidden }

  function enterListEditMode() {
    if (selectionMode) return;
    listEditSnapshot = {
      all: JSON.parse(JSON.stringify(App.conceptSets)),
      user: JSON.parse(JSON.stringify(App.conceptSets.filter(function(cs) { return App.isUserConceptSet(cs.id); }))),
      hidden: localStorage.getItem('indicate_hidden_cs') || '[]'
    };
    selectionMode = true;
    selectedIds.clear();
    updateListEditToolbar();
    renderCSTable();
  }

  function saveListEdits() {
    listEditSnapshot = null;
    selectionMode = false;
    selectedIds.clear();
    updateListEditToolbar();
    renderAll();
    App.showToast(App.i18n('Changes saved'));
  }

  function cancelListEdits() {
    if (listEditSnapshot) {
      App.restoreConceptSets(listEditSnapshot.all, listEditSnapshot.user);
      localStorage.setItem('indicate_hidden_cs', listEditSnapshot.hidden);
    }
    selectionMode = false;
    selectedIds.clear();
    listEditSnapshot = null;
    updateListEditToolbar();
    renderAll();
  }

  function updateListEditToolbar() {
    var table = document.getElementById('cs-table');
    table.classList.toggle('selection-mode', selectionMode);

    // Edit mode buttons
    document.getElementById('cs-select-all-btn').style.display = selectionMode ? '' : 'none';
    document.getElementById('cs-unselect-all-btn').style.display = selectionMode ? '' : 'none';
    document.getElementById('cs-delete-selected-btn').style.display = selectionMode ? '' : 'none';
    document.getElementById('cs-selection-count').style.display = selectionMode ? '' : 'none';
    document.getElementById('cs-list-cancel-btn').style.display = selectionMode ? '' : 'none';
    document.getElementById('cs-list-save-btn').style.display = selectionMode ? '' : 'none';

    // Normal mode buttons
    document.getElementById('cs-edit-list-btn').style.display = selectionMode ? 'none' : '';
    document.getElementById('cs-export-all-btn').style.display = selectionMode ? 'none' : '';
    // Add Concept Set only visible in edit mode
    document.getElementById('cs-create-btn').style.display = selectionMode ? '' : 'none';
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
      App.showToast(App.i18n('No concept sets selected.'), 'warning');
      return;
    }
    var n = selectedIds.size;
    var msg = App.i18n('Delete ') + n + App.i18n(n > 1 ? ' selected concept sets' : ' selected concept set') + '?';
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
      App.showToast(result.deleted + App.i18n(result.deleted > 1 ? ' concept sets' : ' concept set') + App.i18n(' deleted.'), 'success');
    }
    if (result.skipped > 0) {
      App.showToast(result.skipped + ' ' + App.i18n('repository ') + App.i18n(result.skipped > 1 ? ' concept sets' : ' concept set') + App.i18n(' cannot be deleted.'), 'warning');
    }
  }

  // ==================== BULK EXPORT ====================
  function openBulkExportModal() {
    // Show/hide the "Export Selected" option
    var selectedOption = document.getElementById('cs-bulk-export-selected-option');
    if (selectionMode && selectedIds.size > 0) {
      selectedOption.style.display = '';
      document.getElementById('cs-bulk-export-selected-desc').textContent =
        App.i18n('Download ') + selectedIds.size + App.i18n(selectedIds.size > 1 ? ' selected concept sets' : ' selected concept set');
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
    App.showToast(list.length + App.i18n(list.length > 1 ? ' concept sets' : ' concept set') + App.i18n(' exported.'), 'success');
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
    App.showToast(list.length + App.i18n(list.length > 1 ? ' concept sets' : ' concept set') + App.i18n(' exported.'), 'success');
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

  var csEditingId = null; // null = create mode, number = edit mode

  function openCreateModal() {
    csEditingId = null;
    document.getElementById('cs-create-modal-title').innerHTML = '<i class="fas fa-plus"></i> New Concept Set';
    document.getElementById('cs-create-submit').innerHTML = '<i class="fas fa-plus"></i> Create';
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

  function openEditModal(id) {
    var cs = App.conceptSets.find(function(c) { return c.id === id; });
    if (!cs) return;
    csEditingId = id;
    document.getElementById('cs-create-modal-title').innerHTML = '<i class="fas fa-pen"></i> Edit Concept Set';
    document.getElementById('cs-create-submit').innerHTML = '<i class="fas fa-save"></i> Save';

    buildCategoryMap();
    populateCatDropdown();

    // Pre-fill form
    var tr = cs.metadata && cs.metadata.translations;
    var trEn = (tr && tr.en) || {};
    var trCur = (tr && tr[App.lang]) || trEn;
    document.getElementById('cs-create-name').value = trCur.name || cs.name || '';
    document.getElementById('cs-create-desc').value = cs.description || '';
    document.getElementById('cs-create-cat-new').style.display = 'none';
    document.getElementById('cs-create-cat-new-input').value = '';
    document.getElementById('cs-create-subcat-new').style.display = 'none';
    document.getElementById('cs-create-subcat-new-input').value = '';

    // Select category
    var catEn = (trEn.category || '').trim();
    document.getElementById('cs-create-cat').value = catEn;
    populateSubcatDropdown();

    // Select subcategory
    var subcatEn = (trEn.subcategory || '').trim();
    document.getElementById('cs-create-subcat').value = subcatEn;

    document.getElementById('cs-create-modal').style.display = 'flex';
  }

  function closeCreateModal() {
    document.getElementById('cs-create-modal').style.display = 'none';
  }

  function resolveModalCatSubcat() {
    var catKey = document.getElementById('cs-create-cat').value;
    var catNewInput = document.getElementById('cs-create-cat-new-input').value.trim();
    var catEn, catFr;
    if (catNewInput) {
      catEn = catNewInput; catFr = catNewInput;
    } else if (catKey && createCatMap[catKey]) {
      catEn = createCatMap[catKey].en; catFr = createCatMap[catKey].fr;
    } else {
      catEn = ''; catFr = '';
    }
    var subcatKey = document.getElementById('cs-create-subcat').value;
    var subcatNewInput = document.getElementById('cs-create-subcat-new-input').value.trim();
    var subcatEn, subcatFr;
    if (subcatNewInput) {
      subcatEn = subcatNewInput; subcatFr = subcatNewInput;
    } else if (subcatKey && catKey && createCatMap[catKey] && createCatMap[catKey].subcats[subcatKey]) {
      subcatEn = createCatMap[catKey].subcats[subcatKey].en;
      subcatFr = createCatMap[catKey].subcats[subcatKey].fr;
    } else {
      subcatEn = ''; subcatFr = '';
    }
    return { catEn: catEn, catFr: catFr, subcatEn: subcatEn, subcatFr: subcatFr };
  }

  function submitCreateCS() {
    var name = document.getElementById('cs-create-name').value.trim();
    var desc = document.getElementById('cs-create-desc').value.trim();
    var r = resolveModalCatSubcat();

    if (!name) { App.showToast(App.i18n('Name is required.'), 'error'); return; }
    if (!r.catEn) { App.showToast(App.i18n('Category is required.'), 'error'); return; }

    // Edit mode
    if (csEditingId != null) {
      var cs = App.conceptSets.find(function(c) { return c.id === csEditingId; });
      if (!cs) return;
      cs.description = desc || null;
      cs.modifiedDate = new Date().toISOString().split('T')[0];
      if (!cs.metadata) cs.metadata = {};
      if (!cs.metadata.translations) cs.metadata.translations = {};
      if (!cs.metadata.translations.en) cs.metadata.translations.en = {};
      if (!cs.metadata.translations.fr) cs.metadata.translations.fr = {};
      if (App.lang === 'fr') {
        cs.metadata.translations.fr.name = name;
        cs.metadata.translations.en.name = cs.metadata.translations.en.name || name;
      } else {
        cs.metadata.translations.en.name = name;
        cs.metadata.translations.fr.name = cs.metadata.translations.fr.name || name;
      }
      cs.name = cs.metadata.translations.en.name;
      cs.metadata.translations.en.category = r.catEn;
      cs.metadata.translations.en.subcategory = r.subcatEn;
      cs.metadata.translations.fr.category = r.catFr;
      cs.metadata.translations.fr.subcategory = r.subcatFr;
      App.updateConceptSet(cs);
      closeCreateModal();
      renderAll();
      App.showToast(App.i18n('Concept set updated.'), 'success');
      return;
    }

    // Create mode
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
      createdByTool: App.APP_NAME + ' v' + App.APP_VERSION,
      expression: { items: [] },
      tags: [],
      metadata: {
        uniqueId: crypto.randomUUID(),
        organization: App.getOrganization() || { name: 'INDICATE Consortium', url: 'https://indicate-eu.org' },
        reviewStatus: 'draft',
        origin: null,
        translations: {
          en: { name: name, category: r.catEn, subcategory: r.subcatEn },
          fr: { name: name, category: r.catFr, subcategory: r.subcatFr }
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
    App.showToast(App.i18n('Concept set created.'), 'success');
  }

  // ==================== EVENTS ====================
  function initEvents() {
    // Copy buttons in concept detail panels
    document.addEventListener('click', function(e) {
      var btn = e.target.closest('.detail-copy-btn');
      if (!btn) return;
      var text = btn.getAttribute('data-copy');
      if (!text) return;
      navigator.clipboard.writeText(text).then(function() {
        btn.classList.replace('far', 'fas');
        btn.classList.replace('fa-clone', 'fa-check');
        setTimeout(function() {
          btn.classList.replace('fas', 'far');
          btn.classList.replace('fa-check', 'fa-clone');
        }, 1200);
      });
    });

    // Toolbar: selection mode toggle
    document.getElementById('cs-edit-list-btn').addEventListener('click', enterListEditMode);
    document.getElementById('cs-list-cancel-btn').addEventListener('click', cancelListEdits);
    document.getElementById('cs-list-save-btn').addEventListener('click', saveListEdits);
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

    // CS table row click -> detail OR toggle checkbox in selection mode OR edit
    document.getElementById('cs-tbody').addEventListener('click', function(e) {
      // Edit button click
      var editBtn = e.target.closest('.cs-row-edit-btn');
      if (editBtn) {
        e.stopPropagation();
        openEditModal(parseInt(editBtn.dataset.editId));
        return;
      }
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
      // Normal mode: open detail via router (creates history entry)
      Router.navigate('/concept-sets', { id: id });
    });

    // CS back button
    document.getElementById('cs-back').addEventListener('click', function() {
      history.back();
    });

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
    document.getElementById('cs-edit-btn').addEventListener('click', enterEditMode);
    document.getElementById('cs-edit-cancel-btn').addEventListener('click', cancelEdits);
    document.getElementById('cs-edit-save-btn').addEventListener('click', saveEdits);
    document.getElementById('cs-stats-reset-btn').addEventListener('click', resetStatsToTemplate);
    document.getElementById('cs-stats-profile-select').addEventListener('change', function() {
      statsCurrentProfile = this.value;
      if (selectedConceptSet) renderStatisticsTab(selectedConceptSet);
    });

    // Expression edit actions
    document.getElementById('expr-import-btn').addEventListener('click', openImportModal);
    document.getElementById('expr-add-btn').addEventListener('click', openAddModal);
    document.getElementById('expr-select-all-btn').addEventListener('click', exprSelectAll);
    document.getElementById('expr-unselect-all-btn').addEventListener('click', exprUnselectAll);
    document.getElementById('expr-delete-sel-btn').addEventListener('click', deleteExprSelected);
    document.getElementById('expr-optimize-btn').addEventListener('click', optimizeExpression);

    // Optimize modal events
    document.getElementById('expr-optimize-close').addEventListener('click', function() {
      document.getElementById('expr-optimize-modal').style.display = 'none';
    });
    document.getElementById('expr-optimize-cancel').addEventListener('click', function() {
      document.getElementById('expr-optimize-modal').style.display = 'none';
    });
    document.getElementById('expr-optimize-apply').addEventListener('click', function() {
      var modal = document.getElementById('expr-optimize-modal');
      if (modal._optimizedItems) {
        exprEditItems = modal._optimizedItems;
        renderExpressionTable();
        App.showToast(App.i18n('Optimization applied — review and save'), 'success');
      }
      modal.style.display = 'none';
    });
    document.getElementById('expr-optimize-modal').addEventListener('click', function(e) {
      if (e.target === this) this.style.display = 'none';
    });

    // Edit custom concept modal
    document.getElementById('edit-custom-concept-close').addEventListener('click', closeEditCustomConceptModal);
    document.getElementById('edit-cc-cancel').addEventListener('click', closeEditCustomConceptModal);
    document.getElementById('edit-cc-save').addEventListener('click', saveEditCustomConcept);
    document.getElementById('edit-custom-concept-modal').addEventListener('click', function(e) {
      if (e.target === this) closeEditCustomConceptModal();
    });

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
      // Edit custom concept icon
      var editIcon = e.target.closest('.expr-edit-custom-icon');
      if (editIcon && exprEditMode) {
        openEditCustomConceptModal(parseInt(editIcon.getAttribute('data-idx')));
        return;
      }
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
      // Row click in edit mode — toggle selection
      if (exprEditMode) {
        var tr = e.target.closest('tr[data-idx]');
        if (tr && !e.target.closest('.toggle-switch') && !e.target.closest('.expr-action-col')) {
          toggleExprRowSelection(parseInt(tr.getAttribute('data-idx')));
        }
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
    document.getElementById('expr-add-exclude').addEventListener('change', updateExcludeModeClass);
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

    // Add concepts: tab switching
    document.getElementById('expr-add-tab-ohdsi').addEventListener('click', function() { switchAddTab('ohdsi'); });
    document.getElementById('expr-add-tab-custom').addEventListener('click', function() { switchAddTab('custom'); });

    // Custom concept: submit & list interactions
    document.getElementById('custom-concept-submit').addEventListener('click', submitCustomConcept);

    // Add concepts: pagination
    document.getElementById('expr-add-page-buttons').addEventListener('click', function(e) {
      handlePageClick(e, addConceptFiltered.length, addPageSize,
        function() { return addPage; },
        function(p) { addPage = p; },
        function() { renderAddResults(); },
        'expr-add-table-scroll');
    });

    // Add concepts: filters popup
    document.getElementById('expr-add-filters-btn').addEventListener('click', function(e) {
      e.stopPropagation();
      var popup = document.getElementById('expr-add-filters-popup');
      addFiltersVisible = !addFiltersVisible;
      popup.style.display = addFiltersVisible ? '' : 'none';
    });
    document.getElementById('expr-add-filters-apply').addEventListener('click', function() {
      // All filters (including Standard) are now multi-selects updated live via onChange
      addFilterValid = document.getElementById('expr-add-filter-valid').checked;
      addFiltersVisible = false;
      document.getElementById('expr-add-filters-popup').style.display = 'none';
      renderAddActiveFilters();
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
      addFilterStandard.clear();
      addFilterValid = false;
      document.getElementById('expr-add-filter-valid').checked = false;
      ['expr-add-filter-vocab', 'expr-add-filter-domain', 'expr-add-filter-class', 'expr-add-filter-standard'].forEach(function(id) {
        var container = document.getElementById(id);
        if (container) {
          container.querySelectorAll('.ms-option input[type="checkbox"]').forEach(function(cb) { cb.checked = false; });
        }
      });
      App.updateMsToggleLabel('expr-add-filter-vocab', addFilterVocab);
      App.updateMsToggleLabel('expr-add-filter-domain', addFilterDomain);
      App.updateMsToggleLabel('expr-add-filter-class', addFilterClass);
      App.updateMsToggleLabel('expr-add-filter-standard', addFilterStandard, getStandardLabelMap());
      renderAddActiveFilters();
    });

    // Chip interactions: click × to remove a single filter, "Clear all" to reset
    document.getElementById('expr-add-active-filters').addEventListener('click', function(e) {
      if (e.target.closest('#expr-add-chips-clear')) {
        clearAllAddActiveFilters();
        return;
      }
      var xBtn = e.target.closest('.expr-add-chip-x');
      if (!xBtn) return;
      var chip = xBtn.closest('.expr-add-chip');
      if (!chip) return;
      removeAddActiveFilter(chip.getAttribute('data-type'), chip.getAttribute('data-value'));
    });
    // Limit 10K checkbox: confirm before loading all concepts
    document.getElementById('expr-add-limit').addEventListener('change', function() {
      var cb = this;
      if (cb.checked) {
        // Re-enabling limit — just re-run
        addLimitChecked = true;
        if (document.getElementById('expr-add-search').value.trim()) searchAddConcepts(); else loadAddDefaults();
        return;
      }
      // Unchecking: count total concepts first
      var whereParts = buildAddFilterWhere();
      var q = document.getElementById('expr-add-search').value.trim();
      if (q) {
        var esc = q.replace(/'/g, "''");
        var qLower = esc.toLowerCase();
        var isNumeric = /^\d+$/.test(q);
        var searchConds = [];
        if (isNumeric) searchConds.push('concept_id = ' + q);
        searchConds.push('concept_code ILIKE \'%' + esc + '%\'');
        var words = esc.split(/\s+/).filter(function(w) { return w.length > 0; });
        if (words.length > 1) {
          searchConds.push('(' + words.map(function(w) { return 'concept_name ILIKE \'%' + w + '%\''; }).join(' AND ') + ')');
        } else {
          searchConds.push('concept_name ILIKE \'%' + esc + '%\'');
        }
        searchConds.push('jaro_winkler_similarity(LOWER(concept_name), \'' + qLower + '\') >= 0.88');
        whereParts.unshift('(' + searchConds.join(' OR ') + ')');
      }
      var whereStr = whereParts.length ? ' WHERE ' + whereParts.join(' AND ') : '';
      VocabDB.query('SELECT COUNT(*) AS cnt FROM concept' + whereStr).then(function(rows) {
        var total = Number(rows[0].cnt);
        if (total > ADD_LIMIT_WARN_THRESHOLD) {
          // Show confirmation modal
          var overlay = document.createElement('div');
          overlay.className = 'modal-overlay';
          overlay.style.display = 'flex';
          overlay.style.zIndex = '10100';
          overlay.innerHTML =
            '<div class="modal" style="max-width:400px;padding:24px;text-align:center">' +
              '<i class="fas fa-exclamation-triangle" style="color:var(--warning);font-size:24px"></i>' +
              '<p style="margin:12px 0">' + App.i18n('This will load') + ' <strong>' + total.toLocaleString() + '</strong> ' + App.i18n('concepts. This may be slow.') + '</p>' +
              '<div style="display:flex;gap:8px;justify-content:center">' +
                '<button class="btn-outline-sm" id="limit-warn-cancel"><i class="fas fa-times"></i> ' + App.i18n('Cancel') + '</button>' +
                '<button class="btn-primary-custom" id="limit-warn-confirm"><i class="fas fa-check"></i> ' + App.i18n('Load all') + '</button>' +
              '</div>' +
            '</div>';
          document.body.appendChild(overlay);
          overlay.addEventListener('click', function(e) { if (e.target === overlay) { cb.checked = true; overlay.remove(); } });
          document.getElementById('limit-warn-cancel').addEventListener('click', function() { cb.checked = true; overlay.remove(); });
          document.getElementById('limit-warn-confirm').addEventListener('click', function() {
            overlay.remove();
            addLimitChecked = false;
            if (q) searchAddConcepts(); else loadAddDefaults();
          });
        } else {
          addLimitChecked = false;
          if (q) searchAddConcepts(); else loadAddDefaults();
        }
      });
    });

    // Close filters popup and custom dropdowns on outside click
    document.getElementById('expr-add-modal').addEventListener('click', function(e) {
      if (addFiltersVisible && !e.target.closest('#expr-add-filters-popup') && !e.target.closest('#expr-add-filters-btn')) {
        addFiltersVisible = false;
        document.getElementById('expr-add-filters-popup').style.display = 'none';
      }
      // Close custom concept single-select dropdowns on outside click
      if (!e.target.closest('.ms-toggle') && !e.target.closest('.ms-dropdown')) {
        document.querySelectorAll('#expr-add-panel-custom .ms-dropdown').forEach(function(d) { d.style.display = 'none'; });
      }
    });

    // Add concepts: column filter inputs (client-side filtering)
    ['expr-add-cf-id','expr-add-cf-name','expr-add-cf-vocab','expr-add-cf-code','expr-add-cf-domain','expr-add-cf-class','expr-add-cf-standard'].forEach(function(id) {
      document.getElementById(id).addEventListener('input', function() {
        applyAddColumnFilters();
      });
    });

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

    // Expression table filters
    ['expr-filter-domain', 'expr-filter-exclude', 'expr-filter-descendants', 'expr-filter-mapped'].forEach(function(id) {
      document.getElementById(id).addEventListener('change', function() { expressionPage = 1; renderExpressionTable(); });
    });
    ['expr-filter-name', 'expr-filter-code'].forEach(function(id) {
      document.getElementById(id).addEventListener('input', function() { expressionPage = 1; renderExpressionTable(); });
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
      var allItems = exprEditMode ? (exprEditItems || []) : ((selectedConceptSet && selectedConceptSet.expression && selectedConceptSet.expression.items) || []);
      var filters = getExpressionFilters();
      var filteredCount = filterExpressionItems(allItems, filters).length;
      handlePageClick(e, filteredCount, expressionPageSize,
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

    // Version modal events
    document.getElementById('cs-version-close').addEventListener('click', closeVersionModal);
    document.getElementById('cs-version-cancel').addEventListener('click', closeVersionModal);
    document.getElementById('cs-version-save').addEventListener('click', saveVersion);
    document.getElementById('cs-version-modal').addEventListener('click', function(e) {
      if (e.target === document.getElementById('cs-version-modal')) closeVersionModal();
    });

    // Status modal events
    document.getElementById('cs-status-close').addEventListener('click', closeStatusModal);
    document.getElementById('cs-status-cancel').addEventListener('click', closeStatusModal);
    document.getElementById('cs-status-save').addEventListener('click', saveStatus);
    document.getElementById('cs-status-modal').addEventListener('click', function(e) {
      if (e.target === document.getElementById('cs-status-modal')) closeStatusModal();
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

    // Header logo/title: warn if unsaved edits, then go to list
    App.onBeforeNavigate(function() {
      if (isAnyEditMode()) {
        if (!confirm('You have unsaved changes. Discard and go back to the list?')) return false;
        cancelEdits();
      }
    });
    App.onHome(function() {
      if (selectedConceptSet) Router.navigate('/concept-sets');
    });

    // Column resizing for both tables
    App.initColResize('resolved-table');
    App.initColResize('expression-table');
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
    var csId = query && (query.id || query.cs);
    if (csId) {
      showCSDetail(parseInt(csId));
      var tab = query && query.tab;
      if (tab && ['concepts', 'comments', 'statistics', 'review'].indexOf(tab) !== -1) {
        switchCSDetailTab(tab);
      }
    } else if (selectedConceptSet) {
      // Back to list view (e.g. browser back button)
      if (exprEditMode) exitExprEditMode();
      if (commentsEditMode) exitCommentsEditMode();
      if (statsEditMode) exitStatsEditMode();
      document.getElementById('cs-edit-btn').style.display = 'none';
      document.getElementById('cs-edit-cancel-btn').style.display = 'none';
      document.getElementById('cs-edit-save-btn').style.display = 'none';
      document.getElementById('cs-detail-view').classList.remove('active');
      document.getElementById('cs-list-view').classList.remove('hidden');
      selectedConceptSet = null;
      csDetailTab = 'concepts';
      csConceptMode = 'resolved';
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
    closeVersionModal();
    closeStatusModal();
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
    if (selectedConceptSet) {
      var savedTab = csDetailTab;
      var savedMode = csConceptMode;
      showCSDetail(selectedConceptSet.id);
      switchCSDetailTab(savedTab);
      switchConceptMode(savedMode);
    }
  }

  return {
    show: show,
    hide: hide,
    onLanguageChange: onLanguageChange
  };
})();

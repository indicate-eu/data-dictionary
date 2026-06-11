// concept-sets.js — Concept Sets page module
var ConceptSetsPage = (function() {
  'use strict';

  function GITHUB_REPO() { return (App.config.github && App.config.github.repo) || ''; }
  function GITHUB_BRANCH() { return (App.config.github && App.config.github.branch) || 'main'; }
  function CUSTOM_VOCAB_ID() { return (App.config.customVocabulary && App.config.customVocabulary.id) || 'CUSTOM'; }
  function CUSTOM_VOCAB_PREFIX() { return (App.config.customVocabulary && App.config.customVocabulary.codePrefix) || 'CUSTOM-'; }

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
  var csFilterReviewStatusDefaulted = false; // first populate seeds it with all statuses except 'deprecated'
  var selectedConceptSet = null;
  var selectedSnapshotVersion = null; // non-null when viewing a pinned snapshot
  var selectedVersionMissing = false; // requested version has no snapshot — banner only, no content
  var selectedFromProjectId = null;   // non-null when navigated from a project's variables tab
  var sqlExportUnitLabels = {}; // unit_concept_id -> short label (e.g. "mg/dL"), populated by the SQL export UI
  var csDetailTab = 'concepts';
  var csConceptMode = 'resolved';
  var resolvedPage = 1;
  var resolvedPageSize = 50;
  var resolvedCurrentConcepts = [];
  var resolvedSort = { key: 'name', asc: true };
  var expressionPage = 1;
  var expressionPageSize = 50;
  var exprSort = { key: null, asc: true };

  // Selection mode state (CS list)
  var selectionMode = false;
  var selectedIds = new Set();

  // Expression editor state
  var exprEditMode = false;
  var exprEditItems = null;
  var exprSelectedIdxs = new Set();
  var exprImportEditor = null;
  var addConceptResults = [];      // all results from SQL query
  var addConceptFiltered = [];     // after column-filter + sort
  // Client-side column sort over the loaded SQL result. Empty key = keep the
  // SQL relevance/depth ordering the query returned.
  var addSort = { key: '', asc: true };
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
  // Normalize a vocab DB date (cast to VARCHAR in SQL: "YYYY-MM-DD" or Athena's
  // raw "YYYYMMDD") to the "YYYY-MM-DD" form used in concept set JSON.
  function normalizeVocabDate(v) {
    if (v == null || v === '') return '';
    var s = String(v);
    if (/^\d{8}$/.test(s)) return s.slice(0, 4) + '-' + s.slice(4, 6) + '-' + s.slice(6, 8);
    if (/^\d{4}-\d{2}-\d{2}/.test(s)) return s.slice(0, 10);
    return s;
  }
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
        return App.fuzzyMatch(text, q) !== -1;
      });
    }
    data.sort(function(a, b) {
      var cmp;
      if (csSort.key === 'version') {
        cmp = App.compareVersions(a.version, b.version);
      } else {
        var va = (a[csSort.key] || '').toString().toLowerCase();
        var vb = (b[csSort.key] || '').toString().toLowerCase();
        cmp = va < vb ? -1 : va > vb ? 1 : 0;
      }
      if (cmp !== 0) return csSort.asc ? cmp : -cmp;
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

    // Default selection on first populate: all statuses checked except 'deprecated'.
    if (!csFilterReviewStatusDefaulted && statuses.length > 0) {
      csFilterReviewStatusDefaulted = true;
      statuses.forEach(function(s) { if (s !== 'deprecated') csFilterReviewStatus.add(s); });
    }

    if (skipId !== 'filter-category') {
      App.buildMultiSelectDropdown('filter-category', categories, csCategories, function() {
        csPage = 1;
        renderCSCategories();
        populateColumnFilters('filter-category');
        renderCSTable();
        syncCategoryFilterToUrl();
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
        '<td class="cs-edit-col"><div class="cs-row-actions">' +
          '<button class="cs-row-edit-btn" data-edit-id="' + d.id + '" title="Edit"><i class="fas fa-pen"></i></button>' +
          '<button class="cs-row-edit-btn cs-row-delete-btn" data-delete-id="' + d.id + '" title="' + App.i18n('Delete') + '"><i class="fas fa-trash"></i></button>' +
        '</div></td>' +
        '<td class="cell-truncate" data-tooltip="' + App.escapeHtml(d.category) + '"><span class="badge badge-category">' + App.escapeHtml(d.category) + '</span></td>' +
        '<td class="cell-truncate" data-tooltip="' + App.escapeHtml(d.subcategory) + '"><span class="badge badge-subcategory">' + App.escapeHtml(d.subcategory) + '</span></td>' +
        '<td class="cell-truncate" data-tooltip="' + App.escapeHtml(d.name) + '"><strong>' + App.escapeHtml(d.name) + '</strong></td>' +
        '<td class="cell-truncate"' + (d.description ? ' data-tooltip="' + App.escapeHtml(d.description) + '"' : '') + '>' + App.escapeHtml(d.description || '') + '</td>' +
        '<td class="td-center">' + App.escapeHtml(d.version) + '</td>' +
        '<td class="td-center" data-tooltip="' + App.escapeHtml(App.statusLabel(d.reviewStatus)) + '">' + App.statusBadge(d.reviewStatus) + '</td>' +
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
    // Update URL with tab param. Keep the pinned-version context so the URL
    // stays shareable: reopening it lands on the same snapshot, with banner.
    if (selectedConceptSet) {
      var url = '#/concept-sets?id=' + selectedConceptSet.id;
      if (selectedSnapshotVersion) {
        url += '&version=' + encodeURIComponent(selectedSnapshotVersion);
        if (selectedFromProjectId) url += '&from=project&projectId=' + selectedFromProjectId;
      }
      if (tabName !== 'concepts') url += '&tab=' + tabName;
      // Go through the router so the active language (?lang=fr) is preserved.
      Router.replaceState(url);
    }
  }

  function updateViewJsonLink() {
    var link = document.getElementById('cs-view-json');
    if (!selectedConceptSet || !link) return;
    var folder = (csConceptMode === 'expression') ? 'concept_sets' : 'concept_sets_resolved';
    link.href = 'https://github.com/' + GITHUB_REPO() + '/blob/' + GITHUB_BRANCH() + '/' + folder + '/' + selectedConceptSet.id + '.json';
  }

  function switchConceptMode(mode) {
    csConceptMode = mode;
    document.querySelectorAll('#cs-concept-toggle-bar .toggle-btn').forEach(function(btn) {
      btn.classList.toggle('active', btn.dataset.mode === mode);
    });
    document.getElementById('cs-expression-view').style.display = (mode === 'expression') ? '' : 'none';
    document.getElementById('cs-resolved-view').style.display = (mode === 'resolved') ? '' : 'none';
    // The Columns button lives in the pagination bar of the active table —
    // move it (one DOM node, listeners preserved) to the bar being shown.
    var colVis = document.getElementById('col-vis-wrapper');
    var activeBar = document.getElementById(mode === 'expression' ? 'expression-pagination' : 'resolved-pagination');
    if (colVis && activeBar && colVis.parentElement !== activeBar) activeBar.appendChild(colVis);
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
  // `totalUnfiltered` (optional): when filters hide part of the data, the info
  // line shows the full count too — "Showing 1-30 of 57 (200 total)".
  function renderPaginationControls(paginationId, pageInfoId, pageBtnsId, currentPage, totalItems, pageSize, totalUnfiltered) {
    var paginationEl = document.getElementById(paginationId);
    var totalPages = Math.ceil(totalItems / pageSize);
    if (totalPages <= 0) totalPages = 1;
    if (currentPage > totalPages) currentPage = totalPages;
    if (currentPage < 1) currentPage = 1;
    var start = (currentPage - 1) * pageSize;
    var info = totalItems === 0 ? 'No items' :
      'Showing ' + (start + 1) + '-' + Math.min(start + pageSize, totalItems) + ' of ' + totalItems;
    if (totalUnfiltered != null && totalUnfiltered !== totalItems) {
      info += ' (' + totalUnfiltered + ' total)';
    }
    document.getElementById(pageInfoId).textContent = info;
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
  function renderExpressionTable(skipFilterId) {
    if (!selectedConceptSet) return;
    var allItems = exprEditMode ? exprEditItems : ((selectedConceptSet.expression && selectedConceptSet.expression.items) || []);
    var table = document.getElementById('expression-table');
    var tbody = document.getElementById('expression-tbody');
    // View mode: 10 data columns. Edit mode adds select + actions = 12.
    var colSpan = exprEditMode ? 12 : 10;

    // Toggle table classes
    table.classList.toggle('expr-edit-mode', exprEditMode);

    // Populate filter dropdowns
    populateExpressionFilters(allItems, skipFilterId);

    // Apply filters — build array of {item, origIdx} to preserve real indices
    var filters = getExpressionFilters();
    var indexed = allItems.map(function(item, idx) { return { item: item, origIdx: idx }; });
    var filtered = indexed.filter(function(entry) { return expressionItemMatches(entry.item, filters); });

    sortExpressionEntries(filtered);
    updateExpressionSortIndicators();

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
      // Single action cell after the checkbox holding edit (custom-only) + delete
      // buttons side by side. The column is content-width, so a delete-only row
      // doesn't leave a wide empty gap. Styled like the all-concept-sets list.
      var actionCol = '<td class="expr-action-col"><div class="expr-row-actions">' +
        (isCustom ? '<button class="cs-row-edit-btn expr-edit-custom-icon" data-idx="' + i + '" title="' + App.i18n('Edit custom concept') + '"><i class="fas fa-pen"></i></button>' : '') +
        '<button class="cs-row-edit-btn cs-row-delete-btn expr-delete-icon" data-idx="' + i + '" title="' + App.i18n('Delete') + '"><i class="fas fa-trash"></i></button>' +
        '</div></td>';

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

      var cVocab = c.vocabularyId || '';
      var cName = c.conceptName || '';
      var cCode = c.conceptCode || '';
      var cDomain = c.domainId || '';
      var cClass = c.conceptClassId || '';
      return '<tr data-idx="' + i + '"' + rowClass + '>' +
        (exprEditMode ? selectCol + actionCol : '') +
        '<td class="cell-truncate" data-tooltip="' + App.escapeHtml(cVocab) + '">' + App.escapeHtml(cVocab) + '</td>' +
        '<td>' + App.escapeHtml(String(c.conceptId || '')) + '</td>' +
        '<td class="cell-truncate" data-tooltip="' + App.escapeHtml(cName) + '">' + App.escapeHtml(cName) + '</td>' +
        '<td class="cell-truncate" data-tooltip="' + App.escapeHtml(cCode) + '">' + App.escapeHtml(cCode) + '</td>' +
        '<td class="cell-truncate" data-tooltip="' + App.escapeHtml(cDomain) + '">' + App.escapeHtml(cDomain) + '</td>' +
        '<td class="cell-truncate" data-tooltip="' + App.escapeHtml(cClass) + '">' + App.escapeHtml(cClass) + '</td>' +
        '<td class="td-center" data-tooltip="' + App.escapeHtml(App.standardLabel(c)) + '">' + App.standardBadge(c) + '</td>' +
        excludeCell + descCell + mappedCell +
        '</tr>';
    }).join('');
    applyColumnVisibility();
    renderPaginationControls('expression-pagination', 'expression-page-info', 'expression-page-buttons', expressionPage, filtered.length, expressionPageSize, allItems.length);
  }

  // ==================== EDIT MODE (generalized) ====================
  function isAnyEditMode() {
    return exprEditMode || commentsEditMode || statsEditMode;
  }

  // Baseline of the active editor's content at edit-mode entry, so we can tell
  // whether anything actually changed (avoids a false "unsaved changes" prompt).
  var editBaseline = null;

  // True only if the current edit buffer differs from its entry baseline.
  function hasUnsavedChanges() {
    if (exprEditMode) {
      return JSON.stringify(exprEditItems) !== editBaseline;
    }
    if (commentsEditMode) {
      return commentsAceEditor && commentsAceEditor.getValue() !== editBaseline;
    }
    if (statsEditMode) {
      return statsAceEditor && statsAceEditor.getValue() !== editBaseline;
    }
    return false;
  }

  function enterEditMode() {
    if (!selectedConceptSet || selectedSnapshotVersion) return;
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

  // Run `action` immediately if there are no unsaved edits; otherwise show the
  // clean "Unsaved changes" modal and run it (after cancelEdits) on confirm.
  var pendingDiscardAction = null;
  function confirmDiscardThen(action) {
    // Only prompt if there are real unsaved changes — not merely "in edit mode".
    if (!hasUnsavedChanges()) { if (isAnyEditMode()) cancelEdits(); action(); return; }
    pendingDiscardAction = action;
    document.getElementById('cs-unsaved-modal').style.display = 'flex';
  }
  function closeUnsavedModal() {
    document.getElementById('cs-unsaved-modal').style.display = 'none';
    pendingDiscardAction = null;
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
    // In expression edit mode the Cancel/Save buttons live inside the
    // expression toolbar (next to Add Concepts); for comments/stats they stay
    // in the header. This keeps the header tidy while editing concepts.
    var exprToolbarActive = exprEditMode && csConceptMode === 'expression';
    if (editing) {
      headerEditBtn.style.display = 'none';
      headerExportBtn.style.display = 'none';
      headerImportBtn.style.display = exprEditMode ? '' : 'none';
      headerCancelBtn.style.display = exprToolbarActive ? 'none' : '';
      headerSaveBtn.style.display = exprToolbarActive ? 'none' : '';
      // Expression-specific toolbar
      editActions.style.display = exprToolbarActive ? 'flex' : 'none';
      selCount.textContent = exprSelectedIdxs.size + ' ' + App.i18n('selected');
    } else {
      // Hide Edit button on review tab (has its own "Add Review") and in snapshot mode (snapshots are immutable)
      var showEdit = (csDetailTab !== 'review') && !selectedSnapshotVersion;
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
    editBaseline = JSON.stringify(exprEditItems);
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
    App.stampModified(selectedConceptSet);
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

  /**
   * Optimize the expression by:
   * 1. Top-down: remove items that are already covered by an ancestor with includeDescendants
   * 2. Bottom-up: find parent concepts that can replace groups of siblings
   *    - Only propose if: fewer total items AND resolved set stays identical
   */
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
    body.innerHTML = '<div class="loading-inline"><i class="fas fa-spinner fa-spin"></i> ' + App.i18n('Analyzing hierarchy...') + '</div>';

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

      // UNION (not UNION ALL): the imported concept_ancestor only has direct
      // edges, and on a multi-parent DAG (SNOMED) UNION ALL enumerates every
      // path — combinatorial blowup. UNION dedupes and guarantees termination.
      var sql =
        'WITH RECURSIVE desc_r AS (' +
          'SELECT ancestor_concept_id AS parent, descendant_concept_id AS cid FROM concept_ancestor WHERE ancestor_concept_id IN (' + parentIds.join(',') + ')' +
          ' UNION ' +
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

    // Get ALL descendants of this parent via recursive CTE. UNION (not
    // UNION ALL) so multi-parent DAGs (SNOMED) don't enumerate every path.
    var descSql =
      'WITH RECURSIVE desc_r AS (' +
        'SELECT descendant_concept_id AS cid FROM concept_ancestor WHERE ancestor_concept_id = ' + parentId +
        ' UNION ' +
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
    var content = (tr && tr.longDescription) || '';
    commentsAceEditor.setValue(content, -1);
    editBaseline = commentsAceEditor.getValue();
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
    selectedConceptSet.metadata.translations[lang].longDescription = newContent || null;
    App.stampModified(selectedConceptSet);
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
    editBaseline = statsAceEditor.getValue();
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
    App.stampModified(selectedConceptSet);
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

  // Pending expression-delete action, run when the confirm modal is accepted.
  var pendingExprDelete = null;

  function openExprDeleteConfirm(n, action) {
    pendingExprDelete = action;
    document.getElementById('expr-delete-msg').textContent = n > 1
      ? App.i18n('Delete ') + n + App.i18n(' selected concepts') + '?'
      : App.i18n('Delete this concept?');
    document.getElementById('expr-delete-modal').style.display = 'flex';
  }

  function closeExprDeleteConfirm() {
    document.getElementById('expr-delete-modal').style.display = 'none';
    pendingExprDelete = null;
  }

  function deleteExprSelected() {
    if (exprSelectedIdxs.size === 0) return;
    openExprDeleteConfirm(exprSelectedIdxs.size, function() {
      var sorted = Array.from(exprSelectedIdxs).sort(function(a, b) { return b - a; });
      sorted.forEach(function(idx) { exprEditItems.splice(idx, 1); });
      exprSelectedIdxs.clear();
      updateToolbar();
      renderExpressionTable();
    });
  }

  function deleteExprRow(idx) {
    openExprDeleteConfirm(1, function() {
      exprEditItems.splice(idx, 1);
      exprSelectedIdxs.clear();
      updateToolbar();
      renderExpressionTable();
    });
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
          App.i18n('Loading concepts...');
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
    addSort = { key: '', asc: true };

    var whereParts = buildAddFilterWhere();

    var useLimit = document.getElementById('expr-add-limit').checked;
    var limitClause = useLimit ? ' LIMIT 10000' : '';
    var whereStr = whereParts.length ? ' WHERE ' + whereParts.join(' AND ') : '';

    var sql = 'SELECT concept_id, concept_name, vocabulary_id, domain_id, concept_class_id, concept_code, standard_concept, invalid_reason, ' +
      'CAST(valid_start_date AS VARCHAR) AS valid_start_date, CAST(valid_end_date AS VARCHAR) AS valid_end_date ' +
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
    addSort = { key: '', asc: true };
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
        'SELECT concept_id, concept_name, vocabulary_id, domain_id, concept_class_id, concept_code, standard_concept, invalid_reason, ' +
        'CAST(valid_start_date AS VARCHAR) AS valid_start_date, CAST(valid_end_date AS VARCHAR) AS valid_end_date ' +
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
      'CAST(valid_start_date AS VARCHAR) AS valid_start_date, CAST(valid_end_date AS VARCHAR) AS valid_end_date, ' +
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
    addConceptFiltered = sortAddRows(addConceptFiltered);
    renderAddResults();
  }

  // Sort the filtered add-results by the active column. concept_id sorts
  // numerically; everything else case-insensitive string. Stable. Empty key
  // leaves the SQL ordering (relevance/depth) untouched.
  function sortAddRows(rows) {
    if (!addSort.key) return rows;
    function val(r) {
      if (addSort.key === 'concept_id') return Number(r.concept_id);
      if (addSort.key === 'standard_concept') {
        return r.standard_concept === 'S' ? 'Standard'
          : (r.standard_concept === 'C' ? 'Classification' : 'Non-standard');
      }
      var v = r[addSort.key];
      return v == null ? '' : v;
    }
    var decorated = rows.map(function(r, i) { return { r: r, i: i }; });
    decorated.sort(function(a, b) {
      var va = val(a.r), vb = val(b.r), cmp;
      if (typeof va === 'number' && typeof vb === 'number') cmp = va - vb;
      else {
        va = String(va).toLowerCase(); vb = String(vb).toLowerCase();
        cmp = va < vb ? -1 : va > vb ? 1 : 0;
      }
      if (cmp === 0) cmp = a.i - b.i;
      return addSort.asc ? cmp : -cmp;
    });
    return decorated.map(function(d) { return d.r; });
  }

  // --- Render results ---
  function renderAddResults() {
    var tbody = document.getElementById('expr-add-results-tbody');
    var table = document.getElementById('expr-add-results-table');
    var colSpan = 8;
    // Reflect the active sort column in the header arrows.
    table.querySelectorAll('thead th[data-sort]').forEach(function(th) {
      var isCur = th.dataset.sort === addSort.key;
      th.classList.toggle('sorted', isCur);
      var icon = th.querySelector('.sort-icon');
      if (icon) icon.textContent = (isCur && !addSort.asc) ? '▼' : '▲';
    });
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

    // Concept IDs in the 2-billion range are local/custom (not in Athena) — no Athena link.
    var idRowHtml = Number(r.concept_id) > 2000000000
      ? '<div class="detail-item"><strong>OMOP Concept ID:</strong><span style="color:var(--text-muted)">' + App.i18n('No link available (custom concept)') + '</span></div>'
      : '<div class="detail-item"><strong>OMOP Concept ID:</strong><span><a href="' + athenaUrl + '" target="_blank">' + r.concept_id + '</a>' + copyBtn(r.concept_id) + '</span></div>';

    el.innerHTML = alreadyHtml +
      '<div class="concept-details-container"><div class="concept-details-grid">' +
      '<div class="detail-item"><strong>Concept Name:</strong><span>' + App.escapeHtml(r.concept_name) + copyBtn(r.concept_name) + '</span></div>' +
      idRowHtml +
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
      if (errTarget) errTarget.innerHTML = '<div class="loading-inline" style="color:var(--danger)">' + App.i18n('Error: ') + App.escapeHtml(err.message) + '</div>';
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
        if (t) t.innerHTML = '<div class="empty-state"><p>' + App.i18n('Concept not found') + '</p></div>';
        return;
      }

      var allIds = [Number(self.concept_id)];
      ancestors.forEach(function(a) { allIds.push(Number(a.concept_id)); });
      descendants.forEach(function(d) { allIds.push(Number(d.concept_id)); });

      if (allIds.length === 1) {
        var t2 = addModalHierarchyWrapper ? addModalHierarchyWrapper.querySelector('.amh-canvas') : el;
        if (t2) t2.innerHTML = '<div class="empty-state"><p>' + App.i18n('No hierarchy') + '</p></div>';
        return;
      }

      var edgesSql = 'SELECT ancestor_concept_id AS from_id, descendant_concept_id AS to_id FROM concept_ancestor ' +
        'WHERE ancestor_concept_id IN (' + allIds.join(',') + ') AND descendant_concept_id IN (' + allIds.join(',') + ')';

      return VocabDB.query(edgesSql).then(function(edgeRows) {
        renderAddModalHierarchy(self, ancestors, descendants, edgeRows || [], el);
      });
    }).catch(function(err) {
      var errTarget = addModalHierarchyWrapper ? addModalHierarchyWrapper.querySelector('.amh-canvas') : el;
      if (errTarget) errTarget.innerHTML = '<div class="loading-inline" style="color:var(--danger)">' + App.i18n('Error: ') + App.escapeHtml(err.message) + '</div>';
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
            '<button class="hierarchy-btn amh-zoom-in" title="' + App.i18n('Zoom in') + '"><i class="fas fa-search-plus"></i></button>' +
            '<button class="hierarchy-btn amh-zoom-out" title="' + App.i18n('Zoom out') + '"><i class="fas fa-search-minus"></i></button>' +
            '<button class="hierarchy-btn amh-fit" title="' + App.i18n('Fit to view') + '"><i class="fas fa-compress-arrows-alt"></i></button>' +
            '<button class="hierarchy-btn amh-fullscreen" title="' + App.i18n('Toggle fullscreen') + '"><i class="fas fa-expand"></i></button>' +
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
        this.title = addModalHierarchyFullscreen ? App.i18n('Exit fullscreen') : App.i18n('Toggle fullscreen');
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
    var clickTimeout = null;
    addModalHierarchyNetwork.on('click', function(params) {
      clearTimeout(tooltipShowTimeout);
      clearTimeout(tooltipHideTimeout);
      clearTimeout(clickTimeout);
      clickTimeout = setTimeout(function() {
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
          unpinHierarchyTooltip();
          addModalHierarchyNetwork.unselectAll();
        }
      }, 280);
    });

    // Double-click to navigate within modal hierarchy
    addModalHierarchyNetwork.on('doubleClick', function(params) {
      clearTimeout(clickTimeout);
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
      // Validity metadata must reflect the vocab DB ("Valid only" can be
      // unticked, so invalidated concepts are addable) — never hard-coded.
      var invalidReason = r.invalid_reason || null;
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
          validStartDate: normalizeVocabDate(r.valid_start_date),
          validEndDate: normalizeVocabDate(r.valid_end_date),
          invalidReason: invalidReason,
          invalidReasonCaption: invalidReason ? 'Invalid' : 'Valid'
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
    searchInput.addEventListener('keydown', function(e) {
      if (e.key !== 'Enter') return;
      e.preventDefault();
      var visible = [].filter.call(container.querySelectorAll('.ms-option-single'), function(opt) {
        return opt.style.display !== 'none';
      });
      if (visible.length === 1) visible[0].click();
    });
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
    var vocab = document.getElementById('custom-concept-vocabulary').value.trim() || CUSTOM_VOCAB_ID();
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
        conceptCode: code || CUSTOM_VOCAB_PREFIX() + conceptId,
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
    document.getElementById('edit-cc-vocabulary').value = c.vocabularyId || CUSTOM_VOCAB_ID();
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
    var vocab = document.getElementById('edit-cc-vocabulary').value.trim() || CUSTOM_VOCAB_ID();

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
    c.conceptCode = code || (CUSTOM_VOCAB_PREFIX() + c.conceptId);

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
    code: { label: 'Concept Code', visible: false },
    domain: { label: 'Domain', visible: true },
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

  // ==================== EXPRESSION TABLE FILTERS ====================
  function populateExpressionFilters(items, skipId) {
    var vocabs = {}, domains = {}, classes = {};
    items.forEach(function(item) {
      var c = item.concept;
      vocabs[c.vocabularyId || ''] = true;
      domains[c.domainId || ''] = true;
      classes[c.conceptClassId || ''] = true;
    });

    // skipId: the dropdown currently being interacted with is only refreshed
    // (label), not rebuilt — rebuilding would close it after every checkbox.
    var vocabValues = Object.keys(vocabs).sort();
    if (skipId !== 'expr-filter-vocabulary') {
      App.buildMultiSelectDropdown('expr-filter-vocabulary', vocabValues, exprFilterVocab, function() {
        expressionPage = 1; renderExpressionTable('expr-filter-vocabulary');
      });
    } else {
      App.updateMsToggleLabel('expr-filter-vocabulary', exprFilterVocab);
    }

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
    if (skipId !== 'expr-filter-standard') {
      App.buildMultiSelectDropdown('expr-filter-standard', stdValues, exprFilterStandard, function() {
        expressionPage = 1; renderExpressionTable('expr-filter-standard');
      }, stdLabels);
    } else {
      App.updateMsToggleLabel('expr-filter-standard', exprFilterStandard, stdLabels);
    }
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

  // Single predicate shared by the table render and the pagination count —
  // two diverging copies previously made the page math disagree with the rows.
  function expressionItemMatches(item, filters) {
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
  }

  function filterExpressionItems(items, filters) {
    return items.filter(function(item) { return expressionItemMatches(item, filters); });
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

  function populateResolvedFilters(concepts, skipId) {
    var vocabs = {}, domains = {}, classes = {};
    concepts.forEach(function(c) {
      vocabs[c.vocabularyId || ''] = true;
      domains[c.domainId || ''] = true;
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

    // skipId: don't rebuild the dropdown being interacted with (see
    // populateExpressionFilters) — it would close after every checkbox.
    var vocabValues = Object.keys(vocabs).sort();
    if (skipId !== 'resolved-filter-vocabulary') {
      App.buildMultiSelectDropdown('resolved-filter-vocabulary', vocabValues, resolvedFilterVocab, function() {
        resolvedPage = 1; renderResolvedTable(true, 'resolved-filter-vocabulary');
      });
    } else {
      App.updateMsToggleLabel('resolved-filter-vocabulary', resolvedFilterVocab);
    }

    fillSelect('resolved-filter-domain', domains);

    // Always offer the 3 standard options, regardless of what's actually present in the data,
    // so users can uncheck categories that aren't represented without leaving ghost selections.
    var stdValues = ['S', 'C', ''];
    var stdLabels = { 'S': 'Standard', 'C': 'Classification', '': 'Non-standard' };
    if (skipId !== 'resolved-filter-standard') {
      App.buildMultiSelectDropdown('resolved-filter-standard', stdValues, resolvedFilterStandard, function() {
        resolvedPage = 1; renderResolvedTable(true, 'resolved-filter-standard');
      }, stdLabels);
    } else {
      App.updateMsToggleLabel('resolved-filter-standard', resolvedFilterStandard, stdLabels);
    }

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
    return App.fuzzyMatch(text, query) !== -1;
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

  var resolvedSortAccessors = {
    vocabulary: function(c) { return c.vocabularyId || ''; },
    conceptId:  function(c) { return c.conceptId || 0; },
    name:       function(c) { return c.conceptName || ''; },
    code:       function(c) { return c.conceptCode || ''; },
    domain:     function(c) { return c.domainId || ''; },
    'class':    function(c) { return c.conceptClassId || ''; },
    standard:   function(c) { return c.standardConcept || ''; }
  };
  function sortResolvedConcepts(concepts) {
    if (!resolvedSort.key) return;
    var acc = resolvedSortAccessors[resolvedSort.key];
    if (!acc) return;
    var asc = resolvedSort.asc;
    concepts.sort(function(a, b) {
      var va = acc(a), vb = acc(b);
      if (typeof va === 'string') va = va.toLowerCase();
      if (typeof vb === 'string') vb = vb.toLowerCase();
      if (va < vb) return asc ? -1 : 1;
      if (va > vb) return asc ? 1 : -1;
      // Tie-break on conceptId so homonyms (e.g. "Glucose" in SNOMED vs LOINC)
      // keep a stable, deterministic order regardless of source row order.
      return (a.conceptId || 0) - (b.conceptId || 0);
    });
  }
  function updateResolvedSortIndicators() {
    document.querySelectorAll('#resolved-table thead th[data-sort]').forEach(function(th) {
      var isCur = th.dataset.sort === resolvedSort.key;
      th.classList.toggle('sorted', isCur);
      var icon = th.querySelector('.sort-icon');
      if (icon) icon.textContent = (isCur && !resolvedSort.asc) ? '▼' : '▲';
    });
  }

  var exprSortAccessors = {
    vocabulary:  function(e) { return (e.item.concept.vocabularyId || ''); },
    conceptId:   function(e) { return e.item.concept.conceptId || 0; },
    name:        function(e) { return (e.item.concept.conceptName || ''); },
    code:        function(e) { return (e.item.concept.conceptCode || ''); },
    domain:      function(e) { return (e.item.concept.domainId || ''); },
    'class':     function(e) { return (e.item.concept.conceptClassId || ''); },
    standard:    function(e) { return (e.item.concept.standardConcept || ''); },
    exclude:     function(e) { return e.item.isExcluded ? 1 : 0; },
    descendants: function(e) { return e.item.includeDescendants ? 1 : 0; },
    mapped:      function(e) { return e.item.includeMapped ? 1 : 0; }
  };
  function sortExpressionEntries(entries) {
    if (!exprSort.key) return;
    var acc = exprSortAccessors[exprSort.key];
    if (!acc) return;
    var asc = exprSort.asc;
    entries.sort(function(a, b) {
      var va = acc(a), vb = acc(b);
      if (typeof va === 'string') va = va.toLowerCase();
      if (typeof vb === 'string') vb = vb.toLowerCase();
      if (va < vb) return asc ? -1 : 1;
      if (va > vb) return asc ? 1 : -1;
      return 0;
    });
  }
  function updateExpressionSortIndicators() {
    document.querySelectorAll('#expression-table thead th[data-sort]').forEach(function(th) {
      var isCur = th.dataset.sort === exprSort.key;
      th.classList.toggle('sorted', isCur);
      var icon = th.querySelector('.sort-icon');
      if (icon) icon.textContent = (isCur && !exprSort.asc) ? '▼' : '▲';
    });
  }

  function renderResolvedTableWithData(allConcepts, keepFilters, skipFilterId) {
    resolvedCurrentConcepts = allConcepts || [];
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

    populateResolvedFilters(allConcepts, skipFilterId);

    var filters = getResolvedFilters();
    var concepts = filterResolvedConcepts(allConcepts, filters);
    sortResolvedConcepts(concepts);

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
      var vocab = c.vocabularyId || '';
      var name = c.conceptName || '';
      var code = c.conceptCode || '';
      var domain = c.domainId || '';
      var klass = c.conceptClassId || '';
      return '<tr data-idx="' + origIdx + '">' +
        '<td class="cell-truncate" data-tooltip="' + App.escapeHtml(vocab) + '">' + App.escapeHtml(vocab) + '</td>' +
        '<td>' + c.conceptId + '</td>' +
        '<td class="cell-truncate" data-tooltip="' + App.escapeHtml(name) + '">' + App.escapeHtml(name) + '</td>' +
        '<td class="cell-truncate" data-tooltip="' + App.escapeHtml(code) + '">' + App.escapeHtml(code) + '</td>' +
        '<td class="cell-truncate" data-tooltip="' + App.escapeHtml(domain) + '">' + App.escapeHtml(domain) + '</td>' +
        '<td class="cell-truncate" data-tooltip="' + App.escapeHtml(klass) + '">' + App.escapeHtml(klass) + '</td>' +
        '<td class="td-center" data-tooltip="' + App.escapeHtml(App.standardLabel(c)) + '">' + App.standardBadge(c) + '</td>' +
        '</tr>';
    }).join('');
    applyColumnVisibility();
    updateResolvedSortIndicators();
    renderPaginationControls('resolved-pagination', 'resolved-page-info', 'resolved-page-buttons', resolvedPage, concepts.length, resolvedPageSize, allConcepts.length);
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

  function renderResolvedTable(keepFilters, skipFilterId) {
    if (!selectedConceptSet) return;

    // Use current expression items (edited or saved)
    var items = exprEditMode && exprEditItems
      ? exprEditItems
      : (selectedConceptSet.expression || {}).items || [];

    // If no items, nothing to resolve
    if (items.length === 0) {
      renderResolvedTableWithData([], keepFilters, skipFilterId);
      return;
    }

    // Snapshot mode: the resolved concepts for the pinned version are inlined
    // in DATA.resolvedConceptSetVersions by build.py. Never live-resolve in this
    // mode — the current VocabDB may not match the snapshot's source vocab.
    if (selectedSnapshotVersion) {
      var snap = App.getResolvedConceptSet(selectedConceptSet.id, selectedSnapshotVersion) || [];
      renderResolvedTableWithData(appendCustomConcepts(snap, items), keepFilters, skipFilterId);
      return;
    }

    // If no DuckDB, fall back to pre-resolved data + custom concepts
    if (typeof VocabDB === 'undefined') {
      var preResolved = App.resolvedIndex[selectedConceptSet.id];
      if (preResolved) {
        renderResolvedTableWithData(appendCustomConcepts(preResolved, items), keepFilters, skipFilterId);
        return;
      }
      // Deferred: fetch from individual file
      if (App.resolvedDeferred[selectedConceptSet.id]) {
        var tbody = document.getElementById('resolved-tbody');
        var colCount = Object.keys(resolvedColumns).length;
        tbody.innerHTML = '<tr><td colspan="' + colCount + '" class="empty-state"><p><i class="fas fa-spinner fa-spin"></i> ' + App.i18n('Loading resolved concepts...') + '</p></td></tr>';
        App.fetchResolved(selectedConceptSet.id).then(function(concepts) {
          renderResolvedTableWithData(appendCustomConcepts(concepts, items), keepFilters, skipFilterId);
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
          renderResolvedTableWithData(appendCustomConcepts(preResolved, items), keepFilters, skipFilterId);
        } else if (App.resolvedDeferred[selectedConceptSet.id]) {
          App.fetchResolved(selectedConceptSet.id).then(function(concepts) {
            renderResolvedTableWithData(appendCustomConcepts(concepts, items), keepFilters, skipFilterId);
          });
        } else {
          // No pre-resolved data — try to remount DB and show loading state
          showResolvedDbLoading();
          VocabDB.remountFromStoredHandles().then(function(ok) {
            if (ok) {
              resolveExpressionLive(items).then(function(concepts) {
                renderResolvedTableWithData(concepts, keepFilters, skipFilterId);
              }).catch(function(err) {
                console.error('Live resolve failed:', err);
                renderResolvedTableWithData([], keepFilters, skipFilterId);
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
        renderResolvedTableWithData(concepts, keepFilters, skipFilterId);
      }).catch(function(err) {
        console.error('Live resolve failed:', err);
        renderResolvedTableWithData([], keepFilters, skipFilterId);
      });
    });
  }

  function showResolvedDbLoading() {
    var tbody = document.getElementById('resolved-tbody');
    var colCount = Object.keys(resolvedColumns).length;
    tbody.innerHTML = '<tr><td colspan="' + colCount + '" class="empty-state"><p><i class="fas fa-spinner fa-spin" style="color:var(--primary); margin-right:6px"></i>' + App.i18n('Loading vocabulary database...') + '</p></td></tr>';
    renderPaginationControls('resolved-pagination', 'resolved-page-info', 'resolved-page-buttons', 1, 0, resolvedPageSize);
  }

  function showResolvedDbUnavailable() {
    var tbody = document.getElementById('resolved-tbody');
    var colCount = Object.keys(resolvedColumns).length;
    tbody.innerHTML = '<tr><td colspan="' + colCount + '" class="empty-state"><p><i class="fas fa-info-circle" style="color:var(--primary); margin-right:6px"></i>' + App.i18n('Load OHDSI vocabularies in') + ' <a href="#/settings" style="color:var(--primary); font-weight:600">' + App.i18n('Dictionary Settings') + '</a> ' + App.i18n('to resolve concepts.') + '</p></td></tr>';
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

    var isCustomConcept = Number(concept.conceptId) > 2000000000;
    var fhirHtml = fhirUrl
      ? '<a href="' + fhirUrl + '" target="_blank">' + App.escapeHtml(concept.vocabularyId) + '</a>'
      : '<span style="color:var(--text-muted)">' + (isCustomConcept ? App.i18n('No link available (custom concept)') : App.i18n('No link available')) + '</span>';

    var backBtnHtml = conceptDetailHistory.length > 0
      ? '<div style="margin-bottom:8px"><button class="btn-outline-sm" id="concept-detail-back"><i class="fas fa-arrow-left"></i> Back</button></div>'
      : '';

    var copyBtn = function(value) {
      return ' <i class="far fa-clone detail-copy-btn" data-copy="' + App.escapeHtml(String(value)) + '" title="Copy"></i>';
    };

    // Concept IDs in the 2-billion range are local/custom (not in Athena) — no Athena link.
    var idRowHtml = isCustomConcept
      ? '<div class="detail-item"><strong>OMOP Concept ID:</strong><span style="color:var(--text-muted)">' + App.i18n('No link available (custom concept)') + '</span></div>'
      : '<div class="detail-item"><strong>OMOP Concept ID:</strong><span><a href="' + athenaUrl + '" target="_blank">' + concept.conceptId + '</a>' + copyBtn(concept.conceptId) + '</span></div>';

    el.innerHTML = backBtnHtml +
      '<div class="concept-details-container"><div class="concept-details-grid">' +
      '<div class="detail-item"><strong>Concept Name:</strong><span>' + App.escapeHtml(concept.conceptName) + copyBtn(concept.conceptName) + '</span></div>' +
      idRowHtml +
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
          App.i18n('Loading concepts...');
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
  // Document-level Esc handler for the hierarchy fullscreen — replaced (not
  // stacked) each time the panel is rebuilt, so handlers don't accumulate.
  var vocabTabsEscHandler = null;
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
        '<button class="concept-vocab-tab' + (activeTab === 'related' ? ' active' : '') + '" data-vtab="related">' + App.i18n('Related') + '</button>' +
        '<button class="concept-vocab-tab' + (activeTab === 'hierarchy' ? ' active' : '') + '" data-vtab="hierarchy">' + App.i18n('Hierarchy') + '</button>' +
        '<button class="concept-vocab-tab' + (activeTab === 'synonyms' ? ' active' : '') + '" data-vtab="synonyms">' + App.i18n('Synonyms') + '</button>' +
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

    el.innerHTML = '<div class="loading-inline"><i class="fas fa-spinner fa-spin"></i> ' + App.i18n('Loading...') + '</div>';

    var sql =
      'SELECT cr.relationship_id, c.concept_id, c.concept_name, c.vocabulary_id, ' +
      'c.domain_id, c.concept_class_id, c.concept_code, c.standard_concept ' +
      'FROM concept_relationship cr ' +
      'JOIN concept c ON c.concept_id = cr.concept_id_2 ' +
      'WHERE cr.concept_id_1 = ' + conceptId + ' ' +
      'ORDER BY cr.relationship_id, c.concept_name';

    VocabDB.query(sql).then(function(rows) {
      if (!rows || rows.length === 0) {
        el.innerHTML = '<div class="loading-inline">' + App.i18n('No related concepts found.') + '</div>';
        return;
      }
      relatedRows = rows;
      renderRelatedPage();
    }).catch(function(err) {
      el.innerHTML = '<div class="loading-inline" style="color:var(--danger)">' + App.i18n('Error: ') + App.escapeHtml(err.message) + '</div>';
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

    // The shell (headers + filter inputs + pager) is rendered ONCE; filtering
    // only re-renders the body, so the filter input keeps focus while typing.
    relatedEl.innerHTML = '<table class="concept-related-table"><thead><tr>' +
      '<th>' + App.i18n('Relationship') + '</th><th>' + App.i18n('Vocabulary') + '</th><th>' + App.i18n('Concept Name') + '</th><th>' + App.i18n('Concept ID') + '</th>' +
      '</tr><tr class="filter-row">' +
      '<th><input type="text" class="column-filter" id="rel-filter-relationship" placeholder="' + App.i18n('Filter...') + '" value="' + App.escapeHtml(relatedFilterRelationship) + '"></th>' +
      '<th><input type="text" class="column-filter" id="rel-filter-vocabulary" placeholder="' + App.i18n('Filter...') + '" value="' + App.escapeHtml(relatedFilterVocabulary) + '"></th>' +
      '<th><input type="text" class="column-filter" id="rel-filter-name" placeholder="' + App.i18n('Filter...') + '" value="' + App.escapeHtml(relatedFilterName) + '"></th>' +
      '<th><input type="text" class="column-filter" id="rel-filter-id" placeholder="' + App.i18n('Filter...') + '" value="' + App.escapeHtml(relatedFilterId) + '"></th>' +
      '</tr></thead><tbody></tbody></table>' +
      '<div class="related-pager" id="rel-pager" style="display:none">' +
        '<button class="btn-outline-sm" id="rel-prev"><i class="fas fa-chevron-left"></i></button>' +
        '<span id="rel-pager-info" style="font-size:12px; color:var(--text-muted)"></span>' +
        '<button class="btn-outline-sm" id="rel-next"><i class="fas fa-chevron-right"></i></button>' +
      '</div>';

    function wireFilter(id, set) {
      document.getElementById(id).addEventListener('input', function() {
        set(this.value); relatedPage = 0; renderRelatedBody();
      });
    }
    wireFilter('rel-filter-relationship', function(v) { relatedFilterRelationship = v; });
    wireFilter('rel-filter-vocabulary', function(v) { relatedFilterVocabulary = v; });
    wireFilter('rel-filter-name', function(v) { relatedFilterName = v; });
    wireFilter('rel-filter-id', function(v) { relatedFilterId = v; });
    document.getElementById('rel-prev').addEventListener('click', function() { relatedPage--; renderRelatedBody(); });
    document.getElementById('rel-next').addEventListener('click', function() { relatedPage++; renderRelatedBody(); });

    // Click row to navigate (with history)
    relatedEl.querySelector('tbody').addEventListener('click', function(e) {
      var tr = e.target.closest('tr[data-cid]');
      if (!tr) return;
      var cid = parseInt(tr.getAttribute('data-cid'));
      navigateToConceptDetail(cid, currentConceptInDetail);
    });

    renderRelatedBody();
  }

  function renderRelatedBody() {
    if (!relatedRows || !relatedEl) return;
    var filtered = getFilteredRelatedRows();
    var total = filtered.length;
    var totalPages = Math.max(1, Math.ceil(total / RELATED_PAGE_SIZE));
    if (relatedPage >= totalPages) relatedPage = totalPages - 1;
    if (relatedPage < 0) relatedPage = 0;
    var start = relatedPage * RELATED_PAGE_SIZE;
    var end = Math.min(start + RELATED_PAGE_SIZE, total);

    var html = '';
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
    if (total === 0) {
      html = '<tr><td colspan="4" style="padding:12px; color:var(--text-muted)">' + App.escapeHtml(App.i18n('No concepts match the current filters.')) + '</td></tr>';
    }
    relatedEl.querySelector('tbody').innerHTML = html;

    var pager = document.getElementById('rel-pager');
    if (totalPages > 1) {
      pager.style.display = '';
      document.getElementById('rel-prev').disabled = relatedPage === 0;
      document.getElementById('rel-next').disabled = relatedPage >= totalPages - 1;
      document.getElementById('rel-pager-info').textContent = (start + 1) + '–' + end + ' ' + App.i18n('of') + ' ' + total;
    } else {
      pager.style.display = 'none';
    }
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
                App.i18n('This concept has') + ' <strong>' + total + '</strong> ' + App.i18n('nodes in the hierarchy. Loading may be slow.') +
              '</div>' +
              '<div style="display:flex; gap:8px; margin-top:12px">' +
                '<button class="btn-outline-sm" id="hierarchy-warn-cancel"><i class="fas fa-times"></i> ' + App.i18n('Cancel') + '</button>' +
                '<button class="btn-outline-sm" id="hierarchy-load-anyway"><i class="fas fa-project-diagram"></i> ' + App.i18n('Load anyway') + '</button>' +
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
      el.innerHTML = '<div class="loading-inline" style="color:var(--danger)">' + App.i18n('Error: ') + App.escapeHtml(err.message) + '</div>';
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
          el.innerHTML = '<div class="loading-inline">' + App.i18n('Concept not found in vocabulary database.') + '</div>';
          return;
        }

        // Collect all concept IDs for edges query
        var allIds = [Number(self.concept_id)];
        ancestors.forEach(function(a) { allIds.push(Number(a.concept_id)); });
        descendants.forEach(function(d) { allIds.push(Number(d.concept_id)); });

        if (allIds.length === 1) {
          el.innerHTML = '<div class="loading-inline">' + App.i18n('No hierarchy relationships found for this concept.') + '</div>';
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
        el.innerHTML = '<div class="loading-inline" style="color:var(--danger)">' + App.i18n('Error: ') + App.escapeHtml(err.message) + '</div>';
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
          '<button class="hierarchy-btn" id="hierarchy-back-btn" title="' + App.i18n('Back to previous concept') + '"' +
            (hierarchyHistory.length === 0 ? ' disabled' : '') + '>' +
            '<i class="fas fa-arrow-left"></i></button>' +
          '<div class="hierarchy-header-title">' +
            App.escapeHtml(self.concept_name) +
            '<span class="hierarchy-id">#' + selfId + ' · ' + App.escapeHtml(self.vocabulary_id) + '</span>' +
          '</div>' +
          '<div class="hierarchy-controls">' +
            '<button class="hierarchy-btn" id="hierarchy-zoom-in" title="' + App.i18n('Zoom in') + '"><i class="fas fa-search-plus"></i></button>' +
            '<button class="hierarchy-btn" id="hierarchy-zoom-out" title="' + App.i18n('Zoom out') + '"><i class="fas fa-search-minus"></i></button>' +
            '<button class="hierarchy-btn" id="hierarchy-fit" title="' + App.i18n('Fit to view') + '"><i class="fas fa-compress-arrows-alt"></i></button>' +
            '<button class="hierarchy-btn" id="hierarchy-fullscreen" title="' + App.i18n('Toggle fullscreen') + '"><i class="fas fa-expand"></i></button>' +
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
        this.title = hierarchyIsFullscreen ? App.i18n('Exit fullscreen') : App.i18n('Toggle fullscreen');
        setTimeout(function() {
          if (vocabTabsHierarchyNetwork) vocabTabsHierarchyNetwork.fit({ animation: { duration: 300 } });
        }, 100);
      });

      // Esc to exit fullscreen
      if (vocabTabsEscHandler) document.removeEventListener('keydown', vocabTabsEscHandler);
      vocabTabsEscHandler = function(e) {
        if (e.key === 'Escape' && hierarchyIsFullscreen) {
          hierarchyIsFullscreen = false;
          wrapper.classList.remove('fullscreen');
          var fsBtn = wrapper.querySelector('#hierarchy-fullscreen');
          if (fsBtn) {
            var icon = fsBtn.querySelector('i');
            icon.className = 'fas fa-expand';
            fsBtn.title = App.i18n('Toggle fullscreen');
          }
          setTimeout(function() {
            if (vocabTabsHierarchyNetwork) vocabTabsHierarchyNetwork.fit({ animation: { duration: 300 } });
          }, 100);
        }
      };
      document.addEventListener('keydown', vocabTabsEscHandler);
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
    var clickTimeout2 = null;
    vocabTabsHierarchyNetwork.on('click', function(params) {
      clearTimeout(tooltipShowTimeout);
      clearTimeout(tooltipHideTimeout);
      clearTimeout(clickTimeout2);
      clickTimeout2 = setTimeout(function() {
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
      }, 280);
    });

    // Double-click on node: navigate hierarchy in-place
    vocabTabsHierarchyNetwork.on('doubleClick', function(params) {
      clearTimeout(clickTimeout2);
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
    el.innerHTML = '<div class="loading-inline"><i class="fas fa-spinner fa-spin"></i> ' + App.i18n('Loading...') + '</div>';
    VocabDB.query(
      'SELECT cs.concept_synonym_name, c.concept_name AS language ' +
      'FROM concept_synonym cs ' +
      'LEFT JOIN concept c ON c.concept_id = cs.language_concept_id ' +
      'WHERE cs.concept_id = ' + conceptId + ' ' +
      'ORDER BY c.concept_name, cs.concept_synonym_name'
    ).then(function(rows) {
        if (!rows || rows.length === 0) {
          el.innerHTML = '<div class="loading-inline">' + App.i18n('No synonyms found.') + '</div>';
          return;
        }
        var html = '<table class="concept-related-table"><thead><tr>' +
          '<th>' + App.i18n('Synonym') + '</th><th>' + App.i18n('Language') + '</th>' +
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
        el.innerHTML = '<div class="loading-inline" style="color:var(--danger)">' + App.i18n('Error: ') + App.escapeHtml(err.message) + '</div>';
      });
  }

  // ==================== TAB CONTENT ====================
  function renderCommentsTab(cs) {
    var el = document.getElementById('cs-comments-body');
    var tr = App.t(cs);
    var longDesc = (tr && tr.longDescription) || '';
    if (!longDesc) {
      el.innerHTML = '<div class="empty-state"><p>' + App.i18n('No description available for this concept set.') + '</p></div>';
      return;
    }
    el.innerHTML = App.renderMarkdown(longDesc);
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
      html += '<div style="font-size:13px; margin-bottom:12px; color:var(--text-muted)"><i class="fas fa-exclamation-triangle" style="margin-right:4px"></i> Missing rate: <strong>' + App.escapeHtml(profile.missing_rate) + '%</strong></div>';
    }

    // Numeric data
    var nd = profile.numeric_data;
    if (nd && (nd.mean != null || nd.median != null || nd.min != null)) {
      html += '<h4 style="font-size:13px; font-weight:600; color:var(--text-muted); text-transform:uppercase; letter-spacing:.5px; margin:16px 0 8px">' + App.i18n('Numeric Summary') + '</h4>';
      html += '<table class="stats-summary-table"><tbody>';
      var rows = [
        ['Min', nd.min], ['P5', nd.p5], ['P25 (Q1)', nd.p25], ['Median', nd.median],
        ['Mean', nd.mean], ['P75 (Q3)', nd.p75], ['P95', nd.p95], ['Max', nd.max],
        ['SD', nd.sd], ['CV', nd.cv != null ? nd.cv + '%' : null]
      ];
      rows.forEach(function(r) {
        if (r[1] != null) html += '<tr><td style="font-weight:600; color:var(--text-muted); padding:3px 12px 3px 0; font-size:13px">' + r[0] + '</td><td style="font-size:13px; padding:3px 0">' + App.escapeHtml(r[1]) + '</td></tr>';
      });
      html += '</tbody></table>';
    }

    // Histogram
    var hist = profile.histogram;
    if (hist && hist.length > 0) {
      html += '<h4 style="font-size:13px; font-weight:600; color:var(--text-muted); text-transform:uppercase; letter-spacing:.5px; margin:16px 0 8px">' + App.i18n('Distribution') + '</h4>';
      var maxCount = Math.max.apply(null, hist.map(function(h) { return h.count || 0; }));
      html += '<div class="stats-histogram">';
      hist.forEach(function(h) {
        var pct = maxCount > 0 ? ((h.count / maxCount) * 100) : 0;
        html += '<div class="stats-hist-row">' +
          '<span class="stats-hist-label">' + App.escapeHtml(h.x != null ? h.x : '') + '</span>' +
          '<div class="stats-hist-bar-wrap"><div class="stats-hist-bar" style="width:' + pct + '%"></div></div>' +
          '<span class="stats-hist-count">' + (h.count || 0).toLocaleString() + '</span>' +
          '</div>';
      });
      html += '</div>';
    }

    // Categorical data
    var cat = profile.categorical_data;
    if (cat && cat.length > 0) {
      html += '<h4 style="font-size:13px; font-weight:600; color:var(--text-muted); text-transform:uppercase; letter-spacing:.5px; margin:16px 0 8px">' + App.i18n('Categories') + '</h4>';
      var maxCatPct = Math.max.apply(null, cat.map(function(c) { return c.percent || 0; }));
      html += '<div class="stats-histogram">';
      cat.forEach(function(c) {
        var barW = maxCatPct > 0 ? ((c.percent / maxCatPct) * 100) : 0;
        html += '<div class="stats-hist-row">' +
          '<span class="stats-hist-label" title="' + App.escapeHtml(c.value || '') + '">' + App.escapeHtml(App.truncate(c.value || '', 30)) + '</span>' +
          '<div class="stats-hist-bar-wrap"><div class="stats-hist-bar stats-hist-bar-cat" style="width:' + barW + '%"></div></div>' +
          '<span class="stats-hist-count">' + (c.percent != null ? App.escapeHtml(c.percent) + '%' : '') + ' (' + (c.count || 0).toLocaleString() + ')</span>' +
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
    reviewSourceReviews = reviews;

    // Populate the status filter from the data, keeping the current selection.
    var statusSel = document.getElementById('review-filter-status');
    var cur = statusSel.value;
    var statuses = {};
    reviews.forEach(function(r) { if (r.status) statuses[r.status] = true; });
    statusSel.innerHTML = '<option value="">' + App.escapeHtml(App.i18n('All')) + '</option>' +
      Object.keys(statuses).sort().map(function(s) {
        return '<option value="' + App.escapeHtml(s) + '">' + App.escapeHtml(App.statusLabel(s)) + '</option>';
      }).join('');
    statusSel.value = cur;

    renderReviewTable();
  }

  // ==================== REVIEW TABLE (filter + sort) ====================
  var reviewSourceReviews = [];
  // Reviews currently shown in the table, after filtering/sorting (modal index).
  var reviewTabReviews = [];
  var reviewSort = { key: 'date', asc: false }; // most recent first by default

  function reviewerName(r) {
    var reviewer = r.reviewer || {};
    return ((reviewer.firstName || '') + ' ' + (reviewer.lastName || '')).trim();
  }

  function renderReviewTable() {
    var f = {
      reviewer: document.getElementById('review-filter-reviewer').value.toLowerCase(),
      date: document.getElementById('review-filter-date').value.toLowerCase(),
      status: document.getElementById('review-filter-status').value,
      version: document.getElementById('review-filter-version').value.toLowerCase(),
      comments: document.getElementById('review-filter-comments').value.toLowerCase()
    };
    var rows = reviewSourceReviews.filter(function(r) {
      if (f.reviewer && reviewerName(r).toLowerCase().indexOf(f.reviewer) === -1) return false;
      if (f.date && (r.reviewDate || '').toLowerCase().indexOf(f.date) === -1) return false;
      if (f.status && (r.status || '') !== f.status) return false;
      if (f.version && (r.version || '').toLowerCase().indexOf(f.version) === -1) return false;
      if (f.comments && (r.comments || '').toLowerCase().indexOf(f.comments) === -1) return false;
      return true;
    });

    rows.sort(function(a, b) {
      var cmp;
      if (reviewSort.key === 'version') {
        cmp = App.compareVersions(a.version, b.version);
      } else {
        var acc = {
          reviewer: function(r) { return reviewerName(r).toLowerCase(); },
          date: function(r) { return r.reviewDate || ''; },
          status: function(r) { return r.status || ''; },
          comments: function(r) { return (r.comments || '').toLowerCase(); }
        }[reviewSort.key];
        var va = acc(a), vb = acc(b);
        cmp = va < vb ? -1 : va > vb ? 1 : 0;
      }
      return reviewSort.asc ? cmp : -cmp;
    });

    // Sort indicators
    document.querySelectorAll('#cs-review-table th[data-sort]').forEach(function(th) {
      var icon = th.querySelector('.sort-icon');
      var isCur = th.dataset.sort === reviewSort.key;
      th.classList.toggle('sorted', isCur);
      if (icon) icon.textContent = (isCur && !reviewSort.asc) ? '▼' : '▲';
    });

    reviewTabReviews = rows;
    var tbody = document.getElementById('cs-review-tbody');
    if (rows.length === 0) {
      tbody.innerHTML = '<tr><td colspan="5" style="padding:12px; color:var(--text-muted)">' +
        App.escapeHtml(App.i18n('No reviews match the current filters.')) + '</td></tr>';
      return;
    }
    tbody.innerHTML = rows.map(function(r, idx) {
      return '<tr data-review-idx="' + idx + '" style="cursor:pointer" title="' + App.escapeHtml(App.i18n('Click to view the full review')) + '">' +
        '<td>' + App.escapeHtml(reviewerName(r) || 'Unknown') + '</td>' +
        '<td>' + App.escapeHtml(r.reviewDate || '') + '</td>' +
        '<td class="td-center">' + App.statusBadge(r.status) + '</td>' +
        '<td>' + App.escapeHtml(r.version || '') + '</td>' +
        '<td class="desc-truncated">' + App.escapeHtml(App.truncate(r.comments || '', 150)) + '</td>' +
        '</tr>';
    }).join('');
  }

  function openReviewViewModal(idx) {
    var r = reviewTabReviews[idx];
    if (!r) return;
    var name = reviewerName(r) || 'Unknown';
    var titleEl = document.getElementById('cs-review-view-title');
    var titleHtml = App.escapeHtml(name + (r.reviewDate ? ' — ' + r.reviewDate : ''));

    // Version badge: blue when the review targets the current version, red
    // (and clickable, opening the pinned version) when it targets an older one.
    if (r.version && selectedConceptSet) {
      var latest = App.getLatestVersion(selectedConceptSet.id);
      var isCurrent = r.version === latest;
      if (isCurrent) {
        titleHtml += ' <span class="review-version-badge current" data-tip="' +
          App.escapeHtml(App.i18n('This review targets the current version')) + '">' + App.escapeHtml(r.version) + '</span>';
      } else {
        titleHtml += ' <a class="review-version-badge outdated" href="#/concept-sets?id=' + selectedConceptSet.id +
          '&version=' + encodeURIComponent(r.version) + '" data-tip="' +
          App.escapeHtml(App.i18n('This review targets an earlier version (current: {v}) — click to open it').replace('{v}', latest)) +
          '">' + App.escapeHtml(r.version) + '</a>';
      }
    }
    titleEl.innerHTML = titleHtml;

    var body = document.getElementById('cs-review-view-body');
    body.innerHTML = (r.comments || '').trim()
      ? App.renderMarkdown(r.comments)
      : '<p style="color:var(--text-muted); font-style:italic">' + App.escapeHtml(App.i18n('No comments in this review.')) + '</p>';
    document.getElementById('cs-review-view-modal').style.display = 'flex';
  }

  function closeReviewViewModal() {
    document.getElementById('cs-review-view-modal').style.display = 'none';
  }

  // ==================== CS DETAIL ====================
  function showCSDetail(id, options) {
    options = options || {};
    var live = App.conceptSets.find(function(c) { return c.id === id; });
    var requestedVersion = options.version || '';
    var cs = live;
    var isSnapshot = false;
    var missing = false;
    if (requestedVersion && live && live.version !== requestedVersion) {
      var snap = App.getConceptSet(id, requestedVersion);
      if (snap) { cs = snap; isSnapshot = true; }
      // Requested version has no snapshot: don't silently fall back to the
      // latest — show the banner and no content instead.
      else missing = true;
    }
    if (!cs) return;
    selectedConceptSet = cs;
    selectedSnapshotVersion = (isSnapshot || missing) ? requestedVersion : null;
    selectedVersionMissing = missing;
    selectedFromProjectId = options.from === 'project' && options.projectId ? parseInt(options.projectId) : null;
    var tr = App.t(cs);

    document.getElementById('cs-list-view').classList.add('hidden');
    document.getElementById('cs-detail-view').classList.add('active');

    var titleName = tr.name || cs.name;
    var titleEl = document.getElementById('cs-detail-title');
    titleEl.querySelector('.title-tooltip-text').textContent = titleName;
    titleEl.querySelector('.title-tooltip-bubble').textContent = titleName;
    refreshDetailBadges();
    renderVersionBanner();

    // Hide edit controls in snapshot mode (snapshots are immutable)
    document.getElementById('cs-edit-btn').style.display = (isSnapshot || missing) ? 'none' : '';
    document.getElementById('cs-edit-cancel-btn').style.display = 'none';
    document.getElementById('cs-edit-save-btn').style.display = 'none';

    // Requested version unavailable: keep the header + banner, hide the rest.
    document.getElementById('cs-detail-tabs').style.display = missing ? 'none' : '';
    if (missing) {
      document.getElementById('cs-export-json').style.display = 'none';
      document.getElementById('expr-import-btn').style.display = 'none';
      document.getElementById('cs-view-json').style.display = 'none';
      document.getElementById('expr-edit-actions').style.display = 'none';
      document.querySelectorAll('#cs-detail-view .cs-tab-content').forEach(function(el) { el.style.display = 'none'; });
      // Keep the requested version in the URL so the link stays shareable.
      Router.replaceState('#/concept-sets?id=' + id + '&version=' + encodeURIComponent(requestedVersion));
      return;
    }
    document.getElementById('cs-view-json').style.display = '';

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

  function renderVersionBanner() {
    var banner = document.getElementById('cs-version-banner');
    if (!banner) return;
    if (!selectedSnapshotVersion || !selectedConceptSet) {
      banner.style.display = 'none';
      return;
    }
    var live = App.conceptSets.find(function(c) { return c.id === selectedConceptSet.id; });
    var latest = live ? (live.version || '') : '';
    var msg;
    var fromProject = selectedFromProjectId
      ? App.projects.find(function(p) { return p.id === selectedFromProjectId; })
      : null;
    if (selectedVersionMissing) {
      msg = App.i18n('The requested version {pinned} is not available (it was never published or snapshotted). The latest version is {latest}.')
        .replace('{pinned}', selectedSnapshotVersion).replace('{latest}', latest);
    } else if (fromProject) {
      var projName = (App.tProj(fromProject).name) || '';
      msg = App.i18n('You are viewing the pinned version {pinned} from project "{project}". The latest version is {latest}.')
        .replace('{pinned}', selectedSnapshotVersion).replace('{project}', projName).replace('{latest}', latest);
    } else {
      msg = App.i18n('You are viewing the pinned version {pinned}. The latest version is {latest}.')
        .replace('{pinned}', selectedSnapshotVersion).replace('{latest}', latest);
    }
    banner.querySelector('.cs-version-banner-text').textContent = msg;
    banner.style.display = '';
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
    selectedSnapshotVersion = null;
    selectedVersionMissing = false;
    selectedFromProjectId = null;
    var banner = document.getElementById('cs-version-banner');
    if (banner) banner.style.display = 'none';
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
        preview.innerHTML = App.renderMarkdown(md);
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
    var url = App.githubEdit('concept_sets/' + selectedConceptSet.id + '.json');
    window.open(url, '_blank');
  }

  // ==================== VERSION MODAL ====================
  // Suggest a minor bump: 1.0.0 -> 1.1.0 (patch resets to 0).
  function suggestNextVersion(version) {
    var parts = (version || '1.0.0').split('.');
    if (parts.length === 3) {
      var minor = parseInt(parts[1], 10) + 1;
      return parts[0] + '.' + (isNaN(minor) ? 1 : minor) + '.0';
    }
    return version || '1.1.0';
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
        '<td style="white-space:nowrap; font-weight:600">' + App.escapeHtml(v.version || '') + '</td>' +
        '<td>' + App.escapeHtml(v.message || v.summary || '') + '</td>' +
        '<td style="white-space:nowrap; color:var(--text-muted); font-size:12px">' + App.escapeHtml(v.date || '') + '</td>' +
        '</tr>';
    }).join('');
    body.innerHTML = '<table class="data-table" style="width:100%; font-size:13px"><thead><tr>' +
      '<th style="white-space:nowrap">' + App.escapeHtml(App.i18n('Version')) + '</th>' +
      '<th>' + App.escapeHtml(App.i18n('Message')) + '</th>' +
      '<th style="white-space:nowrap">' + App.escapeHtml(App.i18n('Date')) + '</th>' +
      '</tr></thead><tbody>' + rows + '</tbody></table>';
  }

  function openVersionModal() {
    if (!selectedConceptSet || selectedSnapshotVersion) return;
    document.getElementById('cs-version-input').value = suggestNextVersion(selectedConceptSet.version);
    document.getElementById('cs-version-message').value = '';
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
    if (!/^\d+\.\d+\.\d+$/.test(newVersion)) {
      App.showToast(App.i18n('Invalid version format — use X.Y.Z (e.g., 1.1.0).'), 'error');
      return;
    }
    var message = document.getElementById('cs-version-message').value.trim();

    // Add to version history. Schema: { version, date, author, message } —
    // matches the convention used across the repo (metadata.versions[]).
    if (!selectedConceptSet.metadata) selectedConceptSet.metadata = {};
    if (!selectedConceptSet.metadata.versions) selectedConceptSet.metadata.versions = [];
    var prof = App.getUserProfile() || {};
    var authorName = [prof.firstName, prof.lastName].filter(Boolean).join(' ');
    selectedConceptSet.metadata.versions.push({
      version: newVersion,
      date: new Date().toISOString().slice(0, 10),
      author: authorName,
      message: message
    });

    selectedConceptSet.version = newVersion;
    App.stampModified(selectedConceptSet);
    App.updateConceptSet(selectedConceptSet);
    refreshDetailBadges();
    closeVersionModal();
    App.showToast(App.i18n('Version updated to ') + newVersion);
  }

  // ==================== STATUS MODAL ====================
  function openStatusModal() {
    if (!selectedConceptSet || selectedSnapshotVersion) return;
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
    App.stampModified(selectedConceptSet);
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
      '<span class="version-badge" id="cs-badge-version">' + App.escapeHtml(cs.version || '1.0.0') + '</span>' +
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

  var exportPreviewCopyResetTimer = null;

  function resetExportCopyBtn() {
    var btn = document.getElementById('export-preview-copy-btn');
    if (!btn) return;
    btn.classList.remove('copied');
    btn.innerHTML = '<i class="fas fa-clipboard"></i> <span data-i18n="Copy to clipboard">' + App.i18n('Copy to clipboard') + '</span>';
  }

  function markExportCopyBtnCopied() {
    var btn = document.getElementById('export-preview-copy-btn');
    if (!btn) return;
    btn.classList.add('copied');
    btn.innerHTML = '<i class="fas fa-check"></i> <span>' + App.i18n('Copied to clipboard!') + '</span>';
    if (exportPreviewCopyResetTimer) clearTimeout(exportPreviewCopyResetTimer);
    exportPreviewCopyResetTimer = setTimeout(resetExportCopyBtn, 2000);
  }

  function showExportPreview(content, aceMode, opts) {
    document.getElementById('export-step-method').style.display = 'none';
    document.getElementById('export-step-format').style.display = 'none';
    document.getElementById('export-step-preview').style.display = '';
    document.getElementById('cs-export-back').style.display = 'none';
    var modal = document.querySelector('#cs-export-modal .modal');
    modal.classList.add('export-preview-mode');

    // Hide SQL unit row unless explicitly shown by caller
    var unitRow = document.getElementById('export-sql-unit-row');
    if (unitRow) unitRow.style.display = (opts && opts.showUnitRow) ? '' : 'none';

    resetExportCopyBtn();

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

  function updateExportPreviewContent(content) {
    if (!exportPreviewEditor) return;
    exportPreviewEditor.setValue(content, -1);
    exportPreviewEditor.resize();
    resetExportCopyBtn();
  }

  function showSqlExportPreview() {
    if (!selectedConceptSet) return;
    // Large resolved sets are deferred by build.py — fetch before building the SQL,
    // otherwise the export would claim "no standard resolved concepts available".
    var csId = selectedConceptSet.id;
    if (!selectedSnapshotVersion && App.resolvedDeferred[csId] && !App.resolvedIndex[csId]) {
      App.fetchResolved(csId).then(function() {
        if (selectedConceptSet && selectedConceptSet.id === csId) showSqlExportPreview();
      });
      return;
    }
    var select = document.getElementById('export-sql-unit-select');
    var hint = document.getElementById('export-sql-unit-hint');

    // Reset UI to loading
    select.innerHTML = '<option>' + App.i18n('Loading units...') + '</option>';
    select.disabled = true;
    if (hint) hint.textContent = '';

    showExportPreview('-- ' + App.i18n('Loading...'), 'sql', { showUnitRow: true });

    var unitIds = getAvailableReferenceUnits();
    if (unitIds.length === 0) {
      select.innerHTML = '<option>' + App.i18n('No reference unit available') + '</option>';
      select.disabled = true;
      if (hint) hint.textContent = App.i18n('No unit conversion defined for this concept set.');
      updateExportPreviewContent(buildOMOPSQL(null));
      return;
    }

    function renderOptions(unitEntries) {
      // unitEntries: [{ unitId, code, name }]
      // Remember labels so buildOMOPSQL can render "mg/dL (8749)" in comments.
      sqlExportUnitLabels = {};
      unitEntries.forEach(function(u) {
        var lbl = u.code || u.name;
        if (lbl) sqlExportUnitLabels[u.unitId] = lbl;
      });
      // Sort by code (fallback to id)
      unitEntries.sort(function(a, b) {
        var ak = (a.code || String(a.unitId)).toLowerCase();
        var bk = (b.code || String(b.unitId)).toLowerCase();
        return ak.localeCompare(bk);
      });
      var opts = unitEntries.map(function(u) {
        var label = u.code || u.name || ('concept_id=' + u.unitId);
        var title = u.name || u.code || '';
        return '<option value="' + u.unitId + '" title="' + App.escapeHtml(title) + '">' + App.escapeHtml(label) + '</option>';
      }).join('');
      select.innerHTML = opts;
      select.disabled = false;
      if (hint) hint.textContent = '';

      // Choose default: prefer the most common recommended unit among CS concepts
      var defaultUnitId = pickDefaultRefUnitId(unitEntries.map(function(u) { return u.unitId; }));
      if (defaultUnitId) select.value = String(defaultUnitId);

      updateExportPreviewContent(buildOMOPSQL(parseInt(select.value, 10)));
    }

    function finishWithMaps(codeMap, nameMap) {
      // Enrich from any runtime-filled fields on App.recommendedUnits / unitConversions
      App.recommendedUnits.forEach(function(ru) {
        if (ru.recommendedUnitConceptId) {
          if (!codeMap[ru.recommendedUnitConceptId] && ru.recommendedUnitCode) codeMap[ru.recommendedUnitConceptId] = ru.recommendedUnitCode;
          if (!nameMap[ru.recommendedUnitConceptId] && ru.recommendedUnitName) nameMap[ru.recommendedUnitConceptId] = ru.recommendedUnitName;
        }
      });
      App.unitConversions.forEach(function(conv) {
        if (conv.sourceUnitConceptId && !nameMap[conv.sourceUnitConceptId] && conv.sourceUnitName) nameMap[conv.sourceUnitConceptId] = conv.sourceUnitName;
        if (conv.targetUnitConceptId && !nameMap[conv.targetUnitConceptId] && conv.targetUnitName) nameMap[conv.targetUnitConceptId] = conv.targetUnitName;
      });
      var entries = unitIds.map(function(id) { return { unitId: id, code: codeMap[id] || '', name: nameMap[id] || '' }; });
      renderOptions(entries);
    }

    var vocabAvailable = (typeof VocabDB !== 'undefined' && VocabDB.isDatabaseReady);
    if (!vocabAvailable) { finishWithMaps({}, {}); return; }

    // Make sure the DB is mounted (it may be available in IndexedDB but not yet loaded this session).
    var readyPromise = VocabDB.isDatabaseReady().then(function(ready) {
      if (ready) return true;
      if (typeof VocabDB.remountFromStoredHandles === 'function') {
        return VocabDB.remountFromStoredHandles().then(function() {
          return VocabDB.isDatabaseReady();
        }).catch(function() { return false; });
      }
      return false;
    });

    readyPromise.then(function(ready) {
      if (!ready) {
        if (hint) hint.textContent = App.i18n('Load OHDSI vocabularies in Settings to see unit names.');
        finishWithMaps({}, {});
        return;
      }
      VocabDB.lookupConcepts(unitIds).then(function(rows) {
        var codeMap = {};
        var nameMap = {};
        (rows || []).forEach(function(r) { codeMap[r.concept_id] = r.concept_code; nameMap[r.concept_id] = r.concept_name; });
        finishWithMaps(codeMap, nameMap);
      }).catch(function() { finishWithMaps({}, {}); });
    });
  }

  function pickDefaultRefUnitId(candidateIds) {
    if (!selectedConceptSet || !candidateIds || candidateIds.length === 0) return null;
    var candSet = {};
    candidateIds.forEach(function(id) { candSet[id] = true; });
    var concepts = getSqlExportConcepts().filter(function(c) { return (c.domainId || '') === 'Measurement'; });
    var conceptIdSet = {};
    concepts.forEach(function(c) { conceptIdSet[c.conceptId] = true; });
    var counts = {};
    App.recommendedUnits.forEach(function(ru) {
      if (conceptIdSet[ru.conceptId] && candSet[ru.recommendedUnitConceptId]) {
        counts[ru.recommendedUnitConceptId] = (counts[ru.recommendedUnitConceptId] || 0) + 1;
      }
    });
    var best = null, bestCount = -1;
    Object.keys(counts).forEach(function(k) {
      if (counts[k] > bestCount) { best = parseInt(k, 10); bestCount = counts[k]; }
    });
    return best || candidateIds[0];
  }

  function exportStepMethod(method) {
    if (method === 'github') {
      // GitHub always uses INDICATE JSON — skip format step
      if (!selectedConceptSet) return;
      var json = buildIndicateJSON();
      navigator.clipboard.writeText(json).then(function() {
        App.showToast(App.i18n('JSON copied to clipboard! Paste it in the GitHub editor.'), 'success', 5000);
      }).catch(function() {});
      var url = App.githubEdit('concept_sets/' + selectedConceptSet.id + '.json');
      window.open(url, '_blank');
      closeExportModal();
      return;
    }
    if (method === 'sql') {
      if (!selectedConceptSet) return;
      showSqlExportPreview();
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
    cs.createdByTool = App.toolTag();
    App.stampModified(cs);
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

  function getSqlExportConcepts() {
    if (!selectedConceptSet) return [];
    var resolved = selectedSnapshotVersion
      ? App.getResolvedConceptSet(selectedConceptSet.id, selectedSnapshotVersion)
      : App.resolvedIndex[selectedConceptSet.id];
    if ((!resolved || resolved.length === 0) && resolvedCurrentConcepts.length > 0) {
      resolved = resolvedCurrentConcepts;
    }
    return (resolved || []).filter(function(c) { return c.standardConcept === 'S'; });
  }

  // Returns the set of candidate reference unit concept IDs for the current CS:
  // the union of recommended units for any concept in the set, plus any unit that
  // is a target of a conversion involving a concept in the set.
  function getAvailableReferenceUnits() {
    var concepts = getSqlExportConcepts().filter(function(c) { return (c.domainId || '') === 'Measurement'; });
    if (concepts.length === 0) return [];
    var conceptIds = {};
    concepts.forEach(function(c) { conceptIds[c.conceptId] = true; });
    var unitIdSet = {};
    App.recommendedUnits.forEach(function(ru) {
      if (conceptIds[ru.conceptId] && ru.recommendedUnitConceptId) {
        unitIdSet[ru.recommendedUnitConceptId] = true;
      }
    });
    App.unitConversions.forEach(function(conv) {
      if (conceptIds[conv.conceptId] && conv.targetUnitConceptId) unitIdSet[conv.targetUnitConceptId] = true;
    });
    return Object.keys(unitIdSet).map(function(k) { return parseInt(k, 10); });
  }

  function buildOMOPSQL(refUnitId) {
    var cs = selectedConceptSet;
    var tr = App.t(cs);
    var csName = tr.name || cs.name || 'Concept Set';
    var concepts = getSqlExportConcepts();

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

    // Build a unit_concept_id -> human label map. Prefer the short UCUM code
    // (e.g. "mg/dL") — falls back to the long concept name, then to the id.
    // Sources, in order: the SQL export UI (which may have populated labels
    // from VocabDB), then the enriched unit_conversions.json and
    // recommended_units.json (which now carry codes/names after the enrichment
    // script).
    var unitLabels = {};
    Object.keys(sqlExportUnitLabels || {}).forEach(function(k) {
      unitLabels[parseInt(k, 10)] = sqlExportUnitLabels[k];
    });
    App.unitConversions.forEach(function(conv) {
      if (conv.sourceUnitConceptId && !unitLabels[conv.sourceUnitConceptId]) {
        var sLbl = conv.sourceUnitCode || conv.sourceUnitName;
        if (sLbl) unitLabels[conv.sourceUnitConceptId] = sLbl;
      }
      if (conv.targetUnitConceptId && !unitLabels[conv.targetUnitConceptId]) {
        var tLbl = conv.targetUnitCode || conv.targetUnitName;
        if (tLbl) unitLabels[conv.targetUnitConceptId] = tLbl;
      }
    });
    App.recommendedUnits.forEach(function(ru) {
      if (ru.recommendedUnitConceptId && !unitLabels[ru.recommendedUnitConceptId]) {
        var label = ru.recommendedUnitCode || ru.recommendedUnitName;
        if (label) unitLabels[ru.recommendedUnitConceptId] = label;
      }
    });
    function unitLabel(id) {
      var n = parseInt(id, 10);
      var lbl = unitLabels[n];
      return lbl ? (lbl + ' (' + n + ')') : String(n);
    }

    // For each measurement concept, return the per-concept map
    // { srcUnitId -> { factor, offset } } of conversions that target the chosen
    // reference unit. Factors depend on the concept (e.g. molecular weight), so we
    // keep them separated by concept. Conversions are affine: target = factor*source + offset
    // (offset defaults to 0 for the common multiplicative case).
    // unit_conversions.json already stores both directions (A->B factor f, B->A factor 1/f)
    // as separate rows, so we only match rows where targetUnitConceptId === refUid.
    function getPerConceptConversions(domainConcepts, refUid) {
      var perConcept = {};
      domainConcepts.forEach(function(c) { perConcept[c.conceptId] = {}; });
      App.unitConversions.forEach(function(conv) {
        if (conv.targetUnitConceptId !== refUid) return;
        if (perConcept[conv.conceptId] !== undefined) {
          perConcept[conv.conceptId][conv.sourceUnitConceptId] = {
            factor: conv.conversionFactor,
            offset: conv.offset || 0
          };
        }
      });
      return perConcept;
    }

    // Render an affine conversion `value_as_number * factor (+|- offset)` for SQL.
    // Omits the multiplier when factor === 1 and the offset term when offset === 0.
    function conversionExpr(conv) {
      var f = conv.factor;
      var o = conv.offset || 0;
      var expr;
      if (f === 1) {
        expr = 'value_as_number';
      } else {
        expr = 'value_as_number * ' + f;
      }
      if (o > 0) expr += ' + ' + o;
      else if (o < 0) expr += ' - ' + Math.abs(o);
      return expr;
    }

    var lines = [];
    lines.push('-- ============================================================');
    lines.push('-- Concept Set: ' + csName + ' (ID: ' + cs.id + ')');
    lines.push('-- Generated by ' + App.toolTag());
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

      // For Measurement domain, rewrite value_as_number with unit conversion if
      // a reference unit is chosen. Factors depend on the concept, but if all
      // concepts in the set happen to share the same factor for a given
      // (srcUnit -> refUnit) pair, we collapse to a flat CASE on unit_concept_id.
      // Otherwise we fall back to a nested CASE (outer on measurement_concept_id,
      // inner on unit_concept_id) so each concept gets its own factor.
      // The resulting column keeps the standard OMOP name `value_as_number`.
      var valueAsNumberExpr = null;
      var unitConceptIdExpr = null;
      if (domain === 'Measurement' && refUnitId) {
        var perConcept = getPerConceptConversions(domainConcepts, refUnitId);

        // Collect all conversions seen per source unit, to detect ambiguity.
        // Two conversions are "the same" only if both factor and offset match.
        var convBySrc = {}; // srcUnitId -> { convKey -> {factor, offset} }
        domainConcepts.forEach(function(c) {
          var m = perConcept[c.conceptId] || {};
          Object.keys(m).forEach(function(srcUnitId) {
            if (!convBySrc[srcUnitId]) convBySrc[srcUnitId] = {};
            var conv = m[srcUnitId];
            convBySrc[srcUnitId][conv.factor + '|' + (conv.offset || 0)] = conv;
          });
        });
        var convertedSrcUnits = Object.keys(convBySrc).map(function(k) { return parseInt(k, 10); });
        var ambiguous = Object.keys(convBySrc).some(function(srcUnitId) {
          return Object.keys(convBySrc[srcUnitId]).length > 1;
        });
        // A concept set covers a single clinical variable (same analyte), so a
        // (srcUnit → refUnit) factor applies to the whole set — including
        // concepts that have no explicit row in the conversion table. The flat
        // CASE is therefore used unless the table itself holds CONTRADICTORY
        // factors for the same source unit (`ambiguous`), in which case we
        // switch per concept.

        // For the ambiguous path: group concepts sharing the exact same
        // conversion set, so the generated CASE has one branch per distinct
        // conversion — not one per concept. Concepts with no conversion get no
        // branch at all (the outer ELSE already keeps their raw value).
        var convGroups = [];
        (function() {
          var bySig = {};
          domainConcepts.forEach(function(c) {
            var m = perConcept[c.conceptId] || {};
            var srcIds = Object.keys(m).map(function(k) { return parseInt(k, 10); }).sort(function(a, b) { return a - b; });
            if (srcIds.length === 0) return;
            var sig = srcIds.map(function(u) { return u + ':' + m[u].factor + ':' + (m[u].offset || 0); }).join('|');
            if (!bySig[sig]) {
              bySig[sig] = { ids: [], names: [], srcIds: srcIds, map: m };
              convGroups.push(bySig[sig]);
            }
            bySig[sig].ids.push(c.conceptId);
            bySig[sig].names.push(c.conceptName);
          });
        })();

        if (!ambiguous) {
          // Flat CASE on unit_concept_id.
          var caseParts = [];
          caseParts.push('        -- Reference unit: ' + unitLabel(refUnitId));
          caseParts.push('        WHEN unit_concept_id = ' + refUnitId + ' THEN value_as_number');
          Object.keys(convBySrc).forEach(function(srcUnitId) {
            var conv = convBySrc[srcUnitId][Object.keys(convBySrc[srcUnitId])[0]];
            caseParts.push('        WHEN unit_concept_id = ' + parseInt(srcUnitId, 10) +
              ' THEN ' + conversionExpr(conv) +
              ' -- convert ' + unitLabel(srcUnitId) + ' -> ' + unitLabel(refUnitId));
          });
          valueAsNumberExpr = '    CASE\n' + caseParts.join('\n') +
            '\n        ELSE value_as_number -- unknown unit, no conversion available: value kept as-is (still in its original unit)' +
            '\n    END AS value_as_number';
        } else {
          // Nested CASE: one branch per group of concepts sharing the same conversions.
          var outerParts = [];
          outerParts.push('        -- Reference unit: ' + unitLabel(refUnitId));
          outerParts.push('        -- Conversions are concept-specific: switching per measurement_concept_id');
          convGroups.forEach(function(grp) {
            if (grp.ids.length === 1) {
              outerParts.push('        WHEN measurement_concept_id = ' + grp.ids[0] + ' THEN -- ' + grp.names[0]);
            } else {
              outerParts.push('        WHEN measurement_concept_id IN (');
              grp.ids.forEach(function(id, i) {
                outerParts.push('            ' + id + (i < grp.ids.length - 1 ? ',' : '') + ' -- ' + grp.names[i]);
              });
              outerParts.push('        ) THEN');
            }
            outerParts.push('            CASE');
            outerParts.push('                WHEN unit_concept_id = ' + refUnitId + ' THEN value_as_number');
            grp.srcIds.forEach(function(srcUnitId) {
              var conv = grp.map[srcUnitId];
              outerParts.push('                WHEN unit_concept_id = ' + srcUnitId +
                ' THEN ' + conversionExpr(conv) +
                ' -- convert ' + unitLabel(srcUnitId) + ' -> ' + unitLabel(refUnitId));
            });
            outerParts.push('                ELSE value_as_number -- unknown unit, no conversion: value kept as-is');
            outerParts.push('            END');
          });
          outerParts.push('        ELSE value_as_number -- no conversion for this concept: value kept as-is');
          valueAsNumberExpr = '    CASE\n' + outerParts.join('\n') +
            '\n    END AS value_as_number';
        }

        // When we convert value_as_number to the reference unit, the original
        // unit_concept_id no longer describes the value. Rewrite it to the
        // reference unit — but only for rows whose value was actually converted,
        // so the reported unit always matches the (possibly raw) value. Rows in
        // an unknown/non-convertible unit are left untouched in BOTH columns
        // (no data is dropped). A commented-out WHERE clause is added so the
        // user can instead filter those rows out for a fully-normalized result.
        if (convertedSrcUnits.length > 0) {
          var unitParts = [];
          if (!ambiguous) {
            unitParts.push('        WHEN unit_concept_id IN (' +
              [refUnitId].concat(convertedSrcUnits).join(', ') + ') THEN ' + refUnitId +
              ' -- normalized to reference unit ' + unitLabel(refUnitId));
          } else {
            unitParts.push('        -- Conversions are concept-specific: relabel only the (concept, unit) pairs actually converted');
            convGroups.forEach(function(grp) {
              var conceptCond = grp.ids.length === 1
                ? 'measurement_concept_id = ' + grp.ids[0]
                : 'measurement_concept_id IN (' + grp.ids.join(', ') + ')';
              unitParts.push('        WHEN ' + conceptCond +
                ' AND unit_concept_id IN (' + [refUnitId].concat(grp.srcIds).join(', ') + ') THEN ' + refUnitId);
            });
          }
          unitConceptIdExpr = '    CASE\n' + unitParts.join('\n') +
            '\n        ELSE unit_concept_id -- no conversion for this (concept, unit): kept as-is, value stays in its original unit\n' +
            '    END AS unit_concept_id';
        }
      } else if (domain === 'Measurement' && !refUnitId) {
        lines.push('-- Note: no reference unit selected — raw value_as_number returned without conversion.');
      }

      // Build the query. When we rewrite value_as_number / unit_concept_id via
      // CASE, skip the plain columns to avoid a duplicate name. The rewritten
      // expressions are appended in their original column position.
      lines.push('');
      lines.push('SELECT');
      var colLines = selectCols
        .map(function(col) {
          if (valueAsNumberExpr && col === 'value_as_number') return valueAsNumberExpr;
          if (unitConceptIdExpr && col === 'unit_concept_id') return unitConceptIdExpr;
          return '    ' + col;
        });
      lines.push(colLines.join(',\n'));

      lines.push('FROM ' + mapping.table);
      lines.push('WHERE ' + mapping.conceptCol + ' IN (');

      // Concept list with names as comments
      domainConcepts.forEach(function(c, idx) {
        var prefix = (idx === 0) ? '    ' : '   ,';
        lines.push(prefix + c.conceptId + ' -- ' + c.conceptName);
      });
      lines.push(')');

      // When conversions are applied, rows in a non-convertible unit are returned
      // with their raw value and original unit (nothing is dropped). Offer an
      // opt-in filter to exclude those rows for a fully-normalized result.
      if (unitConceptIdExpr) {
        lines.push('-- Optional: uncomment to drop rows whose unit cannot be converted to the reference unit');
        if (!ambiguous) {
          lines.push('-- AND unit_concept_id IN (' + [refUnitId].concat(convertedSrcUnits).join(', ') + ')');
        } else {
          lines.push('-- AND (unit_concept_id = ' + refUnitId);
          convGroups.forEach(function(grp) {
            var conceptCond = grp.ids.length === 1
              ? 'measurement_concept_id = ' + grp.ids[0]
              : 'measurement_concept_id IN (' + grp.ids.join(', ') + ')';
            lines.push('--      OR (' + conceptCond + ' AND unit_concept_id IN (' + grp.srcIds.join(', ') + '))');
          });
          lines.push('-- )');
        }
      }

      lines.push(';');
    });

    return lines.join('\n');
  }

  // `format` is 'indicate' or 'atlas' — the SQL export has its own flow
  // (exportStepMethod('sql') → showSqlExportPreview, which handles the
  // reference-unit selection that a direct buildOMOPSQL() call would skip).
  function executeExport(format) {
    if (!selectedConceptSet || !exportMethod) return;

    var content = (format === 'atlas') ? buildAtlasJSON() : buildIndicateJSON();
    var filename = selectedConceptSet.id + '.json';
    var mimeType = 'application/json';

    if (exportMethod === 'clipboard') {
      navigator.clipboard.writeText(content).then(function() {
        showExportPreview(content, 'json');
        markExportCopyBtnCopied();
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
    // Hide the category filter badges in edit mode to free up room for the
    // edit toolbar (Select all / Delete / Cancel / Save / Add).
    var cats = document.getElementById('cs-categories');
    if (cats) cats.style.display = selectionMode ? 'none' : '';

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
  // IDs the confirm modal will delete. Set from the selection (bulk) or a
  // single row's delete button.
  var pendingDeleteIds = null;

  function openDeleteConfirm() {
    if (selectedIds.size === 0) {
      App.showToast(App.i18n('No concept sets selected.'), 'warning');
      return;
    }
    pendingDeleteIds = Array.from(selectedIds);
    var n = selectedIds.size;
    var msg = App.i18n('Delete ') + n + App.i18n(n > 1 ? ' selected concept sets' : ' selected concept set') + '?';
    document.getElementById('cs-delete-confirm-msg').textContent = msg;
    document.getElementById('cs-delete-confirm-modal').style.display = 'flex';
  }

  // Single-row delete (the per-row trash button).
  function openSingleDeleteConfirm(id) {
    pendingDeleteIds = [id];
    document.getElementById('cs-delete-confirm-msg').textContent =
      App.i18n('Delete ') + 1 + App.i18n(' selected concept set') + '?';
    document.getElementById('cs-delete-confirm-modal').style.display = 'flex';
  }

  function closeDeleteConfirm() {
    document.getElementById('cs-delete-confirm-modal').style.display = 'none';
  }

  function executeDelete() {
    var ids = pendingDeleteIds || Array.from(selectedIds);
    var result = App.deleteConceptSets(ids);
    closeDeleteConfirm();
    pendingDeleteIds = null;
    // Drop any deleted ids from the current selection.
    ids.forEach(function(id) { selectedIds.delete(id); });
    updateSelectionCount();
    renderAll();
    if (result.deleted > 0) {
      App.showToast(result.deleted + App.i18n(result.deleted > 1 ? ' concept sets' : ' concept set') + App.i18n(' deleted.'), 'success');
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
    document.getElementById('cs-create-desc').value = trCur.shortDescription || '';
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
      App.stampModified(cs);
      if (!cs.metadata) cs.metadata = {};
      if (!cs.metadata.translations) cs.metadata.translations = {};
      if (!cs.metadata.translations.en) cs.metadata.translations.en = {};
      if (!cs.metadata.translations.fr) cs.metadata.translations.fr = {};
      if (App.lang === 'fr') {
        cs.metadata.translations.fr.name = name;
        cs.metadata.translations.en.name = cs.metadata.translations.en.name || name;
        cs.metadata.translations.fr.shortDescription = desc || null;
      } else {
        cs.metadata.translations.en.name = name;
        cs.metadata.translations.fr.name = cs.metadata.translations.fr.name || name;
        cs.metadata.translations.en.shortDescription = desc || null;
      }
      cs.name = cs.metadata.translations.en.name;
      cs.description = cs.metadata.translations.en.shortDescription || null;
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

    var enShort = App.lang === 'en' ? (desc || null) : null;
    var frShort = App.lang === 'fr' ? (desc || null) : null;
    var cs = {
      id: App.nextConceptSetId(),
      name: name,
      description: enShort,
      version: '1.0.0',
      createdBy: authorName,
      createdDate: today,
      modifiedBy: authorName,
      modifiedDate: today,
      createdByTool: App.toolTag(),
      expression: { items: [] },
      tags: [],
      metadata: {
        uniqueId: crypto.randomUUID(),
        organization: App.getOrganization() || App.config.organization || { name: '', url: '' },
        reviewStatus: 'draft',
        origin: null,
        translations: {
          en: { name: name, category: r.catEn, subcategory: r.subcatEn, shortDescription: enShort, longDescription: null },
          fr: { name: name, category: r.catFr, subcategory: r.subcatFr, shortDescription: frShort, longDescription: null }
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
    // Version snapshot banner: "View latest version" action.
    // Navigate FIRST and let the hashchange render the latest version: pushing
    // a new history entry keeps the pinned-version URL in history, so the
    // browser Back button returns to it. (Rendering before navigating would
    // not work: showCSDetail's replaceState overwrites the pinned entry, and
    // the subsequent navigate becomes a same-hash no-op.)
    var bannerLatest = document.getElementById('cs-version-banner-latest');
    if (bannerLatest) {
      bannerLatest.addEventListener('click', function(e) {
        e.preventDefault();
        if (!selectedConceptSet) return;
        Router.navigate('/concept-sets', { id: selectedConceptSet.id });
      });
    }

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
      syncCategoryFilterToUrl();
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

    // Resolved table sort
    document.getElementById('resolved-table').querySelector('thead').addEventListener('click', function(e) {
      var th = e.target.closest('th[data-sort]');
      if (!th) return;
      var key = th.dataset.sort;
      if (resolvedSort.key === key) resolvedSort.asc = !resolvedSort.asc;
      else { resolvedSort.key = key; resolvedSort.asc = true; }
      resolvedPage = 1;
      renderResolvedTable(true);
    });

    // Expression table sort
    document.getElementById('expression-table').querySelector('thead').addEventListener('click', function(e) {
      var th = e.target.closest('th[data-sort]');
      if (!th) return;
      var key = th.dataset.sort;
      if (exprSort.key === key) exprSort.asc = !exprSort.asc;
      else { exprSort.key = key; exprSort.asc = true; }
      expressionPage = 1;
      renderExpressionTable();
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
      // Delete button click (checked before edit — it shares .cs-row-edit-btn)
      var delBtn = e.target.closest('.cs-row-delete-btn');
      if (delBtn) {
        e.stopPropagation();
        openSingleDeleteConfirm(parseInt(delBtn.dataset.deleteId));
        return;
      }
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

    // CS back button — always return to the concept sets list, regardless of how
    // the detail view was reached. Using history.back() is unreliable: if the user
    // got here via another page (e.g. Documentation -> "Data Dictionary" restoring
    // the remembered detail hash), the previous history entry is that other page,
    // not the list. Navigating explicitly to the list view is the intended behaviour.
    document.getElementById('cs-back').addEventListener('click', function() {
      confirmDiscardThen(function() { Router.navigate('/concept-sets'); });
    });

    // Unsaved-changes modal: confirm discards edits then runs the pending action.
    document.getElementById('cs-unsaved-close').addEventListener('click', closeUnsavedModal);
    document.getElementById('cs-unsaved-cancel').addEventListener('click', closeUnsavedModal);
    document.getElementById('cs-unsaved-modal').addEventListener('click', function(e) {
      if (e.target === this) closeUnsavedModal();
    });
    document.getElementById('cs-unsaved-ok').addEventListener('click', function() {
      var action = pendingDiscardAction;
      document.getElementById('cs-unsaved-modal').style.display = 'none';
      pendingDiscardAction = null;
      cancelEdits();
      if (action) action();
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
    // Expression-toolbar Cancel/Save mirror the header ones (same handlers).
    document.getElementById('expr-edit-cancel-btn').addEventListener('click', cancelEdits);
    document.getElementById('expr-edit-save-btn').addEventListener('click', saveEdits);
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

    // Expression delete confirmation modal
    document.getElementById('expr-delete-close').addEventListener('click', closeExprDeleteConfirm);
    document.getElementById('expr-delete-cancel').addEventListener('click', closeExprDeleteConfirm);
    document.getElementById('expr-delete-modal').addEventListener('click', function(e) {
      if (e.target === this) closeExprDeleteConfirm();
    });
    document.getElementById('expr-delete-ok').addEventListener('click', function() {
      var action = pendingExprDelete;
      document.getElementById('expr-delete-modal').style.display = 'none';
      pendingExprDelete = null;
      if (action) action();
    });

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
        // When exclude flips, the descendants/mapped toggles in the same row
        // recolor (red when excluded). Update their class IN PLACE rather than
        // re-rendering the whole table — a full re-render rebuilds the DOM, so
        // the exclude toggle would jump to its new state with no slide
        // transition. Toggling the class keeps the CSS .2s slide on all three.
        if (field === 'isExcluded') {
          var row = input.closest('tr');
          if (row) {
            row.querySelectorAll('input[data-field="includeDescendants"], input[data-field="includeMapped"]').forEach(function(cb) {
              cb.closest('.toggle-switch').classList.toggle('toggle-exclude', input.checked);
            });
          }
        }
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
    // Add concepts: column sort (click a header cell). Only the label row has
    // data-sort; the filter row below it doesn't, so its inputs are unaffected.
    document.getElementById('expr-add-results-table').querySelector('thead').addEventListener('click', function(e) {
      var th = e.target.closest('th[data-sort]');
      if (!th) return;
      if (addSort.key === th.dataset.sort) addSort.asc = !addSort.asc;
      else { addSort.key = th.dataset.sort; addSort.asc = true; }
      applyAddColumnFilters();
    });
    App.initColResize('expr-add-results-table');

    // Resolved concept row click -> concept detail (fresh navigation, reset history)
    document.getElementById('resolved-tbody').addEventListener('click', function(e) {
      var tr = e.target.closest('tr[data-idx]');
      if (!tr || !selectedConceptSet) return;
      var idx = parseInt(tr.dataset.idx);
      if (resolvedCurrentConcepts[idx]) {
        conceptDetailHistory = [];
        showResolvedConceptDetail(resolvedCurrentConcepts[idx]);
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
    ['expr-filter-domain', 'expr-filter-class', 'expr-filter-exclude', 'expr-filter-descendants', 'expr-filter-mapped'].forEach(function(id) {
      document.getElementById(id).addEventListener('change', function() { expressionPage = 1; renderExpressionTable(); });
    });
    ['expr-filter-conceptId', 'expr-filter-name', 'expr-filter-code'].forEach(function(id) {
      document.getElementById(id).addEventListener('input', function() { expressionPage = 1; renderExpressionTable(); });
    });

    // Resolved table pagination
    document.getElementById('resolved-page-buttons').addEventListener('click', function(e) {
      handlePageClick(e, (function() {
        var filters = getResolvedFilters();
        return filterResolvedConcepts(resolvedCurrentConcepts, filters).length;
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
    document.getElementById('export-sql-unit-select').addEventListener('change', function() {
      var val = parseInt(this.value, 10);
      if (!isNaN(val)) updateExportPreviewContent(buildOMOPSQL(val));
    });
    document.getElementById('export-preview-copy-btn').addEventListener('click', function() {
      if (!exportPreviewEditor) return;
      var content = exportPreviewEditor.getValue();
      navigator.clipboard.writeText(content).then(function() {
        markExportCopyBtnCopied();
      }).catch(function() {
        App.showToast(App.i18n('Could not copy to clipboard.'), 'error');
      });
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

    // Review table: click a row to view the full review (rendered Markdown)
    document.getElementById('cs-review-tbody').addEventListener('click', function(e) {
      var tr = e.target.closest('tr[data-review-idx]');
      if (tr) openReviewViewModal(parseInt(tr.dataset.reviewIdx, 10));
    });
    document.getElementById('cs-review-view-close').addEventListener('click', closeReviewViewModal);
    document.getElementById('cs-review-view-modal').addEventListener('click', function(e) {
      if (e.target === document.getElementById('cs-review-view-modal')) closeReviewViewModal();
      // Outdated-version badge: navigate to the pinned version (href) and close.
      if (e.target.closest('.review-version-badge.outdated')) closeReviewViewModal();
    });

    // Review table: column filters + sorting
    ['review-filter-reviewer', 'review-filter-date', 'review-filter-version', 'review-filter-comments'].forEach(function(id) {
      document.getElementById(id).addEventListener('input', renderReviewTable);
    });
    document.getElementById('review-filter-status').addEventListener('change', renderReviewTable);
    document.querySelectorAll('#cs-review-table th[data-sort]').forEach(function(th) {
      th.addEventListener('click', function(e) {
        if (e.target.closest('.filter-row') || e.target.tagName === 'INPUT' || e.target.tagName === 'SELECT') return;
        var key = th.dataset.sort;
        if (reviewSort.key === key) reviewSort.asc = !reviewSort.asc;
        else reviewSort = { key: key, asc: key !== 'date' };
        renderReviewTable();
      });
    });

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

    // Header logo/title: warn if unsaved edits, then go to list.
    // Returning false blocks the synchronous navigation; the clean modal then
    // drives the actual navigation on confirm.
    App.onBeforeNavigate(function() {
      if (hasUnsavedChanges()) {
        confirmDiscardThen(function() { Router.navigate('/concept-sets'); });
        return false;
      }
      // No real changes: drop edit mode silently and let navigation proceed.
      if (isAnyEditMode()) cancelEdits();
    });
    App.onHome(function() {
      if (selectedConceptSet) Router.navigate('/concept-sets');
    });

    // Column resizing
    App.initColResize('cs-table');
    App.initColResize('resolved-table');
    App.initColResize('expression-table');
    App.initColResize('cs-review-table');
  }

  // ==================== PAGE MODULE ====================
  function init() {
    if (initialized) return;
    initialized = true;
    initEvents();
    renderAll();
  }

  // Seed csCategories from ?category=A,B in the URL. Only categories that
  // actually exist in the current data are kept (an unknown slug is ignored so
  // it can't silently filter everything out). Returns true if it changed state.
  function applyCategoryFilterFromUrl(query) {
    var raw = query && query.category;
    if (raw == null) return false;
    var wanted = String(raw).split(',').map(function(s) { return s.trim(); }).filter(Boolean);
    var valid = new Set(App.getCSData().map(function(d) { return d.category; }));
    var next = new Set();
    wanted.forEach(function(c) { if (valid.has(c)) next.add(c); });
    // No change → don't touch (avoids clobbering an in-session filter on a
    // same-page hashchange that didn't carry a category param).
    if (next.size === csCategories.size) {
      var same = true;
      next.forEach(function(c) { if (!csCategories.has(c)) same = false; });
      if (same) return false;
    }
    csCategories = next;
    csPage = 1;
    return true;
  }

  // Reflect the active category badges into the URL (?category=A,B), without
  // adding a history entry, so the current filter is shareable/bookmarkable.
  function syncCategoryFilterToUrl() {
    if (selectedConceptSet) return; // detail view owns the URL
    var url = '#/concept-sets';
    if (csCategories.size > 0) {
      url += '?category=' + encodeURIComponent(Array.from(csCategories).join(','));
    }
    Router.replaceState(url);
  }

  function show(query) {
    init();
    // Shareable category filter: ?category=Conditions,Vitals seeds the active
    // category badges from the URL. Values are the (language-specific) category
    // labels, comma-separated. Only applied to the list view (not a detail id).
    var catChanged = applyCategoryFilterFromUrl(query);
    var csId = query && (query.id || query.cs);
    if (csId) {
      showCSDetail(parseInt(csId), {
        version: query && query.version,
        from: query && query.from,
        projectId: query && query.projectId
      });
      var tab = query && query.tab;
      if (tab && ['concepts', 'comments', 'statistics', 'review'].indexOf(tab) !== -1) {
        switchCSDetailTab(tab);
      }
    } else if (selectedConceptSet) {
      // Back to list view (e.g. browser back button)
      hideCSDetail();
      if (catChanged) renderAll();
    } else if (catChanged) {
      // Bare list view whose category filter came from the URL: re-render so the
      // seeded badges + filtered rows reflect it (init's renderAll ran first).
      renderAll();
    }
    // else: bare list view, nothing extra to do (renderAll already ran in init)
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
    csFilterReviewStatusDefaulted = false;
    csFilterName = '';
    document.getElementById('filter-name').value = '';
    csPage = 1;
    renderAll();
    if (selectedConceptSet) {
      var savedTab = csDetailTab;
      var savedMode = csConceptMode;
      var opts = selectedSnapshotVersion
        ? { version: selectedSnapshotVersion, from: selectedFromProjectId ? 'project' : null, projectId: selectedFromProjectId }
        : undefined;
      showCSDetail(selectedConceptSet.id, opts);
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

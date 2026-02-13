// concept-sets.js — Concept Sets page logic
(function() {
  'use strict';

  var GITHUB_REPO = 'indicate-eu/data-dictionary-content';

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
      return '<tr data-id="' + d.id + '">' +
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
    btns += '<button ' + (csPage <= 1 ? 'disabled' : '') + ' data-page="prev">&laquo;</button>';
    var maxButtons = 7;
    var startPage = Math.max(1, csPage - Math.floor(maxButtons / 2));
    var endPage = Math.min(totalPages, startPage + maxButtons - 1);
    if (endPage - startPage < maxButtons - 1) startPage = Math.max(1, endPage - maxButtons + 1);
    for (var i = startPage; i <= endPage; i++) {
      btns += '<button ' + (i === csPage ? 'class="active"' : '') + ' data-page="' + i + '">' + i + '</button>';
    }
    btns += '<button ' + (csPage >= totalPages ? 'disabled' : '') + ' data-page="next">&raquo;</button>';
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

  function switchConceptMode(mode) {
    csConceptMode = mode;
    document.querySelectorAll('#cs-concept-toggle-bar .toggle-btn').forEach(function(btn) {
      btn.classList.toggle('active', btn.dataset.mode === mode);
    });
    document.getElementById('cs-expression-view').style.display = (mode === 'expression') ? '' : 'none';
    document.getElementById('cs-resolved-view').style.display = (mode === 'resolved') ? '' : 'none';
    buildColVisDropdown();
    if (mode === 'expression') renderExpressionTable();
    else renderResolvedTable();
  }

  // ==================== EXPRESSION TABLE ====================
  function renderExpressionTable() {
    if (!selectedConceptSet) return;
    var items = (selectedConceptSet.expression && selectedConceptSet.expression.items) || [];
    document.getElementById('cs-concept-count').textContent = items.length;
    var tbody = document.getElementById('expression-tbody');
    if (items.length === 0) {
      tbody.innerHTML = '<tr><td colspan="8" class="empty-state"><p>No concepts in this concept set</p></td></tr>';
      return;
    }
    tbody.innerHTML = items.map(function(item, i) {
      var c = item.concept;
      return '<tr data-idx="' + i + '">' +
        '<td>' + App.escapeHtml(c.vocabularyId) + '</td>' +
        '<td>' + App.escapeHtml(c.conceptName) + '</td>' +
        '<td>' + App.escapeHtml(c.conceptCode) + '</td>' +
        '<td>' + App.escapeHtml(c.domainId) + '</td>' +
        '<td class="td-center">' + App.standardBadge(c) + '</td>' +
        '<td class="td-center">' + (item.isExcluded ? '<span class="flag-yes-danger">Yes</span>' : '<span class="flag-no">No</span>') + '</td>' +
        '<td class="td-center">' + (item.includeDescendants ? '<span class="' + (item.isExcluded ? 'flag-yes-danger' : 'flag-yes') + '">Yes</span>' : '<span class="flag-no">No</span>') + '</td>' +
        '<td class="td-center">' + (item.includeMapped ? '<span class="' + (item.isExcluded ? 'flag-yes-danger' : 'flag-yes') + '">Yes</span>' : '<span class="flag-no">No</span>') + '</td>' +
        '</tr>';
    }).join('');
    applyColumnVisibility();
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
    keys.forEach(function(col) {
      var vis = cols[col].visible;
      table.querySelectorAll('[data-col="' + col + '"]').forEach(function(el) {
        el.style.display = vis ? '' : 'none';
      });
      var colIndex = keys.indexOf(col);
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
      renderResolvedTable(true);
    });

    fillSelect('resolved-filter-domain', domains);

    var stdValues = Object.keys(standards).sort();
    var stdLabels = {};
    stdValues.forEach(function(v) { stdLabels[v] = standards[v]; });
    App.buildMultiSelectDropdown('resolved-filter-standard', stdValues, resolvedFilterStandard, function() {
      renderResolvedTable(true);
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
      return;
    }
    if (concepts.length === 0) {
      tbody.innerHTML = '<tr><td colspan="' + colCount + '" class="empty-state"><p>No concepts match the current filters.</p></td></tr>';
      applyColumnVisibility();
      return;
    }
    tbody.innerHTML = concepts.map(function(c) {
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

  function showResolvedConceptDetail(concept) {
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

    el.innerHTML =
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

    // Show/hide GitHub propose button
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

    switchCSDetailTab('concepts');
    switchConceptMode('resolved');

    renderCommentsTab(cs);
    renderStatisticsTab(cs);
    renderReviewTab(cs);
  }

  function hideCSDetail() {
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
    document.getElementById('export-back').style.display = 'none';
    document.getElementById('export-modal').style.display = 'flex';
  }

  function closeExportModal() {
    document.getElementById('export-modal').style.display = 'none';
  }

  function exportStepMethod(method) {
    exportMethod = method;
    document.getElementById('export-step-method').style.display = 'none';
    document.getElementById('export-step-format').style.display = '';
    document.getElementById('export-back').style.display = '';
  }

  function exportStepBack() {
    exportMethod = null;
    document.getElementById('export-step-method').style.display = '';
    document.getElementById('export-step-format').style.display = 'none';
    document.getElementById('export-back').style.display = 'none';
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

  // ==================== LANGUAGE CHANGE CALLBACK ====================
  window.onLanguageChange = function() {
    csCategories.clear();
    csSubcategories.clear();
    csFilterReviewStatus.clear();
    csFilterName = '';
    document.getElementById('filter-name').value = '';
    csPage = 1;
    renderAll();
    if (selectedConceptSet) showCSDetail(selectedConceptSet.id);
  };

  // ==================== EVENTS ====================
  function initEvents() {
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
      if (p === 'prev') csPage--;
      else if (p === 'next') csPage++;
      else csPage = parseInt(p);
      renderCSTable();
    });

    // CS table row click -> detail
    document.getElementById('cs-tbody').addEventListener('click', function(e) {
      var tr = e.target.closest('tr[data-id]');
      if (!tr) return;
      showCSDetail(parseInt(tr.dataset.id));
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

    // Resolved concept row click -> concept detail
    document.getElementById('resolved-tbody').addEventListener('click', function(e) {
      var tr = e.target.closest('tr[data-idx]');
      if (!tr || !selectedConceptSet) return;
      var concepts = App.resolvedIndex[selectedConceptSet.id] || [];
      var idx = parseInt(tr.dataset.idx);
      if (concepts[idx]) showResolvedConceptDetail(concepts[idx]);
    });

    // Resolved table filters
    ['resolved-filter-domain', 'resolved-filter-class'].forEach(function(id) {
      document.getElementById(id).addEventListener('change', function() { renderResolvedTable(true); });
    });
    ['resolved-filter-conceptId', 'resolved-filter-name', 'resolved-filter-code'].forEach(function(id) {
      document.getElementById(id).addEventListener('input', function() { renderResolvedTable(true); });
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
    document.addEventListener('click', function(e) {
      var dd = document.getElementById('col-vis-dropdown');
      if (dd.style.display !== 'none' && !e.target.closest('#col-vis-wrapper')) {
        dd.style.display = 'none';
      }
    });

    // Export modal events
    document.getElementById('cs-export-json').addEventListener('click', openExportModal);
    document.getElementById('export-modal-close').addEventListener('click', closeExportModal);
    document.getElementById('export-cancel').addEventListener('click', closeExportModal);
    document.getElementById('export-back').addEventListener('click', exportStepBack);
    document.getElementById('export-modal').addEventListener('click', function(e) {
      if (e.target === document.getElementById('export-modal')) closeExportModal();
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

    // Keyboard: Escape
    document.addEventListener('keydown', function(e) {
      if (e.key === 'Escape') {
        if (document.getElementById('confirm-reset-modal').style.display !== 'none') {
          document.getElementById('confirm-reset-modal').style.display = 'none';
        } else if (document.getElementById('export-modal').style.display !== 'none') {
          closeExportModal();
        } else if (document.getElementById('profile-modal').style.display !== 'none') {
          App.closeProfileModal();
        } else if (document.getElementById('review-modal').classList.contains('visible')) {
          closeReviewModal();
        } else if (selectedConceptSet) {
          hideCSDetail();
        }
      }
    });
  }

  // ==================== INIT ====================
  App.updateUserBadge();
  App.initSharedEvents();
  initEvents();
  App.loadData(function() {
    renderAll();
    var params = new URLSearchParams(window.location.search);
    var csId = params.get('cs');
    if (csId) showCSDetail(parseInt(csId));
  });
})();

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

  // Selection mode state
  var selectionMode = false;
  var selectedIds = new Set();

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

    // Append vocab tabs if DuckDB is ready, or show a hint
    if (typeof VocabDB !== 'undefined') {
      VocabDB.isDatabaseReady().then(function(ready) {
        if (ready) {
          renderVocabTabs(concept, el);
        } else {
          var hint = document.createElement('div');
          hint.style.cssText = 'margin-top:16px; padding:12px 16px; background:#f8f9fa; border:1px solid #e0e0e0; border-radius:6px; font-size:13px; color:#666';
          hint.innerHTML = '<i class="fas fa-info-circle" style="color:var(--primary); margin-right:6px"></i>' +
            'Load OHDSI vocabularies in <a href="#/general-settings" style="color:var(--primary); font-weight:600">General Settings</a> ' +
            'to view related concepts, hierarchy, and synonyms.';
          el.appendChild(hint);
        }
      });
    }
  }

  // ==================== VOCAB TABS (Related / Hierarchy / Synonyms) ====================
  var vocabTabsHierarchyNetwork = null;

  function renderVocabTabs(concept, containerEl) {
    var tabsHtml =
      '<div class="concept-vocab-tab-bar">' +
        '<button class="concept-vocab-tab active" data-vtab="related">Related</button>' +
        '<button class="concept-vocab-tab" data-vtab="hierarchy">Hierarchy</button>' +
        '<button class="concept-vocab-tab" data-vtab="synonyms">Synonyms</button>' +
      '</div>' +
      '<div class="concept-vocab-content" id="vtab-related"></div>' +
      '<div class="concept-vocab-content" id="vtab-hierarchy" style="display:none"></div>' +
      '<div class="concept-vocab-content" id="vtab-synonyms" style="display:none"></div>';

    var wrapper = document.createElement('div');
    wrapper.innerHTML = tabsHtml;
    containerEl.appendChild(wrapper);

    // Tab switching
    var tabs = wrapper.querySelectorAll('.concept-vocab-tab');
    var loaded = {};
    for (var i = 0; i < tabs.length; i++) {
      tabs[i].addEventListener('click', function() {
        var vtab = this.getAttribute('data-vtab');
        for (var j = 0; j < tabs.length; j++) tabs[j].classList.toggle('active', tabs[j] === this);
        ['related', 'hierarchy', 'synonyms'].forEach(function(t) {
          var el = document.getElementById('vtab-' + t);
          if (el) el.style.display = (t === vtab) ? '' : 'none';
        });
        if (!loaded[vtab]) {
          loaded[vtab] = true;
          if (vtab === 'hierarchy') loadHierarchyGraph(concept.conceptId, document.getElementById('vtab-hierarchy'));
          if (vtab === 'synonyms') loadSynonyms(concept.conceptId, document.getElementById('vtab-synonyms'));
        }
      });
    }

    // Load related by default
    loaded.related = true;
    loadRelatedConcepts(concept.conceptId, document.getElementById('vtab-related'));
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

    // Click row to navigate
    relatedEl.querySelector('tbody').addEventListener('click', function(e) {
      var tr = e.target.closest('tr[data-cid]');
      if (!tr) return;
      var cid = parseInt(tr.getAttribute('data-cid'));
      VocabDB.lookupConcepts([cid]).then(function(concepts) {
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
    });
  }

  var HIERARCHY_MAX_LEVELS = 5;
  var HIERARCHY_WARN_THRESHOLD = 100;

  function loadHierarchyGraph(conceptId, el) {
    el.innerHTML = '<div class="loading-inline"><i class="fas fa-spinner fa-spin"></i> Loading hierarchy...</div>';

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
        el.innerHTML =
          '<div class="loading-inline" style="text-align:left">' +
          '<i class="fas fa-exclamation-triangle" style="color:var(--warning)"></i> ' +
          'This concept has <strong>' + total + '</strong> nodes in the hierarchy (' + HIERARCHY_MAX_LEVELS + ' levels). ' +
          'Loading may be slow.' +
          '<br><button class="btn-outline-sm" id="hierarchy-load-anyway" style="margin-top:8px">' +
          '<i class="fas fa-project-diagram"></i> Load anyway</button></div>';
        document.getElementById('hierarchy-load-anyway').addEventListener('click', function() {
          el.innerHTML = '<div class="loading-inline"><i class="fas fa-spinner fa-spin"></i> Loading hierarchy...</div>';
          buildHierarchyGraph(conceptId, el);
        });
        return;
      }
      buildHierarchyGraph(conceptId, el);
    }).catch(function(err) {
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

  function conceptTooltip(c) {
    var std = c.standard_concept === 'S' ? 'Standard' : (c.standard_concept || 'Non-standard');
    return c.concept_name + ' [' + c.vocabulary_id + ']\n' +
      'ID: ' + c.concept_id + ' | Code: ' + (c.concept_code || '') + '\n' +
      'Domain: ' + (c.domain_id || '') + ' | Class: ' + (c.concept_class_id || '') + '\n' +
      'Standard: ' + std;
  }

  function renderHierarchyNetwork(self, ancestors, descendants, edgeRows, el) {
    el.innerHTML = '<div id="hierarchy-graph-container" style="height:400px; border:1px solid #eee; border-radius:6px"></div>';

    var nodes = [];
    var edges = [];
    var selfId = Number(self.concept_id);

    // Self node (level 0)
    nodes.push({
      id: selfId,
      label: self.concept_name + '\n[' + self.vocabulary_id + ']',
      title: conceptTooltip(self),
      level: 0,
      shape: 'box',
      color: { background: '#0f60af', border: '#0a4a8a' },
      font: { color: '#fff', size: 12 },
      widthConstraint: { minimum: 140, maximum: 220 }
    });

    // Ancestor nodes (negative levels)
    ancestors.forEach(function(a) {
      var aid = Number(a.concept_id);
      nodes.push({
        id: aid,
        label: a.concept_name + '\n[' + a.vocabulary_id + ']',
        title: conceptTooltip(a),
        level: Number(a.hierarchy_level), // negative
        shape: 'box',
        color: { background: '#6c757d', border: '#555' },
        font: { color: '#fff', size: 11 },
        widthConstraint: { minimum: 140, maximum: 220 }
      });
    });

    // Descendant nodes (positive levels)
    descendants.forEach(function(d) {
      var did = Number(d.concept_id);
      nodes.push({
        id: did,
        label: d.concept_name + '\n[' + d.vocabulary_id + ']',
        title: conceptTooltip(d),
        level: Number(d.hierarchy_level), // positive
        shape: 'box',
        color: { background: '#28a745', border: '#1e7e34' },
        font: { color: '#fff', size: 11 },
        widthConstraint: { minimum: 140, maximum: 220 }
      });
    });

    // Edges from the direct parent-child query
    edgeRows.forEach(function(e) {
      edges.push({ from: Number(e.from_id), to: Number(e.to_id), arrows: 'to' });
    });

    var container = document.getElementById('hierarchy-graph-container');
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
    vocabTabsHierarchyNetwork = new vis.Network(container, data, options);

    // Double-click to navigate
    vocabTabsHierarchyNetwork.on('doubleClick', function(params) {
      if (params.nodes.length === 1) {
        var cid = params.nodes[0];
        VocabDB.lookupConcepts([cid]).then(function(concepts) {
          if (concepts.length > 0) {
            var c2 = concepts[0];
            showResolvedConceptDetail({
              conceptId: c2.concept_id, conceptName: c2.concept_name,
              vocabularyId: c2.vocabulary_id, domainId: c2.domain_id,
              conceptClassId: c2.concept_class_id, conceptCode: c2.concept_code,
              standardConcept: c2.standard_concept
            });
          }
        });
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

    switchCSDetailTab('concepts');
    switchConceptMode('resolved');
    updateViewJsonLink();

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
  function openCreateModal() {
    // Clear form
    ['cs-create-name-en', 'cs-create-name-fr', 'cs-create-desc',
     'cs-create-cat-en', 'cs-create-cat-fr',
     'cs-create-subcat-en', 'cs-create-subcat-fr'].forEach(function(id) {
      document.getElementById(id).value = '';
    });
    document.getElementById('cs-create-version').value = '1.0.0';

    // Populate datalists with existing categories/subcategories
    var catsEn = new Set(), catsFr = new Set(), subcatsEn = new Set(), subcatsFr = new Set();
    App.conceptSets.forEach(function(cs) {
      var tr = cs.metadata && cs.metadata.translations;
      if (tr && tr.en) {
        if (tr.en.category) catsEn.add(tr.en.category);
        if (tr.en.subcategory) subcatsEn.add(tr.en.subcategory);
      }
      if (tr && tr.fr) {
        if (tr.fr.category) catsFr.add(tr.fr.category);
        if (tr.fr.subcategory) subcatsFr.add(tr.fr.subcategory);
      }
    });

    function fillDatalist(id, values) {
      var dl = document.getElementById(id);
      dl.innerHTML = '';
      Array.from(values).sort().forEach(function(v) {
        var opt = document.createElement('option');
        opt.value = v;
        dl.appendChild(opt);
      });
    }
    fillDatalist('cs-create-cat-en-list', catsEn);
    fillDatalist('cs-create-cat-fr-list', catsFr);
    fillDatalist('cs-create-subcat-en-list', subcatsEn);
    fillDatalist('cs-create-subcat-fr-list', subcatsFr);

    document.getElementById('cs-create-modal').style.display = 'flex';
  }

  function closeCreateModal() {
    document.getElementById('cs-create-modal').style.display = 'none';
  }

  function submitCreateCS() {
    var nameEn = document.getElementById('cs-create-name-en').value.trim();
    var nameFr = document.getElementById('cs-create-name-fr').value.trim();
    var desc = document.getElementById('cs-create-desc').value.trim();
    var catEn = document.getElementById('cs-create-cat-en').value.trim();
    var catFr = document.getElementById('cs-create-cat-fr').value.trim();
    var subcatEn = document.getElementById('cs-create-subcat-en').value.trim();
    var subcatFr = document.getElementById('cs-create-subcat-fr').value.trim();
    var version = document.getElementById('cs-create-version').value.trim() || '1.0.0';

    if (!nameEn) { App.showToast('Name (EN) is required.', 'error'); return; }
    if (!catEn) { App.showToast('Category (EN) is required.', 'error'); return; }

    var profile = App.getUserProfile();
    var authorName = ((profile.firstName || '') + ' ' + (profile.lastName || '')).trim() || 'Anonymous';
    var today = new Date().toISOString().split('T')[0];

    var cs = {
      id: App.nextConceptSetId(),
      name: nameEn,
      description: desc || null,
      version: version,
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
          en: { name: nameEn, category: catEn, subcategory: subcatEn },
          fr: { name: nameFr || nameEn, category: catFr || catEn, subcategory: subcatFr || subcatEn }
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
    App.showToast('Concept set "' + nameEn + '" created.', 'success');
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

// documentation.js — Documentation page module
var DocumentationPage = (function() {
  'use strict';

  var initialized = false;
  var currentSection = 'introduction';

  function isDev() {
    var h = window.location.hostname;
    return h === 'localhost' || h === '127.0.0.1' || h === '';
  }

  // ==================== SIDEBAR STRUCTURE ====================

  function sections() {
    var en = App.lang === 'en';
    return [
      {
        title: en ? 'Overview' : 'Pr\u00e9sentation',
        items: [
          { id: 'introduction', label: 'Introduction' },
          { id: 'getting-started', label: en ? 'Getting Started' : 'Prise en main' }
        ]
      },
      {
        title: en ? 'Data Dictionary' : 'Dictionnaire de donn\u00e9es',
        items: [
          { id: 'what-are-concept-sets', label: en ? 'What are Concept Sets?' : 'Les jeux de concepts' },
          { id: 'browsing', label: en ? 'Browsing Concept Sets' : 'Parcourir les jeux de concepts' },
          { id: 'concept-set-details', label: en ? 'Concept Set Details' : 'D\u00e9tails d\u2019un jeu de concepts' },
          { id: 'editing-concept-sets', label: en ? 'Editing Concept Sets' : 'Modifier un jeu de concepts' },
          { id: 'reviewing', label: en ? 'Reviewing & GitHub' : 'Relecture & GitHub' },
          { id: 'exporting', label: en ? 'Exporting' : 'Exporter' }
        ]
      },
      {
        title: en ? 'Projects' : 'Projets',
        items: [
          { id: 'projects', label: en ? 'Managing Projects' : 'G\u00e9rer les projets' }
        ]
      },
      {
        title: en ? 'Mapping Recommendations' : 'Recommandations',
        items: [
          { id: 'mapping-recommendations', label: en ? 'Mapping Recommendations' : 'Recommandations de mapping' }
        ]
      },
      {
        title: en ? 'Settings' : 'Param\u00e8tres',
        items: [
          { id: 'dictionary-settings', label: en ? 'Dictionary Settings' : 'Param\u00e8tres du dictionnaire' },
          { id: 'dev-tools', label: en ? 'Dev Tools' : 'Outils de d\u00e9veloppement' },
          { id: 'local-data', label: en ? 'Local Data' : 'Donn\u00e9es locales' }
        ]
      }
    ];
  }

  // ==================== CONTENT REGISTRY ====================

  function content() {
    var en = App.lang === 'en';
    return {
      'introduction':         en ? introductionEN()         : introductionFR(),
      'getting-started':      en ? gettingStartedEN()       : gettingStartedFR(),
      'what-are-concept-sets':en ? whatAreConceptSetsEN()    : whatAreConceptSetsFR(),
      'browsing':             en ? browsingEN()              : browsingFR(),
      'concept-set-details':  en ? conceptSetDetailsEN()     : conceptSetDetailsFR(),
      'editing-concept-sets': en ? editingConceptSetsEN()    : editingConceptSetsFR(),
      'reviewing':            en ? reviewingEN()             : reviewingFR(),
      'exporting':            en ? exportingEN()             : exportingFR(),
      'projects':             en ? projectsEN()              : projectsFR(),
      'mapping-recommendations': en ? mappingEN()            : mappingFR(),
      'dictionary-settings':  en ? dictSettingsEN()          : dictSettingsFR(),
      'dev-tools':            en ? devToolsEN()              : devToolsFR(),
      'local-data':           en ? localDataEN()             : localDataFR()
    };
  }

  // ==================== HTML HELPERS ====================

  function featureCard(icon, title, desc) {
    return '<div class="doc-feature-card">'
      + '<div class="doc-feature-icon"><i class="fas ' + icon + '"></i></div>'
      + '<h4>' + title + '</h4>'
      + '<p>' + desc + '</p></div>';
  }

  function audienceCard(icon, title, desc) {
    return '<div class="doc-audience-card">'
      + '<div class="doc-audience-icon"><i class="fas ' + icon + '"></i></div>'
      + '<h4>' + title + '</h4>'
      + '<p>' + desc + '</p></div>';
  }

  function infoBox(title, body, type) {
    return '<div class="doc-info-box doc-' + (type || 'info') + '">'
      + '<div class="doc-info-title">' + title + '</div>'
      + '<p>' + body + '</p></div>';
  }

  function profileMock(lang) {
    var en = lang === 'en';
    var idPrefix = 'doc-profile-' + lang;
    var authorTab = idPrefix + '-author-tab';
    var orgTab = idPrefix + '-org-tab';
    var authorPane = idPrefix + '-author-pane';
    var orgPane = idPrefix + '-org-pane';

    return '<div class="doc-mock-modal">'
      // Header
      + '<div class="modal-header">'
      + '<h3>' + (en ? 'Edit Profile' : 'Modifier le profil') + '</h3>'
      + '<span class="modal-close" style="cursor:default">&times;</span>'
      + '</div>'
      // Tabs
      + '<div class="profile-modal-tabs">'
      + '<button class="profile-modal-tab active" id="' + authorTab + '" onclick="'
      + 'document.getElementById(\'' + authorTab + '\').classList.add(\'active\');'
      + 'document.getElementById(\'' + orgTab + '\').classList.remove(\'active\');'
      + 'document.getElementById(\'' + authorPane + '\').style.display=\'\';'
      + 'document.getElementById(\'' + orgPane + '\').style.display=\'none\';'
      + '">'
      + '<i class="fas fa-user-circle"></i> ' + (en ? 'Author' : 'Auteur')
      + '</button>'
      + '<button class="profile-modal-tab" id="' + orgTab + '" onclick="'
      + 'document.getElementById(\'' + orgTab + '\').classList.add(\'active\');'
      + 'document.getElementById(\'' + authorTab + '\').classList.remove(\'active\');'
      + 'document.getElementById(\'' + orgPane + '\').style.display=\'\';'
      + 'document.getElementById(\'' + authorPane + '\').style.display=\'none\';'
      + '">'
      + '<i class="fas fa-building"></i> ' + 'Organisation'
      + '</button>'
      + '</div>'
      // Author pane
      + '<div class="modal-body" id="' + authorPane + '">'
      + '<div class="form-row">'
      + '<div class="form-group"><label>' + (en ? 'First Name *' : 'Pr\u00e9nom *') + '</label>'
      + '<input type="text" class="form-input" value="John" readonly></div>'
      + '<div class="form-group"><label>' + (en ? 'Last Name *' : 'Nom *') + '</label>'
      + '<input type="text" class="form-input" value="Doe" readonly></div>'
      + '</div>'
      + '<div class="form-row">'
      + '<div class="form-group"><label>' + (en ? 'Affiliation' : 'Affiliation') + '</label>'
      + '<input type="text" class="form-input" value="University Hospital" readonly></div>'
      + '<div class="form-group"><label>' + (en ? 'Profession' : 'Profession') + '</label>'
      + '<input type="text" class="form-input" value="Intensivist" readonly></div>'
      + '</div>'
      + '<div class="form-group"><label>ORCID</label>'
      + '<input type="text" class="form-input" value="0000-0001-2345-6789" readonly></div>'
      + '</div>'
      // Organization pane
      + '<div class="modal-body" id="' + orgPane + '" style="display:none">'
      + '<div class="form-group"><label>' + (en ? 'Organization Name *' : 'Nom de l\u2019organisation *') + '</label>'
      + '<input type="text" class="form-input" value="INDICATE Consortium" readonly></div>'
      + '<div class="form-group"><label>URL</label>'
      + '<input type="text" class="form-input" value="https://indicate-eu.org" readonly></div>'
      + '</div>'
      // Footer
      + '<div class="modal-footer">'
      + '<button class="btn-cancel" disabled>' + (en ? 'Cancel' : 'Annuler') + '</button>'
      + '<button class="btn-submit" disabled><i class="fas fa-check"></i> ' + (en ? 'Save' : 'Enregistrer') + '</button>'
      + '</div>'
      + '</div>';
  }

  function mockConceptSetTable(lang) {
    var en = lang === 'en';
    var rows = [
      { cat: en ? 'Vital Signs' : 'Signes vitaux', sub: en ? 'Haemodynamics' : 'H\u00e9modynamique', name: en ? 'Heart rate' : 'Fr\u00e9quence cardiaque', ver: '1.0.1', status: 'approved', statusLabel: en ? 'Approved' : 'Approuv\u00e9' },
      { cat: en ? 'Vital Signs' : 'Signes vitaux', sub: en ? 'Haemodynamics' : 'H\u00e9modynamique', name: en ? 'Systolic blood pressure' : 'Pression art\u00e9rielle systolique', ver: '1.0.0', status: 'pending_review', statusLabel: en ? 'Pending Review' : 'En attente' },
      { cat: en ? 'Laboratory' : 'Biologie', sub: en ? 'Chemistry' : 'Biochimie', name: en ? 'Serum Creatinine' : 'Cr\u00e9atinine s\u00e9rique', ver: '1.1.0', status: 'approved', statusLabel: en ? 'Approved' : 'Approuv\u00e9' },
      { cat: en ? 'Laboratory' : 'Biologie', sub: en ? 'Haematology' : 'H\u00e9matologie', name: en ? 'Haemoglobin' : 'H\u00e9moglobine', ver: '1.0.0', status: 'draft', statusLabel: en ? 'Draft' : 'Brouillon' },
      { cat: en ? 'Drugs' : 'M\u00e9dicaments', sub: en ? 'Vasopressors' : 'Vasopresseurs', name: en ? 'Norepinephrine' : 'Nor\u00e9pin\u00e9phrine', ver: '1.0.0', status: 'approved', statusLabel: en ? 'Approved' : 'Approuv\u00e9' }
    ];
    var fl = en ? 'Filter...' : 'Filtrer...';
    var html = '<div class="doc-mock-table"><table><thead><tr>'
      + '<th>' + (en ? 'Category' : 'Cat\u00e9gorie') + '</th>'
      + '<th>' + (en ? 'Subcategory' : 'Sous-cat\u00e9gorie') + '</th>'
      + '<th>' + (en ? 'Name' : 'Nom') + '</th>'
      + '<th>' + (en ? 'Version' : 'Version') + '</th>'
      + '<th>' + (en ? 'Status' : 'Statut') + '</th>'
      + '</tr><tr class="doc-mock-filter-row">'
      + '<th><input type="text" class="form-input" placeholder="' + fl + '" readonly></th>'
      + '<th><input type="text" class="form-input" placeholder="' + fl + '" readonly></th>'
      + '<th><input type="text" class="form-input" placeholder="' + fl + '" readonly></th>'
      + '<th><input type="text" class="form-input" placeholder="' + fl + '" readonly></th>'
      + '<th><input type="text" class="form-input" placeholder="' + fl + '" readonly></th>'
      + '</tr></thead><tbody>';
    for (var i = 0; i < rows.length; i++) {
      var r = rows[i];
      html += '<tr>'
        + '<td><span class="badge badge-category">' + r.cat + '</span></td>'
        + '<td><span class="badge badge-subcategory">' + r.sub + '</span></td>'
        + '<td><strong>' + r.name + '</strong></td>'
        + '<td style="text-align:right">' + r.ver + '</td>'
        + '<td><span class="status-badge ' + r.status + '" style="cursor:default; font-size:11px; padding:2px 8px">' + r.statusLabel + '</span></td>'
        + '</tr>';
    }
    html += '</tbody></table></div>';
    return html;
  }

  function detailTabs(lang, activeTab) {
    var en = lang === 'en';
    var tabs = [
      { id: 'concepts', icon: 'fa-list', label: 'Concepts' },
      { id: 'comments', icon: 'fa-comment', label: en ? 'Comments' : 'Commentaires' },
      { id: 'statistics', icon: 'fa-chart-bar', label: en ? 'Statistics' : 'Statistiques' },
      { id: 'review', icon: 'fa-clipboard-check', label: en ? 'Review' : 'Relecture' }
    ];
    var html = '<div class="detail-header-tabs" style="justify-content:center; margin:16px 0 12px">';
    for (var i = 0; i < tabs.length; i++) {
      var t = tabs[i];
      var isActive = t.id === activeTab;
      var cursor = isActive ? 'cursor:default' : 'cursor:pointer';
      var onclick = isActive ? '' : ' onclick="var el=document.getElementById(\'doc-tab-' + t.id + '\');if(el)el.scrollIntoView({behavior:\'smooth\',block:\'start\'})"';
      html += '<button class="tab-btn-blue' + (isActive ? ' active' : '') + '" style="' + cursor + '"' + onclick + '>'
        + '<i class="fas ' + t.icon + '"></i> ' + t.label + '</button>';
    }
    html += '</div>';
    return html;
  }

  function conceptModeToggle(lang, activeMode) {
    var en = lang === 'en';
    var resolved = en ? 'Resolved' : 'R\u00e9solus';
    var expression = 'Expression';
    return '<div style="margin:16px 0; display:flex; justify-content:center">'
      + '<div class="toggle-group">'
      + '<button class="toggle-btn' + (activeMode === 'resolved' ? ' active' : '') + '" style="cursor:default">' + resolved + '</button>'
      + '<button class="toggle-btn' + (activeMode === 'expression' ? ' active' : '') + '" style="cursor:default">' + expression + '</button>'
      + '</div></div>';
  }

  function mockExpressionTable(lang) {
    var en = lang === 'en';
    var flagYes = '<span class="flag-yes">Yes</span>';
    var flagNo = '<span class="flag-no">No</span>';
    var flagYesDanger = '<span class="flag-yes-danger">Yes</span>';
    var rows = [
      { vocab: 'LOINC', name: 'Heart rate', code: 'LP415670-1', domain: 'Measurement', std: 'C', excl: false, desc: true, map: true },
      { vocab: 'LOINC', name: 'Heart rate.beat-to-beat | Heart', code: 'LP415748-5', domain: 'Measurement', std: 'C', excl: false, desc: true, map: true },
      { vocab: 'SNOMED', name: 'Heart rate', code: '364075005', domain: 'Measurement', std: 'S', excl: false, desc: true, map: true },
      { vocab: 'SNOMED', name: 'Resting heart rate', code: '444981005', domain: 'Measurement', std: 'S', excl: false, desc: true, map: true },
      { vocab: 'SNOMED', name: 'Fetal heart rate', code: '249043002', domain: 'Measurement', std: 'S', excl: true, desc: true, map: true },
      { vocab: 'LOINC', name: 'Heart rate at First encounter', code: '69000-8', domain: 'Measurement', std: 'S', excl: true, desc: true, map: true }
    ];
    var stdBadge = function(s) {
      if (s === 'S') return '<span class="badge badge-standard">Standard</span>';
      return '<span class="badge badge-classification">Classification</span>';
    };
    var fl = en ? 'Filter...' : 'Filtrer...';
    var html = '<div class="doc-mock-table"><table><thead><tr>'
      + '<th>' + (en ? 'Vocabulary' : 'Vocabulaire') + '</th>'
      + '<th>' + (en ? 'Concept Name' : 'Nom du concept') + '</th>'
      + '<th>' + (en ? 'Domain' : 'Domaine') + '</th>'
      + '<th>Standard</th>'
      + '<th>' + (en ? 'Exclude' : 'Exclure') + '</th>'
      + '<th>Desc.</th>'
      + '<th>' + (en ? 'Mapped' : 'Mapp\u00e9') + '</th>'
      + '</tr><tr class="doc-mock-filter-row">'
      + '<th><input type="text" class="form-input" placeholder="' + fl + '" readonly></th>'
      + '<th><input type="text" class="form-input" placeholder="' + fl + '" readonly></th>'
      + '<th><input type="text" class="form-input" placeholder="' + fl + '" readonly></th>'
      + '<th><input type="text" class="form-input" placeholder="' + fl + '" readonly></th>'
      + '<th><input type="text" class="form-input" placeholder="' + fl + '" readonly></th>'
      + '<th><input type="text" class="form-input" placeholder="' + fl + '" readonly></th>'
      + '<th><input type="text" class="form-input" placeholder="' + fl + '" readonly></th>'
      + '</tr></thead><tbody>';
    for (var i = 0; i < rows.length; i++) {
      var r = rows[i];
      html += '<tr>'
        + '<td>' + r.vocab + '</td>'
        + '<td>' + r.name + '</td>'
        + '<td>' + (en ? r.domain : 'Mesure') + '</td>'
        + '<td>' + stdBadge(r.std) + '</td>'
        + '<td class="td-center">' + (r.excl ? flagYesDanger : flagNo) + '</td>'
        + '<td class="td-center">' + (r.excl ? (r.desc ? flagYesDanger : flagNo) : (r.desc ? flagYes : flagNo)) + '</td>'
        + '<td class="td-center">' + (r.excl ? (r.map ? flagYesDanger : flagNo) : (r.map ? flagYes : flagNo)) + '</td>'
        + '</tr>';
    }
    html += '<tr><td colspan="7" style="text-align:center; color:var(--text-muted); font-size:12px; padding:8px">'
      + (en ? '... 38 items total' : '... 38 \u00e9l\u00e9ments au total')
      + '</td></tr>';
    html += '</tbody></table></div>';
    return html;
  }

  function mockResolvedTable(lang) {
    var en = lang === 'en';
    var rows = [
      { id: 3027018, vocab: 'LOINC', name: 'Heart rate', code: '8867-4', domain: 'Measurement', std: 'S' },
      { id: 36303943, vocab: 'LOINC', name: 'Heart rate --W exercise', code: '89273-7', domain: 'Measurement', std: 'S' },
      { id: 36305351, vocab: 'LOINC', name: 'Heart rate --during anesthesia', code: '89278-6', domain: 'Measurement', std: 'S' },
      { id: 3040891, vocab: 'LOINC', name: 'Heart rate --resting', code: '40443-4', domain: 'Measurement', std: 'S' },
      { id: 40771525, vocab: 'LOINC', name: 'Heart rate --sitting', code: '69001-6', domain: 'Measurement', std: 'S' },
      { id: 3001376, vocab: 'LOINC', name: 'Heart rate by Pulse oximetry', code: '8889-8', domain: 'Measurement', std: 'S' },
      { id: 40481601, vocab: 'SNOMED', name: 'Resting heart rate', code: '444981005', domain: 'Measurement', std: 'S' },
      { id: 35610095, vocab: 'SNOMED', name: 'Heart rate at cardiac apex', code: '429525003', domain: 'Measurement', std: 'S' }
    ];
    var fl = en ? 'Filter...' : 'Filtrer...';
    var html = '<div class="doc-mock-table"><table><thead><tr>'
      + '<th>' + (en ? 'Concept ID' : 'ID Concept') + '</th>'
      + '<th>' + (en ? 'Vocabulary' : 'Vocabulaire') + '</th>'
      + '<th>' + (en ? 'Concept Name' : 'Nom du concept') + '</th>'
      + '<th>' + (en ? 'Concept Code' : 'Code') + '</th>'
      + '<th>Standard</th>'
      + '</tr><tr class="doc-mock-filter-row">'
      + '<th><input type="text" class="form-input" placeholder="' + fl + '" readonly></th>'
      + '<th><input type="text" class="form-input" placeholder="' + fl + '" readonly></th>'
      + '<th><input type="text" class="form-input" placeholder="' + fl + '" readonly></th>'
      + '<th><input type="text" class="form-input" placeholder="' + fl + '" readonly></th>'
      + '<th><input type="text" class="form-input" placeholder="' + fl + '" readonly></th>'
      + '</tr></thead><tbody>';
    for (var i = 0; i < rows.length; i++) {
      var r = rows[i];
      html += '<tr>'
        + '<td>' + r.id + '</td>'
        + '<td>' + r.vocab + '</td>'
        + '<td>' + r.name + '</td>'
        + '<td>' + r.code + '</td>'
        + '<td><span class="badge badge-standard">Standard</span></td>'
        + '</tr>';
    }
    html += '<tr><td colspan="5" style="text-align:center; color:var(--text-muted); font-size:12px; padding:8px">'
      + (en ? '... 23 standard concepts resolved (63 total)' : '... 23 concepts standards r\u00e9solus (63 au total)')
      + '</td></tr>';
    html += '</tbody></table></div>';
    return html;
  }

  function mockConceptDetailPanel(lang) {
    var en = lang === 'en';
    var p = 'doc-cdp-' + lang; // unique prefix

    function detailItem(label, value, isLink) {
      var val = isLink
        ? '<a href="javascript:void(0)" style="color:var(--primary); text-decoration:underline">' + value + '</a>'
        : value;
      return '<div class="detail-item"><strong>' + label + ':</strong><span>' + val
        + '</span></div>';
    }

    var html = '<div class="doc-mock-modal" style="max-width:100%">'
      + '<div style="padding:12px 16px; border-bottom:1px solid var(--gray-200)">'
      + '<h3 style="margin:0; font-size:14px">' + (en ? 'Concept Details' : 'D\u00e9tails du concept') + '</h3></div>'
      + '<div style="padding:16px">'

      // Details grid
      + '<div class="concept-details-grid">'
      + detailItem('Concept Name', 'Heart rate --W exercise')
      + detailItem('OMOP Concept ID', '36303943', true)
      + detailItem('Vocabulary ID', 'LOINC')
      + detailItem('FHIR Resource', 'LOINC', true)
      + detailItem('Concept Code', '89273-7')
      + detailItem('Standard', '<span style="color:#28a745; font-weight:600">Standard</span>')
      + detailItem('Domain', 'Measurement')
      + detailItem('Validity', '<span style="color:#28a745; font-weight:600">Valid</span>')
      + detailItem('Concept Class', 'Clinical Observation')
      + '</div>'

      // Tabs
      + '<div class="concept-vocab-tab-bar" id="' + p + '-tabs">'
      + '<button class="concept-vocab-tab active" data-vtab="related" onclick="DocumentationPage._switchVtab(\'' + p + '\',\'related\')">Related</button>'
      + '<button class="concept-vocab-tab" data-vtab="hierarchy" onclick="DocumentationPage._switchVtab(\'' + p + '\',\'hierarchy\')">' + (en ? 'Hierarchy' : 'Hi\u00e9rarchie') + '</button>'
      + '<button class="concept-vocab-tab" data-vtab="synonyms" onclick="DocumentationPage._switchVtab(\'' + p + '\',\'synonyms\')">' + (en ? 'Synonyms' : 'Synonymes') + '</button>'
      + '</div>'

      // Related panel
      + '<div id="' + p + '-related" style="margin-top:8px">'
      + '<table style="font-size:12px; margin:0"><thead><tr>'
      + '<th>' + (en ? 'Relationship' : 'Relation') + '</th>'
      + '<th>' + (en ? 'Concept Name' : 'Nom du concept') + '</th>'
      + '<th>' + (en ? 'Vocabulary' : 'Vocabulaire') + '</th>'
      + '<th>' + (en ? 'Class' : 'Classe') + '</th>'
      + '</tr></thead><tbody>'
      + '<tr><td>Is a</td><td>Heart rate | XXX | Heart rate taken in specific position</td><td>LOINC</td><td>LOINC Hierarchy</td></tr>'
      + '<tr><td>Is a</td><td>Heart rate positional molecular</td><td>LOINC</td><td>LOINC Class</td></tr>'
      + '<tr><td>Has component</td><td>Heart rate^W exercise</td><td>LOINC</td><td>LOINC Component</td></tr>'
      + '<tr><td>Has property</td><td>Number Rate</td><td>LOINC</td><td>LOINC Property</td></tr>'
      + '<tr><td>Maps to</td><td>Heart rate --W exercise</td><td>LOINC</td><td>Clinical Observation</td></tr>'
      + '</tbody></table></div>'

      // Hierarchy panel — real vis.js graph
      + '<div id="' + p + '-hierarchy" style="display:none; margin-top:8px">'
      + '<div style="border:1px solid var(--border); border-radius:var(--radius); overflow:hidden">'
      // Header bar
      + '<div class="hierarchy-header" style="display:flex; align-items:center; gap:8px; padding:8px 12px; background:var(--gray-light); border-bottom:1px solid var(--border)">'
      + '<button class="hierarchy-btn" disabled style="cursor:default"><i class="fas fa-arrow-left"></i></button>'
      + '<div style="flex:1"><strong style="font-size:13px">Heart rate --W exercise</strong> '
      + '<span style="font-size:11px; color:var(--text-muted)">#36303943 \u00b7 LOINC</span></div>'
      + '<div class="hierarchy-controls">'
      + '<button class="hierarchy-btn" style="cursor:default"><i class="fas fa-search-plus"></i></button>'
      + '<button class="hierarchy-btn" style="cursor:default"><i class="fas fa-search-minus"></i></button>'
      + '<button class="hierarchy-btn" style="cursor:default"><i class="fas fa-compress-arrows-alt"></i></button>'
      + '<button class="hierarchy-btn" style="cursor:default"><i class="fas fa-expand"></i></button>'
      + '</div></div>'
      // Graph container
      + '<div id="' + p + '-hierarchy-graph" style="height:250px; background:white"></div>'
      + '</div></div>'

      // Synonyms panel — datatable
      + '<div id="' + p + '-synonyms" style="display:none; margin-top:8px">'
      + '<table style="font-size:12px; margin:0"><thead><tr>'
      + '<th>' + (en ? 'Synonym' : 'Synonyme') + '</th>'
      + '<th>' + (en ? 'Language' : 'Langue') + '</th>'
      + '</tr></thead><tbody>'
      + '<tr><td>Heart rate - W exercise</td><td>English</td></tr>'
      + '<tr><td>Heart rate W exercise</td><td>English</td></tr>'
      + '<tr><td style="font-size:11px">\u5FC3\u7387^\u91C7\u7528\u8FD0\u52A8:\u8BA1\u6570\u578B\u901F\u7387:\u65F6\u95F4\u70B9:XXX:\u5B9A\u91CF\u578B</td><td>Chinese</td></tr>'
      + '</tbody></table></div>'

      + '</div></div>';

    return html;
  }

  function mockFiltersPopup(lang) {
    var en = lang === 'en';
    function filterRow(label, value) {
      return '<div style="display:flex; align-items:center; gap:8px; margin-bottom:8px">'
        + '<label style="min-width:80px; font-size:12px; font-weight:600; color:var(--text-muted)">' + label + '</label>'
        + '<select class="form-input" disabled style="flex:1; font-size:12px; padding:3px 8px"><option>' + value + '</option></select>'
        + '</div>';
    }
    return '<div class="doc-mock-modal" style="max-width:360px; padding:16px">'
      + filterRow(en ? 'Vocabulary' : 'Vocabulaire', en ? 'All' : 'Tous')
      + filterRow(en ? 'Domain' : 'Domaine', en ? 'All' : 'Tous')
      + filterRow(en ? 'Class' : 'Classe', en ? 'All' : 'Tous')
      + filterRow('Standard', 'Standard')
      + '<div style="display:flex; align-items:center; gap:8px; margin-bottom:12px">'
      + '<label style="min-width:80px; font-size:12px; font-weight:600; color:var(--text-muted)">'
      + (en ? 'Valid only' : 'Valides uniq.') + '</label>'
      + '<input type="checkbox" checked onclick="return false">'
      + '</div>'
      + '<div style="display:flex; gap:6px; justify-content:flex-end">'
      + '<button class="btn-primary-custom btn-gray" style="cursor:default; font-size:12px">'
      + (en ? 'Clear' : 'Effacer') + '</button>'
      + '<button class="btn-primary-custom" style="cursor:default; font-size:12px">'
      + (en ? 'Apply' : 'Appliquer') + '</button>'
      + '</div></div>';
  }

  function mockAddConceptsTable(lang) {
    var en = lang === 'en';
    var fl = en ? 'Filter...' : 'Filtrer...';
    var rows = [
      { id: 3027018, name: 'Heart rate', vocab: 'LOINC', code: '8867-4', domain: 'Measurement', cls: 'Clinical Observation', std: 'S' },
      { id: 3040891, name: 'Heart rate --resting', vocab: 'LOINC', code: '40443-4', domain: 'Measurement', cls: 'Clinical Observation', std: 'S' },
      { id: 3001376, name: 'Heart rate by Pulse oximetry', vocab: 'LOINC', code: '8889-8', domain: 'Measurement', cls: 'Clinical Observation', std: 'S' },
      { id: 4239408, name: 'Heart rate', vocab: 'SNOMED', code: '364075005', domain: 'Measurement', cls: 'Observable Entity', std: '' }
    ];
    var stdBadge = function(s) {
      if (s === 'S') return '<span class="badge badge-standard">Standard</span>';
      if (s === 'C') return '<span class="badge badge-classification">Classification</span>';
      return '<span class="badge badge-non-standard">Non-standard</span>';
    };
    var html = '<div class="doc-mock-table"><table><thead><tr>'
      + '<th style="width:36px"><input type="checkbox" onclick="return false"></th>'
      + '<th>' + (en ? 'Concept ID' : 'ID Concept') + '</th>'
      + '<th>' + (en ? 'Concept Name' : 'Nom du concept') + '</th>'
      + '<th>' + (en ? 'Vocabulary' : 'Vocabulaire') + '</th>'
      + '<th>Code</th>'
      + '<th>' + (en ? 'Domain' : 'Domaine') + '</th>'
      + '<th>' + (en ? 'Class' : 'Classe') + '</th>'
      + '<th class="td-center">Standard</th>'
      + '</tr><tr class="doc-mock-filter-row">'
      + '<th></th>'
      + '<th><input type="text" class="form-input" placeholder="' + fl + '" readonly></th>'
      + '<th><input type="text" class="form-input" placeholder="' + fl + '" readonly></th>'
      + '<th><input type="text" class="form-input" placeholder="' + fl + '" readonly></th>'
      + '<th><input type="text" class="form-input" placeholder="' + fl + '" readonly></th>'
      + '<th><input type="text" class="form-input" placeholder="' + fl + '" readonly></th>'
      + '<th><input type="text" class="form-input" placeholder="' + fl + '" readonly></th>'
      + '<th><input type="text" class="form-input" placeholder="' + fl + '" readonly></th>'
      + '</tr></thead><tbody>';
    for (var i = 0; i < rows.length; i++) {
      var r = rows[i];
      var sel = i === 0 ? ' style="background:#e8f0fe"' : '';
      html += '<tr' + sel + '>'
        + '<td class="td-center"><input type="checkbox"' + (i === 0 ? ' checked' : '') + ' onclick="return false" style="accent-color:var(--primary); width:15px; height:15px"></td>'
        + '<td>' + r.id + '</td>'
        + '<td>' + r.name + '</td>'
        + '<td>' + r.vocab + '</td>'
        + '<td>' + r.code + '</td>'
        + '<td>' + (en ? r.domain : 'Mesure') + '</td>'
        + '<td>' + r.cls + '</td>'
        + '<td class="td-center">' + stdBadge(r.std) + '</td>'
        + '</tr>';
    }
    html += '</tbody></table></div>';
    return html;
  }

  function mockAddConceptsFooter(lang, isCustom) {
    var en = lang === 'en';
    function toggle(checked, isExclude) {
      var cls = 'toggle-switch toggle-sm' + (isExclude ? ' toggle-exclude' : '');
      return '<label class="' + cls + '" style="cursor:default">'
        + '<input type="checkbox"' + (checked ? ' checked' : '') + ' onclick="return false">'
        + '<span class="toggle-slider" style="cursor:default"></span></label>';
    }
    var html = '<div class="doc-mock-modal" style="max-width:100%; padding:10px 16px">'
      + '<div style="display:flex; align-items:center; justify-content:space-between; flex-wrap:wrap; gap:8px">';

    if (!isCustom) {
      html += '<label style="display:inline-flex; align-items:center; gap:4px; font-size:13px; cursor:default">'
        + '<input type="checkbox" onclick="return false"> '
        + '<span>' + (en ? 'Multiple Selection' : 'S\u00e9lection multiple') + '</span></label>';
    } else {
      html += '<div></div>';
    }

    html += '<div style="display:flex; align-items:center; gap:12px">';
    html += toggle(false, true) + ' <span style="font-size:13px; font-weight:500">'
      + (en ? 'Exclude' : 'Exclure') + '</span>';
    if (!isCustom) {
      html += toggle(false, false) + ' <span style="font-size:13px; font-weight:500">Descendants</span>';
      html += toggle(false, false) + ' <span style="font-size:13px; font-weight:500">'
        + (en ? 'Mapped' : 'Mapp\u00e9') + '</span>';
      html += '<span style="font-size:12px; color:var(--text-muted)">'
        + (en ? '1 selected' : '1 s\u00e9lectionn\u00e9') + '</span>';
      html += '<button class="btn-success-custom" style="cursor:default"><i class="fas fa-plus"></i> '
        + (en ? 'Add Concepts' : 'Ajouter des concepts') + '</button>';
    } else {
      html += '<button class="btn-success-custom" style="cursor:default"><i class="fas fa-plus"></i> '
        + (en ? 'Add Custom Concept' : 'Ajouter le concept') + '</button>';
    }
    html += '</div></div></div>';
    return html;
  }

  function mockCustomConceptForm(lang) {
    var en = lang === 'en';
    return '<div class="doc-mock-modal" style="max-width:100%; padding:20px 24px">'
      + '<div class="custom-concept-form" style="max-width:500px">'
      + '<div class="custom-concept-row">'
      + '<label>' + (en ? 'Concept ID' : 'ID Concept') + '</label>'
      + '<div class="custom-concept-input-wrap">'
      + '<input type="text" class="form-input" value="2100000003" readonly>'
      + '<span style="font-size:11px; color:var(--text-muted)">'
      + (en ? 'Auto-assigned from 2,100,000,000' : 'Auto-attribu\u00e9 \u00e0 partir de 2\u202f100\u202f000\u202f000')
      + '</span></div></div>'
      + '<div class="custom-concept-row">'
      + '<label>' + (en ? 'Concept Name *' : 'Nom du concept *') + '</label>'
      + '<input type="text" class="form-input" value="ICDSC Score" readonly></div>'
      + '<div class="custom-concept-row">'
      + '<label>' + (en ? 'Domain *' : 'Domaine *') + '</label>'
      + '<input type="text" class="form-input" value="Measurement" readonly></div>'
      + '<div class="custom-concept-row">'
      + '<label>' + (en ? 'Vocabulary' : 'Vocabulaire') + '</label>'
      + '<div class="custom-concept-input-wrap">'
      + '<input type="text" class="form-input" value="INDICATE" readonly>'
      + '<span style="font-size:11px; color:var(--text-muted)">'
      + (en ? 'Custom concepts use the INDICATE vocabulary' : 'Les concepts personnalis\u00e9s utilisent le vocabulaire INDICATE')
      + '</span></div></div>'
      + '<div class="custom-concept-row">'
      + '<label>' + (en ? 'Concept Class *' : 'Classe *') + '</label>'
      + '<input type="text" class="form-input" value="Clinical Observation" readonly></div>'
      + '<div class="custom-concept-row">'
      + '<label>' + (en ? 'Concept Code' : 'Code du concept') + '</label>'
      + '<input type="text" class="form-input" value="" placeholder="'
      + (en ? 'Enter concept code (optional)...' : 'Code du concept (optionnel)...')
      + '" readonly></div>'
      + '<div class="custom-concept-row">'
      + '<label>Standard Concept</label>'
      + '<input type="text" class="form-input" value="Non-standard" readonly></div>'
      + '</div></div>';
  }

  function mockExpressionEditTable(lang) {
    var en = lang === 'en';
    function toggle(checked, isExclude) {
      var cls = 'toggle-switch toggle-sm' + (isExclude ? ' toggle-exclude' : '');
      return '<label class="' + cls + '" style="cursor:default">'
        + '<input type="checkbox"' + (checked ? ' checked' : '') + ' onclick="return false">'
        + '<span class="toggle-slider" style="cursor:default"></span></label>';
    }
    var rows = [
      { vocab: 'LOINC', name: 'Heart rate', cls: 'LOINC Hierarchy', std: 'C', excl: false, desc: true, map: true },
      { vocab: 'SNOMED', name: 'Heart rate', cls: 'Observable Entity', std: 'S', excl: false, desc: true, map: true },
      { vocab: 'SNOMED', name: 'Fetal heart rate', cls: 'Observable Entity', std: 'S', excl: true, desc: true, map: true },
      { vocab: 'LOINC', name: 'Heart rate at First encounter', cls: 'Clinical Observation', std: 'S', excl: true, desc: true, map: true }
    ];
    var stdBadge = function(s) {
      return s === 'S'
        ? '<span class="badge badge-standard">Standard</span>'
        : '<span class="badge badge-classification">Classification</span>';
    };
    var fl = en ? 'Filter...' : 'Filtrer...';
    var html = '<div class="doc-mock-table"><table><thead><tr>'
      + '<th>' + (en ? 'Vocabulary' : 'Vocabulaire') + '</th>'
      + '<th>' + (en ? 'Concept Name' : 'Nom du concept') + '</th>'
      + '<th>' + (en ? 'Concept Class' : 'Classe') + '</th>'
      + '<th>Standard</th>'
      + '<th class="td-center">' + (en ? 'Exclude' : 'Exclure') + '</th>'
      + '<th class="td-center">Desc.</th>'
      + '<th class="td-center">' + (en ? 'Mapped' : 'Mapp\u00e9') + '</th>'
      + '<th style="width:36px"></th>'
      + '</tr><tr class="doc-mock-filter-row">'
      + '<th><input type="text" class="form-input" placeholder="' + fl + '" readonly></th>'
      + '<th><input type="text" class="form-input" placeholder="' + fl + '" readonly></th>'
      + '<th><input type="text" class="form-input" placeholder="' + fl + '" readonly></th>'
      + '<th><input type="text" class="form-input" placeholder="' + fl + '" readonly></th>'
      + '<th></th><th></th><th></th><th></th>'
      + '</tr></thead><tbody>';
    for (var i = 0; i < rows.length; i++) {
      var r = rows[i];
      html += '<tr>'
        + '<td>' + r.vocab + '</td>'
        + '<td>' + r.name + '</td>'
        + '<td>' + r.cls + '</td>'
        + '<td>' + stdBadge(r.std) + '</td>'
        + '<td class="td-center">' + toggle(r.excl, true) + '</td>'
        + '<td class="td-center">' + toggle(r.desc, r.excl) + '</td>'
        + '<td class="td-center">' + toggle(r.map, r.excl) + '</td>'
        + '<td class="td-center"><i class="fas fa-trash" style="color:var(--danger); opacity:0.6; font-size:13px; cursor:default"></i></td>'
        + '</tr>';
    }
    html += '<tr><td colspan="8" style="text-align:center; color:var(--text-muted); font-size:12px; padding:8px">'
      + (en ? '... 38 items total' : '... 38 \u00e9l\u00e9ments au total')
      + '</td></tr>';
    html += '</tbody></table></div>';
    return html;
  }

  function mockEditModeTable(lang) {
    var en = lang === 'en';
    var rows = [
      { name: en ? 'Heart rate' : 'Fr\u00e9quence cardiaque', cat: en ? 'Vital Signs' : 'Signes vitaux', sub: en ? 'Haemodynamics' : 'H\u00e9modynamique', ver: '1.0.1', status: 'approved', statusLabel: en ? 'Approved' : 'Approuv\u00e9' },
      { name: en ? 'Systolic blood pressure' : 'Pression art\u00e9rielle systolique', cat: en ? 'Vital Signs' : 'Signes vitaux', sub: en ? 'Haemodynamics' : 'H\u00e9modynamique', ver: '1.0.0', status: 'approved', statusLabel: en ? 'Approved' : 'Approuv\u00e9' },
      { name: en ? 'Mean arterial pressure' : 'Pression art\u00e9rielle moyenne', cat: en ? 'Vital Signs' : 'Signes vitaux', sub: en ? 'Haemodynamics' : 'H\u00e9modynamique', ver: '1.0.0', status: 'draft', statusLabel: en ? 'Draft' : 'Brouillon' }
    ];
    var html = '<div class="doc-mock-table"><table><thead><tr>'
      + '<th style="width:36px"></th>'
      + '<th style="width:40px"></th>'
      + '<th>' + (en ? 'Category' : 'Cat\u00e9gorie') + '</th>'
      + '<th>' + (en ? 'Subcategory' : 'Sous-cat\u00e9gorie') + '</th>'
      + '<th>' + (en ? 'Name' : 'Nom') + '</th>'
      + '<th>' + (en ? 'Version' : 'Version') + '</th>'
      + '<th>' + (en ? 'Status' : 'Statut') + '</th>'
      + '</tr></thead><tbody>';
    for (var i = 0; i < rows.length; i++) {
      var r = rows[i];
      var checked = i === 1 ? ' checked' : '';
      var selected = i === 1 ? ' style="background:#e8f0fe"' : '';
      html += '<tr' + selected + '>'
        + '<td class="td-center"><input type="checkbox"' + checked + ' onclick="return false" style="accent-color:var(--primary); width:15px; height:15px"></td>'
        + '<td class="td-center"><button class="cs-row-edit-btn" style="cursor:default"><i class="fas fa-pen"></i></button></td>'
        + '<td><span class="badge badge-category">' + r.cat + '</span></td>'
        + '<td><span class="badge badge-subcategory">' + r.sub + '</span></td>'
        + '<td><strong>' + r.name + '</strong></td>'
        + '<td style="text-align:center">' + r.ver + '</td>'
        + '<td class="td-center"><span class="status-badge ' + r.status + '" style="cursor:default; font-size:11px; padding:2px 8px">' + r.statusLabel + '</span></td>'
        + '</tr>';
    }
    html += '</tbody></table></div>';
    return html;
  }

  function mockNewConceptSetModal(lang) {
    var en = lang === 'en';
    return '<div class="doc-mock-modal">'
      + '<div class="modal-header">'
      + '<h3 style="margin:0"><i class="fas fa-plus"></i> ' + (en ? 'New Concept Set' : 'Nouveau jeu de concepts') + '</h3>'
      + '<span class="modal-close" style="cursor:default">&times;</span>'
      + '</div>'
      + '<div class="modal-body">'
      + '<div class="form-group"><label>' + (en ? 'Name *' : 'Nom *') + '</label>'
      + '<input type="text" class="form-input" value="Heart rate" readonly></div>'
      + '<div class="form-group"><label>' + (en ? 'Category *' : 'Cat\u00e9gorie *') + '</label>'
      + '<div class="input-with-add">'
      + '<select class="form-input" disabled><option>' + (en ? 'Vital Signs' : 'Signes vitaux') + '</option></select>'
      + '<button class="btn-outline-sm" style="cursor:default"><i class="fas fa-plus"></i></button>'
      + '</div></div>'
      + '<div class="form-group"><label>' + (en ? 'Subcategory' : 'Sous-cat\u00e9gorie') + '</label>'
      + '<div class="input-with-add">'
      + '<select class="form-input" disabled><option>' + (en ? 'Haemodynamics' : 'H\u00e9modynamique') + '</option></select>'
      + '<button class="btn-outline-sm" style="cursor:default"><i class="fas fa-plus"></i></button>'
      + '</div></div>'
      + '<div class="form-group"><label>Description</label>'
      + '<textarea class="form-input" rows="2" readonly style="resize:none">'
      + (en ? 'Number of heartbeats per minute (bpm).' : 'Nombre de battements cardiaques par minute (bpm).')
      + '</textarea></div>'
      + '</div>'
      + '<div class="modal-footer">'
      + '<button class="btn-cancel" disabled>' + (en ? 'Cancel' : 'Annuler') + '</button>'
      + '<button class="btn-submit" disabled><i class="fas fa-plus"></i> ' + (en ? 'Create' : 'Cr\u00e9er') + '</button>'
      + '</div>'
      + '</div>';
  }

  function mockCommentsPanel(lang) {
    var en = lang === 'en';
    var content = en
      ? '<h3 style="margin-top:0">Definition & Clinical Context</h3>'
        + '<p>Heart rate is the number of heartbeats per unit of time (bpm). Normal ranges: 60\u2013100 bpm in adults, '
        + '110\u2013160 bpm in neonates. This concept set captures numeric heart rate values only, excluding pulse '
        + 'waveform morphology, rhythm classification, and fetal heart rate.</p>'

        + '<h3>Included Concepts</h3>'
        + '<p>22 standard concepts (20 LOINC + 2 SNOMED) organised by clinical context:</p>'
        + '<ul style="margin-bottom:8px">'
        + '<li><strong>General</strong> \u2014 <em>3027018 / 8867-4 Heart rate</em>: default concept when source does not specify method or site</li>'
        + '<li><strong>By method</strong> \u2014 e.g. <em>3001376 / 8889-8 Heart rate by Pulse oximetry</em>, '
        + '<em>21490670 / 60978-4 Heart rate Intra arterial line by Invasive</em></li>'
        + '<li><strong>By position</strong> \u2014 e.g. <em>40771524 / 68999-2 Heart rate \u2013\u2013supine</em></li>'
        + '<li><strong>By condition</strong> \u2014 e.g. <em>3040891 / 40443-4 Heart rate \u2013\u2013resting</em></li>'
        + '<li><strong>Neonatal screening</strong> \u2014 pre- and postductal pulse oximetry</li>'
        + '</ul>'

        + '<h3>Excluded Concepts</h3>'
        + '<ul style="margin-bottom:8px">'
        + '<li><strong>Pulse waveform & intensity</strong> \u2014 morphology observations, not numeric rates</li>'
        + '<li><strong>Fetal heart rate</strong> \u2014 covered by a dedicated concept set</li>'
        + '<li><strong>Timed aggregates</strong> \u2014 Holter/telemetry summaries (max, mean, min over hours)</li>'
        + '<li><strong>Calculated differences</strong> \u2014 e.g. orthostatic heart rate delta</li>'
        + '</ul>'

        + '<h3>Mapping Notes</h3>'
        + '<ul style="margin-bottom:0">'
        + '<li><strong>Default</strong>: "HR", "Pulse", "FC" \u2192 <em>Heart rate (3027018)</em></li>'
        + '<li><strong>SpO2-derived</strong>: "SpO2 PR", "Pleth HR" \u2192 <em>Heart rate by Pulse oximetry (3001376)</em></li>'
        + '<li><strong>Arterial line</strong>: "Art line HR" \u2192 <em>Heart rate Intra arterial line (21490670)</em></li>'
        + '</ul>'

      : '<h3 style="margin-top:0">D\u00e9finition & Contexte clinique</h3>'
        + '<p>La fr\u00e9quence cardiaque est le nombre de battements par minute (bpm). Valeurs normales\u00a0: '
        + '60\u2013100 bpm chez l\u2019adulte, 110\u2013160 bpm chez le nouveau-n\u00e9. Ce jeu capture uniquement '
        + 'les valeurs num\u00e9riques, excluant la morphologie du pouls, la classification du rythme et la '
        + 'fr\u00e9quence cardiaque f\u0153tale.</p>'

        + '<h3>Concepts inclus</h3>'
        + '<p>22 concepts standards (20 LOINC + 2 SNOMED) organis\u00e9s par contexte\u00a0:</p>'
        + '<ul style="margin-bottom:8px">'
        + '<li><strong>G\u00e9n\u00e9ral</strong> \u2014 <em>3027018 / 8867-4 Heart rate</em>\u00a0: concept par d\u00e9faut</li>'
        + '<li><strong>Par m\u00e9thode</strong> \u2014 ex. <em>3001376 / 8889-8 Heart rate by Pulse oximetry</em>, '
        + '<em>21490670 / 60978-4 Heart rate Intra arterial line</em></li>'
        + '<li><strong>Par position</strong> \u2014 ex. <em>40771524 / 68999-2 Heart rate \u2013\u2013supine</em></li>'
        + '<li><strong>Par condition</strong> \u2014 ex. <em>3040891 / 40443-4 Heart rate \u2013\u2013resting</em></li>'
        + '<li><strong>D\u00e9pistage n\u00e9onatal</strong> \u2014 oxym\u00e9trie pr\u00e9- et post-ductale</li>'
        + '</ul>'

        + '<h3>Concepts exclus</h3>'
        + '<ul style="margin-bottom:8px">'
        + '<li><strong>Forme d\u2019onde & intensit\u00e9 du pouls</strong> \u2014 observations morphologiques</li>'
        + '<li><strong>Fr\u00e9quence cardiaque f\u0153tale</strong> \u2014 jeu de concepts d\u00e9di\u00e9</li>'
        + '<li><strong>Agr\u00e9gats temporels</strong> \u2014 r\u00e9sum\u00e9s Holter/t\u00e9l\u00e9m\u00e9trie</li>'
        + '<li><strong>Diff\u00e9rences calcul\u00e9es</strong> \u2014 ex. delta orthostatique</li>'
        + '</ul>'

        + '<h3>Notes de mapping</h3>'
        + '<ul style="margin-bottom:0">'
        + '<li><strong>Par d\u00e9faut</strong>\u00a0: \u00ab HR \u00bb, \u00ab Pouls \u00bb, \u00ab FC \u00bb \u2192 <em>Heart rate (3027018)</em></li>'
        + '<li><strong>SpO2</strong>\u00a0: \u00ab SpO2 PR \u00bb, \u00ab Pleth HR \u00bb \u2192 <em>Heart rate by Pulse oximetry (3001376)</em></li>'
        + '<li><strong>Ligne art\u00e9rielle</strong>\u00a0: \u00ab Art line HR \u00bb \u2192 <em>Heart rate Intra arterial line (21490670)</em></li>'
        + '</ul>';

    return '<p style="font-size:12px; color:var(--text-muted); margin-bottom:4px"><i class="fas fa-info-circle"></i> '
      + (en ? 'Example: Heart rate concept set comments (condensed).' : 'Exemple\u00a0: commentaires du jeu Fr\u00e9quence cardiaque (condens\u00e9).') + '</p>'
      + '<div class="doc-mock-modal" style="max-width:100%">'
      + '<div style="padding:20px; font-size:13px; line-height:1.6">'
      + content
      + '</div></div>';
  }

  function mockReviewTable(lang) {
    var en = lang === 'en';
    var reviews = [
      {
        name: 'Jane Smith',
        date: '2026-03-15',
        status: 'approved',
        statusLabel: en ? 'Approved' : 'Approuv\u00e9',
        version: '1.0.1',
        comment: en
          ? 'Concept set is comprehensive. Good coverage of the LOINC hierarchy. The exclusion of fetal heart rate with a dedicated concept set makes sense, as fetal HR is recorded at the maternal level and could be confused with the mother\'s own heart rate during data alignment.'
          : 'Jeu de concepts complet. Bonne couverture de la hi\u00e9rarchie LOINC. L\u2019exclusion de la fr\u00e9quence cardiaque f\u0153tale dans un jeu d\u00e9di\u00e9 est pertinente, car la FC f\u0153tale est enregistr\u00e9e au niveau maternel et pourrait \u00eatre confondue avec celle de la m\u00e8re lors de l\u2019alignement des donn\u00e9es.'
      },
      {
        name: 'John Doe',
        date: '2026-01-10',
        status: 'needs_revision',
        statusLabel: en ? 'Needs Revision' : '\u00c0 r\u00e9viser',
        version: '1.0.0',
        comment: en
          ? 'Fetal heart rate should be excluded from this set. It is recorded at the maternal level (in the mother\'s obstetric record), creating a risk of confusion with the mother\'s own heart rate. I suggest moving it to a dedicated concept set to prevent mixing fetal and maternal values during data alignment.'
          : 'La fr\u00e9quence cardiaque f\u0153tale devrait \u00eatre exclue de ce jeu. Elle est enregistr\u00e9e au niveau maternel (dans le dossier obst\u00e9trical de la m\u00e8re), ce qui cr\u00e9e un risque de confusion avec la FC de la m\u00e8re. Je sugg\u00e8re de la d\u00e9placer dans un jeu de concepts d\u00e9di\u00e9 pour \u00e9viter de m\u00e9langer les valeurs f\u0153tales et maternelles lors de l\u2019alignement.'
      }
    ];

    // Panel header with count and buttons
    var html = '<div class="doc-mock-modal" style="max-width:100%">'
      + '<div style="display:flex; align-items:center; gap:8px; padding:12px 16px; border-bottom:1px solid var(--gray-200)">'
      + '<h3 style="margin:0; font-size:14px; font-weight:600">' + (en ? 'Reviews' : 'Relectures') + '</h3>'
      + '<span class="badge badge-count">' + reviews.length + '</span>'
      + '<span style="flex:1"></span>'
      + '<button class="tab-btn-green" style="cursor:default"><i class="fab fa-github"></i> '
      + (en ? 'Propose on GitHub' : 'Proposer sur GitHub') + '</button>'
      + '<button class="tab-btn-green" style="cursor:default"><i class="fas fa-plus"></i> '
      + (en ? 'Add Review' : 'Ajouter une relecture') + '</button>'
      + '</div>';

    // Table
    html += '<div style="padding:0"><table style="margin:0"><thead><tr>'
      + '<th style="width:18%">' + (en ? 'Reviewer' : 'Relecteur') + '</th>'
      + '<th style="width:12%">' + (en ? 'Date' : 'Date') + '</th>'
      + '<th style="width:12%" class="td-center">' + (en ? 'Status' : 'Statut') + '</th>'
      + '<th style="width:10%">' + (en ? 'Version' : 'Version') + '</th>'
      + '<th style="width:48%">' + (en ? 'Comments' : 'Commentaires') + '</th>'
      + '</tr></thead><tbody>';

    for (var i = 0; i < reviews.length; i++) {
      var r = reviews[i];
      html += '<tr style="cursor:default">'
        + '<td>' + r.name + '</td>'
        + '<td>' + r.date + '</td>'
        + '<td class="td-center"><span class="status-badge ' + r.status + '" style="cursor:default; font-size:11px; padding:2px 8px">' + r.statusLabel + '</span></td>'
        + '<td>' + r.version + '</td>'
        + '<td style="font-size:12px">' + r.comment + '</td>'
        + '</tr>';
    }

    html += '</tbody></table></div></div>';
    return html;
  }

  function docLink(sectionId, label) {
    return '<a href="#/documentation?section=' + sectionId + '">' + label + '</a>';
  }

  // ==================== ENGLISH CONTENT ====================

  function introductionEN() {
    return '<h1>Introduction</h1>'
      + '<p>The <strong>INDICATE Data Dictionary</strong> is a web application for browsing, reviewing, '
      + 'and contributing to a curated library of standardized clinical concept sets for intensive care. '
      + 'It is designed to help harmonize ICU data across European institutions using the OMOP Common Data Model.</p>'

      + infoBox('What is INDICATE?',
        '<a href="https://indicate-europe.eu/" target="_blank">INDICATE</a> is a European initiative '
        + 'launched in December 2024, co-funded by the EU Digital Europe Programme (Grant No. 101167778). '
        + 'It aims to build a federated infrastructure for secure, cross-border ICU data sharing across '
        + '15 data providers in 12 European countries.')

      + '<h2>Why a Data Dictionary?</h2>'
      + '<p>Even with standardized terminologies like LOINC and SNOMED CT, a single clinical idea (e.g. '
      + '"Heart Rate") can be represented by hundreds of distinct standard concepts, varying by measurement '
      + 'method, specimen type, or clinical context. Selecting appropriate concepts requires combined '
      + 'clinical, data science, and terminology expertise.</p>'
      + '<p>The INDICATE Data Dictionary addresses this by providing expert-curated '
      + '<strong>concept sets</strong> \u2014 reusable collections of OMOP vocabulary concepts that '
      + 'define clinically meaningful variables. It follows the '
      + '<a href="https://ohdsi.github.io/TAB/Concept-Set-Specification.html" target="_blank">'
      + 'OHDSI Concept Set Specification</a>, ensuring interoperability with ATLAS and the broader OHDSI ecosystem.</p>'

      + '<h2>Key Features</h2>'
      + '<div class="doc-feature-grid">'
      + featureCard('fa-book', 'Concept Set Browser',
        'Browse concept sets organized by clinical category: vitals, labs, conditions, drugs, ventilation, and more.')
      + featureCard('fa-search', 'Concept Explorer',
        'Navigate inside each concept set, view individual concept details with links to ATHENA and FHIR, and explore vocabulary hierarchies interactively.')
      + featureCard('fa-comment-dots', 'Expert Guidance',
        'Each concept set includes expert comments (Markdown) with clinical context and ETL recommendations.')
      + featureCard('fa-chart-bar', 'Reference Statistics',
        'Expected distributions (histograms, percentiles) for data validation, with multiple profiles (Adult, Child, Newborn).')
      + featureCard('fa-user-check', 'Peer Review',
        'Submit reviews with status tracking, and propose changes on GitHub via pull requests.')
      + featureCard('fa-list-check', 'Projects',
        'Organize concept sets into research projects and export project-level concept lists as CSV.')
      + '</div>'

      + '<h2>Who is this for?</h2>'
      + '<div class="doc-audience-grid">'
      + audienceCard('fa-user-md', 'Clinicians & Researchers',
        'Provide expertise on concept definitions, review clinical relevance, and use curated concept sets for study design and cohort definition.')
      + audienceCard('fa-chart-line', 'Data Scientists',
        'Build ETL pipelines and federated queries with validated concept sets.')
      + audienceCard('fa-database', 'Data Engineers',
        'Map source data to OMOP CDM using recommended concept sets and unit conversions.')
      + '</div>'

      + '<h2>About the project</h2>'
      + '<p>Concept set definitions were developed through an iterative, consensus-building process. '
      + 'Use case leaders first identified the variables required for their clinical applications. '
      + 'These requirements were refined in bi-weekly interdisciplinary meetings bringing together '
      + 'clinical experts, data scientists, and interoperability specialists.</p>'
      + '<p>The library currently comprises over 330 concept sets organized into nine categories. '
      + 'All content is open source on '
      + '<a href="https://github.com/indicate-eu/data-dictionary" target="_blank">GitHub</a>. '
      + 'Learn more at <a href="https://indicate-europe.eu/" target="_blank">indicate-europe.eu</a>.</p>';
  }

  function gettingStartedEN() {
    return '<h1>Getting Started</h1>'
      + '<p>The application runs entirely in the browser \u2014 no installation or server required. '
      + 'Simply open the web page and start browsing.</p>'

      + '<h2>Quick Tour</h2>'
      + '<p>The navigation bar at the top provides access to the main sections:</p>'
      + '<ul>'
      + '<li><strong>Data Dictionary</strong> \u2014 Browse and search concept sets (' + docLink('browsing', 'details') + ')</li>'
      + '<li><strong>Mapping Recommendations</strong> \u2014 Guidance for mapping local variables (' + docLink('mapping-recommendations', 'details') + ')</li>'
      + '<li><strong>Projects</strong> \u2014 Group concept sets by research project (' + docLink('projects', 'details') + ')</li>'
      + '<li><strong>Documentation</strong> \u2014 This page</li>'
      + '</ul>'

      + '<h2>Optional: Import OHDSI Vocabularies</h2>'
      + '<p>For advanced features (concept search, descendant expansion, hierarchy visualization, '
      + 'concept set optimization), you can import OHDSI vocabulary files into a local DuckDB database '
      + 'that runs in the browser. See ' + docLink('ohdsi-vocabularies', 'OHDSI Vocabularies') + '.</p>'

      + '<h2>User Profile</h2>'
      + '<p>Click your name in the top-right corner to set your profile.</p>'
      + '<p>The <strong>Author</strong> tab stores your name, affiliation, profession, and ORCID \u2014 '
      + 'this information is embedded in concept sets you create or review.</p>'
      + '<p>The <strong>Organisation</strong> tab lets you set the organisation name and URL that will '
      + 'appear in concept set metadata.</p>'
      + profileMock('en')

      + '<h2>Language</h2>'
      + '<p>Toggle between English and French using the <strong>EN</strong>/<strong>FR</strong> '
      + 'button in the header. Concept set names, categories, and descriptions are multilingual (currently English and French). '
      + 'Support for additional languages may be added in the future.</p>'

      + '<h2>Local Storage</h2>'
      + '<p>All your edits (concept sets, projects, reviews) are stored in your browser\'s local storage. '
      + 'They persist across sessions but are local to your browser. To share changes, use the '
      + docLink('reviewing', 'GitHub workflow') + '.</p>';
  }

  function whatAreConceptSetsEN() {
    return '<h1>What are Concept Sets?</h1>'

      + '<p>A <strong>concept set</strong> is a reusable collection of OMOP vocabulary concepts that '
      + 'defines a clinically meaningful variable (e.g., "Heart Rate", "Serum Creatinine", "Norepinephrine"). '
      + 'Rather than working with individual LOINC or SNOMED codes, researchers and data engineers work '
      + 'with concept sets that group related codes under intuitive clinical labels.</p>'

      + '<h2>The OHDSI Concept Set Specification</h2>'
      + '<p>Each concept set follows the '
      + '<a href="https://ohdsi.github.io/TAB/Concept-Set-Specification.html" target="_blank">'
      + 'OHDSI Concept Set Specification</a>, the standard format used by ATLAS and the OHDSI ecosystem. '
      + 'A concept set expression is a list of items, where each item references an OMOP concept and has '
      + 'three boolean flags:</p>'
      + '<ul>'
      + '<li><strong>Exclude</strong> \u2014 Remove this concept (and optionally its descendants) from the set</li>'
      + '<li><strong>Descendants</strong> \u2014 Include all descendant concepts in the vocabulary hierarchy</li>'
      + '<li><strong>Mapped</strong> \u2014 Include concepts linked via "Maps to" relationships</li>'
      + '</ul>'

      + infoBox('Expression vs. Resolved',
        'The <strong>expression</strong> is what you author \u2014 a compact list of selected concepts with flags. '
        + 'The <strong>resolved set</strong> is the expanded result after applying descendants, mapped, and exclusion '
        + 'logic. For example, an expression with one LOINC classification concept + Descendants might resolve '
        + 'to dozens of specific measurement codes.')

      + '<h2>Extended Metadata</h2>'
      + '<p>Beyond the standard OHDSI specification, each concept set in the INDICATE library includes '
      + 'additional metadata:</p>'
      + '<ul>'
      + '<li><strong>Version</strong> \u2014 Semantic versioning (e.g. 1.0.0) with a version history log</li>'
      + '<li><strong>Review status</strong> \u2014 Draft, Pending Review, Approved, Needs Revision, or Deprecated</li>'
      + '<li><strong>Author info</strong> \u2014 Creator name, affiliation, profession, ORCID</li>'
      + '<li><strong>Translations</strong> \u2014 Multilingual name, category, and subcategory (currently English and French, extensible to other languages)</li>'
      + '<li><strong>Expert comments</strong> \u2014 Markdown field for clinical guidance and ETL recommendations</li>'
      + '<li><strong>Statistical profiles</strong> \u2014 Expected distributions for data validation</li>'
      + '<li><strong>Review history</strong> \u2014 Reviewer name, date, status, and comments for each review</li>'
      + '</ul>'

      + '<h2>Categories</h2>'
      + '<p>Concept sets are organized into nine clinical categories:</p>'
      + '<ul>'
      + '<li>Demographics & Encounters</li>'
      + '<li>Conditions (diagnoses)</li>'
      + '<li>Clinical Observations (assessment scales)</li>'
      + '<li>Vital Signs</li>'
      + '<li>Laboratory Measurements</li>'
      + '<li>Microbiology</li>'
      + '<li>Ventilation</li>'
      + '<li>Drugs</li>'
      + '<li>Procedures</li>'
      + '</ul>'

      + '<h2>Use Cases</h2>'
      + '<p>These curated, reviewed, and versioned concept sets can be used for:</p>'
      + '<ul>'
      + '<li><strong>Cohort definition</strong> \u2014 As building blocks in ATLAS or custom queries</li>'
      + '<li><strong>ETL development</strong> \u2014 To prioritize and validate concept mappings</li>'
      + '<li><strong>Study feasibility</strong> \u2014 To evaluate data availability across a federated network</li>'
      + '</ul>';
  }

  function browsingEN() {
    return '<h1>Browsing Concept Sets</h1>'
      + '<p>The <strong>Data Dictionary</strong> page displays all concept sets in a searchable, filterable table.</p>'

      + '<h2>Category Badges</h2>'
      + '<p>At the top of the page, badges show each category with its concept set count. '
      + 'Click a badge to filter the table to that category. Click again to remove the filter. '
      + 'Multiple categories can be selected simultaneously.</p>'
      + '<div class="category-badges" style="justify-content:center; margin:16px 0">'
      + '<span class="category-badge">Vital Signs <span class="count">10</span></span>'
      + '<span class="category-badge active">Laboratory <span class="count">76</span></span>'
      + '<span class="category-badge">Drugs <span class="count">112</span></span>'
      + '<span class="category-badge">Ventilation <span class="count">26</span></span>'
      + '</div>'

      + '<h2>Searching & Filtering</h2>'
      + '<p>Each column header has a filter. Most columns use exact matching, but the '
      + '<strong>Name</strong> column uses <strong>fuzzy search</strong> \u2014 for example, '
      + 'typing "hart rate" will still find "Heart rate".</p>'
      + '<p>Additional multi-select dropdowns let you filter by:</p>'
      + '<ul>'
      + '<li><strong>Category</strong> \u2014 Same as clicking badges, with item counts</li>'
      + '<li><strong>Subcategory</strong> \u2014 Dynamically populated based on selected categories</li>'
      + '<li><strong>Review Status</strong> \u2014 Filter by Draft, Approved, Pending Review, etc.</li>'
      + '</ul>'

      + '<h2>Table</h2>'
      + '<p>Click any column header to sort. Click any row to open the '
      + docLink('concept-set-details', 'detail view') + '.</p>'
      + mockConceptSetTable('en');
  }

  function conceptSetDetailsEN() {
    return '<h1>Concept Set Details</h1>'
      + '<p>The detail view shows everything about a concept set, organized in four tabs: <strong>Concepts</strong>, <strong>Comments</strong>, <strong>Statistics</strong>, and <strong>Review</strong>.</p>'

      + '<h2 id="doc-tab-concepts">Concepts Tab</h2>'
      + detailTabs('en', 'concepts')
      + '<p>This tab has two modes, toggled with a switch: <strong>Expression</strong> and <strong>Resolved</strong>.</p>'

      + '<h3>Expression Mode</h3>'
      + conceptModeToggle('en', 'expression')
      + '<p>Shows the concept set expression \u2014 the authored items with their flags.</p>'
      + '<p>Each row shows Vocabulary, Concept Name, Concept Code, Domain, Concept Class, '
      + 'Standard status, and three boolean flags: <strong>Exclude</strong>, '
      + '<strong>Descendants</strong>, and <strong>Mapped</strong>.</p>'
      + '<p>These flags control how the expression is resolved into the final set of concepts. '
      + 'See ' + docLink('editing-concept-sets', 'Editing Concept Sets') + ' for detailed explanations.</p>'
      + '<p>Use the column filters (vocabulary, domain, standard, fuzzy name search) to navigate large expressions.</p>'
      + '<p style="font-size:12px; color:var(--text-muted); margin-bottom:4px"><i class="fas fa-info-circle"></i> '
      + 'Example: Heart rate concept set expression.'
      + '</p>'
      + mockExpressionTable('en')

      + '<h3>Resolved Mode</h3>'
      + conceptModeToggle('en', 'resolved')
      + '<p>Shows the expanded result after applying all expression logic. This is the actual set of '
      + 'OMOP concepts that would be used in a query. Columns include Concept ID, Vocabulary, Name, '
      + 'Code, Domain, Standard, and Concept Class.</p>'
      + '<p>If an OHDSI vocabulary database is loaded (see ' + docLink('ohdsi-vocabularies', 'OHDSI Vocabularies') + '), '
      + 'resolution is computed live in the browser. Otherwise, pre-computed resolved sets from the '
      + 'repository are used.</p>'
      + '<p style="font-size:12px; color:var(--text-muted); margin-bottom:4px"><i class="fas fa-info-circle"></i> '
      + (App.lang === 'en'
        ? 'Example: Heart rate resolved set \u2014 the actual standard OMOP concepts after expansion.'
        : 'Exemple\u00a0: jeu r\u00e9solu Fr\u00e9quence cardiaque \u2014 les concepts OMOP standards apr\u00e8s expansion.')
      + '</p>'
      + mockResolvedTable(App.lang)

      + '<h3>Concept Detail Panel</h3>'
      + '<p>' + (App.lang === 'en'
        ? 'Click any concept row to display a detail panel. It contains three sections:'
        : 'Cliquez sur un concept pour afficher le panneau de d\u00e9tails. Il contient trois sections\u00a0:')
      + '</p>'

      + '<p style="font-size:12px; color:var(--text-muted); margin-bottom:4px"><i class="fas fa-info-circle"></i> '
      + (App.lang === 'en'
        ? 'Example: "Heart rate --W exercise" (LOINC 89273-7).'
        : 'Exemple\u00a0: \u00ab Heart rate --W exercise \u00bb (LOINC 89273-7).')
      + '</p>'
      + mockConceptDetailPanel(App.lang)

      + '<p style="margin-top:20px">' + (App.lang === 'en'
        ? 'The <strong>Concept Details</strong> grid shows the full metadata '
          + 'with links to <a href="https://athena.ohdsi.org/" target="_blank">ATHENA</a> (via Concept ID) '
          + 'and the <a href="https://tx.fhir.org/r4/" target="_blank">FHIR Terminology Server</a> (via FHIR Resource).'
        : 'La grille <strong>D\u00e9tails du concept</strong> affiche toutes les m\u00e9tadonn\u00e9es, '
          + 'et des liens vers <a href="https://athena.ohdsi.org/" target="_blank">ATHENA</a> (via l\u2019ID) '
          + 'et le <a href="https://tx.fhir.org/r4/" target="_blank">serveur de terminologie FHIR</a>.')
      + '</p>'
      + '<p>' + (App.lang === 'en'
        ? 'Three tabs below the metadata provide additional information:'
        : 'Trois onglets sous les m\u00e9tadonn\u00e9es fournissent des informations compl\u00e9mentaires\u00a0:')
      + '</p>'
      + '<ul>'
      + '<li><strong>Related</strong> \u2014 ' + (App.lang === 'en'
        ? 'Relationships to other concepts (Is a, Has component, Maps to, etc.). Filterable by relationship type, vocabulary, and name.'
        : 'Relations avec d\u2019autres concepts (Is a, Has component, Maps to, etc.). Filtrables par type de relation, vocabulaire et nom.')
      + '</li>'
      + '<li><strong>' + (App.lang === 'en' ? 'Hierarchy' : 'Hi\u00e9rarchie') + '</strong> \u2014 ' + (App.lang === 'en'
        ? 'Interactive force-directed graph (vis.js) showing ancestors, descendants, and related concepts. Click any node to navigate to that concept.'
        : 'Graphe interactif (vis.js) montrant anc\u00eatres, descendants et concepts li\u00e9s. Cliquez sur un n\u0153ud pour naviguer.')
      + '</li>'
      + '<li><strong>' + (App.lang === 'en' ? 'Synonyms' : 'Synonymes') + '</strong> \u2014 ' + (App.lang === 'en'
        ? 'Alternative names for the concept from the OMOP vocabulary (including translations in other languages).'
        : 'Noms alternatifs du concept depuis le vocabulaire OMOP (y compris des traductions dans d\u2019autres langues).')
      + '</li></ul>'

      + '<h2 id="doc-tab-comments">Comments Tab</h2>'
      + detailTabs('en', 'comments')
      + '<p>Displays expert guidance in Markdown. Comments typically describe:</p>'
      + '<ul>'
      + '<li>The clinical meaning and context of the concept set</li>'
      + '<li>Which concepts to prefer in specific scenarios</li>'
      + '<li>Common pitfalls during ETL</li>'
      + '<li>Differences between similar concepts across vocabularies</li>'
      + '</ul>'
      + '<p>In edit mode, a dual-pane editor with live Markdown preview is available.</p>'
      + mockCommentsPanel('en')
      + '<p>For broader recommendations that apply across multiple concept sets (e.g. general ETL guidance, '
      + 'mapping strategies), see the ' + docLink('mapping-recommendations', 'Mapping Recommendations') + ' page.</p>'

      + '<h2 id="doc-tab-statistics">Statistics Tab</h2>'
      + detailTabs('en', 'statistics')
      + infoBox('Work in Progress',
        'This feature is still under discussion and has not yet been implemented in practice. '
        + 'The format and content of statistical profiles may evolve.', 'warning')
      + '<p>Shows expected data distributions to help validate your data during ETL:</p>'
      + '<ul>'
      + '<li><strong>Numeric data</strong> \u2014 Min, P5, P25 (Q1), Median, Mean, P75 (Q3), P95, Max, SD, CV</li>'
      + '<li><strong>Histograms</strong> \u2014 Horizontal bar charts of the value distribution</li>'
      + '<li><strong>Categorical data</strong> \u2014 Categories with counts and percentages</li>'
      + '<li><strong>Multiple profiles</strong> \u2014 e.g. Adult, Child, Newborn with different reference ranges</li>'
      + '<li><strong>Measurement frequency</strong> \u2014 Typical recording interval (hourly, daily, etc.)</li>'
      + '</ul>'

      + '<h2 id="doc-tab-review">Review Tab</h2>'
      + detailTabs('en', 'review')
      + '<p>Displays the review history for this concept set. Each review records the reviewer, date, '
      + 'status, version reviewed, and comments.</p>'
      + mockReviewTable('en')
      + '<p>See ' + docLink('reviewing', 'Reviewing & GitHub') + ' for the full workflow on submitting '
      + 'reviews and proposing changes on GitHub.</p>'

      + '<h2>Header Metadata</h2>'
      + '<p>The detail header shows:</p>'
      + '<ul>'
      + '<li><strong>Version badge</strong> \u2014 Click to view the version history log</li>'
      + '<li><strong>Review status badge</strong> \u2014 Click to change status (in edit mode)</li>'
      + '<li><strong>Export</strong> \u2014 Download or copy as JSON, propose on GitHub, '
      + 'or generate an OMOP SQL query with unit conversions (see ' + docLink('exporting', 'Exporting') + ')</li>'
      + '</ul>';
  }

  function editingConceptSetsEN() {
    return '<h1>Editing Concept Sets</h1>'
      + '<p>All edits are saved to your browser\u2019s local storage. They persist across sessions '
      + 'but are tied to your browser.</p>'
      + infoBox('Local storage warning',
        'If you clear your browser data, local edits will be lost. '
        + 'Remember to <strong>export</strong> your work as JSON and/or '
        + '<strong>propose changes on GitHub</strong> via a pull request to preserve them. '
        + 'See ' + docLink('exporting', 'Exporting') + ' and '
        + docLink('reviewing', 'Reviewing & GitHub') + '.', 'warning')

      + '<p>This section covers two levels of editing: first, managing the list of concept sets '
      + '(adding, deleting, renaming); then, editing the details of an individual concept set '
      + '(expression, comments, statistics).</p>'

      // ===== PART 1: LIST EDITING =====
      + '<h2>Editing the Concept Set List</h2>'
      + '<p>These actions apply to the main Data Dictionary table.</p>'

      + '<h3>Entering Edit Mode</h3>'
      + '<p>Click the <strong>Edit</strong> button in the toolbar:</p>'
      + '<div style="display:flex; gap:6px; justify-content:center; margin:16px 0; flex-wrap:wrap; align-items:center">'
      + '<button class="btn-primary-custom btn-gray" style="cursor:default"><i class="fas fa-pen"></i> Edit</button>'
      + '<button class="btn-primary-custom" style="cursor:default"><i class="fas fa-download"></i> Export</button>'
      + '</div>'
      + '<p>The toolbar changes to show selection, add, and save/cancel controls:</p>'
      + '<div style="display:flex; gap:6px; justify-content:center; margin:16px 0; flex-wrap:wrap; align-items:center">'
      + '<button class="btn-secondary-custom btn-sm" style="cursor:default"><i class="fas fa-check-square"></i></button>'
      + '<button class="btn-secondary-custom btn-sm" style="cursor:default"><i class="far fa-square"></i></button>'
      + '<button class="btn-danger-custom btn-sm" style="cursor:default"><i class="fas fa-trash"></i></button>'
      + '<span style="font-size:12px; color:var(--text-muted)">0 selected</span>'
      + '<button class="btn-primary-custom btn-gray" style="cursor:default"><i class="fas fa-times"></i> '
      + (App.lang === 'en' ? 'Cancel' : 'Annuler') + '</button>'
      + '<button class="btn-primary-custom" style="cursor:default"><i class="fas fa-save"></i> '
      + (App.lang === 'en' ? 'Save' : 'Enregistrer') + '</button>'
      + '<button class="btn-success-custom" style="cursor:default"><i class="fas fa-plus"></i> '
      + (App.lang === 'en' ? 'Add Concept Set' : 'Ajouter un jeu de concepts') + '</button>'
      + '</div>'

      + '<h3>Adding a Concept Set</h3>'
      + '<p>In edit mode, click <strong>Add Concept Set</strong> (green button). A modal opens where you '
      + 'provide a name and category (required), and optionally a subcategory and description. '
      + 'Use the <strong>+</strong> button next to category or subcategory to create a new one.</p>'
      + mockNewConceptSetModal('en')

      + '<h3>Selecting, Editing & Deleting</h3>'
      + '<p>In edit mode, two extra columns appear on each row: a <strong>checkbox</strong> for selection '
      + 'and a <strong>pen icon</strong> to edit that concept set.</p>'
      + mockEditModeTable(App.lang)
      + '<p style="margin-top:16px"><button class="cs-row-edit-btn" style="cursor:default"><i class="fas fa-pen"></i></button> '
      + '<strong>' + (App.lang === 'en' ? 'Edit' : 'Modifier') + '</strong> \u2014 '
      + (App.lang === 'en'
        ? 'Opens the edit modal (same form as "New Concept Set", pre-filled with the existing values).'
        : 'Ouvre le modal d\u2019\u00e9dition (m\u00eame formulaire que \u00ab Nouveau jeu de concepts \u00bb, pr\u00e9-rempli).')
      + '</p>'
      + '<p><button class="btn-secondary-custom btn-sm" style="cursor:default"><i class="fas fa-check-square"></i></button> '
      + '<button class="btn-secondary-custom btn-sm" style="cursor:default"><i class="far fa-square"></i></button> '
      + '<strong>' + (App.lang === 'en' ? 'Select All / Unselect All' : 'Tout s\u00e9lectionner / D\u00e9s\u00e9lectionner') + '</strong> \u2014 '
      + (App.lang === 'en' ? 'Toggle selection on all rows.' : 'Basculer la s\u00e9lection sur toutes les lignes.')
      + '</p>'
      + '<p><button class="btn-danger-custom btn-sm" style="cursor:default"><i class="fas fa-trash"></i></button> '
      + '<strong>' + (App.lang === 'en' ? 'Delete' : 'Supprimer') + '</strong> \u2014 '
      + (App.lang === 'en' ? 'Remove all selected concept sets.' : 'Supprimer les jeux de concepts s\u00e9lectionn\u00e9s.')
      + '</p>'

      + '<h3>Saving & Cancelling</h3>'
      + '<p>All changes made in edit mode (additions, edits, deletions) are pending until you explicitly act:</p>'
      + '<ul>'
      + '<li><strong>Save</strong> \u2014 Commits all pending changes to local storage</li>'
      + '<li><strong>Cancel</strong> \u2014 Discards all pending changes, restoring the list to its state before '
      + 'entering edit mode. This undoes everything: additions, edits, and deletions.</li>'
      + '</ul>'

      // ===== PART 2: DETAIL EDITING =====
      + '<h2>Editing a Concept Set\u2019s Details</h2>'
      + '<p>Open a concept set, then click <strong>Edit</strong> in the detail header. '
      + 'The Edit and Export buttons are replaced by Import, Cancel, and Save:</p>'
      + '<div style="display:flex; gap:6px; justify-content:center; margin:16px 0; flex-wrap:wrap">'
      + '<button class="btn-primary-custom btn-purple" style="cursor:default"><i class="fas fa-file-import"></i> Import</button>'
      + '<button class="btn-primary-custom btn-gray" style="cursor:default"><i class="fas fa-times"></i> Cancel</button>'
      + '<button class="btn-primary-custom" style="cursor:default"><i class="fas fa-save"></i> Save</button>'
      + '</div>'

      + '<h3>Expression Flags</h3>'
      + '<p>Each concept in the expression has three flags that you can toggle directly in the table. '
      + 'These flags follow the '
      + '<a href="https://ohdsi.github.io/TAB/Concept-Set-Specification.html" target="_blank">'
      + 'OHDSI Concept Set Specification</a>:</p>'
      + '<p style="font-size:12px; color:var(--text-muted); margin-bottom:4px"><i class="fas fa-info-circle"></i> '
      + (App.lang === 'en'
        ? 'Example: Heart rate expression in edit mode. Toggle switches control each flag. The trash icon deletes individual items.'
        : 'Exemple\u00a0: expression Fr\u00e9quence cardiaque en mode \u00e9dition. Les interrupteurs contr\u00f4lent chaque option. L\u2019ic\u00f4ne corbeille supprime un \u00e9l\u00e9ment.')
      + '</p>'
      + mockExpressionEditTable(App.lang)

      + '<p><strong>Descendants</strong> \u2014 When checked, all descendant concepts in the '
      + 'vocabulary hierarchy are automatically included. OMOP vocabularies organize concepts '
      + 'in hierarchical trees using "Is a" / "Subsumes" relationships (stored in the '
      + 'CONCEPT_ANCESTOR table). For example, the LOINC hierarchy concept "Heart rate" has dozens '
      + 'of descendants like "Heart rate \u2013\u2013resting", "Heart rate \u2013\u2013sitting", '
      + '"Heart rate by Pulse oximetry", etc. Checking Descendants on a parent concept captures '
      + 'all of them without listing each one individually.</p>'

      + '<p><strong>Mapped</strong> \u2014 When checked, non-standard concepts that are linked to the '
      + 'selected concept via "Maps to" / "Mapped from" relationships are also included. '
      + 'In the OMOP vocabulary, each clinical idea has one designated <strong>Standard</strong> concept '
      + '(marked "S"). Other vocabulary codes representing the same idea are <strong>non-standard</strong> '
      + 'and are linked to the Standard concept via "Maps to". For example, SNOMED "Heart rate" '
      + '(concept ID 4239408, non-standard) maps to LOINC "Heart rate" (concept ID 3027018, Standard). '
      + 'Checking Mapped ensures that non-standard concepts from other vocabularies are captured alongside the '
      + 'standard concept.</p>'

      + '<p><strong>Exclude</strong> \u2014 When checked, this concept is removed from the resolved set. '
      + 'If Descendants is also checked, all its descendant concepts are excluded too. This allows you to '
      + 'include a broad parent concept with its descendants, then selectively exclude specific branches. '
      + 'For example, in the Heart rate concept set, "Fetal heart rate" is excluded with Descendants to '
      + 'remove fetal-specific measurements from the set.</p>'

      + infoBox('Resolution Algorithm',
        'The concept set is resolved in three steps:'
        + '<ol style="margin:8px 0 0 0; padding-left:20px">'
        + '<li>Build the <strong>inclusion set</strong> from all items where Exclude is unchecked, expanding via Descendants and Mapped as configured</li>'
        + '<li>Build the <strong>exclusion set</strong> from items where Exclude is checked, with the same expansion logic</li>'
        + '<li>Final result = <strong>inclusion set minus exclusion set</strong></li>'
        + '</ol>')

      + '<h3>Adding Concepts</h3>'
      + '<p>In edit mode, the expression toolbar shows additional buttons:</p>'
      + '<div style="display:flex; gap:6px; justify-content:center; margin:16px 0; flex-wrap:wrap; align-items:center">'
      + '<button class="btn-secondary-custom btn-sm" style="cursor:default"><i class="fas fa-check-square"></i></button>'
      + '<button class="btn-secondary-custom btn-sm" style="cursor:default"><i class="far fa-square"></i></button>'
      + '<button class="btn-danger-custom btn-sm" style="cursor:default"><i class="fas fa-trash"></i></button>'
      + '<span style="font-size:12px; color:var(--text-muted)">0 selected</span>'
      + '<button class="btn-success-custom" style="cursor:default"><i class="fas fa-plus"></i> Add Concepts</button>'
      + '<button class="btn-primary-custom" style="cursor:default"><i class="fas fa-magic"></i> Optimize</button>'
      + '</div>'
      + '<p>Click <strong>Add Concepts</strong> to open a fullscreen modal with two tabs:</p>'
      + '<div style="display:flex; gap:0; justify-content:center; margin:16px 0">'
      + '<button class="expr-add-tab active" style="cursor:default">'
      + (App.lang === 'en' ? 'OHDSI Vocabularies' : 'Vocabulaires OHDSI') + '</button>'
      + '<button class="expr-add-tab" style="cursor:default">'
      + (App.lang === 'en' ? 'Custom Concept' : 'Concept personnalis\u00e9') + '</button>'
      + '</div>'
      + '<ul>'
      + '<li><strong>' + (App.lang === 'en' ? 'OHDSI Vocabularies' : 'Vocabulaires OHDSI') + '</strong> \u2014 '
      + (App.lang === 'en'
        ? 'Search and add existing OMOP standard concepts from the OHDSI vocabulary database (SNOMED, LOINC, RxNorm, etc.). This is the primary way to build concept set expressions.'
        : 'Recherchez et ajoutez des concepts OMOP standards existants depuis la base de vocabulaires OHDSI (SNOMED, LOINC, RxNorm, etc.). C\u2019est la m\u00e9thode principale pour construire les expressions.')
      + '</li>'
      + '<li><strong>' + (App.lang === 'en' ? 'Custom Concept' : 'Concept personnalis\u00e9') + '</strong> \u2014 '
      + (App.lang === 'en'
        ? 'Create a non-OMOP concept manually when no standard concept exists in the OHDSI vocabularies. Use as a last resort \u2014 custom concepts are not interoperable with the OHDSI ecosystem.'
        : 'Cr\u00e9ez manuellement un concept hors OMOP quand aucun concept standard n\u2019existe dans les vocabulaires OHDSI. \u00c0 utiliser en dernier recours \u2014 les concepts personnalis\u00e9s ne sont pas interop\u00e9rables avec l\u2019\u00e9cosyst\u00e8me OHDSI.')
      + '</li>'
      + '</ul>'

      // --- OHDSI Vocabularies tab ---
      + '<h4>' + (App.lang === 'en' ? 'OHDSI Vocabularies' : 'Vocabulaires OHDSI') + '</h4>'
      + '<p>' + (App.lang === 'en'
        ? 'Search the local OHDSI vocabulary database by name, concept ID, or code. Requires '
          + docLink('ohdsi-vocabularies', 'importing vocabularies') + ' first. '
          + 'The search uses <strong>fuzzy matching</strong> on concept names.'
        : 'Recherchez dans la base de vocabulaires OHDSI locale par nom, ID ou code. N\u00e9cessite l\u2019'
          + docLink('ohdsi-vocabularies', 'import des vocabulaires')
          + '. La recherche utilise une <strong>correspondance floue</strong> sur les noms.')
      + '</p>'

      // Search bar mock
      + '<div class="doc-mock-modal" style="max-width:100%; padding:12px 16px">'
      + '<div style="display:flex; gap:6px; align-items:center; flex-wrap:wrap">'
      + '<input type="text" class="form-input" placeholder="'
      + (App.lang === 'en' ? 'Search concepts by name, code, or ID...' : 'Rechercher par nom, code ou ID...')
      + '" value="heart rate" readonly style="flex:1; min-width:200px">'
      + '<button class="btn-primary-custom" style="cursor:default"><i class="fas fa-search"></i> '
      + (App.lang === 'en' ? 'Search' : 'Rechercher') + '</button>'
      + '<button class="btn-primary-custom btn-gray" style="cursor:default"><i class="fas fa-filter"></i> '
      + (App.lang === 'en' ? 'Filters' : 'Filtres') + '</button>'
      + '<label style="display:inline-flex; align-items:center; gap:4px; font-size:12px; color:var(--text-muted); white-space:nowrap">'
      + '<input type="checkbox" checked onclick="return false"> <span>Limit 10K</span></label>'
      + '</div></div>'

      + '<p style="margin-top:16px">' + (App.lang === 'en'
        ? 'The <strong>Filters</strong> button opens a popup to narrow results:'
        : 'Le bouton <strong>Filtres</strong> ouvre un popup pour affiner les r\u00e9sultats\u00a0:')
      + '</p>'
      + mockFiltersPopup(App.lang)
      + '<p>' + (App.lang === 'en'
        ? '<strong>Limit 10K</strong> caps results at 10,000 to avoid overloading the table.'
        : '<strong>Limit 10K</strong> limite les r\u00e9sultats \u00e0 10\u202f000 pour \u00e9viter de surcharger le tableau.')
      + '</p>'

      // Results table mock
      + '<p>' + (App.lang === 'en'
        ? 'Results are displayed in a datatable with column filters:'
        : 'Les r\u00e9sultats sont affich\u00e9s dans un tableau avec filtres par colonne\u00a0:')
      + '</p>'
      + mockAddConceptsTable(App.lang)

      + '<p>' + (App.lang === 'en'
        ? 'Below the table, two panels show details for the selected concept:'
        : 'Sous le tableau, deux panneaux affichent les d\u00e9tails du concept s\u00e9lectionn\u00e9\u00a0:')
      + '</p>'
      + '<ul>'
      + '<li><strong>' + (App.lang === 'en' ? 'Concept Details' : 'D\u00e9tails du concept')
      + '</strong> \u2014 ' + (App.lang === 'en'
        ? 'Full metadata, ATHENA and FHIR links'
        : 'M\u00e9tadonn\u00e9es compl\u00e8tes, liens ATHENA et FHIR')
      + '</li>'
      + '<li><strong>' + (App.lang === 'en' ? 'Hierarchy' : 'Hi\u00e9rarchie')
      + '</strong> \u2014 ' + (App.lang === 'en'
        ? 'Interactive graph of ancestors, descendants, and related concepts'
        : 'Graphe interactif des anc\u00eatres, descendants et concepts li\u00e9s')
      + '</li></ul>'

      // Footer mock
      + '<p>' + (App.lang === 'en'
        ? 'At the bottom, configure the flags and add the selected concept(s):'
        : 'En bas, configurez les options et ajoutez le(s) concept(s) s\u00e9lectionn\u00e9(s)\u00a0:')
      + '</p>'
      + mockAddConceptsFooter(App.lang, false)

      + '<p>' + (App.lang === 'en'
        ? 'Check <strong>Multiple Selection</strong> to select several concepts at once using checkboxes '
          + 'in the table, then add them all in one click.'
        : 'Cochez <strong>S\u00e9lection multiple</strong> pour s\u00e9lectionner plusieurs concepts avec les '
          + 'cases \u00e0 cocher du tableau, puis les ajouter en une seule fois.')
      + '</p>'

      // --- Custom Concept tab ---
      + '<h4>' + (App.lang === 'en' ? 'Custom Concept' : 'Concept personnalis\u00e9') + '</h4>'
      + '<p>' + (App.lang === 'en'
        ? 'Create non-OMOP concepts when no standard concept exists. Use sparingly \u2014 custom concepts break interoperability.'
        : 'Cr\u00e9ez des concepts hors OMOP quand aucun concept standard n\u2019existe. \u00c0 utiliser avec parcimonie.')
      + '</p>'
      + mockCustomConceptForm(App.lang)
      + '<p>' + (App.lang === 'en'
        ? 'Only the <strong>Exclude</strong> toggle is available for custom concepts, since Descendants and Mapped '
          + 'rely on OMOP vocabulary relationships that do not exist for custom entries.'
        : 'Seule l\u2019option <strong>Exclure</strong> est disponible pour les concepts personnalis\u00e9s, '
          + 'car Descendants et Mapp\u00e9 reposent sur des relations de vocabulaire OMOP inexistantes pour les entr\u00e9es personnalis\u00e9es.')
      + '</p>'
      + mockAddConceptsFooter(App.lang, true)

      + '<h3>Import JSON</h3>'
      + '<p>Click <strong>Import</strong> (purple button) to paste an ATLAS-format or INDICATE-format '
      + 'concept set expression. The importer accepts both UPPERCASE (ATLAS) and camelCase (INDICATE) '
      + 'field names, deduplicates by concept ID, and reports added/skipped counts.</p>'

      + '<h3>Deleting Concepts</h3>'
      + '<p>Use the trash icon on each row, or select multiple rows with checkboxes and click the '
      + 'red trash button in the toolbar.</p>'

      + '<h3>Optimizing the Expression</h3>'
      + '<p>Click <strong>Optimize</strong> to simplify the expression using vocabulary hierarchy analysis '
      + '(requires an OHDSI vocabulary database). The optimizer:</p>'
      + '<ul>'
      + '<li>Removes descendants already covered by a parent\'s "Include Descendants" flag (top-down)</li>'
      + '<li>Removes parent items that don\'t broaden scope (bottom-up)</li>'
      + '<li>Shows a before/after comparison with the items that would be removed or added</li>'
      + '<li>Warns if the optimization changes the resolved set</li>'
      + '</ul>'

      + '<h3>Editing Comments</h3>'
      + '<p>In the Comments tab, edit mode opens an ACE editor with Markdown syntax highlighting '
      + 'and a live preview panel. Use Cmd/Ctrl+S to save. Comments are stored per language.</p>'

      + '<h3>Editing Statistics</h3>'
      + '<p>In the Statistics tab, edit mode opens a JSON editor. A template with the expected '
      + 'structure is provided. You can define numeric data (min, max, mean, median, SD, percentiles, '
      + 'histogram), categorical data, measurement frequency, and multiple population profiles.</p>'

      + '<h3>Version & Status</h3>'
      + '<p>When saving changes, you can update the version (suggested: patch increment) and add '
      + 'a version summary. The review status can be changed via the status badge in the header.</p>';
  }

  function reviewingEN() {
    return '<h1>Reviewing & Proposing on GitHub</h1>'
      + '<p>The INDICATE Data Dictionary uses a GitHub-based workflow for contributing changes. '
      + 'All content is stored as JSON files in the '
      + '<a href="https://github.com/indicate-eu/data-dictionary" target="_blank">'
      + 'indicate-eu/data-dictionary</a> repository.</p>'

      // ===== SUBMITTING A REVIEW =====
      + '<h2>Submitting a Review</h2>'
      + '<p>Open a concept set, go to the <strong>Review</strong> tab, and click '
      + '<button class="tab-btn-green" style="cursor:default"><i class="fas fa-plus"></i> Add Review</button>. '
      + 'A fullscreen editor opens:</p>'

      // Mock review modal
      + '<div class="doc-mock-modal" style="max-width:100%">'
      // Header
      + '<div style="padding:6px 15px; border-bottom:1px solid #ddd; background:#f8f9fa; display:flex; align-items:center; gap:12px">'
      + '<h3 style="margin:0; font-size:15px">Add Review</h3>'
      + '<label style="font-size:12px; font-weight:600; color:var(--text-muted)">Status:</label>'
      + '<select class="form-input" disabled style="width:140px; height:28px; font-size:12px; padding:2px 8px">'
      + '<option>Needs Revision</option></select>'
      + '<button class="btn-success-custom" style="cursor:default"><i class="fas fa-check"></i> Submit Review</button>'
      + '<span style="flex:1"></span>'
      + '<span class="modal-close" style="cursor:default; font-size:20px">&times;</span>'
      + '</div>'
      // Body: Editor + Preview
      + '<div style="display:flex; min-height:180px">'
      // Editor
      + '<div style="flex:1; border-right:1px solid #ddd; display:flex; flex-direction:column">'
      + '<div style="font-size:12px; font-weight:600; color:var(--text-muted); padding:6px 12px; border-bottom:1px solid #eee">'
      + '<i class="fas fa-pencil-alt"></i> Editor</div>'
      + '<div style="padding:12px; font-family:monospace; font-size:12px; color:#333; flex:1; background:#fafafa; white-space:pre-wrap">'
      + 'Fetal heart rate should be excluded from this set.\n\n'
      + 'It is recorded at the **maternal level** (in the mother\'s obstetric record), '
      + 'creating a risk of confusion with the mother\'s own heart rate.\n\n'
      + 'I suggest moving it to a dedicated concept set to prevent mixing fetal and maternal values during data alignment.'
      + '</div></div>'
      // Preview
      + '<div style="flex:1; display:flex; flex-direction:column">'
      + '<div style="font-size:12px; font-weight:600; color:var(--text-muted); padding:6px 12px; border-bottom:1px solid #eee">'
      + '<i class="fas fa-eye"></i> Preview</div>'
      + '<div style="padding:12px; font-size:13px; flex:1">'
      + '<p style="margin:0 0 10px">Fetal heart rate should be excluded from this set.</p>'
      + '<p style="margin:0 0 10px">It is recorded at the <strong>maternal level</strong> (in the mother\'s obstetric record), '
      + 'creating a risk of confusion with the mother\'s own heart rate.</p>'
      + '<p style="margin:0">I suggest moving it to a dedicated concept set to prevent mixing fetal and maternal values during data alignment.</p>'
      + '</div></div>'
      + '</div></div>'

      + '<p>Select a <strong>status</strong> (Approved or Needs Revision), write your comments using Markdown '
      + 'in the left editor with a live preview on the right, then click <strong>Submit Review</strong>.</p>'
      + '<p>Your review is stored in the current browser session and appears in the Review tab.</p>'

      // ===== PROPOSING ON GITHUB =====
      + '<h2>Proposing Changes on GitHub</h2>'
      + '<p>You can propose changes on GitHub in two ways:</p>'
      + '<ul>'
      + '<li>In the <strong>Review tab</strong>, after submitting a review, a '
      + '<button class="tab-btn-green" style="cursor:default"><i class="fab fa-github"></i> Propose on GitHub</button>'
      + ' button appears</li>'
      + '<li>From <strong>any tab</strong>, click '
      + '<button class="btn-primary-custom" style="cursor:default"><i class="fas fa-download"></i> Export</button>'
      + ' and choose the GitHub option</li>'
      + '</ul>'
      + '<p>In both cases, clicking it:</p>'
      + '<ol>'
      + '<li>Copies the full updated concept set JSON to your clipboard</li>'
      + '<li>Opens the GitHub editor for that file \u2014 if you don\'t have write access, '
      + 'you will be prompted to <strong>fork</strong> the repository into your account</li>'
      + '<li>Paste the JSON from your clipboard, replacing the file content</li>'
      + '<li>Commit to a new branch and open a <strong>pull request</strong></li>'
      + '</ol>'

      + infoBox('No GitHub Account?',
        'You can still browse and use the dictionary locally. The GitHub workflow is only needed '
        + 'to contribute changes back to the shared library.')

      // ===== WHAT CAN YOU CONTRIBUTE =====
      + '<h2>What Can You Contribute?</h2>'
      + '<ul>'
      + '<li><strong>New concept sets</strong> \u2014 For clinical variables not yet covered</li>'
      + '<li><strong>Concept additions/removals</strong> \u2014 Improve existing concept set expressions</li>'
      + '<li><strong>Expert comments</strong> \u2014 Clinical guidance for ETL and mapping</li>'
      + '<li><strong>Statistical data</strong> \u2014 Reference distributions for data validation</li>'
      + '<li><strong>Reviews</strong> \u2014 Approve or request revision of concept sets</li>'
      + '<li><strong>Translations</strong> \u2014 Improve or add translations</li>'
      + '<li><strong>Bug reports</strong> \u2014 '
      + '<a href="https://github.com/indicate-eu/data-dictionary/issues" target="_blank">Open an issue</a></li>'
      + '</ul>'

      // ===== REPOSITORY STRUCTURE =====
      + '<h2>Repository Structure</h2>'
      + '<p>The <a href="https://github.com/indicate-eu/data-dictionary" target="_blank">'
      + 'indicate-eu/data-dictionary</a> repository is organized as follows:</p>'
      + '<div class="doc-mock-modal" style="max-width:100%; padding:12px 16px">'
      + '<table style="font-size:12px; font-family:monospace; margin:0; border-collapse:collapse">'
      + '<tr><td style="padding:3px 16px 3px 0; white-space:nowrap; color:var(--primary); font-weight:600; border:none">concept_sets/</td>'
      + '<td style="padding:3px 0; border:none; font-family:inherit; color:var(--text)">One JSON file per concept set ({id}.json)</td></tr>'
      + '<tr><td style="padding:3px 16px 3px 0; white-space:nowrap; color:var(--primary); font-weight:600; border:none">concept_sets_resolved/</td>'
      + '<td style="padding:3px 0; border:none; font-family:inherit; color:var(--text)">Resolved concept sets (generated by resolve.py)</td></tr>'
      + '<tr><td style="padding:3px 16px 3px 0; white-space:nowrap; color:var(--primary); font-weight:600; border:none">projects/</td>'
      + '<td style="padding:3px 0; border:none; font-family:inherit; color:var(--text)">One JSON file per project ({id}.json)</td></tr>'
      + '<tr><td style="padding:3px 16px 3px 0; white-space:nowrap; color:var(--primary); font-weight:600; border:none">mapping_recommendations/</td>'
      + '<td style="padding:3px 0; border:none; font-family:inherit; color:var(--text)">Mapping recommendations (multilingual JSON)</td></tr>'
      + '<tr><td style="padding:3px 16px 3px 0; white-space:nowrap; color:var(--primary); font-weight:600; border:none">units/</td>'
      + '<td style="padding:3px 0; border:none; font-family:inherit; color:var(--text)">unit_conversions.csv + recommended_units.csv</td></tr>'
      + '<tr><td style="padding:3px 16px 3px 0; white-space:nowrap; color:var(--primary); font-weight:600; border:none">docs/</td>'
      + '<td style="padding:3px 0; border:none; font-family:inherit; color:var(--text)">GitHub Pages static site (HTML, JS, CSS, generated data files)</td></tr>'
      + '<tr><td style="padding:3px 16px 3px 0; white-space:nowrap; color:#e67700; font-weight:600; border:none">build.py</td>'
      + '<td style="padding:3px 0; border:none; font-family:inherit; color:var(--text)">Aggregates all JSON into docs/data.json and docs/data_inline.js</td></tr>'
      + '<tr><td style="padding:3px 16px 3px 0; white-space:nowrap; color:#e67700; font-weight:600; border:none">resolve.py</td>'
      + '<td style="padding:3px 0; border:none; font-family:inherit; color:var(--text)">Resolves concept set expressions using OMOP vocabularies</td></tr>'
      + '</table></div>'

      // ===== BUILD PIPELINE =====
      + '<h2>Build Pipeline</h2>'
      + '<p>Two Python scripts maintain the data files used by the web application:</p>'

      + '<h3>resolve.py</h3>'
      + '<p>Resolves concept set expressions by expanding descendants and mapped concepts using '
      + 'OMOP vocabulary tables stored in a DuckDB database.</p>'
      + '<div class="doc-mock-modal" style="max-width:100%; padding:12px 16px; font-family:monospace; font-size:12px; white-space:pre-wrap">'
      + 'python3 resolve.py --db /path/to/ohdsi_vocabularies.duckdb\n'
      + '# or\n'
      + 'python3 resolve.py --csv-dir /path/to/athena_csv_folder'
      + '</div>'
      + '<p>You can provide either a DuckDB database (<code>--db</code>) or a folder of Athena CSV files '
      + '(<code>--csv-dir</code> containing CONCEPT.csv, CONCEPT_ANCESTOR.csv, CONCEPT_RELATIONSHIP.csv).</p>'
      + '<p>For each concept set, it:</p>'
      + '<ol>'
      + '<li>Partitions expression items into included and excluded</li>'
      + '<li>Expands each set with descendants and mapped concepts as configured</li>'
      + '<li>Computes: included \u2212 excluded</li>'
      + '<li>Writes the resolved set to <code>concept_sets_resolved/{id}.json</code> \u2014 '
      + 'these pre-computed files allow users to browse the Resolved tab in Concept Set Details '
      + 'without needing to import an OHDSI vocabulary database locally</li>'
      + '</ol>'

      + '<h3>build.py</h3>'
      + '<p>Aggregates all source JSON files into data files consumed by the static site.</p>'
      + '<div class="doc-mock-modal" style="max-width:100%; padding:12px 16px; font-family:monospace; font-size:12px">'
      + 'python3 build.py'
      + '</div>'
      + '<p>Produces:</p>'
      + '<ul>'
      + '<li><code>docs/data.json</code> \u2014 Compact JSON for programmatic use</li>'
      + '<li><code>docs/data_inline.js</code> \u2014 Same data as <code>const DATA={...};</code> for direct script inclusion</li>'
      + '</ul>'

      + infoBox('Full rebuild',
        'After modifying source data files, run both scripts in sequence:<br>'
        + '<code style="font-size:12px">python3 resolve.py --db /path/to/vocabularies.duckdb && python3 build.py</code><br>'
        + 'or with CSV files:<br>'
        + '<code style="font-size:12px">python3 resolve.py --csv-dir /path/to/athena_csv && python3 build.py</code>')

      // ===== CLAUDE CODE SKILLS =====
      + '<h2>Claude Code Skills</h2>'
      + '<p>If you use <a href="https://github.com/anthropics/claude-code" target="_blank">Claude Code</a> '
      + 'to work on this repository, three skills (slash commands) are available:</p>'
      + '<ul>'
      + '<li><code>/resolve-concept-sets</code> \u2014 Runs resolve.py to resolve one or all concept sets '
      + 'using the OMOP vocabulary database</li>'
      + '<li><code>/build-catalog</code> \u2014 Runs build.py to regenerate the data files for the static site</li>'
      + '<li><code>/describe-concept-set</code> \u2014 Generates a detailed clinical description for a concept set '
      + 'using UMLS, LOINC, and SNOMED vocabulary sources \u2014 useful for writing the Comments tab content</li>'
      + '</ul>'
      + '<p>These automate the build pipeline and assist with documentation.</p>';
  }

  function exportingEN() {
    var sql = '-- ============================================================\n'
      + '-- Concept Set: Plasma creatinine (ID: 206)\n'
      + '-- Generated by INDICATE Data Dictionary (Web) v1.0.2\n'
      + '-- Date: 2026-04-06\n'
      + '-- ============================================================\n\n'
      + '-- ------------------------------------------------------------\n'
      + '-- Domain: Measurement (6 concepts)\n'
      + '-- ------------------------------------------------------------\n\n'
      + 'SELECT\n'
      + '    person_id,\n'
      + '    measurement_concept_id,\n'
      + '    measurement_date,\n'
      + '    measurement_datetime,\n'
      + '    value_as_number,\n'
      + '    value_as_concept_id,\n'
      + '    unit_concept_id,\n'
      + '    measurement_source_value,\n'
      + '    measurement_source_concept_id,\n'
      + '    unit_source_value,\n'
      + '    CASE\n'
      + '        -- Recommended unit concept_id: 8749\n'
      + '        -- Applies to:\n'
      + '        --   3020564 (Creatinine [Moles/volume] in Serum or Plasma)\n'
      + '        WHEN unit_concept_id = 8749 THEN value_as_number\n\n'
      + '        -- Recommended unit concept_id: 8751\n'
      + '        -- Applies to:\n'
      + '        --   3016723 (Creatinine [Mass/volume] in Serum or Plasma)\n'
      + '        WHEN unit_concept_id = 8751 THEN value_as_number\n\n'
      + '        -- No recommended unit for:\n'
      + '        --   3051825 (Creatinine [Mass/volume] in Blood)\n'
      + '        --   40762887 (Creatinine [Moles/volume] in Blood)\n'
      + '        --   46235076 (Creatinine [Moles/volume] in Serum, Plasma or Blood)\n'
      + '        --   3964702 (Creatinine [Moles/volume] in Venous blood)\n'
      + '        ELSE NULL -- unknown unit, no conversion available\n'
      + '    END AS value_as_number_converted\n'
      + 'FROM measurement\n'
      + 'WHERE measurement_concept_id IN (\n'
      + '    3051825 -- Creatinine [Mass/volume] in Blood\n'
      + '   ,3016723 -- Creatinine [Mass/volume] in Serum or Plasma\n'
      + '   ,40762887 -- Creatinine [Moles/volume] in Blood\n'
      + '   ,3020564 -- Creatinine [Moles/volume] in Serum or Plasma\n'
      + '   ,46235076 -- Creatinine [Moles/volume] in Serum, Plasma or Blood\n'
      + '   ,3964702 -- Creatinine [Moles/volume] in Venous blood\n'
      + ')\n;';
    var lineCount = sql.split('\n').length;
    var sqlExample = '<div class="doc-mock-modal" style="max-width:100%; padding:0; overflow:hidden">'
      + '<div id="doc-sql-ace" style="width:100%; height:' + (lineCount * 16 + 20) + 'px; min-height:200px">' + App.escapeHtml(sql) + '</div>'
      + '</div>';

    return '<h1>Exporting</h1>'

      // ===== EXPORT ALL =====
      + '<h2>Export All Concept Sets</h2>'
      + '<p>On the main <strong>Data Dictionary</strong> page (the datatable listing all concept sets), click '
      + '<button class="btn-primary-custom" style="cursor:default"><i class="fas fa-download"></i> Export</button>'
      + ' to open the bulk export modal.</p>'
      + mockBulkExportModal('en')

      // ===== EXPORT SINGLE =====
      + '<h2>Export a Single Concept Set</h2>'
      + '<p>From a concept set\u2019s detail view, click '
      + '<button class="btn-primary-custom" style="cursor:default"><i class="fas fa-download"></i> Export</button>'
      + ' to open the export modal.</p>'

      + '<h3>Step 1: Choose a method</h3>'
      + mockExportStep1('en')
      + '<ul>'
      + '<li><strong>Download OHDSI JSON File</strong> \u2014 Downloads the concept set as a <code>.json</code> file to your computer</li>'
      + '<li><strong>Copy OHDSI JSON to Clipboard</strong> \u2014 Copies the JSON to your clipboard, ready to paste</li>'
      + '<li><strong>Propose on GitHub</strong> \u2014 Copies to clipboard and opens the GitHub editor to submit a pull request '
      + '(see ' + docLink('reviewing', 'Reviewing & GitHub') + ')</li>'
      + '<li><strong>Copy OMOP SQL Query</strong> \u2014 Generates and copies a SQL query to extract data from OMOP CDM tables '
      + '(see below)</li>'
      + '</ul>'

      + '<h3>Step 2: Choose a format</h3>'
      + '<p>For Download and Clipboard, a second step lets you pick the format:</p>'
      + mockExportStep2('en')
      + '<ul>'
      + '<li><strong><a href="https://ohdsi.github.io/TAB/Concept-Set-Specification.html" target="_blank">Concept Set Specification</a></strong> \u2014 Full OHDSI format with all metadata and translations (the native format of this dictionary)</li>'
      + '<li><strong>ATLAS</strong> \u2014 ATLAS-compatible format with expression only (UPPERCASE field names)</li>'
      + '</ul>'

      // ===== SQL =====
      + '<h2>OMOP SQL Query</h2>'
      + '<p>The <strong>Copy OMOP SQL Query</strong> option generates a SQL query to extract data '
      + 'from OMOP CDM tables for the resolved concepts in the current concept set.</p>'
      + '<p>The generated query:</p>'
      + '<ul>'
      + '<li>Selects from the appropriate OMOP table based on concept domain '
      + '(measurement, condition_occurrence, drug_exposure, procedure_occurrence, observation, device_exposure)</li>'
      + '<li>Filters on the resolved standard concept IDs</li>'
      + '<li>Includes <strong>unit conversions</strong> when available \u2014 using the conversion factors '
      + 'defined in ' + docLink('dictionary-settings', 'Dictionary Settings') + ' (Unit Conversions tab), '
      + 'the query converts values to the <strong>recommended unit</strong> defined in the '
      + 'Recommended Units tab</li>'
      + '</ul>'
      + '<p>The SQL is copied to your clipboard and a preview is shown in the modal.</p>'
      + '<p style="font-size:12px; color:var(--text-muted); margin-bottom:4px"><i class="fas fa-info-circle"></i> '
      + 'Example: Plasma creatinine concept set SQL query with unit conversions.</p>'
      + sqlExample

      // ===== PROJECT CSV =====
      + '<h2>Project Export</h2>'
      + '<p>From a project\u2019s detail view, click '
      + '<button class="btn-primary-custom" style="cursor:default"><i class="fas fa-download"></i> Export</button>'
      + ' to open the export modal:</p>'
      + mockGenericExportModal('en', 'Export Project')
      + '<p>The Concept Sets tab also provides '
      + '<button class="btn-primary-custom" style="cursor:default"><i class="fas fa-file-csv"></i> Export CSV</button>'
      + ' to download all OMOP concepts from the project\u2019s concept sets as CSV, '
      + 'useful for analysis pipelines.</p>';
  }

  function mockGenericExportModal(lang, title) {
    var en = lang === 'en';
    return '<div class="doc-mock-modal" style="max-width:480px">'
      + '<div class="modal-header"><h3 style="margin:0; font-size:14px"><i class="fas fa-download"></i> '
      + (en ? title : title) + '</h3>'
      + '<span class="modal-close" style="cursor:default">&times;</span></div>'
      + '<div style="padding:12px"><div class="export-options-container" style="gap:8px; padding:4px 0">'
      + mockExportOpt('fas fa-file-download', '#0f60af',
        en ? 'Download File' : 'T\u00e9l\u00e9charger',
        en ? 'Download as a file' : 'T\u00e9l\u00e9charger en fichier')
      + mockExportOpt('fas fa-clipboard', '#28a745',
        en ? 'Copy to Clipboard' : 'Copier',
        en ? 'Copy the content to clipboard' : 'Copier le contenu dans le presse-papiers')
      + mockExportOpt('fab fa-github', '#6f42c1',
        en ? 'Propose on GitHub' : 'Proposer sur GitHub',
        en ? 'Copy to clipboard and open GitHub editor' : 'Copier et ouvrir l\u2019\u00e9diteur GitHub')
      + '</div></div>'
      + '<div class="modal-footer"><button class="btn-cancel" disabled>' + (en ? 'Cancel' : 'Annuler') + '</button></div>'
      + '</div>';
  }

  var _docSqlEditor = null;

  function initDocSqlEditor() {
    var el = document.getElementById('doc-sql-ace');
    if (!el || !window.ace || _docSqlEditor) return;
    _docSqlEditor = ace.edit(el);
    _docSqlEditor.setTheme('ace/theme/chrome');
    _docSqlEditor.session.setMode('ace/mode/sql');
    _docSqlEditor.setReadOnly(true);
    _docSqlEditor.setShowPrintMargin(false);
    _docSqlEditor.setHighlightActiveLine(false);
    _docSqlEditor.renderer.setShowGutter(true);
    _docSqlEditor.renderer.$cursorLayer.element.style.display = 'none';
  }

  function mockProjectCard(lang) {
    var en = lang === 'en';
    return '<div style="display:flex; justify-content:center; margin:16px 0">'
      + '<div class="project-card" style="cursor:default; max-width:450px; position:relative">'
      + '<div style="margin:0 0 8px; font-size:16px; font-weight:600">Quality Benchmarking Dashboards [Minimal]</div>'
      + '<p style="margin:0 0 12px" title="Demonstrates data sharing practices designed to support continuous improvement of clinical practice through quality benchmarking.">'
      + 'Demonstrates data sharing practices designed to support continuous improvement of clinical practice through quality benchmarking.'
      + '</p>'
      + '<div class="project-card-footer">'
      + '<span><i class="fas fa-list"></i> 99 ' + (en ? 'concept sets' : 'jeux de concepts') + '</span>'
      + '<span><i class="fas fa-user"></i> Falk von Dincklage</span>'
      + '<span><i class="fas fa-calendar-alt"></i> 2024-12-01</span>'
      + '</div>'
      + '</div></div>';
  }

  function mockNewProjectModal(lang) {
    var en = lang === 'en';
    return '<div class="doc-mock-modal">'
      + '<div class="modal-header">'
      + '<h3 style="margin:0"><i class="fas fa-plus"></i> ' + (en ? 'New Project' : 'Nouveau projet') + '</h3>'
      + '<span class="modal-close" style="cursor:default">&times;</span>'
      + '</div>'
      + '<div class="modal-body" style="display:flex; flex-direction:column; gap:12px">'
      + '<div><label class="form-label">' + (en ? 'Name *' : 'Nom *') + '</label>'
      + '<input type="text" class="form-input" value="Quality Benchmarking Dashboards" readonly></div>'
      + '<div><label class="form-label">' + (en ? 'Short description' : 'Description courte') + '</label>'
      + '<input type="text" class="form-input" value="Quality benchmarking dashboards for ICU data" readonly></div>'
      + '<div><label class="form-label">' + (en ? 'Created By' : 'Cr\u00e9\u00e9 par') + '</label>'
      + '<input type="text" class="form-input" value="Falk von Dincklage" readonly></div>'
      + '</div>'
      + '<div class="modal-footer">'
      + '<button class="btn-cancel" disabled>' + (en ? 'Cancel' : 'Annuler') + '</button>'
      + '<button class="btn-submit" disabled><i class="fas fa-plus"></i> ' + (en ? 'Create' : 'Cr\u00e9er') + '</button>'
      + '</div>'
      + '</div>';
  }

  function mockProjectCSEditPanels(lang) {
    var en = lang === 'en';
    var available = [
      { cat: en ? 'Vitals' : 'Signes vitaux', sub: en ? 'Other vitals' : 'Autres signes vitaux', name: en ? 'Body temperature' : 'Temp\u00e9rature corporelle' },
      { cat: en ? 'Vitals' : 'Signes vitaux', sub: en ? 'Other vitals' : 'Autres signes vitaux', name: en ? 'Body weight' : 'Poids corporel' },
      { cat: en ? 'Labs' : 'Laboratoire', sub: en ? 'Liver test' : 'Bilan h\u00e9patique', name: en ? 'Albumin' : 'Albumine' }
    ];
    var project = [
      { cat: en ? 'Vitals' : 'Signes vitaux', sub: en ? 'Haemodynamics' : 'H\u00e9modynamique', name: en ? 'Heart rate' : 'Fr\u00e9quence cardiaque' },
      { cat: en ? 'Vitals' : 'Signes vitaux', sub: en ? 'Haemodynamics' : 'H\u00e9modynamique', name: en ? 'Blood pressure' : 'Pression art\u00e9rielle' },
      { cat: en ? 'Labs' : 'Laboratoire', sub: en ? 'Other labs' : 'Autres labos', name: en ? 'Creatinine' : 'Cr\u00e9atinine' },
      { cat: en ? 'Labs' : 'Laboratoire', sub: en ? 'Liver test' : 'Bilan h\u00e9patique', name: en ? 'Bilirubin' : 'Bilirubine' }
    ];
    var td = 'padding:5px 8px; border-bottom:1px solid #eee; font-size:12px';
    function rowAvail(d) {
      return '<tr>'
        + '<td style="' + td + '">' + d.cat + '</td>'
        + '<td style="' + td + '">' + d.sub + '</td>'
        + '<td style="' + td + '">' + d.name + '</td>'
        + '<td style="' + td + '"><button class="proj-cs-add-btn" style="cursor:default"><i class="fas fa-plus-circle"></i></button></td>'
        + '</tr>';
    }
    function rowProj(d) {
      return '<tr>'
        + '<td style="' + td + '"><button class="proj-cs-remove-btn" style="cursor:default"><i class="fas fa-minus-circle"></i></button></td>'
        + '<td style="' + td + '">' + d.cat + '</td>'
        + '<td style="' + td + '">' + d.sub + '</td>'
        + '<td style="' + td + '">' + d.name + '</td>'
        + '</tr>';
    }
    var thStyle = 'padding:6px 8px; border-bottom:2px solid var(--border); color:var(--primary); font-weight:600; font-size:11px; text-align:left';
    return '<div style="display:flex; gap:16px; margin:16px 0">'
      // Left panel — available
      + '<div style="flex:1; border:1px solid var(--border); border-radius:var(--radius); overflow:hidden">'
      + '<div style="padding:8px 12px; background:var(--gray-light); font-size:12px; font-weight:600; color:var(--text-muted); text-transform:uppercase; letter-spacing:.5px">'
      + (en ? 'Available Concept Sets' : 'Jeux de concepts disponibles') + '</div>'
      + '<table style="width:100%; border-collapse:collapse"><thead><tr>'
      + '<th style="' + thStyle + '">' + (en ? 'Category' : 'Cat\u00e9gorie') + '</th>'
      + '<th style="' + thStyle + '">' + (en ? 'Subcategory' : 'Sous-cat\u00e9gorie') + '</th>'
      + '<th style="' + thStyle + '">' + (en ? 'Name' : 'Nom') + '</th>'
      + '<th style="' + thStyle + '; width:40px"></th>'
      + '</tr></thead><tbody>'
      + available.map(rowAvail).join('')
      + '</tbody></table></div>'
      // Right panel — project
      + '<div style="flex:1; border:1px solid var(--border); border-radius:var(--radius); overflow:hidden">'
      + '<div style="padding:8px 12px; background:var(--gray-light); font-size:12px; font-weight:600; color:var(--text-muted); text-transform:uppercase; letter-spacing:.5px">'
      + (en ? 'Project Concept Sets' : 'Jeux de concepts du projet')
      + ' <span style="font-weight:400">(' + project.length + ')</span></div>'
      + '<table style="width:100%; border-collapse:collapse"><thead><tr>'
      + '<th style="' + thStyle + '; width:40px"></th>'
      + '<th style="' + thStyle + '">' + (en ? 'Category' : 'Cat\u00e9gorie') + '</th>'
      + '<th style="' + thStyle + '">' + (en ? 'Subcategory' : 'Sous-cat\u00e9gorie') + '</th>'
      + '<th style="' + thStyle + '">' + (en ? 'Name' : 'Nom') + '</th>'
      + '</tr></thead><tbody>'
      + project.map(rowProj).join('')
      + '</tbody></table></div>'
      + '</div>';
  }

  function mockBulkExportModal(lang) {
    var en = lang === 'en';
    return '<div class="doc-mock-modal" style="max-width:480px">'
      + '<div class="modal-header"><h3 style="margin:0; font-size:14px"><i class="fas fa-download"></i> '
      + (en ? 'Export Concept Sets' : 'Exporter les jeux de concepts') + '</h3>'
      + '<span class="modal-close" style="cursor:default">&times;</span></div>'
      + '<div style="padding:12px"><div class="export-options-container" style="gap:8px; padding:4px 0">'
      + mockExportOpt('fas fa-file-archive', '#0f60af',
        en ? 'Export All' : 'Tout exporter',
        en ? 'Download all concept sets as a single JSON file' : 'T\u00e9l\u00e9charger tous les jeux de concepts en un seul fichier JSON')
      + mockExportOpt('fas fa-folder', '#28a745',
        en ? 'Filter by Category' : 'Filtrer par cat\u00e9gorie',
        en ? 'Export concept sets from a specific category' : 'Exporter les jeux de concepts d\u2019une cat\u00e9gorie sp\u00e9cifique')
      + '</div></div>'
      + '<div class="modal-footer"><button class="btn-cancel" disabled>' + (en ? 'Close' : 'Fermer') + '</button></div>'
      + '</div>';
  }

  function mockExportOpt(iconClass, color, title, subtitle) {
    return '<div class="export-option" style="cursor:default; padding:8px 12px">'
      + '<div class="export-option-icon" style="font-size:18px; min-width:30px"><i class="' + iconClass + '" style="color:' + color + '"></i></div>'
      + '<div class="export-option-content">'
      + '<h5 class="export-option-title" style="font-size:13px; margin:0 0 2px">' + title + '</h5>'
      + '<p class="export-option-subtitle" style="font-size:11px; margin:0; color:var(--text-muted)">' + subtitle + '</p>'
      + '</div></div>';
  }

  function mockExportStep1(lang) {
    var en = lang === 'en';
    return '<div class="doc-mock-modal" style="max-width:480px">'
      + '<div class="modal-header"><h3 style="margin:0; font-size:14px"><i class="fas fa-download"></i> '
      + (en ? 'Export Concept Set' : 'Exporter le jeu de concepts') + '</h3>'
      + '<span class="modal-close" style="cursor:default">&times;</span></div>'
      + '<div style="padding:12px"><div class="export-options-container" style="gap:8px; padding:4px 0">'
      + mockExportOpt('fas fa-file-download', '#0f60af',
        en ? 'Download OHDSI JSON File' : 'T\u00e9l\u00e9charger le fichier JSON OHDSI',
        en ? 'Download the concept set as a JSON file following OHDSI specification' : 'T\u00e9l\u00e9charger le jeu de concepts au format JSON OHDSI')
      + mockExportOpt('fas fa-clipboard', '#28a745',
        en ? 'Copy OHDSI JSON to Clipboard' : 'Copier le JSON OHDSI',
        en ? 'Copy the concept set in OHDSI-compliant JSON format to clipboard' : 'Copier le jeu de concepts au format JSON OHDSI dans le presse-papiers')
      + mockExportOpt('fab fa-github', '#6f42c1',
        en ? 'Propose on GitHub' : 'Proposer sur GitHub',
        en ? 'Copy to clipboard and open GitHub editor' : 'Copier et ouvrir l\u2019\u00e9diteur GitHub')
      + mockExportOpt('fas fa-database', '#e67700',
        en ? 'Copy OMOP SQL Query' : 'Copier la requ\u00eate SQL OMOP',
        en ? 'SQL query to extract data from OMOP CDM tables, with unit conversions' : 'Requ\u00eate SQL pour extraire les donn\u00e9es des tables OMOP CDM, avec conversions d\u2019unit\u00e9s')
      + '</div></div>'
      + '<div class="modal-footer"><button class="btn-cancel" disabled>' + (en ? 'Close' : 'Fermer') + '</button></div>'
      + '</div>';
  }

  function mockExportStep2(lang) {
    var en = lang === 'en';
    return '<div class="doc-mock-modal" style="max-width:480px">'
      + '<div class="modal-header"><h3 style="margin:0; font-size:14px"><i class="fas fa-download"></i> '
      + (en ? 'Export Concept Set' : 'Exporter le jeu de concepts') + '</h3>'
      + '<span class="modal-close" style="cursor:default">&times;</span></div>'
      + '<div style="padding:12px"><div class="export-options-container" style="gap:8px; padding:4px 0">'
      + mockExportOpt('fas fa-file-code', '#0f60af',
        en ? 'Concept Set Specification' : 'Sp\u00e9cification du jeu de concepts',
        en ? 'Full OHDSI format with metadata and translations' : 'Format OHDSI complet avec m\u00e9tadonn\u00e9es et traductions')
      + mockExportOpt('fas fa-globe', '#28a745',
        'ATLAS',
        en ? 'ATLAS-compatible format (expression only)' : 'Format compatible ATLAS (expression uniquement)')
      + '</div></div>'
      + '<div class="modal-footer">'
      + '<button class="btn-cancel" style="cursor:default; opacity:0.6"><i class="fas fa-arrow-left"></i> '
      + (en ? 'Back' : 'Retour') + '</button>'
      + '<button class="btn-cancel" disabled>' + (en ? 'Close' : 'Fermer') + '</button></div>'
      + '</div>';
  }

  function projectsEN() {
    return '<h1>Managing Projects</h1>'
      + '<p>The <strong>Projects</strong> page lets you organize concept sets into research projects. '
      + 'A project can be a clinical study, a machine learning pipeline, a dashboard, or any data-driven initiative.</p>'

      + '<h2>Projects List</h2>'
      + '<p>Projects are displayed as cards showing name, description, concept set count, author, and date. '
      + 'Use the search field to filter by name or description. Click a card to open the project.</p>'
      + mockProjectCard('en')

      + '<h2>Creating a Project</h2>'
      + '<p>In edit mode, click <strong>Add Project</strong>. Provide a name and short description '
      + '(multilingual, currently EN/FR). The author is pre-filled from your profile.</p>'
      + mockNewProjectModal('en')

      + '<h2>Project Detail View</h2>'
      + '<p>Click a project card to open its detail view with two tabs:</p>'

      + '<h3>Description Tab</h3>'
      + '<p>A Markdown-formatted long description with live preview in edit mode. '
      + 'The description is edited for the currently selected language.</p>'

      + '<h3>Concept Sets Tab</h3>'
      + '<p>In read mode, shows a sortable, filterable table of the project\'s concept sets. '
      + 'Click a row to navigate to that concept set.</p>'
      + '<p>In edit mode, a dual-panel interface lets you:</p>'
      + '<ul>'
      + '<li><strong>Left panel</strong> \u2014 Available concept sets (not yet in the project)</li>'
      + '<li><strong>Right panel</strong> \u2014 Concept sets assigned to the project</li>'
      + '<li>Use the <i class="fas fa-plus-circle" style="color:var(--success)"></i> and <i class="fas fa-minus-circle" style="color:var(--danger)"></i> buttons to move concept sets between panels</li>'
      + '<li>Filter both panels by category, subcategory, or name</li>'
      + '</ul>'
      + mockProjectCSEditPanels(App.lang)

      + infoBox('Best Practice',
        'Include all concept sets needed for your analysis, even those only used for adjustment or '
        + 'stratification. This ensures complete data collection from the start.')

      + '<h2>Exporting</h2>'
      + '<p>The project detail view offers two export options:</p>'

      + '<h3>JSON Export</h3>'
      + '<p>Click the <strong>Export</strong> button in the project header to export the project definition as JSON. '
      + 'You can download it as a file, copy to clipboard, or propose changes on GitHub.</p>'
      + mockProjectExportModal('en')

      + '<h3>CSV Export</h3>'
      + '<p>In the Concept Sets tab (read mode), click the <strong>CSV</strong> button to download all OMOP concepts '
      + 'from the project\'s concept sets as a CSV file. The export includes concept set metadata '
      + '(ID, name, category, subcategory) and expression flags (excluded, descendants, mapped) for each concept.</p>';
  }

  function mockProjectExportModal(lang) {
    var en = lang === 'en';
    return '<div class="doc-mock-modal" style="max-width:480px">'
      + '<div class="modal-header"><h3 style="margin:0; font-size:14px"><i class="fas fa-download"></i> '
      + (en ? 'Export Project' : 'Exporter le projet') + '</h3>'
      + '<span class="modal-close" style="cursor:default">&times;</span></div>'
      + '<div style="padding:12px"><div class="export-options-container" style="gap:8px; padding:4px 0">'
      + mockExportOpt('fas fa-file-download', '#0f60af',
        en ? 'Download File' : 'T\u00e9l\u00e9charger le fichier',
        en ? 'Download as a JSON file' : 'T\u00e9l\u00e9charger en tant que fichier JSON')
      + mockExportOpt('fas fa-clipboard', '#28a745',
        en ? 'Copy to Clipboard' : 'Copier dans le presse-papiers',
        en ? 'Copy the project JSON to clipboard' : 'Copier le JSON du projet dans le presse-papiers')
      + mockExportOpt('fab fa-github', '#6f42c1',
        en ? 'Propose on GitHub' : 'Proposer sur GitHub',
        en ? 'Copy to clipboard and open GitHub editor' : 'Copier dans le presse-papiers et ouvrir l\u2019\u00e9diteur GitHub')
      + '</div></div>'
      + '<div class="modal-footer"><button class="btn-cancel" disabled>' + (en ? 'Cancel' : 'Annuler') + '</button></div>'
      + '</div>';
  }

  function mockMappingToolbar(lang) {
    var en = lang === 'en';
    return '<div style="display:flex; gap:6px; justify-content:center; margin-bottom:12px">'
      + '<button class="btn-primary-custom" style="pointer-events:none"><i class="fas fa-download"></i> '
      + (en ? 'Export' : 'Export') + '</button>'
      + '<button class="btn-primary-custom btn-gray" style="pointer-events:none"><i class="fas fa-pen"></i> '
      + (en ? 'Edit' : '\u00c9diter') + '</button>'
      + '</div>';
  }

  function mockMappingExportModal(lang) {
    var en = lang === 'en';
    return '<div class="doc-mock-modal" style="max-width:480px">'
      + '<div class="modal-header"><h3 style="margin:0; font-size:14px"><i class="fas fa-download"></i> '
      + (en ? 'Export Mapping Recommendations' : 'Exporter les recommandations de mapping') + '</h3>'
      + '<span class="modal-close" style="cursor:default">&times;</span></div>'
      + '<div style="padding:12px"><div class="export-options-container" style="gap:8px; padding:4px 0">'
      + mockExportOpt('fas fa-file-download', '#0f60af',
        en ? 'Download File' : 'T\u00e9l\u00e9charger',
        en ? 'Download as mapping_recommendations.json' : 'T\u00e9l\u00e9charger en fichier mapping_recommendations.json')
      + mockExportOpt('fas fa-clipboard', '#28a745',
        en ? 'Copy to Clipboard' : 'Copier',
        en ? 'Copy JSON to clipboard' : 'Copier le JSON dans le presse-papiers')
      + mockExportOpt('fab fa-github', '#6f42c1',
        en ? 'Propose on GitHub' : 'Proposer sur GitHub',
        en ? 'Copy to clipboard and open GitHub editor' : 'Copier et ouvrir l\u2019\u00e9diteur GitHub')
      + '</div></div>'
      + '<div class="modal-footer"><button class="btn-cancel" disabled>' + (en ? 'Cancel' : 'Annuler') + '</button></div>'
      + '</div>';
  }

  function mappingEN() {
    return '<h1>Mapping Recommendations</h1>'
      + '<p>The <strong>Mapping Recommendations</strong> page provides expert-curated guidance for '
      + 'mapping common local ICU variables to OMOP standard concepts.</p>'

      + '<h2>What are Mapping Recommendations?</h2>'
      + '<p>During an ETL process to convert local clinical data to the OMOP CDM, deciding how to map '
      + 'each local variable to standard concepts is one of the most challenging steps. Mapping recommendations '
      + 'provide structured guidance for common variables found in ICU databases.</p>'

      + '<h2>Viewing</h2>'
      + '<p>The content is rendered as Markdown, allowing rich formatting with tables, links, and structured guidance.</p>'
      + '<p>Two buttons are available in the top-right corner:</p>'
      + mockMappingToolbar('en')
      + '<ul>'
      + '<li><strong>Export</strong> \u2014 opens the export modal (see below)</li>'
      + '<li><strong>Edit</strong> \u2014 enters edit mode to modify the content</li>'
      + '</ul>'

      + '<h2>Editing</h2>'
      + '<p>In edit mode, an ACE editor with Markdown syntax highlighting opens alongside a live preview panel.</p>'
      + '<p>Content is multilingual \u2014 switching language saves the current text and loads the other language.</p>'

      + '<h2>Exporting</h2>'
      + '<p>Click <strong>Export</strong> to open the export modal:</p>'
      + mockMappingExportModal('en')
      + '<ul>'
      + '<li><strong>Download File</strong> \u2014 downloads <code>mapping_recommendations.json</code>, which belongs in the <code>mapping_recommendations/</code> folder of the Git repository</li>'
      + '<li><strong>Copy to Clipboard</strong> \u2014 copies the JSON content to your clipboard</li>'
      + '<li><strong>Propose on GitHub</strong> \u2014 copies to clipboard and opens the GitHub editor to propose changes via a pull request</li>'
      + '</ul>';
  }

  function mockSqlEditor(lang) {
    var en = lang === 'en';
    return '<div class="doc-mock-modal" style="max-width:100%; padding:0; border-radius:var(--radius)">'
      // Toolbar
      + '<div style="display:flex; align-items:center; gap:8px; padding:8px 12px; border-bottom:1px solid var(--border); background:var(--gray-light)">'
      + '<select class="form-input" style="max-width:220px; font-size:12px; padding:4px 6px" disabled>'
      + '<option>-- ' + (en ? 'Example queries' : 'Requ\u00eates d\u2019exemple') + ' --</option></select>'
      + '<button class="btn-submit" style="font-size:12px; padding:4px 10px" disabled>'
      + '<i class="fas fa-play"></i> Run</button>'
      + '<span style="font-size:11px; color:var(--text-muted); margin-left:4px">Ctrl+Enter</span>'
      + '</div>'
      // Split layout
      + '<div style="display:grid; grid-template-columns:1fr 1fr; min-height:120px">'
      // Left: SQL code
      + '<div style="border-right:1px solid var(--border); padding:10px 12px; font-family:monospace; font-size:12px; '
      + 'white-space:pre; background:#fff; line-height:1.5; color:#333; overflow:auto">'
      + '<span style="color:#0000ff">SELECT</span> concept_id, concept_name\n'
      + '<span style="color:#0000ff">FROM</span> concept\n'
      + '<span style="color:#0000ff">WHERE</span> standard_concept = <span style="color:#a31515">\'S\'</span>\n'
      + '<span style="color:#0000ff">LIMIT</span> <span style="color:#098658">50</span>'
      + '</div>'
      // Right: results
      + '<div style="padding:10px 12px; overflow:auto; background:#fff">'
      + '<div style="display:flex; align-items:center; gap:8px; margin-bottom:8px">'
      + '<span style="font-size:11px; color:var(--text-muted)">50 rows</span>'
      + '<button class="btn-outline-sm" style="margin-left:auto; font-size:11px; padding:2px 8px" disabled>'
      + '<i class="fas fa-download"></i> CSV</button></div>'
      + '<table class="table" style="font-size:11px"><thead><tr>'
      + '<th>concept_id</th><th>concept_name</th>'
      + '</tr></thead><tbody>'
      + '<tr><td>4239408</td><td>Systolic blood pressure</td></tr>'
      + '<tr><td>4302666</td><td>Heart rate</td></tr>'
      + '<tr><td>37393863</td><td>Body temperature</td></tr>'
      + '<tr><td colspan="2" style="text-align:center; color:var(--text-muted); font-style:italic">...</td></tr>'
      + '</tbody></table>'
      + '</div></div></div>';
  }

  function devToolsEN() {
    return '<h1>Dev Tools</h1>'
      + '<p>Access via the Settings button (gear icon) in the top-right corner of the header \u2192 Dev Tools.</p>'
      + '<p>The Dev Tools page provides advanced features for developers and power users.</p>'

      + '<h2>SQL Editor</h2>'
      + '<p>Query the OHDSI vocabulary database directly using SQL.</p>'
      + '<p>A dropdown provides pre-built example queries.</p>'
      + '<p>Results are displayed in a datatable with an option to export as CSV.</p>'
      + mockSqlEditor('en')

      + '<h2>Schema / ERD</h2>'
      + '<p>View the database schema and entity-relationship diagram for the vocabulary tables.</p>';
  }

  function mockDataUpdateModal(lang) {
    var en = lang === 'en';
    return '<div class="doc-mock-modal" style="max-width:600px">'
      + '<div class="modal-header"><h3 style="margin:0; font-size:14px">'
      + '<i class="fas fa-cloud-arrow-down"></i> '
      + (en ? 'Data Update Available' : 'Mise \u00e0 jour disponible') + '</h3>'
      + '<span class="modal-close" style="cursor:default">&times;</span></div>'
      + '<div style="padding:16px 20px; font-size:13px">'
      + '<p style="margin:0 0 12px">' + (en ? 'The data dictionary has been updated.' : 'Le dictionnaire de donn\u00e9es a \u00e9t\u00e9 mis \u00e0 jour.') + '</p>'
      + '<details open style="margin-bottom:4px">'
      + '<summary style="cursor:pointer; font-size:13px; font-weight:600; color:var(--primary); margin-bottom:6px">'
      + '<i class="fas fa-list"></i> '
      + (en ? '3 concept set(s) changed remotely' : '3 jeu(x) de concepts modifi\u00e9(s) \u00e0 distance') + '</summary>'
      + '<table class="table" style="font-size:12px; margin-top:4px"><thead><tr>'
      + '<th>ID</th><th>' + (en ? 'Name' : 'Nom') + '</th><th>' + (en ? 'Version' : 'Version') + '</th><th>' + (en ? 'Modified' : 'Modifi\u00e9') + '</th>'
      + '</tr></thead><tbody>'
      + '<tr><td>207</td><td>Plasma glucose</td><td>1.0.0 \u2192 1.1.0</td><td>2025-03-10 \u2192 2025-04-01</td></tr>'
      + '<tr><td>341</td><td>Certoparin</td><td>1.0.0 \u2192 1.0.1</td><td>2025-03-15 \u2192 2025-04-02</td></tr>'
      + '<tr><td>342</td><td>Decision authority documented</td><td>\u2014</td>'
      + '<td><span style="color:var(--accent-green); font-weight:600">' + (en ? 'New' : 'Nouveau') + '</span></td></tr>'
      + '</tbody></table></details>'
      + '</div>'
      + '<div class="modal-footer">'
      + '<button class="btn-cancel" disabled>' + (en ? 'Later' : 'Plus tard') + '</button>'
      + '<button class="btn-submit" disabled><i class="fas fa-check"></i> '
      + (en ? 'Apply Updates' : 'Appliquer') + '</button>'
      + '</div></div>';
  }

  function mockSettingsDropdown(lang) {
    var en = lang === 'en';
    return '<div style="display:inline-block; position:relative; margin:12px 0">'
      + '<div style="background:#fff; border:1px solid var(--border); border-radius:var(--radius); '
      + 'box-shadow:0 4px 12px rgba(0,0,0,.12); min-width:220px; padding:4px 0; font-size:13px">'
      + '<a style="display:flex; align-items:center; gap:8px; padding:8px 14px; color:var(--text); text-decoration:none; cursor:default">'
      + '<i class="fas fa-book-medical" style="width:16px; text-align:center; color:var(--gray)"></i> '
      + (en ? 'Dictionary Settings' : 'Param\u00e8tres du dictionnaire') + '</a>'
      + '<a style="display:flex; align-items:center; gap:8px; padding:8px 14px; color:var(--text); text-decoration:none; cursor:default">'
      + '<i class="fas fa-code" style="width:16px; text-align:center; color:var(--gray)"></i> '
      + (en ? 'Dev Tools' : 'Outils de d\u00e9veloppement') + '</a>'
      + '<div style="height:1px; background:var(--border); margin:4px 0"></div>'
      + '<a style="display:flex; align-items:center; gap:8px; padding:8px 14px; color:#dc3545; text-decoration:none; cursor:default">'
      + '<i class="fas fa-rotate-right" style="width:16px; text-align:center; color:#dc3545"></i> '
      + (en ? 'Reset local data' : 'R\u00e9initialiser les donn\u00e9es locales') + '</a>'
      + '</div></div>';
  }

  function localDataEN() {
    return '<h1>Local Data</h1>'
      + '<p>The INDICATE Data Dictionary is a <strong>fully client-side application</strong>. '
      + 'All data is stored locally in your browser \u2014 nothing is sent to a server.</p>'

      + '<h2>How it Works</h2>'
      + '<p>The application uses two browser storage mechanisms:</p>'
      + '<ul>'
      + '<li><strong>localStorage</strong> \u2014 stores concept sets, projects, mapping recommendations, '
      + 'unit conversions, recommended units, user profile, reviews, and language preferences. '
      + 'All your edits (adding, modifying, or deleting concept sets and projects) are saved here.</li>'
      + '<li><strong>IndexedDB</strong> \u2014 stores the OHDSI vocabulary database, powered by '
      + '<a href="https://duckdb.org/docs/api/wasm/overview" target="_blank">DuckDB-WASM</a>. '
      + 'This is a full SQL database running entirely in your browser, enabling concept search, '
      + 'hierarchy visualization, and expression resolution without any server.</li>'
      + '</ul>'
      + '<p>Your data persists across sessions and browser restarts.</p>'

      + '<h2>Data Updates</h2>'
      + '<p>When the application is deployed on GitHub Pages, the source data (concept sets, projects, etc.) '
      + 'may be updated by contributors via pull requests.</p>'
      + '<p>When you visit the application and new data is available, a modal appears:</p>'
      + mockDataUpdateModal('en')
      + '<ul>'
      + '<li><strong>Apply Updates</strong> \u2014 merges the remote updates into your local data. '
      + 'If you have local edits on the same concept sets, the modal highlights conflicts and lets you '
      + 'choose between your local version and the remote version for each one.</li>'
      + '<li><strong>Later</strong> \u2014 dismisses the modal and keeps your current local data unchanged. '
      + 'The prompt will reappear on your next visit.</li>'
      + '</ul>'

      + '<h2>Reset Local Data</h2>'
      + '<p>If you want to discard all local modifications and start fresh with the latest deployed version, '
      + 'open the Settings dropdown (gear icon, top-right of the header) and click <strong>Reset local data</strong>:</p>'
      + mockSettingsDropdown('en')
      + '<p>This clears all localStorage data (concept sets, projects, reviews, profile, preferences) '
      + 'and reloads the application with the original data from GitHub Pages.</p>'

      + infoBox('Warning',
        'Reset local data is irreversible. '
        + 'Make sure to <strong>export</strong> any work you want to keep before resetting. '
        + 'See ' + docLink('exporting', 'Exporting') + ' and '
        + docLink('reviewing', 'Reviewing & GitHub') + '.', 'warning')

      + '<h2>OHDSI Vocabulary Database</h2>'
      + '<p>The vocabulary database stored in IndexedDB is independent from the Reset local data action. '
      + 'To manage it, use the <strong>OHDSI Vocabularies</strong> tab in '
      + docLink('dictionary-settings', 'Dictionary Settings') + '.</p>';
  }

  function mockSettingsExportModal(lang, title) {
    var en = lang === 'en';
    return '<div class="doc-mock-modal" style="max-width:480px">'
      + '<div class="modal-header"><h3 style="margin:0; font-size:14px"><i class="fas fa-download"></i> '
      + title + '</h3>'
      + '<span class="modal-close" style="cursor:default">&times;</span></div>'
      + '<div style="padding:12px"><div class="export-options-container" style="gap:8px; padding:4px 0">'
      + mockExportOpt('fas fa-file-download', '#0f60af',
        en ? 'Download File' : 'T\u00e9l\u00e9charger',
        en ? 'Download as JSON file' : 'T\u00e9l\u00e9charger en fichier JSON')
      + mockExportOpt('fas fa-clipboard', '#28a745',
        en ? 'Copy to Clipboard' : 'Copier',
        en ? 'Copy JSON to clipboard' : 'Copier le JSON dans le presse-papiers')
      + '</div></div>'
      + '<div class="modal-footer"><button class="btn-cancel" disabled>' + (en ? 'Cancel' : 'Annuler') + '</button></div>'
      + '</div>';
  }

  function dictSettingsEN() {
    return '<h1>Dictionary Settings</h1>'
      + '<p>Access via the Settings button (gear icon) in the top-right corner of the header \u2192 Dictionary Settings.</p>'
      + '<p>The page has three tabs:</p>'
      + '<ul>'
      + '<li><strong>OHDSI Vocabularies</strong> \u2014 import and manage the local vocabulary database</li>'
      + '<li><strong>Unit Conversions</strong> \u2014 conversion factors between measurement units</li>'
      + '<li><strong>Recommended Units</strong> \u2014 recommended unit per measurement concept</li>'
      + '</ul>'

      + '<h2>OHDSI Vocabularies</h2>'
      + '<p>The application can import OHDSI vocabulary files into a <strong>DuckDB database that runs '
      + 'entirely in your browser</strong>. This enables powerful features without requiring any server.</p>'

      + '<h3>What it Enables</h3>'
      + '<ul>'
      + '<li><strong>Concept search</strong> \u2014 Search OMOP concepts by name, ID, or code when adding concepts to expressions</li>'
      + '<li><strong>Live resolution</strong> \u2014 Resolve concept set expressions in real-time (expand descendants and mapped concepts)</li>'
      + '<li><strong>Hierarchy visualization</strong> \u2014 Interactive graphs of concept ancestors, descendants, and relationships</li>'
      + '<li><strong>Expression optimization</strong> \u2014 Simplify expressions using vocabulary hierarchy analysis</li>'
      + '<li><strong>SQL queries</strong> \u2014 Query the vocabulary database directly in the Dev Tools SQL editor</li>'
      + '</ul>'

      + '<h3>How to Import</h3>'
      + '<ol>'
      + '<li>Download vocabulary files from <a href="https://athena.ohdsi.org/vocabulary/list" target="_blank">ATHENA</a> (CSV or Parquet format)</li>'
      + '<li>Go to <strong>Settings</strong> (gear icon) \u2192 <strong>Dictionary Settings</strong> \u2192 <strong>OHDSI Vocabularies</strong> tab</li>'
      + '<li>Click <strong>Select Vocabulary Folder</strong> and choose the folder containing the vocabulary files</li>'
      + '<li>Wait for the import to complete \u2014 a progress bar shows per-file status</li>'
      + '</ol>'
      + '<p>The import reads CONCEPT.csv, CONCEPT_RELATIONSHIP.csv, CONCEPT_ANCESTOR.csv, and related files, '
      + 'indexes them in DuckDB, and saves the database to browser storage.</p>'

      + '<h3>Re-importing and Deleting</h3>'
      + '<p>To update the vocabulary database after downloading new files, delete the existing database '
      + 'and re-import by selecting the folder again.</p>'
      + '<ul>'
      + '<li><strong>Delete Database</strong> \u2014 removes the local vocabulary database entirely</li>'
      + '<li><strong>Select Vocabulary Folder</strong> \u2014 re-import from the vocabulary files folder</li>'
      + '</ul>'

      + '<h2>Unit Conversions</h2>'
      + '<p>Manage conversion factors between measurement units.</p>'
      + '<p>The table shows source and target concepts with their units and conversion factors.</p>'
      + '<p>Use the column filters to search within each column.</p>'

      + '<h3>Actions</h3>'
      + '<ul>'
      + '<li><strong>Add Conversion</strong> \u2014 create a new conversion with source/target concept IDs, unit names, and factor. '
      + 'The add dialog will be improved in a future version to include a concept search datatable.</li>'
      + '<li><strong>Edit factor</strong> \u2014 click a conversion factor cell to edit it inline</li>'
      + '<li><strong>Test</strong> \u2014 open a calculator to verify the conversion (supports bidirectional swap)</li>'
      + '<li><strong>Delete</strong> \u2014 remove a conversion with confirmation</li>'
      + '</ul>'

      + '<h3>Export</h3>'
      + '<p>Click <strong>Export</strong> to open the export modal:</p>'
      + mockSettingsExportModal('en', 'Export')

      + '<h2>Recommended Units</h2>'
      + '<p>Define the recommended unit for each measurement concept.</p>'
      + '<p>This helps ensure consistent unit usage across the dictionary, and is used for automatic '
      + 'unit conversions when exporting concept sets as SQL.</p>'
      + '<p>Use the column filters to search within each column.</p>'

      + '<h3>Actions</h3>'
      + '<ul>'
      + '<li><strong>Add Recommended Unit</strong> \u2014 associate a concept with its recommended unit (concept ID, name, code). '
      + 'The add dialog will be improved in a future version to include a concept search datatable.</li>'
      + '<li><strong>Delete</strong> \u2014 remove a recommendation with confirmation</li>'
      + '</ul>'

      + '<h3>Export</h3>'
      + '<p>Click <strong>Export</strong> to open the export modal:</p>'
      + mockSettingsExportModal('en', 'Export')

      + infoBox('Vocabulary Enrichment',
        'When an OHDSI vocabulary database is loaded, concept names in both tables are '
        + 'automatically resolved from the database. If the database is not yet ready when '
        + 'you open a tab, the application retries automatically.');
  }

  // ==================== FRENCH CONTENT ====================

  function introductionFR() {
    return '<h1>Introduction</h1>'
      + '<p>Le <strong>Dictionnaire de Donn\u00e9es INDICATE</strong> est une application web permettant '
      + 'de parcourir, relire et contribuer \u00e0 une biblioth\u00e8que de jeux de concepts cliniques '
      + 'standardis\u00e9s pour la r\u00e9animation. Il utilise le mod\u00e8le OMOP CDM pour harmoniser '
      + 'les donn\u00e9es de soins intensifs \u00e0 travers les institutions europ\u00e9ennes.</p>'

      + infoBox('Qu\u2019est-ce qu\u2019INDICATE ?',
        '<a href="https://indicate-europe.eu/" target="_blank">INDICATE</a> est une initiative '
        + 'europ\u00e9enne lanc\u00e9e en d\u00e9cembre 2024, cofinanc\u00e9e par le programme Europe '
        + 'Num\u00e9rique de l\u2019UE (Convention n\u00b0 101167778). Le projet vise \u00e0 construire '
        + 'une infrastructure f\u00e9d\u00e9r\u00e9e pour le partage s\u00e9curis\u00e9 de donn\u00e9es '
        + 'de r\u00e9animation \u00e0 travers 15 fournisseurs dans 12 pays.')

      + '<h2>Pourquoi un dictionnaire de donn\u00e9es ?</h2>'
      + '<p>M\u00eame avec des terminologies standardis\u00e9es comme LOINC et SNOMED CT, une seule '
      + 'id\u00e9e clinique (ex. \u00ab Fr\u00e9quence cardiaque \u00bb) peut \u00eatre repr\u00e9sent\u00e9e '
      + 'par des centaines de concepts standards distincts. Le dictionnaire fournit des '
      + '<strong>jeux de concepts</strong> expertis\u00e9s, conformes \u00e0 la '
      + '<a href="https://ohdsi.github.io/TAB/Concept-Set-Specification.html" target="_blank">'
      + 'Sp\u00e9cification OHDSI des Concept Sets</a>.</p>'

      + '<h2>Fonctionnalit\u00e9s principales</h2>'
      + '<div class="doc-feature-grid">'
      + featureCard('fa-book', 'Navigateur de jeux de concepts',
        'Parcourez les jeux de concepts par cat\u00e9gorie clinique\u00a0: signes vitaux, biologie, pathologies, m\u00e9dicaments, ventilation, etc.')
      + featureCard('fa-search', 'Explorateur de concepts',
        'Naviguez dans chaque jeu de concepts, consultez les d\u00e9tails de chaque concept avec des liens vers ATHENA et FHIR, et explorez les hi\u00e9rarchies de vocabulaires.')
      + featureCard('fa-comment-dots', 'Recommandations d\u2019experts',
        'Chaque jeu de concepts inclut des commentaires cliniques en Markdown pour guider l\u2019ETL.')
      + featureCard('fa-chart-bar', 'Statistiques de r\u00e9f\u00e9rence',
        'Distributions attendues (histogrammes, percentiles) pour la validation des donn\u00e9es.')
      + featureCard('fa-user-check', 'Relecture par les pairs',
        'Soumettez des relectures avec suivi de statut et proposez des modifications via GitHub.')
      + featureCard('fa-list-check', 'Projets',
        'Organisez les jeux de concepts en projets de recherche et exportez les listes en CSV.')
      + '</div>'

      + '<h2>\u00c0 qui s\u2019adresse cette application ?</h2>'
      + '<div class="doc-audience-grid">'
      + audienceCard('fa-user-md', 'Cliniciens & Chercheurs',
        'Apportez votre expertise sur les d\u00e9finitions des concepts, relisez leur pertinence, et utilisez les jeux de concepts pour la conception d\u2019\u00e9tudes et la d\u00e9finition de cohortes.')
      + audienceCard('fa-chart-line', 'Data Scientists',
        'Construisez des pipelines ETL et des requ\u00eates f\u00e9d\u00e9r\u00e9es avec des jeux valid\u00e9s.')
      + audienceCard('fa-database', 'Ing\u00e9nieurs de donn\u00e9es',
        'Mappez vos donn\u00e9es sources vers l\u2019OMOP CDM avec les jeux recommand\u00e9s.')
      + '</div>'

      + '<h2>\u00c0 propos du projet</h2>'
      + '<p>Les d\u00e9finitions des jeux de concepts ont \u00e9t\u00e9 d\u00e9velopp\u00e9es par un processus '
      + 'it\u00e9ratif de consensus. Les responsables de cas d\u2019usage ont d\u2019abord identifi\u00e9 les '
      + 'variables n\u00e9cessaires \u00e0 leurs applications cliniques. Ces exigences ont \u00e9t\u00e9 '
      + 'affin\u00e9es lors de r\u00e9unions bimensuelles interdisciplinaires r\u00e9unissant experts '
      + 'cliniques, data scientists et sp\u00e9cialistes d\u2019interop\u00e9rabilit\u00e9.</p>'
      + '<p>La biblioth\u00e8que comprend actuellement plus de 330 jeux de concepts organis\u00e9s en '
      + 'neuf cat\u00e9gories. Tout le contenu est open source sur '
      + '<a href="https://github.com/indicate-eu/data-dictionary" target="_blank">GitHub</a>. '
      + 'En savoir plus sur <a href="https://indicate-europe.eu/" target="_blank">indicate-europe.eu</a>.</p>';
  }

  function gettingStartedFR() {
    return '<h1>Prise en main</h1>'
      + '<p>L\u2019application fonctionne enti\u00e8rement dans le navigateur \u2014 aucune installation '
      + 'ni serveur requis. Ouvrez simplement la page web et commencez \u00e0 naviguer.</p>'

      + '<h2>Visite rapide</h2>'
      + '<p>La barre de navigation en haut donne acc\u00e8s aux sections principales\u00a0:</p>'
      + '<ul>'
      + '<li><strong>Dictionnaire de donn\u00e9es</strong> \u2014 Parcourir et rechercher les jeux de concepts (' + docLink('browsing', 'd\u00e9tails') + ')</li>'
      + '<li><strong>Recommandations de mapping</strong> \u2014 Guide de mapping des variables locales (' + docLink('mapping-recommendations', 'd\u00e9tails') + ')</li>'
      + '<li><strong>Projets</strong> \u2014 Grouper les jeux de concepts par projet de recherche (' + docLink('projects', 'd\u00e9tails') + ')</li>'
      + '<li><strong>Documentation</strong> \u2014 Cette page</li>'
      + '</ul>'

      + '<h2>Optionnel\u00a0: Importer les vocabulaires OHDSI</h2>'
      + '<p>Pour les fonctionnalit\u00e9s avanc\u00e9es (recherche de concepts, expansion des descendants, '
      + 'visualisation hi\u00e9rarchique, optimisation des expressions), vous pouvez importer les fichiers '
      + 'de vocabulaires OHDSI dans une base DuckDB locale qui fonctionne dans le navigateur. '
      + 'Voir ' + docLink('ohdsi-vocabularies', 'Vocabulaires OHDSI') + '.</p>'

      + '<h2>Profil utilisateur</h2>'
      + '<p>Cliquez sur votre nom en haut \u00e0 droite pour configurer votre profil.</p>'
      + '<p>L\u2019onglet <strong>Auteur</strong> contient votre nom, affiliation, profession et ORCID \u2014 '
      + 'ces informations sont int\u00e9gr\u00e9es aux jeux de concepts que vous cr\u00e9ez ou relisez.</p>'
      + '<p>L\u2019onglet <strong>Organisation</strong> permet de d\u00e9finir le nom et l\u2019URL de '
      + 'l\u2019organisation qui appara\u00eetront dans les m\u00e9tadonn\u00e9es des jeux de concepts.</p>'
      + profileMock('fr')

      + '<h2>Langue</h2>'
      + '<p>Basculez entre anglais et fran\u00e7ais avec le bouton <strong>EN</strong>/<strong>FR</strong> '
      + 'dans l\u2019en-t\u00eate. Les noms, cat\u00e9gories et descriptions des jeux de concepts sont '
      + 'multilingues (actuellement anglais et fran\u00e7ais). Le support d\u2019autres langues pourra '
      + '\u00eatre ajout\u00e9 \u00e0 l\u2019avenir.</p>'

      + '<h2>Stockage local</h2>'
      + '<p>Toutes vos modifications (jeux de concepts, projets, relectures) sont stock\u00e9es dans le '
      + 'stockage local de votre navigateur. Elles persistent entre les sessions mais restent locales \u00e0 '
      + 'votre navigateur. Pour partager des modifications, utilisez le '
      + docLink('reviewing', 'workflow GitHub') + '.</p>';
  }

  function whatAreConceptSetsFR() {
    return '<h1>Les jeux de concepts</h1>'

      + '<p>Un <strong>jeu de concepts</strong> (concept set) est une collection r\u00e9utilisable '
      + 'de concepts de vocabulaire OMOP d\u00e9finissant une variable clinique (ex. \u00ab Fr\u00e9quence '
      + 'cardiaque \u00bb, \u00ab Cr\u00e9atinine s\u00e9rique \u00bb, \u00ab Nor\u00e9pin\u00e9phrine \u00bb). '
      + 'Plut\u00f4t que de manipuler des codes LOINC ou SNOMED individuels, les chercheurs et ing\u00e9nieurs '
      + 'de donn\u00e9es travaillent avec des jeux de concepts qui regroupent les codes associ\u00e9s sous '
      + 'des \u00e9tiquettes cliniques intuitives.</p>'

      + '<h2>La Sp\u00e9cification OHDSI</h2>'
      + '<p>Chaque jeu de concepts suit la '
      + '<a href="https://ohdsi.github.io/TAB/Concept-Set-Specification.html" target="_blank">'
      + 'Sp\u00e9cification OHDSI des Concept Sets</a>, le format standard utilis\u00e9 par ATLAS et '
      + 'l\u2019\u00e9cosyst\u00e8me OHDSI. Une expression de jeu de concepts est une liste d\u2019\u00e9l\u00e9ments, '
      + 'o\u00f9 chacun r\u00e9f\u00e9rence un concept OMOP et poss\u00e8de trois options bool\u00e9ennes\u00a0:</p>'
      + '<ul>'
      + '<li><strong>Exclure</strong> \u2014 Retirer ce concept (et optionnellement ses descendants) du jeu</li>'
      + '<li><strong>Descendants</strong> \u2014 Inclure tous les concepts descendants dans la hi\u00e9rarchie du vocabulaire</li>'
      + '<li><strong>Mapp\u00e9</strong> \u2014 Inclure les concepts li\u00e9s par des relations \u00ab Maps to \u00bb</li>'
      + '</ul>'

      + infoBox('Expression vs. R\u00e9solus',
        'L\u2019<strong>expression</strong> est ce que vous r\u00e9digez \u2014 une liste compacte de concepts '
        + 's\u00e9lectionn\u00e9s avec leurs options. Le <strong>jeu r\u00e9solu</strong> est le r\u00e9sultat '
        + '\u00e9tendu apr\u00e8s application des descendants, mapp\u00e9s et exclusions. Par exemple, une expression '
        + 'avec un seul concept de classification LOINC + Descendants peut se r\u00e9soudre en des dizaines '
        + 'de codes de mesure sp\u00e9cifiques.')

      + '<h2>M\u00e9tadonn\u00e9es \u00e9tendues</h2>'
      + '<p>Au-del\u00e0 de la sp\u00e9cification OHDSI standard, chaque jeu de concepts de la biblioth\u00e8que '
      + 'INDICATE inclut des m\u00e9tadonn\u00e9es suppl\u00e9mentaires\u00a0:</p>'
      + '<ul>'
      + '<li><strong>Version</strong> \u2014 Versioning s\u00e9mantique (ex. 1.0.0) avec un historique des versions</li>'
      + '<li><strong>Statut de relecture</strong> \u2014 Brouillon, En attente de relecture, Approuv\u00e9, \u00c0 r\u00e9viser ou Obsol\u00e8te</li>'
      + '<li><strong>Informations auteur</strong> \u2014 Nom, affiliation, profession, ORCID</li>'
      + '<li><strong>Traductions</strong> \u2014 Nom, cat\u00e9gorie et sous-cat\u00e9gorie multilingues (actuellement anglais et fran\u00e7ais, extensible \u00e0 d\u2019autres langues)</li>'
      + '<li><strong>Commentaires d\u2019experts</strong> \u2014 Champ Markdown pour les recommandations cliniques et ETL</li>'
      + '<li><strong>Profils statistiques</strong> \u2014 Distributions attendues pour la validation des donn\u00e9es</li>'
      + '<li><strong>Historique de relectures</strong> \u2014 Nom du relecteur, date, statut et commentaires pour chaque relecture</li>'
      + '</ul>'

      + '<h2>Cat\u00e9gories</h2>'
      + '<p>Les jeux de concepts sont organis\u00e9s en neuf cat\u00e9gories cliniques\u00a0:</p>'
      + '<ul>'
      + '<li>D\u00e9mographie & Rencontres</li>'
      + '<li>Pathologies (diagnostics)</li>'
      + '<li>Observations cliniques (\u00e9chelles d\u2019\u00e9valuation)</li>'
      + '<li>Signes vitaux</li>'
      + '<li>Biologie</li>'
      + '<li>Microbiologie</li>'
      + '<li>Ventilation</li>'
      + '<li>M\u00e9dicaments</li>'
      + '<li>Proc\u00e9dures</li>'
      + '</ul>'

      + '<h2>Cas d\u2019utilisation</h2>'
      + '<p>Ces jeux de concepts expertis\u00e9s, relus et versionn\u00e9s peuvent \u00eatre utilis\u00e9s pour\u00a0:</p>'
      + '<ul>'
      + '<li><strong>D\u00e9finition de cohortes</strong> \u2014 Comme briques de base dans ATLAS ou des requ\u00eates personnalis\u00e9es</li>'
      + '<li><strong>D\u00e9veloppement ETL</strong> \u2014 Pour prioriser et valider les mappings de concepts</li>'
      + '<li><strong>Faisabilit\u00e9 d\u2019\u00e9tudes</strong> \u2014 Pour \u00e9valuer la disponibilit\u00e9 des donn\u00e9es dans un r\u00e9seau f\u00e9d\u00e9r\u00e9</li>'
      + '</ul>';
  }

  function browsingFR() {
    return '<h1>Parcourir les jeux de concepts</h1>'
      + '<p>La page <strong>Dictionnaire de donn\u00e9es</strong> affiche tous les jeux dans un tableau filtrable.</p>'

      + '<h2>Badges de cat\u00e9gorie</h2>'
      + '<p>En haut de page, des badges indiquent chaque cat\u00e9gorie avec son nombre de jeux. '
      + 'Cliquez pour filtrer, re-cliquez pour retirer le filtre. S\u00e9lection multiple possible.</p>'
      + '<div class="category-badges" style="justify-content:center; margin:16px 0">'
      + '<span class="category-badge">Signes vitaux <span class="count">10</span></span>'
      + '<span class="category-badge active">Biologie <span class="count">76</span></span>'
      + '<span class="category-badge">M\u00e9dicaments <span class="count">112</span></span>'
      + '<span class="category-badge">Ventilation <span class="count">26</span></span>'
      + '</div>'

      + '<h2>Recherche & Filtres</h2>'
      + '<p>Chaque en-t\u00eate de colonne dispose d\u2019un filtre. La plupart utilisent une '
      + 'correspondance exacte, mais la colonne <strong>Nom</strong> utilise une '
      + '<strong>recherche floue</strong> \u2014 par exemple, \u00ab hart rate \u00bb trouvera '
      + '\u00ab Heart rate \u00bb.</p>'
      + '<p>Des menus d\u00e9roulants multi-s\u00e9lection permettent aussi de filtrer par\u00a0:</p>'
      + '<ul>'
      + '<li><strong>Cat\u00e9gorie</strong> \u2014 Comme les badges, avec compteurs</li>'
      + '<li><strong>Sous-cat\u00e9gorie</strong> \u2014 Adapt\u00e9e aux cat\u00e9gories s\u00e9lectionn\u00e9es</li>'
      + '<li><strong>Statut de relecture</strong> \u2014 Brouillon, Approuv\u00e9, etc.</li>'
      + '</ul>'

      + '<h2>Tableau</h2>'
      + '<p>Cliquez sur un en-t\u00eate de colonne pour trier. Cliquez sur une ligne pour ouvrir la '
      + docLink('concept-set-details', 'vue d\u00e9taill\u00e9e') + '.</p>'
      + mockConceptSetTable('fr');
  }

  function conceptSetDetailsFR() {
    return '<h1>D\u00e9tails d\u2019un jeu de concepts</h1>'
      + '<p>La vue d\u00e9taill\u00e9e affiche toutes les informations d\u2019un jeu de concepts, organis\u00e9es en quatre onglets\u00a0: <strong>Concepts</strong>, <strong>Commentaires</strong>, <strong>Statistiques</strong> et <strong>Relecture</strong>.</p>'

      + '<h2 id="doc-tab-concepts">Onglet Concepts</h2>'
      + detailTabs('fr', 'concepts')
      + '<p>Cet onglet propose deux modes, accessibles via un commutateur\u00a0: <strong>Expression</strong> et <strong>R\u00e9solus</strong>.</p>'

      + '<h3>Mode Expression</h3>'
      + conceptModeToggle('fr', 'expression')
      + '<p>Affiche l\u2019expression du jeu de concepts \u2014 les \u00e9l\u00e9ments r\u00e9dig\u00e9s avec leurs options.</p>'
      + '<p>Chaque ligne affiche le Vocabulaire, le Nom du concept, le Code, le Domaine, la Classe de concept, '
      + 'le statut Standard, et trois options bool\u00e9ennes\u00a0: <strong>Exclure</strong>, '
      + '<strong>Descendants</strong> et <strong>Mapp\u00e9</strong>.</p>'
      + '<p>Ces options contr\u00f4lent la r\u00e9solution de l\u2019expression en jeu final de concepts. '
      + 'Voir ' + docLink('editing-concept-sets', 'Modifier un jeu de concepts') + ' pour les explications d\u00e9taill\u00e9es.</p>'
      + '<p>Utilisez les filtres de colonnes (vocabulaire, domaine, standard, recherche floue par nom) pour naviguer dans les expressions volumineuses.</p>'
      + '<p style="font-size:12px; color:var(--text-muted); margin-bottom:4px"><i class="fas fa-info-circle"></i> '
      + 'Exemple\u00a0: expression du jeu de concepts Fr\u00e9quence cardiaque.</p>'
      + mockExpressionTable('fr')

      + '<h3>Mode R\u00e9solus</h3>'
      + conceptModeToggle('fr', 'resolved')
      + '<p>Affiche le r\u00e9sultat \u00e9tendu apr\u00e8s application de toute la logique de l\u2019expression. '
      + 'C\u2019est l\u2019ensemble r\u00e9el de concepts OMOP qui serait utilis\u00e9 dans une requ\u00eate. '
      + 'Les colonnes incluent ID du concept, Vocabulaire, Nom, Code, Domaine, Standard et Classe de concept.</p>'
      + '<p>Si une base de vocabulaires OHDSI est charg\u00e9e (voir ' + docLink('ohdsi-vocabularies', 'Vocabulaires OHDSI') + '), '
      + 'la r\u00e9solution est calcul\u00e9e en temps r\u00e9el dans le navigateur. Sinon, les jeux r\u00e9solus '
      + 'pr\u00e9-calcul\u00e9s du d\u00e9p\u00f4t sont utilis\u00e9s.</p>'
      + '<p style="font-size:12px; color:var(--text-muted); margin-bottom:4px"><i class="fas fa-info-circle"></i> '
      + 'Exemple\u00a0: jeu r\u00e9solu Fr\u00e9quence cardiaque \u2014 les concepts OMOP standards apr\u00e8s expansion.</p>'
      + mockResolvedTable('fr')

      + '<h3>Panneau de d\u00e9tail concept</h3>'
      + '<p>Cliquez sur un concept pour afficher le panneau de d\u00e9tails. Il contient trois sections\u00a0:</p>'
      + '<p style="font-size:12px; color:var(--text-muted); margin-bottom:4px"><i class="fas fa-info-circle"></i> '
      + 'Exemple\u00a0: \u00ab Heart rate --W exercise \u00bb (LOINC 89273-7).</p>'
      + mockConceptDetailPanel('fr')

      + '<p style="margin-top:20px">La grille <strong>D\u00e9tails du concept</strong> affiche toutes les m\u00e9tadonn\u00e9es, '
      + 'avec des liens vers <a href="https://athena.ohdsi.org/" target="_blank">ATHENA</a> (via l\u2019ID du concept) '
      + 'et le <a href="https://tx.fhir.org/r4/" target="_blank">serveur de terminologie FHIR</a> (via la Ressource FHIR).</p>'
      + '<p>Trois onglets sous les m\u00e9tadonn\u00e9es fournissent des informations compl\u00e9mentaires\u00a0:</p>'
      + '<ul>'
      + '<li><strong>Related</strong> \u2014 Relations avec d\u2019autres concepts (Is a, Has component, Maps to, etc.). Filtrables par type de relation, vocabulaire et nom.</li>'
      + '<li><strong>Hi\u00e9rarchie</strong> \u2014 Graphe interactif force-directed (vis.js) montrant anc\u00eatres, descendants et concepts li\u00e9s. Cliquez sur un n\u0153ud pour naviguer vers ce concept.</li>'
      + '<li><strong>Synonymes</strong> \u2014 Noms alternatifs du concept depuis le vocabulaire OMOP (y compris des traductions dans d\u2019autres langues).</li>'
      + '</ul>'

      + '<h2 id="doc-tab-comments">Onglet Commentaires</h2>'
      + detailTabs('fr', 'comments')
      + '<p>Affiche les recommandations d\u2019experts en Markdown. Les commentaires d\u00e9crivent g\u00e9n\u00e9ralement\u00a0:</p>'
      + '<ul>'
      + '<li>La signification clinique et le contexte du jeu de concepts</li>'
      + '<li>Quels concepts privil\u00e9gier dans des sc\u00e9narios sp\u00e9cifiques</li>'
      + '<li>Les pi\u00e8ges courants lors de l\u2019ETL</li>'
      + '<li>Les diff\u00e9rences entre concepts similaires de diff\u00e9rents vocabulaires</li>'
      + '</ul>'
      + '<p>En mode \u00e9dition, un \u00e9diteur double panneau avec aper\u00e7u Markdown en direct est disponible.</p>'
      + mockCommentsPanel('fr')
      + '<p>Pour les recommandations plus g\u00e9n\u00e9rales concernant plusieurs jeux de concepts '
      + '(bonnes pratiques ETL, strat\u00e9gies de mapping), consultez la page '
      + docLink('mapping-recommendations', 'Recommandations de mapping') + '.</p>'

      + '<h2 id="doc-tab-statistics">Onglet Statistiques</h2>'
      + detailTabs('fr', 'statistics')
      + infoBox('En cours de d\u00e9veloppement',
        'Cette fonctionnalit\u00e9 est encore en discussion et n\u2019a pas encore \u00e9t\u00e9 '
        + 'mise en \u0153uvre en pratique. Le format et le contenu des profils statistiques pourront \u00e9voluer.', 'warning')
      + '<p>Affiche les distributions attendues des donn\u00e9es pour aider \u00e0 valider vos donn\u00e9es lors de l\u2019ETL\u00a0:</p>'
      + '<ul>'
      + '<li><strong>Donn\u00e9es num\u00e9riques</strong> \u2014 Min, P5, P25 (Q1), M\u00e9diane, Moyenne, P75 (Q3), P95, Max, \u00c9T, CV</li>'
      + '<li><strong>Histogrammes</strong> \u2014 Diagrammes en barres horizontales de la distribution des valeurs</li>'
      + '<li><strong>Donn\u00e9es cat\u00e9gorielles</strong> \u2014 Cat\u00e9gories avec effectifs et pourcentages</li>'
      + '<li><strong>Profils multiples</strong> \u2014 ex. Adulte, Enfant, Nouveau-n\u00e9 avec des plages de r\u00e9f\u00e9rence diff\u00e9rentes</li>'
      + '<li><strong>Fr\u00e9quence de mesure</strong> \u2014 Intervalle d\u2019enregistrement typique (horaire, quotidien, etc.)</li>'
      + '</ul>'

      + '<h2 id="doc-tab-review">Onglet Relecture</h2>'
      + detailTabs('fr', 'review')
      + '<p>Affiche l\u2019historique des relectures pour ce jeu de concepts. Chaque relecture enregistre '
      + 'le relecteur, la date, le statut, la version relue et les commentaires.</p>'
      + mockReviewTable('fr')
      + '<p>Voir ' + docLink('reviewing', 'Relecture & GitHub') + ' pour le workflow complet de soumission '
      + 'de relectures et de proposition de modifications sur GitHub.</p>'

      + '<h2>M\u00e9tadonn\u00e9es de l\u2019en-t\u00eate</h2>'
      + '<p>L\u2019en-t\u00eate de la vue d\u00e9taill\u00e9e affiche\u00a0:</p>'
      + '<ul>'
      + '<li><strong>Badge de version</strong> \u2014 Cliquez pour afficher l\u2019historique des versions</li>'
      + '<li><strong>Badge de statut de relecture</strong> \u2014 Cliquez pour modifier le statut (en mode \u00e9dition)</li>'
      + '<li><strong>Exporter</strong> \u2014 T\u00e9l\u00e9charger ou copier en JSON, proposer sur GitHub, '
      + 'ou g\u00e9n\u00e9rer une requ\u00eate SQL OMOP avec conversions d\u2019unit\u00e9s (voir ' + docLink('exporting', 'Exporter') + ')</li>'
      + '</ul>';
  }

  function editingConceptSetsFR() {
    return '<h1>Modifier les jeux de concepts</h1>'
      + '<p>Toutes les modifications sont sauvegard\u00e9es dans le stockage local de votre navigateur. '
      + 'Elles persistent entre les sessions mais sont li\u00e9es \u00e0 votre navigateur.</p>'
      + infoBox('Avertissement stockage local',
        'Si vous effacez les donn\u00e9es de votre navigateur, les modifications locales seront perdues. '
        + 'Pensez \u00e0 <strong>exporter</strong> votre travail en JSON et/ou '
        + '<strong>proposer des modifications sur GitHub</strong> via une pull request pour les pr\u00e9server. '
        + 'Voir ' + docLink('exporting', 'Exporter') + ' et '
        + docLink('reviewing', 'Relecture & GitHub') + '.', 'warning')

      + '<p>Cette section couvre deux niveaux d\u2019\u00e9dition\u00a0: d\u2019abord, la gestion de la liste des jeux de concepts '
      + '(ajout, suppression, renommage)\u00a0; puis, l\u2019\u00e9dition des d\u00e9tails d\u2019un jeu de concepts '
      + '(expression, commentaires, statistiques).</p>'

      + '<h2>Modifier la liste des jeux de concepts</h2>'
      + '<p>Ces actions s\u2019appliquent au tableau principal du Dictionnaire de donn\u00e9es.</p>'

      + '<h3>Entrer en mode \u00e9dition</h3>'
      + '<p>Cliquez sur le bouton <strong>\u00c9diter</strong> dans la barre d\u2019outils\u00a0:</p>'
      + '<div style="display:flex; gap:6px; justify-content:center; margin:16px 0; flex-wrap:wrap; align-items:center">'
      + '<button class="btn-primary-custom btn-gray" style="cursor:default"><i class="fas fa-pen"></i> \u00c9diter</button>'
      + '<button class="btn-primary-custom" style="cursor:default"><i class="fas fa-download"></i> Exporter</button>'
      + '</div>'
      + '<p>La barre d\u2019outils change pour afficher les contr\u00f4les de s\u00e9lection, d\u2019ajout et de sauvegarde/annulation\u00a0:</p>'
      + '<div style="display:flex; gap:6px; justify-content:center; margin:16px 0; flex-wrap:wrap; align-items:center">'
      + '<button class="btn-secondary-custom btn-sm" style="cursor:default"><i class="fas fa-check-square"></i></button>'
      + '<button class="btn-secondary-custom btn-sm" style="cursor:default"><i class="far fa-square"></i></button>'
      + '<button class="btn-danger-custom btn-sm" style="cursor:default"><i class="fas fa-trash"></i></button>'
      + '<span style="font-size:12px; color:var(--text-muted)">0 s\u00e9lectionn\u00e9(s)</span>'
      + '<button class="btn-primary-custom btn-gray" style="cursor:default"><i class="fas fa-times"></i> Annuler</button>'
      + '<button class="btn-primary-custom" style="cursor:default"><i class="fas fa-save"></i> Enregistrer</button>'
      + '<button class="btn-success-custom" style="cursor:default"><i class="fas fa-plus"></i> Ajouter un jeu de concepts</button>'
      + '</div>'

      + '<h3>Ajouter un jeu de concepts</h3>'
      + '<p>En mode \u00e9dition, cliquez sur <strong>Ajouter un jeu de concepts</strong> (bouton vert). Un modal s\u2019ouvre '
      + 'o\u00f9 vous fournissez un nom et une cat\u00e9gorie (obligatoires), et optionnellement une sous-cat\u00e9gorie '
      + 'et une description. Utilisez le bouton <strong>+</strong> \u00e0 c\u00f4t\u00e9 de la cat\u00e9gorie ou '
      + 'sous-cat\u00e9gorie pour en cr\u00e9er une nouvelle.</p>'
      + mockNewConceptSetModal('fr')

      + '<h3>S\u00e9lectionner, modifier & supprimer</h3>'
      + '<p>En mode \u00e9dition, deux colonnes suppl\u00e9mentaires apparaissent sur chaque ligne\u00a0: une '
      + '<strong>case \u00e0 cocher</strong> pour la s\u00e9lection et une <strong>ic\u00f4ne crayon</strong> pour modifier ce jeu.</p>'
      + mockEditModeTable(App.lang)
      + '<p style="margin-top:16px"><button class="cs-row-edit-btn" style="cursor:default"><i class="fas fa-pen"></i></button> '
      + '<strong>Modifier</strong> \u2014 '
      + 'Ouvre le modal d\u2019\u00e9dition (m\u00eame formulaire que \u00ab Nouveau jeu de concepts \u00bb, pr\u00e9-rempli).</p>'
      + '<p><button class="btn-secondary-custom btn-sm" style="cursor:default"><i class="fas fa-check-square"></i></button> '
      + '<button class="btn-secondary-custom btn-sm" style="cursor:default"><i class="far fa-square"></i></button> '
      + '<strong>Tout s\u00e9lectionner / D\u00e9s\u00e9lectionner</strong> \u2014 '
      + 'Basculer la s\u00e9lection sur toutes les lignes.</p>'
      + '<p><button class="btn-danger-custom btn-sm" style="cursor:default"><i class="fas fa-trash"></i></button> '
      + '<strong>Supprimer</strong> \u2014 '
      + 'Supprimer les jeux de concepts s\u00e9lectionn\u00e9s.</p>'

      + '<h3>Enregistrer & Annuler</h3>'
      + '<p>Toutes les modifications en mode \u00e9dition sont en attente jusqu\u2019\u00e0 ce que vous agissiez explicitement\u00a0:</p>'
      + '<ul>'
      + '<li><strong>Enregistrer</strong> \u2014 Valide toutes les modifications en attente dans le stockage local</li>'
      + '<li><strong>Annuler</strong> \u2014 Annule toutes les modifications, restaurant la liste \u00e0 son \u00e9tat avant '
      + 'l\u2019entr\u00e9e en mode \u00e9dition. Cela d\u00e9fait tout\u00a0: ajouts, modifications et suppressions.</li>'
      + '</ul>'

      + '<h2>Modifier les d\u00e9tails d\u2019un jeu de concepts</h2>'
      + '<p>Ouvrez un jeu de concepts, puis cliquez sur <strong>\u00c9diter</strong> dans l\u2019en-t\u00eate. '
      + 'Les boutons \u00c9diter et Exporter sont remplac\u00e9s par Importer, Annuler et Enregistrer\u00a0:</p>'
      + '<div style="display:flex; gap:6px; justify-content:center; margin:16px 0; flex-wrap:wrap">'
      + '<button class="btn-primary-custom btn-purple" style="cursor:default"><i class="fas fa-file-import"></i> Importer</button>'
      + '<button class="btn-primary-custom btn-gray" style="cursor:default"><i class="fas fa-times"></i> Annuler</button>'
      + '<button class="btn-primary-custom" style="cursor:default"><i class="fas fa-save"></i> Enregistrer</button>'
      + '</div>'

      + '<h3>Options de l\u2019expression</h3>'
      + '<p>Chaque concept de l\u2019expression a trois options que vous pouvez basculer directement dans '
      + 'le tableau. Ces options suivent la '
      + '<a href="https://ohdsi.github.io/TAB/Concept-Set-Specification.html" target="_blank">'
      + 'Sp\u00e9cification OHDSI des Concept Sets</a>\u00a0:</p>'
      + '<p style="font-size:12px; color:var(--text-muted); margin-bottom:4px"><i class="fas fa-info-circle"></i> '
      + 'Exemple\u00a0: expression Fr\u00e9quence cardiaque en mode \u00e9dition. Les interrupteurs contr\u00f4lent chaque option. L\u2019ic\u00f4ne corbeille supprime un \u00e9l\u00e9ment.</p>'
      + mockExpressionEditTable(App.lang)

      + '<p><strong>Descendants</strong> \u2014 Lorsque coch\u00e9, tous les concepts descendants dans la '
      + 'hi\u00e9rarchie du vocabulaire sont automatiquement inclus. Les vocabulaires OMOP organisent les concepts '
      + 'en arbres hi\u00e9rarchiques via les relations \u00ab Is a \u00bb / \u00ab Subsumes \u00bb (stock\u00e9es '
      + 'dans la table CONCEPT_ANCESTOR). Par exemple, le concept hi\u00e9rarchique LOINC '
      + '\u00ab Heart rate \u00bb a des dizaines de descendants comme \u00ab Heart rate \u2013\u2013resting \u00bb, '
      + '\u00ab Heart rate \u2013\u2013sitting \u00bb, \u00ab Heart rate by Pulse oximetry \u00bb, etc. '
      + 'Cocher Descendants sur un concept parent les capture tous sans les lister individuellement.</p>'

      + '<p><strong>Mapp\u00e9</strong> \u2014 Lorsque coch\u00e9, les concepts non standards li\u00e9s au '
      + 'concept s\u00e9lectionn\u00e9 via les relations \u00ab Maps to \u00bb / \u00ab Mapped from \u00bb sont '
      + '\u00e9galement inclus. Dans le vocabulaire OMOP, chaque id\u00e9e clinique a un seul concept '
      + 'd\u00e9sign\u00e9 <strong>Standard</strong> (marqu\u00e9 \u00ab S \u00bb). Les autres codes de vocabulaire '
      + 'repr\u00e9sentant la m\u00eame id\u00e9e sont <strong>non standards</strong> et li\u00e9s au concept '
      + 'Standard via \u00ab Maps to \u00bb. Par exemple, SNOMED \u00ab Heart rate \u00bb (ID 4239408, non standard) '
      + 'mappe vers LOINC \u00ab Heart rate \u00bb (ID 3027018, Standard). Cocher Mapp\u00e9 garantit que les '
      + 'concepts non standards d\u2019autres vocabulaires sont captur\u00e9s avec le concept standard.</p>'

      + '<p><strong>Exclure</strong> \u2014 Lorsque coch\u00e9, ce concept est retir\u00e9 du jeu r\u00e9solu. '
      + 'Si Descendants est \u00e9galement coch\u00e9, tous ses descendants sont aussi exclus. Cela permet '
      + 'd\u2019inclure un concept parent large avec ses descendants, puis d\u2019exclure s\u00e9lectivement '
      + 'certaines branches. Par exemple, dans le jeu Fr\u00e9quence cardiaque, \u00ab Fetal heart rate \u00bb '
      + 'est exclu avec Descendants pour retirer les mesures sp\u00e9cifiques au f\u0153tus.</p>'

      + infoBox('Algorithme de r\u00e9solution',
        'Le jeu de concepts est r\u00e9solu en trois \u00e9tapes\u00a0:'
        + '<ol style="margin:8px 0 0 0; padding-left:20px">'
        + '<li>Construire l\u2019<strong>ensemble d\u2019inclusion</strong> \u00e0 partir de tous les \u00e9l\u00e9ments o\u00f9 Exclure est d\u00e9coch\u00e9, en \u00e9tendant via Descendants et Mapp\u00e9 selon la configuration</li>'
        + '<li>Construire l\u2019<strong>ensemble d\u2019exclusion</strong> \u00e0 partir des \u00e9l\u00e9ments o\u00f9 Exclure est coch\u00e9, avec la m\u00eame logique d\u2019expansion</li>'
        + '<li>R\u00e9sultat final = <strong>ensemble d\u2019inclusion moins ensemble d\u2019exclusion</strong></li>'
        + '</ol>')

      + '<h3>Ajouter des concepts</h3>'
      + '<p>En mode \u00e9dition, la barre d\u2019outils de l\u2019expression affiche des boutons suppl\u00e9mentaires\u00a0:</p>'
      + '<div style="display:flex; gap:6px; justify-content:center; margin:16px 0; flex-wrap:wrap; align-items:center">'
      + '<button class="btn-secondary-custom btn-sm" style="cursor:default"><i class="fas fa-check-square"></i></button>'
      + '<button class="btn-secondary-custom btn-sm" style="cursor:default"><i class="far fa-square"></i></button>'
      + '<button class="btn-danger-custom btn-sm" style="cursor:default"><i class="fas fa-trash"></i></button>'
      + '<span style="font-size:12px; color:var(--text-muted)">0 s\u00e9lectionn\u00e9(s)</span>'
      + '<button class="btn-success-custom" style="cursor:default"><i class="fas fa-plus"></i> Ajouter des concepts</button>'
      + '<button class="btn-primary-custom" style="cursor:default"><i class="fas fa-magic"></i> Optimiser</button>'
      + '</div>'
      + '<p>Cliquez sur <strong>Ajouter des concepts</strong> pour ouvrir un modal plein \u00e9cran avec deux onglets\u00a0:</p>'
      + '<div style="display:flex; gap:0; justify-content:center; margin:16px 0">'
      + '<button class="expr-add-tab active" style="cursor:default">Vocabulaires OHDSI</button>'
      + '<button class="expr-add-tab" style="cursor:default">Concept personnalis\u00e9</button>'
      + '</div>'
      + '<ul>'
      + '<li><strong>Vocabulaires OHDSI</strong> \u2014 '
      + 'Recherchez et ajoutez des concepts OMOP standards depuis la base de vocabulaires OHDSI (SNOMED, LOINC, RxNorm, etc.). C\u2019est la m\u00e9thode principale pour construire les expressions.</li>'
      + '<li><strong>Concept personnalis\u00e9</strong> \u2014 '
      + 'Cr\u00e9ez manuellement un concept hors OMOP quand aucun concept standard n\u2019existe. \u00c0 utiliser en dernier recours \u2014 les concepts personnalis\u00e9s ne sont pas interop\u00e9rables avec l\u2019\u00e9cosyst\u00e8me OHDSI.</li>'
      + '</ul>'

      + '<h4>Vocabulaires OHDSI</h4>'
      + '<p>Recherchez dans la base de vocabulaires OHDSI locale par nom, ID ou code. N\u00e9cessite l\u2019'
      + docLink('ohdsi-vocabularies', 'import des vocabulaires')
      + '. La recherche utilise une <strong>correspondance floue</strong> sur les noms.</p>'
      + '<div class="doc-mock-modal" style="max-width:100%; padding:12px 16px">'
      + '<div style="display:flex; gap:6px; align-items:center; flex-wrap:wrap">'
      + '<input type="text" class="form-input" placeholder="Rechercher par nom, code ou ID..." value="heart rate" readonly style="flex:1; min-width:200px">'
      + '<button class="btn-primary-custom" style="cursor:default"><i class="fas fa-search"></i> Rechercher</button>'
      + '<button class="btn-primary-custom btn-gray" style="cursor:default"><i class="fas fa-filter"></i> Filtres</button>'
      + '<label style="display:inline-flex; align-items:center; gap:4px; font-size:12px; color:var(--text-muted); white-space:nowrap">'
      + '<input type="checkbox" checked onclick="return false"> <span>Limite 10K</span></label>'
      + '</div></div>'
      + '<p style="margin-top:16px">Le bouton <strong>Filtres</strong> ouvre un popup pour affiner les r\u00e9sultats\u00a0:</p>'
      + mockFiltersPopup(App.lang)
      + '<p><strong>Limite 10K</strong> limite les r\u00e9sultats \u00e0 10\u202f000 pour \u00e9viter de surcharger le tableau.</p>'
      + '<p>Les r\u00e9sultats sont affich\u00e9s dans un tableau avec filtres par colonne\u00a0:</p>'
      + mockAddConceptsTable(App.lang)
      + '<p>Sous le tableau, deux panneaux affichent les d\u00e9tails du concept s\u00e9lectionn\u00e9\u00a0:</p>'
      + '<ul>'
      + '<li><strong>D\u00e9tails du concept</strong> \u2014 M\u00e9tadonn\u00e9es compl\u00e8tes, liens ATHENA et FHIR</li>'
      + '<li><strong>Hi\u00e9rarchie</strong> \u2014 Graphe interactif des anc\u00eatres, descendants et concepts li\u00e9s</li>'
      + '</ul>'
      + '<p>En bas, configurez les options et ajoutez le(s) concept(s) s\u00e9lectionn\u00e9(s)\u00a0:</p>'
      + mockAddConceptsFooter(App.lang, false)
      + '<p>Cochez <strong>S\u00e9lection multiple</strong> pour s\u00e9lectionner plusieurs concepts avec les '
      + 'cases \u00e0 cocher du tableau, puis les ajouter en une seule fois.</p>'

      + '<h4>Concept personnalis\u00e9</h4>'
      + '<p>Cr\u00e9ez des concepts hors OMOP quand aucun concept standard n\u2019existe. \u00c0 utiliser avec parcimonie.</p>'
      + mockCustomConceptForm(App.lang)
      + '<p>Seule l\u2019option <strong>Exclure</strong> est disponible pour les concepts personnalis\u00e9s, '
      + 'car Descendants et Mapp\u00e9 reposent sur des relations de vocabulaire OMOP inexistantes pour les entr\u00e9es personnalis\u00e9es.</p>'
      + mockAddConceptsFooter(App.lang, true)

      + '<h3>Importer un JSON</h3>'
      + '<p>Cliquez sur <strong>Importer</strong> (bouton violet) pour coller une expression au format ATLAS ou INDICATE. '
      + 'L\u2019importateur accepte les noms de champs en MAJUSCULES (ATLAS) et en camelCase (INDICATE), '
      + 'd\u00e9duplique par ID de concept, et rapporte les compteurs d\u2019ajouts/ignor\u00e9s.</p>'

      + '<h3>Supprimer des concepts</h3>'
      + '<p>Utilisez l\u2019ic\u00f4ne corbeille sur chaque ligne, ou s\u00e9lectionnez plusieurs lignes avec les cases \u00e0 cocher '
      + 'et cliquez sur le bouton rouge corbeille dans la barre d\u2019outils.</p>'

      + '<h3>Optimiser l\u2019expression</h3>'
      + '<p>Cliquez sur <strong>Optimiser</strong> pour simplifier l\u2019expression en utilisant l\u2019analyse de la '
      + 'hi\u00e9rarchie du vocabulaire (n\u00e9cessite une base de vocabulaires OHDSI). L\u2019optimiseur\u00a0:</p>'
      + '<ul>'
      + '<li>Supprime les descendants d\u00e9j\u00e0 couverts par l\u2019option \u00ab Inclure les descendants \u00bb d\u2019un parent (descendant)</li>'
      + '<li>Supprime les \u00e9l\u00e9ments parents qui n\u2019\u00e9largissent pas le p\u00e9rim\u00e8tre (ascendant)</li>'
      + '<li>Affiche une comparaison avant/apr\u00e8s avec les \u00e9l\u00e9ments qui seraient supprim\u00e9s ou ajout\u00e9s</li>'
      + '<li>Avertit si l\u2019optimisation modifie le jeu r\u00e9solu</li>'
      + '</ul>'

      + '<h3>Modifier les commentaires</h3>'
      + '<p>Dans l\u2019onglet Commentaires, le mode \u00e9dition ouvre un \u00e9diteur ACE avec coloration syntaxique '
      + 'Markdown et un panneau d\u2019aper\u00e7u en direct. Utilisez Cmd/Ctrl+S pour enregistrer. Les commentaires sont stock\u00e9s par langue.</p>'

      + '<h3>Modifier les statistiques</h3>'
      + '<p>Dans l\u2019onglet Statistiques, le mode \u00e9dition ouvre un \u00e9diteur JSON. Un mod\u00e8le avec '
      + 'la structure attendue est fourni. Vous pouvez d\u00e9finir des donn\u00e9es num\u00e9riques (min, max, moyenne, '
      + 'm\u00e9diane, \u00c9T, percentiles, histogramme), des donn\u00e9es cat\u00e9gorielles, la fr\u00e9quence '
      + 'de mesure et des profils de population multiples.</p>'

      + '<h3>Version & Statut</h3>'
      + '<p>Lors de l\u2019enregistrement des modifications, vous pouvez mettre \u00e0 jour la version '
      + '(suggestion\u00a0: incr\u00e9ment patch) et ajouter un r\u00e9sum\u00e9 de version. Le statut de relecture '
      + 'peut \u00eatre modifi\u00e9 via le badge de statut dans l\u2019en-t\u00eate.</p>';
  }

  function reviewingFR() {
    return '<h1>Relecture & Proposition sur GitHub</h1>'
      + '<p>Le Dictionnaire de Donn\u00e9es INDICATE utilise un workflow GitHub pour contribuer des modifications. '
      + 'Tout le contenu est stock\u00e9 en fichiers JSON dans le d\u00e9p\u00f4t '
      + '<a href="https://github.com/indicate-eu/data-dictionary" target="_blank">'
      + 'indicate-eu/data-dictionary</a>.</p>'

      // ===== SOUMETTRE UNE RELECTURE =====
      + '<h2>Soumettre une relecture</h2>'
      + '<p>Ouvrez un jeu de concepts, allez dans l\u2019onglet <strong>Relecture</strong>, et cliquez sur '
      + '<button class="tab-btn-green" style="cursor:default"><i class="fas fa-plus"></i> Ajouter une relecture</button>. '
      + 'Un \u00e9diteur plein \u00e9cran s\u2019ouvre\u00a0:</p>'

      + '<div class="doc-mock-modal" style="max-width:100%">'
      + '<div style="padding:6px 15px; border-bottom:1px solid #ddd; background:#f8f9fa; display:flex; align-items:center; gap:12px">'
      + '<h3 style="margin:0; font-size:15px">Ajouter une relecture</h3>'
      + '<label style="font-size:12px; font-weight:600; color:var(--text-muted)">Statut\u00a0:</label>'
      + '<select class="form-input" disabled style="width:140px; height:28px; font-size:12px; padding:2px 8px">'
      + '<option>\u00c0 r\u00e9viser</option></select>'
      + '<button class="btn-success-custom" style="cursor:default"><i class="fas fa-check"></i> Soumettre la relecture</button>'
      + '<span style="flex:1"></span>'
      + '<span class="modal-close" style="cursor:default; font-size:20px">&times;</span>'
      + '</div>'
      + '<div style="display:flex; min-height:180px">'
      + '<div style="flex:1; border-right:1px solid #ddd; display:flex; flex-direction:column">'
      + '<div style="font-size:12px; font-weight:600; color:var(--text-muted); padding:6px 12px; border-bottom:1px solid #eee">'
      + '<i class="fas fa-pencil-alt"></i> \u00c9diteur</div>'
      + '<div style="padding:12px; font-family:monospace; font-size:12px; color:#333; flex:1; background:#fafafa; white-space:pre-wrap">'
      + 'La fr\u00e9quence cardiaque f\u0153tale devrait \u00eatre exclue de ce jeu.\n\n'
      + 'Elle est enregistr\u00e9e au **niveau maternel** (dans le dossier obst\u00e9trical de la m\u00e8re), '
      + 'cr\u00e9ant un risque de confusion avec la fr\u00e9quence cardiaque propre de la m\u00e8re.\n\n'
      + 'Je sugg\u00e8re de la d\u00e9placer dans un jeu de concepts d\u00e9di\u00e9.'
      + '</div></div>'
      + '<div style="flex:1; display:flex; flex-direction:column">'
      + '<div style="font-size:12px; font-weight:600; color:var(--text-muted); padding:6px 12px; border-bottom:1px solid #eee">'
      + '<i class="fas fa-eye"></i> Aper\u00e7u</div>'
      + '<div style="padding:12px; font-size:13px; flex:1">'
      + '<p style="margin:0 0 10px">La fr\u00e9quence cardiaque f\u0153tale devrait \u00eatre exclue de ce jeu.</p>'
      + '<p style="margin:0 0 10px">Elle est enregistr\u00e9e au <strong>niveau maternel</strong> (dans le dossier obst\u00e9trical de la m\u00e8re), '
      + 'cr\u00e9ant un risque de confusion avec la fr\u00e9quence cardiaque propre de la m\u00e8re.</p>'
      + '<p style="margin:0">Je sugg\u00e8re de la d\u00e9placer dans un jeu de concepts d\u00e9di\u00e9.</p>'
      + '</div></div>'
      + '</div></div>'

      + '<p>S\u00e9lectionnez un <strong>statut</strong> (Approuv\u00e9 ou \u00c0 r\u00e9viser), r\u00e9digez vos commentaires en '
      + 'Markdown dans l\u2019\u00e9diteur de gauche avec un aper\u00e7u en direct \u00e0 droite, puis cliquez sur <strong>Soumettre la relecture</strong>.</p>'
      + '<p>Votre relecture est stock\u00e9e dans la session actuelle du navigateur et appara\u00eet dans l\u2019onglet Relecture.</p>'

      // ===== PROPOSER SUR GITHUB =====
      + '<h2>Proposer des modifications sur GitHub</h2>'
      + '<p>Vous pouvez proposer des modifications sur GitHub de deux mani\u00e8res\u00a0:</p>'
      + '<ul>'
      + '<li>Dans l\u2019onglet <strong>Relecture</strong>, apr\u00e8s avoir soumis une relecture, un bouton '
      + '<button class="tab-btn-green" style="cursor:default"><i class="fab fa-github"></i> Proposer sur GitHub</button>'
      + ' appara\u00eet</li>'
      + '<li>Depuis <strong>n\u2019importe quel onglet</strong>, cliquez sur '
      + '<button class="btn-primary-custom" style="cursor:default"><i class="fas fa-download"></i> Exporter</button>'
      + ' et choisissez l\u2019option GitHub</li>'
      + '</ul>'
      + '<p>Dans les deux cas, cliquer sur le bouton\u00a0:</p>'
      + '<ol>'
      + '<li>Copie le JSON complet mis \u00e0 jour dans votre presse-papiers</li>'
      + '<li>Ouvre l\u2019\u00e9diteur GitHub pour ce fichier \u2014 si vous n\u2019avez pas les droits d\u2019\u00e9criture, '
      + 'vous serez invit\u00e9 \u00e0 <strong>forker</strong> le d\u00e9p\u00f4t</li>'
      + '<li>Collez le JSON depuis votre presse-papiers, en rempla\u00e7ant le contenu du fichier</li>'
      + '<li>Committez sur une nouvelle branche et ouvrez une <strong>pull request</strong></li>'
      + '</ol>'

      + infoBox('Pas de compte GitHub\u00a0?',
        'Vous pouvez toujours parcourir et utiliser le dictionnaire localement. Le workflow GitHub n\u2019est n\u00e9cessaire '
        + 'que pour contribuer des modifications \u00e0 la biblioth\u00e8que partag\u00e9e.')

      // ===== QUE POUVEZ-VOUS CONTRIBUER =====
      + '<h2>Que pouvez-vous contribuer\u00a0?</h2>'
      + '<ul>'
      + '<li><strong>Nouveaux jeux de concepts</strong> \u2014 Pour les variables cliniques pas encore couvertes</li>'
      + '<li><strong>Ajout/suppression de concepts</strong> \u2014 Am\u00e9liorer les expressions existantes</li>'
      + '<li><strong>Commentaires d\u2019experts</strong> \u2014 Recommandations cliniques pour l\u2019ETL et le mapping</li>'
      + '<li><strong>Donn\u00e9es statistiques</strong> \u2014 Distributions de r\u00e9f\u00e9rence pour la validation</li>'
      + '<li><strong>Relectures</strong> \u2014 Approuver ou demander la r\u00e9vision de jeux de concepts</li>'
      + '<li><strong>Traductions</strong> \u2014 Am\u00e9liorer ou ajouter des traductions</li>'
      + '<li><strong>Signalement de bugs</strong> \u2014 '
      + '<a href="https://github.com/indicate-eu/data-dictionary/issues" target="_blank">Ouvrir un ticket</a></li>'
      + '</ul>'

      // ===== STRUCTURE DU D\u00c9P\u00d4T =====
      + '<h2>Structure du d\u00e9p\u00f4t</h2>'
      + '<p>Le d\u00e9p\u00f4t <a href="https://github.com/indicate-eu/data-dictionary" target="_blank">'
      + 'indicate-eu/data-dictionary</a> est organis\u00e9 comme suit\u00a0:</p>'
      + '<div class="doc-mock-modal" style="max-width:100%; padding:12px 16px">'
      + '<table style="font-size:12px; font-family:monospace; margin:0; border-collapse:collapse">'
      + '<tr><td style="padding:3px 16px 3px 0; white-space:nowrap; color:var(--primary); font-weight:600; border:none">concept_sets/</td>'
      + '<td style="padding:3px 0; border:none; font-family:inherit; color:var(--text)">Un fichier JSON par jeu de concepts ({id}.json)</td></tr>'
      + '<tr><td style="padding:3px 16px 3px 0; white-space:nowrap; color:var(--primary); font-weight:600; border:none">concept_sets_resolved/</td>'
      + '<td style="padding:3px 0; border:none; font-family:inherit; color:var(--text)">Jeux de concepts r\u00e9solus (g\u00e9n\u00e9r\u00e9s par resolve.py)</td></tr>'
      + '<tr><td style="padding:3px 16px 3px 0; white-space:nowrap; color:var(--primary); font-weight:600; border:none">projects/</td>'
      + '<td style="padding:3px 0; border:none; font-family:inherit; color:var(--text)">Un fichier JSON par projet ({id}.json)</td></tr>'
      + '<tr><td style="padding:3px 16px 3px 0; white-space:nowrap; color:var(--primary); font-weight:600; border:none">mapping_recommendations/</td>'
      + '<td style="padding:3px 0; border:none; font-family:inherit; color:var(--text)">Recommandations de mapping (JSON multilingue)</td></tr>'
      + '<tr><td style="padding:3px 16px 3px 0; white-space:nowrap; color:var(--primary); font-weight:600; border:none">units/</td>'
      + '<td style="padding:3px 0; border:none; font-family:inherit; color:var(--text)">unit_conversions.csv + recommended_units.csv</td></tr>'
      + '<tr><td style="padding:3px 16px 3px 0; white-space:nowrap; color:var(--primary); font-weight:600; border:none">docs/</td>'
      + '<td style="padding:3px 0; border:none; font-family:inherit; color:var(--text)">Site statique GitHub Pages (HTML, JS, CSS, fichiers de donn\u00e9es g\u00e9n\u00e9r\u00e9s)</td></tr>'
      + '<tr><td style="padding:3px 16px 3px 0; white-space:nowrap; color:#e67700; font-weight:600; border:none">build.py</td>'
      + '<td style="padding:3px 0; border:none; font-family:inherit; color:var(--text)">Agr\u00e8ge tous les JSON dans docs/data.json et docs/data_inline.js</td></tr>'
      + '<tr><td style="padding:3px 16px 3px 0; white-space:nowrap; color:#e67700; font-weight:600; border:none">resolve.py</td>'
      + '<td style="padding:3px 0; border:none; font-family:inherit; color:var(--text)">R\u00e9sout les expressions des jeux de concepts avec les vocabulaires OMOP</td></tr>'
      + '</table></div>'

      // ===== PIPELINE DE BUILD =====
      + '<h2>Pipeline de build</h2>'
      + '<p>Deux scripts Python maintiennent les fichiers de donn\u00e9es utilis\u00e9s par l\u2019application web\u00a0:</p>'

      + '<h3>resolve.py</h3>'
      + '<p>R\u00e9sout les expressions des jeux de concepts en \u00e9tendant les descendants et les concepts mapp\u00e9s '
      + 'en utilisant les tables de vocabulaires OMOP stock\u00e9es dans une base DuckDB.</p>'
      + '<div class="doc-mock-modal" style="max-width:100%; padding:12px 16px; font-family:monospace; font-size:12px; white-space:pre-wrap">'
      + 'python3 resolve.py --db /path/to/ohdsi_vocabularies.duckdb\n'
      + '# ou\n'
      + 'python3 resolve.py --csv-dir /path/to/athena_csv_folder'
      + '</div>'
      + '<p>Vous pouvez fournir soit une base DuckDB (<code>--db</code>) soit un dossier de fichiers CSV Athena '
      + '(<code>--csv-dir</code> contenant CONCEPT.csv, CONCEPT_ANCESTOR.csv, CONCEPT_RELATIONSHIP.csv).</p>'
      + '<p>Pour chaque jeu de concepts, il\u00a0:</p>'
      + '<ol>'
      + '<li>Partitionne les \u00e9l\u00e9ments de l\u2019expression en inclus et exclus</li>'
      + '<li>\u00c9tend chaque ensemble avec les descendants et concepts mapp\u00e9s selon la configuration</li>'
      + '<li>Calcule\u00a0: inclus \u2212 exclus</li>'
      + '<li>\u00c9crit le jeu r\u00e9solu dans <code>concept_sets_resolved/{id}.json</code> \u2014 '
      + 'ces fichiers pr\u00e9-calcul\u00e9s permettent de parcourir l\u2019onglet R\u00e9solus sans importer de base de vocabulaires localement</li>'
      + '</ol>'

      + '<h3>build.py</h3>'
      + '<p>Agr\u00e8ge tous les fichiers JSON sources dans les fichiers de donn\u00e9es consomm\u00e9s par le site statique.</p>'
      + '<div class="doc-mock-modal" style="max-width:100%; padding:12px 16px; font-family:monospace; font-size:12px">'
      + 'python3 build.py'
      + '</div>'
      + '<p>Produit\u00a0:</p>'
      + '<ul>'
      + '<li><code>docs/data.json</code> \u2014 JSON compact pour un usage programmatique</li>'
      + '<li><code>docs/data_inline.js</code> \u2014 M\u00eames donn\u00e9es sous forme <code>const DATA={...};</code> pour inclusion directe par script</li>'
      + '</ul>'

      + infoBox('Rebuild complet',
        'Apr\u00e8s modification des fichiers de donn\u00e9es sources, ex\u00e9cutez les deux scripts\u00a0:<br>'
        + '<code style="font-size:12px">python3 resolve.py --db /path/to/vocabularies.duckdb && python3 build.py</code><br>'
        + 'ou avec des fichiers CSV\u00a0:<br>'
        + '<code style="font-size:12px">python3 resolve.py --csv-dir /path/to/athena_csv && python3 build.py</code>')

      // ===== SKILLS CLAUDE CODE =====
      + '<h2>Skills Claude Code</h2>'
      + '<p>Si vous utilisez <a href="https://github.com/anthropics/claude-code" target="_blank">Claude Code</a> '
      + 'pour travailler sur ce d\u00e9p\u00f4t, trois skills (commandes slash) sont disponibles\u00a0:</p>'
      + '<ul>'
      + '<li><code>/resolve-concept-sets</code> \u2014 Ex\u00e9cute resolve.py pour r\u00e9soudre un ou tous les jeux de concepts</li>'
      + '<li><code>/build-catalog</code> \u2014 Ex\u00e9cute build.py pour reg\u00e9n\u00e9rer les fichiers de donn\u00e9es du site statique</li>'
      + '<li><code>/describe-concept-set</code> \u2014 G\u00e9n\u00e8re une description clinique d\u00e9taill\u00e9e pour un jeu de concepts</li>'
      + '</ul>'
      + '<p>Ceux-ci automatisent le pipeline de build et assistent la r\u00e9daction de la documentation.</p>';
  }

  function exportingFR() {
    return '<h1>Exporter</h1>'

      + '<h2>Exporter tous les jeux de concepts</h2>'
      + '<p>Sur la page principale <strong>Dictionnaire de donn\u00e9es</strong> (le datatable listant tous les jeux), cliquez '
      + '<button class="btn-primary-custom" style="cursor:default"><i class="fas fa-download"></i> Exporter</button>'
      + ' pour ouvrir le modal d\u2019export group\u00e9.</p>'
      + mockBulkExportModal('fr')

      + '<h2>Exporter un jeu de concepts</h2>'
      + '<p>Depuis la vue d\u00e9taill\u00e9e d\u2019un jeu, cliquez '
      + '<button class="btn-primary-custom" style="cursor:default"><i class="fas fa-download"></i> Exporter</button>'
      + ' pour ouvrir le modal d\u2019export.</p>'

      + '<h3>\u00c9tape 1\u00a0: Choisir une m\u00e9thode</h3>'
      + mockExportStep1('fr')
      + '<ul>'
      + '<li><strong>T\u00e9l\u00e9charger le fichier JSON OHDSI</strong> \u2014 T\u00e9l\u00e9charge en fichier <code>.json</code></li>'
      + '<li><strong>Copier le JSON OHDSI</strong> \u2014 Copie le JSON dans le presse-papiers</li>'
      + '<li><strong>Proposer sur GitHub</strong> \u2014 Copie et ouvre l\u2019\u00e9diteur GitHub '
      + '(voir ' + docLink('reviewing', 'Relecture & GitHub') + ')</li>'
      + '<li><strong>Copier la requ\u00eate SQL OMOP</strong> \u2014 G\u00e9n\u00e8re une requ\u00eate SQL (voir ci-dessous)</li>'
      + '</ul>'

      + '<h3>\u00c9tape 2\u00a0: Choisir un format</h3>'
      + '<p>Pour T\u00e9l\u00e9charger et Copier\u00a0:</p>'
      + mockExportStep2('fr')
      + '<ul>'
      + '<li><strong><a href="https://ohdsi.github.io/TAB/Concept-Set-Specification.html" target="_blank">Sp\u00e9cification du jeu de concepts</a></strong> \u2014 Format OHDSI complet (format natif du dictionnaire)</li>'
      + '<li><strong>ATLAS</strong> \u2014 Format compatible ATLAS (expression uniquement)</li>'
      + '</ul>'

      + '<h2>Requ\u00eate SQL OMOP</h2>'
      + '<p>L\u2019option <strong>Copier la requ\u00eate SQL OMOP</strong> g\u00e9n\u00e8re une requ\u00eate SQL pour extraire '
      + 'les donn\u00e9es des tables OMOP CDM pour les concepts r\u00e9solus du jeu de concepts actuel.</p>'
      + '<p>La requ\u00eate g\u00e9n\u00e9r\u00e9e\u00a0:</p>'
      + '<ul>'
      + '<li>S\u00e9lectionne dans la table OMOP adapt\u00e9e au domaine du concept '
      + '(measurement, condition_occurrence, drug_exposure, procedure_occurrence, observation, device_exposure)</li>'
      + '<li>Filtre sur les IDs de concepts standards r\u00e9solus</li>'
      + '<li>Inclut les <strong>conversions d\u2019unit\u00e9s</strong> lorsque disponibles \u2014 en utilisant les facteurs de conversion '
      + 'd\u00e9finis dans ' + docLink('dictionary-settings', 'Param\u00e8tres du dictionnaire') + ' (onglet Conversions d\u2019unit\u00e9s), '
      + 'la requ\u00eate convertit les valeurs vers l\u2019<strong>unit\u00e9 recommand\u00e9e</strong> d\u00e9finie dans '
      + 'l\u2019onglet Unit\u00e9s recommand\u00e9es</li>'
      + '</ul>'
      + '<p>Le SQL est copi\u00e9 dans votre presse-papiers et un aper\u00e7u est affich\u00e9 dans le modal.</p>'

      + '<h2>Export projet</h2>'
      + '<p>Depuis la vue d\u00e9taill\u00e9e d\u2019un projet, cliquez '
      + '<button class="btn-primary-custom" style="cursor:default"><i class="fas fa-download"></i> Exporter</button>'
      + ' pour ouvrir le modal d\u2019export\u00a0:</p>'
      + mockGenericExportModal('fr', 'Exporter le projet')
      + '<p>L\u2019onglet Jeux de concepts propose \u00e9galement '
      + '<button class="btn-primary-custom" style="cursor:default"><i class="fas fa-file-csv"></i> Exporter CSV</button>'
      + ' pour t\u00e9l\u00e9charger tous les concepts OMOP des jeux de concepts du projet en CSV, '
      + 'utile pour les pipelines d\u2019analyse.</p>';
  }

  function projectsFR() {
    return '<h1>G\u00e9rer les projets</h1>'
      + '<p>La page <strong>Projets</strong> permet d\u2019organiser les jeux de concepts en projets de recherche. '
      + 'Un projet peut \u00eatre une \u00e9tude clinique, un pipeline de machine learning, un tableau de bord, '
      + 'ou toute initiative data-driven.</p>'

      + '<h2>Liste des projets</h2>'
      + '<p>Les projets sont affich\u00e9s sous forme de cartes montrant le nom, la description, le nombre de jeux de concepts, l\u2019auteur et la date. '
      + 'Utilisez le champ de recherche pour filtrer par nom ou description. Cliquez sur une carte pour ouvrir le projet.</p>'
      + mockProjectCard('fr')

      + '<h2>Cr\u00e9er un projet</h2>'
      + '<p>En mode \u00e9dition, cliquez <strong>Ajouter un projet</strong>. Fournissez un nom et une description courte '
      + '(multilingues, actuellement EN/FR). L\u2019auteur est pr\u00e9-rempli depuis votre profil.</p>'
      + mockNewProjectModal('fr')

      + '<h2>Vue d\u00e9taill\u00e9e du projet</h2>'
      + '<p>Cliquez sur une carte de projet pour ouvrir sa vue d\u00e9taill\u00e9e avec deux onglets\u00a0:</p>'

      + '<h3>Onglet Description</h3>'
      + '<p>Description longue au format Markdown avec aper\u00e7u en direct en mode \u00e9dition. '
      + 'La description est \u00e9dit\u00e9e pour la langue actuellement s\u00e9lectionn\u00e9e.</p>'

      + '<h3>Onglet Jeux de concepts</h3>'
      + '<p>En mode lecture, affiche un tableau triable et filtrable des jeux de concepts du projet. '
      + 'Cliquez sur une ligne pour naviguer vers ce jeu de concepts.</p>'
      + '<p>En mode \u00e9dition, une interface \u00e0 double panneau vous permet de\u00a0:</p>'
      + '<ul>'
      + '<li><strong>Panneau gauche</strong> \u2014 Jeux de concepts disponibles (pas encore dans le projet)</li>'
      + '<li><strong>Panneau droit</strong> \u2014 Jeux de concepts assign\u00e9s au projet</li>'
      + '<li>Utilisez les boutons <i class="fas fa-plus-circle" style="color:var(--success)"></i> et <i class="fas fa-minus-circle" style="color:var(--danger)"></i> pour d\u00e9placer les jeux entre les panneaux</li>'
      + '<li>Filtrez les deux panneaux par cat\u00e9gorie, sous-cat\u00e9gorie ou nom</li>'
      + '</ul>'
      + mockProjectCSEditPanels('fr')

      + infoBox('Bonne pratique',
        'Incluez tous les jeux de concepts n\u00e9cessaires \u00e0 votre analyse, m\u00eame ceux utilis\u00e9s '
        + 'uniquement pour l\u2019ajustement ou la stratification. Cela garantit une collecte compl\u00e8te '
        + 'des donn\u00e9es d\u00e8s le d\u00e9part.')

      + '<h2>Export</h2>'
      + '<p>La vue d\u00e9taill\u00e9e du projet propose deux options d\u2019export\u00a0:</p>'

      + '<h3>Export JSON</h3>'
      + '<p>Cliquez sur le bouton <strong>Export</strong> dans l\u2019en-t\u00eate du projet pour exporter la d\u00e9finition du projet en JSON. '
      + 'Vous pouvez t\u00e9l\u00e9charger le fichier, copier dans le presse-papiers ou proposer des modifications sur GitHub.</p>'
      + mockProjectExportModal('fr')

      + '<h3>Export CSV</h3>'
      + '<p>Dans l\u2019onglet Jeux de concepts (mode lecture), cliquez sur le bouton <strong>CSV</strong> pour t\u00e9l\u00e9charger '
      + 'tous les concepts OMOP des jeux du projet en fichier CSV. L\u2019export inclut les m\u00e9tadonn\u00e9es du jeu '
      + '(ID, nom, cat\u00e9gorie, sous-cat\u00e9gorie) et les options de l\u2019expression (exclu, descendants, mapp\u00e9) pour chaque concept.</p>';
  }

  function mappingFR() {
    return '<h1>Recommandations de mapping</h1>'
      + '<p>La page <strong>Recommandations de mapping</strong> fournit des recommandations expertis\u00e9es '
      + 'pour mapper les variables cliniques locales vers les concepts OMOP standards.</p>'

      + '<h2>Que sont les recommandations de mapping\u00a0?</h2>'
      + '<p>Lors d\u2019un processus ETL pour convertir des donn\u00e9es cliniques locales vers le CDM OMOP, '
      + 'd\u00e9cider comment mapper chaque variable locale vers des concepts standards est l\u2019une des \u00e9tapes '
      + 'les plus complexes. Les recommandations de mapping fournissent des conseils structur\u00e9s pour les '
      + 'variables courantes des bases de donn\u00e9es de r\u00e9animation.</p>'

      + '<h2>Visualisation</h2>'
      + '<p>Le contenu est rendu en Markdown avec mise en forme riche (tableaux, liens, listes).</p>'
      + '<p>Deux boutons sont disponibles en haut \u00e0 droite\u00a0:</p>'
      + mockMappingToolbar('fr')
      + '<ul>'
      + '<li><strong>Export</strong> \u2014 ouvre le modal d\u2019export (voir ci-dessous)</li>'
      + '<li><strong>\u00c9diter</strong> \u2014 passe en mode \u00e9dition pour modifier le contenu</li>'
      + '</ul>'

      + '<h2>\u00c9dition</h2>'
      + '<p>En mode \u00e9dition, un \u00e9diteur ACE avec coloration syntaxique Markdown s\u2019ouvre \u00e0 c\u00f4t\u00e9 d\u2019un panneau d\u2019aper\u00e7u en direct.</p>'
      + '<p>Le contenu est multilingue \u2014 changer de langue sauvegarde le texte actuel et charge l\u2019autre langue.</p>'

      + '<h2>Export</h2>'
      + '<p>Cliquez sur <strong>Export</strong> pour ouvrir le modal d\u2019export\u00a0:</p>'
      + mockMappingExportModal('fr')
      + '<ul>'
      + '<li><strong>T\u00e9l\u00e9charger</strong> \u2014 t\u00e9l\u00e9charge <code>mapping_recommendations.json</code>, \u00e0 placer dans le dossier <code>mapping_recommendations/</code> du d\u00e9p\u00f4t Git</li>'
      + '<li><strong>Copier</strong> \u2014 copie le contenu JSON dans le presse-papiers</li>'
      + '<li><strong>Proposer sur GitHub</strong> \u2014 copie dans le presse-papiers et ouvre l\u2019\u00e9diteur GitHub pour proposer des modifications via une pull request</li>'
      + '</ul>';
  }

  function devToolsFR() {
    return '<h1>Outils de d\u00e9veloppement</h1>'
      + '<p>Acc\u00e8s via le bouton Param\u00e8tres (engrenage) en haut \u00e0 droite du header \u2192 Outils de d\u00e9veloppement.</p>'
      + '<p>La page Dev Tools fournit des fonctionnalit\u00e9s avanc\u00e9es pour les d\u00e9veloppeurs.</p>'

      + '<h2>\u00c9diteur SQL</h2>'
      + '<p>Interrogez directement la base de vocabulaires OHDSI en SQL.</p>'
      + '<p>Un menu d\u00e9roulant propose des requ\u00eates d\u2019exemple pr\u00e9construites.</p>'
      + '<p>Les r\u00e9sultats s\u2019affichent dans un datatable avec export CSV possible.</p>'
      + mockSqlEditor('fr')

      + '<h2>Sch\u00e9ma / ERD</h2>'
      + '<p>Visualisez le sch\u00e9ma de la base et le diagramme entit\u00e9-relation des tables de vocabulaires.</p>';
  }

  function localDataFR() {
    return '<h1>Donn\u00e9es locales</h1>'
      + '<p>Le Dictionnaire de Donn\u00e9es INDICATE est une <strong>application enti\u00e8rement c\u00f4t\u00e9 client</strong>. '
      + 'Toutes les donn\u00e9es sont stock\u00e9es localement dans votre navigateur \u2014 rien n\u2019est envoy\u00e9 vers un serveur.</p>'

      + '<h2>Fonctionnement</h2>'
      + '<p>L\u2019application utilise deux m\u00e9canismes de stockage du navigateur\u00a0:</p>'
      + '<ul>'
      + '<li><strong>localStorage</strong> \u2014 stocke les jeux de concepts, projets, recommandations de mapping, '
      + 'conversions d\u2019unit\u00e9s, unit\u00e9s recommand\u00e9es, profil utilisateur, relectures et pr\u00e9f\u00e9rences de langue. '
      + 'Toutes vos modifications (ajout, modification, suppression) sont sauvegard\u00e9es ici.</li>'
      + '<li><strong>IndexedDB</strong> \u2014 stocke la base de vocabulaires OHDSI, propuls\u00e9e par '
      + '<a href="https://duckdb.org/docs/api/wasm/overview" target="_blank">DuckDB-WASM</a>. '
      + 'C\u2019est une base SQL compl\u00e8te fonctionnant enti\u00e8rement dans votre navigateur, permettant la recherche de concepts, '
      + 'la visualisation hi\u00e9rarchique et la r\u00e9solution d\u2019expressions sans aucun serveur.</li>'
      + '</ul>'
      + '<p>Vos donn\u00e9es persistent entre les sessions et les red\u00e9marrages du navigateur.</p>'

      + '<h2>Mises \u00e0 jour des donn\u00e9es</h2>'
      + '<p>Quand l\u2019application est d\u00e9ploy\u00e9e sur GitHub Pages, les donn\u00e9es sources (jeux de concepts, projets, etc.) '
      + 'peuvent \u00eatre mises \u00e0 jour par les contributeurs via des pull requests.</p>'
      + '<p>Lorsque vous visitez l\u2019application et que de nouvelles donn\u00e9es sont disponibles, un modal appara\u00eet\u00a0:</p>'
      + mockDataUpdateModal('fr')
      + '<ul>'
      + '<li><strong>Appliquer</strong> \u2014 fusionne les mises \u00e0 jour distantes dans vos donn\u00e9es locales. '
      + 'Si vous avez des modifications locales sur les m\u00eames jeux de concepts, le modal met en \u00e9vidence les conflits '
      + 'et vous laisse choisir entre votre version locale et la version distante pour chacun.</li>'
      + '<li><strong>Plus tard</strong> \u2014 ferme le modal et conserve vos donn\u00e9es locales inchang\u00e9es. '
      + 'Le message r\u00e9appara\u00eetra lors de votre prochaine visite.</li>'
      + '</ul>'

      + '<h2>R\u00e9initialiser les donn\u00e9es locales</h2>'
      + '<p>Pour supprimer toutes les modifications locales et repartir avec la derni\u00e8re version d\u00e9ploy\u00e9e, '
      + 'ouvrez le menu Param\u00e8tres (engrenage, en haut \u00e0 droite du header) et cliquez sur <strong>R\u00e9initialiser les donn\u00e9es locales</strong>\u00a0:</p>'
      + mockSettingsDropdown('fr')
      + '<p>Cela efface toutes les donn\u00e9es localStorage (jeux de concepts, projets, relectures, profil, pr\u00e9f\u00e9rences) '
      + 'et recharge l\u2019application avec les donn\u00e9es originales de GitHub Pages.</p>'

      + infoBox('Attention',
        'La r\u00e9initialisation est irr\u00e9versible. '
        + 'Assurez-vous d\u2019<strong>exporter</strong> tout travail que vous souhaitez conserver avant de r\u00e9initialiser. '
        + 'Voir ' + docLink('exporting', 'Exporter') + ' et '
        + docLink('reviewing', 'Relecture & GitHub') + '.', 'warning')

      + '<h2>Base de vocabulaires OHDSI</h2>'
      + '<p>La base de vocabulaires stock\u00e9e dans IndexedDB est ind\u00e9pendante de l\u2019action R\u00e9initialiser les donn\u00e9es locales. '
      + 'Pour la g\u00e9rer, utilisez l\u2019onglet <strong>Vocabulaires OHDSI</strong> dans '
      + docLink('dictionary-settings', 'Param\u00e8tres du dictionnaire') + '.</p>';
  }

  function dictSettingsFR() {
    return '<h1>Param\u00e8tres du dictionnaire</h1>'
      + '<p>Acc\u00e8s via le bouton Param\u00e8tres (engrenage) en haut \u00e0 droite du header \u2192 Param\u00e8tres du dictionnaire.</p>'
      + '<p>La page comporte trois onglets\u00a0:</p>'
      + '<ul>'
      + '<li><strong>Vocabulaires OHDSI</strong> \u2014 importer et g\u00e9rer la base de vocabulaires locale</li>'
      + '<li><strong>Conversions d\u2019unit\u00e9s</strong> \u2014 facteurs de conversion entre unit\u00e9s de mesure</li>'
      + '<li><strong>Unit\u00e9s recommand\u00e9es</strong> \u2014 unit\u00e9 recommand\u00e9e par concept de mesure</li>'
      + '</ul>'

      + '<h2>Vocabulaires OHDSI</h2>'
      + '<p>L\u2019application peut importer des fichiers de vocabulaires OHDSI dans une <strong>base DuckDB '
      + 'qui fonctionne enti\u00e8rement dans votre navigateur</strong>. Cela permet des fonctionnalit\u00e9s '
      + 'avanc\u00e9es sans n\u00e9cessiter de serveur.</p>'

      + '<h3>Ce que \u00e7a permet</h3>'
      + '<ul>'
      + '<li><strong>Recherche de concepts</strong> \u2014 par nom, ID ou code lors de l\u2019ajout de concepts aux expressions</li>'
      + '<li><strong>R\u00e9solution en direct</strong> \u2014 expansion des descendants et concepts mapp\u00e9s en temps r\u00e9el</li>'
      + '<li><strong>Graphe hi\u00e9rarchique</strong> \u2014 visualisation interactive des relations entre concepts</li>'
      + '<li><strong>Optimisation</strong> \u2014 simplification des expressions par analyse hi\u00e9rarchique</li>'
      + '<li><strong>Requ\u00eates SQL</strong> \u2014 \u00e9diteur SQL dans les Outils de d\u00e9veloppement</li>'
      + '</ul>'

      + '<h3>Comment importer</h3>'
      + '<ol>'
      + '<li>T\u00e9l\u00e9chargez les vocabulaires depuis <a href="https://athena.ohdsi.org/vocabulary/list" target="_blank">ATHENA</a> (format CSV ou Parquet)</li>'
      + '<li>Allez dans <strong>Param\u00e8tres</strong> (engrenage) \u2192 <strong>Param\u00e8tres du dictionnaire</strong> \u2192 onglet <strong>Vocabulaires OHDSI</strong></li>'
      + '<li>Cliquez <strong>S\u00e9lectionner le dossier</strong> et choisissez le dossier contenant les fichiers</li>'
      + '<li>Attendez la fin de l\u2019import \u2014 une barre de progression indique l\u2019\u00e9tat</li>'
      + '</ol>'
      + '<p>L\u2019import lit CONCEPT.csv, CONCEPT_RELATIONSHIP.csv, CONCEPT_ANCESTOR.csv et les fichiers associ\u00e9s, '
      + 'les indexe dans DuckDB et sauvegarde la base dans le stockage du navigateur.</p>'

      + '<h3>R\u00e9importer et supprimer</h3>'
      + '<p>Pour mettre \u00e0 jour la base apr\u00e8s avoir t\u00e9l\u00e9charg\u00e9 de nouveaux fichiers, '
      + 'supprimez la base existante puis r\u00e9importez en s\u00e9lectionnant \u00e0 nouveau le dossier.</p>'
      + '<ul>'
      + '<li><strong>Delete Database</strong> \u2014 supprime enti\u00e8rement la base locale</li>'
      + '<li><strong>Select Vocabulary Folder</strong> \u2014 r\u00e9importer depuis le dossier de vocabulaires</li>'
      + '</ul>'

      + '<h2>Conversions d\u2019unit\u00e9s</h2>'
      + '<p>G\u00e9rez les facteurs de conversion entre unit\u00e9s de mesure.</p>'
      + '<p>Le tableau affiche les concepts source et cible avec leurs unit\u00e9s et facteurs de conversion.</p>'
      + '<p>Utilisez les filtres de colonnes pour rechercher dans chaque colonne.</p>'

      + '<h3>Actions</h3>'
      + '<ul>'
      + '<li><strong>Ajouter une conversion</strong> \u2014 cr\u00e9er une conversion avec concepts source/cible, unit\u00e9s et facteur. '
      + 'Le formulaire d\u2019ajout sera am\u00e9lior\u00e9 dans une future version avec un datatable de recherche de concepts.</li>'
      + '<li><strong>Modifier le facteur</strong> \u2014 cliquez sur la cellule du facteur pour l\u2019\u00e9diter en ligne</li>'
      + '<li><strong>Tester</strong> \u2014 ouvrir une calculatrice pour v\u00e9rifier la conversion (inversion bidirectionnelle)</li>'
      + '<li><strong>Supprimer</strong> \u2014 supprimer une conversion avec confirmation</li>'
      + '</ul>'

      + '<h3>Export</h3>'
      + '<p>Cliquez sur <strong>Export</strong> pour ouvrir le modal d\u2019export\u00a0:</p>'
      + mockSettingsExportModal('fr', 'Export')

      + '<h2>Unit\u00e9s recommand\u00e9es</h2>'
      + '<p>D\u00e9finissez l\u2019unit\u00e9 recommand\u00e9e pour chaque concept de mesure.</p>'
      + '<p>Ceci garantit un usage coh\u00e9rent des unit\u00e9s dans le dictionnaire et est utilis\u00e9 '
      + 'pour les conversions automatiques lors de l\u2019export SQL des jeux de concepts.</p>'
      + '<p>Utilisez les filtres de colonnes pour rechercher dans chaque colonne.</p>'

      + '<h3>Actions</h3>'
      + '<ul>'
      + '<li><strong>Ajouter une unit\u00e9 recommand\u00e9e</strong> \u2014 associer un concept \u00e0 son unit\u00e9 recommand\u00e9e (ID, nom, code). '
      + 'Le formulaire d\u2019ajout sera am\u00e9lior\u00e9 dans une future version avec un datatable de recherche de concepts.</li>'
      + '<li><strong>Supprimer</strong> \u2014 supprimer une recommandation avec confirmation</li>'
      + '</ul>'

      + '<h3>Export</h3>'
      + '<p>Cliquez sur <strong>Export</strong> pour ouvrir le modal d\u2019export\u00a0:</p>'
      + mockSettingsExportModal('fr', 'Export')

      + infoBox('Enrichissement des vocabulaires',
        'Lorsqu\u2019une base de vocabulaires OHDSI est charg\u00e9e, les noms de concepts des deux tableaux sont '
        + 'automatiquement r\u00e9solus depuis la base. Si la base n\u2019est pas encore pr\u00eate \u00e0 l\u2019ouverture '
        + 'd\u2019un onglet, l\u2019application r\u00e9essaie automatiquement.');
  }

  // ==================== RENDERING ====================

  function renderSidebar() {
    var secs = sections();
    var dev = isDev();
    var html = '';
    for (var i = 0; i < secs.length; i++) {
      var sec = secs[i];
      html += '<div class="doc-sidebar-section">';
      html += '<div class="doc-sidebar-title">' + App.escapeHtml(sec.title) + '</div>';
      html += '<ul class="doc-sidebar-nav">';
      for (var j = 0; j < sec.items.length; j++) {
        var item = sec.items[j];
        var cls = item.id === currentSection ? 'active' : '';
        if (item.draft && !dev) cls += (cls ? ' ' : '') + 'doc-draft';
        var clsAttr = cls ? ' class="' + cls + '"' : '';
        html += '<li><a href="#/documentation?section=' + item.id + '"' + clsAttr + ' data-doc-section="' + item.id + '">'
          + App.escapeHtml(item.label)
          + (item.draft && dev ? ' <span class="doc-draft-badge">draft</span>' : '')
          + '</a></li>';
      }
      html += '</ul></div>';
    }
    document.getElementById('doc-sidebar').innerHTML = html;
  }

  function isSectionDraft(sectionId) {
    var secs = sections();
    for (var i = 0; i < secs.length; i++) {
      for (var j = 0; j < secs[i].items.length; j++) {
        if (secs[i].items[j].id === sectionId) return !!secs[i].items[j].draft;
      }
    }
    return false;
  }

  function draftPlaceholder() {
    var en = App.lang === 'en';
    return '<div class="doc-draft-placeholder">'
      + '<i class="fas fa-hard-hat"></i>'
      + '<h2>' + (en ? 'Under Construction' : 'En construction') + '</h2>'
      + '<p>' + (en
        ? 'This section is currently being written. Check back soon!'
        : 'Cette section est en cours de r\u00e9daction. Revenez bient\u00f4t\u00a0!')
      + '</p></div>';
  }

  function renderContent() {
    var c = content();
    var section = c[currentSection];
    if (!section) {
      currentSection = 'introduction';
      section = c['introduction'];
    }
    _docSqlEditor = null;
    if (!isDev() && isSectionDraft(currentSection)) {
      document.getElementById('doc-content-inner').innerHTML = draftPlaceholder();
    } else {
      document.getElementById('doc-content-inner').innerHTML = section;
    }
    setTimeout(initDocSqlEditor, 50);
  }

  function renderToc() {
    var container = document.getElementById('doc-content-inner');
    var tocEl = document.getElementById('doc-toc');
    if (!container || !tocEl) return;
    var allHeadings = container.querySelectorAll('h2, h3, h4');
    // Exclude headings inside UI mocks
    var headings = [];
    for (var k = 0; k < allHeadings.length; k++) {
      if (!allHeadings[k].closest('.doc-mock-modal, .doc-mock-table, .doc-feature-card, .doc-audience-card, .project-card')) headings.push(allHeadings[k]);
    }
    if (headings.length === 0) { tocEl.innerHTML = ''; return; }

    // Assign IDs to headings that don't have one
    for (var i = 0; i < headings.length; i++) {
      if (!headings[i].id) {
        headings[i].id = 'doc-heading-' + i;
      }
    }

    var en = App.lang === 'en';
    var html = '<div class="doc-toc-title">' + (en ? 'On this page' : 'Sur cette page') + '</div><ul>';
    for (var j = 0; j < headings.length; j++) {
      var h = headings[j];
      var level = h.tagName.toLowerCase();
      html += '<li class="toc-' + level + '"><a href="javascript:void(0)" data-toc-target="' + h.id + '">'
        + h.textContent + '</a></li>';
    }
    html += '</ul>';
    tocEl.innerHTML = html;
  }

  var tocScrollHandler = null;

  function setupTocScroll() {
    var contentEl = document.getElementById('doc-content');
    var tocEl = document.getElementById('doc-toc');
    if (!contentEl || !tocEl) return;

    // Remove previous handler
    if (tocScrollHandler) contentEl.removeEventListener('scroll', tocScrollHandler);

    var allH = document.getElementById('doc-content-inner').querySelectorAll('h2, h3, h4');
    var headings = [];
    for (var m = 0; m < allH.length; m++) {
      if (!allH[m].closest('.doc-mock-modal, .doc-mock-table')) headings.push(allH[m]);
    }
    if (headings.length === 0) return;

    tocScrollHandler = function() {
      var scrollTop = contentEl.scrollTop;
      var viewBottom = scrollTop + contentEl.clientHeight;
      var containerTop = contentEl.offsetTop;
      var links = tocEl.querySelectorAll('a[data-toc-target]');

      for (var j = 0; j < links.length; j++) {
        var hIdx = -1;
        var targetId = links[j].getAttribute('data-toc-target');
        for (var k = 0; k < headings.length; k++) {
          if (headings[k].id === targetId) { hIdx = k; break; }
        }
        if (hIdx === -1) { links[j].classList.remove('active'); continue; }

        // Section starts at this heading, ends at the next heading (or end of content)
        var sectionTop = headings[hIdx].offsetTop - containerTop;
        var sectionBottom = (hIdx + 1 < headings.length)
          ? headings[hIdx + 1].offsetTop - containerTop
          : contentEl.scrollHeight;

        // Section is visible if it overlaps the viewport
        var visible = sectionBottom > scrollTop && sectionTop < viewBottom;
        links[j].classList.toggle('active', visible);
      }
    };

    contentEl.addEventListener('scroll', tocScrollHandler, { passive: true });
    tocScrollHandler(); // initial highlight
  }

  function renderAll() {
    renderSidebar();
    renderContent();
    renderToc();
    setupTocScroll();
  }

  // ==================== EVENTS ====================

  function initEvents() {
    // TOC clicks scroll to heading
    document.getElementById('doc-toc').addEventListener('click', function(e) {
      var link = e.target.closest('[data-toc-target]');
      if (!link) return;
      e.preventDefault();
      var target = document.getElementById(link.getAttribute('data-toc-target'));
      if (target) target.scrollIntoView({ behavior: 'smooth', block: 'start' });
    });
  }

  function navigateTo(id) {
    Router.navigate('/documentation', { section: id });
  }

  // ==================== LIFECYCLE ====================

  function init() {
    if (initialized) return;
    initialized = true;
    initEvents();
  }

  function show(query) {
    init();
    var newSection = (query && query.section) || 'introduction';
    var changed = newSection !== currentSection;
    currentSection = newSection;
    renderAll();
    if (changed) {
      var el = document.getElementById('doc-content');
      if (el) el.scrollTop = 0;
    }
  }

  function hide() {}

  function onLanguageChange() {
    if (!initialized) return;
    renderAll();
  }

  var _hierarchyGraphs = {};

  function _initHierarchyGraph(prefix) {
    var containerId = prefix + '-hierarchy-graph';
    if (_hierarchyGraphs[containerId]) return;
    var container = document.getElementById(containerId);
    if (!container || typeof vis === 'undefined') return;

    var nodes = new vis.DataSet([
      { id: 1003106, label: 'General heart rate\n[LOINC]', color: { background: '#6c757d', border: '#555' }, font: { color: '#fff', size: 11 }, widthConstraint: { minimum: 140, maximum: 220 } },
      { id: 1003302, label: 'Specific heart rate\n[LOINC]', color: { background: '#6c757d', border: '#555' }, font: { color: '#fff', size: 11 }, widthConstraint: { minimum: 140, maximum: 220 } },
      { id: 1004124, label: 'Heart rate taken in\nspecific position\n[LOINC]', color: { background: '#6c757d', border: '#555' }, font: { color: '#fff', size: 11 }, widthConstraint: { minimum: 140, maximum: 220 } },
      { id: 45876230, label: 'Heart rate\npositional molecular\n[LOINC]', color: { background: '#6c757d', border: '#555' }, font: { color: '#fff', size: 11 }, widthConstraint: { minimum: 140, maximum: 220 } },
      { id: 36303943, label: 'Heart rate --W exercise\n[LOINC]', color: { background: '#0f60af', border: '#0a4a8a' }, font: { color: '#fff', size: 12 }, widthConstraint: { minimum: 140, maximum: 220 } }
    ]);
    var edges = new vis.DataSet([
      { from: 1003106, to: 1003302, arrows: 'to', color: { color: '#ccc' } },
      { from: 1003302, to: 1004124, arrows: 'to', color: { color: '#ccc' } },
      { from: 1003302, to: 45876230, arrows: 'to', color: { color: '#ccc' } },
      { from: 1004124, to: 36303943, arrows: 'to', color: { color: '#ccc' } },
      { from: 45876230, to: 36303943, arrows: 'to', color: { color: '#ccc' } }
    ]);

    _hierarchyGraphs[containerId] = new vis.Network(container, { nodes: nodes, edges: edges }, {
      layout: { hierarchical: { direction: 'UD', sortMethod: 'directed', levelSeparation: 70, nodeSpacing: 200 } },
      nodes: { shape: 'box', borderWidth: 1, margin: 10, shadow: false },
      edges: { smooth: { type: 'cubicBezier' }, color: { color: '#ccc', highlight: '#0f60af' } },
      physics: false,
      interaction: { dragNodes: false, zoomView: true, dragView: true }
    });
  }

  function _switchVtab(prefix, tab) {
    var tabs = document.querySelectorAll('#' + prefix + '-tabs .concept-vocab-tab');
    for (var i = 0; i < tabs.length; i++) {
      tabs[i].classList.toggle('active', tabs[i].getAttribute('data-vtab') === tab);
    }
    ['related', 'hierarchy', 'synonyms'].forEach(function(n) {
      var el = document.getElementById(prefix + '-' + n);
      if (el) el.style.display = (n === tab) ? '' : 'none';
    });
    if (tab === 'hierarchy') {
      setTimeout(function() { _initHierarchyGraph(prefix); }, 50);
    }
  }

  return {
    show: show,
    hide: hide,
    onLanguageChange: onLanguageChange,
    navigateTo: navigateTo,
    _switchVtab: _switchVtab
  };
})();

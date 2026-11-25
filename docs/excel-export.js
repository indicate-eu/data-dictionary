/**
 * Excel export of a project — the readable counterpart of the CSV export.
 *
 * One workbook, four sheets:
 *   - Concept sets     one row per concept set, at the version the project pins
 *                      (same columns as the project's Concept Sets tab, plus the
 *                      version date, its change note and a link back to the app).
 *                      Each name links to the first row of its concepts.
 *   - Concepts         the resolved OMOP concepts of every concept set (what the
 *                      concept set detail view lists), with a filter on every
 *                      column: picking one concept set in the "Concept set"
 *                      filter shows its concepts only.
 *   - Version history  every version of each concept set, most recent first,
 *                      flagging the ones newer than the pinned version.
 *   - About            project, export date, dictionary build, vocabulary
 *                      release, and how to read the file.
 *
 * Unlike the CSV (the expression items, for tooling), this lists resolved
 * concepts: descendants and mapped concepts expanded, exclusions removed — the
 * list a data provider maps its source data to.
 *
 * ExcelJS (~1 MB) is loaded from the CDN on first use only, so the page itself
 * carries no extra weight.
 */
var ExcelExport = (function() {
  'use strict';

  var EXCELJS_URL = 'https://cdn.jsdelivr.net/npm/exceljs@4.4.0/dist/exceljs.min.js';
  var EXCELJS_SRI = 'sha384-Pqp51FUN2/qzfxZxBCtF0stpc9ONI6MYZpVqmo8m20SoaQCzf+arZvACkLkirlPz';

  var HEADER_FILL = 'FF0F60AF';   // --primary
  var HEADER_FONT = 'FFFFFFFF';
  var LINK_FONT = 'FF0F60AF';
  var OUTDATED = { bg: 'FFFEF3C7', fg: 'FF92400E' };
  var UP_TO_DATE = { bg: 'FFDCFCE7', fg: 'FF166534' };

  // Workbook-only labels. Kept here rather than in App's I18N table: they only
  // make sense inside the file.
  var L = {
    sheetConceptSets:  { en: 'Concept sets',        fr: 'Jeux de concepts' },
    sheetConcepts:     { en: 'Concepts',            fr: 'Concepts' },
    sheetVersions:     { en: 'Version history',     fr: 'Historique des versions' },
    sheetAbout:        { en: 'About',               fr: 'À propos' },
    id:                { en: 'ID',                  fr: 'ID' },
    group:             { en: 'Group',               fr: 'Groupe' },
    groupRule:         { en: 'Group rule',          fr: 'Règle du groupe' },
    category:          { en: 'Category',            fr: 'Catégorie' },
    subcategory:       { en: 'Subcategory',         fr: 'Sous-catégorie' },
    name:              { en: 'Name',                fr: 'Nom' },
    description:       { en: 'Description',         fr: 'Description' },
    reviewStatus:      { en: 'Review status',       fr: 'Statut de relecture' },
    pinnedVersion:     { en: 'Pinned version',      fr: 'Version épinglée' },
    latestVersion:     { en: 'Latest version',      fr: 'Dernière version' },
    update:            { en: 'Update',              fr: 'Mise à jour' },
    upToDate:          { en: 'Up to date',          fr: 'À jour' },
    outdated:          { en: 'Newer version available', fr: 'Nouvelle version disponible' },
    noVersion:         { en: 'No version',          fr: 'Sans version' },
    nConcepts:         { en: 'Concepts',            fr: 'Concepts' },
    versionDate:       { en: 'Version date',        fr: 'Date de la version' },
    changeNote:        { en: 'Change note',         fr: 'Note de version' },
    link:              { en: 'Link',                fr: 'Lien' },
    openInApp:         { en: 'Open in the app',     fr: 'Ouvrir dans l’application' },
    conceptSetId:      { en: 'Concept set ID',      fr: 'ID du jeu' },
    conceptSet:        { en: 'Concept set',         fr: 'Jeu de concepts' },
    version:           { en: 'Version',             fr: 'Version' },
    vocabulary:        { en: 'Vocabulary',          fr: 'Vocabulaire' },
    conceptId:         { en: 'Concept ID',          fr: 'ID du concept' },
    conceptName:       { en: 'Concept name',        fr: 'Nom du concept' },
    conceptCode:       { en: 'Concept code',        fr: 'Code du concept' },
    domain:            { en: 'Domain',              fr: 'Domaine' },
    conceptClass:      { en: 'Concept class',       fr: 'Classe du concept' },
    standard:          { en: 'Standard',            fr: 'Standard' },
    recommendedUnit:   { en: 'Recommended unit',    fr: 'Unité recommandée' },
    athena:            { en: 'Athena',              fr: 'Athena' },
    date:              { en: 'Date',                fr: 'Date' },
    author:            { en: 'Author',              fr: 'Auteur' },
    message:           { en: 'Message',             fr: 'Message' },
    inProject:         { en: 'In this project',     fr: 'Dans ce projet' },
    pinned:            { en: 'Pinned',              fr: 'Épinglée' },
    newer:             { en: 'Newer, not adopted yet', fr: 'Plus récente, pas encore adoptée' },
    unavailable:       { en: 'Concept list unavailable for this version', fr: 'Liste de concepts indisponible pour cette version' },
    project:           { en: 'Project',             fr: 'Projet' },
    projectModified:   { en: 'Project last modified', fr: 'Dernière modification du projet' },
    exportedOn:        { en: 'Exported on',         fr: 'Exporté le' },
    dictionaryBuild:   { en: 'Dictionary build',    fr: 'Version du dictionnaire' },
    vocabRelease:      { en: 'OMOP vocabulary release', fr: 'Version des vocabulaires OMOP' },
    nConceptSets:      { en: 'Concept sets',        fr: 'Jeux de concepts' },
    nOutdated:         { en: 'with a newer version', fr: 'avec une version plus récente' },
    howToRead:         { en: 'How to read this file', fr: 'Comment lire ce fichier' },
    howConceptSets:    {
      en: 'One row per concept set, at the version this project pins. Click a name to jump to its concepts. "Update" tells whether a newer version exists in the dictionary.',
      fr: 'Une ligne par jeu de concepts, à la version épinglée par ce projet. Cliquez sur un nom pour aller à ses concepts. « Mise à jour » indique si une version plus récente existe dans le dictionnaire.'
    },
    howConcepts:       {
      en: 'The resolved OMOP concepts of each concept set: descendants and mapped concepts expanded, exclusions removed. This is the list to map your source data to. To see a single concept set, use the filter arrow of the "Concept set" column.',
      fr: 'Les concepts OMOP résolus de chaque jeu : descendants et concepts mappés développés, exclusions retirées. C’est la liste sur laquelle aligner vos données sources. Pour n’afficher qu’un jeu, utilisez la flèche de filtre de la colonne « Jeu de concepts ».'
    },
    howVersions:       {
      en: 'Every version of each concept set, most recent first, with its change note. Rows marked "Newer, not adopted yet" are changes this project has not pinned.',
      fr: 'Toutes les versions de chaque jeu de concepts, de la plus récente à la plus ancienne, avec leur note de version. Les lignes « Plus récente, pas encore adoptée » sont des changements que ce projet n’a pas encore épinglés.'
    }
  };
  function l(key) {
    var e = L[key];
    return (e && (e[App.lang] || e.en)) || key;
  }

  // ==================== LIBRARY LOADING ====================
  var loading = null;
  function loadExcelJS() {
    if (window.ExcelJS) return Promise.resolve(window.ExcelJS);
    if (loading) return loading;
    loading = new Promise(function(resolve, reject) {
      var s = document.createElement('script');
      s.src = EXCELJS_URL;
      s.integrity = EXCELJS_SRI;
      s.crossOrigin = 'anonymous';
      s.onload = function() {
        if (window.ExcelJS) resolve(window.ExcelJS);
        else { loading = null; reject(new Error('ExcelJS did not register')); }
      };
      s.onerror = function() {
        loading = null;
        s.remove();
        reject(new Error('Could not load ' + EXCELJS_URL));
      };
      document.head.appendChild(s);
    });
    return loading;
  }

  // ==================== DATA ====================

  // Resolved lists of the latest versions above the inline threshold are lazy;
  // past pinned versions are fetched from the repository. Load both before
  // reading anything synchronously.
  function preload(project) {
    var jobs = [App.fetchPinnedVersions(project)];
    App.getProjectConceptSetEntries(project).forEach(function(e) {
      var latest = App.getLatestVersion(e.id);
      if ((!e.version || e.version === latest) && App.resolvedDeferred[e.id]) {
        jobs.push(App.fetchResolved(e.id));
      }
    });
    return Promise.all(jobs);
  }

  function versionEntry(cs, version) {
    var list = (cs && cs.metadata && cs.metadata.versions) || [];
    for (var i = 0; i < list.length; i++) {
      if (list[i].version === version) return list[i];
    }
    return null;
  }

  function appUrl(hashPath) {
    return window.location.origin + window.location.pathname + hashPath;
  }

  function collect(project, ruleLabel) {
    var unitByConcept = {};
    (App.recommendedUnits || []).forEach(function(ru) {
      if (ru.recommendedUnitCode) unitByConcept[ru.conceptId] = ru.recommendedUnitCode;
    });

    var sets = [];
    App.getProjectGroups(project).forEach(function(g) {
      var groupName = App.getGroupName(g) || '';
      var rule = g.rule || '';
      var inGroup = [];
      (g.conceptSets || []).forEach(function(e) {
        var live = App.getConceptSet(e.id);
        var pinned = e.version || '';
        // A pinned version that cannot be reached (never snapshotted, or the
        // fetch failed) still gets its row, described from the latest version,
        // so the concept set does not silently drop out of the file.
        var cs = App.getConceptSet(e.id, pinned || undefined);
        var resolved = cs ? App.getResolvedConceptSet(e.id, pinned || undefined) : null;
        var src = cs || live;
        if (!src) return;
        var tr = App.t(src);
        var latest = App.getLatestVersion(e.id);
        var ver = versionEntry(src, pinned || src.version);
        inGroup.push({
          id: e.id,
          groupName: groupName,
          groupRule: rule ? ruleLabel(rule) : '',
          category: tr.category || '',
          subcategory: tr.subcategory || '',
          name: tr.name || src.name || '',
          description: tr.shortDescription || '',
          reviewStatus: (src.metadata && src.metadata.reviewStatus) || 'draft',
          pinnedVersion: pinned,
          latestVersion: latest,
          versionStatus: !pinned ? 'noVersion' : (latest && pinned !== latest ? 'outdated' : 'upToDate'),
          versionDate: (ver && ver.date) || src.modifiedDate || '',
          changeNote: plain(ver && ver.message),
          url: appUrl('#/concept-sets?id=' + e.id + (pinned ? '&version=' + encodeURIComponent(pinned) : '')),
          resolved: resolved,
          live: live,
          unitByConcept: unitByConcept
        });
      });
      inGroup.sort(function(a, b) {
        return a.category.localeCompare(b.category) ||
          a.subcategory.localeCompare(b.subcategory) ||
          a.name.localeCompare(b.name);
      });
      sets = sets.concat(inGroup);
    });
    return sets;
  }

  // ==================== WORKBOOK ====================

  function argb(color) {
    if (typeof color !== 'string') return null;
    var m = /^#([0-9a-f]{3}|[0-9a-f]{6})$/i.exec(color.trim());
    if (!m) return null;
    var h = m[1];
    if (h.length === 3) h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2];
    return 'FF' + h.toUpperCase();
  }

  function paint(cell, bg, fg) {
    if (bg) cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: bg } };
    if (fg) cell.font = Object.assign({}, cell.font || {}, { color: { argb: fg } });
  }

  // columns: [{ key, header, width, wrap }]
  function setupTable(ws, columns) {
    ws.views = [{ state: 'frozen', ySplit: 1 }];
    ws.columns = columns.map(function(c) {
      return { key: c.key, header: c.header, width: c.width || 14,
        style: c.wrap ? { alignment: { wrapText: true, vertical: 'top' } } : { alignment: { vertical: 'top' } } };
    });
    var head = ws.getRow(1);
    head.eachCell(function(cell) {
      cell.font = { bold: true, color: { argb: HEADER_FONT } };
      cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: HEADER_FILL } };
      cell.alignment = { vertical: 'middle', wrapText: true };
    });
    head.height = 30;
    return ws;
  }

  function finishTable(ws, nCols) {
    if (ws.rowCount > 1) {
      ws.autoFilter = { from: { row: 1, column: 1 }, to: { row: ws.rowCount, column: nCols } };
    }
  }

  // Change notes are written in Markdown; a spreadsheet cell shows it raw.
  // Drop the emphasis and code markers, keep line breaks and "- " bullets.
  function plain(md) {
    return String(md || '')
      .replace(/\*\*([^*]+)\*\*/g, '$1')
      .replace(/__([^_]+)__/g, '$1')
      .replace(/`([^`]+)`/g, '$1')
      .replace(/\[([^\]]+)\]\(([^)]+)\)/g, '$1 ($2)')
      .replace(/\n{3,}/g, '\n\n')
      .trim();
  }

  function link(text, target) {
    return { text: text, hyperlink: target };
  }

  // Link to a cell of this workbook. A HYPERLINK formula rather than a
  // { hyperlink } value: ExcelJS writes the latter with an external
  // relationship next to its location, which Excel may open as a missing file.
  function internalLink(text, sheet, address) {
    var ref = "#'" + sheet.replace(/'/g, "''") + "'!" + address;
    var q = function(v) { return '"' + String(v).replace(/"/g, '""') + '"'; };
    return { formula: 'HYPERLINK(' + q(ref) + ',' + q(text) + ')', result: text };
  }

  function build(ExcelJS, project, sets) {
    var wb = new ExcelJS.Workbook();
    wb.creator = (App.config && App.config.title) || 'Data Dictionary';
    wb.created = new Date();

    var statusDefs = {};
    (App.reviewStatuses || []).forEach(function(s) { statusDefs[s.id] = s; });

    // Sheets are created in display order (concept sets first: what readers
    // come for) but filled concepts first, so each concept set row knows where
    // its block of concepts starts.
    var csName = l('sheetConceptSets');
    var cName = l('sheetConcepts');
    var wsS = wb.addWorksheet(csName);
    var wsC = wb.addWorksheet(cName);
    var wsV = wb.addWorksheet(l('sheetVersions'));
    var wsA = wb.addWorksheet(l('sheetAbout'));

    // --- Concepts
    var cCols = [
      { key: 'csId', header: l('conceptSetId'), width: 10 },
      { key: 'csName', header: l('conceptSet'), width: 36 },
      { key: 'csVersion', header: l('version'), width: 10 },
      { key: 'vocabulary', header: l('vocabulary'), width: 13 },
      { key: 'conceptId', header: l('conceptId'), width: 13 },
      { key: 'conceptName', header: l('conceptName'), width: 60, wrap: true },
      { key: 'conceptCode', header: l('conceptCode'), width: 16 },
      { key: 'domain', header: l('domain'), width: 14 },
      { key: 'conceptClass', header: l('conceptClass'), width: 20 },
      { key: 'standard', header: l('standard'), width: 14 },
      { key: 'unit', header: l('recommendedUnit'), width: 14 },
      { key: 'athena', header: l('athena'), width: 10 }
    ];
    setupTable(wsC, cCols);
    var firstRow = {};
    var nConcepts = 0;
    sets.forEach(function(s) {
      var list = (s.resolved || []).slice().sort(function(a, b) {
        return String(a.vocabularyId || '').localeCompare(String(b.vocabularyId || '')) ||
          String(a.conceptName || '').localeCompare(String(b.conceptName || ''));
      });
      s.count = s.resolved ? list.length : null;
      if (!list.length) return;
      firstRow[s.id] = wsC.rowCount + 1;
      list.forEach(function(c) {
        var row = wsC.addRow({
          csId: s.id,
          csName: s.name,
          csVersion: s.pinnedVersion || s.latestVersion,
          vocabulary: c.vocabularyId || '',
          conceptId: c.conceptId,
          conceptName: c.conceptName || '',
          conceptCode: c.conceptCode || '',
          domain: c.domainId || '',
          conceptClass: c.conceptClassId || '',
          standard: App.standardLabel(c),
          unit: s.unitByConcept[c.conceptId] || '',
          // Local concepts (IDs above 2 000 000 000) are not on Athena.
          athena: Number(c.conceptId) > 2000000000 ? ''
            : link(l('athena'), 'https://athena.ohdsi.org/search-terms/terms/' + c.conceptId)
        });
        row.getCell('athena').font = { color: { argb: LINK_FONT }, underline: true };
        nConcepts++;
      });
    });
    finishTable(wsC, cCols.length);

    // --- Concept sets
    var sCols = [
      { key: 'id', header: l('id'), width: 7 },
      { key: 'group', header: l('group'), width: 18, wrap: true },
      { key: 'rule', header: l('groupRule'), width: 14 },
      { key: 'category', header: l('category'), width: 20, wrap: true },
      { key: 'subcategory', header: l('subcategory'), width: 20, wrap: true },
      { key: 'name', header: l('name'), width: 36, wrap: true },
      { key: 'description', header: l('description'), width: 60, wrap: true },
      { key: 'status', header: l('reviewStatus'), width: 20 },
      { key: 'pinned', header: l('pinnedVersion'), width: 10 },
      { key: 'latest', header: l('latestVersion'), width: 10 },
      { key: 'update', header: l('update'), width: 18, wrap: true },
      { key: 'count', header: l('nConcepts'), width: 10 },
      { key: 'date', header: l('versionDate'), width: 12 },
      { key: 'note', header: l('changeNote'), width: 50, wrap: true },
      { key: 'url', header: l('link'), width: 18 }
    ];
    setupTable(wsS, sCols);
    var nOutdated = 0;
    sets.forEach(function(s) {
      if (s.versionStatus === 'outdated') nOutdated++;
      var row = wsS.addRow({
        id: s.id,
        group: s.groupName,
        rule: s.groupRule,
        category: s.category,
        subcategory: s.subcategory,
        name: firstRow[s.id] ? internalLink(s.name, cName, 'A' + firstRow[s.id]) : s.name,
        description: s.description,
        status: App.statusLabel(s.reviewStatus),
        pinned: s.pinnedVersion,
        latest: s.latestVersion,
        update: l(s.versionStatus),
        count: s.count == null ? l('unavailable') : s.count,
        date: s.versionDate,
        note: s.changeNote,
        url: link(l('openInApp'), s.url)
      });
      var nameCell = row.getCell('name');
      nameCell.font = firstRow[s.id] ? { bold: true, color: { argb: LINK_FONT }, underline: true } : { bold: true };
      row.getCell('url').font = { color: { argb: LINK_FONT }, underline: true };
      var def = statusDefs[s.reviewStatus];
      if (def) paint(row.getCell('status'), argb(def.background), argb(def.color));
      if (s.versionStatus === 'outdated') {
        paint(row.getCell('update'), OUTDATED.bg, OUTDATED.fg);
        row.getCell('latest').font = { bold: true };
      } else if (s.versionStatus === 'upToDate') {
        paint(row.getCell('update'), UP_TO_DATE.bg, UP_TO_DATE.fg);
      }
    });
    finishTable(wsS, sCols.length);

    // --- Version history (latest metadata holds the full history)
    var vCols = [
      { key: 'date', header: l('date'), width: 12 },
      { key: 'csId', header: l('conceptSetId'), width: 10 },
      { key: 'csName', header: l('conceptSet'), width: 36, wrap: true },
      { key: 'version', header: l('version'), width: 10 },
      { key: 'author', header: l('author'), width: 22 },
      { key: 'message', header: l('message'), width: 70, wrap: true },
      { key: 'inProject', header: l('inProject'), width: 22, wrap: true }
    ];
    setupTable(wsV, vCols);
    var history = [];
    sets.forEach(function(s) {
      var src = s.live;
      ((src && src.metadata && src.metadata.versions) || []).forEach(function(v) {
        var rel = '';
        if (s.pinnedVersion) {
          var cmp = App.compareVersions(v.version, s.pinnedVersion);
          rel = cmp === 0 ? 'pinned' : (cmp > 0 ? 'newer' : '');
        }
        history.push({ s: s, v: v, rel: rel });
      });
    });
    history.sort(function(a, b) {
      return String(b.v.date || '').localeCompare(String(a.v.date || '')) ||
        a.s.id - b.s.id ||
        App.compareVersions(b.v.version, a.v.version);
    });
    history.forEach(function(h) {
      var row = wsV.addRow({
        date: h.v.date || '',
        csId: h.s.id,
        csName: h.s.name,
        version: h.v.version || '',
        author: h.v.author || '',
        message: plain(h.v.message),
        inProject: h.rel ? l(h.rel) : ''
      });
      if (h.rel === 'newer') paint(row.getCell('inProject'), OUTDATED.bg, OUTDATED.fg);
      else if (h.rel === 'pinned') paint(row.getCell('inProject'), UP_TO_DATE.bg, UP_TO_DATE.fg);
    });
    finishTable(wsV, vCols.length);

    // --- About
    var projTr = App.tProj(project);
    // Release the latest resolved lists were built against (pinned past
    // versions may predate it).
    var inProject = {};
    sets.forEach(function(s) { inProject[s.id] = true; });
    var releases = {};
    ((typeof DATA !== 'undefined' && DATA.resolvedConceptSets) || []).forEach(function(r) {
      if (inProject[r.conceptSetId] && r.vocabularyVersion && r.vocabularyVersion.release) {
        releases[r.vocabularyVersion.release] = true;
      }
    });
    wsA.columns = [{ width: 32 }, { width: 100 }];
    var title = wsA.addRow([projTr.name || '']);
    title.font = { bold: true, size: 14 };
    wsA.addRow([]);
    var now = new Date();
    var info = [
      [l('project'), projTr.name || ''],
      [l('description'), projTr.shortDescription || ''],
      [l('projectModified'), project.modifiedDate || project.createdDate || ''],
      [l('exportedOn'), now.toISOString().slice(0, 10) + ' ' + now.toTimeString().slice(0, 5)],
      [l('dictionaryBuild'), (typeof DATA !== 'undefined' && DATA.dataVersion) || ''],
      [l('vocabRelease'), Object.keys(releases).sort().join('; ')],
      [l('nConceptSets'), sets.length + (nOutdated ? ' (' + nOutdated + ' ' + l('nOutdated') + ')' : '')],
      [l('nConcepts'), nConcepts],
      [l('link'), link(appUrl('#/projects?id=' + project.id), appUrl('#/projects?id=' + project.id))]
    ];
    info.forEach(function(r) {
      var row = wsA.addRow(r);
      row.getCell(1).font = { bold: true };
      row.getCell(2).alignment = { wrapText: true, vertical: 'top', horizontal: 'left' };
    });
    wsA.lastRow.getCell(2).font = { color: { argb: LINK_FONT }, underline: true };
    wsA.addRow([]);
    wsA.addRow([l('howToRead')]).font = { bold: true, size: 12 };
    [['sheetConceptSets', 'howConceptSets'], ['sheetConcepts', 'howConcepts'], ['sheetVersions', 'howVersions']]
      .forEach(function(p) {
        var row = wsA.addRow([l(p[0]), l(p[1])]);
        row.getCell(1).font = { bold: true };
        row.getCell(2).alignment = { wrapText: true, vertical: 'top' };
      });

    wb.views = [{ activeTab: 0, firstSheet: 0 }];
    return wb;
  }

  // ==================== ENTRY POINT ====================

  /**
   * Build and download the workbook for `project`. `ruleLabel(rule)` gives the
   * translated group rule label. Resolves once the download has been triggered.
   */
  function exportProject(project, ruleLabel) {
    return Promise.all([loadExcelJS(), preload(project)]).then(function(res) {
      var ExcelJS = res[0];
      var sets = collect(project, ruleLabel || function(r) { return r; });
      var wb = build(ExcelJS, project, sets);
      return wb.xlsx.writeBuffer().then(function(buf) {
        var blob = new Blob([buf], { type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' });
        var url = URL.createObjectURL(blob);
        var a = document.createElement('a');
        a.href = url;
        var projTr = App.tProj(project);
        a.download = (projTr.name || 'project').normalize('NFD').replace(/[\u0300-\u036f]/g, '')
          .replace(/[^a-zA-Z0-9]+/g, '_').replace(/^_|_$/g, '') +
          '_' + new Date().toISOString().slice(0, 10) + '.xlsx';
        document.body.appendChild(a);
        a.click();
        a.remove();
        setTimeout(function() { URL.revokeObjectURL(url); }, 1000);
      });
    });
  }

  return { exportProject: exportProject };
})();

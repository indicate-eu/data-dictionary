// mapping-recommendations.js — Mapping Recommendations page module (view + edit, multilingual)
var MappingRecommendationsPage = (function() {
  'use strict';

  var initialized = false;
  var editor = null;
  var editing = false;
  var tocScrollHandler = null;

  function getContent() {
    return App.getMappingContent();
  }

  function renderView() {
    var container = document.getElementById('mapping-view-content');
    if (!container) return;
    var md = getContent();
    if (!md.trim()) {
      container.innerHTML = '<div class="markdown-preview-placeholder">' +
        App.escapeHtml(App.i18n('No mapping recommendations available.')) + '</div>';
    } else {
      container.innerHTML = marked.parse(md);
    }
    renderToc();
    setupTocScroll();
  }

  function renderToc() {
    var container = document.getElementById('mapping-view-content');
    var tocEl = document.getElementById('mapping-toc');
    if (!container || !tocEl) return;
    var headings = container.querySelectorAll('h2, h3');
    if (headings.length === 0) { tocEl.innerHTML = ''; return; }

    for (var i = 0; i < headings.length; i++) {
      if (!headings[i].id) {
        headings[i].id = 'mapping-heading-' + i;
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

  function setupTocScroll() {
    var contentEl = document.getElementById('mapping-view-container');
    var tocEl = document.getElementById('mapping-toc');
    if (!contentEl || !tocEl) return;

    if (tocScrollHandler) contentEl.removeEventListener('scroll', tocScrollHandler);

    var headings = document.getElementById('mapping-view-content').querySelectorAll('h2, h3');
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

        var sectionTop = headings[hIdx].offsetTop - containerTop;
        var sectionBottom = (hIdx + 1 < headings.length)
          ? headings[hIdx + 1].offsetTop - containerTop
          : contentEl.scrollHeight;

        var visible = sectionBottom > scrollTop && sectionTop < viewBottom;
        links[j].classList.toggle('active', visible);
      }
    };

    contentEl.addEventListener('scroll', tocScrollHandler, { passive: true });
    tocScrollHandler();
  }

  function enterEditMode() {
    editing = true;
    document.getElementById('mapping-view-container').style.display = 'none';
    document.getElementById('mapping-edit-container').style.display = 'flex';
    document.getElementById('mapping-toc').style.display = 'none';
    document.getElementById('mapping-toolbar-view').style.display = 'none';
    document.getElementById('mapping-toolbar-edit').style.display = '';

    if (!editor) {
      editor = ace.edit('mapping-page-ace-editor');
      editor.setTheme('ace/theme/chrome');
      editor.session.setMode('ace/mode/markdown');
      editor.setFontSize(13);
      editor.setShowPrintMargin(false);
      editor.session.setUseWrapMode(true);
      editor.session.on('change', function() {
        var md = editor.getValue();
        var preview = document.getElementById('mapping-page-preview');
        if (!md.trim()) {
          preview.innerHTML = '<div class="markdown-preview-placeholder">Preview will appear here...</div>';
        } else {
          preview.innerHTML = marked.parse(md);
        }
      });
      // CMD/CTRL+S to save
      editor.commands.addCommand({
        name: 'saveMappingRecommendations',
        bindKey: { win: 'Ctrl-S', mac: 'Cmd-S' },
        exec: function() { save(); }
      });
    }
    editor.setValue(getContent(), -1);
    editor.resize();
    // Trigger initial preview
    var initMd = editor.getValue();
    var preview = document.getElementById('mapping-page-preview');
    if (initMd.trim()) {
      preview.innerHTML = marked.parse(initMd);
    } else {
      preview.innerHTML = '<div class="markdown-preview-placeholder">Preview will appear here...</div>';
    }
  }

  function exitEditMode() {
    editing = false;
    document.getElementById('mapping-view-container').style.display = '';
    document.getElementById('mapping-edit-container').style.display = 'none';
    document.getElementById('mapping-toc').style.display = '';
    document.getElementById('mapping-toolbar-view').style.display = '';
    document.getElementById('mapping-toolbar-edit').style.display = 'none';
  }

  function save() {
    if (!editor) return;
    App.setMappingContent(editor.getValue());
    renderView();
    exitEditMode();
    App.showToast(App.i18n('Mapping recommendations saved.'), 'success');
  }

  function cancel() {
    exitEditMode();
  }

  function exportMapping() {
    var content = JSON.stringify(App.mappingRecommendations, null, 2);
    App.openExportModal({
      title: App.i18n('Export Mapping Recommendations'),
      content: content,
      filename: 'mapping_recommendations.json',
      type: 'application/json',
      clipboardDesc: App.i18n('Copy JSON to clipboard'),
      fileDesc: App.i18n('Download as mapping_recommendations.json'),
      githubUrl: 'https://github.com/indicate-eu/data-dictionary/edit/main/mapping_recommendations/mapping_recommendations.json'
    });
  }

  function initEvents() {
    document.getElementById('mapping-page-export-btn').addEventListener('click', exportMapping);
    document.getElementById('mapping-page-edit-btn').addEventListener('click', enterEditMode);
    document.getElementById('mapping-page-cancel-btn').addEventListener('click', cancel);
    document.getElementById('mapping-page-save-btn').addEventListener('click', save);
    // TOC clicks scroll to heading
    document.getElementById('mapping-toc').addEventListener('click', function(e) {
      var link = e.target.closest('[data-toc-target]');
      if (!link) return;
      e.preventDefault();
      var target = document.getElementById(link.getAttribute('data-toc-target'));
      if (target) target.scrollIntoView({ behavior: 'smooth', block: 'start' });
    });
  }

  function onLanguageChange() {
    if (!editing) {
      renderView();
    } else if (editor) {
      // When language changes during edit, save current content for old language
      // and load content for new language
      editor.setValue(getContent(), -1);
    }
  }

  function show() {
    if (!initialized) {
      initialized = true;
      initEvents();
    }
    if (!editing) {
      renderView();
    } else if (editor) {
      editor.resize();
    }
  }

  function hide() {}

  return {
    show: show,
    hide: hide,
    onLanguageChange: onLanguageChange
  };
})();

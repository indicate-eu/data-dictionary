// mapping-recommendations.js — Mapping Recommendations page module (view + edit, multilingual)
var MappingRecommendationsPage = (function() {
  'use strict';

  var initialized = false;
  var editor = null;
  var editing = false;

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
  }

  function enterEditMode() {
    editing = true;
    var toolbar = document.querySelector('.mapping-page-toolbar');
    toolbar.classList.add('edit-mode');
    document.getElementById('mapping-page-export-btn').style.display = 'none';
    document.getElementById('mapping-page-edit-btn').style.display = 'none';
    document.getElementById('mapping-page-cancel-btn').style.display = '';
    document.getElementById('mapping-page-save-btn').style.display = '';
    document.getElementById('mapping-view-container').style.display = 'none';
    document.getElementById('mapping-edit-container').style.display = 'block';

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
    var toolbar = document.querySelector('.mapping-page-toolbar');
    toolbar.classList.remove('edit-mode');
    document.getElementById('mapping-page-export-btn').style.display = '';
    document.getElementById('mapping-page-edit-btn').style.display = '';
    document.getElementById('mapping-page-cancel-btn').style.display = 'none';
    document.getElementById('mapping-page-save-btn').style.display = 'none';
    document.getElementById('mapping-view-container').style.display = '';
    document.getElementById('mapping-edit-container').style.display = 'none';
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

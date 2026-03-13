// shared.js — expose window.App for use by page-specific scripts
var App = (function() {
  'use strict';

  var APP_NAME = 'INDICATE Data Dictionary (Web)';
  var APP_VERSION = '1.0.1';

  // ==================== STATE ====================
  var conceptSets = [];
  var projects = [];
  var unitConversions = [];
  var recommendedUnits = [];
  var etlGuidelines = '';
  var lang = localStorage.getItem('indicate_lang') || 'en';
  var resolvedIndex = {}; // conceptSetId -> resolvedConcepts[]
  var sessionReviews = JSON.parse(localStorage.getItem('indicate_reviews') || '{}');
  var languageChangeCallbacks = [];
  var beforeNavigateCallbacks = [];
  var homeCallbacks = [];
  var userConceptSets = JSON.parse(localStorage.getItem('indicate_user_cs') || '[]');
  var userProjects = JSON.parse(localStorage.getItem('indicate_user_proj') || '[]');

  // Migrate legacy project format (name/description/justification/bibliography → translations)
  (function migrateProjects() {
    var migrated = false;
    userProjects.forEach(function(p) {
      if (!p.translations) {
        p.translations = {
          en: {
            name: p.name || '',
            short_description: p.description || '',
            long_description: p.justification || ''
          },
          fr: { name: '', short_description: '', long_description: '' }
        };
        delete p.name;
        delete p.description;
        delete p.justification;
        delete p.bibliography;
        migrated = true;
      }
    });
    if (migrated) localStorage.setItem('indicate_user_proj', JSON.stringify(userProjects));
  })();

  // ==================== DATA LOADING ====================
  function loadData(callback) {
    var hiddenIds = JSON.parse(localStorage.getItem('indicate_hidden_cs') || '[]');
    var hiddenSet = {};
    hiddenIds.forEach(function(id) { hiddenSet[id] = true; });
    // User-modified repo CS override originals; hidden ones are excluded
    var userIdSet = {};
    userConceptSets.forEach(function(cs) { userIdSet[cs.id] = true; });
    var repoCS = (DATA.conceptSets || []).filter(function(cs) { return !hiddenSet[cs.id] && !userIdSet[cs.id]; });
    conceptSets = repoCS.concat(userConceptSets);
    // Merge user projects with repo projects (user overrides repo)
    var hiddenProjIds = JSON.parse(localStorage.getItem('indicate_hidden_proj') || '[]');
    var hiddenProjSet = {};
    hiddenProjIds.forEach(function(id) { hiddenProjSet[id] = true; });
    var userProjIdSet = {};
    userProjects.forEach(function(p) { userProjIdSet[p.id] = true; });
    var repoProj = (DATA.projects || []).filter(function(p) { return !hiddenProjSet[p.id] && !userProjIdSet[p.id]; });
    projects = repoProj.concat(userProjects);
    unitConversions = DATA.unitConversions || [];
    recommendedUnits = DATA.recommendedUnits || [];
    etlGuidelines = DATA.etlGuidelines || '';
    var resolved = DATA.resolvedConceptSets || [];
    resolved.forEach(function(r) {
      resolvedIndex[r.conceptSetId] = r.resolvedConcepts || [];
    });
    document.getElementById('loading').classList.add('hidden');
    if (callback) callback();
  }

  // ==================== I18N DICTIONARY ====================
  var I18N = {
    // Navigation & Header
    'Data Dictionary':               { fr: 'Dictionnaire de données' },
    'Projects':                      { fr: 'Projets' },
    'Organization':                  { fr: 'Organisation' },
    'Guest':                         { fr: 'Invité' },
    'Reset':                         { fr: 'Réinitialiser' },
    'EN':                            { fr: 'EN' },
    'General Settings':              { fr: 'Paramètres généraux' },
    'Dictionary Settings':           { fr: 'Paramètres du dictionnaire' },
    'Dev Tools':                     { fr: 'Outils de développement' },

    // Common actions
    'Cancel':                        { fr: 'Annuler' },
    'Save':                          { fr: 'Enregistrer' },
    'Edit':                          { fr: 'Modifier' },
    'Delete':                        { fr: 'Supprimer' },
    'Back':                          { fr: 'Retour' },
    'Close':                         { fr: 'Fermer' },
    'Search':                        { fr: 'Rechercher' },
    'Export':                        { fr: 'Exporter' },
    'Create':                        { fr: 'Créer' },
    'Apply':                         { fr: 'Appliquer' },
    'Clear':                         { fr: 'Effacer' },
    'Submit':                        { fr: 'Soumettre' },
    'Filter...':                     { fr: 'Filtrer...' },
    'All':                           { fr: 'Tous' },
    'Loading...':                    { fr: 'Chargement...' },

    // Table headers
    'Category':                      { fr: 'Catégorie' },
    'Subcategory':                   { fr: 'Sous-catégorie' },
    'Name':                          { fr: 'Nom' },
    'Description':                   { fr: 'Description' },
    'Version':                       { fr: 'Version' },
    'Status':                        { fr: 'Statut' },
    'Concept ID':                    { fr: 'ID Concept' },
    'Vocabulary':                    { fr: 'Vocabulaire' },
    'Concept Name':                  { fr: 'Nom du concept' },
    'Concept Code':                  { fr: 'Code du concept' },
    'Domain':                        { fr: 'Domaine' },
    'Standard':                      { fr: 'Standard' },
    'Concept Class':                 { fr: 'Classe du concept' },
    'Date':                          { fr: 'Date' },
    'Reset to Template':             { fr: 'Réinitialiser le modèle' },

    // Status labels
    'Draft':                         { fr: 'Brouillon' },
    'Pending Review':                { fr: 'En attente de relecture' },
    'Approved':                      { fr: 'Approuvé' },
    'Needs Revision':                { fr: 'À réviser' },
    'Deprecated':                    { fr: 'Obsolète' },

    // Standard/Validity badges
    'Classification':                { fr: 'Classification' },
    'Non-standard':                  { fr: 'Non standard' },
    'Valid':                         { fr: 'Valide' },

    // Concept Sets page
    'Add Concept Set':               { fr: 'Ajouter un jeu de concepts' },
    'Select all':                    { fr: 'Tout sélectionner' },
    'Unselect all':                  { fr: 'Tout désélectionner' },
    'Delete selected':               { fr: 'Supprimer la sélection' },
    '0 selected':                    { fr: '0 sélectionné(s)' },
    'Concepts':                      { fr: 'Concepts' },
    'Comments':                      { fr: 'Commentaires' },
    'Statistics':                    { fr: 'Statistiques' },
    'Review':                        { fr: 'Relecture' },
    'Resolved':                      { fr: 'Résolus' },
    'Expression':                    { fr: 'Expression' },
    'Add Concepts':                  { fr: 'Ajouter des concepts' },
    'Select':                        { fr: 'Sélectionner' },
    'Delete Selected':               { fr: 'Supprimer la sélection' },
    'Optimize':                      { fr: 'Optimiser' },
    'Columns':                       { fr: 'Colonnes' },
    'View JSON':                     { fr: 'Voir JSON' },
    'Exclude':                       { fr: 'Exclure' },
    'Descendants':                   { fr: 'Descendants' },
    'Mapped':                        { fr: 'Mappé' },

    // Concept detail
    'Excluded':                      { fr: 'Exclu' },
    'Mapped from':                   { fr: 'Mappé depuis' },
    'Maps to':                       { fr: 'Mappe vers' },

    // Distribution Statistics
    'Distribution Statistics':       { fr: 'Statistiques de distribution' },
    'Distribution Statistics (JSON)':{ fr: 'Statistiques de distribution (JSON)' },

    // Review tab
    'Reviews':                       { fr: 'Relectures' },
    'Add Review':                    { fr: 'Ajouter une relecture' },
    'Reviewer':                      { fr: 'Relecteur' },
    'No reviews yet. Click "Add Review" to submit the first review.': { fr: 'Aucune relecture. Cliquez sur « Ajouter une relecture » pour soumettre la première.' },

    // Comments
    'No description available':      { fr: 'Aucune description disponible' },
    'Editor':                        { fr: 'Éditeur' },
    'Preview':                       { fr: 'Aperçu' },
    'Preview will appear here...':   { fr: 'L\'aperçu apparaîtra ici...' },

    // Projects page
    'Concept Sets':                  { fr: 'Jeux de concepts' },
    'No description':                { fr: 'Pas de description' },
    'Actions':                       { fr: 'Actions' },
    'concept sets':                  { fr: 'jeux de concepts' },
    'AVAILABLE CONCEPT SETS':        { fr: 'JEUX DE CONCEPTS DISPONIBLES' },
    'PROJECT CONCEPT SETS':          { fr: 'JEUX DE CONCEPTS DU PROJET' },
    'Enter description (Markdown supported)...': { fr: 'Saisir la description (Markdown supporté)...' },
    'Enter justification (Markdown supported)...': { fr: 'Saisir la justification (Markdown supporté)...' },

    // Project modals
    'New Project':                   { fr: 'Nouveau projet' },
    'Edit Project':                  { fr: 'Modifier le projet' },
    'Delete Project':                { fr: 'Supprimer le projet' },
    'Project name':                  { fr: 'Nom du projet' },
    'Author name':                   { fr: 'Nom de l\'auteur' },
    'Name *':                        { fr: 'Nom *' },
    'Created By':                    { fr: 'Créé par' },
    'Are you sure you want to delete this project?': { fr: 'Êtes-vous sûr de vouloir supprimer ce projet ?' },
    'Add Project':                   { fr: 'Ajouter un projet' },
    'Search projects...':            { fr: 'Rechercher des projets...' },
    'Name (EN) *':                   { fr: 'Nom (EN) *' },
    'Name (FR)':                     { fr: 'Nom (FR)' },
    'Project name (English)':        { fr: 'Nom du projet (Anglais)' },
    'Project name (French)':         { fr: 'Nom du projet (Français)' },
    'Short description (EN)':        { fr: 'Description courte (EN)' },
    'Short description (FR)':        { fr: 'Description courte (FR)' },
    'Short description (English)':   { fr: 'Description courte (Anglais)' },
    'Short description (French)':    { fr: 'Description courte (Français)' },
    'Long description (EN)':         { fr: 'Description longue (EN)' },
    'Long description (FR)':         { fr: 'Description longue (FR)' },
    'Enter long description in English (Markdown supported)...': { fr: 'Saisir la description longue en anglais (Markdown supporté)...' },
    'Enter long description in French (Markdown supported)...': { fr: 'Saisir la description longue en français (Markdown supporté)...' },
    'Export CSV':                    { fr: 'Exporter CSV' },

    // Profile modal
    'Edit Profile':                  { fr: 'Modifier le profil' },
    'Select an existing author':     { fr: 'Sélectionner un auteur existant' },
    '— Custom —':                    { fr: '— Personnalisé —' },
    'First Name *':                  { fr: 'Prénom *' },
    'Last Name *':                   { fr: 'Nom *' },
    'Affiliation':                   { fr: 'Affiliation' },
    'Profession':                    { fr: 'Profession' },
    'ORCID':                         { fr: 'ORCID' },

    // Organization modal
    'Edit Organization':             { fr: 'Modifier l\'organisation' },
    'Organization Name *':           { fr: 'Nom de l\'organisation *' },
    'URL':                           { fr: 'URL' },

    // Reset modal
    'Reset local data':              { fr: 'Réinitialiser les données locales' },
    'This will clear your saved profile and all local data.': { fr: 'Ceci effacera votre profil enregistré et toutes les données locales.' },
    'This action cannot be undone.': { fr: 'Cette action est irréversible.' },

    // Export modal
    'Export Concept Set':            { fr: 'Exporter le jeu de concepts' },
    'Copy OHDSI JSON to Clipboard':  { fr: 'Copier le JSON OHDSI dans le presse-papiers' },
    'Copy the concept set in OHDSI-compliant JSON format to clipboard': { fr: 'Copier le jeu de concepts au format JSON OHDSI dans le presse-papiers' },
    'Download OHDSI JSON File':      { fr: 'Télécharger le fichier JSON OHDSI' },
    'Download the concept set as a JSON file following OHDSI specification': { fr: 'Télécharger le jeu de concepts au format JSON suivant la spécification OHDSI' },
    'Concept Set Specification':     { fr: 'Spécification du jeu de concepts' },
    'Full OHDSI format with metadata and translations': { fr: 'Format OHDSI complet avec métadonnées et traductions' },
    'ATLAS':                         { fr: 'ATLAS' },
    'ATLAS-compatible format (expression only)': { fr: 'Format compatible ATLAS (expression uniquement)' },

    // Bulk export modal
    'Export Concept Sets':           { fr: 'Exporter les jeux de concepts' },
    'Export All':                    { fr: 'Tout exporter' },
    'Download all concept sets as a single JSON file': { fr: 'Télécharger tous les jeux de concepts dans un seul fichier JSON' },
    'Export Selected':               { fr: 'Exporter la sélection' },
    'Download selected concept sets': { fr: 'Télécharger les jeux de concepts sélectionnés' },
    'Filter by Category':            { fr: 'Filtrer par catégorie' },
    'Export concept sets from a specific category': { fr: 'Exporter les jeux de concepts d\'une catégorie spécifique' },

    // New Concept Set modal
    'New Concept Set':               { fr: 'Nouveau jeu de concepts' },
    'e.g. Heart Rate':               { fr: 'ex. Fréquence cardiaque' },
    'Category *':                    { fr: 'Catégorie *' },
    'Select a category...':          { fr: 'Sélectionner une catégorie...' },
    'Subcategory':                   { fr: 'Sous-catégorie' },
    'Select a subcategory...':       { fr: 'Sélectionner une sous-catégorie...' },
    'Brief description of the concept set...': { fr: 'Brève description du jeu de concepts...' },

    // Version modal
    'Change Summary (optional)':     { fr: 'Résumé des modifications (optionnel)' },
    'Describe what changed...':      { fr: 'Décrivez les modifications...' },
    'Version History':               { fr: 'Historique des versions' },

    // Status modal
    'Change Status':                 { fr: 'Changer le statut' },

    // Import ATLAS JSON
    'Import ATLAS JSON':             { fr: 'Importer JSON ATLAS' },
    'Paste an ATLAS concept set expression JSON. Format: {"items": [...]}': { fr: 'Collez une expression JSON de jeu de concepts ATLAS. Format : {"items": [...]}' },

    // Optimize Expression
    'Optimize Expression':           { fr: 'Optimiser l\'expression' },
    'Analyzing hierarchy...':        { fr: 'Analyse de la hiérarchie...' },
    'Apply Optimization':            { fr: 'Appliquer l\'optimisation' },

    // Add Concepts modal
    'Load OHDSI vocabularies in General Settings to search concepts.': { fr: 'Chargez les vocabulaires OHDSI dans les Paramètres généraux pour rechercher des concepts.' },
    'Search concepts by name, code, or ID...': { fr: 'Rechercher des concepts par nom, code ou ID...' },
    'Filters':                       { fr: 'Filtres' },
    'Class':                         { fr: 'Classe' },
    'Valid only':                    { fr: 'Valides uniquement' },
    'Limit 10K':                     { fr: 'Limite 10K' },
    'Concept Details':               { fr: 'Détails du concept' },
    'Select a concept to view details': { fr: 'Sélectionnez un concept pour voir les détails' },
    'Hierarchy':                     { fr: 'Hiérarchie' },
    'Select a concept to view hierarchy': { fr: 'Sélectionnez un concept pour voir la hiérarchie' },
    'Multiple Selection':            { fr: 'Sélection multiple' },
    'This will load':                { fr: 'Cela va charger' },
    'concepts. This may be slow.':   { fr: 'concepts. Cela peut être lent.' },
    'Load all':                      { fr: 'Tout charger' },

    // Confirm Delete
    'Confirm Delete':                { fr: 'Confirmer la suppression' },
    'This will only remove locally created concept sets. Repository concept sets cannot be deleted.': { fr: 'Seuls les jeux de concepts créés localement seront supprimés. Les jeux de concepts du dépôt ne peuvent pas être supprimés.' },
    'Create New Version':            { fr: 'Créer une nouvelle version' },
    'Import':                        { fr: 'Importer' },

    // Toast messages
    'Expression saved':              { fr: 'Expression enregistrée' },
    'Nothing to optimize':           { fr: 'Rien à optimiser' },
    'Comments saved':                { fr: 'Commentaires enregistrés' },
    'Statistics saved':              { fr: 'Statistiques enregistrées' },
    'Please paste JSON content.':    { fr: 'Veuillez coller du contenu JSON.' },
    'JSON must contain a non-empty "items" array.': { fr: 'Le JSON doit contenir un tableau "items" non vide.' },
    'Please set up your profile first (click on "Guest" in the header).': { fr: 'Veuillez d\'abord configurer votre profil (cliquez sur « Invité » dans l\'en-tête).' },
    'Please select a review status.': { fr: 'Veuillez sélectionner un statut de relecture.' },
    'Review comments are required.': { fr: 'Les commentaires de relecture sont requis.' },
    'Review submitted! Use "Propose on GitHub" to submit a pull request.': { fr: 'Relecture soumise ! Utilisez « Proposer sur GitHub » pour soumettre une pull request.' },
    'JSON copied to clipboard! Paste it in the GitHub editor.': { fr: 'JSON copié dans le presse-papiers ! Collez-le dans l\'éditeur GitHub.' },
    'Please enter a version number': { fr: 'Veuillez saisir un numéro de version' },
    'Copied to clipboard!':          { fr: 'Copié dans le presse-papiers !' },
    'Could not copy to clipboard. Try downloading the file instead.': { fr: 'Impossible de copier. Essayez de télécharger le fichier.' },
    'Changes saved':                 { fr: 'Modifications enregistrées' },
    'No concept sets selected.':     { fr: 'Aucun jeu de concepts sélectionné.' },
    'Name is required.':             { fr: 'Le nom est requis.' },
    'Category is required.':         { fr: 'La catégorie est requise.' },
    'First name and last name are required.': { fr: 'Le prénom et le nom sont requis.' },
    'Organization name is required.': { fr: 'Le nom de l\'organisation est requis.' },
    'Organization saved':            { fr: 'Organisation enregistrée' },
    'Project name is required.':     { fr: 'Le nom du projet est requis.' },
    'Project saved.':                { fr: 'Projet enregistré.' },
    'Optimization applied — review and save': { fr: 'Optimisation appliquée — vérifiez et enregistrez' },
    'Invalid JSON: ':                { fr: 'JSON invalide : ' },
    'Version updated to v':          { fr: 'Version mise à jour en v' },
    'Status changed to ':            { fr: 'Statut changé en ' },
    'No concepts in this concept set': { fr: 'Aucun concept dans ce jeu de concepts' },
    'No concepts match the current filters.': { fr: 'Aucun concept ne correspond aux filtres actuels.' },
    'No description available for this concept set.': { fr: 'Aucune description disponible pour ce jeu de concepts.' },
    'No distribution statistics available for this concept set.': { fr: 'Aucune statistique de distribution disponible pour ce jeu de concepts.' },
    'Click <strong>Edit</strong> to add statistics, or compute them via the INDICATE Data Dictionary application.': { fr: 'Cliquez sur <strong>Modifier</strong> pour ajouter des statistiques, ou calculez-les via l\'application INDICATE Data Dictionary.' },
    'Loading vocabulary database...': { fr: 'Chargement de la base de vocabulaire...' },
    ' imported':                     { fr: ' importé(s)' },
    ' added':                        { fr: ' ajouté(s)' },
    ' skipped (duplicate or invalid)': { fr: ' ignoré(s) (doublon ou invalide)' },
    ' skipped (already in expression)': { fr: ' ignoré(s) (déjà dans l\'expression)' },
    ' concept set':                  { fr: ' jeu de concepts' },
    ' concept sets':                 { fr: ' jeux de concepts' },
    ' deleted.':                     { fr: ' supprimé(s).' },
    ' exported.':                    { fr: ' exporté(s).' },
    ' cannot be deleted.':           { fr: ' ne peut pas être supprimé(s).' },
    'Delete ':                       { fr: 'Supprimer ' },
    ' selected concept set':         { fr: ' jeu de concepts sélectionné' },
    ' selected concept sets':        { fr: ' jeux de concepts sélectionnés' },
    'Download ':                     { fr: 'Télécharger ' },
    ' selected concept set':         { fr: ' jeu de concepts sélectionné' },
    'Concept set updated.':          { fr: 'Jeu de concepts mis à jour.' },
    'Concept set created.':          { fr: 'Jeu de concepts créé.' },
    'Project updated.':              { fr: 'Projet mis à jour.' },
    'Project created.':              { fr: 'Projet créé.' },
    'Project deleted.':              { fr: 'Projet supprimé.' },
    ' concept':                      { fr: ' concept' },
    ' concepts':                     { fr: ' concepts' },
    'repository ':                   { fr: 'du dépôt ' },

    // Settings
    'OHDSI Vocabularies':            { fr: 'Vocabulaires OHDSI' },
    'Load a DuckDB (.duckdb) or SQLite (.sqlite / .db) database containing OMOP vocabulary tables.': { fr: 'Chargez une base de données DuckDB (.duckdb) ou SQLite (.sqlite / .db) contenant les tables de vocabulaire OMOP.' },
    'Load vocabulary database':      { fr: 'Charger la base de vocabulaire' },
    'ETL Guidelines':                { fr: 'Directives ETL' },
    'Units':                         { fr: 'Unités' },
    'Recommended Units':             { fr: 'Unités recommandées' },
    'Unit Conversions':              { fr: 'Conversions d\'unités' },

    // Footer
    'Powered by':                    { fr: 'Propulsé par' },

    // Multi-select
    'selected':                      { fr: 'sélectionné(s)' },

    // Review form
    'Submit Review':                 { fr: 'Soumettre la relecture' },
    'Propose on GitHub':             { fr: 'Proposer sur GitHub' },
    '-- Select status --':           { fr: '-- Sélectionner un statut --' },
    'Status:':                       { fr: 'Statut :' },

    // Custom concepts
    'OHDSI Vocabularies':            { fr: 'Vocabulaires OHDSI' },
    'Custom Concept':                { fr: 'Concept personnalisé' },
    'Add Custom Concept':            { fr: 'Ajouter un concept personnalisé' },
    'Custom Concepts Added':         { fr: 'Concepts personnalisés ajoutés' },
    'No custom concepts added yet.': { fr: 'Aucun concept personnalisé ajouté.' },
    'Auto-assigned from 2,100,000,000': { fr: 'Auto-assigné à partir de 2 100 000 000' },
    'Enter concept name...':         { fr: 'Saisir le nom du concept...' },
    'Enter concept code (optional)...': { fr: 'Saisir le code du concept (optionnel)...' },
    'Custom concepts use the INDICATE vocabulary': { fr: 'Les concepts personnalisés utilisent le vocabulaire INDICATE' },
    '-- Select --':                  { fr: '-- Sélectionner --' },
    'Standard Concept':              { fr: 'Concept standard' },
    'Concept Class':                 { fr: 'Classe du concept' },
    'Please enter a concept name.':  { fr: 'Veuillez saisir un nom de concept.' },
    'Please select a domain.':       { fr: 'Veuillez sélectionner un domaine.' },
    'Please select a concept class.': { fr: 'Veuillez sélectionner une classe.' },
    ' custom concept added':         { fr: ' concept personnalisé ajouté' },
    'Resolving concepts...':         { fr: 'Résolution des concepts...' }
  };

  function i18n(key) {
    if (lang === 'en') return key;
    var entry = I18N[key];
    return (entry && entry[lang]) || key;
  }

  function formatDate(dateStr) {
    if (!dateStr) return '';
    // Input expected: YYYY-MM-DD
    var parts = dateStr.split('-');
    if (parts.length !== 3) return dateStr;
    if (lang === 'fr') return parts[2] + '/' + parts[1] + '/' + parts[0];
    return dateStr; // YYYY-MM-DD for EN
  }

  /** Translate all elements with data-i18n attributes */
  function translateDOM() {
    document.querySelectorAll('[data-i18n]').forEach(function(el) {
      el.textContent = i18n(el.getAttribute('data-i18n'));
    });
    document.querySelectorAll('[data-i18n-placeholder]').forEach(function(el) {
      el.placeholder = i18n(el.getAttribute('data-i18n-placeholder'));
    });
    document.querySelectorAll('[data-i18n-title]').forEach(function(el) {
      el.title = i18n(el.getAttribute('data-i18n-title'));
    });
  }

  // ==================== HELPERS ====================
  function t(cs) {
    var tr = cs.metadata && cs.metadata.translations;
    return (tr && tr[lang]) || (tr && tr.en) || {};
  }

  function tProj(proj) {
    var tr = proj.translations;
    return (tr && tr[lang]) || (tr && tr.en) || {};
  }

  function escapeHtml(s) {
    if (!s) return '';
    return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
  }

  var toastIcons = { error: 'fa-circle-exclamation', success: 'fa-circle-check', warning: 'fa-triangle-exclamation', info: 'fa-circle-info' };
  function showToast(message, type, duration) {
    type = type || 'info';
    duration = duration || 3000;
    var container = document.getElementById('toast-container');
    var toast = document.createElement('div');
    toast.className = 'toast toast-' + type;
    toast.innerHTML = '<i class="fas ' + (toastIcons[type] || toastIcons.info) + '"></i><span>' + escapeHtml(message) + '</span>';
    container.appendChild(toast);
    setTimeout(function() {
      toast.classList.add('toast-fade-out');
      setTimeout(function() { toast.remove(); }, 300);
    }, duration);
  }

  function renderMarkdown(s) {
    if (!s) return '';
    if (typeof marked !== 'undefined' && marked.parse) {
      var renderer = new marked.Renderer();
      renderer.link = function(token) {
        var h = typeof token === 'object' ? token.href : token;
        var ti = typeof token === 'object' ? token.title : arguments[1];
        var tx = typeof token === 'object' ? token.text : arguments[2];
        var t = ti ? ' title="' + escapeHtml(ti) + '"' : '';
        return '<a href="' + escapeHtml(h) + '"' + t + ' target="_blank" rel="noopener noreferrer">' + (tx || '') + '</a>';
      };
      return marked.parse(s, { renderer: renderer });
    }
    // Fallback if marked not loaded
    var html = escapeHtml(s);
    html = html.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
    var blocks = html.split(/\n\n+/);
    return blocks.map(function(block) {
      var lines = block.split('\n');
      var isList = lines.every(function(l) { return l.trim() === '' || l.trim().startsWith('- '); });
      if (isList) {
        var items = lines.filter(function(l) { return l.trim().startsWith('- '); }).map(function(l) { return '<li>' + l.trim().substring(2) + '</li>'; });
        return '<ul style="margin:8px 0 8px 20px; line-height:1.8">' + items.join('') + '</ul>';
      }
      return '<p>' + block.replace(/\n/g, '<br>') + '</p>';
    }).join('');
  }

  function fuzzyMatch(text, query) {
    text = text.toLowerCase();
    query = query.toLowerCase();
    if (text.includes(query)) return 0;
    var ti = 0, qi = 0, score = 0, lastMatch = -1;
    while (ti < text.length && qi < query.length) {
      if (text[ti] === query[qi]) {
        score += (ti - (lastMatch + 1));
        lastMatch = ti;
        qi++;
      }
      ti++;
    }
    return qi === query.length ? score + 1 : -1;
  }

  function fuzzyFilter(items, query, getTexts) {
    if (!query) return items;
    var q = query.toLowerCase().trim();
    var results = [];
    for (var i = 0; i < items.length; i++) {
      var texts = getTexts(items[i]);
      var bestScore = -1;
      for (var j = 0; j < texts.length; j++) {
        var s = fuzzyMatch(texts[j] || '', q);
        if (s >= 0 && (bestScore < 0 || s < bestScore)) bestScore = s;
      }
      if (bestScore >= 0) results.push({ item: items[i], score: bestScore });
    }
    results.sort(function(a, b) { return a.score - b.score; });
    return results.map(function(r) { return r.item; });
  }

  var statusLabelsMap = { draft: 'Draft', pending_review: 'Pending Review', approved: 'Approved', needs_revision: 'Needs Revision', deprecated: 'Deprecated' };

  function statusLabel(status) {
    return i18n(statusLabelsMap[status] || status);
  }

  function statusBadge(status) {
    if (!status) status = 'draft';
    return '<span class="status-badge ' + escapeHtml(status) + '">' + escapeHtml(statusLabel(status)) + '</span>';
  }

  function truncate(s, n) {
    if (!s) return '';
    return s.length > n ? s.substring(0, n) + '...' : s;
  }

  function standardBadge(concept) {
    var sc = concept.standardConcept;
    if (sc === 'S') return '<span class="badge badge-standard">' + escapeHtml(i18n('Standard')) + '</span>';
    if (sc === 'C') return '<span class="badge badge-classification">' + escapeHtml(i18n('Classification')) + '</span>';
    return '<span class="badge badge-non-standard">' + escapeHtml(i18n('Non-standard')) + '</span>';
  }

  function validBadge(concept) {
    var v = concept.invalidReasonCaption;
    if (v === 'Valid') return '<span class="badge badge-valid">' + escapeHtml(i18n('Valid')) + '</span>';
    return '<span class="badge badge-invalid">' + escapeHtml(v) + '</span>';
  }

  // ==================== MULTI-SELECT DROPDOWN ====================
  function buildMultiSelectDropdown(containerId, values, selectedSet, onChange, labelMap) {
    var container = document.getElementById(containerId);
    if (!container) return;
    function getLabel(v) { return labelMap ? (labelMap[v] || v) : v; }
    function toggleLabel() {
      if (selectedSet.size === 0) return i18n('All');
      if (selectedSet.size === 1) return escapeHtml(getLabel([...selectedSet][0]));
      return selectedSet.size + ' ' + i18n('selected');
    }
    var showSearch = values.length > 10;
    container.innerHTML =
      '<div class="ms-toggle" tabindex="0">' + toggleLabel() + ' <i class="fas fa-chevron-down" style="font-size:9px;margin-left:2px"></i></div>' +
      '<div class="ms-dropdown" style="display:none">' +
        (showSearch ? '<div class="ms-search-wrap"><input type="text" class="ms-search" placeholder="' + escapeHtml(i18n('Search')) + '…"></div>' : '') +
        '<div class="ms-options">' +
          values.map(function(v) {
            return '<label class="ms-option"><input type="checkbox" value="' + escapeHtml(v) + '"' + (selectedSet.has(v) ? ' checked' : '') + '> ' + escapeHtml(getLabel(v) || '(empty)') + '</label>';
          }).join('') +
        '</div>' +
      '</div>';
    var toggle = container.querySelector('.ms-toggle');
    var dropdown = container.querySelector('.ms-dropdown');
    var searchInput = container.querySelector('.ms-search');
    toggle.addEventListener('click', function(e) {
      e.stopPropagation();
      document.querySelectorAll('.ms-dropdown').forEach(function(d) { if (d !== dropdown) d.style.display = 'none'; });
      var wasHidden = dropdown.style.display === 'none';
      dropdown.style.display = wasHidden ? '' : 'none';
      if (wasHidden && searchInput) { searchInput.value = ''; searchInput.dispatchEvent(new Event('input')); searchInput.focus(); }
    });
    if (searchInput) {
      searchInput.addEventListener('input', function() {
        var q = searchInput.value.toLowerCase();
        container.querySelectorAll('.ms-option').forEach(function(opt) {
          var label = opt.textContent.toLowerCase();
          opt.style.display = label.indexOf(q) !== -1 ? '' : 'none';
        });
      });
      searchInput.addEventListener('click', function(e) { e.stopPropagation(); });
    }
    dropdown.addEventListener('change', function(e) {
      var cb = e.target;
      if (cb.checked) selectedSet.add(cb.value); else selectedSet.delete(cb.value);
      toggle.innerHTML = toggleLabel() + ' <i class="fas fa-chevron-down" style="font-size:9px;margin-left:2px"></i>';
      onChange();
    });
  }

  function updateMsToggleLabel(containerId, selectedSet) {
    var container = document.getElementById(containerId);
    if (!container) return;
    var toggle = container.querySelector('.ms-toggle');
    if (toggle) {
      toggle.innerHTML = (selectedSet.size === 0 ? i18n('All') : selectedSet.size === 1 ? escapeHtml([...selectedSet][0]) : selectedSet.size + ' ' + i18n('selected')) + ' <i class="fas fa-chevron-down" style="font-size:9px;margin-left:2px"></i>';
    }
  }

  // ==================== USER PROFILE ====================
  function getUserProfile() {
    try { return JSON.parse(localStorage.getItem('indicate_reviewer') || '{}'); } catch(e) { return {}; }
  }

  function saveUserProfile(profile) {
    try { localStorage.setItem('indicate_reviewer', JSON.stringify(profile)); } catch(e) {}
    updateUserBadge();
  }

  function updateUserBadge() {
    var p = getUserProfile();
    var name = ((p.firstName || '') + ' ' + (p.lastName || '')).trim();
    var el = document.getElementById('user-badge-name');
    if (el) el.textContent = name || i18n('Guest');
  }

  function getKnownAuthors() {
    var seen = {};
    var authors = [];
    conceptSets.forEach(function(cs) {
      var d = cs.metadata && cs.metadata.createdByDetails;
      if (!d || !d.firstName || !d.lastName) return;
      var key = (d.firstName + ' ' + d.lastName).toLowerCase();
      if (seen[key]) return;
      seen[key] = true;
      authors.push({ firstName: d.firstName, lastName: d.lastName, affiliation: d.affiliation || '', profession: d.profession || '', orcid: d.orcid || '' });
    });
    authors.sort(function(a, b) { return (a.lastName + a.firstName).localeCompare(b.lastName + b.firstName); });
    return authors;
  }

  function populateAuthorSelect(currentProfile) {
    var select = document.getElementById('profile-select-author');
    if (!select) return;
    var authors = getKnownAuthors();
    select.innerHTML = '<option value="">' + escapeHtml(i18n('— Custom —')) + '</option>';
    authors.forEach(function(a, i) {
      var opt = document.createElement('option');
      opt.value = i;
      opt.textContent = a.firstName + ' ' + a.lastName + (a.affiliation ? ' — ' + a.affiliation : '');
      select.appendChild(opt);
    });
    if (currentProfile && currentProfile.firstName && currentProfile.lastName) {
      var key = (currentProfile.firstName + ' ' + currentProfile.lastName).toLowerCase();
      authors.forEach(function(a, i) {
        if ((a.firstName + ' ' + a.lastName).toLowerCase() === key) select.value = i;
      });
    }
    select._authors = authors;
  }

  function openProfileModal() {
    var p = getUserProfile();
    populateAuthorSelect(p);
    document.getElementById('profile-firstName').value = p.firstName || '';
    document.getElementById('profile-lastName').value = p.lastName || '';
    document.getElementById('profile-affiliation').value = p.affiliation || '';
    document.getElementById('profile-profession').value = p.profession || '';
    document.getElementById('profile-orcid').value = p.orcid || '';
    document.getElementById('profile-modal').style.display = '';
  }

  function closeProfileModal() {
    document.getElementById('profile-modal').style.display = 'none';
  }

  function saveProfileFromModal() {
    var firstName = document.getElementById('profile-firstName').value.trim();
    var lastName = document.getElementById('profile-lastName').value.trim();
    if (!firstName || !lastName) {
      showToast(i18n('First name and last name are required.'), 'error');
      return;
    }
    saveUserProfile({
      firstName: firstName,
      lastName: lastName,
      affiliation: document.getElementById('profile-affiliation').value.trim(),
      profession: document.getElementById('profile-profession').value.trim(),
      orcid: document.getElementById('profile-orcid').value.trim()
    });
    closeProfileModal();
  }

  // ==================== ORGANIZATION ====================
  function getOrganization() {
    try {
      var saved = JSON.parse(localStorage.getItem('indicate_organization') || 'null');
      if (saved) return saved;
      return detectDefaultOrganization();
    } catch(e) { return null; }
  }

  function saveOrganization(org) {
    try { localStorage.setItem('indicate_organization', JSON.stringify(org)); } catch(e) {}
    updateOrgBadge();
  }

  function detectDefaultOrganization() {
    // Scan concept sets for a unique organization; use it as default
    var orgs = {};
    conceptSets.forEach(function(cs) {
      var o = cs.metadata && cs.metadata.organization;
      if (o && o.name) {
        var key = o.name.toLowerCase();
        if (!orgs[key]) orgs[key] = o;
      }
    });
    var keys = Object.keys(orgs);
    if (keys.length === 1) return orgs[keys[0]];
    return null;
  }

  function updateOrgBadge() {
    var org = getOrganization();
    if (!org) org = detectDefaultOrganization();
    var el = document.getElementById('org-badge-name');
    if (el) el.textContent = (org && org.name) ? org.name : i18n('Organization');
  }

  function openOrgModal() {
    var org = getOrganization();
    if (!org) org = detectDefaultOrganization() || {};
    document.getElementById('org-name').value = org.name || '';
    document.getElementById('org-url').value = org.url || '';
    document.getElementById('org-modal').style.display = '';
  }

  function closeOrgModal() {
    document.getElementById('org-modal').style.display = 'none';
  }

  function saveOrgFromModal() {
    var name = document.getElementById('org-name').value.trim();
    if (!name) {
      showToast(i18n('Organization name is required.'), 'error');
      return;
    }
    saveOrganization({
      name: name,
      url: document.getElementById('org-url').value.trim()
    });
    closeOrgModal();
    showToast(i18n('Organization saved'));
  }

  // ==================== SHARED EVENTS ====================
  function initSharedEvents() {
    // Language toggle
    var langBtn = document.getElementById('lang-toggle');
    if (langBtn) {
      langBtn.textContent = lang.toUpperCase();
      langBtn.addEventListener('click', function() {
        lang = lang === 'en' ? 'fr' : 'en';
        localStorage.setItem('indicate_lang', lang);
        langBtn.textContent = lang.toUpperCase();
        translateDOM();
        updateUserBadge();
        updateOrgBadge();
        languageChangeCallbacks.forEach(function(cb) { cb(); });
      });
    }

    // User profile modal events
    var userBadge = document.getElementById('user-badge');
    if (userBadge) userBadge.addEventListener('click', openProfileModal);

    var profileClose = document.getElementById('profile-modal-close');
    if (profileClose) profileClose.addEventListener('click', closeProfileModal);

    var profileCancel = document.getElementById('profile-cancel');
    if (profileCancel) profileCancel.addEventListener('click', closeProfileModal);

    var profileSave = document.getElementById('profile-save');
    if (profileSave) profileSave.addEventListener('click', saveProfileFromModal);

    var profileSelect = document.getElementById('profile-select-author');
    if (profileSelect) {
      profileSelect.addEventListener('change', function() {
        var select = this;
        var authors = select._authors;
        if (select.value === '' || !authors) return;
        var a = authors[parseInt(select.value)];
        if (!a) return;
        document.getElementById('profile-firstName').value = a.firstName;
        document.getElementById('profile-lastName').value = a.lastName;
        document.getElementById('profile-affiliation').value = a.affiliation;
        document.getElementById('profile-profession').value = a.profession;
        document.getElementById('profile-orcid').value = a.orcid;
      });
    }

    var profileModal = document.getElementById('profile-modal');
    if (profileModal) {
      profileModal.addEventListener('click', function(e) {
        if (e.target === profileModal) closeProfileModal();
      });
    }

    // Organization modal events
    var orgBadge = document.getElementById('org-badge');
    if (orgBadge) orgBadge.addEventListener('click', openOrgModal);

    var orgClose = document.getElementById('org-modal-close');
    if (orgClose) orgClose.addEventListener('click', closeOrgModal);

    var orgCancel = document.getElementById('org-cancel');
    if (orgCancel) orgCancel.addEventListener('click', closeOrgModal);

    var orgSave = document.getElementById('org-save');
    if (orgSave) orgSave.addEventListener('click', saveOrgFromModal);

    var orgModal = document.getElementById('org-modal');
    if (orgModal) {
      orgModal.addEventListener('click', function(e) {
        if (e.target === orgModal) closeOrgModal();
      });
    }

    // Reset cache
    var resetBtn = document.getElementById('reset-cache-btn');
    if (resetBtn) {
      resetBtn.addEventListener('click', function() {
        document.getElementById('confirm-reset-modal').style.display = '';
      });
    }
    var confirmResetClose = document.getElementById('confirm-reset-close');
    if (confirmResetClose) {
      confirmResetClose.addEventListener('click', function() {
        document.getElementById('confirm-reset-modal').style.display = 'none';
      });
    }
    var confirmResetCancel = document.getElementById('confirm-reset-cancel');
    if (confirmResetCancel) {
      confirmResetCancel.addEventListener('click', function() {
        document.getElementById('confirm-reset-modal').style.display = 'none';
      });
    }
    var confirmResetOk = document.getElementById('confirm-reset-ok');
    if (confirmResetOk) {
      confirmResetOk.addEventListener('click', function() {
        localStorage.clear();
        window.location.reload();
      });
    }
    var confirmResetModal = document.getElementById('confirm-reset-modal');
    if (confirmResetModal) {
      confirmResetModal.addEventListener('click', function(e) {
        if (e.target === this) this.style.display = 'none';
      });
    }

    // Settings dropdown
    var navSettingsBtn = document.getElementById('nav-settings-btn');
    var navSettingsMenu = document.getElementById('nav-settings-menu');
    if (navSettingsBtn && navSettingsMenu) {
      navSettingsBtn.addEventListener('click', function(e) {
        e.stopPropagation();
        navSettingsMenu.style.display = navSettingsMenu.style.display === 'none' ? '' : 'none';
      });
    }

    // Close multi-select dropdowns and nav dropdown on outside click
    document.addEventListener('click', function(e) {
      if (!e.target.closest('.ms-container')) {
        document.querySelectorAll('.ms-dropdown').forEach(function(d) { d.style.display = 'none'; });
      }
      if (!e.target.closest('.nav-dropdown')) {
        var menu = document.getElementById('nav-settings-menu');
        if (menu) menu.style.display = 'none';
      }
    });

    // Header logo/title click -> go home (with unsaved-changes check)
    var headerLeft = document.querySelector('.header-left');
    if (headerLeft && headerLeft.tagName !== 'A') {
      headerLeft.addEventListener('click', function() {
        for (var i = 0; i < beforeNavigateCallbacks.length; i++) {
          if (beforeNavigateCallbacks[i]() === false) return;
        }
        // Navigate to concept sets list and force show even if already on that route
        var current = Router.getCurrentRoute();
        if (current && current.path === '/concept-sets' && !current.query.cs && !current.query.id) {
          // Already on list view, trigger homeCallbacks to close detail if open
          for (var j = 0; j < homeCallbacks.length; j++) homeCallbacks[j]();
        } else {
          Router.navigate('/concept-sets');
          // Also trigger homeCallbacks to ensure detail closes
          for (var j = 0; j < homeCallbacks.length; j++) homeCallbacks[j]();
        }
      });
    }
  }

  // ==================== USER CONCEPT SETS ====================
  function nextConceptSetId() {
    var maxId = 0;
    conceptSets.forEach(function(cs) { if (cs.id > maxId) maxId = cs.id; });
    return maxId + 1;
  }

  function saveUserConceptSets() {
    localStorage.setItem('indicate_user_cs', JSON.stringify(userConceptSets));
  }

  function addConceptSet(cs) {
    conceptSets.push(cs);
    userConceptSets.push(cs);
    saveUserConceptSets();
  }

  function updateConceptSet(cs) {
    for (var i = 0; i < conceptSets.length; i++) {
      if (conceptSets[i].id === cs.id) { conceptSets[i] = cs; break; }
    }
    // Promote to userConceptSets if not already there
    var found = false;
    for (var j = 0; j < userConceptSets.length; j++) {
      if (userConceptSets[j].id === cs.id) { userConceptSets[j] = cs; found = true; break; }
    }
    if (!found) userConceptSets.push(cs);
    saveUserConceptSets();
  }

  function deleteConceptSets(ids) {
    var idSet = {};
    ids.forEach(function(id) { idSet[id] = true; });
    userConceptSets = userConceptSets.filter(function(cs) { return !idSet[cs.id]; });
    var before = conceptSets.length;
    conceptSets = conceptSets.filter(function(cs) { return !idSet[cs.id]; });
    var deleted = before - conceptSets.length;
    // Track deleted repo IDs so they stay hidden on reload
    var hidden = JSON.parse(localStorage.getItem('indicate_hidden_cs') || '[]');
    ids.forEach(function(id) { if (hidden.indexOf(id) < 0) hidden.push(id); });
    localStorage.setItem('indicate_hidden_cs', JSON.stringify(hidden));
    saveUserConceptSets();
    return { deleted: deleted, skipped: 0 };
  }

  function isUserConceptSet(id) {
    return userConceptSets.some(function(cs) { return cs.id === id; });
  }

  function restoreConceptSets(allSnapshot, userSnapshot) {
    conceptSets.length = 0;
    allSnapshot.forEach(function(cs) { conceptSets.push(cs); });
    userConceptSets = userSnapshot;
    saveUserConceptSets();
  }

  // ==================== USER PROJECTS ====================
  function nextProjectId() {
    var maxId = 0;
    projects.forEach(function(p) { if (p.id > maxId) maxId = p.id; });
    return maxId + 1;
  }

  function saveUserProjects() {
    localStorage.setItem('indicate_user_proj', JSON.stringify(userProjects));
  }

  function addProject(proj) {
    projects.push(proj);
    userProjects.push(proj);
    saveUserProjects();
  }

  function updateProject(proj) {
    for (var i = 0; i < projects.length; i++) {
      if (projects[i].id === proj.id) { projects[i] = proj; break; }
    }
    var found = false;
    for (var j = 0; j < userProjects.length; j++) {
      if (userProjects[j].id === proj.id) { userProjects[j] = proj; found = true; break; }
    }
    if (!found) userProjects.push(proj);
    saveUserProjects();
  }

  function deleteProject(id) {
    userProjects = userProjects.filter(function(p) { return p.id !== id; });
    projects = projects.filter(function(p) { return p.id !== id; });
    var hidden = JSON.parse(localStorage.getItem('indicate_hidden_proj') || '[]');
    if (hidden.indexOf(id) < 0) hidden.push(id);
    localStorage.setItem('indicate_hidden_proj', JSON.stringify(hidden));
    saveUserProjects();
  }

  // ==================== GETCSDATA ====================
  function getCSData() {
    return conceptSets.map(function(cs) {
      var tr = t(cs);
      return {
        id: cs.id,
        name: tr.name || cs.name,
        category: tr.category || '',
        subcategory: tr.subcategory || '',
        description: cs.description || '',
        reviewStatus: (cs.metadata && cs.metadata.reviewStatus) || 'draft',
        version: cs.version || '',
        concepts: (cs.expression && cs.expression.items) ? cs.expression.items.length : 0,
        modified: cs.modifiedDate || cs.createdDate || '',
        raw: cs
      };
    });
  }

  // ==================== COLUMN RESIZE ====================
  /**
   * Make table columns resizable by adding drag handles to header cells.
   * Call once per table. Handles are added to the first <tr> in <thead>.
   * Widths are locked on first drag so hidden tables work correctly.
   * @param {string} tableId - the table element id
   */
  function initColResize(tableId) {
    var table = document.getElementById(tableId);
    if (!table || table._colResizeInit) return;
    table._colResizeInit = true;

    var headerRow = table.querySelector('thead tr');
    if (!headerRow) return;
    var ths = Array.prototype.slice.call(headerRow.querySelectorAll('th'));

    function lockWidths() {
      if (table.classList.contains('col-resizable')) return;
      table.classList.add('col-resizable');
      ths.forEach(function(th) {
        th.style.width = th.offsetWidth + 'px';
      });
    }

    // Add resize handles
    ths.forEach(function(th, idx) {
      if (idx === ths.length - 1) return; // skip last column
      var handle = document.createElement('div');
      handle.className = 'col-resize-handle';
      th.appendChild(handle);

      handle.addEventListener('mousedown', function(e) {
        e.preventDefault();
        e.stopPropagation();
        lockWidths();
        handle.classList.add('dragging');
        document.body.style.cursor = 'col-resize';
        document.body.style.userSelect = 'none';
        var startX = e.clientX;
        var startW = th.offsetWidth;
        var nextTh = ths[idx + 1];
        var nextStartW = nextTh ? nextTh.offsetWidth : 0;

        function onMove(ev) {
          var dx = ev.clientX - startX;
          var newW = Math.max(40, startW + dx);
          th.style.width = newW + 'px';
          if (nextTh) {
            var newNextW = Math.max(40, nextStartW - dx);
            nextTh.style.width = newNextW + 'px';
          }
        }
        function onUp() {
          handle.classList.remove('dragging');
          document.body.style.cursor = '';
          document.body.style.userSelect = '';
          document.removeEventListener('mousemove', onMove);
          document.removeEventListener('mouseup', onUp);
        }
        document.addEventListener('mousemove', onMove);
        document.addEventListener('mouseup', onUp);
      });
    });
  }

  // ==================== PUBLIC API ====================
  return {
    APP_NAME: APP_NAME,
    APP_VERSION: APP_VERSION,
    // State getters/setters
    get conceptSets() { return conceptSets; },
    get projects() { return projects; },
    get unitConversions() { return unitConversions; },
    get recommendedUnits() { return recommendedUnits; },
    get etlGuidelines() { return etlGuidelines; },
    get lang() { return lang; },
    set lang(v) { lang = v; },
    get resolvedIndex() { return resolvedIndex; },
    get sessionReviews() { return sessionReviews; },
    set sessionReviews(v) { sessionReviews = v; localStorage.setItem('indicate_reviews', JSON.stringify(v)); },
    saveSessionReviews: function() { localStorage.setItem('indicate_reviews', JSON.stringify(sessionReviews)); },
    get statusLabelsMap() { return statusLabelsMap; },

    // Functions
    loadData: loadData,
    t: t,
    tProj: tProj,
    escapeHtml: escapeHtml,
    showToast: showToast,
    renderMarkdown: renderMarkdown,
    fuzzyMatch: fuzzyMatch,
    fuzzyFilter: fuzzyFilter,
    statusBadge: statusBadge,
    truncate: truncate,
    standardBadge: standardBadge,
    validBadge: validBadge,
    buildMultiSelectDropdown: buildMultiSelectDropdown,
    updateMsToggleLabel: updateMsToggleLabel,
    getUserProfile: getUserProfile,
    saveUserProfile: saveUserProfile,
    updateUserBadge: updateUserBadge,
    getKnownAuthors: getKnownAuthors,
    openProfileModal: openProfileModal,
    closeProfileModal: closeProfileModal,
    getOrganization: getOrganization,
    updateOrgBadge: updateOrgBadge,
    initSharedEvents: initSharedEvents,
    getCSData: getCSData,
    onLanguageChange: function(cb) { languageChangeCallbacks.push(cb); },
    onBeforeNavigate: function(cb) { beforeNavigateCallbacks.push(cb); },
    onHome: function(cb) { homeCallbacks.push(cb); },
    nextConceptSetId: nextConceptSetId,
    addConceptSet: addConceptSet,
    updateConceptSet: updateConceptSet,
    deleteConceptSets: deleteConceptSets,
    isUserConceptSet: isUserConceptSet,
    saveUserConceptSets: saveUserConceptSets,
    restoreConceptSets: restoreConceptSets,
    initColResize: initColResize,
    nextProjectId: nextProjectId,
    addProject: addProject,
    updateProject: updateProject,
    deleteProject: deleteProject,
    i18n: i18n,
    formatDate: formatDate,
    translateDOM: translateDOM,
    statusLabel: statusLabel
  };
})();

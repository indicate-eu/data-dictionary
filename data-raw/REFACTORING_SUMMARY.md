# Refactoring Summary: concept_mappings.csv Structure Change

## Objectif
Restructurer les fichiers CSV pour éviter de stocker des données sous licence (SNOMED, etc.) et ne garder que les identifiants OMOP pour faire des jointures dynamiques avec les tables OMOP.

## Changements effectués

### 1. Fichiers CSV créés

#### a) `concept_mappings.csv` (allégé)
**Anciennes colonnes** : `general_concept_id`, `concept_name`, `vocabulary_id`, `concept_code`, `omop_concept_id`, `recommended`, `unit_concept_code`, `omop_unit_concept_id`, `data_type`, `omop_table`, `omop_column`, `omop_domain_id`, `ehden_rows_count`, `ehden_num_data_sources`, `loinc_rank`

**Nouvelles colonnes** : `general_concept_id`, `omop_concept_id`, `omop_unit_concept_id`, `recommended`

**Contenu** : 610 lignes (concepts avec OMOP IDs uniquement)

#### b) `concept_statistics.csv` (nouveau)
**Colonnes** : `omop_concept_id`, `loinc_rank`, `ehden_rows_count`, `ehden_num_data_sources`

**Contenu** : 610 lignes (statistiques EHDEN et LOINC)

#### c) `custom_concepts.csv` (nouveau)
**Colonnes** : `general_concept_id`, `vocabulary_id`, `concept_code`, `concept_name`, `omop_unit_concept_id`, `recommended`

**Contenu** : 9 lignes (concepts INDICATE custom sans omop_concept_id)

### 2. Code modifié

#### a) `R/utils_data_csv.R`
- ✅ Ajout du chargement de `concept_statistics.csv`
- ✅ Ajout du chargement de `custom_concepts.csv`
- ✅ Retour des 3 nouveaux data frames dans la liste

#### b) `R/mod_dictionary_explorer.R` (ligne ~1443-1463)
- ✅ Simplifié la création de nouveaux concepts pour n'inclure que les colonnes minimales
- ✅ Supprimé les références aux colonnes `concept_name`, `vocabulary_id`, `concept_code` lors de l'ajout de concepts

## Changements restants à faire

### 1. Gestion des statistiques EHDEN (CRITIQUE)

**Localisation** : `R/mod_dictionary_explorer.R` lignes ~1363-1400

**Problème** : Le code modifie directement `concept_mappings` pour mettre à jour `ehden_num_data_sources`, `ehden_rows_count`, et `loinc_rank`, mais ces colonnes n'existent plus dans `concept_mappings`.

**Solution** :
- Modifier le code pour mettre à jour `concept_statistics` au lieu de `concept_mappings`
- S'assurer que `concept_statistics` est aussi sauvegardé lors des modifications

```r
# Ancien code (à remplacer)
concept_mappings <- concept_mappings %>%
  dplyr::mutate(
    ehden_num_data_sources = ifelse(...)
  )

# Nouveau code (à implémenter)
concept_statistics <- concept_statistics %>%
  dplyr::mutate(
    ehden_num_data_sources = ifelse(
      omop_concept_id == selected_omop_id,
      as.character(new_ehden_data_sources),
      ehden_num_data_sources
    )
  )
```

### 2. Affichage des statistiques dans les détails (CRITIQUE)

**Localisation** : `R/mod_dictionary_explorer.R` lignes ~2489-2494

**Problème** : Le code accède directement à `info$ehden_num_data_sources`, `info$ehden_rows_count`, `info$loinc_rank` mais ces colonnes ne sont plus dans `concept_mappings`.

**Solution** :
- Faire une jointure avec `concept_statistics` avant d'afficher les détails
- Exemple :

```r
# Jointure avec les statistiques
if (!is.null(vocab_data)) {
  concept_stats <- current_data()$concept_statistics %>%
    dplyr::filter(omop_concept_id == !!omop_concept_id)

  if (nrow(concept_stats) > 0) {
    ehden_num_sources <- concept_stats$ehden_num_data_sources[1]
    ehden_rows <- concept_stats$ehden_rows_count[1]
    loinc_rank_val <- concept_stats$loinc_rank[1]
  } else {
    ehden_num_sources <- NA
    ehden_rows <- NA
    loinc_rank_val <- NA
  }
}
```

### 3. Affichage des concepts custom INDICATE (IMPORTANT)

**Problème** : Les concepts INDICATE (vocabulary_id = "INDICATE") n'ont pas d'omop_concept_id et doivent être affichés depuis `custom_concepts.csv`.

**Solution** :
- Détecter si le concept est de type INDICATE
- Si oui, charger les informations depuis `custom_concepts` au lieu de faire une jointure OMOP
- Exemple :

```r
# Dans la section d'affichage des détails
csv_mapping <- current_data()$concept_mappings %>%
  dplyr::filter(
    general_concept_id == concept_id,
    omop_concept_id == !!omop_concept_id
  )

if (nrow(csv_mapping) > 0) {
  # Concept OMOP standard
  # ... code actuel ...
} else {
  # Peut-être un concept custom INDICATE
  custom_concept <- current_data()$custom_concepts %>%
    dplyr::filter(general_concept_id == concept_id)

  if (nrow(custom_concept) > 0) {
    info <- custom_concept[1, ]
    # Utiliser info$concept_name, info$vocabulary_id, etc.
  }
}
```

### 4. Sauvegarde des modifications (CRITIQUE)

**Localisation** : `R/mod_dictionary_explorer.R` lignes ~1496-1513

**Problème** : Le code ne sauvegarde que `general_concepts` et `concept_mappings`, mais pas `concept_statistics` ni `custom_concepts`.

**Solution** :
```r
# Ajouter à la section de sauvegarde
readr::write_csv(
  concept_statistics,
  app_sys("extdata", "csv", "concept_statistics.csv")
)

readr::write_csv(
  custom_concepts,
  app_sys("extdata", "csv", "custom_concepts.csv")
)

# Mettre à jour local_data
updated_data <- list(
  general_concepts = general_concepts,
  concept_mappings = concept_mappings,
  concept_statistics = concept_statistics,
  custom_concepts = custom_concepts
)
local_data(updated_data)
```

### 5. Conversion script (À FAIRE PLUS TARD)

**Localisation** : `data-raw/convert_excel_to_csv.R`

**Action** : Mettre à jour le script de conversion Excel → CSV pour générer les 3 nouveaux fichiers au lieu d'un seul.

## Fichiers à nettoyer

- `inst/extdata/csv/concept_mappings_old.csv` : à supprimer après vérification
- `data-raw/restructure_concept_mappings.R` : peut être conservé comme référence ou supprimé

## Tests à effectuer

1. ✅ Vérifier que l'application démarre sans erreur
2. ⏳ Vérifier l'affichage de la liste des concepts
3. ⏳ Vérifier l'affichage des détails d'un concept OMOP standard
4. ⏳ Vérifier l'affichage des détails d'un concept INDICATE custom
5. ⏳ Vérifier la modification des statistiques EHDEN
6. ⏳ Vérifier l'ajout d'un nouveau concept
7. ⏳ Vérifier la sauvegarde des modifications

## Notes importantes

- Les concepts avec `omop_concept_id` : informations récupérées depuis les tables OMOP + statistiques depuis `concept_statistics.csv`
- Les concepts INDICATE custom (sans omop_concept_id) : toutes les informations stockées dans `custom_concepts.csv`
- La structure permet de respecter les licences en ne stockant que les IDs OMOP, pas les noms/codes sous licence

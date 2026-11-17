# AGENTS.md

## Typ repozytorium
Projekt Dataform/GA4 BigQuery do modelowania danych. Skupiony na SQL, nie typowym kodzie.

## Struktura
- `ga4_flattened_data_model/` — Główny projekt Dataform (definicje w 1_pre/, 2_outputs/, 3_attribution/, 4_reports/)
- `ga4_flattened_data_model_sql_edu/` — Wariant edukacyjny

## Polecenia deweloperskie
- Dataform: `dataform compile`, `dataform run`
- Brak build/test/lint — to tylko definicje SQL

## Kluczowe pliki
- `dataform.json` w każdym projekcie Dataform — konfiguracja warehouse (BigQuery, domyślna lokalizacja: EU)

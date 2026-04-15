# AGENTS.md

## Typ repozytorium
Projekt Dataform/GA4 BigQuery do modelowania danych. Skupiony na SQL, nie typowym kodzie.

## Struktura
- `ga4_flattened_data_model/` — Główny projekt Dataform (definicje w 1_pre/, 2_outputs/, 3_attribution/, 4_reports/)
- `ga4_flattened_data_model_sql/` — Wariant SQL
- `ga4_flattened_data_model_sql_edu/` — Wariant edukacyjny
- `scratch/` — Eksperymentalne zapytania
- `stitch_mcp.json` — Konfiguracja serwera MCP dla Stitch API

## Polecenia deweloperskie
- Dataform: `dataform compile`, `dataform run`
- Serwer MCP uruchamiamy przez: `npx -y mcp-remote https://stitch.googleapis.com/mcp` (wymaga Node v24.11.0, ładuje STITCH_API_KEY z .env)
- Brak build/test/lint — to tylko definicje SQL

## opencode.json
Niestandardowi agenci skonfigurowani dla polskojęzycznej analizy GA4/BigQuery. Narzędzia wyłączone (tryb tylko do odczytu). Używa modeli Claude.

## Środowisko
- `.env` zawiera GEMINI_API_KEY i STITCH_API_KEY
- OpenCode zainstalowany globalnie (wymaga Node v24.11.0 do MCP Stitch)

## Kluczowe pliki
- `dataform.json` w każdym projekcie Dataform — konfiguracja warehouse (BigQuery, domyślna lokalizacja: EU)
- `stitch_mcp.json` — polecenie uruchomienia serwera MCP
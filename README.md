# GA4-Flattened-Data-Model-Vibe

Projekt do modelowania danych Google Analytics 4 (GA4) w BigQuery. Udostępnia zestaw zmaterializowanych tabel SQLx (Dataform) które spłaszczają surowe dane `events_*` z GA4 do czytelnej struktury gotowej do analizy i raportowania.

Główne tabele: sesje z atrybucją (first-click, last-non-direct, linear), transakcje, produkty. Model danych jest gotowy do podłączenia pod BI (Looker Studio, Metabase, Power BI).

---

## Struktura projektu

`ls -la /Users/p/Documents/dev/GA4-Flattened-Data-Model-Vibe/`

```
GA4-Flattened-Data-Model-Vibe/
├── .env                     # Zmienne środowiskowe (API keys)
├── .git/                    # Repo git - historia wersji
├── .gitignore               # Wykluczenia z git (np. .env)
├── .opencode/               # Konfiguracja OpenCode
│   ├── .gitignore           # Wykluczenia dla .opencode
│   └── skills/              # Skill dataform-helper - wiedza o projekcie
│       └── dataform-helper/
├── AGENTS.md                # Instrukcje dla agenta AI
├── ga4_flattened_data_model/        # Główny projekt Dataform (.sqlx)
├── ga4_flattened_data_model_sql_edu/ # Wariant edukacyjny SQL
├── opencode.json            # Konfiguracja agentów OpenCode
├── scratch/                 # Eksperymentalne zapytania / testy
└── stitch_mcp.json          # Konfiguracja MCP Stitch API
```

---

## Wymagania

- Google Cloud Platform z włączonym BigQuery
- Dataform CLI (`npm install -g @dataform/cli`)
- Node.js v18+
- OpenCode (opcjonalnie - do pracy z agentem AI)

## Setup

1. Sklonuj repo i zainstaluj zależności:
```bash
npm install
```

2. Skonfiguruj `.env`:
```bash
# Dodaj swoje zmienne (GCP_PROJECT_ID, API keys)
```

3. Skompiluj i uruchom:
```bash
dataform compile
dataform run
```

## Licencja

MIT

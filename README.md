# GA4 Flattened Data Model

Projekt do modelowania danych Google Analytics 4 (GA4) w BigQuery. Udostępnia zestaw zmaterializowanych tabel SQLx (Dataform) które spłaszczają surowe dane `events_*` z GA4 do czytelnej struktury gotowej do analizy i raportowania.

Główne tabele: sesje z atrybucją (first-click, last-non-direct, linear), transakcje, produkty. Model danych jest gotowy do podłączenia pod BI (Looker Studio, Metabase, Power BI).

---

## Struktura projektu

```
ga4-flattened-data-model/
├── ga4_flattened_data_model/          # Główny projekt Dataform (.sqlx)
│   └── definitions/
│       ├── sources/                   # Źródło: eksport GA4 events_*
│       ├── 1_pre/                     # Preprocessing zdarzeń i sesji
│       ├── 2_outputs/                 # Sesje i ujednolicony identyfikator użytkownika
│       ├── 3_attribution/             # Atrybucja: first-click, last-non-direct, linear
│       └── 4_reports/                 # Transakcje i produkty
├── ga4_flattened_data_model_sql_edu/  # Ten sam model w plikach .sql z komentarzami krok po kroku
└── AGENTS.md                          # Instrukcje dla agenta AI
```

---

## Wymagania

- Google Cloud Platform z włączonym BigQuery
- Dataform CLI (`npm install -g @dataform/cli`)
- Node.js v18+

## Setup

1. Zainstaluj Dataform CLI:
```bash
npm i -g @dataform/cli
```

2. W `ga4_flattened_data_model/dataform.json` podmień `defaultDatabase` (`your-gcp-project-id`) na swój projekt GCP.

3. Dodaj w katalogu projektu plik `.df-credentials.json` z `projectId` i `location`. Bez pola `credentials` CLI użyje Application Default Credentials.

4. Skompiluj i uruchom:
```bash
cd ga4_flattened_data_model
dataform compile
dataform run
```

## Licencja

MIT

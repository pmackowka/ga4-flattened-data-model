---
name: dataform-helper
description: Kompleksowy helper do projektów Dataform i modelowania danych GA4/BigQuery w repozytorium Wipecoding
---

# 📚 Dataform Helper — Wipecoding Project

## Spis treści
1. [Architektura projektu](#architektura-projektu)
2. [Wykonywanie zadań przez agenta](#wykonywanie-zadań-przez-agenta)
3. [Konwencje i standardy kodowania](#konwencje-i-standardy-kodowania)
4. [Schemat danych GA4](#schemat-danych-ga4)
5. [Modele atrybucji](#modele-atrybucji)
6. [Code Review — najlepsze praktyki](#code-review--najlepsze-praktyki)
7. [Współpraca z Git](#współpraca-z-git)
8. [Wytyczne dla uczestników projektu](#wytyczne-dla-uczestników-projektu)
9. [Rozwiązywanie problemów](#rozwiązywanie-problemów)

---

## Architektura projektu

### Struktura katalogów

```
Vibe-coding/
├── ga4_flattened_data_model/          # Główny projekt Dataform (.sqlx)
│   ├── dataform.json                   # Konfiguracja: ga4_flattened, BigQuery, EU
│   └── definitions/
│       ├── sources/                    # Definicje źródeł danych
│       │   └── ga4_events.sqlx          # Tabela źródłowa events_* 
│       ├── 1_pre/                      # Preprocessing
│       │   ├── ga4_pre_events.sqlx      # Ekstrakcja parametrów, standaryzacja źródeł
│       │   └── ga4_pre_sessions.sqlx    # Agregacja sesji
│       ├── 2_outputs/                  # Tabele wynikowe
│       │   ├── ga4_unified_id.sqlx      # Unikalne ID użytkownika
│       │   └── ga4_sessions.sqlx        # Sesje z atrybucją
│       ├── 3_attribution/               # Modele atrybucji
│       │   ├── ga4_attribution_first_click.sqlx
│       │   ├── ga4_attribution_last_non_direct.sqlx
│       │   └── ga4_attribution_linear.sqlx
│       └── 4_reports/                   # Raporty końcowe
│           ├── ga4_transactions.sqlx
│           └── ga4_products.sqlx
│
├── ga4_flattened_data_model_sql/       # Wariant czystego SQL
│
├── ga4_flattened_data_model_sql_edu/    # Wariant edukacyjny z komentarzami
│
├── scratch/                             # Eksperymentalne zapytania
│   └── query_mcp.js                     # Przykładowe zapytanie do MCP Stitch API
│
├── .opencode/
│   └── skills/dataform-helper/
│       └── SKILL.md                     # Ten plik
│
└── stitch_mcp.json                      # Konfiguracja MCP Stitch API
```

### Zależności między tabelami (flow danych)

```
events_* (BigQuery native)
    │
    ▼
ga4_pre_events (incremental)
    │
    ▼
ga4_pre_sessions (incremental)
    │
    ├──► ga4_sessions ──► ga4_unified_id ──► 4_reports
    │                                              │
    └──► 3_attribution ◄──────────────────────────┘
           │
           ├── ga4_attribution_first_click
           ├── ga4_attribution_last_non_direct
           └── ga4_attribution_linear
```

### Konfiguracja Dataform

```json
{
  "defaultSchema": "ga4_flattened",
  "assertionSchema": "dataform_assertions",
  "warehouse": "bigquery",
  "defaultDatabase": "your-gcp-project-id",
  "defaultLocation": "EU"
}
```

---

## Wykonywanie zadań przez agenta

### Tryb pracy (zgodnie z opencode.json)

1. **Tryb tylko do odczytu** (analyst-opencode-big-pickle):
   - Narzędzia `write`, `edit`, `bash` wyłączone
   - Agent może analizować, doradzać, wskazywać problemy
   - Przydatny do audytu, eksploracji i rekomendacji

2. **Tryb pełny** (analyst-claude-sonnet, analyst-claude-opus):
   - Wszystkie narzędzia włączone
   - Agent może tworzyć i edytować pliki
   - Wymaga świadomego użycia narzędzi

### Zasady odpowiedzialnego korzystania z narzędzi

#### ✅ KIEDY WOLNO Pisać/Edytować
- Po wyraźnej zgodzie użytkownika ("napisz", "zmodyfikuj", "popraw")
- Po pokazaniu proposed changes i akceptacji
- W katalogu `scratch/` na eksperymenty
- W plikach dokumentacyjnych (*.md) — jeśli nie są krytyczne

#### ❌ KIEDY NIE WOLNO Pisać/Edytować
- Bez pytania użytkownika
- W głównych plikach produkcyjnych (ga4_flattened_data_model/)
- W konfiguracjach (.env, dataform.json)
- Pliki .sqlx bez uprzedniej weryfikacji działania

### Priorytety zadań

1. **Krytyczne** — naprawa błędów w istniejących modelach
2. **Wysokie** — nowe modele zgodne ze schematem
3. **Średnie** — optymalizacja wydajności zapytań
4. **Niskie** — refaktoryzacja, dokumentacja

---

## Konwencje i standardy kodowania

### Nazewnictwo plików

| Typ | Konwencja | Przykład |
|-----|-----------|----------|
| Tabele pre | `ga4_pre_{entity}` | `ga4_pre_events.sqlx` |
| Tabele wyjściowe | `ga4_{entity}` | `ga4_sessions.sqlx` |
| Atrybucja | `ga4_attribution_{model}` | `ga4_attribution_last_non_direct.sqlx` |
| Raporty | `ga4_{report_type}` | `ga4_transactions.sqlx` |
| Źródła | `ga4_{source}` | `ga4_events.sqlx` |

### Nazewnictwo w SQL

```sqlx
-- ✅ Poprawne
final_session_source     -- camelCase, opisowy prefiks
event_timestamp          -- timestamp, nie event_date w tabeli events
session_last_non_direct -- jasne, co oznacza

-- ❌ Unikaj
src                      -- zbyt skrótowe
final                    -- niejednoznaczne
sess                     -- slang
```

### Struktura pliku SQLx

```sqlx
config {
    type: "table" | "incremental" | "view",
    schema: "ga4_flattened",
    description: "Jasny opis co tabela robi.",
    uniqueKey: ["id"]  -- tylko dla incremental
}

-- ============================================
-- SEKCJA 1: Komentarz opisujący logikę
-- ============================================

WITH step_1 AS (
    SELECT
        ...
    FROM ${ref("source_table")}
    WHERE ${when(incremental(), "date >= ...")}
),

step_2 AS (
    SELECT
        ...
    FROM step_1
)

SELECT
    ...
FROM step_2
```

### Komentarze — ZASADA 80/20

- **20% pliku** — komentarze wyjaśniające logikę biznesową
- **80% pliku** — czytelny, samodokumentujący się kod

```sqlx
-- ✅ Dobrze
-- Atrybucja last non-direct: jeśli sesja jest direct, bierzemy
-- ostatnie znane źródło użytkownika. W przeciwnym razie bieżące.
LAST_VALUE(...) IGNORE NULLS OVER (...) AS session_last_non_direct_source

-- ❌ Złe
-- Używamy window function
LAST_VALUE(...) IGNORE NULLS OVER (...) AS session_last_non_direct_source
```

### Indeksowanie CTE (WITH)

1. Każdy CTE = jeden logiczny krok transformacji
2. Nazwy CTE: `step_1`, `base`, `aggregated`, `deduplicated`
3. Maksymalnie 5-7 CTE na zapytanie (potem rozważ podział)

---

## Schemat danych GA4

### Tabela źródłowa `events_*`

Struktura dzienna `events_20240115` lub partycjonowana `events_*`.

#### Kluczowe pola

| Pole | Typ | Opis |
|------|-----|------|
| `event_date` | STRING | Format `YYYYMMDD` |
| `event_timestamp` | INT64 | Microsekundy od epoch |
| `event_name` | STRING | np. `page_view`, `purchase` |
| `user_pseudo_id` | STRING | Identyfikator GA4 (client_id) |
| `user_id` | STRING | Zalogowany użytkownik (jeśli dostępny) |
| `event_params` | ARRAY<STRUCT> | Parametry zdarzenia |
| `event_items` | ARRAY<STRUCT> | Produkty (dla ecommerce) |
| `ecommerce` | STRUCT | Dane koszyka i transakcji |
| `items` | ARRAY<STRUCT> | Alias dla event_items |
| `collected_traffic_source` | STRUCT | UTM z pierwszej sesji |
| `session_traffic_source_last_click` | STRUCT | Ostatnie kliknięcie w sesji |

#### Najważniejsze event_params

| Key | Typ | Opis |
|-----|-----|------|
| `ga_session_id` | int | ID sesji GA4 |
| `page_location` | string | URL strony (zawiera UTM!) |
| `campaign` | string | Nazwa kampanii |
| `source` | string | Źródło ruchu |
| `medium` | string | Medium ruchu |

### Hierarchia źródeł ruchu (prioritet)

W projekcie stosujemy następującą hierarchię dla standaryzacji źródeł:

```
1. UTM z page_location (REGEXP_EXTRACT z URL)
2. event_params (source, medium, campaign)
3. collected_traffic_source (z pierwszej sesji)
4. session_traffic_source_last_click (fallback)
```

### Typy zdarzeń ecommerce

| event_name | Opis |
|------------|------|
| `page_view` | Odsłona strony |
| `session_start` | Początek sesji |
| `first_visit` | Pierwsza wizyta użytkownika |
| `purchase` | Transakcja |
| `refund` | Zwrot |
| `view_item` | Widok produktu |
| `add_to_cart` | Dodanie do koszyka |
| `begin_checkout` | Rozpoczęcie checkoutu |

---

## Modele atrybucji

### 1. Last Non Direct (produkcyjny)

**Zasada**: 100% wartości przypisane do ostatniej niebezpośredniej sesji.

**Zastosowanie**: Standardowy model Google Analytics.

**Logika**:
- Jeśli `session_source ≠ 'direct'` → przypisz konwersję
- Jeśli `session_source = 'direct'` → szukaj ostatniej niezerowej sesji wstecz

**Implementacja**:
```sqlx
LAST_VALUE(NULLIF(source, '(direct)')) IGNORE NULLS OVER (
    PARTITION BY user_pseudo_id
    ORDER BY session_timestamp
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
) AS session_last_non_direct_source
```

### 2. First Click

**Zasada**: 100% wartości przypisane do pierwszego punktu kontaktu.

**Zastosowanie**: Kampanie świadomości marki, analiza ścieżek konwersji.

**Implementacja**:
```sqlx
FIRST_VALUE(session_source) OVER (
    PARTITION BY user_pseudo_id
    ORDER BY session_timestamp
    ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
) AS first_click_source
```

### 3. Linear

**Zasada**: Wartość równo podzielona między wszystkie punkty kontaktu.

**Zastosowanie**: Długie ścieżki decyzyjne, B2B.

**Implementacja**:
```sqlx
1.0 / COUNT(*) OVER (PARTITION BY user_pseudo_id) AS attribution_weight
```

### Porównanie modeli

| Model | Zużycie budgetu | Czułość na ścieżkę | Zastosowanie |
|-------|-----------------|--------------------|--------------|
| Last Non Direct | 100% na końcu | Niska | E-commerce, performance |
| First Click | 100% na początku | Niska | Brand, awareness |
| Linear | Równo | Wysoka | Długie cykle, B2B |

---

## Code Review — najlepsze praktyki

### Dla recenzentów (ludzie)

#### Checklist przed merge

- [ ] **Semantyka SQL**
  - [ ] Zapytanie zwraca poprawny typ danych?
  - [ ] NULL handling jest zgodny z oczekiwaniami?
  - [ ] JOINy nie generują duplikatów (karttezjańskie iloczyny)?

- [ ] **Logika biznesowa**
  - [ ] Atrybucja zgodna z dokumentacją modelu?
  - [ ] Hierarchia źródeł ruchu zachowana?
  - [ ] Filtry dat prawidłowe (incremental vs full refresh)?

- [ ] **Wydajność**
  - [ ] Nie ma SELECT * w podzapytaniach?
  - [ ] UNNEST tylko dla potrzebnych pól?
  - [ ] Window functions mają PARTITION BY?

- [ ] **Dokumentacja**
  - [ ] `config.description` wypełnione?
  - [ ] Złożona logika skomentowana?
  - [ ] Zmiany w schema.md (jeśli istnieje)?

#### Typowe błędy do wyłapania

```sqlx
-- ❌ BŁĄD: Cartesian product
SELECT * FROM sessions, users  -- brak JOIN condition

-- ✅ POPRAWNE: Explicit JOIN
SELECT * FROM sessions s JOIN users u ON s.user_id = u.id

-- ❌ BŁĄD: Brak deduplikacji window function
SELECT *, ROW_NUMBER() OVER () FROM table

-- ✅ POPRAWNE: Deduplikacja z ORDER BY
SELECT * FROM (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY timestamp DESC) as rn
    FROM table
) WHERE rn = 1

-- ❌ BŁĄD: Niedeterministyczne zapytanie
SELECT DISTINCT user_id, source FROM events

-- ✅ POPRAWNE: Agregacja lub deduplikacja
SELECT user_id, ANY_VALUE(source) as source
FROM events
GROUP BY user_id
```

### Dla agentów AI

#### Zasady code review

1. **Zawsze weryfikuj `@ref()`**: sprawdź czy referencja istnieje
2. **Testuj logicznie**: prześledź przynajmniej 3 przypadki danych wejściowych
3. **Licz wiersze**: oszacuj wynik przed napisaniem kodu
4. **Dokumentuj kontrowersje**: jeśli logika jest nietypowa, wyjaśnij dlaczego

#### Checklist automagiczny (sugestie)

```
□ Sprawdź czy wszystkie ${ref()} mają odpowiadające definicje
□ Sprawdź czy incremental mode ma uniqueKey dla deduplication
□ Sprawdź czy window functions mają ORDER BY
□ Sprawdź czy COALESCE ma minimum 2 argumenty
□ Sprawdź czy REGEXP_EXTRACT ma grupę przechwytującą ()
```

---

## Współpraca z Git

### Branching strategy

```
main (produkcja)
  └── develop (integracja)
        ├── feature/ga4-new-attribution-model
        ├── fix/session-deduplication-bug
        └── refactor/pre-events-optimization
```

### Konwencja commitów

```
<type>(<scope>): <description>

Types:
  - feat:     Nowa funkcjonalność
  - fix:      Naprawa błędu
  - refactor: Refaktoryzacja (bez zmiany funkcji)
  - docs:     Dokumentacja
  - test:     Testy (jeśli dodajemy)
  - perf:     Optymalizacja wydajności
```

### Przykłady commitów

```
feat(pre): dodanie standaryzacji źródeł z page_location
fix(sessions): poprawa deduplicacji przy wielu eventach w sesji
refactor(attribution): ekstrakcja wspólnej logiki do CTE
docs(readme): aktualizacja diagramu zależności
perf(pre_events): dodanie indeksu na event_timestamp
```

### Pull Request — wymagania

1. **Tytuł**: jasny, skrótowy opis zmiany
2. **Opis**:
   - Co zostało zmienione?
   - Dlaczego?
   - Jak przetestować?
3. **Reviewers**: minimum 1 osoba
4. **Labels**: `dataform`, `ga4`, `bugfix`, itp.

### Konflikty — rozwiązywanie

1. Preferuj ` theirs` (przychodzące zmiany) dla definicji tabel
2. Preferuj `ours` (lokalne) dla konfiguracji projektu
3. Po konflikcie — uruchom `dataform compile`

---

## Wytyczne dla uczestników projektu

### Dla programistów (ludzi)

#### Przed rozpoczęciem pracy

1. **Zapoznaj się ze skill.md** — ten plik jest źródłem prawdy
2. **Zainstaluj Dataform CLI**: `npm install -g @dataform/cli`
3. **Skonfiguruj credentials**: `dataform init-credentials`
4. **Przeczytaj AGENTS.md** — zrozum kontekst agenta AI

#### Podczas tworzenia nowych modeli

1. **Wybierz właściwy folder**:
   - `1_pre/` — przetwarzanie surowych danych GA4
   - `2_outputs/` — główne tabele wynikowe
   - `3_attribution/` — modele atrybucji
   - `4_reports/` — agregacje raportowe

2. **Zachowaj konwencje nazewnictwa** (patrz wyżej)

3. **Dodaj opis w `config.description`**

4. **Zaktualizuj dokumentację** jeśli zmieniasz schema

#### Tip: Jak korzystać z agenta AI

```
# Zapytania, które działają dobrze:
"Przeanalizuj ga4_pre_events pod kątem wydajności"
"Znajdź potencjalne problemy z null handling"
"Sugeruj optymalizację dla zapytania X"
"Wyjaśnij jak działa atrybucja last non direct"

# Zapytania, których unikaj:
"Napisz mi kod" (bez kontekstu)
"Zrób wszystko" (zbyt ogólne)
"Popraw błąd" (bez info o błędzie)
```

### Dla analityków

#### Czytanie modeli

1. Zacznij od `config.description` — opis przeznaczenia
2. Przejdź przez CTE od góry na dół — logika transformacji
3. Zwróć uwagę na `ref()` — skąd pochodzą dane
4. Sprawdź `WHERE` clauses — filtry i warunki

#### Walidacja wyników

```sql
-- Przykładowe sanity check po uruchomieniu modelu
SELECT 
    COUNT(*) as total_rows,
    COUNT(DISTINCT user_pseudo_id) as unique_users,
    COUNTIF(final_session_source IS NULL) as null_sources,
    MIN(event_date) as oldest_date,
    MAX(event_date) as newest_date
FROM ga4_flattened.ga4_sessions
```

### Dla zespołu DevOps/DataOps

#### CI/CD considerations

1. **Dataform compile** — wymagany przed merge
2. **Dataform run** — tylko na develop/main
3. **Assertions** — warto dodawać dla walidacji danych

#### Monitoring

```sql
-- Sprawdzenie ostatnich uruchomień
SELECT 
    table_name,
    last_modified_time,
    row_count,
    size_bytes
FROM `region-eu`.INFORMATION_SCHEMA.TABLES
WHERE table_schema = 'ga4_flattened'
ORDER BY last_modified_time DESC
```

---

## Rozwiązywanie problemów

### Typowe błędy Dataform

#### Błąd: "Table not found"
```
✗ Could not find table: ga4_pre_events
```
**Rozwiązanie**: Sprawdź czy tabela jest zdefiniowana w `definitions/` i czy `ref()` używa poprawnej nazwy.

#### Błąd: "Incremental table requires uniqueKey"
```
✗ Incremental tables must specify uniqueKey
```
**Rozwiązanie**: Dodaj `uniqueKey: ["event_id"]` do `config {}`.

#### Błąd: "Schema changed"
```
✗ Schema changed since last run
```
**Rozwiązanie**: Uruchom `dataform run --force-full-refresh` lub zmodyfikuj definicję.

### Problemy z danymi GA4

#### Brakujące UTM
- Upewnij się, że `page_location` zawiera parametry
- Sprawdź `REGEXP_EXTRACT` pattern
- Rozważ fallback do `collected_traffic_source`

#### Zduplikowane sesje
- Problem: Ten sam `ga_session_id` dla różnych dni
- Rozwiązanie: Użyj `session_key = CONCAT(user_pseudo_id, ga_session_id)`

#### Sesje direct bez historii
- Problem: Nowy użytkownik = wszystkie sesje 'direct'
- Rozwiązanie: Model atrybucji last non direct to obsługuje

### Debugowanie z agentem AI

```
Pomocne polecenia:
1. "Znajdź wszystkie miejsca gdzie używany jest X"
2. "Wyjaśnij dlaczego te dwa zapytania dają różne wyniki"
3. "Sprawdź czy ta logika jest zgodna z modelem atrybucji Y"
4. "Zoptymalizuj to zapytanie pod kątem kosztu"
```

---

## Dodatek: Szybka referencja

### Przydatne polecenia

```bash
# Kompilacja projektu
dataform compile

# Uruchomienie (produkcja)
dataform run

# Uruchomienie z full refresh
dataform run --force-full-refresh

# Walidacja bez uruchomienia
dataform compile --dry-run
```

### Typy tabel Dataform

| Type | Opis | Kiedy używać |
|------|------|--------------|
| `view` | Virtualna tabela | Proste transformacje, oszczędność storage |
| `table` | Materializowana | Agregacje, indeksy |
| `incremental` | Append-only | Duże zbiory, przetwarzanie dzienne |

### Zasada 3 warunków sukcesu

1. **Poprawność** — zwraca dokładnie to, co oczekujemy
2. **Wydajność** — mieści się w budżecie i czasie
3. **Czytelność** — inny analityk zrozumie logikę

---

*Ostatnia aktualizacja: 2026-04-14*
*Wersja skill: 1.0*
*Kompatybilność: Dataform v2.x, BigQuery*

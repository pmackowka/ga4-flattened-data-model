config {
    -- Rodzaj operacji budującej tabelę bez inkrementacji na nowo
    type: "table",
    -- Ściąga końcowa - ga4_flattened (raporting domena np. w Looker)
    schema: "ga4_flattened",
    -- Dokumentacja modelu finalnego
    description: "Tabela raportowa dla produktów (bazująca na spłaszczeniu wymiaru items z pełnego eventu sprzedażowego)."
}

-- Pobieramy z jednego źródła (zdarzenia zakupowe z okrojonej paczki 1-dniowej testowej)
WITH purchases AS (
    -- Wybiermy transakcje jako podzbiór
    SELECT
        -- Zachowujemy pacjenta cookies dla atrybucji podziału
        e.user_pseudo_id,
        
        -- Formujemy klucz by podłączyć atrybucję źródła ruchu do sprzedaży
        e.session_key,
        
        -- Czas wbijania transakcji
        e.event_timestamp,
        
        -- Data wbicia zdarzenia zakupowego
        e.event_date,
        
        -- Bezpośrednie ID samej faktycznej transakcji jako string/number
        e.ecommerce.transaction_id,
        
        -- Wyłuskujemy całą nieprzetworzoną tablicę obiektów items z wewnątrz
        items
        
    -- Sięgamy do głównej żyły ze złota - pierwsza warstwa wyciągnięta i oczyszczona z events_x
    FROM
        ${ref("ga4_pre_events")} e
        
    -- Warunkujemy się docelowo tylko koszykiem po dacie wysyłki twardego zdarzenia kosza opłaconego
    WHERE
        e.event_name = 'purchase'
        AND e.ecommerce.transaction_id IS NOT NULL
),

-- Blok kluczowy. Złamanie i rozsmarowanie nested table (Spłaszczanie).
unnested_items AS (
    SELECT
        -- Podpinamy sesje 
        p.session_key,
        -- Daty 
        p.event_date,
        -- Puszczamy niżej ten sam id zakupu dla każdego produktu w wierszu
        p.transaction_id,
        
        -- [ZAAWANSOWANE: UNNEST SPŁASZCZENIA DANYCH BQ]
        -- Ponieważ `items` w GA4 jest tablicą zagnieżdżoną ([ {}, {} ]),
        -- BQ rozdzieli każdy obiekt na swój pojedynczy wiersz klonując meta-dane `p` nad nim.
        
        -- Zwracamy id rzutu z item
        i.item_id,
        
        -- Baza - nazwa sprzedanego artykułu
        i.item_name,
        
        -- Wymiar katalogowania
        i.item_category,
        
        -- Stawka unitowa produktu w transakcji
        i.price,
        
        -- Stan ilościowy rzucony na kosz jako number
        i.quantity,
        
        -- [OBLICZENIOWA] Wyliczamy ręcznie z błędu G4 rynkowe obroty czyste produktu
        -- na wypadek gdy item_revenue wpisany jako pole typu string był null / 0
        COALESCE(i.item_revenue, (i.price * i.quantity)) AS item_revenue
        
    -- "purchases p, UNNEST" operuje jak CROSS JOIN p z pod-tablicą i 
    FROM
        purchases p,
        UNNEST(p.items) as i
)

-- Kompilacja ostatecznego widżetu pod PowerBI / Looker Data Studio 
SELECT
    -- Zrzucamy na dół po unnest
    u.event_date,
    u.transaction_id,
    u.item_id,
    u.item_name,
    u.item_category,
    u.price,
    u.quantity,
    u.item_revenue,
    
-- [Atrybucja Dołączona]: Złączenie modelu do każdej unikalnej transakcji!
        -- Wyciągamy source / medium ze skompilowanego w logice "Last Non Direct".
        -- Wrzucając tutaj JOIN, z łatwością model udowadnia siłę Data Ops przy dynamicznych podziałach
    attr.final_session_source AS attribution_source,
    attr.final_session_medium AS attribution_medium,
    
    -- Oddajemy w Looker Studio wagę. 1.0 (zakodowaną domyślnie), dzięki modelce pojedynczej (first / last).
    -- Używana zazwyczaj we wspinaczkach LTV na linearach przy mnożeniu
    attr.attribution_weight
    
FROM
    -- Korzeniemy się w rozpieczestanej tablicy unnested
    unnested_items u
    
-- Szukamy przypisania z okrążenia 3 warstwy modelu 
LEFT JOIN
    ${ref("ga4_attribution_last_non_direct")} attr 
    ON u.session_key = attr.session_key

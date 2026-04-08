-- Konfiguracja pliku w dół od rzeki (Reports)
config {
    -- Rodzaj operacji budującej tabelę bez inkrementacji na nowo
    type: "table",
    -- Ściąga końcowa - ga4_flattened (raporting domena np. w Looker)
    schema: "ga4_flattened",
    -- Dokumentacja modelu finalnego
    description: "Tabela raportowa dla produktów (bazująca na the spłaszczeniu wymiaru items z pełnego eventu sprzedażowego)."
}

-- Pijemy z jednego źródła (the purchase events from okrojonej paczki 1 dniowej testowej)
WITH purchases AS (
    -- Wybiermy transakcje jako podzbiór
    SELECT
        -- Zachowujemy pacjenta cookies dla atrybucji podziału
        e.user_pseudo_id,
        
        -- Formujemy klucz by podłączyć atrybucję the źródła ruchu do sprzedaży
        CONCAT(e.user_pseudo_id, CAST(e.ga_session_id AS STRING)) AS session_key,
        
        -- Czas wbijania transakcji
        e.event_timestamp,
        
        -- Data wbicia the zdarzenia zakupowego
        e.event_date,
        
        -- Bezpośrednie ID samej faktycznej the transakcji jako string/number
        e.ecommerce.transaction_id,
        
        -- Wyłuskujemy the calutką nieprzetworzoną tablicę obiektów items z wewnątrz
        items
        
    -- Sięgamy do głównej żyły ze złota the 1sza warstwa wyciągnięta i oczyszczona z events_x
    FROM
        ${ref("ga4_pre_events")} e
        
    -- Warunkujemy się docelowo tylko the koszykiem po dacie wysyłki twardego zdarzenia kosza opłaconego
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
        -- Puszczamy nizej ten sam id the zakupu dla każdego produktu w wierszyku
        p.transaction_id,
        
        -- [ZAAWANSOWANE: UNNEST SPŁASZCZENIA DANYCH BQ]
        -- Ponieważ `items` w GA4 jest The Array (Tablicą Zagnieżdżoną [ {}, {} ]),
        -- BQ rozdzieli każdy obiekt na swój pojedynczy wiersz klonując the meta-dane `p` nad nim.
        
        -- Zwracamy id the rzutu z item
        i.item_id,
        
        -- Baza - the nazwa sprzedanego artikulusa
        i.item_name,
        
        -- Wymiar katalogowania
        i.item_category,
        
        -- Stawka unitowa produktu w transakcji
        i.price,
        
        -- Stan ilościowy rzucony na kosz jako number
        i.quantity,
        
        -- [OBLICZENIOWA] Wyliczamy manualnie z błędu G4 rynkowe the obroty czyste produktu
        -- na wypadek gdy item_revenue wpisany jako pole the string byl null / 0
        (i.price * i.quantity) AS item_revenue
        
    -- "purchases p, UNNEST" operuje jak CROSS JOIN p z pod-tablicą i 
    FROM
        purchases p,
        UNNEST(p.items) as i
)

-- Kompilacja ostatecznego widżetu pod PowerBI / Looker Data Studio 
SELECT
    -- Zrzucamy na dół po the unnest
    u.event_date,
    u.transaction_id,
    u.item_id,
    u.item_name,
    u.item_category,
    u.price,
    u.quantity,
    u.item_revenue,
    
    -- [The Atrybucja Dołączona]: the Złączenie modelu do każdej unikalnej transakcji!
    -- Wyciągamy source / medium ze skompilowanego w logice "Last Non Direct".
    -- Wrzucając tutaj JOIN, z łatwością model udowadnia siłę the Data Ops przy dynamicznych podziałach
    attr.final_session_source AS attribution_source,
    attr.final_session_medium AS attribution_medium,
    
    -- Oddajemy w the Looker Studio wagę. 1.0 (zakodowaną domyślnie), dzięki the modelce pojedynczej (first / last).
    -- Uzywana zazwyczaj we wspinaczkach LTV na linearach przy mnozeniu
    attr.attribution_weight
    
FROM
    -- Korzeniemy się w rozpieczestanej tablicy unnested
    unnested_items u
    
-- Szukamy przypisania z okrążenia 3 warstwy the modelu 
LEFT JOIN
    ${ref("ga4_attribution_last_non_direct")} attr 
    ON u.session_key = attr.session_key

-- Blok konfiguracji
config {
    -- Rodzaj generowanej encji (gotowa tabela zastępująca w całości poprzedni stan)
    type: "table",
    
    -- Schemat w docelowej bazie dancyh
    schema: "ga4_flattened",
    
    -- Dokumentacja użyteczna przy przeglądaniu BQ
    description: "Tabela wynikowa sesji po deduplikacji oraz nadpisaniu logicznego SESSION_LAST_NON_DIRECT."
}

-- Otwieramy pierwsze podzapytanie (wspólną tabelę dla poniższych kroków)
WITH deduplicated_sessions AS (
    -- SELECT DISTINCT wyłapuje duplikaty wierszy i grupuje identyczne wyniki do jednego wystąpienia
    -- Zabezpiecza nas to przed mnożeniem wiersza ze względu na poprzednio użyte funkcje agregacji 
    SELECT DISTINCT
        -- Główny identyfikator sesji
        session_key,
        -- Kto ją przypisał
        user_pseudo_id,
        -- Techniczny id
        ga_session_id,
        -- Obliczony czas pojawienia się sesji
        session_start_timestamp,
        -- Pobrane z pre_sessions pierwotne źródło
        session_first_source,
        -- Pobrane z pre_sessions pierwotne medium
        session_first_medium,
        -- Pobrane z pre_sessions nadpisane pod koniec źródło
        session_last_source,
        -- Pobrane z pre_sessions nadpisane medium
        session_last_medium
        
    -- Sięgamy bezpośrednio z odczytem do pierwszego wyliczonej tabeli sesji
    FROM
        ${ref("ga4_pre_sessions")}
),

-- Drugie CTE z kluczową logiką dla słynnego "Ostatnie niebezpośrednie źródło"
last_non_direct_logic AS (
    -- Wybiermy wszystkie wyliczone od góry z wiersza za pomocą '*' 
    SELECT 
        *,
        
        -- [ZAAWANSOWANE: SZYMEROWANIE BEZPOŚREDNIMI] Wypełnianie brakujących UTM dla "Direct"
        -- 1. IF(warunek, TRUE, FALSE) w naszym wypadku IF(...) filtruje i wyrzuca '(direct)' zastępując go polem pustym NULL by nie brał go do wagi.
        -- 2. Zabezpieczenie poprzez NULLIF(... , NULL) dodatkowo gwarantuje null jeśli wyjdzie null.
        -- 3. LAST_VALUE( .. IGNORE NULLS) OVER: Ta komenda idzie po sesjach z perspektywy całego kalendarza danego klienta
        -- 4. PARTITION BY user_pseudo_id - patrzymy wyłącznie z punktu widzenia historii jednego ciasteczka/urządzenia.
        -- 5. ORDER BY session_start_timestamp chronologicznie porządkuje sesje historycznie (krok po kroku)
        -- 6. Ogranicza ramkę poprzez domyślne ROWS BETWEEN UNBOUNDED PRECEDING (od zarania dziejów tego usera) AND CURRENT ROW (aż do czasu wystąpienia tej właśnie sesji).
        -- Efekt: Jeśli obecna wpadła tu jako (direct), BQ poszuka poprzedniej sesji która directem nie była i nada jej źródło w dół.
        LAST_VALUE(NULLIF(IF(session_first_source = '(direct)', NULL, session_first_source), NULL) IGNORE NULLS) OVER(
            PARTITION BY user_pseudo_id
            ORDER BY session_start_timestamp 
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS session_last_non_direct_source,
        
        -- Analogiczne zrzucenie dla medium wędrującego po "(none)"
        LAST_VALUE(NULLIF(IF(session_first_medium = '(none)', NULL, session_first_medium), NULL) IGNORE NULLS) OVER(
            PARTITION BY user_pseudo_id
            ORDER BY session_start_timestamp 
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS session_last_non_direct_medium

    -- To skomplikowane okno na czasoprzestrzeni wykonuje się na zde-duplikowanych wyżej sesjach
    FROM deduplicated_sessions
)

-- Ostatni blok złączenia i zwrócenia wyników
SELECT 
    -- Puszczamy nienaruszone metadane w dół leja
    session_key,
    user_pseudo_id,
    ga_session_id,
    session_start_timestamp,
    session_first_source,
    session_last_source,
    
    -- COALESCE stanowi spadochron bezpieczeństwa dla usera. Zwróci odnalezioną poprzednią obcą wartość sesyjną if istnieje, 
    -- jeżeli nie udało się znaleźć absolutnie PUSTEGO źródła wyżej, odda domyślnie '(direct)' w stringu.
    COALESCE(session_last_non_direct_source, '(direct)') AS final_session_source,
    
    -- Spadochron dla medium
    COALESCE(session_last_non_direct_medium, '(none)')  AS final_session_medium
    
-- Pobieramy to z naszej tabelki wirtualnej generującej the logic w CTE
FROM
    last_non_direct_logic

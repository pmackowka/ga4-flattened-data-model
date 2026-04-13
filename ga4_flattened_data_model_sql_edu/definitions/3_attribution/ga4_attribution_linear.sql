-- Sekcja konfiguracji meta
config {
    -- Ustanowienie wygenerowanej w locie tabeli wynikowej w repozytorium SQL.
    type: "table",
    
    -- Ścieżka wyjściowa
    schema: "ga4_flattened",
    
    -- Opis w celach ewidencyjnych w tabelach i interfejsie gcp
    description: "Model atrybucji Linear - Równy podział wartości 1.0 dla absolutnie wszystkich ujętych w zrębkach sesji na osi czasowej."
}

-- Deklarujemy wirtualną oś
WITH user_paths AS (
    -- Wybiermy skondensowane kolumny dla modelu wielodotykowego z równą wagą
    SELECT
        -- Podstawowe identyfikatory i detale...
        user_pseudo_id,
        session_key,
        final_session_source,
        final_session_medium,
        session_start_timestamp,
        
        -- [ZAAWANSOWANE: SUMOWANIE DO DZIELNIKA UŁAMKÓW W LINEARNYM ROZLICZENIU]
        -- Aby w Linear podzielić ciasto np po 25% na każdego (przy 4 wizytach usera omijamy 'WHERE last_click=coś'),
        -- używamy okna zliczającego wystąpienia (COUNT).
        -- PARTITION BY dzieli to wyłącznie dla ramy punktu 1-go ciastka usera. Wynikiem wiersza total_sessions 
        -- w nowej kolumnie będzie informacja "Ile razy tu gościłeś generalnie?". 
        COUNT(session_key) OVER (PARTITION BY user_pseudo_id) as total_sessions
        
    -- Sięgamy do dedup dla zaufanego wyciągu z sesji 
    FROM
        ${ref("ga4_sessions")}
)

-- Ostatni blok wyrzutu 
SELECT
    user_pseudo_id,
    session_key,
    final_session_source,
    final_session_medium,
    
    -- Równomierny podział wagi ułamkowej:
    -- Ponieważ usunęliśmy wiersze "które odpadają" (Linear bierze każdy etap drogi klienta z tej 30-dniowej puli naciasz),
    -- to jeśli ktoś przed zakupem wszedł np. 4 razy z innych reklam, na każdą wizytę przypadnie przypisanie punktowe wagi atrybucji (1.0 / 4) równe rynkowemu skokowi w raporcie jako 0.25 obrotu gotówki.
    1.0 / total_sessions AS attribution_weight
    
-- Pobieramy na out... (bez WHERE, tutaj wszystkie sesje zostają!)
FROM
    user_paths

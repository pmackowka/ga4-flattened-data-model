-- Konfiguracja Dataform
config {
    -- Ustanowienie by the sql zrzuciło wynikową tebele nadpisując poprzednią
    type: "table",
    
    -- Cel uderzenia
    schema: "ga4_flattened",
    
    -- Opis w ramach wyjaśnień dla repo docelowego
    description: "Model atrybucji Last Non Direct - 100% wartości konwersji do ustandaryzowanej ostatniej niebezpośredniej sesji."
}

-- Zapuszczamy ramowy CTE
WITH user_paths AS (
    -- Wyłapujemy wyliczone kolumnowce od góry
    SELECT
        user_pseudo_id,
        session_key,
        final_session_source,
        final_session_medium,
        session_start_timestamp,
        
        -- [ZAAWANSOWANE: SZYKOWANIE DO OSTATNIEGO SKOKU] Sorter rewersowy z okna:
        -- Logika układa od tyłu ranking dla pojedynczego okrążenia każdego klienta.
        -- Czas sortowany jst wg DESC (Malejąco), co tworzy ranking 1, 2, 3.. tak, że wiersz nr = 1 przypadnie ZAWSZE 
        -- tej najbardziej OSTATNIEJ historycznie sesji przed pchnięciem transakcji.
        ROW_NUMBER() OVER (PARTITION BY user_pseudo_id ORDER BY session_start_timestamp DESC) as reverse_session_rank
        
    -- Sięgamy bezpośrednio z zdeduplikowanej i oczyszczonej bazy logicznych sesji z wykluczeniem w locie trybu '(direct)' (Last Non-Direct Click). 
    -- Ten plik już o to zadbał poprzez skomplikowany system spadochronowy i ominięcie wejść pustych na rzecz przepisania!
    FROM
        ${ref("ga4_sessions")}
)

-- Wariant wynoszący na świat
SELECT
    user_pseudo_id,
    session_key,
    final_session_source,
    final_session_medium,
    
    -- Jako model Single-Touch the weight stuka pełne i ostateczne odzwierciedleniie całej kasy lub ilości akcji na 1 sesji 
    1.0 AS attribution_weight
    
FROM
    -- Siągamy z rankingu od tylu CTE bazy ścieżki
    user_paths
WHERE
    -- Ze względu na fakt, że plik wyżej sam uprzednio rozlał UTM pod ruch "Direct", pomijając i przepisując wejścia w tył,
    -- bezpiecznie i po prostu filtrujemy sesję użytkownika do ujęcia OSTATNIEJ (co odpowiada teraz LNonDirect domyślnego Analytics).
    reverse_session_rank = 1

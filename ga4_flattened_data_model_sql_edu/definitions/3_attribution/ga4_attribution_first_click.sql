-- Konfiguracja pliku w modelu z atrybutami Dataform
config {
    -- Rodzaj operacji w BD
    type: "table",
    -- Nazwa bazy wynikowej (schematu)
    schema: "ga4_flattened",
    -- Opis analityczny dodawany z repo do interfejsu
    description: "Model atrybucji First Click - 100% wartości konwersji przypisywanej do pierwszej sesji na ścieżce klienta."
}

-- Deklarujemy wirtualną tabelę grupującą trasy dla każdego klienta
WITH user_paths AS (
    -- Wyciągamy kolumny
    SELECT
        -- Podstawowe id urządzenia
        user_pseudo_id,
        -- Podstawowe id badanej pod atrybucję sesji na tym urządzeniu
        session_key,
        -- Spadochronowe ostateczne źródło i medium z wyliczonej warstwy OUTPUTS
        final_session_source,
        final_session_medium,
        -- Punkt orientacyjny w czasie na osi tego kalendarza ścieżki (path)
        session_start_timestamp,
        
        -- [ZAAWANSOWANE: SZYKOWANIE DO PIERWSZEGO KLIKNIĘCIA] Funkcja sortująca i numerująca:
        -- 1. Śledzimy kalendarz konkretnego usera (PARTITION BY user_pseudo_id).
        -- 2. Sortujemy poszczególne wizyty na tym terytorium od najstarszej historycznie jako pierwsze pchnięcie twarde (ORDER BY .. ASC).
        -- 3. Numerujemy je sobie wg rankingu od góry w dół jako 1, 2, 3..
        ROW_NUMBER() OVER (PARTITION BY user_pseudo_id ORDER BY session_start_timestamp ASC) as session_rank
        
    -- Sięgamy bezpośrednio z zdedupliowanej bazy logicznych sesji z ominiętym trybem bezpośredniego
    FROM
        ${ref("ga4_sessions")}
)

-- Końcowy output z modelu w tej logice
SELECT
    -- Powtarzamy selekcjonowanie usera
    user_pseudo_id,
    -- Sesja która docelowo wygrywa (o numerku nizej)
    session_key,
    -- Żądło atrybucyjne Source i Medium wygrywające w tym wyliczeniu
    final_session_source,
    final_session_medium,
    
    -- Jako że to tzw. model Single-Touch (jeden punkt wygrywa wszystko), wpisujemy sztucznie pełną wagę dla całej operacji.
    -- Oznacza to, że 1.0 (100%) wartości przychodów i zakupów z każdego działania spadnie wyłącznie na korzyść przypisaną w tym module w dolnych plikach the Reports.
    1.0 AS attribution_weight
    
-- Pobieramy to z wirtrualnej bazy userów posortowanych wyżej
FROM
    user_paths
    
-- [ZŁOTY STRZAŁ] Odcinamy całą resztę i przypisujemy punkt tylko do sesji, pod którą postawiono nr = 1 (czyli tą totalnie najstarszą first click w układance the window ASC).
WHERE
    session_rank = 1

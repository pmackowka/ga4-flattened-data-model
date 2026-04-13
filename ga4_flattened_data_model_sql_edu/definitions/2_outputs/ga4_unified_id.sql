-- Konfiguracja pliku w modelu z atrybutami Dataform
config {
    -- Wypychamy wyliczony słownik IDków w formie stałej tabeli
    type: "table",
    
    -- Baza docelowa dla gotowego spłaszczonego rozwiązania Identity
    schema: "ga4_flattened",
    
    description: "Tabela rozwiązywania tożsamości cross-device dla użytkowników (Identity resolution). Lookback window zalezne od bazy źródłowej."
}

-- Otwieramy CTE wyciągające czyste informacje o uderzeniach tagów autoryzacyjnych usera
WITH id_matches AS (
    -- Selekcjonujemy niezbędne nam zmienne
    SELECT
        -- Pobieramy identyfikator cookies (pseudo ID, to czego nie wolno nadpisać u usera cross device)
        user_pseudo_id,
        
        -- Pobieramy twardy User-ID (unikalny dla naszej platformy przy zalogowaniu, np. identyfikator z e-commerce CRM)
        user_id,
        
        -- Ustawiamy punkt kontrolny czasu przy najwcześniejszym zaobserwowaniu przypisania tego twardego ID 
        -- do tego konkretnego cookies w tym bloku czasu
        MIN(event_timestamp) AS first_seen_with_id
        
    -- Bierzemy to wyłączenie z pierwszej warstwy 'pre', która wyczyściła stringi
    FROM
        ${ref("ga4_pre_events")}
        
    -- Filtrujemy tylko przypadki logowania
    WHERE
        -- Aby rozwiązać tożsamość, system musiał zarejestrować chociaż raz zalogowane ID
        user_id IS NOT NULL 
        
    -- Grupowanie unikalnych dopasowań pod tożsamość cookiesa + user_id CRM
    GROUP BY
        user_pseudo_id,
        user_id
)

-- Ostatni blok wyrzucający wynik do podpowiedzi modelu dla innych tabel 
SELECT
    -- Oddajemy bazowe cookie
    user_pseudo_id,
    
    -- Tłumaczymy CRMowy user_id pod rynkową flagę "rozwiązanego/połączonego adresu" cross-device
    user_id AS resolved_user_id
    
-- Posługujemy się wewnętrzną tabelką na górze (match table)
FROM
    id_matches
    
-- [ZAAWANSOWANE: QUALIFY z ROW_NUMBER] Zabezpieczenie przed konfliktami Tożsamości:
-- 1. Klient mógł założyć 2 twarde konta pod user_id siedząc na 1 cookies/urządzeniu. To spowodowałoby powieleniami 2 rozwiązań!
-- 2. QUALIFY działa jak "WHERE" ale operuje już w fazie PO wykonaniu funkcji analitycznej "OVER".
-- 3. Polecenie liczy rzędy (ROW_NUMBER()) rozdzielając użytkowników ze względu na user_pseudo_id, ustawiając w rankingu najwcześniejsze spotkanie pierwszego wiersza (ORDER BY first_seen_with_id ASC).
-- 4. Przepuszczamy (= 1) tylko jedno, najstarsze napotkane powiązanie konta z tym anonimowym i ucinamy resztę (2, 3..). To rozwiązuje duplikaty cross device.
QUALIFY ROW_NUMBER() OVER (PARTITION BY user_pseudo_id ORDER BY first_seen_with_id) = 1

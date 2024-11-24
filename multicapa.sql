-- Instala PostGIS
CREATE EXTENSION IF NOT EXISTS postgis;
-- Aquesta línia instal·la l'extensió PostGIS si encara no està instal·lada. PostGIS permet gestionar dades geoespacials en PostgreSQL.

-- Instala pgRouting
CREATE EXTENSION IF NOT EXISTS pgrouting;
-- Aquesta línia instal·la l'extensió pgRouting si encara no està instal·lada. pgRouting afegeix funcionalitats de rutes i anàlisi de xarxes a PostgreSQL.

-- Crea una taula unificada de totes les carreteres combinant red1, red2 i red3
CREATE TABLE todas_carreteras AS
SELECT 
    id, 
    geom, 
    3 AS coste_por_metro, 
    1 AS carretera_id 
FROM eps.red1
UNION ALL
SELECT 
    id, 
    geom, 
    5 AS coste_por_metro, 
    2 AS carretera_id 
FROM eps.red2
UNION ALL
SELECT 
    id, 
    geom, 
    10 AS coste_por_metro, 
    3 AS carretera_id 
FROM eps.red3;
-- Aquesta secció crea una nova taula anomenada "todas_carreteras" que combina les tres xarxes de carreteres (red1, red2 i red3).
-- Assigna un cost per metre diferent segons la carretera (3, 5 o 10) i un identificador de carretera (1, 2 o 3).

-- Definir la distància umbral per considerar que dues aristes estan "molt a prop" (per exemple, 10 metres)
SELECT set_config('pgr.routing.debug', 'on', false); -- Opcional: per a depuració
-- Aquesta línia configura una variable de configuració per pgRouting. En aquest cas, es desactiva la depuració.

-- Crear un node per a cada punt d'intersecció o proximitat
-- Primer, extreure tots els nodes (punts finals) de cada arista
WITH nodos AS (
    SELECT 
        id, 
        (ST_DumpPoints(geom)).geom AS punto
    FROM todas_carreteras
),
-- Trobar punts que estan dins de la distància umbral
nodos_conectados AS (
    SELECT 
        a.id AS id_a, 
        b.id AS id_b, 
        a.punto AS punto_a, 
        b.punto AS punto_b
    FROM nodos a
    JOIN nodos b 
      ON a.id <> b.id 
      AND ST_DWithin(a.punto, b.punto, 10) -- 10 metres d'umbral
)
-- Inserir nous nodes de connexió
INSERT INTO nodos_conexion (geom)
SELECT DISTINCT 
    ST_ClosestPoint(a.punto_a, b.punto_b)
FROM nodos_conectados;
-- Aquesta secció crea nous nodes de connexió per a les aristes que estan molt a prop (dins de 10 metres).
-- Utilitza funcions de PostGIS per identificar punts propers i crear punts de connexió.

-- Crea la taula "nodos_conexion" per emmagatzemar els nodes de connexió
CREATE TABLE nodos_conexion (
    id SERIAL PRIMARY KEY,
    geom geometry(Point, 25830)
);
-- Aquesta línia crea una nova taula anomenada "nodos_conexion" amb un identificador únic i una geometria de punt.
-- L'ús de EPSG:25830 assegura que les geometries utilitzin la projecció espacial adequada.

-- Inserir els nodes de connexió identificats anteriorment
INSERT INTO nodos_conexion (geom)
SELECT DISTINCT (ST_Dump(punto_conexion)).geom
FROM conexiones
WHERE punto_conexion IS NOT NULL;
-- Aquesta secció insereix els punts de connexió únics a la taula "nodos_conexion".
-- Filtra els punts que no són nuls per assegurar-se que només s'insereixen connexions vàlides.

-- Crea la taula "aristas" que conté les aristes amb informació de cost
CREATE TABLE aristas AS
SELECT 
    row_number() OVER () AS id,
    ST_StartPoint(geom) AS start_geom,
    ST_EndPoint(geom) AS end_geom,
    geom,
    coste_por_metro * ST_Length(geom::geography) AS coste_total
FROM todas_carreteras;
-- Aquesta secció crea una taula "aristas" que conté cada arista amb un identificador únic, 
-- els punts d'inici i fi, la geometria completa, i el cost total calculat com el cost per metre multiplicat per la longitud de l'arista.

-- Combinar tots els punts d'inici i fi més els nodes de connexió en una sola taula de nodes
CREATE TABLE all_nodos AS
SELECT start_geom AS geom FROM aristas
UNION
SELECT end_geom AS geom FROM aristas
UNION
SELECT geom FROM nodos_conexion;
-- Aquesta línia crea una taula "all_nodos" que combina tots els punts d'inici i fi de les aristes
-- amb els nodes de connexió per obtenir una llista completa de tots els nodes de la xarxa.

-- Assignar un ID únic a cada node
CREATE TABLE nodos AS
SELECT 
    row_number() OVER () AS id, 
    geom
FROM all_nodos;
-- Aquesta secció crea una taula "nodos" assignant un identificador únic a cada geomètria de punt de "all_nodos".

-- Afegir columnes "source" i "target" a la taula "aristas"
ALTER TABLE aristas ADD COLUMN source INTEGER;
ALTER TABLE aristas ADD COLUMN target INTEGER;
-- Aquestes línies afegeixen les columnes "source" i "target" a la taula "aristas" per emmagatzemar els IDs dels nodes d'origen i destí.

-- Assignar els IDs de "source" i "target" basant-se en la geometria
UPDATE aristas
SET 
    source = nodos.id,
    target = nodos2.id
FROM 
    nodos AS nodos,
    nodos AS nodos2
WHERE 
    ST_Equal(aristas.start_geom, nodos.geom) 
    AND ST_Equal(aristas.end_geom, nodos2.geom);
-- Aquesta secció actualitza les columnes "source" i "target" de cada arista 
-- assignant els IDs dels nodes d'origen i destí basant-se en la igualtat de geometries.

-- Crear índexs espacials per millorar el rendiment de les consultes
CREATE INDEX idx_aristas_geom ON aristas USING GIST (geom);
CREATE INDEX idx_nodos_geom ON nodos USING GIST (geom);
CREATE INDEX idx_nodos_conexion_geom ON nodos_conexion USING GIST (geom);
-- Aquestes línies creen índexs espacials (GIST) a les taules "aristas", "nodos" i "nodos_conexion"
-- per optimitzar les consultes espacials.

-- Obtenir les geometries d'origen i destí des de "red1_puntos"
SELECT geom FROM eps.red1_puntos WHERE id = 1; -- Origen
SELECT geom FROM eps.red1_puntos WHERE id = 6; -- Destí
-- Aquestes consultes recuperen les geometries dels punts d'origen i destí a partir de la taula "red1_puntos".

-- Trobar els nodes més propers a l'origen i destí
WITH origen AS (
    SELECT id FROM nodos
    ORDER BY nodos.geom <-> (SELECT geom FROM eps.red1_puntos WHERE id = 1)
    LIMIT 1
),
destino AS (
    SELECT id FROM nodos
    ORDER BY nodos.geom <-> (SELECT geom FROM eps.red1_puntos WHERE id = 6)
    LIMIT 1
)
-- Aquesta secció utilitza l'operador "<->" per trobar el node més proper a les geometries d'origen i destí.
-- "origen" i "destino" són subconsultes que seleccionen l'ID del node més proper per cada punt.

-- Executar l'algoritme A* per trobar la ruta més curta
SELECT 
    pgr_aStar(
        'SELECT id, source, target, coste_total AS cost FROM aristas',
        (SELECT id FROM origen),
        (SELECT id FROM destino),
        false
    );
-- Aquesta consulta executa la funció pgr_aStar de pgRouting per trobar la ruta més curta 
-- des del node d'origen fins al node de destí basant-se en el cost total de les aristes.
-- El paràmetre 'false' indica que la xarxa no és dirigida.

--- Exemple de consulta
WITH 
    origen AS (
        SELECT id FROM nodos
        ORDER BY nodos.geom <-> (SELECT geom FROM eps.red1_puntos WHERE id = 1)
        LIMIT 1
    ),
    destino AS (
        SELECT id FROM nodos
        ORDER BY nodos.geom <-> (SELECT geom FROM eps.red1_puntos WHERE id = 6)
        LIMIT 1
    )
SELECT * FROM pgr_aStar(
    'SELECT id, source, target, coste_total AS cost FROM aristas',
    (SELECT id FROM origen),
    (SELECT id FROM destino),
    false
);
-- Aquest és un exemple complet de consulta que utilitza CTEs (Common Table Expressions) per definir els nodes d'origen i destí
-- i després executa l'algoritme A* per obtenir la ruta més curta entre ells.

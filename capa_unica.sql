-- Crear una taula d'aristes per a pgRouting
CREATE TABLE aristas AS
SELECT 
    id,
    geom,
    ST_Length(geom) AS cost  -- Cost basat en la longitud de l'arista en unitats del sistema de coordenades (metres per EPSG:25830)
FROM eps.red1;
-- Aquesta consulta crea una nova taula anomenada "aristas" que inclou l'identificador de l'arista, 
-- la seva geometria i el cost associat, que en aquest cas és la longitud de l'arista calculada 
-- utilitzant la funció ST_Length sense convertir a geography.

-- Extraure tots els nodes (punts d'inici i fi) de les aristes
CREATE TABLE all_nodos AS
SELECT 
    ST_StartPoint(geom) AS geom 
FROM aristas
UNION
SELECT 
    ST_EndPoint(geom) AS geom 
FROM aristas;
-- Aquesta consulta crea una taula temporal "all_nodos" que combina tots els punts d'inici 
-- i fi de les aristes de la taula "aristas". L'ús de UNION elimina els duplicats, 
-- resultant en una llista única de tots els nodes de la xarxa.

-- Assignar un ID únic a cada node
CREATE TABLE nodos AS
SELECT 
    row_number() OVER () AS id,
    geom
FROM all_nodos;
-- Aquesta consulta crea una taula "nodos" assignant un identificador únic a cada geomètria de punt 
-- present a "all_nodos". Això és essencial per a pgRouting, que necessita identificar 
-- cada node de manera única.

-- Afegir columnes source i target a la taula d'aristes
ALTER TABLE aristas ADD COLUMN source INTEGER;
ALTER TABLE aristas ADD COLUMN target INTEGER;
-- Aquestes línies afegeixen les columnes "source" i "target" a la taula "aristas". 
-- Aquestes columnes emmagatzemaran els IDs dels nodes d'origen i destí per a cada arista, 
-- necessari per al càlcul de rutes amb pgRouting.

-- Assignar els IDs de source i target basant-se en la proximitat dels punts d'inici i fi
-- A continuació, s'utilitza la proximitat dels punts d'inici i fi de cada arista amb els nodes per assignar els IDs correctes.

-- Actualitzar source
UPDATE aristas
SET source = nodos.id
FROM nodos
WHERE ST_DWithin(aristas.geom, nodos.geom, 0.001)  -- Ajusta la tolerància si és necessari
  AND ST_Distance(aristas.geom, nodos.geom) = (
      SELECT MIN(ST_Distance(aristas.geom, nodos2.geom))
      FROM nodos AS nodos2
      WHERE ST_DWithin(aristas.geom, nodos2.geom, 0.001)
  )
  AND ST_StartPoint(aristas.geom) = nodos.geom;
-- Aquesta consulta actualitza la columna "source" de cada arista assignant el ID del node 
-- més proper al punt d'inici de l'arista. Utilitza ST_DWithin per assegurar-se que els punts 
-- estan dins d'una distància de 0.001 unitats (ajustable segons sigui necessari) i 
-- selecciona el node amb la mínima distància.

-- Actualitzar target
UPDATE aristas
SET target = nodos.id
FROM nodos
WHERE ST_DWithin(aristas.geom, nodos.geom, 0.001)  -- Ajusta la tolerància si és necessari
  AND ST_Distance(aristas.geom, nodos.geom) = (
      SELECT MIN(ST_Distance(aristas.geom, nodos2.geom))
      FROM nodos AS nodos2
      WHERE ST_DWithin(aristas.geom, nodos2.geom, 0.001)
  )
  AND ST_EndPoint(aristas.geom) = nodos.geom;
-- Aquesta consulta actualitza la columna "target" de cada arista assignant el ID del node 
-- més proper al punt de fi de l'arista, utilitzant una lògica similar a la de l'actualització de "source".


--- CAMBIAR PELS PUNTS QUE ENS DONEN 
-- Definir els IDs dels punts d'origen i destí
SELECT geom INTO TEMP TABLE origen_punto FROM eps.red1_puntos WHERE id = 1;
SELECT geom INTO TEMP TABLE destino_punto FROM eps.red1_puntos WHERE id = 6;
-- Aquestes consultes seleccionen les geometries dels punts amb ID 1 i 6 
-- de la taula "red1_puntos" i les emmagatzemen en taules temporals "origen_punto" 
-- i "destino_punto", respectivament. Aquests punts seran utilitzats com a origen i destí 
-- per a l'algoritme A*.

-- Trobar el node més proper al punt d'origen
SELECT id INTO TEMP TABLE origen_nodo
FROM nodos
ORDER BY nodos.geom <-> (SELECT geom FROM origen_punto)
LIMIT 1;
-- Aquesta consulta troba el node amb la geomètria més propera al punt d'origen 
-- utilitzant l'operador de distància "<->" i emmagatzema el seu ID en una taula temporal "origen_nodo".

-- Trobar el node més proper al punt de destí
SELECT id INTO TEMP TABLE destino_nodo
FROM nodos
ORDER BY nodos.geom <-> (SELECT geom FROM destino_punto)
LIMIT 1;
-- Aquesta consulta troba el node amb la geomètria més propera al punt de destí 
-- i emmagatzema el seu ID en una taula temporal "destino_nodo".

-- Executar l'algoritme A*
SELECT * FROM pgr_aStar(
    'SELECT id, source, target, cost FROM aristas',
    (SELECT id FROM origen_nodo),
    (SELECT id FROM destino_nodo),
    false  -- La xarxa no és dirigida
);
-- Aquesta consulta executa la funció pgr_aStar de pgRouting per trobar la ruta més curta 
-- des del node d'origen fins al node de destí. El paràmetre 'false' indica que 
-- la xarxa no és dirigida, és a dir, que les aristes poden ser transitades en ambdues direccions.

--- EJEMPLO DE LA CONSULTA

WITH 
    -- Definir els punts d'origen i destí
    origen_punto AS (
        SELECT geom FROM eps.red1_puntos WHERE id = 1
    ),
    destino_punto AS (
        SELECT geom FROM eps.red1_puntos WHERE id = 6
    ),
    -- Trobar el node més proper a l'origen
    origen_nodo AS (
        SELECT id FROM nodos
        ORDER BY nodos.geom <-> (SELECT geom FROM origen_punto)
        LIMIT 1
    ),
    -- Trobar el node més proper al destí
    destino_nodo AS (
        SELECT id FROM nodos
        ORDER BY nodos.geom <-> (SELECT geom FROM destino_punto)
        LIMIT 1
    ),
    -- Executar A* i obtenir les aristes de la ruta
    ruta_aStar AS (
        SELECT * FROM pgr_aStar(
            'SELECT id, source, target, cost FROM aristas',
            (SELECT id FROM origen_nodo),
            (SELECT id FROM destino_nodo),
            false
        )
    )
-- Seleccionar les geometries de les aristes que formen la ruta
SELECT a.geom
FROM aristas a
JOIN ruta_aStar r ON a.id = r.edge;
-- Aquesta secció final utilitza una consulta amb Common Table Expressions (CTEs) 
-- per definir els punts d'origen i destí, trobar els nodes més propers a aquests punts, 
-- executar l'algoritme A* i finalment seleccionar les geometries de les aristes que 
-- formen la ruta resultant. La consulta resultant pot ser utilitzada per visualitzar 
-- la ruta en eines SIG com QGIS.

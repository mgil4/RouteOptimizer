-- Crear una tabla de aristas para pgRouting
CREATE TABLE aristas AS
SELECT 
    id,
    geom,
    ST_Length(geom::geography) AS cost  -- Coste basado en la longitud de la arista
FROM eps.red1;

ç-- Extraer todos los nodos (puntos de inicio y fin) de las aristas
CREATE TABLE all_nodos AS
SELECT 
    ST_StartPoint(geom) AS geom 
FROM aristas
UNION
SELECT 
    ST_EndPoint(geom) AS geom 
FROM aristas;

-- Asignar un ID único a cada nodo
CREATE TABLE nodos AS
SELECT 
    row_number() OVER () AS id,
    geom
FROM all_nodos;

-- Agregar columnas source y target a la tabla de aristas
ALTER TABLE aristas ADD COLUMN source INTEGER;
ALTER TABLE aristas ADD COLUMN target INTEGER;

-- Actualizar las columnas source y target con los IDs correspondientes
UPDATE aristas
SET 
    source = nodos.id,
    target = nodos2.id
FROM 
    nodos AS nodos,
    nodos AS nodos2
WHERE 
    ST_Equals(aristas.geom, ST_SetSRID(ST_MakeLine(nodos.geom, nodos2.geom), 25830));

-- Actualizar source
UPDATE aristas
SET source = nodos.id
FROM nodos
WHERE ST_DWithin(aristas.geom, nodos.geom, 0.001)  -- Ajusta la tolerancia si es necesario
  AND ST_Distance(aristas.geom, nodos.geom) = (
      SELECT MIN(ST_Distance(aristas.geom, nodos2.geom))
      FROM nodos AS nodos2
      WHERE ST_DWithin(aristas.geom, nodos2.geom, 0.001)
  );

-- Actualizar target
UPDATE aristas
SET target = nodos.id
FROM nodos
WHERE ST_DWithin(aristas.geom, nodos.geom, 0.001)  -- Ajusta la tolerancia si es necesario
  AND ST_Distance(aristas.geom, nodos.geom) = (
      SELECT MIN(ST_Distance(aristas.geom, nodos2.geom))
      FROM nodos AS nodos2
      WHERE ST_DWithin(aristas.geom, nodos2.geom, 0.001)
  );

CREATE TABLE eps.red1_puntos (
    id integer NOT NULL,
    geom geometry(Point, 25830),
    fid bigint
);

-- Definir los IDs de los puntos de origen y destino
SELECT geom INTO TEMP TABLE origen_punto FROM eps.red1_puntos WHERE id = 1;
SELECT geom INTO TEMP TABLE destino_punto FROM eps.red1_puntos WHERE id = 6;

-- Encontrar el nodo más cercano al punto de origen
SELECT id INTO TEMP TABLE origen_nodo
FROM nodos
ORDER BY nodos.geom <-> (SELECT geom FROM origen_punto)
LIMIT 1;

-- Encontrar el nodo más cercano al punto de destino
SELECT id INTO TEMP TABLE destino_nodo
FROM nodos
ORDER BY nodos.geom <-> (SELECT geom FROM destino_punto)
LIMIT 1;

-- Ejecutar el algoritmo A*
SELECT * FROM pgr_aStar(
    'SELECT id, source, target, cost FROM aristas',
    (SELECT id FROM origen_nodo),
    (SELECT id FROM destino_nodo),
    false  -- La red no es dirigida
);

--- EJEMPLO DE LA CONSULTA

WITH 
    -- Definir los puntos de origen y destino
    origen_punto AS (
        SELECT geom FROM eps.red1_puntos WHERE id = 1
    ),
    destino_punto AS (
        SELECT geom FROM eps.red1_puntos WHERE id = 6
    ),
    -- Encontrar el nodo más cercano al origen
    origen_nodo AS (
        SELECT id FROM nodos
        ORDER BY nodos.geom <-> (SELECT geom FROM origen_punto)
        LIMIT 1
    ),
    -- Encontrar el nodo más cercano al destino
    destino_nodo AS (
        SELECT id FROM nodos
        ORDER BY nodos.geom <-> (SELECT geom FROM destino_punto)
        LIMIT 1
    ),
    -- Ejecutar A* y obtener las aristas de la ruta
    ruta_aStar AS (
        SELECT * FROM pgr_aStar(
            'SELECT id, source, target, cost FROM aristas',
            (SELECT id FROM origen_nodo),
            (SELECT id FROM destino_nodo),
            false
        )
    )
-- Seleccionar las geometrías de las aristas que forman la ruta
SELECT a.geom
FROM aristas a
JOIN ruta_aStar r ON a.id = r.edge;

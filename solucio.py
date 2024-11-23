import psycopg2
from psycopg2 import sql

# Configuración de la conexión a PostgreSQL
db_config = {
    "dbname": "database",
    "user": "user",
    "password": "password",
    "host": "localhost",
    "port": 5432
}

def ejecutar_consulta(query, params=None):
    """
    Ejecuta una consulta SQL y devuelve los resultados.
    """
    try:
        with psycopg2.connect(**db_config) as conn:
            with conn.cursor() as cur:
                cur.execute(query, params)
                if query.strip().lower().startswith("select"):
                    return cur.fetchall()
                conn.commit()
    except Exception as e:
        print(f"Error ejecutando la consulta: {e}")

def comprobar_conexion():
    """
    Verifica si se puede conectar a la base de datos.
    """
    try:
        with psycopg2.connect(**db_config) as conn:
            print("Conexión exitosa a la base de datos.")
    except Exception as e:
        print(f"No se pudo conectar a la base de datos: {e}")
        raise

def comprobar_tablas(tablas):
    """
    Comprueba si las tablas necesarias existen en la base de datos.
    """
    tablas_faltantes = []
    for tabla in tablas:
        query = sql.SQL("SELECT to_regclass(%s);")
        resultado = ejecutar_consulta(query, (tabla,))
        if not resultado or resultado[0][0] is None:
            tablas_faltantes.append(tabla)
    if tablas_faltantes:
        raise Exception(f"Las siguientes tablas no existen en la base de datos: {', '.join(tablas_faltantes)}")
    print("Todas las tablas necesarias existen en la base de datos.")


# Crear la vista unificada
def crear_vista_unificada():
    query = """
    CREATE OR REPLACE VIEW red_unificada AS
    SELECT 
        id,
        geom,
        3 * ST_Length(geom) AS costo
    FROM eps.red1
    UNION ALL
    SELECT 
        id,
        geom,
        5 * ST_Length(geom) AS costo
    FROM eps.red2
    UNION ALL
    SELECT 
        id,
        geom,
        10 * ST_Length(geom) AS costo
    FROM eps.red3;
    """
    ejecutar_consulta(query)
    print("Vista unificada creada correctamente.")

# Preparar las tablas para pgRouting
def preparar_tablas_para_pgrouting():
    redes = ["eps.red1", "eps.red2", "eps.red3"]
    for red in redes:
        query = sql.SQL(
           f"SELECT pgr_createTopology({red}, 0.001, 'geom', 'id');"
        ).format(table=sql.Identifier(red))
        ejecutar_consulta(query)
        print(f"Topología creada para {red}.")

# Función para ejecutar A* y obtener la ruta
def calcular_ruta_a_estrella(x_origen, y_origen, x_destino, y_destino):
    query_ruta = """
    SELECT edge FROM pgr_astar(
        'SELECT id, source, target, costo AS cost, costo AS reverse_cost FROM red_unificada',
        (SELECT id FROM eps.red1_puntos WHERE ST_DWithin(geom, ST_SetSRID(ST_MakePoint(%s, %s), 4326), 0.001)),
        (SELECT id FROM eps.red2_puntos WHERE ST_DWithin(geom, ST_SetSRID(ST_MakePoint(%s, %s), 4326), 0.001)),
        (SELECT id FROM eps.red3_puntos WHERE ST_DWithin(geom, ST_SetSRID(ST_MakePoint(%s, %s), 4326), 0.001)),
        directed := false
    );
    """
    params = (x_origen, y_origen, x_destino, y_destino)
    resultado = ejecutar_consulta(query_ruta, params)
    return [row[0] for row in resultado]

# Crear tabla para visualizar resultados
def guardar_resultados_ruta(ids_ruta):
    query_guardar = """
    CREATE TABLE IF NOT EXISTS ruta_resultado AS
    SELECT 
        id, 
        geom 
    FROM red_unificada
    WHERE id = ANY(%s);
    """
    ejecutar_consulta(query_guardar, (ids_ruta,))
    print("Ruta guardada en tabla ruta_resultado.")

# Función principal
def main():
    # Crear la vista unificada
    crear_vista_unificada()
    
    # Preparar las tablas para pgRouting
    preparar_tablas_para_pgrouting()
    
    # Calcular la ruta óptima
    x_origen, y_origen = -3.7038, 40.4168  # Ejemplo: Coordenadas de Madrid
    x_destino, y_destino = -0.1276, 51.5074  # Ejemplo: Coordenadas de Londres
    ids_ruta = calcular_ruta_a_estrella(x_origen, y_origen, x_destino, y_destino)
    print(f"IDs de la ruta calculada: {ids_ruta}")
    
    # Guardar los resultados
    guardar_resultados_ruta(ids_ruta)

if __name__ == "__main__":
    main()

import psycopg2
import geopandas as gpd
import matplotlib.pyplot as plt
from shapely import wkt

# Parámetros de conexión a PostgreSQL
PSQL_HOST = 'localhost'
PSQL_PORT = 5432
PSQL_DB = 'database'
PSQL_USER = 'user'
PSQL_PWD = 'password'

# Crear una conexión a la base de datos
def connect_to_db():
    try:
        connection = psycopg2.connect(
            host=PSQL_HOST,
            port=PSQL_PORT,
            database=PSQL_DB,
            user=PSQL_USER,
            password=PSQL_PWD
        )
        return connection
    except Exception as e:
        print("Error al conectar con la base de datos:", e)
        return None

# Función para ejecutar Beam Search
def beam_search(connection, start_id, end_id, k=3):
    try:
        with connection.cursor() as cursor:
            # Inicializar la búsqueda con el nodo de inicio
            cursor.execute(
                f"SELECT id, ST_AsText(geom) FROM eps.red1_puntos WHERE id = {start_id}"
            )
            start_point = cursor.fetchone()
            if not start_point:
                raise ValueError("El punto de inicio no existe en la base de datos.")

            current_paths = [(start_point[0], [start_point[1]], 0)]  # (id, camino, costo)
            final_paths = []

            while current_paths:
                new_paths = []
                for path_id, path_geom, path_cost in current_paths:
                    # Encontrar los k puntos más cercanos desde el último punto del camino
                    cursor.execute(f"""
                        SELECT id, ST_AsText(geom), 
                               ST_3DDistance(ST_SetSRID(geom, 25830), ST_SetSRID(ST_GeomFromText('{path_geom[-1]}'), 25830)) * 3 AS cost
                        FROM eps.red1_puntos
                        WHERE id != {path_id}
                        ORDER BY geom <-> ST_SetSRID(ST_GeomFromText('{path_geom[-1]}'), 25830)
                        LIMIT {k}
                    """)
                    neighbors = cursor.fetchall()

                    for neighbor_id, neighbor_geom, neighbor_cost in neighbors:
                        if neighbor_id == end_id:
                            # Si alcanzamos el destino, guardar el camino final
                            final_paths.append((path_geom + [neighbor_geom], path_cost + neighbor_cost))
                        else:
                            # Agregar nuevos caminos
                            new_paths.append((neighbor_id, path_geom + [neighbor_geom], path_cost + neighbor_cost))

                # Mantener solo los k caminos más prometedores
                new_paths.sort(key=lambda x: x[2])  # Ordenar por costo acumulado
                current_paths = new_paths[:k]

            # Seleccionar el camino final de menor costo
            best_path = min(final_paths, key=lambda x: x[1])
            return best_path
    except Exception as e:
        print("Error durante Beam Search:", e)
        return None

# Función para visualizar el camino en un mapa
def visualize_path(path):
    try:
        # Convertir geometrías WKT en GeoDataFrame
        geoms = [wkt.loads(geom) for geom in path[0]]
        gdf = gpd.GeoDataFrame(geometry=geoms)
        gdf.plot()
        plt.title("Camino de menor costo")
        plt.show()
    except Exception as e:
        print("Error al visualizar el camino:", e)

# Ejecutar el algoritmo
if __name__ == "__main__":
    connection = connect_to_db()
    if connection:
        start_id = 0  # Punto de inicio
        end_id = 5    # Punto de destino
        best_path = beam_search(connection, start_id, end_id)
        if best_path:
            print("Mejor camino encontrado:", best_path)
            visualize_path(best_path)
        connection.close()

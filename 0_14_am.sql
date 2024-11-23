CREATE EXTENSION postgis;
CREATE EXTENSION pgrouting;

--- Comprobación de la versión de PostGIS y pgRouting después de habilitarlos en la base de datos.
SELECT PostGIS_full_version();
SELECT * FROM pgr_version();


--- Actualización de la base de datos
ALTER EXTENSION pgrouting UPDATE TO "3.7.0";

--- Dependencias de bases de datos
sudo apt install postgresql-15
sudo apt install postgresql-server-dev-15
sudo apt install postgresql-15-postgis
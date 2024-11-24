# RouteOptimizer

Projecte desenvolupat per al HackEPS 2024.

## Descripció del Projecte

RouteOptimizer és una solució al repte d'optimització de rutes en xarxes terrestres multicapa, enfocada en vehicles autònoms i mobilitat avançada. L'objectiu principal és calcular rutes de menor cost entre un origen i una destinació, tenint en compte:

* Transicions entre diferents capes de xarxa (urbanes, autopistes, camins rurals, etc.).
* Restriccions dinàmiques com costos variables i punts d'accés limitats.
* Optimització de l'ús de recursos computacionals per garantir temps d'execució eficients.

## Característiques Principals

* Base de dades: S'utilitza PostgreSQL per gestionar les capes de dades i punts de transició entre xarxes.
* Visualització: Integració amb eines de Python per a la visualització de dades multicapa i creació d'extensions personalitzades.
* Docker: Contenidor Docker amb configuracions predefinides per a l'execució del projecte.
* Eficiència: Implementació d'algorismes optimitzats per a temps d'execució ràpids i ús eficient de recursos.

## Requisits

Dependències principals:
* PostgreSQL 14+
* Python 3.9+
* Docker i Docker Compose

Estructura de dades necessària:
* Punts de transició entre capes.
* Costos predefinits per a les xarxes.

## Instal·lació

1. Clonar el repositori:
```
git clone https://github.com/usuari/RouteOptimizer.git
cd RouteOptimizer
```
2. Configurar Docker: Construir i executar els contenidors:
```
docker-compose up --build
```
3. Importar la base de dades: Importar els fitxers SQL proporcionats:
```
psql -U usuari -d nom_base_dades -f capa_unica.sql
psql -U usuari -d nom_base_dades -f multicapa.sql
```
4. Iniciar l'entorn de desenvolupament: Executar l'entorn de visualització:
```
python3 main.py
```


# Ciudades variadas, aceras y giros de coches

## Trazados (`generador_mundo.gd`, clave `trazado` de cada asentamiento)
| Id | Nombre | Dónde sale | Qué es |
|---|---|---|---|
| 0 | cuadrícula | aldeas, algunos pueblos/ciudades | Calles rectas cada 44 m (aldeas sin aceras). |
| 1 | casco antiguo | ~40 % de los pueblos | Casas iguales de 13 m pegadas a la acera, **callejones empedrados de 3 m** en cruz por cada manzana, farol en el cruce, sin solares vacíos. |
| 2 | cuadrícula irregular | ~30 % de pueblos y ~25 % de ciudades | Faltan calles interiores (`arista_existe`): hay calles sin salida y **paseos peatonales** empedrados con árboles y banco. La red de tráfico y peatones sigue solo las calles que existen. |
| 3 | mixto | ~35 % de las ciudades | Casco antiguo en el centro (cerca < 2 manzanas) y cuadrícula fuera. |

Las casas siguen sin girar (los interiores dependen de ello), por eso aún no hay radial, ribereño ni de ladera.

## Aceras (pueblos y ciudades)
Bordillo claro + baldosa de 2,2 m (3 tonos) alrededor de cada manzana, 15 cm sobre la calzada, y un árbol cada ~10 m pegado al bordillo.
El solar de cada casa baja de 18 a 15,5 m para dejar sitio a la acera (`ACERA = 2.5`). La franja del peatón (a 6 m del eje) queda libre.

## Giros de coches (`vida_urbana.gd`)
Al acercarse a un cruce el coche elige con tiempo el siguiente tramo (`_elegir_siguiente`). Si hay que girar, entre la línea de detención y la salida sigue
una curva Bézier cúbica (`curva`): orientación = tangente, velocidad según lo cerrada que sea (~15 km/h a 90°, ~10 km/h en vuelta en U) y frena antes.
Ya no hay salto lateral ni giro en ángulo recto. Semáforos, pasos de cebra y esperas funcionan igual (también se espera si hay peatones en la calle de salida).

## Pruebas
- `tests/prueba_giros.tscn -- segundos tipo` (saltos de posición, giro máximo, curvas completadas).
- `tests/prueba_trazados.tscn` (reparto, red conectada, casas dentro del solar, callejón de 3 m).
- `tests/captura_trazados.tscn -- carpeta` (aéreas, calle, callejón, coche girando).

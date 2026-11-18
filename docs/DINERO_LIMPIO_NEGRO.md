# Dinero limpio y dinero negro

Mecánica de ficción del juego (estilo juegos de negocios). No describe nada real: son números y reglas del juego.

## Idea
- **Dinero limpio** (`Juego.dinero`, el de siempre; empiezas con 200 $) vale en todas partes.
- **Dinero negro** (`Juego.dinero_negro`) es lo que ganas con el trato ilegal (venta de pociones por la ventana, encargos del móvil, botín de guardias).
- El negro **no** vale en el banco ni para licencias, casas, coches, inmobiliaria, sueldos, alquileres o gastos de negocio (todo eso usa `Juego.gastar()`, solo limpio).
- El negro **sí** vale en compras de calle: tiendas, taxi, gasolinera, taberna y pedidos de material (`Juego.gastar_con_negro()`, gasta primero negro).
- Para pasarlo a limpio hay que **blanquearlo** en un negocio tuyo (móvil o ventana de negocios > pestaña **Lavado**).

## Frentes de blanqueo (`scripts/datos/blanqueo.gd`)
| Licencia | Límite/día | Comisión | Riesgo |
|---|---|---|---|
| Tienda de barrio (nueva, 3.000 $, nivel 2) | 300 | 25 % | x1,0 |
| Alquiler de coches | 1.200 | 18 % | x0,9 |
| Inmobiliaria | 1.800 | 16 % | x0,8 |
| Concesionario | 2.500 | 14 % | x0,8 |
| Alquiler de maquinaria | 3.500 | 12 % | x0,7 |
| Aeródromo | 9.000 | 10 % | x0,6 |

El límite crece un 25 % por cada propiedad o vehículo de su tipo en tu cartera (hasta 4) y se renueva cada día.

## Riesgo
- **Vigilancia fiscal** (0-100): blanquear el límite entero de un frente sube 40 x riesgo. Baja 8 al día.
- Con 80 o más, cada día hay un 50 % de **inspección**: te quitan el 25 % del negro, multa del 5 % del limpio y +1 estrella.
- Blanquear sube también la **sospecha** de los guardias (4 por cada 1.000 $).
- Llevar 300 $ o más de negro sube la sospecha por segundo (hasta 1,2/s con 4.000 $), aumenta un 50 % la probabilidad de cacheo y cuenta como riqueza para los refuerzos de la policía por estrellas.
- **Cacheo**: se puede esconder el dinero negro (65 %); si no, se confisca el 60 %.
- **Detención**: confiscan 40 % + 12 % x estrellas del negro. **Muerte**: pierdes el 40 %.

## Guardado
`dinero_negro`, `vigilancia_fiscal` y `negocio.blanqueo` (límites usados hoy y total). Las partidas antiguas cargan con 0.

## Multijugador (docs/MULTIJUGADOR.md, PR 14)
Todo el dinero pasa por `Juego` (`cobrar`, `cobrar_negro`, `gastar`, `gastar_con_negro`, `dinero_total`) y por `Blanqueo`. La "cartera" es: `dinero`, `dinero_negro`, `banco`, `vigilancia_fiscal` y `negocio.blanqueo`. En modo `propio` irá en `EstadoJugador`; en `cooperativo` en `EstadoEquipo` compartido, cambiando solo dónde leen y escriben esas funciones. El servidor autoritativo debe validar cada `blanquear()` (distancia al negocio, saldo, límite). La vigilancia fiscal y la sospecha serían por jugador (o por equipo en cooperativo).

## Pruebas
`godot --headless --path . res://tests/prueba_dinero_negro.tscn` y capturas con `tests/captura_dinero.tscn`.

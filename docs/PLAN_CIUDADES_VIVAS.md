# Plan: ciudades vivas, tráfico, variedad y carreteras de montaña

Revisión hecha el 2026-11-18 sobre la rama integrada `claude/project-thread-bxnc21` (incluye los PR 2-9).
Todo está escrito en la nube y **sin probar en Godot**.

## 1. Diagnóstico honesto (qué hay hoy)
| Cosa | Estado |
|---|---|
| Tráfico de coches | **No existe.** Solo hay coches aparcados, el coche patrulla (policía) y los vehículos que conduce el jugador. |
| Semáforos | **No existen.** |
| Peatones | **No existen.** Solo hay guardias, tenderos y compradores fijos en sitios concretos. |
| Ciudad original | Cuatro barrios hechos a mano; las calles están como datos en `red_calles.gd` (preparado para tráfico, sin usar). |
| Asentamientos | Eran ~34 en celdas de 1200 m: mucha distancia entre ellos. |
| Variedad | Todas las casas salen de pocas plantillas con 6 colores de pared y 3 de techo; solo 4 distritos (centro, rico, industrial, residencial). Aldeas y pueblos son una cuadrícula igual. |
| Terreno | Altura máxima ≈ 160 m (9·ruido + 150·máscara de montaña). Una colina de 157 m en 10 km es muy poco: no hay sensación de montaña. |
| Carreteras | Segmentos **rectos** puerta a puerta, pegados al terreno (`_dibujar_carreteras`): si cruzan una montaña la suben y bajan en línea recta, sin curvas, sin desmontes y **sin quitamiedos**. Los pueblos no se generan donde la base supera 30 m, así que **no hay pueblos de montaña**. |

## 2. Hecho en este PR
1. **Modo volar** en el panel de administrador (F1): casilla "Volar" + botón "Velocidad normal".
   Volando: WASD hacia donde miras, Espacio sube, C/Ctrl baja, Mayús x3, **rueda del ratón** cambia la
   velocidad (de 2 a 3000 m/s, un 15 % por muesca). Atraviesa edificios y suelo (sin colisiones).
2. **Más asentamientos, más cerca**: celdas de 700 m (antes 1200), ~135 asentamientos (antes ~43;
   ~90 aldeas, ~35 pueblos, ~10 ciudades). Si dos zonas se pisan, gana la más grande. Se calculan una
   sola vez al iniciar (seguro para los hilos de los trozos).

## 3. Plan priorizado
**P1 – Vida en la ciudad** (más valor, riesgo bajo)
1. Peatones con rutinas día/noche: aparecen solo cerca del jugador sobre `RedCalles`; de día pasean y
   van a tiendas, de noche se recogen en casas y quedan borrachos en la taberna. Reaccionan a disparos.
2. Tráfico: coches que siguen los tramos de `RedCalles` y giran en cruces; solo existen en un radio de ~150 m.
3. Semáforos en los cruces de la plaza y avenidas (ciclo verde/ámbar/rojo); los coches paran, y cruzar en
   rojo con la policía delante suma sospecha (ya existe `_vigilar_trafico` en `guardia.gd`).
4. Mismo sistema extendido a pueblos y ciudades generados (usando sus calles de `_calles_de`).

**P2 – Variedad**
5. Estilos de asentamiento por región (clima/bioma): pueblo de piedra, de madera, blanco costero, minero.
6. Más plantillas de casa (tejados a dos aguas, torres, soportales), paletas por distrito, tamaño y altura variables.
7. Elementos únicos por asentamiento: iglesia/plaza, mercado, molino, faro, puente; nombres y mapa con iconos.
8. Bosques, ríos y lagos con carácter propio.

**P3 – Montaña y carreteras de experto**
9. Subir el relieve: montañas de 400-900 m con cordilleras (ruido "ridged") manteniendo llanuras para ciudades.
10. Carreteras que **no** vayan en recta: trazado por pendiente máxima (≤ 8-10 %) con serpentinas y
    curvas suaves (curvas de Bézier/spline sobre el relieve), terraplén y desmonte lateral.
11. **Quitamiedos** (barrera metálica con postes cada 4 m) en el lado del precipicio, muros de piedra,
    túneles cortos y puentes en barrancos, señales de curva y de "peligro, desprendimientos".
12. **Pueblos de montaña** (aldeas en laderas/valles altos, con terrazas) accesibles solo por carretera de
    montaña; nieve arriba, leñadores, minas y refugios. Servirán para encargos de materias primas raras.
13. Física: los coches deben aguantar pendientes y se frenan en curvas; el tráfico de montaña es escaso.

**P4 – Sentido global (economía, misiones, historia)**
14. Cada región produce y consume cosas distintas (la montaña: minerales y hierbas raras; la costa: sal y
    pescado); los precios varían por región y se ganan con viajes (coche, camión, tren, avioneta).
15. Los encargos usan estas regiones; las misiones llevan a pueblos de montaña lejanos.
16. Línea de historia: la "Hoja de Bruma" nace en la montaña; policía y bandas se organizan por regiones.

## 4. Riesgos
- El relieve y las carreteras nuevos son un cambio grande en `generador_mundo.gd`: conviene probarlo en el PC
  (rendimiento al cargar trozos, tirones, orden de caras) antes de seguir con P3.
- Peatones y tráfico deben crearse **solo cerca del jugador** para no hundir los FPS.

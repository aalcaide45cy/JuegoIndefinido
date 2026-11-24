# La magia de Juego Indefinido

Aprobado por Alfonso el 24 de noviembre de 2026 (4 escuelas). Datos en `scripts/datos/magia.gd`,
sistema en `scripts/magia.gd`, grimorio en `scripts/ui/ventana_grimorio.gd`.

## La idea

En este mundo **la magia existe pero está prohibida**. Cualquiera puede aprenderla, y sirve para
todo: para el trabajo, para el negocio, para escapar de la policía o para pelear. Cuanto más la usas,
mejor la dominas. Pero si te ven, tienes un problema.

Tres reglas:

1. **Se aprende usándola.** Cada escuela sube del nivel 1 al 5 al lanzar sus hechizos. Al subir, los
   hechizos cuestan menos maná y son más fuertes, y se aprenden hechizos nuevos.
2. **Cuesta maná.** Tienes 100 de maná, que se recupera solo (más rápido cuanto más nivel tienes).
   Cada hechizo tiene además un tiempo de espera.
3. **Es ilegal.** Si un guardia te ve lanzar un hechizo, sube una estrella de búsqueda. Si te ve la
   gente de la calle, sube la sospecha. De noche te ven la mitad, con Velo o Apagón aún menos, y
   dentro de los edificios la gente de la calle no te ve. Cada hechizo tiene su "riesgo": un Empujón
   se ve mucho; unos Ojos de búho casi nada.

## Controles

- **F**: lanzar el hechizo preparado.
- **Q**: preparar el siguiente hechizo que sepas.
- **K**: grimorio (escuelas, niveles, hechizos; elegir cuál preparar).
- Se pueden cambiar en Esc > Controles.

## Las 4 escuelas y sus 12 hechizos

| Escuela | Nivel 1 | Nivel 2 | Nivel 3 |
|---|---|---|---|
| **Naturaleza** (verde): crecer, sanar, ver | **Brote**: las macetas cercanas crecen de golpe | **Sanar**: recuperas vida al momento y un poco más después | **Ojos de búho**: ves de noche casi como de día |
| **Ilusión** (violeta): engañar | **Velo**: casi invisible para los guardias durante 25 s | **Rostro ajeno**: cambias de cara, baja una estrella y la alerta | **Encanto**: los clientes pagan más |
| **Fuerza** (naranja): empujar, proteger, moverse | **Empujón**: lanza hacia atrás a quien tengas delante | **Escudo**: recibes mucho menos daño | **Zancada**: corres más y saltas más alto |
| **Sombras** (azul): abrir, oscurecer, asustar | **Ganzúa sombría**: abres sin ruido una puerta cerrada | **Apagón**: se apagan las luces de alrededor durante un minuto | **Pavor**: la gente cercana huye aterrada |

Números (coste, espera, riesgo, alcance) en `scripts/datos/magia.gd`: cambiarlos es todo lo que hace
falta para equilibrar.

## Cómo encaja con el resto del juego

- **Oficios**: Brote ayuda al cultivo; Encanto a cualquier oficio de cara al público; Sanar al médico.
- **Negocio ilegal**: Velo y Rostro ajeno para escapar; Apagón para moverte de noche.
- **Asaltos**: Ganzúa sombría abre puertas sin hacer ruido (y sin gastar ganzúas).
- **Combate**: Empujón, Escudo y Pavor.
- **Pociones**: los efectos de los hechizos son los mismos que los de las pociones (`datos/efectos.gd`),
  así que se ven en el mismo panel de efectos.

## Lo que queda (siguientes pasos)

- [ ] Hechizos de nivel 4 y 5 (uno por escuela): por ejemplo Enredadera (inmoviliza), Doble (copia
  ilusoria que distrae), Onda (empuja en círculo), Sombra andante (atraviesas una pared fina).
- [ ] Magia en los oficios con minijuego propio: tinte mágico en la peluquería, desatasco mágico del
  fontanero, curación mágica del médico (MAG-3 del plan).
- [ ] Grimorios que se compran o se encuentran, para aprender antes un hechizo.
- [ ] Maestros de magia escondidos en el mapa (uno por escuela) que dan misiones.
- [ ] Efectos visuales propios por hechizo (ahora todos usan un estallido de cubitos de luz del color
  de su escuela) y sonidos propios.
- [ ] Mando: asignar lanzar y cambiar de hechizo (hoy solo teclado).
- [ ] Los personajes reaccionan a la magia (los hilos de IA pueden implementar `asustar(desde)` y
  `empujar(impulso)` en peatones, guardias y vecinos; la magia ya los llama si existen).

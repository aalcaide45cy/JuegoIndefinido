# Oficios y variedad: "Se puede ser cualquier cosa"

Documento de diseño. Escrito el 2026-11-21 sobre la rama `claude/project-thread-e0ycx5`.
Parte 1 es la auditoría de lo que hay hoy (leyendo el código). Parte 2 es el catálogo de oficios
que queremos. Parte 3 explica cómo se entra y se sale de un oficio, cómo se progresa y cómo
encaja con el dinero limpio y negro y con la magia. Parte 4 dice qué se ha hecho ya
(peluquería y barbería) y cómo añadir un oficio nuevo sin repetir código.

## 0. La idea

El juego es **vivir la vida**: cada persona puede ser lo que quiera (peluquero, fontanero,
alquimista, taxista, ladrón...) y cambiar cuando quiera. Por eso el nombre **"Indefinido"** le
va bien: nadie está definido para siempre. Propuesta de título (solo propuesta, no se ha
cambiado nada): **«Contrato Indefinido»**. Cada oficio es un "contrato" que firmas y puedes
romper, y siempre conservas tu rango en los oficios que dejaste.

Todo sigue siendo low poly, y lo mágico no desaparece: la Hoja de Bruma, las pociones y el
caldero siguen siendo el hilo especial del juego. Cada oficio tendrá su toque mágico
(el peluquero tiñe con tinte de bruma, el fontanero desatasca tuberías encantadas...).

## 1. Auditoría: qué hay hoy

| Área | Qué existe | Hueco de variedad |
|---|---|---|
| Oficios del jugador | 4 con rangos, sueldo por hora y avisos por la calle: policía, médico, bombero, mecánico (`datos/oficios.gd`) | Todos son "de emergencias". Ninguno de oficio manual, de comercio, de campo o de arte. Los avisos son siempre iguales (pulsar E varias veces). |
| Personal que contratas | 3: agricultor, ganadero, guardaespaldas (`datos/personal.gd`) | Pocos. No hay cocinero, camarero, mensajero... |
| Negocios | 6 licencias: inmobiliaria, concesionario, alquiler de coches y de maquinaria, aeródromo, oficina (`datos/negocios.gd`) | Solo compraventa y alquiler de pisos y vehículos. No puedes montar una peluquería, un bar o un taller propio. |
| Servicios de la ciudad | Banco, taberna, hospital, taller, gasolinera, comisaría, bomberos, discoteca, tragaperras, casino, club, timba, prestamista, mercado negro | Poca vida cotidiana: no había peluquería, farmacia, panadería abierta al público, tintorería, gimnasio... |
| Tiendas | 11 tiendas de 6 tipos (herbolario, ferretería, panadería, botica, armería...) | Todas venden objetos del mismo modo. No hay tienda de ropa, de muebles ni de peluquería. |
| Aspecto | Piel, pelo (6 colores), 3 peinados, sombrero, abrigo, bufanda, cuerpos | Solo se cambiaba en una ventana gratis (tecla O). No había sitio donde "ir a arreglarse". |
| Encargos | Encargos del móvil de pociones y 10 lugares fijos (`encargos.gd`) | Solo pociones. No hay encargos de otros oficios. |
| Mundo | Ciudades, pueblos, aldeas, barrios (residencial, industrial, mercado, campo, plaza) | Los edificios son cajas por fuera. Los interiores los hace otro hilo. |
| Logros | 22, ninguno de oficios | Ni ascender, ni cambiar de oficio, ni probar muchos. |
| Interacciones | E usa, Mayús+E es la acción alternativa, minijuegos de plantar, remover y machacar | Un oficio nuevo no tiene su propio minijuego. |

**Conclusión:** el motor de oficios es bueno (datos + avisos + rangos), pero solo hay oficios
de un tipo y todo se resuelve igual. Lo que falta es variedad de *oficios*, de *lugares donde
ejercerlos* y de *cómo se juegan*.

## 2. Catálogo de oficios

Leyenda: **Lugar** = edificio donde se ficha; **Juego** = cómo se trabaja; **Magia** = su
toque especial; **Dinero** = limpio (declarado) o negro.

### 2.1 Cuidado personal
| Oficio | Lugar | Juego | Magia | Dinero |
|---|---|---|---|---|
| **Peluquero** *(hecho)* | Peluquería | Clientes que piden un peinado y color | Tintes mágicos con Hoja de Bruma | Limpio |
| **Barbero** *(hecho)* | Barbería | Clientes con barba y peinado | Navaja de plata: afeitado "de luna" | Limpio |
| Tatuador | Estudio de tatuajes | Diseñar y pintar un dibujo en un cliente | Tinta que brilla de noche | Mixto |
| Masajista / spa | Balneario | Minijuego de ritmo | Aguas termales con efecto de poción | Limpio |
| Sastre | Sastrería | Cortar y coser trajes nuevos para el aspecto | Hilo encantado | Limpio |

### 2.2 Casa y construcción
| Oficio | Lugar | Juego | Magia | Dinero |
|---|---|---|---|---|
| Fontanero | Almacén de fontanería | Aviso de fuga: encontrar la tubería y apretar | Tuberías con duendes | Limpio |
| Electricista | Almacén eléctrico | Conectar cables del mismo color | Luces de bruma | Limpio |
| Carpintero | Carpintería | Cortar y ensamblar muebles para vender | Madera de árbol viejo | Limpio |
| Albañil / obrero | Obras | Poner bloques con ritmo | Piedra que se arregla sola | Limpio |
| Cerrajero | Cerrajería | Abrir cerraduras (ganzúa); a veces para ladrones | — | Mixto |

### 2.3 Comida y hostelería
| Oficio | Lugar | Juego | Magia | Dinero |
|---|---|---|---|---|
| Cocinero | Restaurante | Minijuego de remover (ya existe) | Platos con efectos como pociones | Limpio |
| Camarero | Taberna, restaurante | Llevar pedidos sin tirarlos | Propinas extra de noche | Limpio |
| Panadero | Panadería | Amasar y hornear a tiempo | Pan de bruma | Limpio |
| Barman | Club de copas | Mezclar copas (como las mezclas del caldero) | Cócteles mágicos | Mixto |

### 2.4 Transporte y reparto
| Oficio | Lugar | Juego | Magia | Dinero |
|---|---|---|---|---|
| Taxista | Parada de taxis (ya hay taxi) | Llevar clientes a su destino | Atajos mágicos | Limpio |
| Mensajero | Oficina de correos | Repartir paquetes a tiempo en bici o moto | Cartas que vuelan | Limpio |
| Camionero | Nave industrial | Rutas largas con camión y remolque (ya hay vehículos) | — | Limpio |
| Piloto | Aeródromo | Vuelos (ya hay avioneta y helicóptero) | — | Limpio |

### 2.5 Campo y naturaleza
| Oficio | Lugar | Juego | Magia | Dinero |
|---|---|---|---|---|
| Granjero | Huerto, corral (ya existe) | Plantar y cosechar | Cultivos mágicos | Limpio |
| Pescador | Puerto o lago | Minijuego de caña | Peces que dan efectos | Limpio |
| Minero | Mina de la montaña | Picar vetas | Gemas mágicas | Limpio |
| Leñador | Bosque | Talar con ritmo | Árboles viejos | Limpio |
| Herborista / alquimista *(es el origen del juego)* | Casa con caldero | Plantar, machacar, cocinar | Pociones | Negro (ilegal) o limpio (botica) |

### 2.6 Oficios con tienda y oficina
| Oficio | Lugar | Juego | Magia | Dinero |
|---|---|---|---|---|
| Tendero | Tienda propia | Atender y poner precios | Objetos raros | Limpio |
| Mecánico *(ya existe)* | Taller | Avisos de coches averiados | Piezas encantadas | Limpio |
| Herrero | Herrería | Martillear con ritmo y forjar armas y herramientas | Acero de bruma | Limpio |
| Periodista | Periódico | Conseguir noticias y escribir | Rumores del Club de Copas | Limpio |
| Músico | Plaza, taberna | Minijuego de ritmo | Melodías con efecto | Limpio |
| Contable | Oficina | Cuadrar libros (blanquear dinero negro, con riesgo) | — | Mixto |

### 2.7 Servicio público (ya existen)
Policía, médico y bombero. Añadir: **maestro** (escuela), **jardinero** (parques),
**basurero** (limpieza de calles) y **guardia de seguridad** (casino y banco).

### 2.8 Oficios de sombra
Contrabandista, ladrón de casas, cobrador del prestamista, trilero de la timba, camello de
pociones. Pagan más, dan dinero **negro** y suben las estrellas de policía.

## 3. Cómo funciona un oficio

### 3.1 Entrar y salir (el "contrato")
1. Vas al lugar del oficio y pulsas **Mayús+E**: "hacerte peluquero". Se llama *fichar*.
2. Con **E** (o Mayús+E de nuevo) *entras de servicio* y empiezan los clientes o avisos.
3. Terminar el turno cobra el sueldo acumulado. Cambiar de oficio no borra el rango del anterior.
4. **Requisitos** por oficio (campo `requisito` en los datos): sin estrellas de policía,
   nivel mínimo, herramienta (tijeras, llave inglesa...) o licencia.
5. Un oficio se puede perder: la policía expulsa a un policía buscado.

### 3.2 Progresión
Cuatro rangos por oficio con multiplicador de sueldo y ventajas (ver `rangos` en
`datos/oficios.gd`): por ejemplo Aprendiz → Oficial → Maestro → Jefe. La experiencia de oficio
(XP) se gana por hora de servicio y por cada cliente. Ideas siguientes: habilidades propias por
oficio (el barbero rápido, el fontanero que no se moja), herramientas mejores y el "local propio".

### 3.3 Ingresos y economía
- **Sueldo por hora** en turno (11 a 16 $ la hora hoy) más **pago por cliente o aviso** (30 a 60 $).
- Cada oficio da una **ventaja** en su sector (descuento en el hospital, en el taller, 50 % en la
  peluquería...). Así conviene *probar* varios oficios.
- Sumideros de dinero: el aspecto (peluquería), herramientas, licencias y alquileres. El oficio
  nunca debe pagar más que una poción bien vendida, pero tampoco da sospecha.
- **Dinero limpio y dinero negro:** los oficios legales pagan limpio (se puede ingresar en el
  banco sin problemas). Los oficios de sombra y las pociones pagan negro: hay que blanquearlo
  (el contable, el casino, la tienda de tapadera) o gastarlo en el mercado negro.

### 3.4 Minijuegos
Hoy: pulsar E varias veces. Propuesta: un minijuego corto por familia de oficio.
- Cuidado personal: elegir el estilo que pide el cliente (parecido al aspecto).
- Casa: unir cables, apretar tuercas.
- Cocina y alquimia: remover (ya existe), cortar y hornear a tiempo.
- Transporte: conducir a tiempo (ya hay vehículos).
- Arte: ritmo (música, forja).
Cada minijuego devuelve calidad (mala, buena, perfecta) que sube la propina y la XP.

### 3.5 Edificios necesarios
Cada oficio necesita su edificio de ciudad con letrero (se declara en `generador_mundo.gd`,
tablas `SERVICIOS_CIUDAD` y `SERVICIOS_PUEBLO`). Con interiores (otro hilo) los clientes y las
sillas estarán dentro del local. Mientras tanto, los avisos salen por la calle. Edificios nuevos
a añadir: restaurante, panadería abierta, estudio de tatuajes, sastrería, correos, escuela,
periódico, herrería, carpintería, almacén de fontanería y eléctrico, puerto, mina.

### 3.6 Lo mágico
Cada oficio tiene un ingrediente mágico que sale de la Hoja de Bruma o de las pociones: es lo
que lo hace distinto de un juego de oficios normal. Reglas: lo mágico cuesta una hoja de
bruma, no es obligatorio y nunca rompe la economía.

## 4. Lo que ya está hecho (primera versión)

Peluquería y barbería, y la base para añadir oficios con datos.

- **Dos locales nuevos** en ciudades (y una peluquería en pueblos) con letrero y puerta: se usa
  con **E** para cambiarte de aspecto y con **Mayús+E** para ficharte de peluquero o barbero.
- **Aspecto ampliado** (`jugador/aspecto.gd`): 3 peinados nuevos (mohicano, coleta, afro),
  barbas (bigote, perilla, corta, larga) y dos tintes mágicos (verde Hoja de Bruma y violeta de luna).
- **Ventana de peluquería** (`ui/ventana_peluqueria.gd`): muñeco que gira, precios por opción, pago.
  Los tintes mágicos gastan una hoja de bruma. Si trabajas ahí, pagas la mitad.
- **Oficios peluquero y barbero** en `datos/oficios.gd`, con rangos, sueldo y clientes: salen
  clientes por la calle sentados en un sillón que piden un peinado concreto.
- **Datos:** todo lo de estética está en `scripts/datos/peluqueria.gd` (locales, precios,
  tintes, clientes).
- **Pruebas:** `tests/prueba_peluqueria.tscn` (sin ventana) y `tests/captura_peluqueria.tscn`.

### Cómo añadir un oficio nuevo (receta)
1. Copia una entrada de `LISTA` en `scripts/datos/oficios.gd` (nombre, lugar, sueldo, rangos, avisos).
2. Añade el lugar en `generador_mundo.gd` (`SERVICIOS_CIUDAD`, color, nombre y franja) y en
   `servicio_mundo.gd` (`NOMBRES`). Mayús+E ficha solo, porque el sistema busca el oficio por su lugar.
3. Si los avisos necesitan un dibujo nuevo, añade un `tipo` en `objetos/aviso_oficio.gd`.
4. Si es un negocio con ventana (como la peluquería), crea su archivo de datos en `scripts/datos/`
   y su ventana en `scripts/ui/`, copiando `peluqueria.gd` y `ventana_peluqueria.gd`.
5. Pruébalo copiando `tests/prueba_peluqueria.gd`.

### Siguiente en la lista (propuesta)
1. Logros de oficios (primer ascenso, tres oficios, maestro en uno).
2. Fontanero y electricista (oficios de casa) con minijuego de cables.
3. Cocinero y camarero cuando existan los interiores.
4. Local propio: comprar una peluquería con la licencia de negocios y contratar peluqueros.
5. Tatuador y sastre: más variedad de aspecto.

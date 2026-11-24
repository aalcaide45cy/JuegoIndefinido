# Física y destrucción del escenario

Documento del sistema nuevo (carpeta `scripts/fisica/`): qué había, qué hacen otros juegos,
qué se ha elegido y por qué, cómo está hecho, cuánto cuesta y qué falta.

## 1. Auditoría: cómo estaba

| Qué | Cómo estaba | Problema |
|---|---|---|
| Farolas, bancos, papeleras, barriles, señales del mundo grande | Cajas dentro de la malla gigante de cada trozo de 128 m (ConstructorMalla) | Imposible moverlas o romperlas: son triángulos de una sola malla. Un coche se paraba en seco contra un farolillo como si fuera un muro. |
| Farolas y props de la ciudad principal | Mallas sueltas que `fusionar_estaticos` junta en una sola al arrancar | Igual: después de fusionar no existen como objetos. |
| Muebles de los interiores | Una malla y un cuerpo estático por casa | Las sillas y cajas no se podían tirar. |
| Disparos | Rayo + `recibir_dano` si el objeto lo tiene; si no, marca de bala | Al escenario solo le quedaba un agujerito negro. |
| Explosiones | Luz, bola, cráter (tanda 1) y daño a la lista "danable" | No empujaban nada: no había nada con física que empujar. |
| Coches reventados | Tanda 1: quemados y con fuego | Bien; se mantiene. |

Conclusión: el problema no eran los efectos, era la **estructura**. Mientras el mobiliario esté
fundido en la malla del terreno, ninguna física puede tocarlo. Hacía falta sacarlo a objetos propios.

## 2. Comparativa: cómo lo hacen otros

| Juego | Técnica | Coste | ¿Nos vale? |
|---|---|---|---|
| GTA V / RDR2 | Props sueltos congelados que se "despiertan" al golpe; farolas que se doblan y caen; piezas pre-rotas | Bajo: solo cuesta lo que se mueve | **Sí, es la base elegida** |
| Just Cause 3/4 | Lo mismo + estructuras grandes pre-troceadas que caen por partes | Medio | Parcial: idea para fase 3 (edificios) |
| Red Faction Guerrilla | Edificios con piezas y uniones que se rompen por tensión | Alto | Más adelante y solo en edificios concretos |
| Teardown | Todo es vóxel destructible | Muy alto, motor propio | No en Godot con mundo de 10×10 km |
| BeamNG | Coches de cuerpo blando (nodos y vigas) | Muy alto | No; el hilo de vehículos va a cuerpo rígido con suspensión |
| Battlefield (Frostbite) | Fachadas que se caen en trozos predefinidos + decals de daño | Medio | Idea para fase 3 |

Para un mundo low poly enorme en Godot 4.7 con Jolt, lo que da más espectáculo por cada milisegundo
es el modelo GTA: **muchos objetos baratos que solo gastan cuando algo los toca**.

## 3. Diseño elegido

### ObjetoFisico (`scripts/fisica/objeto_fisico.gd`)
- `RigidBody3D` que nace **congelado en modo estático**: para Jolt es igual que una pared. 764 objetos
  cargados alrededor del jugador en una ciudad no cuestan casi nada.
- Se **despierta** con un golpe: bala, puñetazo, explosión, coche o el jugador al empujarlo.
- **Anclados** (farolas, bolardos, señales, bancos atornillados): un disparo no los mueve; solo un coche
  o una explosión. El **farol** de una farola sí se rompe de un tiro (cristales, chispas y la luz se apaga).
- **Vida**: al llegar a 0 se rompe en **sus propias piezas** (las cajas con las que está dibujado; si
  tiene pocas, se trocean). Las piezas salen como escombros con física.
- **Bolardos**: un coche a menos de 9 m/s (32 km/h) se para en seco. Más rápido, lo arranca.
- **Golpes al caer**: si algo sale volando y se estampa, se daña (la cerámica más, el metal menos).
- **Especiales**: el **bidón rojo explota** (y hace explotar a los de al lado, en cadena) y la **boca de
  riego** suelta un **géiser de agua** 12 segundos.
- Catálogo de 21 tipos: farola, farol de casco antiguo, farolillo de aldea, banco, banco rústico,
  papelera, bolardo, buzón, contenedor, boca de riego, cono, valla de obra, barril, bidón rojo, caja,
  pila de leña, señal de curva, señal de velocidad, silla, maceta y mesa de terraza. Más
  `desde_cajas()` (muebles de interiores) y `desde_modelo()` (modelos 3D de los kits).

### Efectos (`scripts/fisica/fisica_escenario.gd`)
- `onda()`: onda expansiva. Empuja todo cuerpo rígido en 1,6 × el radio, con caída por distancia y
  algo hacia arriba. Rompe lo que se queda sin vida. Llamada desde `Combate.explosion()`.
- `particulas()`: chispas (metal), astillas (madera), polvo (piedra), cristales, trozos de cerámica y de
  plástico, agua. Todas con malla compartida.
- `escombro()`: trozo con física que se queda un rato en el suelo, encoge y desaparece.
- `impacto_bala()`: para el hilo de armas (ver sección 6).

### GestorFisica (`scripts/fisica/gestor_fisica.gd`)
- Mira un poco **por delante de cada coche en marcha** (el tuyo y el tráfico cercano) y lanza lo que va a
  arrollar con la velocidad del coche. El coche pierde velocidad según lo que pese el objeto.
- Funciona con el chasis actual (`CharacterBody3D`) y con el rígido que prepara el hilo de vehículos
  (lee `linear_velocity`, o el meta `vel_choque` del tráfico).
- El jugador **empuja** cajas, conos, papeleras, sillas y barriles al andar contra ellos.
- Procesa las explosiones en cadena de los bidones (en el fotograma siguiente, para no hacer bucles).

### Dónde aparecen
- **Ciudades y pueblos**: farolas en los cruces y a media manzana al tresbolillo; en las aceras,
  papeleras, bancos, bolardos, bocas de riego, buzones, macetas, contenedores y terrazas (mesa con
  sillas en el centro). Barrio **industrial**: contenedores, bidones rojos, cajas y vallas.
  Parques: bancos mirando al centro y papeleras. Casco antiguo: faroles de hierro.
- **Aldeas**: farolillos de madera, barriles, cajas, pilas de leña y bancos rústicos.
- **Carreteras de montaña**: señales de curva y de velocidad (un coche las arranca) y obras en el arcén
  con conos y valla.
- **Ciudad principal**: farolas (con su luz de verdad) y los props sólidos de los kits (barriles, cajas,
  bancos, cofres, el muñeco de prácticas).
- **Interiores**: sillas, cajas, barriles, macetas y mesillas sueltas (no las camas ni los muebles con
  botín de los asaltos, ni los sanitarios, ni lo que está encima de una mesa).

## 4. Rendimiento y ajustes

- Objetos congelados ≈ coste de un muro. Solo se simula lo despierto, y Jolt lo duerme al pararse.
- Se dibujan hasta 320 m; malla compartida por tipo (una llamada de dibujo por objeto).
- Topes por calidad (menú **Gráficos > Violencia > Destrucción**, también en los presets):

| Calidad | Escombros a la vez | Partículas a la vez | Trozos por objeto | Vida del escombro |
|---|---|---|---|---|
| Baja | 12 | 8 | 3 | 5 s |
| Media | 60 | 20 | 6 | 10 s |
| Alta | 140 | 36 | 10 | 16 s |

- `FisicaEscenario.activa = false` lo apaga todo (para el panel de admin o pruebas).

## 5. Pruebas

- `tests/prueba_fisica.tscn` (sin ventana): 25 comprobaciones — disparo que empuja, farol que se
  rompe, coche que tumba la farola, bolardo que para, explosión que rompe y lanza, cadena de bidones,
  agua, jugador que empuja, coche de verdad que arrolla, muebles de interiores y mobiliario del mundo.
- `tests/captura_fisica.tscn`: capturas en el juego real (plaza, calle, farola atropellada, explosión,
  bidones, agua).

## 6. Para los otros hilos

- **Armas**: en `_disparar`, antes de la marca de bala, llamar a
  `FisicaEscenario.impacto_bala(choque, dir, dano)`; devuelve `true` si ha dado en algo con física.
  (Ahora mismo ya funciona sin tocar nada: `ObjetoFisico.recibir_dano` repite el rayo de la cámara.)
- **Vehículos**: con chasis `RigidBody3D`, poner en su `collision_mask` la capa 3 (valor 4) para que
  choque de verdad con los objetos despertados. El gestor ya los despierta antes del golpe.
- **Personajes / gore**: si un cuerpo es `RigidBody3D` (muñeco de trapo), `onda()` ya lo empuja. Si
  tiene `onda_expansiva(dir, dv, dano)`, se llama a esa en su lugar.
- **IA**: `onda()` llama a `EstimulosIA.emitir(..., "explosion", ...)` si ese archivo existe.

Capas de choque: 1 = mundo, personajes y coches; 3 (valor 4) = objetos del escenario;
5 (valor 16) = escombros (chocan con el mundo y los objetos, no entre sí ni con el jugador).

## 7. Siguientes fases (propuesta)

1. **Árboles**: que un coche rápido parta los árboles pequeños de las aceras (hoy son parte del trozo).
2. **Cristales**: escaparates y ventanas de los bajos que se rompen (nodos aparte, como las puertas).
3. **Edificios**: boquetes y trozos de fachada que caen con explosivos fuertes (estilo Battlefield:
   piezas predefinidas, no simulación completa).
4. **Persistencia corta**: recordar unos minutos lo roto aunque el trozo se descargue.
5. **Sonidos propios** por material (ahora usa el "golpe" genérico).

# Vehículos y tráfico: auditoría y rediseño

## 1. Cómo estaba (auditoría)

| Parte | Antes | Problema |
|---|---|---|
| Conducción | `CharacterBody3D` que se deslizaba como un muñeco | Sin suspensión, sin inercia real, sin derrapes, giraba como un tanque |
| Velocidades | 15–25 m/s de tope | Un deportivo no pasaba de ~90 km/h |
| Choques | Nada: el coche se paraba | Sin daño, sin abolladuras, sin chispas |
| Disparos | Los coches no reaccionaban | No había forma de reventarlos ni pinchar ruedas |
| Luces y sonido | Ninguno | Sin faros, freno, intermitentes ni motor |
| Tráfico | Velocidad fija, frenazo seco ante obstáculos | Parecía ir sobre raíles, sin carácter, sin luces de freno |
| Cámara | Fija detrás | Sin sensación de velocidad |

## 2. Comparativa

- **GTA V**: arcade con física debajo (suspensión por rayos, derrapes fáciles, daños visuales con
  deformación, ruedas pinchables, explosión tras incendio). Es nuestra referencia de "sensación".
- **BeamNG**: deformación física completa por nodos y vigas. Demasiado caro para un mundo abierto
  con tráfico; nos quedamos con la idea de abollar la malla donde se golpea.
- **Simuladores de tráfico (IDM)**: el modelo "Intelligent Driver Model" decide aceleración según
  la distancia y la velocidad del de delante. Da colas y frenadas suaves y creíbles con muy poco
  cálculo.

## 3. Diseño nuevo

### Física (`scripts/vehiculos/fisica_coche.gd`)
- `RigidBody3D` con una suspensión por rueda (muelle + amortiguador, rayo al suelo).
- Neumáticos con curva tipo Pacejka y "círculo de fricción" (si frenas fuerte, giras menos).
- Dirección Ackermann, barras estabilizadoras, motor limitado por potencia, cambio automático
  con revoluciones, control de tracción, ayuda de estabilidad, freno de mano para derrapar.
- Cada tipo tiene su perfil (masa, tracción, agarre, marchas, centro de gravedad).
- Se congela a más de 170 m de la cámara y se duerme aparcado para no gastar CPU.

Resultados en la prueba automática (`tests/prueba_conduccion.tscn`):

| Coche | 0–100 km/h | Punta |
|---|---|---|
| Deportivo | 4,4 s | 234 km/h |
| Todoterreno | 5,6 s | 149 km/h |
| Hatchback | 6,3 s | 156 km/h |
| Sedán | 6,6 s | 164 km/h |

### Daños (`vehiculo.gd`, `deformacion.gd`, `efectos_vehiculo.gd`)
- Choques: daño según el cambio de velocidad, abolladura real de la malla en el punto del golpe,
  chispas, cristales, sonido y temblor de cámara.
- Disparos: abollan, sacan chispas, pinchan la rueda si das cerca de ella, y por detrás (depósito)
  hacen más daño. La rueda pinchada se aplasta, agarra menos y frena el coche hacia ese lado.
- Salud baja: humo gris, luego negro. A cero: arde unos segundos y explota (o explota al momento
  si el golpe final es muy fuerte). Queda el coche quemado.
- Taller o kit de reparación: deja la chapa como nueva.

### Luces, sonido y marcas
- Faros de noche, luces de freno, marcha atrás e intermitentes.
- Motor sintetizado según revoluciones y carga, chirrido de ruedas y claxon (Q).
- Marcas de frenada en el suelo al derrapar.

### Tráfico (`vida_urbana.gd`)
- Aceleración con IDM: guardan distancia, frenan progresivamente, hacen cola.
- Cada conductor tiene carácter (prudente, normal, agresivo): velocidad, distancia, tiempo de reacción.
- Intermitentes en los giros, luces de freno, se inclinan al frenar y en las curvas, las ruedas giran.
- Te pitan si les cortas el paso más de 3 s.
- Si los embistes o disparas, pasan a ser coches físicos de verdad (se abollan, pinchan, explotan).

### Controles al conducir
W/S acelerar y frenar, A/D girar, Espacio freno de mano, Q claxon, R enderezar el coche, E bajar.
La cámara se pone sola detrás tras 1,2 s sin mover el ratón y abre el campo de visión con la velocidad.

## 4. Recomendaciones siguientes
- Activar la interpolación de física de Godot para que los coches se vean suaves en pantallas de 120/144 Hz.
- Poner a los peatones en su propia capa de colisión (ahora se usan excepciones por cercanía).
- Modelos de coche con piezas separadas (puertas, capó) para que puedan caerse.
- Tráfico que adelanta y cambia de carril.

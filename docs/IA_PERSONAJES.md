# IA de los personajes

Cómo piensan y se mueven peatones, vecinos de las casas y la gente de los locales. El código está
en `scripts/ia/`. Las pruebas, en `tests/prueba_ia.gd` y `tests/captura_ia.gd`.

## 1. Cómo estaba (auditoría)

| Qué | Problema que tenía |
|---|---|
| Peatones | Iban por raíles: seguían la acera a un lado fijo, sin mirar a nadie. Dos que se cruzaban se atravesaban. |
| Reacciones | Solo había una: huir corriendo en línea recta. Nadie se defendía, ni suplicaba, ni miraba. |
| Testigos | `asustar_testigos` buscaba el grupo `"peatones"`, que nadie llenaba: los disparos no asustaban a nadie. |
| Vecinos (asaltos) | Máquina de estados propia, cilindros de colores, sin animaciones. Iban en línea recta atravesando paredes de la casa. |
| Gente de los locales | Un muñeco quieto detrás del mostrador. Sin clientes. |
| Pies | En los pueblos con acera (0,3 m) los peatones iban hundidos 30 cm. |
| Interiores | 196 errores de script al generar locales de servicios (faltaban valores por defecto). |
| Aspecto | Al pasar al modelo humano (UAL) la gente salía en ropa interior. |

## 2. Diseño nuevo

Todos los personajes (peatones, vecinos, gente de los locales, civiles del panel de admin) usan
**el mismo cerebro**, `PersonaIA`. El cuerpo de cada uno (un `Agente` de la calle, un `Vecino`, un
`Ocupante`) solo aplica lo que el cerebro decide: velocidad, hacia dónde mira y qué animación pone.

```
          estímulos (disparos, gritos, muertes, atropellos)      percepción propia
                         │  EstimulosIA                          (te ve armado, le apuntas,
                         ▼                                        le empujas, coche encima...)
  carácter ──►  emociones (miedo, ira, alerta, que se apagan solas)
                         │
                         ▼
              árbol de comportamiento (ArbolIA)  ──►  acción  ──►  movimiento con esquiva
```

### Carácter
Cada persona nace con rasgos al azar: valentía, agresividad, curiosidad, sociabilidad, civismo,
agilidad, prisa y si va armada (pocos). Así, ante lo mismo, unos huyen, otros se encaran, otros
graban con el móvil (miran) y otros llaman a la policía.

### Árbol de comportamiento
`arbol_ia.gd` tiene las piezas: selector, secuencia, **utilidad** (elige la opción con más
puntuación, con histéresis para no cambiar de idea cada décima), condición, acción, enfriamiento,
probabilidad e inversor. Los árboles se comparten (uno por tipo) y cada persona guarda su memoria
aparte, así que cuesta poco tener cientos.

Árbol del **peatón**, por orden de prioridad:
1. Coche que se le viene encima → salta a un lado (predice la trayectoria del coche).
2. Amenaza (le has pegado, disparado, apuntado, ve un arma) → elige por utilidad entre
   **huir, pelear a puñetazos, sacar su arma y disparar, cubrirse, suplicar** (te da dinero si le
   sigues apuntando) **o llamar a la policía**.
3. Incidente cerca (pelea, herido, muerto) → socorrer al herido, mirar desde lejos o alejarse.
4. Le empujas → se queja.
5. Ves un arma en tu mano cerca → se pone nervioso y se aparta.
6. Va acompañado → camina al lado de su pareja (y se pone detrás si hay un árbol o farola).
7. Saluda a conocidos, se para a charlar con otros.
8. Si se ha salido de su ruta, vuelve a la acera; si no, pasea.

Árbol del **vecino** (casas y locales): amenaza (con la opción extra de esconderse en la habitación
más alejada) → socorrer a un herido → su rutina (pasea por la casa pasando por las puertas, o el
empleado por detrás del mostrador).

### Moverse con naturalidad
- **Esquiva predictiva**: calcula dónde estarán los demás en un momento y se aparta antes de chocar,
  más una pequeña separación para no ir pegados.
- **Bigotes**: tres rayos cortos a la altura de la cintura para no meterse en árboles, farolas o paredes.
- En la acera, cada uno va a su altura lateral y se aparta hacia la calle o hacia las casas para
  dejar paso; ya no "saltan" a la línea central al doblar una esquina.
- Paradas en escaparates, esperas con un poco de variación en los pasos de cebra, borrachos que
  hacen eses, parejas que van juntas.
- Animaciones al ritmo de la velocidad, puñetazos, esquivar tus golpes, agacharse, saludar...

### Peleas y armas
- Pelea a puñetazos: se pone a tu alcance dando vueltas, lanza golpes con su tiempo de animación y
  esquiva hacia un lado cuando tú golpeas.
- Armado: saca la pistola (o la escopeta, el dueño de un local), se aparta a 6–14 m, se mueve de lado
  y dispara si te ve. La puntería baja con la distancia, si corres, si estás agachado o en un coche.
  Las balas que fallan dejan marca, y una bala perdida puede herir a otro.
- Delitos: herir a alguien, atracarle o que te denuncie sube las estrellas de búsqueda.

### Ropa (`ropa.gd`)
El modelo humano viene en ropa interior y no tenemos ropa en 3D. La ropa se pinta sobre el cuerpo:
cada vértice se marca como camisa, pantalón, zapatos o piel según su altura en la pose de reposo, y un
shader mezcla colores por persona. Hay manga larga, corta o tirantes; pantalón largo, corto o falda;
pelo, barba y varios tonos de piel. Cuesta muy poco: todos comparten unas pocas mallas.

## 3. Comparación con juegos de mundo abierto

| Comportamiento | Juegos grandes del género | Aquí ahora |
|---|---|---|
| Huir de disparos | Sí | Sí, según carácter |
| Unos pelean y otros huyen | Sí | Sí (utilidad por carácter y emociones) |
| Civiles armados | Algunos | Sí (pocos peatones, algunos dueños de local) |
| Atracar apuntando | Sí | Sí (suplican y te dan dinero) |
| Llamar a la policía | Sí | Sí (sube estrellas si no lo impides) |
| Mirar o grabar el incidente | Sí | Sí (curiosos que se paran a mirar) |
| Socorrer heridos | Algunos | Sí |
| Esquivarse en la acera | Sí | Sí (predictivo) |
| Esquivar coches | Sí | Sí (saltan a un lado) |
| Parejas y charlas | Sí | Sí |
| Reacción en cadena por gritos | Sí | Sí (los gritos se propagan) |
| Ropa variada | Sí | Sí, pintada (sin modelos de ropa) |
| Navegación por todo el mapa | Sí (navmesh) | No: aceras, cruces y, en casas, habitaciones y puertas |

## 4. Límites y próximos pasos
- Fuera de la acera la navegación es local (esquiva y bigotes): quien huye lejos puede quedarse
  atascado contra una esquina hasta que el cerebro elige otra dirección. Un navmesh por manzana lo
  arreglaría.
- En algunos pueblos en pendiente el monte invade un poco las calles del borde: quien cruza por ahí
  roza el talud. Es del generador del terreno; la prueba de peatones lo cuenta aparte.
- La ropa es de colores lisos. Con modelos de ropa (los de la biblioteca de Fab, por ejemplo) se vería
  mucho mejor; `Ropa.vestir` es el único sitio que habría que cambiar.
- Falta: hacer cola en tiendas, sentarse en bancos, ir del trabajo a casa según la hora.

## 5. Pruebas
- `tests/prueba_ia.tscn`: árbol, todos con cerebro, esquivarse (cuántas veces se "atraviesan"),
  reacción a un disparo, pelea a puñetazos, armado que dispara y acierta, esquivar un coche, reacción
  al apuntar y civil armado.
- `tests/prueba_peatones.tscn`: que nadie atraviese edificios.
- `tests/captura_ia.tscn`: capturas de cada situación.

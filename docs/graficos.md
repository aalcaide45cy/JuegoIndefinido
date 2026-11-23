# Opciones gráficas

Menú: **Esc → Gráficos…** (también en el menú de inicio). **F3** enseña u oculta el contador de FPS.
Los ajustes se guardan en `user://ajustes.cfg` y se aplican al arrancar (`scripts/graficos.gd`, autoload `Graficos`).

## Qué se puede cambiar
| Opción | Qué toca |
|---|---|
| Preset (Bajo / Medio / Alto / Ultra / Personalizado) | Sombras, distancias, densidades, antialiasing, efectos y escala de render. No toca ventana, VSync, FOV ni brillo. |
| Renderizador | Compatibilidad (ligero, por defecto) o Forward+. Cambiarlo reinicia el juego (se relanza con `--rendering-method`). |
| Modo / resolución / VSync / límite de FPS | Ventana, pantalla completa sin bordes o exclusiva; VSync desactivada, activada, adaptativa o buzón. |
| Escala de render + método | 50 %–150 %; bilineal, FSR 1, FSR 2 (solo Forward+). |
| Antialiasing | Ninguno, FXAA, MSAA 2x/4x/8x, TAA (Forward+). En Compatibilidad FXAA se sustituye por MSAA 2x y TAA por MSAA 4x. |
| Sombras | Sin sombras / baja / media / alta / ultra (tamaño del atlas, filtro y distancia de las luces direccionales). |
| Distancia de dibujado | Multiplica el alcance de árboles/objetos con `visibility_range_end` y la distancia máxima de la cámara. |
| Distancia de carga de trozos | `RADIO_CERCA` y `RADIO_LEJOS` del `GestorTrozos`. |
| Densidad de vegetación | Aclara árboles, arbustos, rocas y flores al generar el trozo (los trozos cercanos se regeneran al cambiarla). |
| Densidad de peatones / tráfico | Multiplica el objetivo de peatones y `MAX_COCHES` de `VidaUrbana`. |
| Glow, SSAO, SSR, niebla volumétrica, SDFGI | Entorno del cielo. SSAO, SSR, niebla volumétrica y SDFGI solo existen en Forward+ (en Compatibilidad salen desactivados). |
| FOV, brillo, contador de FPS | La cámara del jugador (el zoom del francotirador no se toca). |

## Cómo engancha con el resto del juego
Casi todo se aplica escuchando `node_added` del árbol: entorno, sol y luna, `MultiMeshInstance3D` y `GestorTrozos`.
Cambios mínimos fuera del módulo: `gestor_trozos.gd` (los radios pasan de `const` a `var` y hay `recargar()`),
`generador_mundo.gd` (dos líneas de aclarado de vegetación), `vida_urbana.gd` (dos multiplicadores)
y los botones «Gráficos…» en `ventanas.gd`.

## Para las pruebas automáticas
Pasar `--sin-ventana` después de `--` impide que `Graficos` cambie el modo o el tamaño de la ventana
y que se relance con otro renderizador (así la ventana fuera de pantalla no salta). Ver `tests/prueba_graficos.gd`.

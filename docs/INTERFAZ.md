# Interfaz de Juego Indefinido

Todo el aspecto sale de un único tema de Godot (`scripts/ui/tema.gd`): colores, fuente Inter, botones,
pestañas, barras y paneles. Nada se pinta "a mano" con otro estilo.

## Piezas reutilizables (`scripts/ui/ui.gd`)
- `UI.Pestanas`: pestañas (teclado, ratón, LB/RB y Re Pág/Av Pág del mando).
- `UI.Filtros`: botones de filtro exclusivos (categorías).
- `UI.buscador`, `UI.tarjeta`, `UI.insignia`, `UI.barra`, `UI.seccion`, `UI.boton`, `UI.etiqueta`, `UI.nota`.
- `PanelInventario` + `DetalleObjeto`: rejilla de casillas con ficha del objeto (inventario, tiendas, estantería, caldero).
- `VentanaOpciones`: filas con deslizador, casilla o desplegable agrupadas en secciones; el buscador de `VentanaAjustes` las filtra.

## Ventanas
Todas heredan de `Ventana`. Para una ventana nueva usa `marco(titulo, subtitulo, tamaño)`: devuelve el cuerpo ya con
cabecera, botón Cerrar y pie con las teclas/botones. Dentro del cuerpo se puede poner un `ScrollContainer` propio.
No metas un `ScrollContainer` con altura "expandir" dentro de `panel_centrado()`: queda con altura 0 (la lista sale vacía).

## Mando
Los botones se enfocan con el stick/cruceta, A pulsa, B cierra, LB/RB cambian de pestaña. En el inventario:
A coge/suelta, X manda al otro lado, Y divide. El pie muestra los iconos del mando cuando hay uno conectado.

## Tamaño
Ajustes > Sonido y juego > Tamaño de la interfaz (de 75 % a 150 %). La interfaz se dibuja a 1280x720 de base y el
motor la escala, así que el texto sale nítido a cualquier resolución.

## Capturas
`xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1920x1080 res://tests/captura_menus.tscn -- /carpeta prefijo`
saca una captura de cada menú (sirve para comparar antes y después).

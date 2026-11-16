# Elixir Clandestino (nombre provisional)

Juego 2D de gestión hecho con **Godot 4.7** (GDScript). De día eres una
herboristería normal; de noche, en el sótano, preparas pociones prohibidas por
la Corona y las vendes a escondidas.

## Estado actual: prototipo 0.1

Un bucle mínimo jugable, con arte provisional hecho con formas simples:

1. **Huerto**: eliges una semilla y haces clic en una maceta vacía. Cuando la
   planta crece, haces clic otra vez para cosecharla.
2. **Caldero**: echas 2 hierbas y pulsas **¡Mezclar!** para obtener una poción.
3. **Mostrador**: entra un cliente pidiendo una poción. Si la tienes, pulsa
   **Vender poción** antes de que se le acabe la paciencia.

El objetivo del prototipo es reunir 60 monedas para pagar el alquiler.

## Cómo abrirlo y probarlo

1. Instala Godot 4.7 (la versión normal, no la ".NET") desde
   <https://godotengine.org/download>.
2. Descarga este repositorio (botón verde **Code > Download ZIP** en GitHub, o
   con GitHub Desktop) y descomprímelo en una carpeta.
3. Abre Godot. En el Gestor de Proyectos pulsa **Importar**, busca la carpeta y
   elige el archivo `project.godot`. Pulsa **Importar y editar**.
4. Dentro del editor, pulsa el botón **▶ (Ejecutar proyecto)** arriba a la
   derecha, o la tecla **F5**.

## Dónde está cada cosa

| Archivo | Qué hace |
|---|---|
| `project.godot` | Configuración del proyecto (nombre, resolución, escena inicial). |
| `scenes/main.tscn` | La escena principal; solo tiene un nodo con `main.gd`. |
| `scripts/game_data.gd` | **Datos del juego**: hierbas, pociones, recetas y precios. Cambia aquí los números para equilibrar. |
| `scripts/main.gd` | El cerebro: dinero, inventario, botones y clientes. |
| `scripts/maceta.gd` | Una maceta del huerto que crece con el tiempo. |
| `scripts/caldero.gd` | El caldero y su dibujo animado. |
| `scripts/cliente.gd` | El cliente del mostrador y su paciencia. |

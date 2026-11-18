# Pruebas automáticas

Se ejecutan sin abrir ventana. Hace falta Godot 4.x en el PATH (aquí `godot`):

```
godot --headless --path . --import                       # solo la primera vez
godot --headless --path . --script res://tests/prueba_recetas.gd   # recetas, efectos, curación
godot --headless --path . res://tests/prueba_ui.tscn     # abre el mundo, caldero, médico, tiendas, cama, guardado
xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/captura_ui.tscn -- /carpeta   # capturas
```
Acaban con `RESULTADO: TODO BIEN` o con la lista de `FALLO:`.

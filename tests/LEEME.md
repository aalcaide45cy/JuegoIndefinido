# Pruebas automáticas

Se ejecutan sin abrir ventana. Hace falta Godot 4.x en el PATH (aquí `godot`):

```
godot --headless --path . --import                       # solo la primera vez
godot --headless --path . --script res://tests/prueba_recetas.gd   # recetas, efectos, curación
godot --headless --path . res://tests/prueba_policia.tscn # estrellas, refuerzos, detención, taxi, servicios, distritos
godot --headless --path . res://tests/prueba_ui.tscn     # abre el mundo, caldero, médico, tiendas, cama, guardado
godot --headless --path . res://tests/prueba_partidas.tscn   # ranuras de guardado y logros
godot --headless --path . res://tests/prueba_asaltos.tscn   # asaltos a casas: ganzúa, ruido, botín, vecinos, estrellas
godot --headless --path . res://tests/prueba_carreteras.tscn   # carreteras: sin huecos en los bordes de trozo y pegadas al terreno
xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/captura_ui.tscn -- /carpeta   # capturas
godot --headless --path . res://tests/prueba_opciones.tscn   # teclas, mando, volúmenes, autoguardado, copia .bak
xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1920x1080 res://tests/medir_rendimiento.tscn -- /carpeta   # rendimiento (CSV + capturas)
xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1920x1080 res://tests/captura_opciones.tscn -- /carpeta   # capturas de Pausa, Sonido y Controles
```

En la nube: descargar `Godot_v4.7.1-stable_linux.x86_64.zip` de las versiones de Godot en GitHub,
descomprimirlo y usarlo en lugar de `godot`.

Acaban con `RESULTADO: TODO BIEN` o con la lista de `FALLO:`.

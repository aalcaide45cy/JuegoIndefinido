# Ajustes del mundo y presets (panel de administrador)

F1 > botón **Ajustes del mundo y presets**. Se pueden tocar: clima, hora, velocidad del tiempo,
minutos por día, linterna (intensidad, alcance, ángulo, color), velocidad al andar y al correr,
fuerza del salto, campo de visión, volumen de música y ambiente, y policía.

Los presets se guardan en `user://presets_admin.json` (Windows: `%APPDATA%\Godot\app_userdata\<juego>`).
«Predeterminado» es fijo. Guardar con un nombre existente o borrar pide pulsar el botón dos veces.
Código: `scripts/ajustes_mundo.gd` (datos y archivo) y `scripts/ui/ventana_ajustes.gd` (ventana).
Prueba: `godot --headless --path . res://tests/prueba_ajustes.tscn`.

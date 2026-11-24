# Lista para publicar en Steam

Lista de lo que falta para tener el juego en Steam, en orden. Marca con [x] lo que se haga.
Ver también la sección 4.14 de [PLAN_MEJORA.md](PLAN_MEJORA.md).

## 1. Decisiones (las tomas tú)

- [ ] Nombre definitivo. Propuestas: **Indefinido** o **Contrato Indefinido**. Antes de decidir: buscarlo
  en Steam y en la oficina de marcas (EUIPO) para ver que no está cogido.
- [ ] Precio orientativo (los juegos de mundo abierto indie en acceso anticipado suelen ir de 15 a 25 €).
- [ ] Acceso anticipado (recomendado) o lanzamiento completo.

## 2. Cuenta y página

- [ ] Cuenta de Steamworks y pago de la tasa de Steam Direct (100 $ por juego, se recupera al vender 1.000 $).
- [ ] Página de la tienda "próximamente" lo antes posible: junta listas de deseos.
- [ ] Imágenes: cápsula principal 616x353, pequeña 231x87, cabecera 460x215, biblioteca 600x900 y
  3840x1240, logo con fondo transparente, y al menos 5 capturas a 1920x1080.
- [ ] Tráiler de 60-90 s (primeros 5 s con lo más espectacular).
- [ ] Cuestionario de contenido: violencia, sangre (con opción de apagarla), consumo de sustancias
  ficticias, armas.

## 3. El ejecutable

- [x] Plantilla de exportación (`export_presets.cfg`): Windows y Linux / Steam Deck. Se exporta a la
  carpeta `exportar/` (no se sube a GitHub).
- [ ] Instalar las plantillas de exportación de Godot 4.7.1 (Editor > Gestionar plantillas de exportación).
- [ ] Icono propio (.ico para Windows) y ponerlo en `application/icon`.
- [ ] Cambiar `config/name` en `project.godot` al nombre definitivo (cambia también la carpeta de
  partidas guardadas: hacerlo ANTES de publicar, o migrar las partidas).
- [ ] Probar la exportación en un PC distinto al tuyo, sin Godot instalado.

## 4. Integración con Steam

- [ ] GodotSteam (versión para Godot 4.7) como extensión GDExtension.
- [ ] `steam_appid.txt` con el número de la aplicación, solo para pruebas (no se sube con el juego).
- [ ] Dar de alta los logros en Steamworks con los nombres `ACH_*` de `scripts/datos/logros.gd`.
- [ ] Guardado en la nube de Steam: carpeta `user://` (partidas `partida_*.json` y `.bak`, opciones `*.cfg`).
- [ ] Compatibilidad con mando: marcar "compatibilidad parcial con mando" (el juego ya se juega con mando;
  los menús aún necesitan ratón).

## 5. Antes de pulsar "publicar"

- [ ] 30 minutos de juego sin errores en 3 PC distintos (uno modesto).
- [ ] Revisar `CREDITS.md`: todas las licencias (Quaternius y Kenney CC0, Fab estándar, Godot MIT).
- [ ] Demo para el Steam Next Fest (opcional pero muy recomendable).

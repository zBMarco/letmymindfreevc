# Mi Estrella

To-do para soltar lo que te estresa. Cada tarea pendiente le suma carga a tu estrella; al terminarla, la estrella se calma. Si la carga pasa de 100% explota en supernova, y de la nebulosa nace una nueva cuando terminas 3 tareas.

## Qué incluye

- **Estrella realista dibujada en la GPU** (`shaders/star.frag`): granulación celular (ruido Worley), rotación diferencial, oscurecimiento del borde, manchas solares, espículas, corona y llamaradas que siguen las líneas de un campo magnético dipolar (`r = L·sin²θ`).
- **Cinco estados** (Radiante, Tranquila, Inquieta, Al límite, Supernova), más la nebulosa y el renacimiento.
- **Tareas** con tipo, tamaño (Chica a Monstruo), fecha límite opcional, repetición (diaria, semanal o mensual), subtareas, notas, cronómetro y traza completa.
- **Captura rápida con fecha en texto**: escribe "pagar la luz mañana 5pm", "dentista el viernes a las 4", "reporte 15 dic" o "llamar en 2 horas" y la fecha límite se llena sola; la tarea se guarda como "pagar la luz". Con la ✕ lo ignoras.
- **Recordatorios en el iPhone**: notificaciones 1 día, 3 h, 1 h y 30 min antes, y al vencer. No necesitan servidor.
- **Agregar al Calendario de iOS** desde el detalle de la tarea.
- **Explorador de la estrella**: toca tu estrella (en el encabezado o en *Estrella › Explorar*) para verla en pantalla completa en el espacio profundo, con la Vía Láctea y estrellas de fondo con su color real. Arrastra para girarla y ver sus polos, pellizca (o usa la rueda del ratón) para acercarte hasta ver la granulación y las manchas, y mueve la vista con dos dedos. Doble toque la centra. Con el botón ⚡ provocas una llamarada (si estás de cerca, la cámara viaja al borde para verla), y también hace erupciones solas, más seguido mientras más estresada está. De cerca, los arcos y las protuberancias se ven como hilos de plasma siguiendo el campo magnético. Abajo te explica lo que estás viendo, y su ficha muestra tipo, clase espectral y temperatura.
- **Vibración** del iPhone (la app no tiene sonido).
- **Progreso**: racha, tareas por día, tiempos, avance por tipo e historial.
- **Metas**: escribe lo que quieres lograr y para qué, con fecha opcional. Márcalas cada día que avances en ellas. Tu **racha** suma uno por cada tarea que completas y vuelve a cero si pasa un día entero sin completar ninguna. Al llegar a 3, 7, 14, 21, 30, 50, 75, 100, 150, 200 y 365 tareas de racha ganas una **constelación** que se dibuja con una animación y queda brillando para siempre en el cielo de fondo de la app. Un punto naranja en la pestaña te avisa si hoy aún no marcas ninguna meta. En *Tareas*, el encabezado muestra tu racha con un fuego que cambia de color como una estrella mientras más tareas lleves: brasa roja (1), naranja (3), amarillo (7), blanco (14), azul (30), violeta (100) y estelar (365). Brilla y parpadea más mientras más caliente está, se ve apagado si hoy aún no completas una tarea, y al tocarlo vas a *Metas*.
- **Sistema solar** (`shaders/planet.frag`, `lib/star/solar_system.dart`): cada tipo de tarea es un planeta (rocoso, gigante gaseoso con anillos o helado) iluminado por la estrella. Crece con su carga, y su órbita se acerca a la estrella cuando se acerca la fecha límite. Cada subtarea pendiente es una luna, y cada tarea terminada queda como una roca en el cinturón de asteroides. En la supernova los planetas salen disparados y al renacer se vuelven a formar.
- **Estrella con temperatura real por punto**: color de cuerpo negro (ley de Planck) en cada gránulo, mancha y borde, tono fílmico ACES y resplandor de cámara. Las llamaradas son tubos de plasma con volumen.
- **Funciona sin internet** en la versión web (`web/sw.js`) después de abrirla una vez.
- Los datos se guardan en el teléfono. Puedes exportar e importar un respaldo desde *Tipos*. En la web, la app pide al navegador que no borre sus datos y te recuerda guardar un respaldo si llevas una semana sin hacerlo (o 3 días de uso sin ninguno).

## Probarla en tu computadora

```bash
flutter run -d chrome
```

Parámetros útiles solo en el navegador: `?demo=1` (tareas de ejemplo, con lunas y asteroides), `?sw=1` (activa el modo sin conexión en localhost), `?tab=1` (abre la estrella), `?ft=0.5` (congela una llamarada), `?icon=1` (dibuja el ícono), `?reward=0` a `?reward=10` (muestra la animación de una constelación ganada), `?streak=30` (simula 30 tareas hechas hoy para ver el color del fuego), `?explore=1` (abre el explorador; `?explore=6` ya acercado; con `&ft=0.45` mira una llamarada congelada).

## Instalarla en tu iPhone gratis

Apple solo deja compilar apps de iPhone en una Mac. Como trabajas en Linux, la compilación corre en una Mac en la nube de GitHub (gratis), y luego instalas la app con tu Apple ID gratuito.

### 1. Compilar en GitHub

1. Crea una cuenta en github.com y un repositorio nuevo (puede ser privado), por ejemplo `mi-estrella`.
2. Desde esta carpeta:
   ```bash
   git init
   git add .
   git commit -m "Mi Estrella"
   git branch -M main
   git remote add origin https://github.com/TU_USUARIO/mi-estrella.git
   git push -u origin main
   ```
3. En GitHub entra a **Actions** y abre "Compilar app de iPhone (sin firmar)". Corre solo con cada push; también lo puedes lanzar con **Run workflow**.
4. Cuando termine (unos 10 a 15 min), descarga el artefacto **MiEstrella-ipa** y descomprímelo: ahí está `MiEstrella.ipa`.

> En repositorios privados, GitHub da 2000 minutos al mes, y los minutos de Mac cuentan 10 veces. Alcanza para unas 10 o 15 compilaciones al mes. En un repositorio público es ilimitado.

### 2. Instalar con tu Apple ID gratuito

Usa **SideStore** (recomendado) o **AltStore**. Firman la app con tu Apple ID.

1. En el iPhone activa **Ajustes › Privacidad y seguridad › Modo de desarrollador** y reinicia.
2. Instala SideStore siguiendo https://docs.sidestore.io. Esa configuración inicial necesita una computadora una sola vez: en Linux se puede con las herramientas que indica su guía, o pide prestada una Mac o PC con Windows.
3. Pasa `MiEstrella.ipa` al iPhone (AirDrop, iCloud Drive o Archivos), ábrelo con SideStore e instálalo.
4. Con cuenta gratuita, Apple exige renovar la firma **cada 7 días**. SideStore lo hace desde el mismo iPhone: abre SideStore y toca "Refresh". Tus datos no se pierden al renovar.

Si en algún momento pagas el Apple Developer Program ($99 USD al año), se puede publicar en TestFlight y ya no hay que renovar cada semana.

## Estructura

```
lib/
  main.dart                  arranque
  models.dart                tareas, tipos, estados de la estrella
  store.dart                 lógica: carga, supernova, renacimiento, repetitivas, guardado
  services/reminders.dart    notificaciones y Calendario
  star/star_fx.dart          animación de la estrella (uniforms del shader y cámara)
  ui/                        pantallas, hoja de tarea, metas y racha, celebración, tema de cristal
shaders/star.frag            la estrella
test/                        pruebas de la lógica
```

```bash
flutter analyze
flutter test
```

## Prototipos

`prototipos/` guarda las primeras versiones en un solo archivo HTML (*Mi Estrella* y el *Laboratorio Estelar*). No se publican; son solo de referencia.

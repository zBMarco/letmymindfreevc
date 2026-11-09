# Mi Estrella

To-do para soltar lo que te estresa. Cada tarea pendiente le suma carga a tu estrella; al terminarla, la estrella se calma. Si la carga pasa de 100% explota en supernova, y de la nebulosa nace una nueva cuando terminas 3 tareas.

## Qué incluye

- **Estrella realista dibujada en la GPU** (`shaders/star.frag`): granulación celular (ruido Worley), rotación diferencial, oscurecimiento del borde, manchas solares, espículas, corona y llamaradas que siguen las líneas de un campo magnético dipolar (`r = L·sin²θ`).
- **Cinco estados** (Radiante, Tranquila, Inquieta, Al límite, Supernova), más la nebulosa y el renacimiento.
- **Tareas** con tipo, tamaño (Chica a Monstruo), fecha límite opcional, repetición (diaria, semanal o mensual), subtareas, notas, cronómetro y traza completa.
- **Recordatorios en el iPhone**: notificaciones 1 día, 3 h, 1 h y 30 min antes, y al vencer. No necesitan servidor.
- **Agregar al Calendario de iOS** desde el detalle de la tarea.
- **Sonido sintetizado** (zumbido de la estrella, llamarada, supernova, renacimiento) y **vibración** del iPhone.
- **Progreso**: racha de días, tareas por día, tiempos, avance por tipo e historial.
- Los datos se guardan en el teléfono.

## Probarla en tu computadora

```bash
flutter run -d chrome
```

Parámetros útiles solo en el navegador: `?demo=1` (tareas de ejemplo), `?tab=1` (abre la estrella), `?ft=0.5` (congela una llamarada), `?icon=1` (dibuja el ícono).

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
  services/sound.dart        sintetizador de sonido
  star/star_fx.dart          animación de la estrella (uniforms del shader)
  ui/                        pantallas, hoja de tarea, celebración, tema de cristal
shaders/star.frag            la estrella
test/                        pruebas de la lógica y del sonido
```

```bash
flutter analyze
flutter test
```

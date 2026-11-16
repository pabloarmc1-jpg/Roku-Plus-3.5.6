# Auditoría de optimización — Roku Plus

**Repositorio:** `pabloarmc1-jpg/Roku-Plus-3.5.6`  
**Rama de trabajo:** `feature/rokuplus-resume-work`  
**Estado inicial:** auditoría en curso; no se han aplicado cambios de optimización de esta lista.  
**Regla de seguridad:** preservar el reproductor y todas las funciones que ya están validadas. No modificar el motor de reproducción, pausa, seek/saltos, reanudación, audio, subtítulos ni controles del reproductor como parte de esta optimización.

> Marca cada casilla al aplicar el cambio y anota el commit y el resultado de la prueba. Una posibilidad no se considera “sin uso” hasta completar el rastreo de referencias en todo el proyecto.

## 1. Limpieza segura y verificación

- [x] Retirar la inicialización duplicada de `m.invidiousQuery = ""` en `components/PlusScene.brs` (tras confirmar que no hay una razón de orden/flujo).
- [ ] Rastrear los dos observadores `progress` de `m.player` y los dos de `m.hostPlayer`; identificar el propósito de cada uno antes de cambiar nada.
- [x] Revisar temporizadores de hero y discovery; ahora se detienen fuera de Home y se reactivan al volver cuando hay contenido suficiente. Commit `67264f5` (`PlusScene.brs`) y `c273166` (`PlusSceneViews.brs`). **Pendiente compilar y validar en Roku.**
- [ ] Revisar por separado temporizadores de transiciones, fundidos y previews; no se modificaron.
- [ ] Rastrear referencias globales de componentes, funciones, tareas, assets y recursos antes de declarar archivos eliminables.
- [ ] Revisar el valor predeterminado `http://192.168.1.17:8099` de `components/CompatTask.xml`; comprobar el flujo de `m.compatBase` y eliminar/cambiar el fallback solo si se demuestra obsoleto.
- [ ] Revisar funciones antiguas de búsqueda/API de subtítulos en `components/PlusPlayer.brs` y `components/SubtitleSearchTask.brs`; retirar únicamente código sin llamadas ni rutas de configuración activas.
- [ ] Comprobar si las opciones de API de subtítulos siguen teniendo un uso real; no eliminar ajustes TMDB ni preferencias compartidas sin rastrear sus consumidores.

## 2. Interfaz y navegación (sin tocar el reproductor)

- [x] Analizar `drawScreen()` y `eraseScreen()` en `components/PlusSceneViews.brs`: `drawScreen()` ejecuta `eraseScreen()` y reconstruye la vista; hay alrededor de 115 llamadas a `drawScreen()` desde `PlusScene.brs`. La limpieza total sigue pendiente de optimización por pantalla.
- [x] Home: la rotación y selección manual del destacado actualizan el poster, título, datos y puntos existentes sin reconstruir toda la pantalla. Commits `35eb15c`, `81dfa54` y `49d68d7`. **Validado por el usuario: funciona en su Roku.**
- [x] Home: al recibir páginas posteriores de películas, actualizar el contador del destacado y conservar los nodos existentes en vez de reconstruir toda la pantalla. Commit `847623a`. **Pendiente compilar y validar en Roku.**
- [x] Catálogo: se probó la reutilización parcial de nodos para mover el foco, pero se revirtió por regresión visual: al cambiar de bloque de diez títulos, el foco podía desaparecer y la cuadrícula no se actualizaba. La navegación vuelve a usar `drawScreen()` al cambiar el cursor. Commits de prueba `20e91dc` y `9c2e4e7`; reversión registrada en esta revisión. **Validado por el usuario: el foco volvió a funcionar correctamente tras actualizar la rama.**
- [x] Revisar detalle y episodios: `detailScreen()` crea un conjunto acotado de nodos (acciones y metadatos); `episodeScreen()` muestra hasta seis temporadas y cuatro episodios por página. La navegación actual redibuja la vista al mover el foco. **Candidato de optimización**, pero no se cambió: cualquier actualización parcial debe sincronizar foco, selección, metadatos y paginación; la regresión anterior demuestra que no conviene actualizar solo el contorno.
- [ ] Revisar transiciones y animaciones para evitar trabajo cuando no son visibles.
- [ ] Revisar el manejo del foco y la creación/destrucción de elementos para reducir trabajo de CPU y recolección de basura.
- [ ] Probar navegación rápida entre Home, películas, series, detalle y búsqueda después de cada cambio de interfaz.
- [x] Revisar el manejo de foco en detalle/episodios: el redibujado completo mantiene coherencia con los grupos visibles; conservarlo hasta diseñar y probar una actualización parcial que también respete los límites de página.

## 3. Catálogos, tareas y rendimiento

- [ ] Auditar las consultas de catálogo de películas y series: caché, paginación, concurrencia y carga progresiva.
- [x] Revisar ciclo de vida de tareas: las consultas generales usan una sola tarea activa (`m.job`); `fetch()` cancela la anterior antes de crear otra. Home mantiene un máximo habitual de dos tareas iniciales y pagina películas de una en una. Las tareas cooperan con `cancelRequested` y los bucles de descarga revisan cancelación y límites de tiempo/tamaño. No se cambió el código.
- [ ] Comprobar cancelación de tareas al ocultar/salir de Roku Plus: no se encontró un manejador `visible = false` en `PlusScene.brs`; confirmar el ciclo de vida desde el componente padre antes de afirmar que las tareas se cancelan al ocultar la experiencia.
- [x] Revisar caché Home: conserva películas y series por modo/proveedor durante cinco minutos, y solo reutiliza el conjunto cuando ambas filas están marcadas como disponibles. No se modificó.
- [ ] Evitar solicitudes repetidas de la misma página/datos cuando ya están disponibles en caché.
- [ ] Revisar tiempos de carga y uso de memoria en dispositivos Roku reales antes y después de optimizar.
- [ ] Revisar modularización de los archivos grandes sin alterar contratos ni comportamiento:
  - `components/PlusScene.brs`
  - `components/PlusSceneViews.brs`
  - `components/HdCatalogTask.brs`
  - `source/HdOnlineData.brs`
- [ ] Considerar modularización solo después de pruebas de regresión; no hacer una refactorización masiva de una sola vez.

## 4. Recursos gráficos

- [ ] Revisar dimensiones, formatos y referencias de imágenes antes de optimizarlas o eliminarlas.
- [ ] Comprobar si imágenes repetidas o de demostración se usan en rutas dinámicas.
- [ ] Priorizar imágenes grandes que realmente se cargan con frecuencia; el total inventariado de imágenes era aproximadamente 1.46 MB, por lo que no es la primera prioridad.

## 5. Componentes que no se deben eliminar sin análisis

- `StreamXImageTask`: hay referencias desde `PlusPlayer.brs`.
- `InvidiousTask`: hay referencias desde `PlusScene.brs`.
- `IntroDbTask`: hay referencias desde `PlusScene.brs`.
- `HdLocalDataTask`: hay al menos una referencia desde `PlusScene.brs`.
- `CompatTask`: hay referencias desde `PlusScene.brs`.
- `TsStreamServer`: revisar instanciación y dependencias indirectas antes de concluir que no se usa.
- `PlusPlayer.brs`, `PlusPlayer.xml` y el motor de reproducción: protegidos por el alcance de esta auditoría.

## 6. Orden recomendado de trabajo

- [ ] **Fase 1 — Limpieza segura:** duplicados confirmados, valores por defecto obsoletos demostrados y código realmente huérfano.
- [ ] **Fase 2 — Interfaz:** reutilización de nodos y ciclo de vida de timers, fuera del reproductor.
- [ ] **Fase 3 — Catálogos/tareas:** caché, cancelación, concurrencia y paginación.
- [ ] **Fase 4 — Medición:** comparar arranque, navegación, carga de catálogo, memoria y estabilidad en Roku real.
- [ ] **Fase 5 — Regresión:** confirmar que reproducción, pausa, avance/retroceso, reanudación, audio y subtítulos siguen funcionando.

## Registro de cambios aplicados

| Fecha | Elemento | Cambio / commit | Prueba y resultado |
|---|---|---|---|
| 2026-11-15 | `PlusScene.brs` | Eliminada una asignación consecutiva duplicada de `m.invidiousQuery`; commit `3e03e9d49255310ceab585f79c809190a313e550`. | Cambio estático confirmado en GitHub; pendiente compilar y probar en Roku. |
| 2026-11-15 | Home / destacado | Reutilización de nodos para rotación automática y selección manual; commits `35eb15c`, `81dfa54` y `49d68d7`. | **Usuario confirmó que funciona.** |
| 2026-11-15 | Home / catálogo | Las páginas posteriores de películas actualizan el contador del destacado sin reconstruir toda la pantalla; commit `847623a`. | Cambio en GitHub; pendiente compilar y probar en Roku. |
| 2026-11-15 | Búsqueda y navegación | Búsqueda insensible a mayúsculas y acceso directo desde sugerencias (commit `619fc0e`); navegación del teclado con `paintFocus()` (commit `acf9145`). | **Usuario confirmó que ambas funciones funcionan en Roku.**

## Notas de auditoría

- Inventario inicial: 201 archivos; 32 archivos BrightScript y 12 XML.
- Los archivos más grandes identificados fueron `PlusPlayer.brs`, `PlusScene.brs` y `HdCatalogTask.brs`.
- Esta lista contiene candidatos y líneas de investigación, no una declaración de que esos archivos o funciones estén sin uso.
- Estado inicial de esta checklist: todo pendiente; todavía no se han aplicado cambios de optimización de esta auditoría.

### Hallazgos añadidos durante el inicio de la auditoría

- Los dos observadores `progress` por instancia están conectados a callbacks diferentes: `playerProgress` y `livePreviewProgress`. Se conservan; no son duplicados que deban borrarse.
- `heroRotation` y `discoveryRotation` son temporizadores repetitivos. Sus callbacks salen temprano cuando `m.view <> "home"`, pero el temporizador puede seguir despertando periódicamente fuera de Home. Candidato de optimización: detenerlos al salir de Home y reactivarlos al volver, después de mapear todas las transiciones de vista y probarlas.
- `catalogFade` y `pageTransition` ya tienen condiciones explícitas de parada; no se cambiarán sin evidencia adicional.

- Optimización de rotación Home implementada: `syncHomeRotationTimers()` gobierna los timers de hero (solo con más de un destacado) y discovery (solo con más de seis elementos). Se invoca al dibujar vistas, al activar la experiencia y al entrar en los reproductores; los timers no permanecen activos fuera de Home.
- Los cambios de ciclo de vida de `heroRotation` y `discoveryRotation` están en GitHub; su validación específica sigue pendiente.

- Optimización incremental de Home: `heroRotationTick` y `changeHero` ya no llaman a `drawScreen()` cuando los nodos del destacado están disponibles. Se actualizan los nodos existentes; si falta el poster requerido o no están inicializados, se conserva el fallback de redibujado completo. Esto evita recrear las filas de continuar viendo, descubrimiento, lista y barra superior cada vez que cambia el destacado. El usuario confirmó que funciona.
- El redibujado general sigue intacto para navegación y cambios de vista. No se hizo una refactorización masiva ni se tocó el reproductor.



- Reversión de optimización del foco del catálogo: se retiró `updateBrowseSelection()` y se restauró el redibujado completo al cambiar la selección. Se mantiene la implementación previa y validada de Home; no se tocó el reproductor.


- Revisión de detalle/episodios (2026-11-15): `detailScreen()` dibuja una pantalla fija con hasta tres acciones; `episodeScreen()` dibuja hasta seis pestañas de temporada y cuatro tarjetas de episodio. `onKeyEvent()` vuelve a llamar `drawScreen()` al mover la selección en detalle y episodios. No se identificó una reconstrucción repetitiva causada por temporizadores; el costo está ligado a cada pulsación. Por seguridad se conserva el comportamiento actual y se documenta como oportunidad, sin modificar código.


### Revisión del ciclo de vida de tareas (2026-11-15)

- `fetch()` llama primero a `cancelRequest()`, retira observadores de la tarea anterior, activa `cancelRequested` y limpia el estado de la solicitud antes de iniciar otra. El timeout general detiene su timer y cancela de forma cooperativa la tarea.
- `CatalogTask.brs` comprueba `cancelRequested` durante las descargas y limita cada petición a 20 segundos y 2 MiB. `HdCatalogTask.brs` comprueba cancelación durante sus peticiones HTTP; la agregación de fuentes mantiene un presupuesto total de 40 segundos y una ventana por proveedor de hasta 9 segundos.
- Home inicia película y serie en paralelo; las páginas adicionales de películas se solicitan secuencialmente hasta `skip <= 40`. La cancelación de Home elimina observadores, marca cada tarea y vacía `m.homeJobs`.
- `homeStopped()` retira tareas que terminan sin resultado; si ya hay un resultado asociativo, espera a `homeFetched()`, que realiza la limpieza normal.
- Hallazgo defensivo: `homeFetched()` tiene retornos tempranos si el modo/proveedor de una tarea ya no coincide; esos retornos no retiran la entrada de `m.homeJobs`. Los flujos actuales de cambio de modo y proveedor llaman a `cancelHomeRequests()` antes del cambio, por lo que no se demostró una fuga reproducible. No se parchea sin una prueba que reproduzca el estado.
- `rpHdTaskCombinedCatalog()` consulta fuentes secuencialmente, con deadline y resultados parciales. No conviene paralelizar: el reparto de tiempo, cancelación y deduplicación están ligados a ese orden; el costo de deduplicación observado es pequeño frente a las esperas de red.
- Resultado: no se encontró un cuello de botella confirmado que justifique modificar el ciclo de tareas. Mantener el comportamiento actual hasta medir en Roku.


### Auditoría de recursos gráficos (2026-11-15)

- Inventario de la rama `feature/rokuplus-resume-work`: 119 archivos bajo `images/` (incluye recursos de interfaz, imágenes de ejemplo, splash/iconos y recursos del reproductor).
- `manifest` declara explícitamente los iconos HD/FHD y las pantallas splash HD/FHD. `PlusSceneViews.brs` carga recursos de interfaz mediante `art()`, `glassSurface()`, arrays de iconos de navegación y nombres construidos dinámicamente; por eso una búsqueda literal de cada ruta no basta para declarar una imagen huérfana.
- `PlusPlayer.xml` referencia recursos gráficos del reproductor. También hay recursos usados desde datos de programación en `source/RealityData.brs` y `source/LivePresentationData.brs` (imágenes `live-program-granja.png` y `live-program-casa.png`). Se conservan.
- Se detectó al menos un duplicado binario exacto por SHA: `images/newplayer-control-focus.png` y `images/newplayer-classic-control-focus.png` comparten el mismo blob. No se elimina ni consolida porque pertenecen al conjunto visual del reproductor, expresamente fuera del alcance.
- Los archivos de imágenes de muestra/portadas en la raíz de `images/` requieren rastrear también los JSON y los datos de catálogo antes de concluir que no se usan. No se ha eliminado ni convertido ningún recurso.
- No se midieron dimensiones ni consumo real de memoria en un Roku; el tamaño comprimido en Git no permite inferir el costo de decodificación. Para una optimización segura, primero hay que obtener dimensiones y verificar carga/uso en dispositivo.
- Resultado: auditoría gráfica inicial completada sin cambios en la aplicación. No hay todavía una imagen que pueda borrarse con seguridad ni evidencia para recomprimir recursos sin alterar calidad o presentación.


### Inventario ampliado de imágenes desde Git (2026-11-15)

- Se verificó el árbol Git recursivo completo de la rama: 119 recursos, sin truncamiento. El tamaño total almacenado es 1,456,909 bytes (aprox. 1.39 MiB): 111 PNG (859,661 bytes) y 8 JPG (597,248 bytes).
- Los tres grupos de blobs idénticos detectados por SHA son:
  - `images/newplayer-classic-control-focus.png` y `images/newplayer-control-focus.png`.
  - `images/ui/live.png` y `images/ui/nav-live.png`.
  - `images/ui/series.png` y `images/ui/tv.png`.
- El par `live.png` / `nav-live.png` y el par `series.png` / `tv.png` aparecen referenciados por la vista de interfaz. Aunque sus bytes sean idénticos, no se renombra ni elimina ninguno: los nombres pueden ser parte de rutas de carga y conservar ambos evita romper referencias.
- Recursos de mayor tamaño en el repositorio: `encanto-hero.jpg` (258,828 bytes), `encanto.jpg` (91,570), `ui/app-background.png` (69,709), `ui/app-background-classic.png` (67,771), `walter-mitty.jpg` (54,702), `splash-fhd.jpg` (48,696), `amelie.jpg` (48,373) y `ui/appearance-glass-preview.png` (44,124).
- La API de Git expone para estos blobs el tamaño y SHA, pero el conector de repositorio rechaza los blobs binarios porque no son UTF-8. Por tanto, desde este acceso no se pueden decodificar cabeceras PNG/JPEG para obtener dimensiones ni medir píxeles/alpha. No se inventan dimensiones ni se infiere el costo de memoria a partir del tamaño comprimido.
- Resultado: inventario y duplicados exactos ampliados desde Git, sin cambios en recursos. Los tres pares duplicados son candidatos de consolidación solo después de confirmar todas las referencias estáticas/dinámicas y decidir si se desea conservar compatibilidad de nombres; por ahora se mantienen.


### Rastreo de referencias de los duplicados (2026-11-15)

- Se rastrearon las referencias directas en `components/PlusSceneViews.brs`, `components/PlusPlayer.xml`, `manifest`, `data/channel-logos.json`, `data/hd-library.json`, `source/RealityData.brs` y `source/LivePresentationData.brs`.
- `images/ui/nav-live.png` se carga desde la lista de iconos de navegación de `PlusSceneViews.brs`; `images/ui/live.png` se carga directamente en la vista de previsualización en vivo. Aunque los archivos son idénticos, cumplen usos/rutas distintas. No consolidar ni borrar.
- `images/ui/tv.png` se carga directamente en una tarjeta de categorías. El nombre `images/ui/series.png` no aparece como ruta literal en los archivos inspeccionados; aun así, no se elimina porque los recursos pueden construirse mediante nombres dinámicos y no se ha hecho una búsqueda exhaustiva en los 78 archivos de texto.
- Los recursos duplicados `newplayer-control-focus.png` y `newplayer-classic-control-focus.png` pertenecen al conjunto del reproductor. `PlusPlayer.xml` carga explícitamente `newplayer-control.png` para superficies de controles, pero no carga los archivos duplicados de foco en las líneas inspeccionadas. Se mantienen fuera del alcance de optimización del reproductor.
- La interfaz genera rutas dinámicas: `glassSurface(name, ...)` construye `pkg:/images/ui/` + nombre + `.png`; por eso la ausencia de un nombre literal en una búsqueda no demuestra que el archivo esté huérfano.
- Resultado: los duplicados identificados no son candidatos seguros de eliminación en esta fase. No se realizaron cambios de código ni de imágenes.


### Auditoría de ciclo de vida y repetición de cargas de imágenes (2026-11-15)

- `art()` centraliza la creación de nodos `Poster`: configura `loadWidth`, `loadHeight`, `loadDisplayMode`, asigna `themeAsset(uri)` y registra cada nodo en `m.images`. `thumbnail()` usa el mismo camino.
- `eraseScreen()` detiene las animaciones de carga, retira observadores `loadStatus`, vacía los URI de los posters anteriores, limpia `m.images` y `m.focusItems`, y elimina los hijos del canvas. No se observa una acumulación permanente de nodos Poster entre redibujados completos.
- Home ya evita redibujar todo para la rotación del destacado mediante `updateHomeHero()`; la fila de descubrimiento desplaza/reutiliza sus siete nodos Poster y cambia el URI del nodo reciclado en vez de crear un nodo por paso. Estas rutas existentes se conservan.
- En Home, los movimientos normales entre tarjetas actualizan el foco sin llamar a `drawScreen()`; los redibujados completos se reservan para cambios de zona/vista y algunas transiciones. La rotación del destacado actualiza sus nodos existentes.
- En el catálogo `browse`, cada cambio de cursor dentro de la cuadrícula ejecuta `drawScreen()`, recreando hasta diez posters y sus objetivos de foco. Esto es un candidato real para reducir creación de nodos, pero ya se intentó una actualización parcial y el usuario reportó pérdida del foco y cambio incorrecto de página; esa optimización fue revertida y el comportamiento actual volvió a funcionar. No se reintroduce sin un diseño que mantenga sincronizados el bloque de diez elementos, la selección y los objetivos de foco; al cambiar de página debe reconstruirse la cuadrícula.
- En la vista en vivo, algunos cambios de estado del preview llaman a `drawScreen()`. Esto puede recrear los posters visibles, pero ocurre ante cambios de estado y no hay evidencia de descargas repetidas ni de impacto medido. No se altera.
- No se encontró un gestor de caché de imágenes propio ni una descarga manual común para los posters del catálogo; los URI se asignan directamente a nodos SceneGraph. No se debe afirmar que cada redibujado vuelve a descargar bytes: la caché interna de SceneGraph no se ha medido desde el repositorio.
- Resultado: se confirmó limpieza correcta de nodos y reutilización parcial en Home. El principal candidato es la cuadrícula browse, pero se deja sin cambios por la regresión de foco ya reproducida. No se modificó código ni el reproductor en esta etapa.


### Optimización incremental de navegación del catálogo (2026-11-15)

- Se añadió `m.browseBackdropPoster` para conservar una referencia al Poster de fondo de la vista browse; se invalida en `eraseScreen()` para no retener nodos de una vista anterior.
- Se añadió `updateBrowseSelection()` en `PlusSceneViews.brs`: actualiza el URI del fondo y ejecuta `paintFocus()` sobre los objetivos de foco ya existentes, sin recrear las diez tarjetas.
- En `onKeyEvent()`, si el cursor cambia pero permanece dentro del mismo bloque de diez títulos, se intenta la actualización parcial. Si cruza a otro bloque, o la actualización parcial no puede aplicarse (por ejemplo, no hay imagen de fondo/poster), se conserva el redibujado completo.
- No se cambia el orden de títulos, los índices de `focusItems`, la paginación, la carga de catálogo ni la lógica del reproductor.
- Cambios guardados en GitHub: `PlusSceneViews.brs` commit `4fab2e2`; `PlusScene.brs` commit `0290024`.
- Estado: **validada por el usuario en Roku**. El usuario confirmó que funciona después de probar la navegación de la cuadrícula. Se mantiene el comportamiento de actualización parcial dentro de la misma página y redibujado completo al cruzar de página o cuando no se puede actualizar el fondo. No se modifica el motor de reproducción.


### Optimización incremental de navegación de episodios (2026-11-15)

- En `onKeyEvent()`, la navegación por episodios ahora conserva los nodos existentes cuando el usuario cambia la selección dentro del mismo bloque de cuatro tarjetas: solo ejecuta `paintFocus()`.
- Cambiar entre el selector de temporadas y la fila de episodios también actualiza el foco sin reconstruir la vista, porque ambos grupos de objetivos ya están presentes en la pantalla.
- Al cambiar de bloque de cuatro episodios o de temporada, se mantiene el redibujado para sincronizar tarjetas, títulos y selector de temporada.
- Al entrar o salir de la barra lateral de navegación, se fuerza el redibujado para crear/eliminar correctamente sus objetivos de foco y actualizar el ancho de la barra. Se conserva también el redibujado explícito al pulsar Arriba desde temporadas.
- La carga de temporadas/episodios, las consultas de red, los datos y el reproductor no se modifican.
- Commits de código: `85514b8` (optimización) y `d54d247` (protección del foco de la barra lateral).
- Estado: revisión estática del flujo y de los objetivos de foco realizada; **pendiente compilar y probar en Roku**. Comprobar cambio de episodio dentro del mismo grupo, cruce del grupo de cuatro, cambio de temporada, transición entre temporadas/episodios y navegación a la barra lateral. No considerar validado hasta recibir confirmación de la prueba.


### Navegación de detalle y selección del último episodio visto (2026-11-15)

- La navegación de temporadas/episodios se optimizó para reutilizar los nodos y actualizar el foco dentro del mismo bloque de cuatro episodios. El usuario confirmó que la navegación funciona tras la corrección de sintaxis BrightScript; al cambiar de bloque o temporada se conserva el redibujado necesario.
- Se añadió la selección automática del último episodio guardado para la serie al entrar desde el detalle o al recibir metadatos HD. La búsqueda usa la identidad de serie disponible (ID de serie, IMDb o título más proveedor), selecciona la temporada y espera la carga asíncrona de episodios cuando corresponde. No inicia la reproducción.
- Commits de selección: `8ec5b6c`, `1306d19` y `4969d2a`. El usuario confirmó que funciona en Roku.
- Siguiente optimización incremental: al cambiar entre acciones de la pantalla de detalle, conservar los nodos ya dibujados y ejecutar solo `paintFocus()`. El redibujado completo se mantiene al entrar/salir de la barra lateral. Commit `13e3726`.
- Estado de esta última optimización: **validada por el usuario en Roku**. El usuario confirmó que funciona tras probar la navegación de las acciones de detalle. Se conserva el redibujado completo al entrar/salir de la barra lateral. No tocar el reproductor.


### Navegación del teclado de búsqueda (2026-11-15)

- La pantalla de búsqueda ya dibuja simultáneamente las teclas, las acciones y las sugerencias disponibles, y registra sus objetivos de foco en `m.focusItems`.
- Al mover el cursor con las flechas, antes se ejecutaba `drawScreen()` y se reconstruían todos esos nodos aunque solo cambiara el borde de selección.
- Se cambió únicamente ese redibujado de navegación por `paintFocus()`, que actualiza la visibilidad de los bordes sobre los objetivos existentes.
- La escritura de caracteres, actualización de sugerencias, borrado, selección de resultados y acciones siguen usando sus rutas de actualización originales; no se cambió la búsqueda ni sus datos.
- Cambio guardado en `components/PlusScene.brs`, commit `acf9145`.
- Estado: **validada por el usuario en Roku**. El usuario confirmó que la navegación del teclado funciona; se conserva la actualización de foco mediante `paintFocus()` sin reconstruir la pantalla. No tocar el reproductor.


### Memoria de imágenes al cambiar de pantalla (2026-11-15)

- Auditoría de `art()` y `eraseScreen()` en `components/PlusSceneViews.brs`: cada Poster creado por `art()` se registra en `m.images`.
- `eraseScreen()` detiene el temporizador de fundido del catálogo, desregistra observadores de carga, vacía las URI de los Posters, limpia listas de referencias y elimina los hijos del canvas. También reinicia referencias específicas de Home y catálogo.
- Antes de abrir el reproductor estándar, `launchVideo()` llama a `eraseScreen()` antes de ocultar el canvas. El reproductor Invidious también ejecuta limpieza antes de mostrar su componente. El cierre vuelve a dibujar la pantalla y crea los nodos necesarios.
- `drawScreen()` limpia la pantalla anterior antes de reconstruirla; su retorno temprano para la vista player es seguro porque las rutas de entrada al reproductor ya limpian explícitamente.
- Conclusión: no se encontró una retención adicional de Posters que justifique cambiar código. No se añadió una segunda limpieza ni se modificó el reproductor, para evitar trabajo redundante y regresiones.
- Estado: **auditoría estática completada; no se requiere cambio de código ni prueba adicional**. No se midió la memoria real del dispositivo Roku.

### Resolución de carga de portadas del catálogo (2026-11-15)

- Las diez tarjetas visibles mantienen sus dimensiones visuales de 292×250.
- Las imágenes de esas tarjetas ahora se decodifican a 256×219 mediante las dimensiones opcionales de `art()`, tanto con la transición de entrada como sin ella. Esto reduce aproximadamente un 23% los píxeles decodificados por portada, sin cambiar el tamaño en pantalla ni el flujo de foco.
- No se modificaron portadas de Home, fichas, fondos, búsqueda ni reproductor.
- Cambio en `components/PlusSceneViews.brs`, commit `2d482c3`.
- Estado: **validado por el usuario en Roku**. El usuario confirmó que funciona; se conserva la carga de portadas a 256×219 con tamaño visual de 292×250.

### Carga del fondo de la cuadrícula del catálogo (2026-11-15)

- La función compartida `art()` ahora admite dimensiones de carga opcionales; todas las llamadas existentes mantienen su comportamiento porque los valores predeterminados siguen siendo las dimensiones visuales del Poster.
- El fondo de la vista `browse` se muestra a 1920×1080, pero su imagen se decodifica a 960×540. En esa vista queda bajo una capa oscura casi opaca, por lo que se reduce el tamaño de decodificación sin cambiar el tamaño visual del fondo.
- Las portadas de las tarjetas, los Posters de Home, las imágenes de detalle, los objetivos de foco y los componentes del reproductor no se modificaron.
- Cambio en `components/PlusSceneViews.brs`, commit `0535509`.
- Estado: **validado por el usuario en Roku**. El usuario confirmó que funciona; se conserva la carga del fondo a 960×540. No se modificaron las portadas, el foco ni la navegación.

### Caché breve de búsquedas repetidas (2026-11-15)

- Se añadió una caché de una sola consulta en memoria para la búsqueda remota: al repetir exactamente la misma consulta normalizada, con el mismo modo de catálogo y proveedor, se reutilizan los resultados durante dos minutos.
- La caché solo se llena cuando la respuesta trae resultados y no está marcada como parcial; así no se conserva una respuesta incompleta como si fuera definitiva.
- Cambiar la consulta, el modo o el proveedor evita reutilizar el resultado anterior. La caché es volátil y no altera preferencias ni datos guardados.
- Cambio en `components/PlusScene.brs`, commit `78d3ca2`.
- Estado: **validada por el usuario en Roku**. El usuario confirmó que la caché de búsquedas repetidas funciona. Se conserva la reutilización durante dos minutos, limitada a la misma consulta normalizada, modo y proveedor; las respuestas parciales no se guardan. No se modificó el reproductor.

### Búsqueda insensible a mayúsculas y acceso directo desde sugerencias (2026-11-15)

- `submitGlobalSearch()` conserva el texto original en `m.query` para presentación y pasa una copia en minúsculas al proceso de búsqueda remota. El catálogo HD local ya compara consulta y título/descripción con `lcase()`; se conserva ese comportamiento.
- La comparación de sugerencias locales ya convertía a minúsculas tanto la consulta como el título. Se conserva y ahora también se normaliza la consulta enviada a los catálogos remotos.
- Al seleccionar una sugerencia, `chooseSearchSuggestion()` abre directamente su ficha mediante `openDetails()`, en lugar de lanzar otra búsqueda por texto.
- Se añadió el origen `search` en `returnOneStep()`: al volver desde la ficha, se restaura el teclado de búsqueda con la sugerencia seleccionada. El botón BUSCAR conserva su flujo normal de resultados.
- No se alteran los extractores, proveedores, metadatos ni el reproductor.
- Cambio guardado en `components/PlusScene.brs`, commit `619fc0e`.
- Estado: **validada por el usuario en Roku**. El usuario confirmó que la búsqueda funciona: la consulta no distingue mayúsculas/minúsculas y las sugerencias abren directamente la ficha, conservando el retorno al teclado de búsqueda. No se modificó el reproductor.


### Fondo de previsualización de búsqueda (2026-11-15)

- La pantalla de búsqueda muestra el fondo de la sugerencia seleccionada a 1920×1080, cubierto por una capa oscura semitransparente. Se mantiene el tamaño visual del fondo, pero su Poster ahora se decodifica a 960×540 mediante los parámetros opcionales de `art()`.
- Las cinco portadas de sugerencias conservan sus dimensiones de visualización y carga (166×194); no se cambió su nitidez ni el flujo de sugerencias.
- No se modificaron el teclado, el foco, la búsqueda, el acceso directo a fichas, la navegación ni el reproductor.
- Cambio en `components/PlusSceneViews.brs`, commit `cb607e7`.
- Estado: **validada por el usuario en Roku**. El usuario confirmó que funciona al cambiar entre sugerencias; se conserva el aspecto del fondo, las portadas y el foco.

### Resolución del fondo del destacado de Inicio (2026-11-15)

- El fondo del destacado ocupa toda la pantalla (1920×1080) y se mantiene en esas dimensiones visuales.
- Su Poster ahora se decodifica a 1600×900 mediante los parámetros opcionales de `art()`, reduciendo aproximadamente un 30.6% los píxeles decodificados frente a 1920×1080, sin cambiar la composición ni la rotación del destacado.
- No se modifican el sombreado, los textos, los botones, los indicadores, la selección de destacados ni la navegación. Tampoco se toca el reproductor.
- Cambio en `components/PlusSceneViews.brs`, commit `d68cf88`.
- Estado: **validada por el usuario en Roku**. El usuario confirmó que el fondo de Inicio se ve correctamente y que la rotación de destacados funciona. Se conserva el tamaño visual y los controles; no se modificó el reproductor.

### Resolución de imágenes de las filas de Inicio (2026-11-15)

- Las imágenes de las filas «Continuar viendo» y «Selección para ti» conservan su tamaño visual de 238×146, pero ahora se decodifican a 224×138 (aproximadamente 11% menos píxeles por imagen).
- Las imágenes de «Mi lista» conservan su tamaño visual de 260×126 y se decodifican a 240×116 (aproximadamente 15% menos píxeles por imagen).
- Se mantienen el modo `scaleToFill`, las posiciones, los overlays de progreso, los objetivos de foco y la cantidad de tarjetas. No se altera la reutilización/rotación de los siete Posters de descubrimiento, ni el reproductor.
- Cambio en `components/PlusSceneViews.brs`, commit `131fbbf`.
- Estado: **validada por el usuario en Roku**. El usuario confirmó que las tres filas se ven bien; se conservan nitidez, indicadores de progreso, foco y rotación automática.

### Corrección de foco al desplazar «Películas para explorar» (2026-11-15)

- Se detectó que al alcanzar el sexto elemento visible y desplazar la ventana de la fila, `discoveryOffset` cambiaba pero la vista no se redibujaba. El foco conservaba su índice, mientras las tarjetas visibles seguían mostrando la ventana anterior; por eso la tarjeta resaltada podía no coincidir con la que se abría.
- Ahora, al desplazar la ventana hacia la derecha o izquierda, se ejecuta `drawScreen()` y se reconstruyen conjuntamente los Posters y los objetivos de foco para el nuevo bloque. Los movimientos dentro de las seis tarjetas visibles siguen usando `paintFocus()` sin reconstrucción completa.
- No se cambia la selección de elementos, el contenido del catálogo, la rotación fuera de la interacción ni el reproductor.
- Corrección en `components/PlusScene.brs`, commit `5a3a933`.
- Estado: **pendiente compilar y probar en Roku**. Verificar el foco al recorrer la fila hasta el extremo derecho, seguir avanzando, retroceder al extremo izquierdo y abrir una tarjeta después de desplazar la ventana.


### Ajuste del foco en la fila inferior de Home (2026-11-15)
- Reporte del usuario: al bajar desde «Películas para explorar», el foco parecía quedar entre dos imágenes.
- Diagnóstico estático: las tarjetas de «Mi lista» avanzan 270 px por posición, pero cada marco de foco tenía 276 px de ancho, por lo que los marcos contiguos se solapaban 6 px.
- Ajuste en `components/PlusSceneViews.brs`: marco de «Mi lista» cambiado a x+4 y ancho 268 px; se conserva la altura y la posición vertical. Esto alinea el marco con la tarjeta y evita el solapamiento horizontal.
- No se modificaron los índices de navegación, el movimiento del cursor, la carga de imágenes ni el reproductor.
- Estado: cambio guardado en GitHub; pendiente de compilar y confirmar visualmente en Roku.


### Corrección del foco al entrar mientras se anima «Películas para explorar» (2026-11-15)
- Aclaración del reporte del usuario: el problema no era el marco de la fila «Mi lista». Ocurre cuando el carrusel «Películas para explorar» se desplaza automáticamente y el usuario baja el foco mientras la animación está en curso.
- Causa: la rotación automática podía continuar durante la transición del foco a `covers`; los posters se trasladaban visualmente mientras el marco de foco y los índices permanecían fijos.
- Solución en `components/PlusScene.brs`: nuevo helper `settleDiscoveryForFocus()`. Al entrar a `covers` desde Hero o Continuar viendo, si el carrusel está animándose, detiene el timer, devuelve los siete posters a su posición estable, limpia el estado de animación y reinicia el timer con el intervalo normal. Ya dentro de `covers`, el callback existente mantiene la rotación pausada.
- Se revirtió el ajuste anterior no relacionado del ancho del foco de «Mi lista»; se conserva su geometría original.
- No se cambió el movimiento izquierda/derecha, la selección lógica ni el reproductor.
- Estado: commits guardados en GitHub; pendiente compilar y validar en Roku.


### Corrección adicional del desplazamiento automático de «Películas para explorar» (2026-11-15)
- Tras la primera corrección, el usuario informó que el foco seguía quedando entre dos imágenes.
- Revisión más profunda del ciclo de animación: `Poster.translation` es una posición del nodo, no un desplazamiento relativo a la posición inicial. El código anterior sobrescribía esa posición con valores calculados como si fueran offsets, y el helper de estabilización también restablecía los posters a [0,0] en vez de a sus posiciones reales.
- Corrección en `components/PlusScene.brs`:
  - Cada tick mueve cada poster 45 px desde su posición actual, conservando la coordenada vertical de la fila.
  - Al terminar el ciclo, el poster reciclado se coloca en la séptima posición real [1878, discoveryRowY].
  - Si se entra a la fila durante una animación, los siete posters se recolocan en las posiciones exactas [258+i*270, discoveryRowY] correspondientes al orden actual, sin cambiar `discoveryOffset`.
  - Se aplica la estabilización también al subir desde «Mi lista» y desde «Series para descubrir» cuando no existe la fila «Mi lista».
- No se cambia la selección de elementos ni el reproductor.
- Estado: **validada por el usuario en Roku**. El usuario confirmó que el foco ya no queda entre dos imágenes al entrar mientras la fila se desplaza automáticamente.


### Validación de la corrección de foco en «Películas para explorar» (2026-11-15)
- El usuario confirmó que la corrección resuelve el problema: al bajar el foco mientras la fila se desplaza automáticamente, el foco ya no queda entre dos imágenes.
- Se considera validada por el usuario en Roku.
- Se conserva la sincronización del carrusel y la pausa de rotación durante la navegación; no se modifica el reproductor.


## Resumen actual del progreso (2026-11-15)

### Validado por el usuario en Roku
- [x] Home: rotación y selección manual del destacado sin redibujar toda la pantalla.
- [x] Catálogo: navegación parcial dentro de una página de diez tarjetas, con redibujado al cambiar de página.
- [x] Detalle: movimiento del foco entre acciones sin reconstruir toda la ficha.
- [x] Episodios: selección automática del último episodio visto y navegación optimizada dentro del bloque visible.
- [x] Búsqueda: ignora mayúsculas/minúsculas; las sugerencias abren directamente sus fichas.
- [x] Caché temporal de búsquedas repetidas (dos minutos para la misma consulta, modo y proveedor).
- [x] Imágenes: fondo de búsqueda, fondo del destacado, portadas del catálogo y filas de Inicio con resolución de decodificación reducida.
- [x] Home: foco sincronizado con «Películas para explorar» al entrar durante la rotación automática.

### Implementado, pero aún pendiente de validación específica
- [ ] Ciclo de vida de los temporizadores Hero/Discovery fuera de Home.
- [ ] Actualización del contador Hero al llegar páginas adicionales del catálogo.
- [ ] Optimización de navegación de episodios tras los cambios de grupo/temporada, si se desea una prueba específica adicional.

### Pendiente de investigar o mejorar
- [ ] Optimizar navegación de categorías y resultados sin perder sincronización de foco/paginación.
- [ ] Completar rastreo de código realmente huérfano antes de eliminar funciones, componentes o recursos.
- [ ] Revisar cancelación de tareas al ocultar/salir de Roku Plus y solicitudes repetidas de catálogo.
- [ ] Medir tiempos y memoria en Roku real; no hay mediciones instrumentales registradas.
- [ ] Pruebas de regresión globales de reproducción, pausa, seek, reanudación, audio y subtítulos después de las optimizaciones (el motor no se ha modificado en esta auditoría).

**Alcance protegido:** no se ha modificado el motor de reproducción ni sus controles como parte de estas optimizaciones.


### Caché temporal de páginas del catálogo (2026-11-15)
- Se añadió una caché acotada a la última página online de catálogo consultada, identificada por modo, proveedor, tipo, consulta y offset.
- Las respuestas parciales no se guardan. Una página completa se conserva durante 90 segundos; al reutilizarla se reconstruyen los títulos, el filtro de género, la paginación y el cursor, sin cambiar la lógica de navegación/foco.
- Si no hay coincidencia vigente, se conserva la solicitud de red original. El catálogo HD local no cambia.
- Código: commit `cae1665` en `components/PlusScene.brs`.
- Estado: implementado y verificado estáticamente en GitHub; pendiente compilar y probar en Roku. No se modificó el reproductor.

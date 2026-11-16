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
- [x] Home: la rotación y selección manual del destacado ahora actualizan el poster, título, datos y puntos existentes sin reconstruir toda la pantalla. Commits `35eb15c`, `81dfa54` y `49d68d7`. **Pendiente compilar y validar en Roku.**
- [ ] Extender la reutilización de nodos a catálogo y detalle después de medir y diseñar cambios específicos; no se modificaron todavía.
- [ ] Revisar transiciones y animaciones para evitar trabajo cuando no son visibles.
- [ ] Revisar el manejo del foco y la creación/destrucción de elementos para reducir trabajo de CPU y recolección de basura.
- [ ] Probar navegación rápida entre Home, películas, series, detalle y búsqueda después de cada cambio de interfaz.

## 3. Catálogos, tareas y rendimiento

- [ ] Auditar las consultas de catálogo de películas y series: caché, paginación, concurrencia y carga progresiva.
- [ ] Comprobar que las tareas anteriores se cancelan cuando el usuario cambia de pantalla o inicia otra consulta.
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
- Los cambios están en GitHub, pero aún no hay evidencia de compilación ni prueba en dispositivo. Mantener el estado como pendiente de validación hasta recibir el log.

- Optimización incremental de Home: `heroRotationTick` y `changeHero` ya no llaman a `drawScreen()` cuando los nodos del destacado están disponibles. Se actualizan los nodos existentes; si falta el poster requerido o no están inicializados, se conserva el fallback de redibujado completo. Esto evita recrear las filas de continuar viendo, descubrimiento, lista y barra superior cada vez que cambia el destacado.
- El redibujado general sigue intacto para navegación y cambios de vista. No se hizo una refactorización masiva ni se tocó el reproductor.

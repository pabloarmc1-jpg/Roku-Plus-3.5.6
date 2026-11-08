# Preparar una playlist HLS sin ID3 (prueba Roku Plus 3.5.52)

Esta herramienta prepara **todos** los segmentos MPEG-TS de una playlist HLS VOD, remuxeando solo H.264 y AAC con FFmpeg. Al excluir el resto de pistas, elimina la pista de metadatos ID3 de cada segmento. Conserva las marcas de tiempo de entrada con `-copyts` y genera una playlist nueva con los mismos `EXTINF`.

> Esta versión 3.5.52 es una herramienta de preparación para PC, no una nueva compilación de la app Roku. No modifica `main`.

## Requisitos

- Windows PowerShell 5.1 o PowerShell 7.
- FFmpeg instalado y disponible como `ffmpeg` en PATH.
- Aproximadamente 2–3 GB libres para una película de unos 95 minutos, dependiendo del bitrate.
- PC y Roku conectados a la misma red local para servir los archivos de prueba.

## 1. Obtener la URL correcta

Usa la URL completa de la **playlist multimedia de la variante 480p** que aparece como `selectedPlaylist` en el log de Roku. Debe terminar en `.m3u8` y contener segmentos `.ts`. No uses la master playlist.

Las URL firmadas pueden caducar. Si la descarga devuelve 403/404, vuelve a abrir la película en la app y copia la URL actual del log.

## 2. Ejecutar la preparación

Abre PowerShell en la carpeta `tools` y ejecuta:

```powershell
.\Prepare-CleanHls.ps1 -PlaylistUrl "PEGA_AQUI_LA_URL_COMPLETA_DE_LA_PLAYLIST"
```

Si el servidor exige Referer, puedes pasarlo:

```powershell
.\Prepare-CleanHls.ps1 -PlaylistUrl "URL_COMPLETA" -Referer "https://lamovi.org/"
```

El proceso descarga y remuxea cada segmento. Con cientos de segmentos puede tardar bastante. No cierres PowerShell hasta que indique `LISTO`. El resultado estará en `tools\clean-hls\index-clean.m3u8`.

La herramienta se detiene si detecta cifrado HLS (`EXT-X-KEY`) o `EXT-X-MAP`; no intenta alterar esos formatos.

## 3. Servir la playlist en la red local

Desde PowerShell, todavía dentro de la carpeta `tools`, ejecuta:

```powershell
py -m http.server 8000 --bind 0.0.0.0
```

Permite Python en el Firewall de Windows si Windows lo pregunta. Averigua la IPv4 de la PC con `ipconfig`. La URL que podrá abrir el Roku será:

```
http://IP_DE_TU_PC:8000/clean-hls/index-clean.m3u8
```

Mantén encendida la PC y abierta la ventana del servidor durante la prueba.

## 4. Siguiente paso

Comparte la IPv4 local de la PC (por ejemplo, `192.168.100.20`) y confirma que la playlist `index-clean.m3u8` se generó. Con esa dirección se puede preparar una compilación diagnóstica separada que apunte el reproductor Roku a la playlist limpia.

## Alcance de la prueba

Esta prueba permite comprobar si el HLS completo funciona cuando se elimina la pista ID3 de todos los segmentos. No demuestra por adelantado que ID3 sea la causa: cada segmento se vuelve a empaquetar y debe validarse la continuidad, los tiempos y la reproducción real en el Roku. El proyecto principal permanece intacto.

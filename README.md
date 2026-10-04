# NetLab

Menús interactivos en Bash, estilo *setoolkit*, para **aprender redes usando las
herramientas reales desde la terminal**. Pensados para estudiantes de **Cisco
Networking Academy** y de técnico en redes.

Cada opción te explica **qué hace cada parámetro del comando** antes de
ejecutarlo, te muestra el comando completo y te pide confirmación. Así
automatizás el trabajo, pero siempre aprendiendo lo que hay detrás.

> **Aviso legal:** usá estos scripts **solo en redes propias, de laboratorio
> (GNS3, Packet Tracer, máquinas virtuales) o con autorización por escrito**.
> Escanear o capturar tráfico de redes ajenas sin permiso puede ser ilegal. El
> autor no se responsabiliza por el mal uso.
> 
> **Nota sobre su origen:** lo armó un estudiante de redes con ayuda de una IA
> (Claude, de Anthropic) para automatizar sus herramientas de estudio. Fue
> revisado con `shellcheck` y probado en Kali Linux. Las mejoras y correcciones
> son bienvenidas.

## Elegí tu versión

Hay dos versiones **independientes**: usá la que se ajuste a tu etapa y a tu
equipo.


||🟢 [Básico](basico/README.md)|🔵 [Completo](completo/README.md)|
|-|-|-|
|**Para quién**|Estás empezando o tu equipo tiene pocos recursos|Querés practicar de punta a punta|
|**Secciones**|8|12|
|**Descubrimiento y puertos**|✔ `nmap`, `arp-scan`, `netdiscover`|✔|
|**Captura de tráfico**|✔ `tcpdump`, Wireshark, `tshark`|✔|
|**Diagnóstico**|✔ `ping`, `traceroute`, `mtr`, `dig`|✔ y además MTU, `nc`, `whois`|
|**Detección de intrusos**|✔ Suricata + EveBox|✔|
|**Ancho de banda**|—|✔ `iftop`, `nload`, `bmon`, `vnstat`|
|**Rendimiento**|—|✔ `iperf3`|
|**Laboratorio Cisco**|—|✔ consola (`picocom`), subnetting (`sipcalc`), SNMP, TFTP|
|**Vulnerabilidades y auditoría**|—|✔ Nessus, `lynis`|
|**RAM recomendada**|4 GB o más|6 GB o más (8 GB ideal)|

**¿Cuál elijo?**

- Si es tu primer contacto con estas herramientas → empezá por el **Básico**.
- Cuando domines lo básico, o si ya estás en el tramo de laboratorios del curso
  → pasá al **Completo**.
- Podés tener las dos instaladas: no se pisan.

## Inicio rápido

```bash
**git clone https://github.com/2008calvin-sudo/netlab.git**
**cd netlab**
```
Después elegí **una** (o las dos, una a la vez):

```bash
**# Versión básica**
**cd basico**
**chmod +x Basico_netlab.sh**
**./Basico_netlab.sh**
**# Versión completa (desde la carpeta netlab)**
**cd completo**
**chmod +x Completo_netlab.sh**
**./Completo_netlab.sh**
```
Cada carpeta tiene su propio README con los requisitos, la lista de paquetes a
instalar, la configuración previa y ejercicios de práctica.

## Estructura

```
**netlab/**
**├── README.md              ← estás aquí**
**├── LICENSE**
**├── basico/**
**│   ├── Basico_netlab.sh**
**│   └── README.md**
**└── completo/**
**    ├── Completo_netlab.sh**
**    └── README.md**
```
## Contribuir

Los *issues* y *pull requests* son bienvenidos. Antes de enviar cambios, revisá
el script con `shellcheck`.

## Licencia

Distribuido bajo licencia **MIT**. Ver el archivo [LICENSE](LICENSE).


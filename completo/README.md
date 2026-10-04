# NetLab Completo

> Esta es la versión **completa** de NetLab. Si recién empezás o tu equipo tiene pocos recursos, probá primero la [versión básica](../basico/README.md). Para elegir, leé el [README general](../README.md).

Menú interactivo en Bash, estilo *setoolkit*, con **12 secciones** para practicar redes de punta a punta: descubrimiento, captura, ancho de banda, rendimiento, laboratorio Cisco, detección de intrusos y auditoría.

Cada opción te muestra **qué hace cada parámetro del comando** antes de ejecutarlo, te pide confirmación y deja el comando a la vista para que lo aprendas y puedas repetirlo a mano.

> **Aviso legal:** usá este script **solo en redes propias, de laboratorio (GNS3, Packet Tracer, máquinas virtuales) o con autorización por escrito**. Escanear, capturar tráfico o auditar redes ajenas sin permiso puede ser ilegal. El autor no se responsabiliza por el mal uso.

> **Nota sobre su origen:** este proyecto lo armó un estudiante de redes con ayuda de una IA (Claude, de Anthropic) para automatizar sus herramientas de estudio. Fue revisado con `shellcheck` y probado en Kali Linux. Las mejoras y correcciones son bienvenidas.

## Qué incluye

| Menú | Qué podés hacer | Herramientas |
|------|-----------------|--------------|
| 1. Descubrimiento | Ver quién está conectado en la red | `nmap`, `arp-scan`, `netdiscover` |
| 2. Escaneo de puertos | Rápido, SYN, TCP connect, UDP, versiones, SO, agresivo, guardar resultados | `nmap` |
| 3. Observación / captura | Capturar y leer tráfico (general, host, puerto, ICMP, ARP, DNS) | `tcpdump`, `wireshark`, `tshark` |
| 4. Ancho de banda | Quién consume y cuánto: en vivo y acumulado | `iftop`, `nload`, `bmon`, `vnstat` |
| 5. Rendimiento | Medir velocidad entre dos equipos (TCP, UDP, inverso, paralelo) | `iperf3` |
| 6. Diagnóstico | Conectividad, MTU del camino, ruta, DNS, puertos, whois | `ping`, `traceroute`, `mtr`, `dig`, `nc`, `whois` |
| 7. Laboratorio Cisco | Cable de consola, subnetting, SNMP, servidor TFTP | `picocom`, `sipcalc`, `snmpget`, `snmpwalk`, `tftpd-hpa` |
| 8. Detección de intrusos | Encender y apagar Suricata y EveBox, reglas, alertas | `suricata`, `evebox`, `jq` |
| 9. Vulnerabilidades | Encender y apagar Nessus, abrir el panel, auditar el equipo | `nessus`, `lynis` |
| 10. Información de mi red | IP, rutas, ARP, puertos, velocidad y duplex, DNS | `ip`, `ss`, `ethtool` |
| 11. Herramientas instaladas | Qué tenés y qué te falta | — |
| 12. Configurar interfaz y rango | Cambiar interfaz, rango y gateway | — |

Las opciones cuya herramienta no está instalada aparecen marcadas con `[falta]`, y el script detecta automáticamente tu interfaz, tu IP, tu rango y tu gateway.

## Requisitos

- Linux basado en Debian (probado en **Kali Linux / Kali Purple**).
- Bash y permisos de `sudo`.
- Recomendado: **8 GB de RAM** si querés usar Suricata o Nessus. Con 6 GB funciona, pero conviene no encender los dos a la vez (el script te avisa).

Instalación de las herramientas (en Kali):

```bash
sudo apt update
sudo apt install nmap arp-scan netdiscover tcpdump wireshark tshark \
                 iftop nload bmon vnstat iperf3 \
                 mtr-tiny traceroute bind9-dnsutils netcat-openbsd whois \
                 picocom sipcalc snmp ethtool jq lynis suricata
```

Opcionales:
- **tftpd-hpa**: `sudo apt install tftpd-hpa` (respaldos de configuración de equipos Cisco).
- **EveBox**: no está en los repositorios de Kali. Instalalo desde <https://evebox.org>.
- **Nessus**: descargalo desde el sitio oficial de Tenable (versión *Essentials* gratuita para uso personal).

## Uso

```bash
git clone https://github.com/2008calvin-sudo/netlab.git
cd netlab/completo
chmod +x Completo_netlab.sh
./Completo_netlab.sh
```

Durante el uso:
- Cada opción explica el comando y pide confirmación (`S/n`).
- `Ctrl+C` corta el comando en ejecución y vuelve al menú, sin cerrar el programa.
- Las capturas y resultados de nmap se guardan en `~/capturas`.

## Configuración previa recomendada

- **Wireshark sin root:** aceptá que usuarios sin privilegios puedan capturar durante la instalación y agregate al grupo:
  ```bash
  sudo usermod -aG wireshark $USER
  ```
  Cerrá sesión y volvé a entrar.
- **iperf3:** cuando el instalador pregunte si lo ejecuta como servicio al arrancar, respondé **No**. El menú 5 lo enciende cuando lo necesitás.
- **Servicios apagados por defecto:** para ahorrar memoria, que Suricata, EveBox, Nessus y TFTP no arranquen solos. Los menús 7, 8 y 9 los encienden y apagan:
  ```bash
  sudo systemctl disable --now suricata
  ```
- **Suricata:** actualizá las reglas (menú 8, opción 7) antes de esperar alertas.
- **Nessus:** la primera vez compila plugins y puede tardar bastante, sobre todo en discos HDD. El panel queda en `https://localhost:8834`.
- **vnstat:** encendé la recolección (menú 4, opción 7) y esperá un rato para tener historial.

## Ideas de práctica

1. **Subnetting:** menú 7 → `sipcalc` para verificar tus ejercicios del curso, y la opción de dividir en subredes.
2. **Capa 2:** menú 3 → capturá ARP e ICMP mientras hacés `ping` desde otra terminal.
3. **IDS en acción:** encendé Suricata y EveBox (menú 8), lanzá un escaneo agresivo (menú 2) y mirá las alertas.
4. **Consola Cisco:** conectate a un router o switch real con `picocom` (menú 7) a 9600 baudios.
5. **MTU y fragmentación:** menú 6 → prueba de MTU con el bit DF activado.
6. **Rendimiento:** medí tu red con `iperf3` entre dos equipos (menú 5) y compará TCP con UDP.

## Problemas comunes

| Síntoma | Solución |
|---------|----------|
| `[falta]` junto a una opción | Instalá el paquete que indica el menú 11 |
| `dig` no aparece | `sudo apt install bind9-dnsutils` |
| EveBox o Nessus no aparecen | Se instalan fuera de apt (ver *Opcionales*) |
| Wireshark no ve interfaces | Agregate al grupo `wireshark` y reiniciá sesión |
| Suricata no genera alertas | Menú 8 → actualizar reglas y reiniciar el servicio |
| `picocom` sin permiso en `/dev/ttyUSB0` | El menú lo ejecuta con sudo, o agregate al grupo `dialout` |
| SNMP no responde | Habilitalo en el equipo: `snmp-server community public RO` (solo laboratorio) |
| El equipo se pone lento | No uses Suricata y Nessus a la vez; apagá lo que no necesites |

## Contribuir

Los *issues* y *pull requests* son bienvenidos. Antes de enviar cambios, revisá el script con:

```bash
shellcheck Completo_netlab.sh
```

## Licencia

Distribuido bajo licencia **MIT**. Ver el archivo [LICENSE](../LICENSE).

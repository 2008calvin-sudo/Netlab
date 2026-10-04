# NetLab Básico

> Esta es la versión **básica** de NetLab. ¿Querés más herramientas (ancho de banda, iperf3, laboratorio Cisco, Nessus)? Mirá la [versión completa](../completo/README.md). Para elegir, leé el [README general](../README.md).

Menú interactivo en Bash, estilo *setoolkit*, para aprender y practicar con las herramientas de redes más usadas desde la terminal. Está pensado para estudiantes de **Cisco Networking Academy** y de técnico en redes.

Cada opción te muestra **qué hace cada parámetro del comando** antes de ejecutarlo, te pide confirmación y te deja el comando a la vista para que lo aprendas y puedas repetirlo a mano.

> **Aviso legal:** usá este script **solo en redes propias, de laboratorio (GNS3, Packet Tracer, máquinas virtuales) o con autorización por escrito**. Escanear o capturar tráfico de redes ajenas sin permiso puede ser ilegal. El autor no se responsabiliza por el mal uso.

> **Nota sobre su origen:** este proyecto lo armó un estudiante de redes con ayuda de una IA (Claude, de Anthropic) para automatizar sus herramientas de estudio. Fue revisado con `shellcheck` y probado en Kali Linux. Las mejoras y correcciones son bienvenidas.

## Qué incluye

| Menú | Qué podés hacer | Herramientas |
|------|-----------------|--------------|
| 1. Descubrimiento | Ver quién está conectado en la red | `nmap`, `arp-scan`, `netdiscover` |
| 2. Escaneo de puertos | Rápido, SYN, TCP connect, UDP, versiones, SO, agresivo, guardar resultados | `nmap` |
| 3. Observación / captura | Ver y guardar tráfico (general, host, puerto, ICMP, ARP, DNS), leer `.pcap` | `tcpdump`, `wireshark`, `tshark` |
| 4. Detección de intrusos | Encender y apagar Suricata y EveBox, actualizar reglas, ver alertas | `suricata`, `evebox` |
| 5. Diagnóstico | Probar conectividad, ruta y DNS | `ping`, `traceroute`, `mtr`, `dig` |
| 6. Información de mi red | IP, rutas, tabla ARP, puertos y conexiones | `ip`, `ss` |
| 7. Herramientas instaladas | Qué tenés y qué te falta | — |
| 8. Configurar interfaz y rango | Cambiar interfaz, rango y gateway | — |

El script detecta automáticamente tu interfaz, tu rango de red y tu gateway.

## Requisitos

- Linux basado en Debian (probado en **Kali Linux / Kali Purple**).
- Bash y permisos de `sudo` (varias herramientas necesitan root).
- Las herramientas que quieras usar. Si falta alguna, el menú te avisa cuál instalar.

Instalación de las herramientas (en Kali):

```bash
sudo apt update
sudo apt install nmap arp-scan netdiscover tcpdump wireshark tshark \
                 suricata mtr-tiny traceroute bind9-dnsutils
```

**EveBox** no está en los repositorios de Kali: instalalo desde su sitio oficial (<https://evebox.org>).

## Uso

```bash
git clone https://github.com/2008calvin-sudo/netlab.git
cd netlab/basico
chmod +x Basico_netlab.sh
./Basico_netlab.sh
```

Durante el uso:
- Cada opción explica el comando y pide confirmación (`S/n`).
- `Ctrl+C` corta el comando en ejecución y vuelve al menú, sin cerrar el programa.
- Las capturas y resultados de nmap se guardan en `~/capturas`.

## Ejemplo de lo que vas a ver

```
== Escaneo SYN (el sencillo) ==
Que hace:
  -sS : SYN scan o 'half-open'. Envia SYN; si recibe SYN/ACK el puerto esta
        abierto y corta con RST sin completar el handshake de 3 vias.
        Rapido y poco ruidoso. Requiere root.

Comando: sudo nmap -sS 192.168.1.1
Ejecutar? [S/n]:
```

## Configuración previa recomendada

- **Wireshark sin root:** durante la instalación aceptá que usuarios sin privilegios puedan capturar, y agregate al grupo:
  ```bash
  sudo usermod -aG wireshark $USER
  ```
  Luego cerrá sesión y volvé a entrar.
- **Suricata:** antes de ver alertas, actualizá las reglas desde el menú 4 (opción 7) o con `sudo suricata-update`.
- **Servicios apagados:** conviene que Suricata y EveBox no arranquen solos, para ahorrar memoria. El menú 4 los enciende y apaga cuando los necesites:
  ```bash
  sudo systemctl disable --now suricata
  ```
- **EveBox:** el menú lo inicia leyendo `/var/log/suricata/eve.json`. El panel queda en `http://127.0.0.1:5636` (o `https://`, según la versión). Si no levanta, mirá `/tmp/netlab_evebox.log`.

## Idea de práctica

1. Encendé Suricata y EveBox (menú 4).
2. Desde el menú 2, ejecutá un escaneo agresivo (`-A`) contra tu gateway.
3. Volvé al menú 4 y mirá las alertas que generó: así ves cómo un IDS detecta un escaneo.
4. En el menú 3, capturá tráfico ICMP y ARP mientras hacés `ping` desde otra terminal.

## Problemas comunes

| Síntoma | Solución |
|---------|----------|
| `'dig' no esta instalado` | `sudo apt install bind9-dnsutils` |
| `evebox` no aparece | Instalarlo desde evebox.org (no está en apt) |
| Wireshark no ve interfaces | Agregate al grupo `wireshark` y reiniciá sesión |
| Suricata no genera alertas | Ejecutá `suricata-update` y reiniciá el servicio |
| Colores raros en la terminal | Usá una terminal con soporte ANSI (la de Kali lo tiene) |

## Contribuir

Los *issues* y *pull requests* son bienvenidos. Antes de enviar cambios, revisá el script con:

```bash
shellcheck Basico_netlab.sh
```

## Licencia

Distribuido bajo licencia **MIT**. Ver el archivo [LICENSE](../LICENSE).

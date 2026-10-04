#!/usr/bin/env bash
# =====================================================================
#  NetLab - Menu de herramientas de red (estilo setoolkit)
#  Pensado para practicar con Cisco Networking Academy.
#  Herramientas: nmap, arp-scan, netdiscover, tcpdump, wireshark,
#                tshark, suricata, evebox, ping, traceroute, mtr, dig
#  USO: chmod +x netlab.sh && ./netlab.sh
#  IMPORTANTE: usalo SOLO en redes propias o de laboratorio
#  (GNS3, Packet Tracer, VMs) o con autorizacion por escrito.
# =====================================================================

# ---------- Colores ----------
R=$'\e[31m'; G=$'\e[32m'; Y=$'\e[33m'; B=$'\e[34m'; C=$'\e[36m'; W=$'\e[1m'; N=$'\e[0m'

# Ctrl+C no debe cerrar el menu (solo corta el comando en ejecucion)
trap '' INT

SUDO=""; [[ $EUID -ne 0 ]] && SUDO="sudo"
CAPDIR="$HOME/capturas"; mkdir -p "$CAPDIR"
EVE_JSON="/var/log/suricata/eve.json"
EVE_LOG="/tmp/netlab_evebox.log"

# ---------- Interfaz y rango por defecto (autodeteccion) ----------
detectar_red() {
  IFACE=$(ip route show default 2>/dev/null | awk '/default/ {print $5; exit}')
  IFACE=${IFACE:-eth0}
  RANGO=$(ip -o -f inet addr show "$IFACE" 2>/dev/null | awk '{print $4; exit}')
  RANGO=${RANGO:-192.168.1.0/24}
  GATEWAY=$(ip route show default 2>/dev/null | awk '/default/ {print $3; exit}')
  GATEWAY=${GATEWAY:-192.168.1.1}
}
detectar_red

# ---------- Utilidades ----------
pausa() { echo; read -rp "${Y}Enter para continuar...${N}" _; }

banner() {
  clear
  echo "${C}${W}"
  echo "  _   _      _   _          _     "
  echo " | \ | | ___| |_| |    __ _| |__  "
  echo " |  \| |/ _ \ __| |   / _\` | '_ \ "
  echo " | |\  |  __/ |_| |__| (_| | |_) |"
  echo " |_| \_|\___|\__|_____\__,_|_.__/ "
  echo "${N}${B} Menu de herramientas de red - Cisco Networking Academy${N}"
  echo " Interfaz: ${G}$IFACE${N}  Mi rango: ${G}$RANGO${N}  Gateway: ${G}$GATEWAY${N}"
  echo "${R} Usalo solo en redes propias / de laboratorio / autorizadas.${N}"
  echo
}

tiene() { command -v "$1" >/dev/null 2>&1; }

necesita() { # herramienta  paquete
  if ! tiene "$1"; then
    echo "${R}[!] '$1' no esta instalado.${N} Instalar con: sudo apt install ${2:-$1}"
    pausa; return 1
  fi
  return 0
}

# Pide un dato con valor por defecto y lo valida (solo caracteres seguros)
pedir() { # variable  pregunta  defecto
  local __in
  read -rp "$2 ${Y}[$3]${N}: " __in
  __in="${__in:-$3}"
  if [[ ! "$__in" =~ ^[A-Za-z0-9./:,_\ @=-]+$ ]]; then
    echo "${R}[!] Entrada con caracteres no permitidos.${N}"; return 1
  fi
  printf -v "$1" '%s' "$__in"
}

# Muestra explicacion + comando, pide confirmacion y lo ejecuta
# lanzar "Titulo" "Explicacion" "comando" [root=0|1]
lanzar() {
  local titulo="$1" explica="$2" cmd="$3" root="${4:-0}"
  [[ "$root" == "1" && -n "$SUDO" ]] && cmd="$SUDO $cmd"
  echo
  echo "${W}${G}== $titulo ==${N}"
  echo "${C}Que hace:${N}"
  echo -e "$explica" | sed 's/^/  /'
  echo
  echo "${C}Comando:${N} ${W}$cmd${N}"
  echo
  read -rp "Ejecutar? [S/n]: " r
  [[ "$r" =~ ^[nN]$ ]] && return
  echo "${Y}(Ctrl+C corta el comando y vuelve al menu)${N}"
  echo "-----------------------------------------------------------"
  ( trap - INT; eval "$cmd" )
  echo "-----------------------------------------------------------"
  pausa
}

# =====================================================================
#  1) DESCUBRIMIENTO DE HOSTS
# =====================================================================
menu_descubrimiento() {
  while true; do
    banner
    echo "${W}[1] DESCUBRIMIENTO - Quien esta conectado en la red${N}"
    echo
    echo "  1) nmap  - Ping sweep            (hosts vivos, sin escanear puertos)"
    echo "  2) nmap  - Descubrimiento ARP    (LAN, muy fiable)"
    echo "  3) nmap  - Solo listar/resolver  (no envia paquetes al objetivo)"
    echo "  4) arp-scan - Escaneo ARP local  (rapido, muestra fabricante MAC)"
    echo "  5) netdiscover - Activo          (ARP sobre un rango)"
    echo "  6) netdiscover - Pasivo          (solo escucha, no genera trafico)"
    echo "  0) Volver"
    echo
    read -rp "${W}netlab/descubrimiento> ${N}" op
    case $op in
      1) necesita nmap || continue; pedir T "Rango/objetivo" "$RANGO" || { pausa; continue; }
         lanzar "nmap -sn (Ping sweep)" \
"nmap     : escaner de redes.
-sn      : 'scan no port' -> solo comprueba si el host responde (ICMP/ARP/TCP),
           NO escanea puertos. Es el descubrimiento mas suave." \
         "nmap -sn $T" 0 ;;
      2) necesita nmap || continue; pedir T "Rango/objetivo (misma LAN)" "$RANGO" || { pausa; continue; }
         lanzar "nmap -sn -PR (ARP)" \
"-sn : solo descubrimiento de hosts.
-PR  : usa peticiones ARP (capa 2). En una LAN es lo mas fiable porque
       un host no puede ocultarse de ARP aunque bloquee ping.
Requiere root para enviar ARP crudo." \
         "nmap -sn -PR $T" 1 ;;
      3) necesita nmap || continue; pedir T "Rango/objetivo" "$RANGO" || { pausa; continue; }
         lanzar "nmap -sL (List scan)" \
"-sL : 'list scan'. Solo lista las IPs del rango y hace resolucion DNS inversa.
       No envia paquetes a los hosts. Util para ver nombres en un rango." \
         "nmap -sL $T" 0 ;;
      4) necesita arp-scan || continue; pedir I "Interfaz" "$IFACE" || { pausa; continue; }
         lanzar "arp-scan --localnet" \
"arp-scan   : envia ARP-request a todas las IPs de la red local.
--localnet  : usa automaticamente el rango de la interfaz.
-I <if>     : interfaz a usar.
Muestra IP, MAC y fabricante (OUI) de cada equipo." \
         "arp-scan --localnet -I $I" 1 ;;
      5) necesita netdiscover || continue; pedir T "Rango" "$RANGO" || { pausa; continue; }
         pedir I "Interfaz" "$IFACE" || { pausa; continue; }
         lanzar "netdiscover activo" \
"-r <rango> : rango a escanear con ARP.
-i <if>     : interfaz de red.
-P          : salida simple (imprime y termina, sin pantalla interactiva)." \
         "netdiscover -i $I -r $T -P" 1 ;;
      6) necesita netdiscover || continue; pedir I "Interfaz" "$IFACE" || { pausa; continue; }
         lanzar "netdiscover pasivo" \
"-p : modo pasivo. Solo escucha ARP que pasan por la red, no envia nada.
      Es silencioso (no lo detecta un IDS), pero tarda mas en ver equipos.
Salir con 'q' o Ctrl+C." \
         "netdiscover -i $I -p" 1 ;;
      0) return ;;
    esac
  done
}

# =====================================================================
#  2) ESCANEO DE PUERTOS Y SERVICIOS (nmap)
# =====================================================================
menu_puertos() {
  necesita nmap || return
  while true; do
    banner
    echo "${W}[2] ESCANEO DE PUERTOS Y SERVICIOS - nmap${N}"
    echo
    echo "  1) Escaneo rapido          (-F, los 100 puertos mas comunes)"
    echo "  2) Escaneo SYN sencillo    (-sS, semiabierto, el clasico)"
    echo "  3) Escaneo TCP connect     (-sT, sin necesidad de root)"
    echo "  4) Escaneo UDP             (-sU, top 20 puertos)"
    echo "  5) Deteccion de versiones  (-sV, que servicio y version corre)"
    echo "  6) Deteccion de SO         (-O, adivina el sistema operativo)"
    echo "  7) Todos los puertos       (-p-, 65535 puertos)"
    echo "  8) Escaneo agresivo        (-A, SO + versiones + scripts + traceroute)"
    echo "  9) Scripts por defecto     (-sC, NSE basicos)"
    echo " 10) Escaneo y guardar       (-oN, guarda el resultado en archivo)"
    echo " 11) Puertos especificos     (-p 22,80,443)"
    echo "  0) Volver"
    echo
    read -rp "${W}netlab/puertos> ${N}" op
    [[ "$op" == "0" ]] && return
    [[ ! "$op" =~ ^([1-9]|1[01])$ ]] && continue
    pedir T "Objetivo (IP, rango o dominio)" "$GATEWAY" || { pausa; continue; }
    case $op in
      1) lanzar "Escaneo rapido" \
"-F : 'fast'. Escanea solo los 100 puertos mas usados en vez de los 1000 por defecto.
Ideal para un primer vistazo." "nmap -F $T" 0 ;;
      2) lanzar "Escaneo SYN (el sencillo)" \
"-sS : SYN scan o 'half-open'. Envia SYN; si recibe SYN/ACK el puerto esta
       abierto y corta con RST sin completar el handshake de 3 vias.
       Rapido y poco ruidoso. Requiere root." "nmap -sS $T" 1 ;;
      3) lanzar "Escaneo TCP connect" \
"-sT : completa el handshake TCP entero (SYN, SYN/ACK, ACK) usando el sistema.
       No necesita root pero es mas lento y deja mas huellas en logs." "nmap -sT $T" 0 ;;
      4) lanzar "Escaneo UDP (top 20)" \
"-sU           : escaneo de puertos UDP (DNS 53, DHCP 67, SNMP 161...).
--top-ports 20 : solo los 20 UDP mas comunes. UDP es lento, no pruebes todos.
Requiere root." "nmap -sU --top-ports 20 $T" 1 ;;
      5) lanzar "Deteccion de versiones" \
"-sV : interroga los puertos abiertos para saber que servicio y que version
       corren (ej: OpenSSH 8.9, Apache 2.4.52)." "nmap -sV $T" 0 ;;
      6) lanzar "Deteccion de sistema operativo" \
"-O : fingerprinting del SO por el comportamiento de la pila TCP/IP.
Requiere root y al menos un puerto abierto y uno cerrado." "nmap -O $T" 1 ;;
      7) lanzar "Todos los puertos" \
"-p- : escanea los 65535 puertos TCP.
-T4  : plantilla de velocidad 4 (agresiva pero razonable en LAN). Escala 0-5." "nmap -p- -T4 $T" 0 ;;
      8) lanzar "Escaneo agresivo" \
"-A  : activa -O (SO), -sV (versiones), -sC (scripts) y --traceroute.
-T4 : mas velocidad.
Es ruidoso: un IDS como Suricata lo detectara. Perfecto para ver alertas!" "nmap -A -T4 $T" 1 ;;
      9) lanzar "Scripts por defecto" \
"-sC : ejecuta los scripts NSE de la categoria 'default' (titulos web, banners,
       informacion SSL, SMB...). Seguros y utiles para empezar." "nmap -sC $T" 0 ;;
     10) pedir F "Nombre del archivo" "escaneo_$(date +%H%M).txt" || { pausa; continue; }
         lanzar "Escanear y guardar" \
"-sV     : versiones de servicios.
-oN <f> : guarda la salida en formato normal (legible) en el archivo.
Guarda en: $CAPDIR" "nmap -sV -oN $CAPDIR/$F $T" 0 ;;
     11) pedir P "Puertos (ej: 22,80,443 o 1-1024)" "22,80,443" || { pausa; continue; }
         lanzar "Puertos especificos" \
"-p <lista> : escanea solo los puertos indicados. Acepta lista (22,80) y rangos (1-1024)." \
         "nmap -p $P $T" 0 ;;
    esac
  done
}

# =====================================================================
#  3) OBSERVACION / CAPTURA DE TRAFICO
# =====================================================================
menu_captura() {
  while true; do
    banner
    echo "${W}[3] OBSERVACION - Captura y analisis de trafico${N}"
    echo
    echo "  1) tcpdump - Ver trafico general        (50 paquetes)"
    echo "  2) tcpdump - Filtrar por host"
    echo "  3) tcpdump - Filtrar por puerto"
    echo "  4) tcpdump - Solo ICMP                  (ping)"
    echo "  5) tcpdump - Solo ARP"
    echo "  6) tcpdump - Solo DNS                   (puerto 53)"
    echo "  7) tcpdump - Guardar captura en .pcap"
    echo "  8) tcpdump - Leer un .pcap"
    echo "  9) Wireshark - Abrir interfaz grafica"
    echo " 10) tshark   - Captura en consola       (Wireshark sin GUI)"
    echo "  0) Volver"
    echo
    read -rp "${W}netlab/observacion> ${N}" op
    case $op in
      1|2|3|4|5|6|7) necesita tcpdump || continue ;;
      9) necesita wireshark || continue ;;
      10) necesita tshark || continue ;;
    esac
    case $op in
      1) pedir I "Interfaz" "$IFACE" || { pausa; continue; }
         lanzar "tcpdump general" \
"-i <if> : interfaz a escuchar.
-n       : no resolver nombres (mas rapido, ves IPs).
-c 50    : se detiene tras 50 paquetes." "tcpdump -i $I -n -c 50" 1 ;;
      2) pedir I "Interfaz" "$IFACE" || { pausa; continue; }
         pedir H "IP del host" "$GATEWAY" || { pausa; continue; }
         lanzar "tcpdump por host" \
"host <ip> : filtro BPF, solo paquetes de/hacia esa IP.
-n         : sin resolucion DNS." "tcpdump -i $I -n -c 50 host $H" 1 ;;
      3) pedir I "Interfaz" "$IFACE" || { pausa; continue; }
         pedir P "Puerto" "80" || { pausa; continue; }
         lanzar "tcpdump por puerto" \
"port <n> : filtro BPF, solo trafico TCP o UDP de ese puerto (80 HTTP, 443 HTTPS...)." \
         "tcpdump -i $I -n -c 50 port $P" 1 ;;
      4) pedir I "Interfaz" "$IFACE" || { pausa; continue; }
         lanzar "tcpdump ICMP" \
"icmp : solo mensajes ICMP (ping, destino inalcanzable, TTL excedido).
Abri otra terminal y hace 'ping' para verlo en vivo." "tcpdump -i $I -n -c 20 icmp" 1 ;;
      5) pedir I "Interfaz" "$IFACE" || { pausa; continue; }
         lanzar "tcpdump ARP" \
"arp : solo ARP (quien tiene tal IP? -> responde su MAC). Clave para entender capa 2.
-e   : muestra tambien las direcciones MAC (cabecera Ethernet)." "tcpdump -i $I -n -e -c 20 arp" 1 ;;
      6) pedir I "Interfaz" "$IFACE" || { pausa; continue; }
         lanzar "tcpdump DNS" \
"port 53 : consultas y respuestas DNS.
-v       : un poco mas de detalle (tipo de registro, TTL)." "tcpdump -i $I -n -v -c 20 port 53" 1 ;;
      7) pedir I "Interfaz" "$IFACE" || { pausa; continue; }
         pedir F "Archivo" "captura_$(date +%H%M).pcap" || { pausa; continue; }
         pedir M "Cantidad de paquetes" "200" || { pausa; continue; }
         lanzar "tcpdump guardar pcap" \
"-w <f> : escribe los paquetes crudos en un archivo .pcap (se abre luego en Wireshark).
-c <n>  : cantidad de paquetes a capturar.
Guarda en: $CAPDIR" "tcpdump -i $I -n -c $M -w $CAPDIR/$F" 1 ;;
      8) pedir F "Archivo pcap (ruta completa)" "$CAPDIR/" || { pausa; continue; }
         lanzar "tcpdump leer pcap" \
"-r <f> : lee un archivo de captura en vez de la red.
-nn     : sin resolver nombres ni puertos." "tcpdump -nn -r $F" 0 ;;
      9) pedir I "Interfaz" "$IFACE" || { pausa; continue; }
         lanzar "Wireshark" \
"-i <if> : interfaz a capturar.
-k       : empieza a capturar inmediatamente.
Se abre en segundo plano. Si no ves interfaces: sudo usermod -aG wireshark \$USER y reinicia sesion." \
         "nohup wireshark -i $I -k >/dev/null 2>&1 &" 0 ;;
     10) pedir I "Interfaz" "$IFACE" || { pausa; continue; }
         lanzar "tshark" \
"tshark es Wireshark en terminal (mismos filtros y disectores).
-i <if> : interfaz.   -c 30 : 30 paquetes.
Muestra el protocolo ya interpretado (HTTP, DNS, TLS...)." "tshark -i $I -c 30" 1 ;;
      0) return ;;
    esac
  done
}

# =====================================================================
#  4) IDS: SURICATA + EVEBOX (encender / apagar)
# =====================================================================
suricata_activo() { systemctl is-active --quiet suricata 2>/dev/null || pgrep -x Suricata-Main >/dev/null 2>&1 || pgrep -x suricata >/dev/null 2>&1; }
evebox_activo()   { systemctl is-active --quiet evebox 2>/dev/null || pgrep -f "evebox server" >/dev/null 2>&1; }

estado_txt() { "$1" && echo "${G}ENCENDIDO${N}" || echo "${R}APAGADO${N}"; }

menu_ids() {
  while true; do
    banner
    echo "${W}[4] DETECCION DE INTRUSOS - Suricata + EveBox${N}"
    echo
    echo "  Suricata: $(estado_txt suricata_activo)    EveBox: $(estado_txt evebox_activo)"
    echo
    echo "  1) Encender Suricata"
    echo "  2) Apagar Suricata"
    echo "  3) Encender EveBox      (panel web de alertas)"
    echo "  4) Apagar EveBox"
    echo "  5) Encender TODO        (Suricata + EveBox)"
    echo "  6) Apagar TODO"
    echo "  7) Actualizar reglas    (suricata-update)"
    echo "  8) Probar configuracion (suricata -T)"
    echo "  9) Ver ultimas alertas  (eve.json)"
    echo "  0) Volver"
    echo
    read -rp "${W}netlab/ids> ${N}" op
    case $op in
      1) suricata_on ;;
      2) suricata_off ;;
      3) evebox_on ;;
      4) evebox_off ;;
      5) suricata_on; evebox_on ;;
      6) evebox_off; suricata_off ;;
      7) necesita suricata-update "suricata (incluye suricata-update)" || continue
         lanzar "Actualizar reglas" \
"suricata-update descarga y activa los conjuntos de reglas (ET Open por defecto).
Sin reglas Suricata no genera alertas. Luego reinicia Suricata." "suricata-update" 1 ;;
      8) necesita suricata || continue
         lanzar "Probar configuracion" \
"-T         : modo test, valida la configuracion y las reglas y termina.
-c <yaml>   : archivo de configuracion." "suricata -T -c /etc/suricata/suricata.yaml" 1 ;;
      9) lanzar "Ultimas alertas" \
"Lee las ultimas lineas de eve.json (el log de eventos de Suricata) y muestra
solo las de tipo 'alert'. Prueba: lanza un 'nmap -A' contra tu gateway y vuelve aca." \
"( $SUDO tail -n 500 $EVE_JSON | grep '\"event_type\":\"alert\"' | tail -n 10 ) || echo 'Sin alertas o no existe $EVE_JSON'" 0 ;;
      0) return ;;
    esac
  done
}

suricata_on() {
  necesita suricata || return
  if suricata_activo; then echo "${Y}Suricata ya esta encendido.${N}"; pausa; return; fi
  echo "${C}Encendiendo Suricata...${N}"
  if systemctl list-unit-files 2>/dev/null | grep -q '^suricata'; then
    $SUDO systemctl start suricata
  else
    $SUDO suricata -c /etc/suricata/suricata.yaml -i "$IFACE" -D
  fi
  sleep 2
  echo "Estado: $(estado_txt suricata_activo)"
  echo "(La interfaz que escucha se define en /etc/suricata/suricata.yaml -> af-packet)"
  pausa
}

suricata_off() {
  echo "${C}Apagando Suricata...${N}"
  if systemctl list-unit-files 2>/dev/null | grep -q '^suricata'; then
    $SUDO systemctl stop suricata
  else
    $SUDO pkill -x suricata; $SUDO pkill -x Suricata-Main
  fi
  sleep 1; echo "Estado: $(estado_txt suricata_activo)"; pausa
}

evebox_on() {
  necesita evebox || return
  if evebox_activo; then echo "${Y}EveBox ya esta encendido.${N}"; pausa; return; fi
  echo "${C}Encendiendo EveBox...${N}"
  if systemctl list-unit-files 2>/dev/null | grep -q '^evebox'; then
    $SUDO systemctl start evebox
  else
    # Lee eve.json de Suricata y guarda en una base SQLite local
    $SUDO nohup evebox server --datastore sqlite --input "$EVE_JSON" >"$EVE_LOG" 2>&1 &
  fi
  sleep 3
  echo "Estado: $(estado_txt evebox_activo)"
  echo "Abri en el navegador: ${W}http://127.0.0.1:5636${N} (o https:// segun tu version)"
  echo "Si no levanta mira el log: $EVE_LOG   y   evebox server --help"
  pausa
}

evebox_off() {
  echo "${C}Apagando EveBox...${N}"
  if systemctl list-unit-files 2>/dev/null | grep -q '^evebox'; then
    $SUDO systemctl stop evebox
  fi
  $SUDO pkill -f "evebox server" 2>/dev/null
  sleep 1; echo "Estado: $(estado_txt evebox_activo)"; pausa
}

# =====================================================================
#  5) DIAGNOSTICO (ping, traceroute, mtr, dig)
# =====================================================================
menu_diagnostico() {
  while true; do
    banner
    echo "${W}[5] DIAGNOSTICO - Conectividad y resolucion de problemas${N}"
    echo
    echo "  1) ping        - Conectividad basica        (capa 3, ICMP)"
    echo "  2) traceroute  - Ruta salto a salto"
    echo "  3) mtr         - traceroute + ping continuo (reporte)"
    echo "  4) dig         - Consulta DNS"
    echo "  5) ping al gateway (prueba rapida de LAN)"
    echo "  0) Volver"
    echo
    read -rp "${W}netlab/diagnostico> ${N}" op
    case $op in
      1) pedir T "Destino" "8.8.8.8" || { pausa; continue; }
         lanzar "ping" \
"-c 4 : envia 4 ICMP Echo Request y espera 4 Echo Reply.
Muestra tiempo (ms) y TTL. Perdida de paquetes = problema de conectividad." "ping -c 4 $T" 0 ;;
      2) necesita traceroute || continue; pedir T "Destino" "8.8.8.8" || { pausa; continue; }
         lanzar "traceroute" \
"Envia paquetes con TTL creciente (1,2,3...). Cada router que descarta el paquete
responde 'TTL excedido' y asi se descubre cada salto del camino.
-n : sin resolver nombres (mas rapido)." "traceroute -n $T" 0 ;;
      3) necesita mtr || continue; pedir T "Destino" "8.8.8.8" || { pausa; continue; }
         lanzar "mtr" \
"Combina ping + traceroute y mide perdida y latencia en cada salto.
-r : modo reporte (termina solo).   -n : sin DNS.   -c 10 : 10 ciclos." "mtr -rn -c 10 $T" 0 ;;
      4) necesita dig dnsutils || continue; pedir T "Dominio" "cisco.com" || { pausa; continue; }
         pedir Q "Tipo de registro (A, AAAA, MX, NS, TXT)" "A" || { pausa; continue; }
         lanzar "dig" \
"Consulta un servidor DNS. Tipos: A (IPv4), AAAA (IPv6), MX (correo), NS (servidores
de nombres), TXT. +short muestra solo la respuesta." "dig $T $Q +short" 0 ;;
      5) lanzar "ping al gateway" \
"Prueba tu enlace con el router. Si falla, el problema es local (cable, Wi-Fi, IP, VLAN)." \
         "ping -c 4 $GATEWAY" 0 ;;
      0) return ;;
    esac
  done
}

# =====================================================================
#  6) INFORMACION DE MI RED
# =====================================================================
menu_info() {
  while true; do
    banner
    echo "${W}[6] INFORMACION DE MI RED${N}"
    echo
    echo "  1) Interfaces e IPs      (ip -br addr)"
    echo "  2) Tabla de rutas        (ip route)"
    echo "  3) Tabla ARP / vecinos   (ip neigh)"
    echo "  4) Puertos en escucha    (ss -tulpn)"
    echo "  5) Conexiones activas    (ss -tn)"
    echo "  0) Volver"
    echo
    read -rp "${W}netlab/info> ${N}" op
    case $op in
      1) lanzar "ip -br addr" "Resumen de interfaces: estado (UP/DOWN) y direcciones IPv4/IPv6 con mascara (CIDR)." "ip -br addr" 0 ;;
      2) lanzar "ip route" "Tabla de enrutamiento. La linea 'default via X' es tu gateway (puerta de enlace)." "ip route" 0 ;;
      3) lanzar "ip neigh" "Tabla ARP: relacion IP -> MAC de los equipos con los que hablaste (capa 2)." "ip neigh" 0 ;;
      4) lanzar "ss -tulpn" \
"-t TCP  -u UDP  -l solo en escucha  -p proceso dueño  -n numeros (sin resolver).
Muestra que servicios tiene abiertos TU maquina." "ss -tulpn" 1 ;;
      5) lanzar "ss -tn" "Conexiones TCP establecidas ahora mismo (origen y destino)." "ss -tn" 0 ;;
      0) return ;;
    esac
  done
}

# =====================================================================
#  7) ESTADO DE HERRAMIENTAS
# =====================================================================
menu_estado() {
  banner
  echo "${W}[7] HERRAMIENTAS INSTALADAS${N}"
  echo
  local t
  for t in nmap arp-scan netdiscover tcpdump wireshark tshark suricata suricata-update evebox mtr traceroute dig; do
    if tiene "$t"; then printf "  %-16s ${G}instalado${N}  (%s)\n" "$t" "$(command -v "$t")"
    else printf "  %-16s ${R}falta${N}\n" "$t"; fi
  done
  echo
  echo "  Suricata: $(estado_txt suricata_activo)    EveBox: $(estado_txt evebox_activo)"
  echo
  echo "  Instalar las que falten (Debian/Ubuntu/Kali):"
  echo "  sudo apt install nmap arp-scan netdiscover tcpdump wireshark tshark suricata mtr traceroute dnsutils"
  pausa
}

# =====================================================================
#  8) CAMBIAR INTERFAZ / RANGO
# =====================================================================
menu_config() {
  banner
  echo "${W}[8] CONFIGURAR INTERFAZ Y RANGO${N}"
  echo "  Interfaces disponibles:"; ip -br link | awk '{print "   - "$1" ("$2")"}'
  echo
  pedir IFACE "Interfaz" "$IFACE" || { pausa; return; }
  RANGO=$(ip -o -f inet addr show "$IFACE" 2>/dev/null | awk '{print $4; exit}'); RANGO=${RANGO:-192.168.1.0/24}
  pedir RANGO "Rango (CIDR, ej 192.168.1.0/24)" "$RANGO" || { pausa; return; }
  pedir GATEWAY "Gateway" "$GATEWAY" || { pausa; return; }
  echo "${G}Listo.${N}"; sleep 1
}

# =====================================================================
#  MENU PRINCIPAL
# =====================================================================
while true; do
  banner
  echo "${W}MENU PRINCIPAL${N}"
  echo
  echo "  1) Descubrimiento        ${B}(nmap, arp-scan, netdiscover)${N}"
  echo "  2) Escaneo de puertos    ${B}(nmap: -sS, -sV, -O, -A ...)${N}"
  echo "  3) Observacion / captura ${B}(tcpdump, wireshark, tshark)${N}"
  echo "  4) Deteccion de intrusos ${B}(suricata + evebox: encender/apagar)${N}"
  echo "  5) Diagnostico           ${B}(ping, traceroute, mtr, dig)${N}"
  echo "  6) Informacion de mi red ${B}(ip, ss, arp)${N}"
  echo "  7) Herramientas instaladas / estado"
  echo "  8) Configurar interfaz y rango"
  echo "  0) Salir"
  echo
  read -rp "${W}netlab> ${N}" op
  case $op in
    1) menu_descubrimiento ;;
    2) menu_puertos ;;
    3) menu_captura ;;
    4) menu_ids ;;
    5) menu_diagnostico ;;
    6) menu_info ;;
    7) menu_estado ;;
    8) menu_config ;;
    0|q|Q) echo "Hasta luego!"; exit 0 ;;
  esac
done

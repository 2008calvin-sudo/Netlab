#!/usr/bin/env bash
# =====================================================================
#  NetLab v2 - Menu de herramientas de REDES (estilo setoolkit)
#  Pensado para Kali Purple + estudio de Cisco Networking Academy.
#  Solo herramientas de redes: nmap, arp-scan, netdiscover, tcpdump,
#  wireshark, tshark, iftop, nload, bmon, vnstat, iperf3, mtr, dig,
#  nc, picocom, sipcalc, snmp, suricata, evebox, nessus, lynis.
#  USO: chmod +x netlab.sh && ./netlab.sh
#  IMPORTANTE: usalo SOLO en redes propias o de laboratorio
#  (GNS3, Packet Tracer, VMs) o con autorizacion por escrito.
# =====================================================================

# ---------- Colores ----------
R=$'\e[31m'; G=$'\e[32m'; Y=$'\e[33m'; B=$'\e[34m'; C=$'\e[36m'; W=$'\e[1m'; N=$'\e[0m'

# Ctrl+C no cierra el menu (solo corta el comando en ejecucion)
trap '' INT

SUDO=""; [[ $EUID -ne 0 ]] && SUDO="sudo"
CAPDIR="$HOME/capturas"; mkdir -p "$CAPDIR"
EVE_JSON="/var/log/suricata/eve.json"
EVE_LOG="/tmp/netlab_evebox.log"
NESSUS_URL="https://localhost:8834"

# ---------- Interfaz y rango por defecto (autodeteccion) ----------
detectar_red() {
  IFACE=$(ip route show default 2>/dev/null | awk '/default/ {print $5; exit}')
  IFACE=${IFACE:-eth0}
  RANGO=$(ip -o -f inet addr show "$IFACE" 2>/dev/null | awk '{print $4; exit}')
  RANGO=${RANGO:-192.168.1.0/24}
  GATEWAY=$(ip route show default 2>/dev/null | awk '/default/ {print $3; exit}')
  GATEWAY=${GATEWAY:-192.168.1.1}
  MIIP=$(ip -o -f inet addr show "$IFACE" 2>/dev/null | awk '{print $4; exit}' | cut -d/ -f1)
  MIIP=${MIIP:-127.0.0.1}
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
  echo "${N}${B} Herramientas de REDES - Cisco Networking Academy${N}"
  echo " Interfaz: ${G}$IFACE${N}  Mi IP: ${G}$MIIP${N}  Rango: ${G}$RANGO${N}  Gateway: ${G}$GATEWAY${N}"
  echo "${R} Usalo solo en redes propias / de laboratorio / autorizadas.${N}"
  echo
}

tiene() { command -v "$1" >/dev/null 2>&1; }

# Marca roja [falta] junto a una opcion si la herramienta no esta instalada
mk() { tiene "$1" || printf '%s' "${R}[falta]${N}"; }

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

# Estado de servicios
tiene_unidad() { systemctl list-unit-files 2>/dev/null | grep -q "^$1"; }
suricata_activo() { systemctl is-active --quiet suricata 2>/dev/null || pgrep -x Suricata-Main >/dev/null 2>&1 || pgrep -x suricata >/dev/null 2>&1; }
evebox_activo()   { systemctl is-active --quiet evebox 2>/dev/null || pgrep -f "evebox server" >/dev/null 2>&1; }
nessus_instalado() { [[ -x /opt/nessus/sbin/nessusd ]] || tiene_unidad nessusd; }
nessus_activo()   { systemctl is-active --quiet nessusd 2>/dev/null; }
estado_txt() { "$1" && echo "${G}ENCENDIDO${N}" || echo "${R}APAGADO${N}"; }

# =====================================================================
#  1) DESCUBRIMIENTO DE HOSTS
# =====================================================================
menu_descubrimiento() {
  while true; do
    banner
    echo "${W}[1] DESCUBRIMIENTO - Quien esta conectado en la red${N}"
    echo
    echo "  1) nmap  - Ping sweep            (hosts vivos, sin escanear puertos) $(mk nmap)"
    echo "  2) nmap  - Descubrimiento ARP    (LAN, muy fiable)                   $(mk nmap)"
    echo "  3) nmap  - Solo listar/resolver  (no envia paquetes al objetivo)     $(mk nmap)"
    echo "  4) arp-scan - Escaneo ARP local  (rapido, muestra fabricante MAC)    $(mk arp-scan)"
    echo "  5) netdiscover - Activo          (ARP sobre un rango)                $(mk netdiscover)"
    echo "  6) netdiscover - Pasivo          (solo escucha, no genera trafico)   $(mk netdiscover)"
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
      Es silencioso, pero tarda mas en ver equipos.
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
Es ruidoso: Suricata lo detectara. Perfecto para ver alertas en EveBox!" "nmap -A -T4 $T" 1 ;;
      9) lanzar "Scripts por defecto" \
"-sC : ejecuta los scripts NSE de la categoria 'default' (banners, informacion
       SSL, SMB...). Seguros y utiles para empezar." "nmap -sC $T" 0 ;;
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
    echo "${W}[3] OBSERVACION - Captura y analisis de paquetes${N}"
    echo
    echo "  1) tcpdump - Ver trafico general        (50 paquetes) $(mk tcpdump)"
    echo "  2) tcpdump - Filtrar por host"
    echo "  3) tcpdump - Filtrar por puerto"
    echo "  4) tcpdump - Solo ICMP                  (ping)"
    echo "  5) tcpdump - Solo ARP"
    echo "  6) tcpdump - Solo DNS                   (puerto 53)"
    echo "  7) tcpdump - Guardar captura en .pcap"
    echo "  8) tcpdump - Leer un .pcap"
    echo "  9) Wireshark - Abrir interfaz grafica   $(mk wireshark)"
    echo " 10) tshark   - Captura en consola        $(mk tshark)"
    echo "  0) Volver"
    echo
    read -rp "${W}netlab/observacion> ${N}" op
    case $op in
      [1-8]) necesita tcpdump || continue ;;
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
#  4) MONITOREO DE ANCHO DE BANDA
# =====================================================================
menu_ancho() {
  while true; do
    banner
    echo "${W}[4] ANCHO DE BANDA - Quien consume y cuanto${N}"
    echo
    echo "  1) iftop  - Conexiones y consumo por host, en vivo   $(mk iftop)"
    echo "  2) nload  - Grafico de entrada/salida de la interfaz $(mk nload)"
    echo "  3) bmon   - Estadisticas por interfaz                $(mk bmon)"
    echo "  4) vnstat - Resumen de consumo acumulado             $(mk vnstat)"
    echo "  5) vnstat - Consumo en vivo                          $(mk vnstat)"
    echo "  6) vnstat - Consumo por hora / por dia               $(mk vnstat)"
    echo "  7) vnstat - Encender / apagar recoleccion de datos"
    echo "  0) Volver"
    echo
    read -rp "${W}netlab/ancho-de-banda> ${N}" op
    case $op in
      1) necesita iftop || continue; pedir I "Interfaz" "$IFACE" || { pausa; continue; }
         lanzar "iftop" \
"Muestra en vivo con quien habla tu equipo y cuanto trafico hay por conexion.
-i <if> : interfaz.
-n      : no resolver nombres.
-P      : muestra los puertos.
Teclas: 'q' sale, 'p' pausa, 'n' DNS on/off." "iftop -nP -i $I" 1 ;;
      2) necesita nload || continue; pedir I "Interfaz" "$IFACE" || { pausa; continue; }
         lanzar "nload" \
"Dibuja dos graficos (Incoming y Outgoing) con la velocidad actual, promedio,
minimo y maximo de la interfaz. Flechas izquierda/derecha cambian de interfaz.
'q' para salir." "nload $I" 0 ;;
      3) necesita bmon || continue; pedir I "Interfaz" "$IFACE" || { pausa; continue; }
         lanzar "bmon" \
"Monitor de ancho de banda con estadisticas por interfaz.
-p <if> : muestra solo esa interfaz.
Teclas: 'd' detalle, 'g' grafico, 'q' sale." "bmon -p $I" 0 ;;
      4) necesita vnstat || continue; pedir I "Interfaz" "$IFACE" || { pausa; continue; }
         lanzar "vnstat resumen" \
"vnstat guarda el consumo de red en una base de datos liviana.
-i <if> : interfaz. Muestra resumen de hoy, ayer, mes y total.
Si dice que no hay datos, usa la opcion 7 para encender la recoleccion." "vnstat -i $I" 0 ;;
      5) necesita vnstat || continue; pedir I "Interfaz" "$IFACE" || { pausa; continue; }
         lanzar "vnstat en vivo" \
"-l : modo 'live', muestra la velocidad actual (rx/tx) hasta que cortes con Ctrl+C
      y luego un resumen del tramo medido." "vnstat -l -i $I" 0 ;;
      6) necesita vnstat || continue; pedir I "Interfaz" "$IFACE" || { pausa; continue; }
         pedir M "Modo: h (por hora), d (por dia), m (por mes)" "h" || { pausa; continue; }
         [[ "$M" =~ ^[hdm]$ ]] || { echo "${R}Usa h, d o m${N}"; pausa; continue; }
         lanzar "vnstat historial" \
"-h : consumo por hora.   -d : por dia.   -m : por mes.
Necesita que la recoleccion este encendida un tiempo para tener datos." "vnstat -$M -i $I" 0 ;;
      7) necesita vnstat || continue
         if systemctl is-active --quiet vnstat 2>/dev/null; then
           lanzar "Apagar recoleccion vnstat" "Detiene el servicio vnstat (deja de acumular estadisticas)." "systemctl disable --now vnstat" 1
         else
           lanzar "Encender recoleccion vnstat" "Inicia el servicio vnstat para acumular consumo por hora/dia/mes. Es muy liviano." "systemctl enable --now vnstat" 1
         fi ;;
      0) return ;;
    esac
  done
}

# =====================================================================
#  5) RENDIMIENTO - iperf3
# =====================================================================
menu_iperf() {
  while true; do
    banner
    echo "${W}[5] RENDIMIENTO - iperf3 (medir velocidad entre dos equipos)${N}"
    echo
    echo "  Mi IP: ${G}$MIIP${N}   Puerto por defecto: 5201"
    echo
    echo "  1) Servidor                       (este equipo espera conexiones) $(mk iperf3)"
    echo "  2) Cliente TCP                    (mide subida hacia el servidor)"
    echo "  3) Cliente TCP inverso            (mide bajada desde el servidor)"
    echo "  4) Cliente UDP                    (perdida de paquetes y jitter)"
    echo "  5) Cliente con varias conexiones  (-P, satura mejor el enlace)"
    echo "  0) Volver"
    echo
    read -rp "${W}netlab/iperf3> ${N}" op
    [[ "$op" =~ ^[1-5]$ ]] && { necesita iperf3 || continue; }
    case $op in
      1) lanzar "iperf3 servidor" \
"-s : modo servidor. Queda escuchando en el puerto TCP/UDP 5201 hasta Ctrl+C.
En el OTRO equipo ejecuta el cliente apuntando a esta IP ($MIIP)." "iperf3 -s" 0 ;;
      2) pedir S "IP del servidor" "$GATEWAY" || { pausa; continue; }
         lanzar "iperf3 cliente TCP" \
"-c <ip> : modo cliente, se conecta al servidor.
-t 10    : prueba de 10 segundos.
Resultado en Mbits/sec: velocidad real de tu enlace (no la teorica)." "iperf3 -c $S -t 10" 0 ;;
      3) pedir S "IP del servidor" "$GATEWAY" || { pausa; continue; }
         lanzar "iperf3 cliente inverso" \
"-R : reverso. El servidor envia y tu recibes, asi mides la BAJADA." "iperf3 -c $S -t 10 -R" 0 ;;
      4) pedir S "IP del servidor" "$GATEWAY" || { pausa; continue; }
         pedir BW "Ancho de banda objetivo (ej 10M)" "10M" || { pausa; continue; }
         lanzar "iperf3 cliente UDP" \
"-u      : usa UDP en vez de TCP.
-b <bw>  : velocidad a enviar (ej 10M = 10 Mbit/s).
Muestra Jitter y % de paquetes perdidos: clave para VoIP y video." "iperf3 -c $S -u -b $BW -t 10" 0 ;;
      5) pedir S "IP del servidor" "$GATEWAY" || { pausa; continue; }
         lanzar "iperf3 varias conexiones" \
"-P 4 : 4 flujos en paralelo, aprovecha mejor enlaces rapidos o con latencia." "iperf3 -c $S -P 4 -t 10" 0 ;;
      0) return ;;
    esac
  done
}

# =====================================================================
#  6) DIAGNOSTICO DE CONECTIVIDAD
# =====================================================================
menu_diagnostico() {
  while true; do
    banner
    echo "${W}[6] DIAGNOSTICO - Conectividad y resolucion de problemas${N}"
    echo
    echo "  1) ping        - Conectividad basica        (capa 3, ICMP)"
    echo "  2) ping        - Probar MTU del camino      (sin fragmentar)"
    echo "  3) traceroute  - Ruta salto a salto         $(mk traceroute)"
    echo "  4) mtr         - traceroute + ping continuo $(mk mtr)"
    echo "  5) dig         - Consulta DNS               $(mk dig)"
    echo "  6) nc          - Probar si un puerto TCP responde $(mk nc)"
    echo "  7) whois       - Datos de una IP o dominio  $(mk whois)"
    echo "  8) ping al gateway (prueba rapida de LAN)"
    echo "  0) Volver"
    echo
    read -rp "${W}netlab/diagnostico> ${N}" op
    case $op in
      1) pedir T "Destino" "8.8.8.8" || { pausa; continue; }
         lanzar "ping" \
"-c 4 : envia 4 ICMP Echo Request y espera 4 Echo Reply.
Muestra tiempo (ms) y TTL. Perdida de paquetes = problema de conectividad." "ping -c 4 $T" 0 ;;
      2) pedir T "Destino" "8.8.8.8" || { pausa; continue; }
         pedir S "Tamano de datos (1472 + 28 de cabeceras = MTU 1500)" "1472" || { pausa; continue; }
         [[ "$S" =~ ^[0-9]+$ ]] || { echo "${R}Solo numeros${N}"; pausa; continue; }
         lanzar "ping con MTU" \
"-M do : prohibe fragmentar (bit DF activado).
-s <n> : tamano del payload. Con 1472 + 8 (ICMP) + 20 (IP) = 1500 bytes.
Si responde 'message too long', el MTU del camino es menor: baja el numero
hasta que pase y suma 28 para saber el MTU real." "ping -M do -s $S -c 4 $T" 0 ;;
      3) necesita traceroute || continue; pedir T "Destino" "8.8.8.8" || { pausa; continue; }
         lanzar "traceroute" \
"Envia paquetes con TTL creciente (1,2,3...). Cada router que descarta el paquete
responde 'TTL excedido' y asi se descubre cada salto del camino.
-n : sin resolver nombres (mas rapido)." "traceroute -n $T" 0 ;;
      4) necesita mtr "mtr-tiny" || continue; pedir T "Destino" "8.8.8.8" || { pausa; continue; }
         lanzar "mtr" \
"Combina ping + traceroute y mide perdida y latencia en cada salto.
-r : modo reporte (termina solo).   -n : sin DNS.   -c 10 : 10 ciclos." "mtr -rn -c 10 $T" 0 ;;
      5) necesita dig bind9-dnsutils || continue; pedir T "Dominio" "cisco.com" || { pausa; continue; }
         pedir Q "Tipo de registro (A, AAAA, MX, NS, TXT)" "A" || { pausa; continue; }
         lanzar "dig" \
"Consulta un servidor DNS. Tipos: A (IPv4), AAAA (IPv6), MX (correo), NS (servidores
de nombres), TXT. +short muestra solo la respuesta." "dig $T $Q +short" 0 ;;
      6) necesita nc netcat-openbsd || continue
         pedir T "Host/IP" "$GATEWAY" || { pausa; continue; }
         pedir P "Puerto" "80" || { pausa; continue; }
         lanzar "nc prueba de puerto" \
"-z      : solo comprueba si el puerto esta abierto, sin enviar datos.
-v      : muestra el resultado (succeeded / refused).
-w 3    : espera maximo 3 segundos.
'refused' = el host responde pero el puerto esta cerrado; 'timed out' = filtrado." \
         "nc -zv -w 3 $T $P" 0 ;;
      7) necesita whois || continue; pedir T "IP o dominio" "cisco.com" || { pausa; continue; }
         lanzar "whois" "Consulta a quien pertenece una IP o dominio (organizacion, rango, contacto)." "whois $T | head -n 40" 0 ;;
      8) lanzar "ping al gateway" \
"Prueba tu enlace con el router. Si falla, el problema es local (cable, Wi-Fi, IP, VLAN)." \
         "ping -c 4 $GATEWAY" 0 ;;
      0) return ;;
    esac
  done
}

# =====================================================================
#  7) LABORATORIO CISCO (consola, subnetting, SNMP, TFTP)
# =====================================================================
menu_lab() {
  while true; do
    banner
    echo "${W}[7] LABORATORIO CISCO - Consola, subnetting, SNMP, TFTP${N}"
    echo
    echo "  1) Ver puertos de consola USB/serie detectados"
    echo "  2) picocom  - Conectar por cable de consola a router/switch $(mk picocom)"
    echo "  3) sipcalc  - Calculadora de subredes (subnetting)          $(mk sipcalc)"
    echo "  4) sipcalc  - Dividir una red en subredes mas chicas"
    echo "  5) snmpget  - Leer el nombre (sysName) de un equipo         $(mk snmpget)"
    echo "  6) snmpwalk - Leer informacion del sistema de un equipo     $(mk snmpwalk)"
    echo "  7) TFTP     - Encender / apagar servidor (respaldos de config)"
    echo "  0) Volver"
    echo
    read -rp "${W}netlab/laboratorio> ${N}" op
    case $op in
      1) lanzar "Puertos serie" \
"Lista los dispositivos USB-serie. El cable de consola Cisco suele aparecer como
/dev/ttyUSB0 (adaptador FTDI/Prolific) o /dev/ttyACM0 (mini-USB nativo)." \
         "ls -l /dev/ttyUSB* /dev/ttyACM* 2>/dev/null || echo 'No hay cable de consola conectado'" 0 ;;
      2) necesita picocom || continue
         pedir D "Dispositivo" "/dev/ttyUSB0" || { pausa; continue; }
         pedir BR "Velocidad (baudios)" "9600" || { pausa; continue; }
         lanzar "picocom consola" \
"-b <baud> : velocidad en baudios. Cisco usa 9600, 8 bits, sin paridad, 1 stop (9600 8N1).
Para SALIR de picocom: Ctrl+A y luego Ctrl+X.
Presiona Enter tras conectar para ver el prompt (Router> o Switch>)." \
         "picocom -b $BR $D" 1 ;;
      3) necesita sipcalc || continue; pedir RD "Red/prefijo (ej 192.168.1.0/24)" "$RANGO" || { pausa; continue; }
         lanzar "sipcalc" \
"Calcula mascara, wildcard, direccion de red, broadcast, rango de hosts utiles y
cantidad de hosts. Ideal para practicar subnetting del curso." "sipcalc $RD" 0 ;;
      4) necesita sipcalc || continue
         pedir RD "Red/prefijo origen (ej 192.168.1.0/24)" "$RANGO" || { pausa; continue; }
         pedir NP "Nuevo prefijo (ej 26)" "26" || { pausa; continue; }
         [[ "$NP" =~ ^[0-9]{1,2}$ ]] || { echo "${R}Prefijo invalido${N}"; pausa; continue; }
         lanzar "sipcalc subredes" \
"-s <prefijo> : divide la red en subredes del nuevo prefijo y las lista
                (ejemplo: /24 con -s 26 -> 4 subredes de 62 hosts)." "sipcalc $RD -s $NP" 0 ;;
      5) necesita snmpget snmp || continue
         pedir T "IP del equipo" "$GATEWAY" || { pausa; continue; }
         pedir CM "Comunidad SNMP (solo laboratorio)" "public" || { pausa; continue; }
         lanzar "snmpget sysName" \
"-v2c      : version 2c de SNMP.
-c <com>   : comunidad (funciona como contrasena de lectura).
1.3.6.1.2.1.1.5.0 : OID de sysName, el nombre (hostname) del equipo.
En Cisco hay que habilitar SNMP: 'snmp-server community public RO'." \
         "snmpget -v2c -c $CM -t 2 -r 1 $T 1.3.6.1.2.1.1.5.0" 0 ;;
      6) necesita snmpwalk snmp || continue
         pedir T "IP del equipo" "$GATEWAY" || { pausa; continue; }
         pedir CM "Comunidad SNMP (solo laboratorio)" "public" || { pausa; continue; }
         lanzar "snmpwalk system" \
"snmpwalk recorre un arbol de OIDs. 1.3.6.1.2.1.1 es el grupo 'system':
descripcion del equipo (sysDescr), uptime, contacto, nombre y ubicacion." \
         "snmpwalk -v2c -c $CM -t 2 -r 1 $T 1.3.6.1.2.1.1" 0 ;;
      7) if ! tiene_unidad tftpd-hpa; then
           echo "${R}[!] tftpd-hpa no esta instalado.${N} Instalar: sudo apt install tftpd-hpa"; pausa; continue
         fi
         if systemctl is-active --quiet tftpd-hpa 2>/dev/null; then
           lanzar "Apagar TFTP" "Detiene el servidor TFTP (cierra el puerto UDP 69)." "systemctl stop tftpd-hpa" 1
         else
           lanzar "Encender TFTP" \
"Inicia el servidor TFTP (UDP 69). Carpeta por defecto: /srv/tftp.
Desde el router Cisco: 'copy running-config tftp:' y pones la IP de esta maquina.
Acordate de apagarlo al terminar." "systemctl start tftpd-hpa" 1
         fi ;;
      0) return ;;
    esac
  done
}

# =====================================================================
#  8) IDS: SURICATA + EVEBOX (encender / apagar)
# =====================================================================
alertas_recientes() {
  if ! tiene jq; then
    $SUDO tail -n 500 "$EVE_JSON" 2>/dev/null | grep '"event_type":"alert"' | tail -n 10
  else
    $SUDO tail -n 1000 "$EVE_JSON" 2>/dev/null | jq -c 'select(.event_type=="alert") | {hora:.timestamp, origen:.src_ip, destino:.dest_ip, alerta:.alert.signature}' | tail -n 10
  fi
  [[ ${PIPESTATUS[0]} -ne 0 ]] && echo "No se pudo leer $EVE_JSON (Suricata apagado o sin alertas)"
  return 0
}

menu_ids() {
  while true; do
    banner
    echo "${W}[8] DETECCION DE INTRUSOS - Suricata + EveBox${N}"
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
      7) necesita suricata-update "suricata" || continue
         lanzar "Actualizar reglas" \
"suricata-update descarga y activa los conjuntos de reglas (ET Open por defecto).
Sin reglas Suricata no genera alertas. Luego reinicia Suricata." "suricata-update" 1 ;;
      8) necesita suricata || continue
         lanzar "Probar configuracion" \
"-T         : modo test, valida la configuracion y las reglas y termina.
-c <yaml>   : archivo de configuracion." "suricata -T -c /etc/suricata/suricata.yaml" 1 ;;
      9) lanzar "Ultimas alertas" \
"Lee las ultimas lineas de eve.json (el log de eventos de Suricata) y muestra solo
las de tipo 'alert': hora, origen, destino y nombre de la regla.
Prueba: lanza un 'nmap -A' contra tu gateway y vuelve aca." "alertas_recientes" 0 ;;
      0) return ;;
    esac
  done
}

suricata_on() {
  necesita suricata || return
  if suricata_activo; then echo "${Y}Suricata ya esta encendido.${N}"; pausa; return; fi
  if nessus_activo; then
    echo "${Y}[!] Nessus esta encendido. Con 6 GB de RAM conviene apagarlo antes.${N}"
    read -rp "Encender Suricata igual? [s/N]: " r; [[ "$r" =~ ^[sS]$ ]] || return
  fi
  echo "${C}Encendiendo Suricata...${N}"
  if tiene_unidad suricata; then
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
  if tiene_unidad suricata; then
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
  if tiene_unidad evebox; then
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
  tiene_unidad evebox && $SUDO systemctl stop evebox
  $SUDO pkill -f "evebox server" 2>/dev/null
  sleep 1; echo "Estado: $(estado_txt evebox_activo)"; pausa
}

# =====================================================================
#  9) VULNERABILIDADES / AUDITORIA (Nessus + lynis)
# =====================================================================
menu_vuln() {
  while true; do
    banner
    echo "${W}[9] VULNERABILIDADES Y AUDITORIA - Nessus + lynis${N}"
    echo
    if nessus_instalado; then
      echo "  Nessus: $(estado_txt nessus_activo)    Panel: ${G}$NESSUS_URL${N}"
    else
      echo "  Nessus: ${R}no instalado${N}"
    fi
    echo
    echo "  1) Encender Nessus"
    echo "  2) Apagar Nessus"
    echo "  3) Abrir el panel web de Nessus en el navegador"
    echo "  4) Ver estado de Nessus"
    echo "  5) lynis - Auditar la seguridad de ESTE equipo   $(mk lynis)"
    echo "  0) Volver"
    echo
    echo "${Y}  Aviso: Nessus consume mucha RAM. Apaga Suricata/Wireshark antes de usarlo.${N}"
    echo "${Y}  Escanea solo equipos propios o de laboratorio.${N}"
    echo
    read -rp "${W}netlab/vulnerabilidades> ${N}" op
    case $op in
      1) nessus_instalado || { echo "${R}Nessus no esta instalado.${N}"; pausa; continue; }
         nessus_activo && { echo "${Y}Nessus ya esta encendido.${N}"; pausa; continue; }
         if suricata_activo; then
           echo "${Y}[!] Suricata esta encendido. Con 6 GB de RAM conviene apagarlo primero.${N}"
           read -rp "Encender Nessus igual? [s/N]: " r; [[ "$r" =~ ^[sS]$ ]] || continue
         fi
         lanzar "Encender Nessus" \
"Inicia el servicio nessusd. La primera vez compila plugins y tarda varios minutos
(en disco HDD mas). Cuando termine, entra a $NESSUS_URL (certificado propio: acepta la advertencia)." \
         "systemctl start nessusd" 1 ;;
      2) nessus_instalado || { echo "${R}Nessus no esta instalado.${N}"; pausa; continue; }
         lanzar "Apagar Nessus" "Detiene el servicio nessusd y libera la RAM que usa." "systemctl stop nessusd" 1 ;;
      3) lanzar "Abrir panel de Nessus" \
"Abre $NESSUS_URL en tu navegador. Tiene que estar encendido y haber terminado de
iniciar. El navegador mostrara una advertencia de certificado: es normal." \
         "nohup xdg-open $NESSUS_URL >/dev/null 2>&1 &" 0 ;;
      4) lanzar "Estado de Nessus" "Muestra si el servicio nessusd esta activo y sus ultimas lineas de log." \
         "systemctl status nessusd --no-pager | head -n 15" 0 ;;
      5) necesita lynis || continue
         lanzar "lynis audit system" \
"Audita la configuracion de seguridad de este equipo (red, servicios, SSH, kernel...).
Solo LEE, no cambia nada. Al final da un 'hardening index' y sugerencias.
Detalles en /var/log/lynis.log." "lynis audit system --quick" 1 ;;
      0) return ;;
    esac
  done
}

# =====================================================================
#  10) INFORMACION DE MI RED
# =====================================================================
menu_info() {
  while true; do
    banner
    echo "${W}[10] INFORMACION DE MI RED${N}"
    echo
    echo "  1) Interfaces e IPs      (ip -br addr)"
    echo "  2) Tabla de rutas        (ip route)"
    echo "  3) Tabla ARP / vecinos   (ip neigh)"
    echo "  4) Puertos en escucha    (ss -tulpn)"
    echo "  5) Conexiones activas    (ss -tn)"
    echo "  6) Velocidad y duplex    (ethtool)  $(mk ethtool)"
    echo "  7) DNS configurado       (/etc/resolv.conf)"
    echo "  0) Volver"
    echo
    read -rp "${W}netlab/info> ${N}" op
    case $op in
      1) lanzar "ip -br addr" "Resumen de interfaces: estado (UP/DOWN) y direcciones IPv4/IPv6 con mascara (CIDR)." "ip -br addr" 0 ;;
      2) lanzar "ip route" "Tabla de enrutamiento. La linea 'default via X' es tu gateway (puerta de enlace)." "ip route" 0 ;;
      3) lanzar "ip neigh" "Tabla ARP: relacion IP -> MAC de los equipos con los que hablaste (capa 2)." "ip neigh" 0 ;;
      4) lanzar "ss -tulpn" \
"-t TCP  -u UDP  -l solo en escucha  -p proceso dueno  -n numeros (sin resolver).
Muestra que servicios tiene abiertos TU maquina." "ss -tulpn" 1 ;;
      5) lanzar "ss -tn" "Conexiones TCP establecidas ahora mismo (origen y destino)." "ss -tn" 0 ;;
      6) necesita ethtool || continue; pedir I "Interfaz" "$IFACE" || { pausa; continue; }
         lanzar "ethtool" \
"Muestra la negociacion del enlace fisico: Speed (10/100/1000 Mb/s), Duplex (Half/Full)
y si hay link detectado. Un duplex mismatch causa errores y lentitud (tema de CCNA).
En Wi-Fi puede no mostrar datos." "ethtool $I" 1 ;;
      7) lanzar "DNS" "Servidores DNS que usa este equipo para resolver nombres." "cat /etc/resolv.conf" 0 ;;
      0) return ;;
    esac
  done
}

# =====================================================================
#  11) ESTADO DE HERRAMIENTAS
# =====================================================================
menu_estado() {
  banner
  echo "${W}[11] HERRAMIENTAS INSTALADAS${N}"
  echo
  local t faltan=0
  for t in nmap arp-scan netdiscover tcpdump wireshark tshark iftop nload bmon vnstat iperf3 \
           mtr traceroute dig nc whois picocom sipcalc snmpget snmpwalk ethtool jq suricata \
           suricata-update evebox lynis; do
    if tiene "$t"; then printf "  %-16s ${G}instalado${N}\n" "$t"
    else printf "  %-16s ${R}falta${N}\n" "$t"; faltan=$((faltan+1)); fi
  done
  if nessus_instalado; then printf "  %-16s ${G}instalado${N}\n" "nessus"; else printf "  %-16s ${R}falta${N}\n" "nessus"; fi
  if tiene_unidad tftpd-hpa; then printf "  %-16s ${G}instalado${N}\n" "tftpd-hpa"; else printf "  %-16s ${Y}opcional (no instalado)${N}\n" "tftpd-hpa"; fi
  echo
  echo "  Suricata: $(estado_txt suricata_activo)   EveBox: $(estado_txt evebox_activo)   Nessus: $(estado_txt nessus_activo)"
  echo
  if [[ $faltan -gt 0 ]]; then
    echo "  Paquetes para lo que falte:"
    echo "  sudo apt install mtr-tiny iperf3 iftop nload bmon vnstat bind9-dnsutils arp-scan"
    echo "                   netdiscover traceroute netcat-openbsd picocom sipcalc snmp jq"
  fi
  pausa
}

# =====================================================================
#  12) CAMBIAR INTERFAZ / RANGO
# =====================================================================
menu_config() {
  banner
  echo "${W}[12] CONFIGURAR INTERFAZ Y RANGO${N}"
  echo "  Interfaces disponibles:"; ip -br link | awk '{print "   - "$1" ("$2")"}'
  echo
  pedir IFACE "Interfaz" "$IFACE" || { pausa; return; }
  RANGO=$(ip -o -f inet addr show "$IFACE" 2>/dev/null | awk '{print $4; exit}'); RANGO=${RANGO:-192.168.1.0/24}
  MIIP=$(echo "$RANGO" | cut -d/ -f1)
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
  echo "   1) Descubrimiento        ${B}(nmap, arp-scan, netdiscover)${N}"
  echo "   2) Escaneo de puertos    ${B}(nmap: -sS, -sV, -O, -A ...)${N}"
  echo "   3) Observacion / captura ${B}(tcpdump, wireshark, tshark)${N}"
  echo "   4) Ancho de banda        ${B}(iftop, nload, bmon, vnstat)${N}"
  echo "   5) Rendimiento           ${B}(iperf3 servidor / cliente)${N}"
  echo "   6) Diagnostico           ${B}(ping, traceroute, mtr, dig, nc)${N}"
  echo "   7) Laboratorio Cisco     ${B}(consola, subnetting, SNMP, TFTP)${N}"
  echo "   8) Deteccion de intrusos ${B}(suricata + evebox: encender/apagar)${N}"
  echo "   9) Vulnerabilidades      ${B}(nessus encender/apagar, lynis)${N}"
  echo "  10) Informacion de mi red ${B}(ip, ss, arp, ethtool)${N}"
  echo "  11) Herramientas instaladas / estado"
  echo "  12) Configurar interfaz y rango"
  echo "   0) Salir"
  echo
  read -rp "${W}netlab> ${N}" op
  case $op in
    1) menu_descubrimiento ;;
    2) menu_puertos ;;
    3) menu_captura ;;
    4) menu_ancho ;;
    5) menu_iperf ;;
    6) menu_diagnostico ;;
    7) menu_lab ;;
    8) menu_ids ;;
    9) menu_vuln ;;
    10) menu_info ;;
    11) menu_estado ;;
    12) menu_config ;;
    0|q|Q) echo "Hasta luego!"; exit 0 ;;
  esac
done

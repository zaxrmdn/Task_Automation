#!/bin/bash
#Author: Zakaria
#Sysadmin toolkit adalah aio tool untuk sysadmin.

LOG="/var/log/sysadmin-toolkit.log"

#############################################
# BASIC UTILITIES
#############################################

log(){
 echo "[$(date '+%F %T')] $1" | tee -a $LOG
}

pause(){
 echo
 read -p "Tekan Enter untuk kembali ke menu..."
}

check_root(){
 if [ "$EUID" -ne 0 ]; then
   echo "Script harus dijalankan sebagai root!"
   exit 1
 fi
}

status(){
 if [ $? -eq 0 ]; then
   echo "[OK]"
 else
   echo "[FAILED]"
 fi
}

#############################################
# MENU FUNCTIONS
#############################################

update_system(){
 echo "Update semua package + security patch"
 echo "---------------------------------------"
 apt update && apt upgrade -y && apt autoremove -y && apt autoclean -y
 log "System update dijalankan"
}

backup_data(){
 echo "Backup direktori penting server"
 echo "---------------------------------------"
 SRC="/var/www"
 DEST="/backup"
 DATE=$(date +%F_%H%M)
 FILE="$DEST/backup-$DATE.tar.gz"

 mkdir -p $DEST
 tar -czf $FILE $SRC
 status
 log "Backup dibuat $FILE"

 echo "Menghapus backup >7 hari"
 find $DEST -type f -mtime +7 -delete
}

audit_users(){
 echo "Audit keamanan user system"
 echo "---------------------------------------"

 echo "[Login terakhir]"
 lastlog | tail

 echo
 echo "[User sudo]"
 getent group sudo

 echo
 echo "[User tanpa password]"
 awk -F: '($2==""){print $1}' /etc/shadow

 log "User audit dijalankan"
}

clean_logs(){
 echo "Membersihkan log besar & cache"
 echo "---------------------------------------"

 echo "Truncate log >50MB"
 find /var/log -type f -name "*.log" -size +50M -exec truncate -s 0 {} \;

 echo "Vacuum journal 7 hari"
 journalctl --vacuum-time=7d

 echo "Clean apt cache"
 apt clean

 log "Log cleanup selesai"
}

monitor_services(){

# ambil semua nama service
SERVICES_LIST=$(systemctl list-unit-files --type=service --no-legend | awk '{print $1}' | sed 's/.service//')

# fungsi autocomplete
_service_autocomplete() {
 local cur=${COMP_WORDS[COMP_CWORD]}
 COMPREPLY=( $(compgen -W "$SERVICES_LIST" -- "$cur") )
}

complete -F _service_autocomplete servicecheck

servicecheck() {

 read -e -p "Masukkan nama service: " input

 for svc in $input
 do
   printf "%-20s : " "$svc"

   if systemctl list-unit-files | grep -q "^$svc.service"; then

     if systemctl is-active --quiet "$svc"; then
        echo "RUNNING"
     else
        echo "DOWN → restart"
        systemctl restart "$svc"

        if systemctl is-active --quiet "$svc"; then
           echo "   Restart berhasil"
        else
           echo "   Restart gagal"
        fi
     fi

   else
     echo "SERVICE TIDAK ADA"
   fi
 done
}

servicecheck
}
security_hardening(){

 echo "Hardening basic security server"
 echo "---------------------------------------"

 echo "Disable root SSH login"
 sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config

 echo "Disable password login"
 sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config

 systemctl reload ssh

 echo "Setup firewall"
 apt install ufw -y >/dev/null
 ufw default deny incoming >/dev/null
 ufw default allow outgoing >/dev/null
 ufw allow ssh >/dev/null
 ufw --force enable >/dev/null

 log "Security hardening selesai"
}

system_info(){

 echo "Informasi sistem server"
 echo "---------------------------------------"

 echo "Hostname   : $(hostname)"
 echo "Uptime     : $(uptime -p)"
 echo "Kernel     : $(uname -r)"
 echo "IP Address : $(hostname -I | awk '{print $1}')"

 echo
 echo "Load Average"
 uptime

 echo
 echo "Disk Usage"
 df -h

 echo
 echo "Memory Usage"
 free -h

 log "System info dilihat"
}

disk_alert(){

 THRESHOLD=80

 echo "Cek disk usage > $THRESHOLD%"
 echo "---------------------------------------"

 df -h | awk '{print $5 " " $1}' | while read output;
 do
   use=$(echo $output | awk '{print $1}' | sed 's/%//g')
   part=$(echo $output | awk '{print $2}')

   if [ $use -ge $THRESHOLD ]; then
      echo "WARNING: $part $use% penuh"
      log "Disk warning $part $use%"
   fi
 done
}

process_monitor(){
 echo "Top 10 proses penggunaan CPU"
 echo "---------------------------------------"
 ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%cpu | head
}

#############################################
# MAIN MENU
#############################################

check_root

while true
do
 clear

 echo "======================================="
 echo "        SYSADMIN TOOLKIT by ZAKARIA"
 echo "======================================="
 echo "1. Update System        → Patch & upgrade package"
 echo "2. Backup Server        → Backup data penting"
 echo "3. Audit Users          → Cek user & privilege"
 echo "4. Clean Logs           → Bersihkan log besar"
 echo "5. Monitor Services     → Cek service critical"
 echo "6. Security Hardening   → Basic server security"
 echo "7. System Info          → Info resource server"
 echo "8. Disk Usage Alert     → Warning disk penuh"
 echo "9. Process Monitor      → Top proses CPU"
 echo "0. Exit"
 echo "======================================="

 read -p "Pilih menu: " opt

 case $opt in
 1) update_system; pause ;;
 2) backup_data; pause ;;
 3) audit_users; pause ;;
 4) clean_logs; pause ;;
 5) monitor_services; pause ;;
 6) security_hardening; pause ;;
 7) system_info; pause ;;
 8) disk_alert; pause ;;
 9) process_monitor; pause ;;
 0) exit ;;
 *) echo "Pilihan tidak valid"; sleep 1 ;;
 esac

done
~
~

#!/bin/bash
# >>> DO NOT USE THIS FILE ON UBUNTU. USE /ARCHIVED/ INSTEAD. THIS FILE HAS BEEN ADJUSTED FOR MANJARO LINUX. <<<

echo "____________________________________________"
echo "           INSTALL SERVER TOOLS             "
echo "                                            "
echo "____________________________________________"

echo "         Docker and Docker Compose          "
echo "--------------------------------------------"
# Install Docker and Docker Compose
sudo pacman -S --noconfirm docker docker-compose

# Create non-root user for docker, with privileges (not docker rootless)
sudo groupadd docker
sudo usermod -aG docker ${USER}

# Enable docker at boot
sudo systemctl enable docker.service
sudo systemctl enable containerd.service

# Add default location of compose file (/home/username/docker/compose.yml) for bash and zsh
echo export COMPOSE_FILE="/home/${USER}/docker/compose.yml" >> /home/${USER}/.bash_profile
sudo touch /etc/zsh/zshenv
sudo sh -c "echo export COMPOSE_FILE="/home/${USER}/docker/compose.yml" >> /etc/zsh/zshenv"

echo "            Wireguard VPN Tools             "
echo "--------------------------------------------"
# If you used the post-install script, this should already be installed
sudo pacman -S --noconfirm wireguard-tools

echo "                   BTRBK                    "
echo "--------------------------------------------"
echo "Swiss handknife-like tool to automate snapshots & backups of personal data" 
# available in the Arch User Repository (AUR) thus installed via Pamac. Will be automatically updated just like official repository packages. 
sudo pacman -S --noconfirm btrbk
sudo pacman -S --noconfirm mbuffer

echo "        RUN-IF-TODAY & ENABLE CRON          "
echo "--------------------------------------------"
echo "simplify scheduling of weekly/monthly tasks"
sudo wget -O /usr/bin/run-if-today https://raw.githubusercontent.com/xr09/cron-last-sunday/master/run-if-today
sudo chmod +x /usr/bin/run-if-today
echo "enable cron service" 
systemctl enable --now cronie.service

echo "                   NOCACHE                  "
echo "--------------------------------------------"
echo "handy when moving lots of files at once in the background, without filling up cache and slowing down the system."
# available in the Arch User Repository (AUR) thus installed via Pamac. Will be automatically updated just like official repository packages. 
sudo pacman -S --noconfirm nocache

echo "                    GRSYNC                  "
echo "--------------------------------------------"
echo "Friendly UI for rsync. Not installed"

echo "                  LM_SENSORS                "
echo "--------------------------------------------"
echo "to be able to read out all sensors" 
sudo pacman -S --noconfirm lm_sensors
sudo sensors-detect --auto

echo "          S.M.A.R.T. monitoring             "
echo "--------------------------------------------"
echo "to be able to read SMART values of drives. Not intalled" 

echo "                 HD PARM                    "
echo "--------------------------------------------"
echo "to be able to configure drive parameters" 
sudo pacman -S --noconfirm hdparm

echo "                 MERGERFS                  "
echo "-------------------------------------------"
echo "pool drives to make them appear as 1 without raid"
# available in the Arch User Repository (AUR) thus installed via Pamac. Will be automatically updated just like official repository packages. 
sudo pacman -S --noconfirm mergerfs


echo "______________________________________________________"
echo "                     SYSTEM CONFIG                    "
echo "______________________________________________________"

echo "      limit log filesize      "  
echo "------------------------------"
# this prevents docker container volumes to be falsely recognized as host system OS and added to boot menu. See https://wiki.archlinux.org/title/GRUB#Detecting_other_operating_systems
sudo sed -i -e "s^#SystemMaxUse=^SystemMaxUse=50M^g" /etc/systemd/journald.conf

echo "      disable os-prober       "  
echo "------------------------------"
# this prevents docker container volumes to be falsely recognized as host system OS and added to boot menu. See https://wiki.archlinux.org/title/GRUB#Detecting_other_operating_systems
sudo sed -i -e "s^GRUB_DISABLE_OS_PROBER=false^GRUB_DISABLE_OS_PROBER=true^g" /etc/default/grub
# apply change
sudo grub-mkconfig

echo "      enable sysRq key        "  
echo "------------------------------"
# If the OS ever freezes completely, Linux allows you to use your keyboard to perform a graceful reboot or power-off, through combination of keys.
# This prevents any kind of filesystem damage or drive hardware damage, especially on HDDs.
# The following enables the key combination.
echo kernel.sysrq=1 | sudo tee --append /etc/sysctl.d/99-sysctl.conf
# How to actually perform the key combination will be explained in the guide. For now see here: https://forum.manjaro.org/t/howto-reboot-turn-off-your-frozen-computer-reisub-reisuo/3855

echo " add user env var for cron    "  
echo "------------------------------"
# Cronjobs are used to schedule maintenance tasks for backups, system cleanup and drive maintenance. These tasks require root. Root cronjob is used.
# FileRun also has maintenance tasks and scheduled notifications. Filerun or any other service should never be run as root, otherwise no FileRun user can delete folders (because items like thumbnails can be created and owned by root)
# Linux wants you to run each cronjob in different crontabs per user. However for a homeserver a single overview of cronjobs would be preferred.
# To run the FileRun commands as the regular user, we add an env variable for that user to the only env that is accessible by root cronjobs: 
sudo sh -c "echo LOGUSER=${USER} >> /etc/environment"

echo " Add useful items to App Menu (Ignored)"
echo "---------------------------------------"

echo "  Add filemanager bookmarks (Ignored)"
echo "-------------------------------------"

echo "  Optimise power consumption  "
echo "------------------------------"
# Always run Powertop autotune at boot
sudo tee -a /etc/systemd/system/powertop.service << EOF
[Unit]
Description=Powertop tunings

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/powertop --auto-tune

[Install]
WantedBy=multi-user.target
EOF
## Enable the service
sudo systemctl daemon-reload
sudo systemctl enable powertop.service
## Tune system now
sudo powertop --auto-tune
## Start the service
sudo systemctl start powertop.service

# Disable automatic suspend
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'


echo "Disable Arch/Manjaro own DNS resolve settings"
echo "------------------------------" 
# Required to run a DNS server like Adguard Home and Unbound
sudo rm /etc/resolv.conf
sudo tee -a /etc/resolv.conf << EOF
nameserver ::1
nameserver 127.0.0.1
options trust-ad
EOF
sudo tee -a /etc/NetworkManager/conf.d/90-dns-none.conf << EOF
[main]
dns=none
EOF
systemctl reload NetworkManager


echo "    Auto-restart VPN server   "
echo "------------------------------" 
# Automatically restart Wireguard VPN server when the wireguard config file is modified (by VPN-Portal webUI)
# Monitor the wireguard config file for changes
sudo tee -a /etc/systemd/system/wgui.path << EOF
[Unit]
Description=Watch /etc/wireguard/wg0.conf for changes

[Path]
PathModified=/etc/wireguard/wg0.conf

[Install]
WantedBy=multi-user.target
EOF
# Restart wireguard service automatically
sudo tee -a /etc/systemd/system/wgui.service << EOF
[Unit]
Description=Restart WireGuard
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/systemctl restart wg-quick@wg0.service

[Install]
RequiredBy=wgui.path
EOF
# Apply these services
systemctl enable --now wgui.{path,service}


echo "    EMAIL NOTIFICATIONS       "
echo "------------------------------"
# allow system to send email notifications - Configure smtp according to Arch wiki
sudo pacman -S --noconfirm msmtp
sudo pacman -S --noconfirm s-nail
# link sendmail to msmtp
sudo ln -s /usr/bin/msmtp /usr/bin/sendmail
sudo ln -s /usr/bin/msmtp /usr/sbin/sendmail
# set msmtp as mta
echo "set mta=/usr/bin/msmtp" | sudo tee -a /etc/mail.rc
echo ">>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<"
echo "                                                             "
echo "To receive important server notifications, please enter your main/default emailaddress that should receive notifications:"
echo "                                                             "
read -p 'Enter email address to receive server notifications:' DEFAULTEMAIL
sudo sh -c "echo default:$DEFAULTEMAIL >> /etc/aliases"
## Get config file
sudo tee -a /etc/msmtprc &>/dev/null << EOF
# Set default values for all following accounts.
defaults
auth           on
tls            on
#tls_trust_file /etc/ssl/certs/ca-certificates.crt
#logfile        $HOME/docker/HOST/logs/msmtp.log
aliases        /etc/aliases

# smtp provider
account        default
host           mail.smtp2go.com
port           587
from           FROMADDRESS
user           SMTPUSER
password       SMTPPASS
EOF
# set SMTP server
echo "  ADD SMTP CREDENTIALS FOR EMAIL NOTIFICATIONS  "
echo ">>>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<"
echo "                                                            "
echo "Would you like to configure sending email now? You need to have an smtp provider account correctly configured with your domain" 
read -p "Have you done that and do you have your smtp credentials at hand? (y/n)" answer
case ${answer:0:1} in
    y|Y )
    read -p "Enter SMTP server address (or hit ENTER for default: mail.smtp2go.com):" SMTPSERVER
    SMTPSERVER="${SMTPSERVER:=mail.smtp2go.com}"
    read -p "Enter SMTP server port (or hit ENTER for default:587):" SMTPPORT
    SMTPPORT="${SMTPPORT:=587}"
    read -p 'Enter SMTP username: ' SMTPUSER
    read -p 'Enter password: ' SMTPPASS
    read -p 'Enter the from emailaddress that will be shown as sender, for example username@yourdomain.com: ' FROMADDRESS
    sudo sed -i -e "s#mail.smtp2go.com#$SMTPSERVER#g" /etc/msmtprc
    sudo sed -i -e "s#587#$SMTPPORT#g" /etc/msmtprc
    sudo sed -i -e "s#SMTPUSER#$SMTPUSER#g" /etc/msmtprc
    sudo sed -i -e "s#SMTPPASS#$SMTPPASS#g" /etc/msmtprc
    sudo sed -i -e "s#FROMADDRESS#$FROMADDRESS#g" /etc/msmtprc
    echo "Done, now sending you a test email...." 
    printf "Subject: Your Homeserver is almost ready\nHello there, I am almost ready. I can sent you emails now." | msmtp -a default $DEFAULTEMAIL
    echo "Email sent!" 
    echo "if an error appeared above, the email has not been sent and you made an error or did not configure your domain and smtp provider" 
    ;;
    * )
        echo "Not configuring SMTP. Please manually enter your SMTP provider details in file /etc/msmprc.." 
    ;;
esac


echo "  on-demand btrfs root mount (Ignored)"
echo "--------------------------------------"

echo "        Docker subvolume       "
echo "-------------------------------"
# create subvolume for Docker persistent data
# Temporarily Mount filesystem root
sudo mount /mnt/drives/system
# create a root subvolume for docker
sudo btrfs subvolume create /mnt/drives/system/@docker
## unmount root filesystem
sudo umount /mnt/drives/system
# Create mountpoint, to be used by fstab
mkdir $HOME/docker
# Get system fs UUID, to be used for next command
fs_uuid=$(findmnt / -o UUID -n)
# Add @docker subvolume to fstab to mount on mountpoint at boot
sudo tee -a /etc/fstab &>/dev/null << EOF

# Mount @docker subvolume
UUID=${fs_uuid} $HOME/docker  btrfs   subvol=@docker,defaults,noatime,x-gvfs-hide,compress-force=zstd:1  0  0
EOF
sudo mount -a
sudo chown ${USER}:${USER} $HOME/docker
sudo chmod -R 755 $HOME/docker
#sudo setfacl -Rdm g:docker:rwx $HOME/docker

echo "Create the minimum folder structure for drives and datapool"
echo "--------------------------------------------"
sudo mkdir /mnt/drives/{data0,data1}
sudo mkdir /mnt/drives/backup1
sudo mkdir -p /mnt/pool/


echo "______________________________________________________________________"
echo "                                                                      " 
echo " GET THE homeserver guide DOCKER COMPOSE FILE and MAINTENANCE SCRIPTS "
echo "______________________________________________________________________"
cd $HOME/Downloads
echo "         compose yml and env file           "
echo "--------------------------------------------"
wget -O $HOME/docker/.env https://raw.githubusercontent.com/zilexa/Homeserver/master/docker/.env
wget -O $HOME/docker/docker-compose.yml https://raw.githubusercontent.com/zilexa/Homeserver/master/docker/docker-compose.yml

echo "      BTRBK config and mail script          "
echo "--------------------------------------------"
mkdir -p $HOME/docker/HOST/btrbk
wget -O $HOME/docker/HOST/btrbk/btrbk.conf https://raw.githubusercontent.com/zilexa/Homeserver/master/docker/HOST/btrbk/btrbk.conf
wget -O $HOME/docker/HOST/btrbk/btrbk-mail.sh https://raw.githubusercontent.com/zilexa/Homeserver/master/docker/HOST/btrbk/btrbk-mail.sh
sudo ln -s $HOME/docker/HOST/btrbk/btrbk.conf /etc/btrbk/btrbk.conf
# MANUALLY configure the $HOME/docker/HOST/btrbk/btrbk.conf to your needs

echo "                 archiver                   "
echo "--------------------------------------------"
mkdir -p $HOME/docker/HOST/archiver
wget -O $HOME/docker/HOST/archiver/archiver.sh https://raw.githubusercontent.com/zilexa/Homeserver/master/docker/HOST/archiver/archiver.sh
wget -O $HOME/docker/HOST/archiver/archiver_exclude.txt https://github.com/zilexa/Homeserver/blob/master/docker/HOST/archiver/archiver_exclude.txt


echo "______________________________________________________"
echo "           OPTIONAL TOOLS OR CONFIGURATIONS           "
echo "______________________________________________________"
echo "--------------------------------------------------------------------------------------------------------------"

echo "Ignored all"

echo "                                                                               "        
echo "==============================================================================="
echo "                                                                               "  
echo "  All done! Please reboot and do not use sudo for docker or compose commands.  "
echo "                                                                               "  
echo "==============================================================================="

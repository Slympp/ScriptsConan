#!/bin/sh

# Script made by Slymp for Akylonia.net
# Join us on discord.gg/7zbWQzU

ScriptVersion=1
RED='\033[0;31m'
NC='\033[0m'

# /Path/To/Folder
user=steam
ConanPath=/home/$user/ConanServer
SteamCmdPath=/home/$user/steamcmd
SteamPath=/home/$user/Steam

IP="37.59.45.211"
Server_Name="[EU/FR] Akylonia.net | XP x2 | NoRules | Wipe 17.02"

# Leaves "" if you don't want to use a password
Server_Password=""

function conan_start {

echo "Starting server..."

isServerDown=$(ps axf | grep ConanSandboxServer-Win64-Test.exe | grep -v grep)

if [ -z "$isServerDown" ]; then
	screen -dmS conan bash -c 'wine "$ConanPath/ConanSandboxServer.exe" "ConanSandbox?MULTIHOME=$IP?listen?" -log -ServerName=$Server_Name -ServerPassword=$Server_Password'
	echo "[V] Server is now up"
	echo "Use \"conan screen\" to watch logs"
else
	echo "[X] Server is already up, no restart required"
fi
}

function conan_stop {

pid=$(ps axf | grep ConanSandboxServer-Win64-Test.exe | grep -v grep | awk '{print $1}')

if [ -z "$pid" ]; then
	echo "[X] There's no server to stop"
else
        # send rcon msg in game and sleep X mn when rcon support will be available
        echo "[V] Existing PIDs: $pid"
	exec kill -SIGINT $pid

        cpt=15
        while [ $cpt -gt 0 ]; do
                echo "Shutting down... $cpt"
                sleep 1
                let cpt=cpt-1
        done
        echo "[V] Server is now shutdown"
fi
}

function conan_update {

echo "Deleting appcache..."
rm -rf $SteamPath/appcache/

# Pull new info and compare new timestamp to saved timestamp
# You may need to initially run the command for currentTimestamp manually and redirect it to /home/steam/exiles/lastUpdate
echo "Checking for last update..."
currentTimestamp=$($SteamCmdPath/steamcmd.sh +login anonymous +app_info_update 1 +app_info_print 443030 +quit | grep -EA 1000 "^\s+\"branches\"$" | grep -EA 5 "^\s+\"public\"$" | grep -m 1 -EB 10 "^\s+}" | grep -E "^\s+\"timeupdated\"\s+" | tr '[:blank:]"' ' ' | awk '{print $2}')
lastTimestamp=$(cat $ConanPath/lastUpdate)

if [ $currentTimestamp -gt $lastTimestamp ]; then
	echo "[V] New update found"
        stop
	echo "Deleting appcache..."
	rm -rf $SteamPath/appcache/
	$SteamCmdPath/steamcmd.sh +@sSteamCmdForcePlatformType windows +force_install_dir $ConanPath +login anonymous +app_update 443030 validate +quit

	echo "[V] Update finished"
        echo "$currentTimestamp" > $ConanPath/lastUpdate

	start
else
        echo "[X] No update found"
fi
}

function conan_show {

exec screen -ls
}

function conan_screen {

exec screen -r $1
}


# TODO: check if files are valides
function conan_validate {
echo "Not implemented yet"
}

function conan_install {

echo "Starting installation."
echo -e "${RED}THIS PART NEED ROOT ACCESS${NC}\n"

echo -e "${RED}Creating user...${NC}"
if [ -n "$user" ]; then
	echo "[?] Please enter a name for your Conan Exiles user. You can provide an existing user"
	read user
fi

while [ -z "$(getent passwd $user)" ]; do
	sudo adduser $user
	if [ -z "$(getent passwd $user)"]; then
		echo -e "${RED}Creation failed, try again${NC}\n"
	fi
done

echo -e "${RED}User \"$user\" found...${NC}\n"

echo -e "${RED}[SKIP] Setting up iptables...${NC}\n"
#TODO: Move la gestion du port dans le script

#iptables -t filter -I INPUT -p udp --dport 7777 -j ACCEPT
#iptables -t filter -I INPUT -p udp --dport 7778 -j ACCEPT
#iptables -t filter -I INPUT -p udp --dport 27015 -j ACCEPT

echo -e "${RED}Installing screen...\n${NC}"
sudo apt-get install screen

echo -e "${RED}\nUpdating repository...${NC}"
#TODO: decommente all
#sudo add-apt-repository ppa:ricotz/unstable
#sudo apt remove wine wine1.8 wine-stable libwine* fonts-wine* && sudo apt autoremove
#sudo apt update

echo -e "${RED}\nInstalling wine2.0...${NC}"
sudo apt install wine2.0

dpkg-query -l wine2.0
if [ $? -eq 1 ]; then
	echo -e "${RED}\n[ERROR] Wine2.0 is not installed, server may not work.${NC}"
	sleep 2
fi

echo -e "${RED}\nInstalling SteamCMD...${NC}"
if [ -n "$SteamCmdPath" ]; then
	echo "[?] Please enter /path/for/steamCMD (i.e. \"/home/steam/steamcmd\"). You can provide an existing linux version of SteamCMD"
	read SteamCmdPath
fi

if  [ ! -f "$SteamCmdPath/steamcmd.sh" ]; then
	echo -e "\n$SteamCmdPath seems not to exist." 
	read -r -p "Do you want to install SteamCMD ? [y/N] " response
	case "$response" in
    	[yY][eE][sS]|[yY]) 
			su -c "mkdir -p $SteamCmdPath" -m $user
			echo -e "${RED}\nDownloading SteamCMD...${NC}"
        	sudo runuser -l $user -c 'cd /home/steam/steamcmd/ && wget https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz && tar -xvzf steamcmd_linux.tar.gz && rm -rf steamcmd_linux.tar.gz'
       		;;

       	*)
			echo -e "${RED}Exiting installation...${NC}"
			exit 1
			;;
	esac		
fi

echo -e "\n${RED}Downloading lastest version of Conan Exiles Server...${NC}"
su -c "$SteamCmdPath/steamcmd.sh +@sSteamCmdForcePlatformType windows +force_install_dir $ConanPath +login anonymous +app_update 443030 validate +quit" -m $user

echo -e "\nYour Conan Exiles server is now fully installed. You can use ${RED}\"conan start\"${NC} to run it"
}

function conan_crontab {

	echo -e "[?] Do you want to add crontabs in order to automate restarts and Steam updates ? [y/N]"
	read -n wantCrontab

	# TODO: don't work
	echo -e "${RED}DEBUG> wantCrontab: $wantCrontab ${NC}\n"
	if [ "$wantCrontab" -eq "N" ]
	then
		exit 1
	else
		echo -e "Enable ${RED}auto-restart${NC} ? (checks if there's no server running and start if needed). Enter a number of minutes between checks (0 to disable)"
		read -n restartTime

		# TODO: check format
		if [ ! -n "$restartTime" ]; then
			restartTime=5
			echo -e "Invalid value. Set${RED} $restartTime ${NC}mn by default"
		fi

		if [ ! "$restartTime" -eq 0 ]; then
			echo -e "${RED}Crontab:${NC} */$restartTime * * * * conan start"
			(crontab -l ; echo "*/$restartTime * * * * conan start") | sort - | uniq - | crontab -
		fi

		echo -e "Enable ${RED}auto-updater${NC} ? (checks for update and if needed, apply and restart server). Enter a number of minutes between checks (0 to disable)"
		read -n updateTime

		# TODO: check format
		if [ ! -n "$updateTime" ]; then
			updateTime=10
			echo -e "Invalid value. Set${RED} $updateTime ${NC}mn by default"
		fi

		if [ ! "$updateTime" -eq 0 ]; then
			echo -e "${RED}Crontab:${NC} */$updateTime * * * * conan update"
			(crontab -l ; echo "*/$updateTime * * * * conan update") | sort - | uniq - | crontab -
	    fi
fi
}

function indent { sed -e 's/^/\t/'; }

function conan_help {

echo "Script with tools for running a Conan Exiles server on Linux"
echo "Made for Ubuntu 16.04, by Slymp (http://akylonia.net)"

echo ""

echo "Available commands:"
echo -e "start\t\t: Starts server. Checks for servers already running" | indent
echo -e "stop\t\t: Stops safely servers by sending a SIGINT" | indent
echo -e "update\t\t: Apply a pending update. Closes and restarts the servers properly" | indent
echo -e "show\t\t: Display running servers and their id" | indent
echo -e "screen [id]\t: Display console. Use ${RED}\"Ctrl + A D\"${NC} to quit the screen without stopping the server" | indent
echo ""
echo -e "[!] Be careful, ${RED}leaving a screen with Ctrl + C force your server to crash without saving${NC}, which can heavily corrupt your database\n" | indent
}

case "$1" in
    start) conan_start ;;
    stop) conan_stop ;;
    update) conan_update ;;
    show) conan_show ;;
    screen) conan_screen ;;
    help) conan_help ;;
    install) conan_install ;;
    crontab) conan_crontab ;;
    validate) conan_validate ;;

    *) echo "Command not found: \"$1\": use \"conan help\" to get more informations"
esac
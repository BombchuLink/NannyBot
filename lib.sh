# shellcheck shell=bash
# Shared setup for every NannyBot script. Source it after setting NannyBotDir:
#   NannyBotDir=${NannyBotDir:-$(dirname "$(readlink -f "$0")")}
#   . "$NannyBotDir/lib.sh"

VERSION=1.0
export NannyBotDir

#read "Key = value" from config.ini
cfg() {
	awk -F'[[:space:]]*=[[:space:]]*' -v k="$1" '
		$1 == k { sub(/[[:space:]]+$/, "", $2); print $2; exit }
	' "$NannyBotDir/config.ini"
}

UName=$(cfg Uname)
BName=$(cfg Bname)
Mtime=$(cfg Mtime)
Vtime=$(cfg Vtime)
icondir="$NannyBotDir/icons/$BName"

#runtime state lives in XDG_RUNTIME_DIR so it's wiped on logout/reboot and can't go stale
state="${XDG_RUNTIME_DIR:-/tmp/nannybot-$UID}/nannybot"
pidfile="$state/pid"
mkdir -p -m 700 "$state"

bot_running() {
	[[ -f $pidfile ]] && kill -0 "$(<"$pidfile")" 2>/dev/null
}

# notify ICON MESSAGE [TIMEOUT_MS]
notify() {
	local icon="$icondir/notify_$1.png"
	[[ -f $icon ]] || icon="$icondir/notify_default.png"
	notify-send --icon="$icon" -t "${3:-30000}" -- "$2"
}

# menu [PROMPT] - reads options on stdin, prints the chosen one
# set NANNYBOT_MENU to use something other than dmenu, e.g. "rofi -dmenu -i"
menu() {
	local -a cmd
	read -ra cmd <<<"${NANNYBOT_MENU:-dmenu -i -l 30}"
	if [[ -n $1 ]]; then
		"${cmd[@]}" -p "$1"
	else
		"${cmd[@]}"
	fi
}

minute_of_day() {
	local h m
	read -r h m <<<"$(date '+%H %M')"
	echo $(( 10#$h * 60 + 10#$m ))
}

# nap SECONDS - interruptible sleep: signal traps run immediately instead of after sleep exits
nap() {
	sleep "$1" &
	_nap=$!
	wait "$_nap"
}

# deliver ICON REST [INTRO]
# REST is either "message text" or *P promptname
# messages starting with $ skip the intro, %Name is replaced with the user's name
deliver() {
	local icon=$1 rest=$2 intro=$3 msg prompt ask tag='%Name'
	if [[ $rest == '*P'* ]]; then
		read -r _ prompt _ <<<"$rest"
		ask="$NannyBotDir/prompts/${prompt}_prompt_ask"
		if [[ -x $ask ]]; then
			"$ask"
		else
			notify dizzy "Ummmm, I couldn't find the '$prompt' prompt you asked me to ask"
		fi
		return
	fi
	if [[ $rest != *\"*\"* ]]; then
		notify dizzy "Ummmm, for some reason I couldn't queue this message for you

[Error 1 - NULL message]"
		return
	fi
	msg=${rest#*\"}
	msg=${msg%\"*}
	if [[ $msg == '$'* ]]; then
		msg=${msg#\$}
	elif [[ -n $intro ]]; then
		msg="$intro $msg"
	fi
	notify "$icon" "${msg//"$tag"/$UName}"
}

#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$CURRENT_DIR/helpers.sh"

short=false

get_remain_settings() {
	short=$(get_tmux_option "@batt_remain_short" false)
}

battery_discharging() {
	local status="$(battery_status)"
	[[ $status =~ (discharging) ]]
}

battery_charged() {
	local status="$(battery_status)"
	[[ $status =~ (charged) ]]
}


convertmins() {
	((h=${1}/60))
	((m=${1}%60))
	printf "%02d:%02d\n" $h $m $s
}

apm_battery_remaining_time() {
	local remaining_time="$(convertmins $(apm -m))"
	if battery_discharging; then
		if $short; then
			echo $remaining_time | awk '{printf "~%s", $1}'
		else
			echo $remaining_time | awk '{printf "- %s left", $1}'
		fi
	elif battery_charged; then
		if $short; then
			echo $remaining_time | awk '{printf "charged", $1}'
		else
			echo $remaining_time | awk '{printf "fully charged", $1}'
		fi
	else
		echo "charging"
	fi
}

pmset_battery_remaining_time() {
	local status="$(pmset -g batt)"
	if echo $status | grep 'no estimate' >/dev/null 2>&1; then
		if $short; then
			echo '~?:??'
		else
			echo '- Calculating estimate...'
		fi
	else
		local remaining_time="$(echo $status | grep -o '[0-9]\{1,2\}:[0-9]\{1,2\}')"
		if battery_discharging; then
			if $short; then
				echo $remaining_time | awk '{printf "~%s", $1}'
			else
				echo $remaining_time | awk '{printf "- %s left", $1}'
			fi
		elif battery_charged; then
			if $short; then
				echo $remaining_time | awk '{printf "charged", $1}'
			else
				echo $remaining_time | awk '{printf "fully charged", $1}'
			fi
		else
			if $short; then
				echo $remaining_time | awk '{printf "~%s", $1}'
			else
				echo $remaining_time | awk '{printf "- %s till full", $1}'
			fi
		fi
	fi
}

upower_battery_remaining_time() {
	battery=$(upower -e | grep -E 'battery|DisplayDevice'| tail -n1)
	if battery_discharging; then
		local remaining_time=$(upower -i "$battery" | grep -E '(remain|time to empty)' | awk '{print $(NF-1)}')
        local hours=$(echo $remaining_time | cut -d. -f1)
        local decimal=$(echo $remaining_time | cut -d. -f2)
        local minutes=$(printf "%02d" $(echo "scale=0;.${decimal} * 60 / 1" | bc))

        echo "${hours}:${minutes}"
        if !$short; then
			echo " left"
		fi
	elif battery_charged; then
		if $short; then
			echo ""
		else
			echo "charged"
		fi
	else
		local remaining_time=$(upower -i "$battery" | grep -E 'time to full' | awk '{print $(NF-1)}')
        local hours=$(echo $remaining_time | cut -d. -f1)
        local decimal=$(echo $remaining_time | cut -d. -f2)
        local minutes=$(printf "%02d" $(echo "scale=0;.${decimal} * 60 / 1" | bc))

        echo -n "${hours}:${minutes}"
        if !$short; then
			echo " to full"
		fi
	fi
}

acpi_battery_remaining_time() {
	acpi -b | grep -m 1 -Eo "[0-9]+:[0-9]+:[0-9]+"
}

print_battery_remain() {
	if command_exists "pmset"; then
		pmset_battery_remaining_time
	elif command_exists "acpi"; then
		acpi_battery_remaining_time
	elif command_exists "upower"; then
		upower_battery_remaining_time
	elif command_exists "apm"; then
		apm_battery_remaining_time
	fi
}

main() {
	get_remain_settings
	print_battery_remain
}
main

#!/bin/sh

# shellcheck disable=SC2059
# shellcheck shell=bash

access_external() {

	if [[ $(uname -s) = Dar* ]]; then

		storage=$(/bin/sh -c "find /Volumes/*KOBO* -maxdepth 0" 2>/dev/null | sort -r | head -1)

	elif [[ $(uname -s) = Lin* ]]; then

		storage=$(/bin/sh -c "find /media/*KOBO* -maxdepth 0" 2>/dev/null | sort -r | head -1)

	fi

	echo "$storage"

}

ensure_accuracy() {

	failure="\r\033[91m%s\033[00m\n\n"

	if [[ $(uname -s) != Dar* && $(uname -s) != Lin* ]]; then

		printf "$failure" "THE ACTUAL SYSTEM IS NOT SUPPORTED." && exit 1

	elif [[ ! -d $(access_external) ]]; then

		printf "$failure" "THE SCRIPT DID NOT FIND THE DEVICE." && exit 1

	elif [[ -z $(command -v curl) || -z $(command -v jq) || -z $(command -v sqlite3) ]]; then

		printf "$failure" "THE DEPENDENCIES ARE NOT INSTALLED." && exit 1

	fi

}

remove_unwanted() {

	storage=$(access_external)

	if [[ -d $storage ]]; then

		rm -fr "$storage/.kobo-images"
		rm -fr "$storage/.Spotlight-V100"
		rm -fr "$storage/.Trashes"
		rm -fr "$storage/System Volume Information"

	fi

}

update_database() {

	storage="$(access_external)/.kobo/KoboReader.sqlite"

	if [[ -f $storage ]]; then

		factors=(

			"00000000-0000-0000-0000-000000000000"
			"00000000-0000-0000-0000-000000000000"
			"MyDummyUser@dummy.com"
			"MyDummyUser@dummy.com"
			"000011"

		)

		content=$(printf ",'%s'" "${factors[@]}" | cut -c2-)

		echo "INSERT INTO user values ($content);" | sqlite3 "$storage" 2>/dev/null

	fi

}

update_firmware() {

	factors=(

		"https://kfwproxy.geek1011.net/api.kobobooks.com?h=1&x=1.0"
		"UpgradeCheck"
		"Device"
		"00000000-0000-0000-0000-000000000360"
		"kobo"
		"0.0"
		"N0"

	)

	address=$(printf "%%2F%s" "${factors[@]}" | cut -c4-)
	address=$(curl -Ls "$address" | jq -r ".[0].body" | jq -r ".UpgradeURL")
	archive=$(mktemp -d)/$(basename "$address")

	curl -Ls "$address" -o "$archive"
	unzip -q "$archive" -d "$(access_external)/.kobo" 2>/dev/null

}

update_koreader() {

	tempdir=$(mktemp -d)

	address="https://www.mobileread.com/forums/showpost.php?p=3797095&postcount=1"
	pattern="href=\"\K(http(.*)OCP-KOReader(.*).zip)(?=\")"
	address=$(curl -Ls "$address" | ggrep -oP "$pattern" | head -1)
	archive=$tempdir/$(basename "$address")

	curl -Ls "$address" -o "$archive"

	if [[ $(uname -s) = Dar* ]]; then

		content=$(curl -Ls "https://www.mobileread.com/forums/showpost.php?p=3797096&postcount=2")
		pattern="href=\"\K(http(.*)kfm_mac_install.zip)(?=\")"
		address=$(echo "$content" | ggrep -oP "$pattern" | head -1)
		archive=$tempdir/$(basename "$address")

		curl -Ls "$address" -o "$archive"
		unzip -q "$archive" -d "$tempdir"
		chmod +x "$tempdir/install.command" && echo 0 | "$tempdir/install.command" &>/dev/null

	elif [[ $(uname -s) = Lin* ]]; then

		content=$(curl -Ls "https://www.mobileread.com/forums/showpost.php?p=3797096&postcount=2")
		pattern="href=\"\K(http(.*)kfm_nix_install.zip)(?=\")"
		address=$(echo "$content" | grep -oP "$pattern" | head -1)
		archive=$tempdir/$(basename "$address")

		curl -Ls "$address" -o "$archive"
		unzip -q "$archive" -d "$tempdir"
		chmod +x "$tempdir/install.sh" && echo 0 | "$tempdir/install.sh" &>/dev/null

	fi

}

main() {

	clear

	read -r -d "" welcome <<-EOD

		██╗░░██╗██╗░░░██╗██████╗░██████╗░░█████╗░████████╗░█████╗░██████╗░
		██║░██╔╝██║░░░██║██╔══██╗██╔══██╗██╔══██╗╚══██╔══╝██╔══██╗██╔══██╗
		█████═╝░██║░░░██║██████╔╝██║░░██║███████║░░░██║░░░██║░░██║██████╔╝
		██╔═██╗░██║░░░██║██╔═══╝░██║░░██║██╔══██║░░░██║░░░██║░░██║██╔══██╗
		██║░╚██╗╚██████╔╝██║░░░░░██████╔╝██║░░██║░░░██║░░░╚█████╔╝██║░░██║
		╚═╝░░╚═╝░╚═════╝░╚═╝░░░░░╚═════╝░╚═╝░░╚═╝░░░╚═╝░░░░╚════╝░╚═╝░░╚═╝

	EOD

	printf "\n\033[92m%s\033[00m\n\n" "$welcome"
	printf "\033]0;%s\007" "kupdator"

	ensure_accuracy

	printf "\r\033[93m%s\033[00m" "LOADING, DO NOT UNPLUG YOUR DEVICE."

	update_database
	update_firmware
	update_koreader
	remove_unwanted

	printf "\r\033[92m%s\033[00m\n\n" "SUCCESS, YOU CAN EJECT AND UNPLUG THE DEVICE."

}

main

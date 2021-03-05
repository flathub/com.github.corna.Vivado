#/bin/bash

if [ -z "$XILINX_INSTALL_PATH" ]; then
	XILINX_INSTALL_PATH="$XDG_DATA_HOME/xilinx"
fi

function xilinx_detect() {
	installed_versions=( $(find "$XILINX_INSTALL_PATH" -mindepth 2 -maxdepth 2 -type d -regex ".*/[0-9\.]+" -exec basename {} \; | sort | uniq) )
}

function xilinx_detect_xsetup() {
	installed_versions=( $(find "$XILINX_INSTALL_PATH/.xinstall" -mindepth 2 -maxdepth 2 -type f -name xsetup -exec sh -c 'basename "$(dirname {})"' \; | sort) )
}

function xilinx_choose_version() {
	if [ "${#installed_versions[@]}" -eq "0" ]; then
		zenity --width=400 --question --title "Missing software" --text "Xilinx Vivado Design Suite is not installed. Do you want to install it now?" && xilinx_install
		xilinx_detect
		chosen_version=${installed_versions[0]}
	elif [ "${#installed_versions[@]}" -eq "1" ]; then
		chosen_version=${installed_versions[0]}
	else
		zenity_versions=()
		for version in "${installed_versions[@]}"; do
			zenity_versions+=(FALSE $version)
		done
		zenity_versions[0]=TRUE
		chosen_version=$(zenity --list --title "Xilinx Vivado Design Suite version" --text "Which version do you want to use?" --radiolist --column "Pick" --column "Version" ${zenity_versions[@]})
	fi
}

function xilinx_install() {
	zenity --width=600 --info --title "Xilinx installer required" --text "Please download the Xilinx Unified installer and select it in the next window."

	# Launch the browser
	xdg-open 'https://www.xilinx.com/support/download.html'

	# Get the installer path
	installer_path=$(zenity --file-selection --title "Select the Xilinx installer (Xilinx_Unified_*_Lin64.bin)")

	zenity --width=600 --warning --text "The Xilinx installer will now start. Make sure to select $XILINX_INSTALL_PATH as installation path."
	mkdir -p "$XILINX_INSTALL_PATH"

	# Run the installer
	sh "$installer_path"

	xilinx_detect
	zenity --width=600 --info --text "Installation is complete.\nTo allow access to the hardware devices (necessary to program them within Vivado and Vitis), run <b>sudo $XILINX_INSTALL_PATH/Vivado/${installed_versions[0]}/data/xicom/cable_drivers/lin64/install_script/install_drivers/install_drivers &amp;&amp; sudo udevadm control --reload</b>, then reconnect all the devices (if any)"
}

function xilinx_source_settings64() {
	version_escaped_dot=${1/./\\.}

	settings64_dir=$(mktemp -d)

	# Fix the paths in .settings64*.sh (so that the installation can be freely moved)
	find "$XILINX_INSTALL_PATH" -maxdepth 3 -regextype posix-egrep -regex ".*/($version_escaped_dot|DocNav)/\.settings64[^/]*\.sh" -exec cp {} "$settings64_dir" \;
	find "$settings64_dir" -type f -exec sed -i -E "s@=.*/(Vivado|Vitis|DocNav)@=$XILINX_INSTALL_PATH/\1@g" {} \;

	# Replace the absolute paths in Vivado/*/settings64.sh with relative ones
	sed "s|source .*/.settings64|source $settings64_dir/.settings64|g" "$XILINX_INSTALL_PATH/Vivado/$1/settings64.sh" > "$settings64_dir/settings64.sh"

	. "$settings64_dir/settings64.sh"
	rm -rf "$settings64_dir"
}

function xilinx_versioned_install_if_needed_then_run() {
	command="$1"
	shift

	xilinx_detect
	xilinx_choose_version
	xilinx_source_settings64 "$chosen_version"

	which $command > /dev/null && "$command" "$@" || zenity --width=400 --error --title "Missing software" --text "$command $chosen_version is not installed, please run the installation wizard to install it."
}

function xilinx_install_if_needed_then_run() {
	command="$1"
	shift

	xilinx_detect
	chosen_version=${installed_versions[0]}
	xilinx_source_settings64 "$chosen_version"

	which $command > /dev/null && "$command" "$@" || zenity --width=400 --error --title "Missing software" --text "$command is not installed, please run the installation wizard to install it."
}

function xilinx_xsetup_install_if_needed_then_run() {
	xilinx_detect_xsetup
	xilinx_choose_version
	export PATH=$XILINX_INSTALL_PATH/.xinstall/$chosen_version:$PATH

	xsetup "$@"
}
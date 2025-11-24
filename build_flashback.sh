#!/usr/bin/env zsh

# ANSI color codes
PURPLE='\033[0;35m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# This gets the location that the script is being run from and moves there.
SCRIPT_DIR=${0:a:h}
cd "$SCRIPT_DIR"

set_variables() {
	ARCH="$(uname -m)"
	CORES=$(sysctl -n hw.ncpu)
	GAME_ID="fb"
	GAME_TITLE="Flashback"
	PKGINFO_TITLE="REFB"
	ICON_URL='https://parsefiles.back4app.com/JPaQcFfEEQ1ePBxbf6wvzkPMEqKYHhPYv8boI1Rc/8c32f68ab013e726114d9b81949e19df_Super_Metroid.icns'
	APP_SUPP=~/Library/Application\ Support/
}

introduction() {
	echo "\n${PURPLE}This script is for compiling ${GREEN}REminiscence${PURPLE} for ${GREEN}Apple Silicon${NC} ${PURPLE}or ${GREEN}Intel${NC} Macs\n"
	
	echo "${GREEN}Homebrew${PURPLE} and the ${GREEN}Xcode command-line tools${PURPLE} are required${NC}"
	echo "${PURPLE}If they are not present you will be prompted to install them${NC}\n"
}

homebrew_check() {
	if ! command -v brew &> /dev/null; then
		echo "${PURPLE}Homebrew not found. Installing Homebrew...${NC}"
		/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
		if [[ "${ARCH_NAME}" == "arm64" ]]; then 
			(echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> $HOME/.zprofile
			eval "$(/opt/homebrew/bin/brew shellenv)"
		else 
			(echo; echo 'eval "$(/usr/local/bin/brew shellenv)"') >> $HOME/.zprofile
			eval "$(/usr/local/bin/brew shellenv)"
		fi
		
		# Check for errors
		if [ $? -ne 0 ]; then
			echo "${RED}There was an issue installing Homebrew${NC}"
			echo "${PURPLE}Quitting script...${NC}"	
			exit 1
		fi
	else
		echo  "${PURPLE}Homebrew found. Updating Homebrew...${NC}"
		brew update
	fi
}

# Function for checking for an individual dependency
single_dependency_check() {
	if [ -d "$(brew --prefix)/opt/$1" ]; then
		echo "${GREEN}Found $1. Checking for updates...${NC}"
			brew upgrade $1
	else
		 echo "${PURPLE}Did not find $1. Installing...${NC}"
		brew install $1
	fi
}

dependencies_check() {
	echo "${PURPLE}Checking for native Homebrew dependencies...${NC}"
	# Required native Homebrew packages
	deps=( libmodplug sdl2 zlib )
	
	for dep in $deps[@]
	do 
		single_dependency_check $dep
	done
}

clone_repo() { 
	echo "${PURPLE}Cloning REminiscence Repository...${NC}"
	rm -rf REminiscence
	git clone https://github.com/chermenin/REminiscence.git
	cd REminiscence
	git pull origin master
}

# This is only required as long as compilation fails with Modplug
fix_build() {
	sed -i '' 's/-DUSE_MODPLUG//' ./makefile
}

build() {
	fix_build
	make -j$CORES
	
	# Check whether the build was successful
	if [ $? -ne 0 ]; then
		echo "\n${RED}Building failed${NC}\n"
		exit 1
	fi 
	
	mv fb ..
	cd ..
	rm -rf REminiscence
}

bundle() {
	echo "${PURPLE}Creating app bundle structure...${NC}"
	rm -rf "${GAME_TITLE}.app"
	mkdir -p "${GAME_TITLE}.app/Contents/Resources"
	mkdir -p "${GAME_TITLE}.app/Contents/MacOS"
	
	echo "${PURPLE}Checking data folders...${NC}"
	if [ ! -d "$APP_SUPP/REminiscence/DATA" ]; then
		mkdir -p "$APP_SUPP/REminiscence/DATA"
	fi
	
	if [ ! -d "$APP_SUPP/REminiscence/SAVE" ]; then
		mkdir -p "$APP_SUPP/REminiscence/SAVE"
	fi
	
	if [ ! -d "$APP_SUPP/REminiscence/TUNES" ]; then
		mkdir -p "$APP_SUPP/REminiscence/TUNES"
	fi
	
	if [ $? -ne 0 ]; then
		echo "\n${RED}Error creating app bundle failed${NC}\n"
		exit 1
	fi 
	
	echo "${PURPLE}Moving files...${NC}"
	mv fb "${GAME_TITLE}.app/Contents/MacOS"
	ln -s "$APP_SUPP/REminiscence/DATA" "${GAME_TITLE}.app/Contents/MacOS"
	ln -s "$APP_SUPP/REminiscence/SAVE" "${GAME_TITLE}.app/Contents/MacOS"
	ln -s "$APP_SUPP/REminiscence/TUNES" "${GAME_TITLE}.app/Contents/MacOS"
	
	# create Info.plist
	echo "${PURPLE}Creating properties list file...${NC}"
	
	PLIST="<?xml version=\"1.0\" encoding=\"UTF-8\"?>
	<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
	<plist version=\"1.0\">
	<dict>
		<key>CFBundleDevelopmentRegion</key>
		<string>English</string>
		<key>CFBundleGetInfoString</key>
		<string>${GAME_TITLE}</string>
		<key>CFBundleExecutable</key>
		<string>launch_${GAME_ID}.sh</string>
		<key>CFBundleIconFile</key>
		<string>${GAME_ID}.icns</string>
		<key>CFBundleIdentifier</key>
		<string>com.github.chermenin.REminiscence</string>
		<key>CFBundleInfoDictionaryVersion</key>
		<string>6.0</string>
		<key>CFBundleName</key>
		<string>${GAME_TITLE}</string>
		<key>CFBundlePackageType</key>
		<string>APPL</string>
		<key>CFBundleSupportedPlatforms</key>
		<array>
			<string>MacOSX</string>
		</array>
		<key>LSArchitecturePriority</key>
		<array>
			<string>arm64</string>
		</array>
		<key>CFBundleShortVersionString</key>
		<string>1.0</string>
		<key>LSMinimumSystemVersion</key>
		<string>11.0</string>
		<key>NSPrincipalClass</key>
		<string>NSApplication</string>
		<key>NSHumanReadableCopyright</key>
		<string>Delphine Software</string>
		<key>NSHighResolutionCapable</key>
		<true/>
		<key>LSApplicationCategoryType</key>
		<string>public.app-category.games</string>
	</dict>
	</plist>
	"
	echo "${PLIST}" > "${GAME_TITLE}.app/Contents/Info.plist"
	
	# Create PkgInfo
	echo "${PURPLE}Creating PkgInfo file...${NC}"
	PKGINFO="-n APPL${PKGINFO_TITLE}"
	echo "${PKGINFO}" > "${GAME_TITLE}.app/Contents/PkgInfo"
	
	# Create launch script (Launching the executable directly doesn't work for some reason) and set executable permissions
	echo "${PURPLE}Creating launcher script...${NC}"
	LAUNCHER="#!/usr/bin/env zsh
	
	SCRIPT_DIR=\${0:a:h}
	cd "\$SCRIPT_DIR"
	
	./${GAME_ID}"
	echo "${LAUNCHER}" > "${GAME_TITLE}.app/Contents/MacOS/launch_${GAME_ID}.sh"
	chmod +x "${GAME_TITLE}.app/Contents/MacOS/launch_${GAME_ID}.sh"
	
	# Check for a 1024x png file to make an icon out of
	echo "${PURPLE}Checking for png file to make icon from...${NC}"
	echo "${PURPLE}File should be named ${GREEN}${GAME_ID}.png${NC}"
	if [[ -a ${GAME_ID}.png ]]; then 
		# Create icon if there is a file called ${GAME_ID}.png in the build folder
		echo "${PURPLE}Found image file. Creating icon...${NC}"
		
		mkdir ${GAME_ID}.iconset
		sips -z 16 16     ${GAME_ID}.png --out ${GAME_ID}.iconset/icon_16x16.png
		sips -z 32 32     ${GAME_ID}.png --out ${GAME_ID}.iconset/icon_16x16@2x.png
		sips -z 128 128   ${GAME_ID}.png --out ${GAME_ID}.iconset/icon_128x128.png
		sips -z 256 256   ${GAME_ID}.png --out ${GAME_ID}.iconset/icon_128x128@2x.png
		sips -z 512 512   ${GAME_ID}.png --out ${GAME_ID}.iconset/icon_512x512.png
		cp ${GAME_ID}.png ${GAME_ID}.iconset/icon_512x512@2x.png
		iconutil -c icns ${GAME_ID}.iconset
		rm -R ${GAME_ID}.iconset
		cp -R ${GAME_ID}.icns "${GAME_TITLE}.app/Contents/Resources/"
		rm -rf ${GAME_ID}.icns
	else 
		# Otherwise get an icon from macosicons.com
		echo "${PURPLE}No png file found. Downloading icon from ${GREEN}macosicons.com...${NC}"
		curl -o ${GAME_TITLE}.app/Contents/Resources/${GAME_ID}.icns $ICON_URL
	fi
	
	# Bundle dependencies
	echo "${PURPLE}Bundling dependencies...${NC}"
	dylibbundler -of -cd -b -x  ${GAME_TITLE}.app/Contents/MacOS/${GAME_ID} -d ${GAME_TITLE}.app/Contents/Frameworks -p @executable_path/../Frameworks/
	
}

main_menu() {
	set_variables
	introduction
	PS3='What would you like to do? '
	OPTIONS=(
		"Build"
		"Build with Homebrew checks"
		"Quit")
	select opt in $OPTIONS[@]
	do
		case $opt in
			"Build")
				echo "\n${RED}Skipping Homebrew checks${NC}"
				echo "${PURPLE}The script will fail if any of the dependencies are missing${NC}\n"
				clone_repo
				continue_menu
				build
				bundle
				break
				;;
			"Build with Homebrew checks")
				homebrew_check
				dependencies_check
				clone_repo
				continue_menu
				build
				bundle
				break
				;;
			"Quit")
				echo "${RED}Quitting${NC}"
				exit 0
				;;
			*) 
				echo "\"$REPLY\" is not one of the options..."
				echo "Enter the number of the option and press enter to select"
				;;
		esac
	done
}

continue_menu() {
	echo "\n${PURPLE}Ready to build${NC}"
	echo "${PURPLE}You can modify the code now before building${NC}\n"
	PS3='Would you like to continue building? '
	OPTIONS=(
		"Continue"
		"Checkout Commit"
		"Checkout Pull Request"
		"Quit")
	select opt in $OPTIONS[@]
	do
		case $opt in
			"Continue")
				break
				;;
			"Checkout Commit")
				checkout_commit_menu
				break
				;;
			"Checkout Pull Request")
				checkout_pr_menu
				break
				;;
			"Quit")
				echo "${PURPLE}Quitting${NC}"
				exit 0
				;;
			*) 
				echo "\"$REPLY\" is not one of the options..."
				echo "Enter the number of the option and press enter to select"
				;;
		esac
	done
}

checkout_commit_menu() {
	echo "\n${PURPLE}What commit would you like to checkout?${NC}"
	commit_hash=$(printf '%s' 'Commit Hash: ' >&2; read x && printf '%s' "$x")
	git checkout "$commit_hash"
	if [ $? -ne 0 ]; then
		echo "\n${RED}Could not find the specified commit${NC}\n"
		continue_menu
	fi 
}

checkout_pr_menu() {
	echo "\n${PURPLE}What pull request would you like to checkout?${NC}"
	pr_id=$(printf '%s' 'Pull Request ID: ' >&2; read x && printf '%s' "$x")
	branch_name=$(printf '%s' 'New Branch Name: ' >&2; read x && printf '%s' "$x")
	git fetch origin pull/$pr_id/head:$branch_name
	if [ $? -ne 0 ]; then
		echo "\n${RED}Could not find the specified pull request${NC}\n"
		continue_menu
	fi 
	git switch $branch_name
}

main_menu

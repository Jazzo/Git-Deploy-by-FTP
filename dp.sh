#!/bin/bash

#### FUNCTIONS ####
function usage {
	echo "usage: dp.sh -p <project-name> -d <commit-sha> [--not-simulate]"
	echo "\t -p, --project  \tThe name of the project to deploy (look at the configuration file)"
	echo "\t -d, --deploy   \tThe commit you want to deploy"
	echo "\t --not-simulate \tReally deploy, it will not simulate!"
    echo "\t --no-colors    \tDisable colors layout"
}

######### Start script ########
echo "Production deployment script (ver. 0.2)"

if [ "$1" == "" ]; then
    usage
	exit 1
fi

# Check parameters and Set defaults
SIMULATION=0
USE_COLOR=1
while [ "$1" != "" ]; do
    case $1 in
        -p | --project )
							shift
							PROJECT_NAME=$1
							;;
        -d | --deploy )
							shift
							DEPLOY_SELECTED=$1
							;;
        --not-simulate )
							SIMULATION=1
							;;
        --no-colors )
							USE_COLOR=0
							;;
        -h | --help )
							usage
							exit;;
        * )
							usage
							exit 1
    esac
    shift
done

# SET Script Directory (so you can call it from anywhere)
BASEDIR=$(dirname $0)
cd $BASEDIR

# Check NO-COLORS parameter (disable colors)
if [ "$USE_COLOR" == 0 ]
then
    COLOR_ALERT=""
    COLOR_ERROR=""
    COLOR_MSG=""
    COLOR_RESET=""
    COLOR_LOG=""
else

#### COLOR SETTINGS ####
    COLOR_ALERT=$(tput setaf 5) # Fuchsia
    COLOR_ERROR=$(tput setaf 1) # Red
    COLOR_MSG=$(tput setaf 7)   # White
    COLOR_LOG=$(tput setaf 3)   # Yellow
    COLOR_RESET=$(tput sgr0)    # Reset any color
fi

# Simulation alert
if [ "$SIMULATION" == 0 ]
then
echo $COLOR_ALERT"** SIMULATION MODE ENABLED **"
fi

# Check if the config file selected EXISTS and include it
if [[ -z "$PROJECT_NAME" ]]
then
	echo $COLOR_ERROR"Please, select a project name to use the correct config file!"
	exit 0
else
	if [ -f .dp-config-$PROJECT_NAME ]
	then
		source .dp-config-$PROJECT_NAME
	else
		echo $COLOR_ERROR"The config file '.dp-config-$PROJECT_NAME' does NOT EXISTS!"
		exit 0
	fi
fi

# Check if Deploy commit EXISTS
cd $PROJECT_REPO_DIR
C_DEPLOY=`git rev-list $DEPLOY_SELECTED | head -n 1`
if [[ -z "$C_DEPLOY" ]]
then
	echo $COLOR_ERROR"The commit '$DEPLOY_SELECTED' does NOT EXISTS in the repo: \n$PROJECT_REPO_DIR!"
	exit 0
else
	echo $COLOR_MSG"Commit to deploy: $C_DEPLOY"
fi

# Check production tag
echo "Check for '$PRODUCTION_TAG_NAME' tag..."
C_PRODUCTION=`git rev-list $PRODUCTION_TAG_NAME | head -n 1`
if [[ -z "$C_PRODUCTION" ]]
then
	echo $COLOR_ERROR"The tag '$PRODUCTION_TAG_NAME' does NOT EXISTS in the repo: \n$PROJECT_REPO_DIR!"
	exit 0
else
	echo $COLOR_MSG"Production environment is on commit: $C_PRODUCTION"
fi

echo $COLOR_MSG"Clean Exported directory..."$COLOR_RESET
rm -fR $EXPORTED_DIR

echo $COLOR_MSG"Clone Git Repository..."$COLOR_RESET
#git clone --recursive file://$PROJECT_REPO_DIR$PROJECT_NAME $REPO_CLONED_DIR
git clone file://$PROJECT_REPO_DIR $REPO_CLONED_DIR
cd $REPO_CLONED_DIR

echo $COLOR_MSG"Get diff between commits: $C_PRODUCTION - $C_DEPLOY "$COLOR_RESET
git diff --name-status --diff-filter=AMDR --no-renames $C_PRODUCTION $C_DEPLOY > $EXPORTED_DIR$FILENAME_DIFF

echo $COLOR_MSG"Checking out $C_DEPLOY ..."$COLOR_RESET
git checkout $C_DEPLOY

echo $COLOR_MSG"Start to read the diff files..."$COLOR_RESET
# Start to Deploy Production environment
COUNTER=0
while read row; do
	COUNTER=$[COUNTER + 1]
	read -r f_status f_path <<< "$row"
	echo "$COUNTER - \c" # write the Row line
	# Check if it Is a file
	case $f_status in

		# STATUS: M (Modified), A (Added)
		[AM] )
			echo $COLOR_LOG"Upload... ($f_status): $f_path";
			if [ "$SIMULATION" == 1 ]
			then
				curl -u $FTP_USERNAME:$FTP_PASSWORD --ftp-create-dirs --silent --show-error -T $f_path ftp://$FTP_SERVER$FTP_PATH$f_path
			fi
			continue;;

		# STATUS: D (Deleted)
		D )
			# Check if it Is a file
			echo $COLOR_LOG"DELETE... ($f_status): Trying to delete $f_path: \c"
			if curl -u $FTP_USERNAME:$FTP_PASSWORD --output /dev/null --silent --head --fail ftp://$FTP_SERVER$FTP_PATH$f_path; then
				if [ "$SIMULATION" == 1 ]
				then
					curl -u $FTP_USERNAME:$FTP_PASSWORD --output /dev/null --silent --show-error --quote "DELE $FTP_PATH$f_path" ftp://$FTP_SERVER
                    echo "DELETED!";
                else
                    echo "DELETED! (SIMULATION, not really deleted)";
				fi
			else
				echo "it does NOT EXISTS!"
			fi
			continue;;

		# UNKNOWN STATUS! (TO DO...)
		* )
			echo $COLOR_ERROR"WARNING: I don't know this status: $f_status";
			break;;
	esac

done < $EXPORTED_DIR$FILENAME_DIFF

echo $COLOR_MSG"The commit $C_DEPLOY is deployed in PRODUCTION environment!"
if [ "$SIMULATION" == 0 ]
then
	echo $COLOR_ALERT"** SIMULATION MODE ENABLED **"
else
	cd $PROJECT_REPO_DIR
	git tag -f $PRODUCTION_TAG_NAME $C_DEPLOY
	echo $COLOR_MSG"Moved production tag '$PRODUCTION_TAG_NAME' to the commit '$C_DEPLOY'"
	echo "Success!"
fi
# Reset sh color
echo $COLOR_RESET

Git Deploy by FTP
=================

This shell script deploy a project from a Git repository by FTP using CURL.
It is only tested on OSX!!

## How it works?
I needed to deploy some projects by FTP because many hosting provider don't provide Git/SSH. The only way to deploy is by FTP.

After a lot of commits it becomes very hard to keep trace of the changed files and I don't want to upload all the project files every time. 
Git helps you to know what files are changed, so I created this script to put together Git and FTP.
You can create a single configuration file for any project and then you can call them by parameter.

Quiet, it creates a git clone of the repo to work on. 

### Git diff
It needs 2 commits to work, we can call them "Production" and "Deploy".
"Production" is the last commit that you've deployed. "Deploy" is the new one.
The script use `git diff` to create a list of the files changed from "Production" to "Deploy" commits.
To keep trace of the commit deployed it creates a tag on your repo: "production" (you can change that name in the config file). After deploying it moves the tag 'production' on the deployed commit.

What commit to "Deploy" will be set by parameter (see Usage).

### Upload by FTP
After creating a file list it starts to upload the files by FTP using CURL.

## Configuration
Create a copy of the 'dp-sample-config' file and rename it as '.dp-config-myProject'.
Change 'myProject' text as you prefer, so you can create more configuration files and you will be able to call them as parameter.

In the config file you have to change these values in the "SETTINGS" area:

* EXPORTED_DIR - is a temp directory where the script will store a cloned repository
* PROJECT_REPO_DIR - is the directory where is located your repo
* FTP_SERVER - FTP server name
* FTP_PATH - the Path where the project is deployed (Production environment)
* FTP_USERNAME - FTP username
* FTP_PASSWORD - FTP password


## Usage

	dp.sh -p <project-name> -d <commit-sha> [--not-simulate]
	 -p, --project 	 The name of the project to deploy (it is the configuration file that will be used)
	 -d, --deploy 	 The commit you want to deploy
	 --not-simulate  Deploy, not simulate!
	 --no-colors	 Disable colors layout
* The '-p' parameter is simple to understand (read above the Configuration).
* The '-d' is the commit that you want to deploy.
* By default it works as a simulation, only when you will be ready add the '--not-simulate' parameter to deploy to the production environment!

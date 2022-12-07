# linux
`tree` - to show in a tree mode

# tmux
* `Ctrl-b [` - enable scrolling
* `q` - exit from scrolling mode

# sed
* [Vilsual tarining](https://betterprogramming.pub/a-visual-guide-to-sed-a7a8abd2f675)

# git
* [git delete tags](https://devconnected.com/how-to-delete-local-and-remote-tags-on-git/)
* `git rebase -i HEAD~n`
* `git revert` - t creates a new commit that effectively reverses the changes introduced by the merge commit
## git log
* `git log --graph --pretty=oneline`
* `--no-notes`
* git log --graph --decorate --all --oneline'
## git worktree
* `git clone --bare [repo]`
* `git worktree add [path] [branch]`
* `git worktree add [path] -b [new branch] [base branch]`
## git sync with master
* `git fetch origin`
* `git rebase origin/master`

# ssh-keygen
* `ssh-keygen -t ed25519 -C $EMAIL -f ~/.ssh/name-of-the-key`

# Python
* `pd.set_option('display.max_columns', None)` - print all DataFrame's columns
* `pip config -v list` - gives a configuration for pip
* `$Env:PIP_CONFIG_FILE = "C:\path\to\your\pip.ini` - how to set path to pip.ini under Windows
* `conda config --get channels` - a list of channels in order based on priority

## pyenv
* `pyenv install 3.11.11`
* `pyenv local 3.11.11` - set environment for a repo after that we can use `python -m venv venv`

## poetry
* `poetry config virtualenvs.in-project true` - set poetry to install environment locally
* `poetry env info -p` - get a path to an environment
* `poetry env info` - general info about an environment

# curl
* `curl --location --header 'Content-Type: application/x-www-form-urlencoded' --data-urlencode 'grant_type=client_credentials' --data-urlencode '<client-id>' --data-urlencode 'client_secret=<client secret>' --location --request POST <pool url>/oauth2/token`
* `curl --request GET "https://1grri0vxad.execute-api.eu-central-1.amazonaws.com/prod/shop" --header "Authorization: <token>`

# MD5
* `openssl dgst -md5 -binary [fn] | openssl base64`

# networking
* `ipcalc [IP cidr]`

# docker
* `docker system df` - how much of your disk is just used for docker
* `docker stats` - how much resources each container is using?
* `docker cp` - copying files or directories between a running Docker container and your local filesystem
* `docker top` - prints out the currently running processes inside a running container

# oc
## docker image pull
1. `oc login`
2. `sudo nvim /etc/docker/daemon.json` and put `{
  "insecure-registries": ["default-route-openshift-image-registry.[*].com"]
}
`
3. `docker login -u openshift -p $(./oc whoami -t) [oc-name]`

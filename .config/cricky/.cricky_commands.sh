#!/bin/bash


# converts and saves youtube video to mp3
function youtubemp3() {
    youtube-dl --embed-thumbnail --extract-audio --audio-format mp3 -o "~/Downloads/ %(title)s.%(ext)s" $1
    cd ~/Documents/script_downloads/youtubemp3/
}

function chilledcow() {
    open https://youtu.be/5qap5aO4i9A
}

function robinhood() {
    open https://robinhood.com/stocks/$1
}

function youtube() {
    IFS='+'
    search="'$*'"
    search="${search:1:${#search}-2}"
    open "https://www.youtube.com/results?search_query=$search"
    IFS=$IFS
}

function google() {
    IFS='+'
    search="'$*'"
    search="${search:1:${#search}-2}"
    open "http://www.google.com/search?q=$search"
    IFS=$IFS
}

function sourceme() {
    source ~/.cricky_commands.sh
}

function sourceopen() {
    code ~/.cricky_commands.sh
}

function quickpy() {
    cd ~/Documents/code/python_projects/unfinished/quickpy
    touch saveme.py
    code saveme.py
}

function quicknote() {
    cd ~/Documents/Christopher/Documents/notes/
    if [ $# -eq 0 ]
    then
    nvim saveme.txt
    else
    touch "$1.txt"
    open "$1.txt"
    fi
}

function todo() {
    cd ~/Documents/Christopher/Documents/notes/
    touch todo.txt
    open todo.txt
}

function notes() {
    cd ~/Documents/Christopher/Documents/notes/
    open ~/Documents/Christopher/Documents/notes/
}

# These next two functions won't work if I don't have the files installed.
function newsite() {
    cd ~/Documents/code/javascript_projects
    mkdir $1
    cp ~/Documents/code/javascript_projects/.basesite/index.html ~/Documents/code/javascript_projects/$1/index.html
    cp ~/Documents/code/javascript_projects/.basesite/style.css ~/Documents/code/javascript_projects/$1/style.css
    cp ~/Documents/code/javascript_projects/.basesite/script.js ~/Documents/code/javascript_projects/$1/script.js
    cd ~/Documents/code/javascript_projects/$1/
    code .
}

function latouch() {
    cp /Users/christopherkapic/Documents/code/templates/standard.tex ./$1.tex
}

function chrome() {
    open file:///Users/christopherkapic/Documents/code/javascript_projects/.hometab/index.html
}

function safari() {
    SUB="http://"
    SUBS="https://"
    if [[ "$1" == *"$SUB"* ]] || [[ "$1" == *"$SUBS"* ]]
    then
        open -a Safari "$1"
    else
        open -a Safari "http://$1"
    fi
}


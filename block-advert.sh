#!/bin/bash

#v0.4 created by sc0ttman, August 2010
#GPL license /usr/share/doc/legal/gpl-2.0.txt
#100830 BK added GPL license, amended Exit msg, bug fixes.
# zenity version by lagopus for antiX, Decemder 2010
# modified to yad by Dave for antiX, September 2011
# fix update URL to mvps

# advert blocker
# downloads a list of known advert servers
# then appends them to /etc/hosts so that
# many online adverts are blocked from sight

TEXTDOMAINDIR=/usr/share/locale
TEXTDOMAIN=block-advert.sh

export title="antiX Advert Blocker"

# the markers used to find the changes in /etc/hosts, which are made by this app
export markerstart='# antiX-advert-blocker IPs below'
export markerend='# antiX-advert-blocker IPs above'

info_text=$"The <b>$title</b> tool adds stuff to your /etc/hosts file, so \n\
that many advertising servers and websites will not be able to connect \n\
to this PC.\n\n\
You can choose one service or combine multiple services for more advert protection.\n\
Blocking ad servers protects your privacy, saves you bandwidth, greatly \n\
improves web-browsing speed and makes the internet much less annoying in general.\n\n\
Do you want to proceed?"

# width of progress dialogs
WIDTH=360

# cleanup all leftover files
function cleanup
{
    # remove all temp files
    rm -f /tmp/adlist{1,2,3,4} /tmp/adlist-all /tmp/hosts-temp
}

# concatenate the downloaded files
# clean out everything but the list of IPs and servers
function build_adlist_all
{
    #echo "====================YTO"
    # suppress comments, then empty lines, replace tabs by spaces
    # remove double spaces, remove lines not beginning by a number,
    # suppress \r at end of line
    # then sort unique by field 2 (url)
    cat /tmp/adlist{1,2,3,4} | sed '/^#/d' | \
                               sed '/^$/d' | \
                               sed 's/[\t]/ /g' | \
                               sed 's/  / /g' | \
                               sed -n '/^[0-9]/p' | \
                               tr -d '\015' | \
                               sort -u -k 2 \
                               > /tmp/adlist-all
    #echo "====================YTO"
}


# append the list to the /etc/hosts
function append_adlist
{
	# copy /etc/hosts, but the stuff between the markers, to a temp hosts file
	sed -e "/$markerstart/,/$markerend/d" /etc/hosts > /tmp/hosts-temp
	# remove the markers
	sed -i -e "/$markerstart/d" /tmp/hosts-temp
	sed -i -e "/$markerend/d"   /tmp/hosts-temp
    
	# check the size of the final adlist - if UNBLOCK is chosen, it will be 0.
    size=$(stat -c%s /tmp/adlist-all 2>/dev/null)
    #echo $size
	if [ -n "$size" ] && [ "$size" -gt "0" ];then
		# add list contents into the hosts file, below a marker (for easier removal)
		echo "$markerstart" >> /tmp/hosts-temp
		cat /tmp/adlist-all >> /tmp/hosts-temp
		echo "$markerend"   >> /tmp/hosts-temp
	else
		yad --image="info" --title "$title" --text=$"Restoring original /etc/hosts."
        exit 1
	fi
    # On first use backup original /etc/hosts to /etc/hosts.ORIGINAL
    # If /etc/hosts.original exists, then backup to /etc/hosts.saved
    if [ -f /etc/hosts.ORIGINAL ]; then
    cp "/etc/hosts" "/etc/hosts.saved"
    mv "/tmp/hosts-temp" "/etc/hosts"
    else
    cp "/etc/hosts" "/etc/hosts.ORIGINAL"
    cp "/etc/hosts" "/etc/hosts.saved"
    mv "/tmp/hosts-temp" "/etc/hosts"
    fi
}


# usage: wget_dialog url file
# $1 : url of the file
# $2 : file: location of the downloaded file
function wget_dialog
{
    #echo "url: [$1]"
    url=$1
    # extract domain name between // and /
    domain=$(echo "$url" | cut -d/ -f3)
    #echo "===> $domain"
    
    # '--progress=dot' prints dots and a percentage at the end of the line
    # print $7 to cut the percentage
    # system("") to flush the output of awk in the pipe
    # sed to delete the ending '%' sign
    # sed -u to flush the output of sed
    # changed -t 0 (tries) to -t 20
    wget -c -4 -t 20 -T 10 --progress=dot -O $2 "$1" 2>&1 | \
        awk '{print $7}; system("")' | sed -u 's/%//' | \
        yad --title "$title" --progress --width $WIDTH \
               --text=$"Loading  adlist from $domain" \
               --percentage=0 \
               --auto-close
}

# download the ads lists
function download_adlist
{
    # mvps
    if [ "$mvps" = true ]; then
        wget_dialog http://winhelp2002.mvps.org/hosts.txt /tmp/adlist1 # TP fix update URL 
    fi
    sed -i 's/0.0.0.0/127.0.0.1/' /tmp/adlist1 # TP fix to change 0.0.0.0 to 127.0.0.1 in mvps list
    sed -i 's/ #.*$//' /tmp/adlist1 # TP fix to remove comments in mvps list

    # someonewhocares
    if [ "$someonewhocares" = true ]; then
        wget_dialog http://someonewhocares.org/hosts/hosts /tmp/adlist2
    fi

    # yoyo
    if [ "$yoyo" = true ]; then
        wget_dialog 'http://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&showintro=0&mimetype=plaintext' /tmp/adlist3
    fi
     
    # adservers
    if [ "$adservers" = true ]; then
        wget_dialog http://hosts-file.net/ad_servers.asp /tmp/adlist4
    fi

    # UNBLOCK
    if [ "$unblock" = true ]; then
        mv -f "/etc/hosts.ORIGINAL" "/etc/hosts" 
        rm -f "/etc/hosts.saved"
    fi

    #100830 BK bug fix: create if not exist...
    touch /tmp/adlist{1,2,3,4} 
}


function success
{
	# tell user 
	yad --image "info" --title "$title" --text=$"Success - your settings have been changed.\n\n\
Your hosts file has been updated.\n\
Restart your browser to see the changes."
}

#=======================================================================
# main
#

# display message and ask to continue
yad --title "$title" --width "$WIDTH" --image "question" --text "$info_text"
rsp=$?

if [ $rsp != 0 ]; then
    exit 0
fi

# selection dialog
ans=$(yad --title "$title" \
             --width "$WIDTH" --height 220 \
             --list --separator=":" \
             --text $"Choose your preferred ad blocking service(s)" \
             --checklist  --column "Pick" --column "Service"\
             FALSE "mvps.org" \
             FALSE "someonewhocares.org" \
             FALSE "yoyo.org" \
             FALSE "adservers.org" \
             FALSE "UNBLOCK" )

#echo $ans

# transform the list separated by ':' into arr
arr=$(echo $ans | tr ":" "\n")

selected=""
for x in $arr
do
    #echo "> [$x]"
    case $x in
    mvps.org)
        mvps='true'
        selected='yes'
        ;;
    someonewhocares.org)
        someonewhocares='true'
        selected='yes'
        ;;
    yoyo.org)
        yoyo='true'
        selected='yes'
        ;;
    adservers.org)
        adservers='true'
        selected='yes'
        ;;
    UNBLOCK)
        unblock='true'
        selected='yes'
        ;;
    esac    
done

if [ -z $selected ]; then
    # nothing selected
    echo $"No item selected"
    exit 0
fi

cleanup
download_adlist
build_adlist_all
append_adlist
cleanup
success

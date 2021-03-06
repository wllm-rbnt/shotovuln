#!/bin/bash

### COLORS
BLUE='\033[94m'
RED='\033[91m'
GREEN='\033[92m'
ORANGE='\033[93m'
NOCOLOR='\e[0m'

echo "SHOTOVULN v0.1"
# insert ASCII art =)
echo -e "$GREEN Senseiiii *0* show me the path to $RED R00T $BLUE *o* ! $NOCOLOR";
echo "";
echo "Please run this script as low privilege user :]";
echo -e "$ORANGE Usage: $NOCOLOR $0 $GREEN [currentuserpassword] [nonbrute] [nodwl]";
echo "";

# PHILOSOPHY / IDEAS
# - non interactive
# - stealth , try not to touch drive except if needed, try to run everything in memory as much as possible
# - do not output useless information
# - run as low privilege user
# - show clear path to root
# requirement on the compromised box : *nix OS, bash , python , pip


echo -e "$ORANGE### 0. Pre work and preparing $NOCOLOR";
echo "Saving writable folders for everyone, useful for next steps";
writabledirs=$(find / -type d -perm /o+w ! -path "*mqueue*" 2>/dev/null);
writedir=$(echo "$writabledirs" | head -n1);
echo -e "$NOCOLOR Will use as writable dir: $RED $writedir";

currentuser=$(id);
echo -e "$NOCOLOR Current user and privileges is: $RED $currentuser";
echo -e "$NOCOLOR Getting quality short password wordlist from internet...";
# TODO for dev purposes , test if file exists
if [ ! -f "$writedir/.wordlist" ]; then
wget -qO "$writedir/.wordlist" "https://raw.githubusercontent.com/berzerk0/Probable-Wordlists/master/Real-Passwords/Top220-probable.txt"; # 200 to be fast
passwords="$writedir/.wordlist";
fi;

echo "Getting valid users for login";
validusers=$(grep -v '/false' /etc/passwd | grep -v '/nologin' | cut -d ':' -f1);
# echo "Valid users are $validusers";

# python and pip needed on the box TODO test here
# pip install pexpect;







echo "";
echo -e "$ORANGE### 1. Auditing features-like paths to go to other privileges $NOCOLOR"
# sudo and su brute https://www.altsci.com/concepts/sudo-and-su-considered-harmful-sudosu-bruteforce-utility
if [ ! -z "$1" ] ; then
echo "Own / currentuser password provided!";
echo "What can you do as sudo with this password :] ?";
sudo -l;
else
echo "Now simple bruteforcing the loggedin user password through simple loop in su or sudo";
# TODO faster sudo bruteforcer , using python child / pexpect
# python tools/sudo_brute1.py < "$passwords" ; # here use a better script or smaller wordlist
fi;

echo "Brute forcing local users via su";
# python su brute script here

echo "Getting SSH permissions";
sshperm=$(grep -niR --color permit /etc/ssh/sshd_config);
echo "[debug] : $sshperm";

echo "Getting allow users if any in SSH config"
sshusers=$(grep -niR --color allowusers /etc/ssh/sshd_config);
echo "[debug]: $sshusers";

echo "Scanning localhost ports for SSH detection and brute force";
# TODO better ssh detection
nc -z -v 127.0.0.1 22;
nc -z -v 127.0.0.1 222;
nc -z -v 127.0.0.1 2222;
nc -z -v 127.0.0.1 22222;
nc -z -v 127.0.0.1 10022;

echo "Now bruting valid users on SSH ports using ssh passcript";
# ./tools/sshpassscript.sh "$passwords";

# TODO check if dmesg allows you to privesc echo "Do we have access to dmesg and check privesc related information ?"
#dmesg script;







echo "";
echo -e "$ORANGE### 2. Auditing file and folders permissions to privesc $NOCOLOR"

echo "Root owned files in non root owned directory, ie. non root user can replace root owned files"
for x in $(find /var -type f -user root 2>/dev/null -exec dirname {} + | sort -u); do (echo -n "$x is owned by " && stat -c %U "$x") | grep -v 'root'; done

echo "Writable directory in default PATH, ie. ..."
pathtotest=$(echo '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' | tr ':' ' ');
#for x in pathtotest; do ; done

echo "Checking tmp files for passwords or secrets";
find /tmp/ -type f -size +0 -exec grep -i --color 'secret/|password/|' {} + 2>/dev/null;
# TODO this step outputs useless information sometimes so filter it better







echo "";
echo -e "$ORANGE### 3. Auditing SUID and SUID operations in a dumb way ... ie no arguments provided to them.$NOCOLOR"
# TODO be careful not to kill network
### https://www.pentestpartners.com/blog/exploiting-suid-executables/;

echo "SGID folders writable by others, ie. other can get group rights by writing to it"
find / -type d -perm /g+s -perm /o+w -exec ls -alhd {} + 2>/dev/null;

echo "SUID folders writable by others, ie. other can get user rights by writing to it"
find / -type d -perm /u+s -perm /o+w -exec ls -alhd {} + 2>/dev/null;

echo "Test SUID conf files for error based info disclosure"
# TODO code it --conf / -c / grep conf in help
# example ./suidbinary -conf /etc/shadow outputs the user hashes

echo "Generating SUID logs ... you might receive some pop ups and error message since we are starting all SUID binaries.";
mkdir -p "$writedir/.shotologs";

find / -perm /4000 2>/dev/null | sort -u > "$writedir/.suidbinaries";
while read -r suid; do
echo "[debug $suid]";
basename=$(basename "$suid");
#sleep 6s;
# TODO debug this s**t;
timeout 13s strace "$suid" -o "$writedir"/.shotologs/"$basename".stracelog 1>/dev/null 2>/dev/null ;
done < "$writedir/.suidbinaries";

echo "Relative path opening in suid binaries, ie. you can fool the suid binary to open arbitrary file."
grep -n 'open("\.' "$writedir"/.shotologs/* --color;
grep -n 'open(' "$writedir"/.shotologs/* | grep -v 'open("/';

echo "Environment variables used in suid binaries, ie. untrusted use of env variables."
grep -n --color "getenv(" "$writedir"/.shotologs/*;

echo "Exec used in suid binaries, ie. untrusted use of PATH potentialy."
grep -n --color 'execve' "$writedir"/.shotologs/*;







echo "";
echo -e "$ORANGE### 4. Specific edge cases which enable you to change privilege. $NOCOLOR"

echo "Apache symlink test";
find / -name apache*.conf -exec echo {} + -exec grep -i symlink --color {} + 2>/dev/null;

echo "Pythonpath or environment var issues"
python -c "import sys; print '\n'.join(sys.path);"







echo "";
echo -e "$ORANGE### 5. Init.d script auditing $NOCOLOR";
### The problem is service (init.d) strips all environment variables but TERM, PATH and LANG which is a good thing
echo "rc scripts pointing to a user controled directory";
#grep -n --color '/' /etc/rc.local;
echo "Init.d scripts using unfiltered environment variables";
grep -n -R --color 'PATH=\|LANG=\|TERM=' /etc/init.d/*;
# TODO confirm this is exploitable , better regexp
# race PATH inject before init.d is starting
# init.d is starting early
echo "Usage of predictable or fixed files in a writable folder used by init.d";
usedbyinit="$(grep -n -R --color ' /tmp' /etc/init.d/*)";
# TODO crosscheck with writabledirs





echo "";
echo -e "$ORANGE### 6. Conf files password disclosure and password reuse $NOCOLOR";
grep -v '^$\|^\s*\#' /etc/*.conf  | grep -i --color "password" -A1;
grep -v '^$\|^\s*\#' /etc/*/*.conf  | grep -i --color "password" -A1;
# TODO filter false positives





echo "";
echo -e "$ORANGE### 7. Log file information disclosure $NOCOLOR";

echo "Valid users history files";
# $validusers history grepping




echo "";
echo -e "$ORANGE### X. Privesc matrix $NOCOLOR";
# we might need to create a matrix of user privs
# user1 > user2 > user9 > group1 > rootgroup > root
# BIG TODO , map the privilege , ie like user1 > user2 > user3 > root
# privescpath=(user1,user2);(user2,root)

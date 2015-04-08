#!/bin/sh

load_conf()
{
	CONF="/usr/local/ddos/ddos.conf"
	# if path "CONF" exist and not empty then
	if [ -f "$CONF" ] && [ ! "$CONF" ==	"" ]; then 
		source $CONF # import/open ddos.conf
	else
		echo "\$CONF not found!"
		exit 1
	fi
}

unban_ip()
{
	UNBAN_SCRIPT=`mktemp /tmp/UnbanIPs.XXXXXXXX`
	echo '#!/bin/sh' > $UNBAN_SCRIPT
	echo "sleep $BAN_PERIOD" >> $UNBAN_SCRIPT
	while read ip; do
		echo "$IPT -D INPUT -s $ip -j DROP" >> $UNBAN_SCRIPT
	done < $FIRST_BANNED_IP_LIST
	echo "rm -f $UNBAN_SCRIPT" >> $UNBAN_SCRIPT
	. $UNBAN_SCRIPT &
}

# add references for start programm by timetable
add_to_cron()
{
	rm -f $CRON
	sleep 1
	service crond restart
	sleep 1
	echo "SHELL=/bin/sh" > $CRON
	if [ $FREQ -le 2 ]; then
		echo "0-59/$FREQ * * * * root /usr/local/ddos/ddos.sh >/dev/null 2>&1" >> $CRON
	else
		let "START_MINUTE = $RANDOM % ($FREQ - 1)"
		let "START_MINUTE = $START_MINUTE + 1"
		let "END_MINUTE = 60 - $FREQ + $START_MINUTE"
		echo "$START_MINUTE-$END_MINUTE/$FREQ * * * * root /usr/local/ddos/ddos.sh >/dev/null 2>&1" >> $CRON
	fi
	service crond restart
}

clean_ip_list()
{
	# start c++ app for clean CHECKING_IP_LIST
	RUN_FILE = "$PROGDIR/CleanLog $CHECKING_IP_LIST"
	. $RUN_FILE &
	while read line; do
		CURR_IP=$(echo $line | cut -d" " -f1)
		echo $CURR_IP >> CURR_CHECK_IP_LIST
	done < $CHECKING_IP_LIST
}

load_conf

while [ $1 ]; do
	# if program start with flag '--cron'
	if [ $1 == '--cron']; then
		add_to_cron
		exit		
	fi
	shift
done

# create tmp files
TMP_PREFIX='/tmp/IPs'
TMP_FILE="mktemp $TMP_PREFIX.XXXXXXXX"
FIRST_BANNED_IP_LIST=`$TMP_FILE`
SECOND_BANNED_IP_LIST=`$TMP_FILE`
TOP_IP_LIST=`$TMP_FILE`
CURR_CHECK_IP_LIST=`$TMP_FILE`

clean_ip_list
# save the top of IP's by connections count to tmp file
netstat -ntu | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -nr > $TOP_IP_LIST
# open tmp file
#####################cat $TOP_IP_LIST
IS_BANNED_IP_NOW=0

while read line; do
	CURR_LINE_CONN=$(echo $line | cut -d" " -f1)
	CURR_LINE_IP=$(echo $line | cut -d" " -f2)
	# check if connections count < min correct conn count then break 
	# because the top of IP's is sorted and it isn't need to check other lines
	if [ $CURR_LINE_CONN -lt $MAX_CONNECTIONS ]; then
		break
	fi
	# if it isn't break then this IP is bad and it must be banned 
	# find CURR_IP in ignore file by command "grep -c"
	IGNORE_BAN=`grep -c $CURR_LINE_IP $IGNORE_IP_LIST`
	# check if IP in ignore list
	if [ $IGNORE_BAN -ge 1 ]; then
		continue
	fi
	IS_BANNED_IP_NOW=1
	EXISTS_IP=`grep -c $CURR_LINE_IP $CURR_CHECK_IP_LIST`
	if [ $EXISTS_IP -ge 1]; then
		echo $CURR_LINE_IP >> $SECOND_BANNED_IP_LIST
	else
		echo $CURR_LINE_IP >> $FIRST_BANNED_IP_LIST
	fi
	# echo $CURR_LINE_IP >> $IGNORE_IP_LIST
	$IPT -I INPUT -s $CURR_LINE_IP -j DROP
done < $TOP_IP_LIST

LINES_COUNT = 0

if [ -r IP_LIST_FOR_BAN ]; then
	IS_BANNED_IP_NOW=1
	while read ip; do
		LINES_COUNT = LINES_COUNT + 1
		EXISTS_IP=`grep -c $ip $FIRST_BANNED_IP_LIST`
		# check if IP is already exists in banned list
		if [ $EXISTS_IP -ge 1 ]; then
			continue
		fi
		EXISTS_IP=`grep -c $ip $SECOND_BANNED_IP_LIST`
		# check if IP is already exists in banned list
		if [ $EXISTS_IP -ge 1 ]; then
			continue
		fi
		EXISTS_IP=`grep -c $ip $CURR_CHECK_IP_LIST`
		if [ $EXISTS_IP -ge 1]; then
			echo $CURR_LINE_IP >> $SECOND_BANNED_IP_LIST
		else
			echo $CURR_LINE_IP >> $FIRST_BANNED_IP_LIST
		fi
		$IPT -I INPUT -s $CURR_LINE_IP -j DROP
	done < $IP_LIST_FOR_BAN
fi

# rm -f $IP_LIST_FOR_BAN

# For Mac OS: DELETE_READEN_LINES = `sed -i.bak '1, $LINES_COUNT d' $IP_LIST_FOR_BAN`
DELETE_READEN_LINES = `sed -i '1, $LINES_COUNT d' $IP_LIST_FOR_BAN`
if [ LINES_COUNT -ge 1]; then 
	$DELETE_READEN_LINES
fi

if [ $IS_BANNED_IP_NOW -eq 1 ]; then
	date=`date`
	while read ip; do
		echo "$ip $(echo $date | cut -d" " -f3) $(echo $date | cut -d" " -f4) 0" >> $CHECKING_IP_LIST
	done < $FIRST_BANNED_IP_LIST
	while read ip; do
		echo "$ip $(echo $date | cut -d" " -f3) $(echo $date | cut -d" " -f4) 1" >> $CHECKING_IP_LIST
	done < $SECOND_BANNED_IP_LIST
	unban_ip
fi
rm -f $TMP_PREFIX.*

#!/bin/bash
#
# rsdns-export.sh - Used to export domains 
#

# config file for variables.
if [ -e ~/.rsdns_config ]
then
  . ~/.rsdns_config
fi

# load up our auth & funct library
if [ -n "$RSPATH" ]
then
  . $RSPATH/lib/auth.sh
  . $RSPATH/lib/func.sh
else
  . lib/auth.sh
  . lib/func.sh
fi

#prints out the usage information on error or request.
function usage () {
	printf "\n"
	printf "rsdns list -u username -a apiKey -d domain\n"
	printf "\t-k Use London/UK Servers.\n"
	printf "\t-h Show this.\n"
	printf "\n"
}

#prints words for master rsdns script output 
function words () {
	printf "Export domains in bind format \n"
}

#
function get_export() {
    
    check_domain

	if [ $FOUND -eq 1 ]
	then

        DOMEXPORT=`curl -k -s -X GET -H X-Auth-Token:\ $TOKEN $DNSSVR/$USERID/domains/$DOMAINID/export|tr -s '[:cntrl:]' "\n"`
        
        JQ_DOMEXPORT_STATUS=`echo $DOMEXPORT | jq .status | tr -d '"'`
        echo "Job status is: $JQ_DOMEXPORT_STATUS"
        
        JQ_DOMEXPORT_CALLBACK=`echo $DOMEXPORT | jq .callbackUrl | tr -d '"'` 
        
        if [ "$JQ_DOMEXPORT_STATUS" == "RUNNING" ]
        then
            while true; do

                DOMEXPORT=`curl -k -s -X GET -H X-Auth-Token:\ $TOKEN $JQ_DOMEXPORT_CALLBACK?showDetails=true|tr -s '[:cntrl:]' "\n"`
                
                JQ_DOMEXPORT_STATUS=`echo $DOMEXPORT | jq .status | tr -d '"'`
                echo "Job status is: $JQ_DOMEXPORT_STATUS"
                echo 
                
                if [ "$JQ_DOMEXPORT_STATUS" == "COMPLETED" ]
                then
                    echo $DOMEXPORT | jq .response.contents | tr -d '"' | awk '{gsub(/\\n/,"\n")}1' | awk '{gsub(/\\t/,"\t")}1' | sed 's/\\//g'
                    break
                elif [ "$JQ_DOMEXPORT_STATUS" == "ERROR" ]; then
                    echo $DOMEXPORT | jq .
                    break
                else
                    echo "Sleeping...."
                    sleep 1
                fi
            done
        else
            echo echo $DOMEXPORT | jq .
        fi
    fi
}


#Get options from the command line.
while getopts "u:a:c:d::hkqw" option
do
	case $option in
		u	) RSUSER=$OPTARG ;;
		a	) RSAPIKEY=$OPTARG ;;
		c	) USERID=$OPTARG ;;
		d	) DOMAIN=$OPTARG ;;
		h	) usage;exit 0 ;;
		q	) QUIET=1 ;;
		k	) UKAUTH=1 ;;
		w	) words;exit 0 ;;
	esac
done

#All actions require authentication, get it done first.
#If the authentication works this will return $TOKEN and $MGMTSVR for use by everything else.
get_auth $RSUSER $RSAPIKEY
if test -z $TOKEN
	then 
	if [[ $QUIET -eq 0 ]]; then
		echo Auth Token does not exist.
	fi
	exit 98
fi
if test -z $MGMTSVR
	then 
	if [[ $QUIET -eq 0 ]]; then
		echo Management Server does not exist.
	fi
	exit 98
fi

#if a domain is given, print records, else print domaints
if [ -z "$DOMAIN" ]
	then
        echo "Which domain do you want to export?"
        echo "use the -d switch"
        echo
	print_domains 
else
	get_export
fi

#done
exit 0
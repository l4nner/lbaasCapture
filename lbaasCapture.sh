#!/bin/bash
#
# Requirements
# - jq package (usually installable via `$sudo yum install jq -y`)
# - Bash shell
# - OCI CLI installed and configured
#   https://docs.cloud.oracle.com/iaas/Content/API/SDKDocs/cliinstall.htm
#
# (this script won't capture LBs inside the root compartment)
#

printTitle() {
	title=$1; str=-; num="80"
	titlelength=`echo -n $title | wc -c`
	repeat=$(expr $num - $titlelength)
	v=$(printf "%-${repeat}s" "$str")
	printf "$title"
	echo "${v// /$str}"
}

for compartmentID in `oci iam compartment list --all | jq -r '.data[] | .id +" "+."lifecycle-state"' | grep "ACTIVE" | awk '{print $1}'`
do
    compartmentID=`oci iam compartment get --compartment-id $compartmentID | jq -r '[.data.id]|.[]'`
    compartmentName=`oci iam compartment get --compartment-id $compartmentID | jq -r '[.data.name]|.[]'`
    if [ `oci lb load-balancer list -c $compartmentID | wc -l` -gt 0 ]
    then
        printTitle "COMPARTMENT $compartmentName"
        echo ">> Policy"
        oci lb policy list -c $compartmentID
        echo ">> Protocol"
        oci lb protocol list -c $compartmentID
        echo ">> Shape"
        oci lb shape list -c $compartmentID
        for lbID in `oci lb load-balancer list -c $compartmentID | jq -r '[.data[].id]|.[]'`
        do
            loadBalancerDisplayName=`oci lb load-balancer get --load-balancer-id $lbID | jq -r '[.data."display-name"]|.[]'`
            printTitle "Load Balancer $loadBalancerDisplayName"
            echo ">> LB Details"
            oci lb load-balancer get --load-balancer-id $lbID
            echo ">> Hostname"
            oci lb hostname list --load-balancer-id $lbID
            echo ">> LB health"
            oci lb load-balancer-health get --load-balancer-id $lbID
            echo ">> Certs"
            oci lb certificate list --load-balancer-id $lbID
            if [ `oci lb backend-set list --load-balancer-id $lbID | wc -l` -gt 3 ]
            then
                for backend in `oci lb backend-set list --load-balancer-id $lbID | jq -r '[.data[].name]|.[]'`
                do
                    echo ">> Backend set"
                    oci lb backend-set get --load-balancer-id $lbID --backend-set-name $backend
                    echo ">> Backend set health"
                    oci lb backend-set-health get --load-balancer-id $lbID --backend-set-name $backend
                    echo ">> Backend set health check"               
                    oci lb health-checker get --load-balancer-id $lbID --backend-set-name $backend
                done
            fi
        done
    else
        echo "No Load Balancers in compartment $compartmentName"
    fi
done

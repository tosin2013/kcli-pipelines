#!/bin/bash 
export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
set -e
set -x
# https://github.com/freeipa/freeipa-container
# docker='sudo podman' tests/run-master-and-replica.sh quay.io/freeipa/freeipa-server:fedora-37
# https://two-oes.medium.com/openshift-4-with-freeipa-container-as-an-identity-provider-3c25bd5fd9ee
DOMAIN_NAME=qubinode-lab.io
SECRET="Secret123"
USERNAME="bob"
LASTNAME="Smith"
DNS_FORWARDER="1.1.1.1"
umask 0007

docker="podman"

sudo=sudo

BASE=ipa
VOLUME=${VOLUME:-/tmp/freeipa-test-$$/data}

function wait_for_ipa_container() {
	set +x
	N="$1" ; shift
	set -e
	$docker logs -f "$N" &
	trap "kill $! 2> /dev/null || : ; trap - RETURN EXIT" RETURN EXIT
	EXIT_STATUS=999
	while true ; do
		sleep 10
		status=$( $docker inspect "$N" --format='{{.State.Status}}' )
		if [ "$status" == exited -o "$status" == stopped ] ; then
			EXIT_STATUS=$( $docker inspect "$N" --format='{{.State.ExitCode}}' )
			echo "The container has exited with .State.ExitCode [$EXIT_STATUS]."
			break
		elif [ "$1" != "exit-on-finished" ] ; then
			# With exit-on-finished, we expect the container to exit, seeing it exited above
			STATUS=$( $docker exec "$N" systemctl is-system-running 2> /dev/null || : )
			if [ "$STATUS" == 'running' ] ; then
				echo "The container systemctl is-system-running [$STATUS]."
				EXIT_STATUS=0
				break
			elif [ "$STATUS" == 'degraded' ] ; then
				echo "The container systemctl is-system-running [$STATUS]."
				$docker exec "$N" systemctl
				$docker exec "$N" systemctl status
				EXIT_STATUS=1
				break
			fi
		fi
	done
	date
	if test -O $VOLUME/build-id ; then
		sudo=
	fi
	if [ "$EXIT_STATUS" -ne 0 ] ; then
		exit "$EXIT_STATUS"
	fi
	MACHINE_ID=$( cat $VOLUME/etc/machine-id )
	# Check that journal landed on volume and not in host's /var/log/journal
	$sudo ls -la $VOLUME/var/log/journal/$MACHINE_ID
	if [ -e /var/log/journal/$MACHINE_ID ] ; then
		ls -la /var/log/journal/$MACHINE_ID
		exit 1
	fi
}

function set_firewall_rules() {
  firewall-cmd --zone=work --permanent --add-service=https
  firewall-cmd --zone=work --permanent --add-service=http
  firewall-cmd --zone=work --permanent --add-service=ldap
  firewall-cmd --zone=work --permanent --add-service=ldaps
  firewall-cmd --zone=work --permanent --add-port=53/udp
  firewall-cmd --zone=work --permanent --add-port=53/tcp
  firewall-cmd --zone=work --permanent --add-port=88
  firewall-cmd --zone=work --permanent --add-port=88/udp
  firewall-cmd --zone=work --permanent --add-port=464/udp
  firewall-cmd --zone=work --permanent --add-port=464
  firewall-cmd --zone=work --permanent --add-port=123/udp
  firewall-cmd --reload
}
function run_ipa_container() {
	set +x
	IMAGE="$1" ; shift
	N="$1" ; shift
	set -e
	date
	HOSTNAME=ipa.${DOMAIN_NAME}
	if [ "$N" == "freeipa-replica" ] ; then
		HOSTNAME=replica.${DOMAIN_NAME}
		VOLUME=/tmp/freeipa-test-$$/data-replica
	fi
	mkdir -p $VOLUME
	OPTS=
	if [ "${docker%podman}" = "$docker" ] ; then
		# if it is not podman, it is docker
		if [ -f /sys/fs/cgroup/cgroup.controllers ] ; then
			# we assume unified cgroup v2 and docker with userns remapping enabled
			OPTS="--sysctl net.ipv6.conf.all.disable_ipv6=0"
		else
			OPTS="-v /sys/fs/cgroup:/sys/fs/cgroup:ro --sysctl net.ipv6.conf.all.disable_ipv6=0"
		fi
	fi
	if [ -n "$seccomp" ] ; then
		OPTS="$OPTS --security-opt seccomp=$seccomp"
	fi
	if [ "$(id -u)" != 0 -a "$docker" == podman -a "$replica" != none ] ; then
		if [ "$N" == "freeipa-master" ] ; then
            OPTS="--setup-dns  --forwarder=${DNS_FORWARDER} --allow-zone-overlap"
			OPTS="$OPTS --pod=$BASE-master"
		else
			OPTS="$OPTS --pod=$BASE-replica"
		fi
	else
		OPTS="$OPTS -h $HOSTNAME"
	fi
	(
	set -x
	umask 0
    if [ "$N" == "freeipa-master" ];
    then 
      PORTS=" -p 53:53/udp -p 53:53  -p 80:80 -p 443:443 -p 389:389 -p 636:636 -p 88:88 -p 464:464 -p 88:88/udp -p 464:464/udp -p 123:123/udp"
    fi 
	$docker run $PORTS $readonly_run -d --name "$N" $OPTS \
		-v $VOLUME:/data:Z $DOCKER_RUN_OPTS \
		-e PASSWORD=${SECRET} "$IMAGE" "$@"
	)
	wait_for_ipa_container "$N" "$@"
}

IMAGE="$1"

readonly_run="$readonly"
if [ "$(id -u)" != 0 -a "$docker" == podman -a "$replica" != none ] ; then
	# cleanup of potential previous runs
	podman pod rm -f $BASE-master 2> /dev/null || :
	podman pod rm -f $BASE-replica 2> /dev/null || :
	sudo ip link del $BASE-master 2> /dev/null || :
	sudo ip link del $BASE-replica 2> /dev/null || :
	sudo ip netns del $BASE-master 2> /dev/null || :
	sudo ip netns del $BASE-replica 2> /dev/null || :
	# create link
	sudo ip link add $BASE-master type veth peer name $BASE-replica
	# create and start pods to get their host pids; not running containers in them yet
	podman pod create --name $BASE-master --hostname ipa.${DOMAIN_NAME} --add-host ipa.${DOMAIN_NAME}:172.29.0.1 --dns=127.0.0.1
	podman pod create --name $BASE-replica --hostname replica.${DOMAIN_NAME} --dns=172.29.0.1
	podman pod start $BASE-master
	podman pod top $BASE-master hpid | grep -v ^HPID | xargs sudo ip netns attach $BASE-master
	sudo ip link set $BASE-master netns $BASE-master
	sudo ip netns exec $BASE-master ip link set dev $BASE-master up
	sudo ip netns exec $BASE-master ip addr add 172.29.0.1/24 dev $BASE-master
	podman pod start $BASE-replica
	podman pod top $BASE-replica hpid | grep -v ^HPID | xargs sudo ip netns attach $BASE-replica
	sudo ip link set $BASE-replica netns $BASE-replica
	sudo ip netns exec $BASE-replica ip link set dev $BASE-replica up
	sudo ip netns exec $BASE-replica ip addr add 172.29.0.2/24 dev $BASE-replica
elif [ "$readonly" == "--read-only" ] ; then
	readonly_run="$readonly --dns=127.0.0.1"
fi

fresh_install=true
if [ -f "$VOLUME/build-id" ] ; then
	# If we were given already populated volume, just run the container
	fresh_install=false
	run_ipa_container $IMAGE freeipa-master exit-on-finished
else
	# Initial setup of the FreeIPA server
  set_firewall_rules
	dns_opts="--auto-reverse --allow-zone-overlap --forwarder=${DNS_FORWARDER}"
	if [ "$replica" = 'none' ] ; then
		dns_opts=""
	fi
	if [ "$(id -u)" != 0 -a "$docker" == podman -a "$replica" != none ] ; then
		dns_opts="$dns_opts --ip-address=172.29.0.1"
	fi
	run_ipa_container $IMAGE freeipa-master exit-on-finished -U -r ${DOMAIN_NAME} --setup-dns  $dns_opts --no-ntp $ca

	if [ -n "$ca" ] ; then
		$docker rm -f freeipa-master
		date
		$sudo cp tests/generate-external-ca.sh $VOLUME/
		$docker run --rm -v $VOLUME:/data:Z --entrypoint /data/generate-external-ca.sh "$IMAGE"
		# For external CA, provide the certificate for the second stage
		run_ipa_container $IMAGE freeipa-master exit-on-finished -U -r ${DOMAIN_NAME} --setup-dns --no-forwarders --no-ntp \
			--external-cert-file=/data/ipa.crt --external-cert-file=/data/ca.crt
	fi
fi

while [ -n "$1" ] ; do
	IMAGE="$1"
	$docker rm -f freeipa-master
	# Start the already-setup master server, or upgrade to next image
	run_ipa_container $IMAGE freeipa-master exit-on-finished
	shift
done

(
set -x
date
$docker stop freeipa-master
date
$docker start freeipa-master
)
wait_for_ipa_container freeipa-master

$docker rm -f freeipa-master
# Force "upgrade" path by simulating image change
$sudo mv $VOLUME/build-id $VOLUME/build-id.initial
uuidgen | $sudo tee $VOLUME/build-id
$sudo touch -r $VOLUME/build-id.initial $VOLUME/build-id
run_ipa_container $IMAGE freeipa-master

# Wait for the services to start to the point when SSSD is operational
for i in $( seq 1 20 ) ; do
	if $docker exec freeipa-master id admin 2> /dev/null ; then
		break
	fi
	if [ "$((i % 5))" == 1 ] ; then
		echo "Waiting for SSSD in the container to start ..."
	fi
	sleep 5
done
(
set -x
$docker exec freeipa-master bash -c 'yes '${SECRET}' | kinit admin'
$docker exec freeipa-master ipa user-add --first ${USERNAME} --last ${LASTNAME} ${USERNAME}$$
$docker exec freeipa-master id ${USERNAME}$$

if $fresh_install ; then
	$docker exec freeipa-master ipa-adtrust-install -a ${SECRET} --netbios-name=EXAMPLE -U
	$docker exec freeipa-master ipa-kra-install -p ${SECRET} -U
fi
)

if [ "$replica" = 'none' ] ; then
	echo OK $0.
	exit
fi

# Setup replica
readonly_run="$readonly"
MASTER_IP=$( $docker inspect --format '{{ .NetworkSettings.IPAddress }}' freeipa-master )
DOCKER_RUN_OPTS="--dns=$MASTER_IP"
if [ "$docker" != "sudo podman" -a "$docker" != "podman" ] ; then
	DOCKER_RUN_OPTS="--link freeipa-master:ipa.${DOMAIN_NAME} $DOCKER_RUN_OPTS"
fi
SETUP_CA=--setup-ca
if [ $(( $RANDOM % 2 )) == 0 ] ; then
	SETUP_CA=
fi
run_ipa_container $IMAGE freeipa-replica no-exit ipa-replica-install -U --principal admin $SETUP_CA --no-ntp
date

if [ -z "$SETUP_CA" ] ; then
	$docker exec freeipa-replica ipa-ca-install -p ${SECRET}
	$docker exec freeipa-replica systemctl is-system-running
fi
echo OK $0.
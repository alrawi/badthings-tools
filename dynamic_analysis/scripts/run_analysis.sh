#!/bin/bash
# do this one day
# https://bertvv.github.io/cheat-sheets/Bash.html 

source ./logger.sh

#function usage {
#	error "\nUsage: $progname <binary_file_path> <timeout>\n\n\
#<binary_file_path>: The path to the binary you would like to run.\
# Make sure the path is accessible inside the container.\n\
#<timeout>: An integer indicating how many seconds you would like the\
# sample to run.\n"
#}

function init {
	# $1 is the path to the binary
	# prep the rootfs
	inf "Preping rootfs for analysis"
	set -e
	cd /br2
	mkdir -p /br2/rtfs
	inf "Mounting rootfs"
	mount rootfs.ext2 /br2/rtfs
	mkdir -p /br2/rtfs/root/.bin
	inf "Copying binary into rootfs"
	if [ -z "$renameFile" ]; then #rename file 
		cp $1 /br2/rtfs/root/.bin
		chmod +x /br2/rtfs/root/.bin/$(basename $1)
	else
		cp $1 /br2/rtfs/root/.bin/${renameFile}
		chmod +x /br2/rtfs/root/.bin/${renameFile}
	fi
	inf "Unmounting rootfs"
	umount /br2/rtfs
	set +e
}

function startVM {
	set -e
	# start the vm
	inf "Starting analysis VM..."
    # run_vm.sh script depends on the system arch, see script folder and corrosponding arch
	/br2/run_vm.sh

	inf "Analysis VM started, waiting on guest to boot"
	sleep 5

	# setup ssh remote exec
	export SSHPASS=root
	rexec="sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 root@127.0.0.1"
	
	# check VM booted and ssh  service running
	while ! $rexec "uname -a" >&2
	do
		debug "Guest not responding, sleeping and checking later"
		sleep 10
		debug "Checking guest..."
	done
	inf "Guest is up and kicking!"

	# test remote command exec
	debug "Checking liveness"
	$rexec "echo 'liveness test: ping'" >&2
	set +e
}

function stopVM {
	inf "Powering off VM..."
	echo q | socat - unix-connect:/br2/qemu-monitor-socket 1>&2
	sleep 3
	inf "Done!"
}

function startAnalysis {
	# param $1 filename, param $2 timeout
	# set up remote exec
	export SSHPASS=root
	rexec="sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 root@127.0.0.1"
	
	bin_name=$(basename $1)
	inf "Running $bin_name"
	$rexec "cd /root/.bin; chmod +x $bin_name; nohup strace -o trace -q -r -x -y -yy -ff -v -s 512 ./$bin_name > nohup.out 2> nohup.err < /dev/null &" 2>/dev/null
	starttime=$SECONDS
	inf "Analyzing..."

	local timeout=$2
	tout=$2
	sint=$PINT

	if [ -z "$fullrun" ]; then
		locked=false
		while true
		do
			# timeout reached
			if ! sleep $sint 2>/dev/null; then
				break
			fi
			
			# check for SSH access
			if ! $rexec "echo 'ping'" 2>/dev/null 1>&2 ; then
				warn "SSH failed, retrying..."
				sleep 2
				# checking again in case of network error
				if ! $rexec "echo 'ping'" 2>/dev/null 1>&2 ; then
					warn "Cannot access VM via SSH, sleeping for rest of the analysis"
					locked=true
					sleep $(($tout - ($SECONDS - $starttime))) 2>/dev/null
					break
				fi
			fi

			# primary check, check if sample is running
			running=false
			pid=$($rexec "ls -1 /root/.bin/trace* | sed 's/^.*trace.//g' |tail -1 2>/dev/null" 2>/dev/null)
			debug "Check for pid $pid"
			if $rexec "kill -0 $pid" 2>/dev/null; then # Primary check
				debug "PID $pid found..."
				running=true
			fi

			# give the sample some time to think about it's existence
			sleep 5

			# if primary check found no running process, check pid diff 
			if ! $running; then
				npid=$($rexec "ls -1 /root/.bin/trace* | sed 's/^.*trace.//g' |tail -1 2>/dev/null" 2>/dev/null)
				if [ $pid -eq $npid ]; then # Secondary check
					debug "Checked pid $pid and latest pid $npid are the same."
					warn "No running processes found, terminating analysis"
					break
				else
					debug "Checked pid $pid and latest pid $npid are not the same."
					running=true
				fi
			fi

			# check if timeout has been reached 
			tout=$(($SECONDS - $starttime))
			inf "Running time: $tout - Timeout: $timeout"
			if [[ $tout -ge $timeout ]]; then
				break
			else
				if [ $sint -ge $(($timeout-$tout)) ]; then
					sint=$(($timeout-$tout))
				fi
			fi
		done
	else
		sleeptime=$(($tout - ($SECONDS - $starttime)))
		inf "Running malware for full timeout period ($sleeptime)..."
		sleep "$sleeptime" 2>/dev/null
		inf "Timeout reached... stopping VM"
	fi
	inf "Analysis complete!"

}

#test
function saveAnalysis {
	# $1 parameter is the path to the bin file
	set -e
	# get system and network traces
	inf "Collecting system traces"
	result_path=$(dirname $1)
	dir_name=$(basename ${1%.*})
	cd $result_path
	inf "Creating dir $result_path/$dir_name"
	mkdir -p $dir_name
	inf "Mounting volume"
	mount /br2/rootfs.ext2 /br2/rtfs
	inf "Copying over artifacts..."
	rsync -aqv /br2/rtfs/root/.bin/ ${result_path}/${dir_name}/ --exclude $(basename $2)
	rsync -aqv /br2/dump.pcap ${result_path}/${dir_name}/
	inf "Number of files found: $(ls -1  ${result_path}/${dir_name}/|wc -l)"
	inf "Creating archive..."
	tar czf ${dir_name}.results.tgz -C $result_path $dir_name
	inf "Done!"
	rm -rf ${result_path}/${dir_name}
	umount /br2/rtfs
	rm -rf /br2/rtfs
	set +e
}

function example {
    echo -e "example: $progname -i /br2/malware.bin -t 60 -R -r evil.bin"
}

function usage {
    echo -e "usage: $progname PARAMETERS [OPTION]\n"
}

function help {
    echo -e ""
  usage
    echo -e "PARAMETERS:"
    echo -e "  -i, --input-bin  VAL  The path to the binary for analysis\n"
    echo -e "OPTION:"
    echo -e "  -t, --timeout    VAL How long to allow the binary to run before terminating analysis, default 60 sec"
    echo -e "  -R, --full-run       Run the analysis for the timeout even if no system activity is detected"
#    echo -e "  -S, --no-strace      Run the binary without system call tracing. Only network activity is logged"
    echo -e "  -r, --rename-bin VAL Rename the binary file before running it to VAL"
    echo -e "  -h,  --help          Prints this help\n"
  example
    echo -e ""
}

# Ensures that all the mandatory args are not empty
function margs_check {
	if [ $# -lt $margs ]; then
	    help
	    exit 1 # error
	fi
}

#make sure at least one param is passed
margs=1
if [ $# -eq 0 ]; then
    help
    exit 1 # error
fi

# TODO: Options for 
# 1. run with no strace
# 2. rename file
# 3. run no early termination
filename=
renameFile=""
noStrace=""
fullrun=""
timeout=60

# dev options
scriptTime=$SECONDS
progname=$0
re='^[0-9]+$'
PINT=30 # poll interval is set 30 seconds
debug=""

while [ "$1" != "" ]; do
    case $1 in
	-i | --input-bin )     shift
				filename=$1
				if [ -z "$1" ] ; then
					echo -e ""
					error "File name for target binary must be specified for analysis.";
					help
					exit 1;
				fi
				;;
	-t | --timeout )        shift
				timeout=$1
				if ! [[ $timeout =~ $re ]] || [ -z "$1" ] ; then
					echo -e ""
					error "Timeout value is not a positive integer.";
					help
					exit 1;
				fi
				;;
	-r | --rename-bin )     shift
				renameFile=$1
				if [[ "$renameFile" =~ [^a-zA-Z0-9_-.] ]] || [ -z "$1" ]; then
					echo -e ""
					error "Invalid rename filename: ${renameFile}. Must only contain shell friendly chars."
					help
					exit 1;
				fi
				;;
	-S | --no-strace )      noStrace="true"
				;;
	-R | --full-run )       fullrun="true"
				;;
	-d | --debug )       	debug="true"
				;;
	-h | --help )           help
				exit
				;;
	* )                     help
				exit 1
    esac
    shift
done

margs_check $filename

analname=

inf "Full file path to analyze: $filename" 
inf "Analysis timeout: $timeout sec"
if [ -z "$renameFile" ]; then
	inf "Binary file will use $filename for analysis.";
	analname="$filename"
else
	inf "Binary file renamed from $(basename $filename) to $renameFile";
	analname="$(dirname $filename)/$renameFile"
fi
if [ -z "$noStrace" ]; then
	inf "Running system call tracing"
else
	inf "Disabling system call tracing"
	fullrun="true"
fi
if [ -z "$fullrun" ]; then
	inf "Full analysis timeout disabled"
else
	inf "Full analysis timeout enabled"
fi
if ! [ -z "$debug" ]; then
	inf "Debug mode enabled"
fi


init $filename
if ! [ -z "$debug" ]; then
	/bin/bash
else
	startVM
	startAnalysis $analname $timeout
fi
stopVM
saveAnalysis $filename $analname
exit 0

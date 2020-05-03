if ( ! $?PBS_ENVIRONMENT  && ! $?SGE_O_SHELL && ! $?JOBNAME ) then
	tty -s
	if ( $status == 0 ) then
		setenv TERM `tset -Q -`
	endif

	# by putting this here, we force DISPLAY to be explicitly set
	# if we ever run an interactive job through the queueing system
	# by using utmp (w) we may have a truncated hostname,
	# so prefer REMOTEHOST if known
	set TTY=`tty|sed 's/\/dev\///p'|sort|uniq`
	set iam=`whoami`
	set REMOTE=`who am i | grep $TTY | grep $iam | awk '{print $NF}' | sed 's/(//' | sed 's/)//' `
	#echo REMOTE: $REMOTE DISPLAY: $DISPLAY
	#setenv DISPLAY ${REMOTE}:0.0
	if ( ! $?DISPLAY ) then
		if ( $?REMOTEHOST ) then
			setenv DISPLAY ${REMOTEHOST}:0.0
		else
			setenv DISPLAY ${REMOTE}:0.0
		endif
	endif
else
	setenv TERM batch
endif

switch ( $TERM )
case dialup:
case unknown:
	setenv DIALUP true
	breaksw
case batch:
	breaksw
default:
	if ( ! $?remote ) then
		set remote=`who am i | awk '{print $6}' | sed 's/(//' | sed 's/)//' | sed 's/.senator.org//' | sed 's/.senator.//'`
		setenv REMOTE $remote
	endif
	breaksw
endsw

if ( -r /etc/csh.login ) then
	source /etc/csh.login
endif

if ( -r $home/.login.${HOST} ) then
	source ~/.login.${HOST}
endif

if ( -r $home/.login.dowin ) then
	source $home/.login.dowin	# else do ...
endif

if ( ( ! $?PBS_ENVIRONMENT ) && ( ! $?SGE_O_SHELL ) && ( ! $?Not_Interactive ) && ( ! $?JOB_NAME ) ) then

	echo "On at: "`date`
	mesg y; uptime

	if ( -r ~/.project ) then
		cat ~/.project
	endif

endif


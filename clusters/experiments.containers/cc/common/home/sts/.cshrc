#[ x"$0" != x"csh" -a x"$0" != x"tcsh" -a x"$0" != x"-tcsh" -a x"$0" != x"-csh"] && echo "This is not a $0 script." && exit

umask 022

if ( -r ~sts/.cshrc.env ) then
	source ~sts/.cshrc.env
else
	if ( -r ~/.cshrc.env ) then
		source ~/.cshrc.env
	endif
endif

set isATTY=`tty`
switch ( "$isATTY" )
"not a tty")
	set Not_Interactive=tty
	;;
*)
	;;
endsw

if ( $?prompt && ( ! $?PBS_ENVIRONMENT ) && ( ! $?SGE_O_SHELL ) && ( ! $?JOB_NAME ) ) then

	if ( -r ~sts/.cshrc.interactive ) then
		source ~sts/.cshrc.interactive

	else
		if ( -r ~/.cshrc.interactive ) then
			source ~/.cshrc.interactive
		endif
	endif
else
	set tty=""
	set cdpath=""
	unsetenv CDPATH
	if ( $?prompt ) then
		set Not_Interactive=prompt
	endif
	if ( $?PBS_ENVIRONMENT ) then
		set Not_Interactive=PBS
	endif
	if ( $?SGE_O_SHELL && $?JOB_NAME ) then
		set Not_Interactive=SGE
	endif
endif

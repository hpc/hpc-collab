setenv SQUEUE_ALL	yes
setenv SQUEUE_FORMAT	"%.24i %.9Q %.9q %.20a %.18u %.18T %.12M %.12l %.20S %.20e %.6D %R"
setenv SQUEUE_SORT	-t,-p,e,S

set scontrol_found=`which scontrol`
if ( -x "${scontrol_found}" ) then
	setenv CLUSTERNAME `scontrol show config | grep ClusterName | awk '{print $3}'`
endif

function slurm_cli_setup_defaults(options, early)
	return slurm.SUCCESS
end

function slurm_cli_pre_submit(cli_type, options, offset)
	return slurm.SUCCESS
end

function slurm_cli_post_submit(cli_type, offset, jobid, stepid)
	return slurm.SUCCESS
end

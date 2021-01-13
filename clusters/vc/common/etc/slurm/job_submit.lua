
--! slurm job_submit.lua
--!  todo: vectorize with a driver table of licenses(), _set_hostqos(), etc
--! todo: licenses(): create a table of licenses, possibly from an external source of state
--! such as a config file or earlier, one-time priming sacctmgr

function _limit_license_cnt(orig_string, license_name, max_count)
	local i = 0
 	local j = 0
 	local val = 0

 	if orig_string == nil then
		return 0
	end

 	i, j, val = string.find(orig_string, license_name .. "%:(%d)")
	if val ~= nil then
		slurm.log_info("name:%s count:%s", license_name, val)
	end
	if val ~= nil and val + 0 > max_count then
		return 1
	end
	return 0
end

function _set_default_license_cnt (job_desc)
	local bad_license_count = 0

	slurm.log_info("[job_submit.lua: _set_default_license_cnt()")
	if job_desc.licenses ~= nil then
		bad_license_count = _limit_license_cnt(job_desc.licenses, "none@slurmdb", 1)
		bad_license_count = _limit_license_cnt(job_desc.licenses, "homevagrant@slurmdb", 1) + bad_license_count
		if bad_license_count > 0 then
			slurm.log_info("slurm_job_submit: for user %d, invalid licenses count: %s",
								job_desc.user_id, job_desc.licenses)
			slurm.log_info(" job_submit.lua: _set_default_license_cnt(slurm.ESLURM_INVALID_LICENSES)]")
			return slurm.ESLURM_INVALID_LICENSES
		end
	else
		job_desc.licenses="homevagrant@slurmdb"
		slurm.log_verbose("Set default filesys license to all licenses for job from user:%d", job_desc.user_id)
	end

	slurm.log_info(" job_submit.lua: _set_default_license_cnt(slurm.SUCCESS)]")
	return slurm.SUCCESS
end

function _slurm_job_setlic ( job_desc )
	local rc = 0
	local jobid = 0

	slurm.log_info("[job_submit.lua: _slurm_job_setlic()")
	if job_desc ~= nil then
		if job_desc.job_id ~= nil then
			jobid = job_desc.job_id
		end
	end

	rc = _set_default_license_cnt ( job_desc )
	slurm.log_info(" job_submit.lua: _slurm_job_setlic(%d)]", rc)
	return rc
end

function _hostname()
	slurm.log_info("[job_submit.lua: _hostname()")
	local hp
	local hostname
	hp = io.popen ("hostname -s")
	hostname = hp:read("*a") or ""
	hp:close()
	hostname = string.gsub(hostname, "\n$", "")
	slurm.log_info(" job_submit.lua: _hostname(%s)]", hostname)
	return hostname
end

function _str (str)
	if str == NIL then
		return "<nil>"
	else
		return str
	end
end

function _set_hostqos ( job_desc )
	local rc = 0
	local qos
	local hostname
	local cluster_abbrev
	slurm.log_info("[job_submit.lua: _set_hostqos()")

	hostname = os.getenv("HOSTNAME")
	if hostname == nil then
		hostname = _hostname()
	end
	qos = job_desc.qos
	if hostname == nil then
		slurm.log_user("  job_submit.lua:_set_hostqos(): internal error: unable to determine hostname:<nil>")
		return slurm.ERROR
	end
	cluster_abbrev = string.sub(hostname,1,2)

	-- if user specified QOS, and it does not include the host-specific suffix "__<cluster-abbreviation>"
	-- then append the host abbreviation suffix.
	-- if the user does not specify a QOS, then normal Default QOS settings apply, no adjustment is done
	qos_suffix = "__" .. cluster_abbrev
	if qos ~= nil then
		sufx_start, sufx_end = string.find(qos, qos_suffix)
		-- not a suffix match? => must append
		if sufx_end ~= string.len(qos) then
			new_qos = qos .. qos_suffix
			job_desc.qos = new_qos
		end
		
	end

	slurm.log_info(" job_submit.lua: _set_hostqos(%s)]", _str(job_desc.qos))
	return slurm.SUCCESS
end

--########################################################################--
--
--  SLURM job_submit/lua interface:
--
--########################################################################--

function slurm_job_submit ( job_desc, part_list, submit_uid )
	local rc

	slurm.log_info("[slurm_job_submit()")
	rc = _slurm_job_setlic(job_desc)
	if rc == slurm.SUCCESS then
		rc = _set_hostqos(job_desc)
	end

	slurm.log_info(" slurm_job_submit()]")
	return rc
end

function slurm_job_modify ( job_desc, job_rec, part_list, modify_uid )
	local rc

	slurm.log_info("[slurm_job_modify()")
	rc = _slurm_job_setlic(job_desc)
	slurm.log_info(" slurm_job_modify()]")

	return rc
end

slurm.log_info("job_submit.lua: initialized/slurm.SUCCESS")
return slurm.SUCCESS

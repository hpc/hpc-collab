#! /usr/bin/env lua

--! slurm job_submit.lua
--!  todo: vectorize with a driver table of licenses(), _set_hostqos(), etc
--! todo: licenses(): create a table of licenses, possibly from an external source of state
--! such as a config file or earlier, one-time priming sacctmgr

--! need a lightweight mechanism to set this, preferably at RPM installation time, not job runtime
--! lightweight = not grep or scontrol show config
local slurm_prefix_dir = "/etc/slurm"

--! lua code is cached in slurmctld, so restart slurmctld when the noisy flag file is created or removed
--! this file must exist on the node hosting the slurmctld
local noisy_flag		= slurm_prefix_dir .. "/.job_submit.noisy"
local conf_file			=	slurm_prefix_dir .. "/job_submit.conf"
local jobsubmit_dir	=	slurm_prefix_dir .. "/job_submit.d"

local luarocks	= require "luarocks.loader"
local unistd		= require "posix.unistd"

function file_exists(path)
  local file = io.open(path, "rb")
  if file then
		file:close()
		return true	-- readable
	end
	return nil		-- not readable
end

function _limit_license_cnt(orig_string, license_name, max_count)
	local i = 0
 	local j = 0
 	local val = 0

 	if orig_string == nil then
		return 0
	end

 	i, j, val = string.find(orig_string, license_name .. "%:(%d)")
	if val ~= nil and noisy ~= nil then
		slurm.log_info("name:%s count:%s", license_name, val)
	end
	if val ~= nil and val + 0 > max_count then
		return 1
	end
	return 0
end

function _set_default_license_cnt (job_desc)
	local bad_license_count = 0

	if noisy ~= nil then slurm.log_info("[job_submit.lua: _set_default_license_cnt()") end
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
		if noisy ~= nil then slurm.log_info("Set default filesys license to all licenses for job from user:%d", job_desc.user_id) end
	end

	if noisy ~= nil then slurm.log_info(" job_submit.lua: _set_default_license_cnt(slurm.SUCCESS)]") end
	return slurm.SUCCESS
end

function _slurm_job_setlic ( job_desc )
	local rc = 0
	local jobid = 0

	if noisy ~= nil then slurm.log_info("[job_submit.lua: _slurm_job_setlic()") end
	if job_desc ~= nil then
		if job_desc.job_id ~= nil then
			jobid = job_desc.job_id
		end
	end

	rc = _set_default_license_cnt ( job_desc )
	if noisy ~= nil then slurm.log_info(" job_submit.lua: _slurm_job_setlic(%d)]", rc) end
	return rc
end

function _hostname()
	if noisy ~= nil then slurm.log_info("[job_submit.lua: _hostname()") end
	local hp
	local hostname
	hp = io.popen ("hostname -s")
	hostname = hp:read("*a") or ""
	hp:close()
	hostname = string.gsub(hostname, "\n$", "")
	if noisy ~= nil then slurm.log_info(" job_submit.lua: _hostname(%s)]", tostring(hostname)) end
	return hostname
end

function _valid_qos ( new_qos )
	if noisy ~= nil then slurm.log_info("[job_submit.lua: _valid_qos(%s)", tostring(new_qos)) end
	local test_qos
	local sp
	local cmd_prefix = "sacctmgr show qos -n format=name%-30s where qos="
	if new_qos == nil or 0 == string.len(new_qos) then
		return nil
	end
	local cmd = cmd_prefix .. new_qos
	sp = io.popen(cmd)
	test_qos = sp:read("*a") or ""
	sp:close()
	if noisy ~= nil then slurm.log_info(" job_submit.lua:_valid_qos(%s) => %s]", tostring(new_qos), tostring(test_qos)) end
	return tostring(new_qos)
end

function _set_hostqos ( job_desc )
	local rc = 0
	local qos
	local hostname
	local cluster_abbrev
	if noisy ~= nil then slurm.log_info("[job_submit.lua: _set_hostqos()") end

	hostname = os.getenv("HOSTNAME")
	if hostname == nil then
		hostname = _hostname()
	end
	qos = job_desc.qos
	if hostname == nil then
		slurm.log_user("  job_submit.lua:_set_hostqos(): internal error: unable to determine hostname:<nil>")
		return slurm.ERROR
	end

	-- if user specified QOS, and it does not include the host-specific suffix "__<cluster-abbreviation>"
	-- then append the host abbreviation suffix.
	-- if the user does not specify a QOS, then normal Default QOS settings apply, no adjustment is done
	cluster_abbrev = string.sub(hostname,1,2)
	qos_suffix = "__" .. cluster_abbrev
	if qos ~= nil then
		sufx_start, sufx_end = string.find(qos, qos_suffix)
		-- not a suffix match? => must append
		if sufx_start == nil or sufx_start == 0 then
			if sufx_end ~= string.len(qos) then
				new_qos = qos .. qos_suffix
				if _valid_qos(new_qos) ~= nil then
					job_desc.qos = new_qos
				end
			end
		end
	end

	if noisy ~= nil then slurm.log_info(" job_submit.lua: _set_hostqos(%s)]", tostring(job_desc.qos)) end
	return slurm.SUCCESS
end

--########################################################################--
--
--  SLURM job_submit/lua interface:
--
--########################################################################--

function slurm_job_submit ( job_desc, part_list, submit_uid )
	local rc = slurm.SUCCESS
  fn = { _slurm_job_setlic, _set_hostqos }

	if noisy ~= nil then slurm.log_info("[slurm_job_submit()") end
	for _,f in pairs(fn)
	do
		if rc == slurm.SUCCESS then
			rc = f(job_desc)
		end
	end
	if noisy ~= nil then slurm.log_info(" slurm_job_submit()]") end
	return rc
end

function slurm_job_modify ( job_desc, job_rec, part_list, modify_uid )
	local rc

	if noisy ~= nil then slurm.log_info("[slurm_job_modify()") end
	rc = _slurm_job_setlic(job_desc)
	if noisy ~= nil then slurm.log_info(" slurm_job_modify()]") end

	return rc
end

--! noisy = file_exists(noisy_flag)
noisy = unistd.access(noisy_flag,"r") == 0
slurm.log_info("job_submit.lua: initialized: noisy=%s, slurm.SUCCESS", tostring(noisy))

return slurm.SUCCESS

-- vim: background=dark sw=2 ts=2 bs=2 syntax=lua
